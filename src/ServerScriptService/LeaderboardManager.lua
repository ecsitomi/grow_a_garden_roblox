--[[
    LeaderboardManager.lua
    Server-Side Global Leaderboard System
    
    Priority: 19 (VIP & Monetization phase)
    Dependencies: DataStoreService, Players, EconomyManager
    Used by: UI, competitive features, social systems
    
    Features:
    - Global player rankings
    - Multiple leaderboard categories
    - VIP player highlighting
    - Competitive seasons
    - Achievement integration
    - Social comparison
--]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

-- Load required modules
local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)

local LeaderboardManager = {}
LeaderboardManager.__index = LeaderboardManager

-- ==========================================
-- DATASTORE SETUP
-- ==========================================

LeaderboardManager.DataStore = DataStoreService:GetDataStore("Leaderboard_v1")
LeaderboardManager.GlobalDataStore = DataStoreService:GetDataStore("GlobalLeaderboard_v1")

-- ==========================================
-- LEADERBOARD CATEGORIES
-- ==========================================

LeaderboardManager.Categories = {
    total_earnings = {
        name = "Total Earnings",
        icon = "💰",
        description = "All-time total coins earned",
        dataKey = "totalEarnings",
        formatFunction = function(value) return "$" .. ConfigModule.FormatNumber(value) end
    },
    
    plants_grown = {
        name = "Plants Grown",
        icon = "🌱",
        description = "Total plants successfully grown",
        dataKey = "totalPlantsGrown",
        formatFunction = function(value) return ConfigModule.FormatNumber(value) end
    },
    
    level = {
        name = "Player Level",
        icon = "⭐",
        description = "Current player level",
        dataKey = "level",
        formatFunction = function(value) return "Level " .. value end
    },
    
    garden_value = {
        name = "Garden Value",
        icon = "🏡",
        description = "Total value of all plots and plants",
        dataKey = "gardenValue",
        formatFunction = function(value) return "$" .. ConfigModule.FormatNumber(value) end
    },
    
    daily_streak = {
        name = "Daily Streak",
        icon = "🔥",
        description = "Consecutive days played",
        dataKey = "dailyStreak",
        formatFunction = function(value) return value .. " days" end
    },
    
    achievements = {
        name = "Achievements",
        icon = "🏆",
        description = "Total achievements unlocked",
        dataKey = "achievementCount",
        formatFunction = function(value) return value .. " unlocked" end
    }
}

-- ==========================================
-- STATE MANAGEMENT
-- ==========================================

LeaderboardManager.ActiveLeaderboards = {}        -- [category] = {data, lastUpdate}
LeaderboardManager.PlayerData = {}                -- [userId] = {cached player data}
LeaderboardManager.VIPPlayers = {}                -- Set of VIP player IDs
LeaderboardManager.UpdateQueue = {}               -- Players pending leaderboard updates

-- Update intervals
LeaderboardManager.UPDATE_INTERVAL = 300          -- 5 minutes
LeaderboardManager.GLOBAL_UPDATE_INTERVAL = 900   -- 15 minutes
LeaderboardManager.MAX_ENTRIES_PER_BOARD = 100    -- Top 100 players

-- ==========================================
-- INITIALIZATION
-- ==========================================

function LeaderboardManager:Initialize()
    print("📊 LeaderboardManager: Initializing leaderboard system...")
    
    -- Initialize data structures
    self:InitializeDataStructures()
    
    -- Set up remote events
    self:SetupRemoteEvents()
    
    -- Load cached leaderboard data
    self:LoadCachedLeaderboards()
    
    -- Set up update loops
    self:SetupUpdateLoops()
    
    -- Set up player tracking
    self:SetupPlayerTracking()
    
    print("✅ LeaderboardManager: Leaderboard system initialized")
end

function LeaderboardManager:InitializeDataStructures()
    -- Initialize empty leaderboards for each category
    for categoryId, categoryData in pairs(self.Categories) do
        self.ActiveLeaderboards[categoryId] = {
            data = {},
            lastUpdate = 0,
            needsUpdate = true
        }
    end
end

function LeaderboardManager:SetupRemoteEvents()
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then
        remoteEvents = Instance.new("Folder")
        remoteEvents.Name = "RemoteEvents"
        remoteEvents.Parent = ReplicatedStorage
    end
    
    -- Create remote functions for leaderboard data
    local getLeaderboardFunction = Instance.new("RemoteFunction")
    getLeaderboardFunction.Name = "GetLeaderboard"
    getLeaderboardFunction.Parent = remoteEvents
    getLeaderboardFunction.OnServerInvoke = function(player, category)
        return self:GetLeaderboardData(category)
    end
    
    local getPlayerRankFunction = Instance.new("RemoteFunction")
    getPlayerRankFunction.Name = "GetPlayerRank"
    getPlayerRankFunction.Parent = remoteEvents
    getPlayerRankFunction.OnServerInvoke = function(player, category)
        return self:GetPlayerRank(player.UserId, category)
    end
    
    -- Event for leaderboard updates
    local leaderboardUpdateEvent = Instance.new("RemoteEvent")
    leaderboardUpdateEvent.Name = "LeaderboardUpdate"
    leaderboardUpdateEvent.Parent = remoteEvents
    
    self.LeaderboardUpdateEvent = leaderboardUpdateEvent
end

function LeaderboardManager:SetupPlayerTracking()
    -- Track player joining
    Players.PlayerAdded:Connect(function(player)
        self:OnPlayerJoined(player)
    end)
    
    -- Track player leaving
    Players.PlayerRemoving:Connect(function(player)
        self:OnPlayerLeaving(player)
    end)
    
    -- Initialize existing players
    for _, player in pairs(Players:GetPlayers()) do
        self:OnPlayerJoined(player)
    end
end

function LeaderboardManager:SetupUpdateLoops()
    -- Regular leaderboard updates
    spawn(function()
        while true do
            wait(self.UPDATE_INTERVAL)
            self:UpdateAllLeaderboards()
        end
    end)
    
    -- Global leaderboard sync
    spawn(function()
        while true do
            wait(self.GLOBAL_UPDATE_INTERVAL)
            self:SyncGlobalLeaderboards()
        end
    end)
    
    -- Process update queue
    spawn(function()
        while true do
            wait(30) -- Process every 30 seconds
            self:ProcessUpdateQueue()
        end
    end)
end

-- ==========================================
-- PLAYER DATA MANAGEMENT
-- ==========================================

function LeaderboardManager:OnPlayerJoined(player)
    -- Initialize player data cache
    self.PlayerData[player.UserId] = {
        displayName = player.DisplayName,
        username = player.Name,
        joinTime = tick(),
        isVIP = false
    }
    
    -- Check VIP status
    self:UpdatePlayerVIPStatus(player)
    
    -- Queue for leaderboard update
    self:QueuePlayerUpdate(player.UserId)
end

function LeaderboardManager:OnPlayerLeaving(player)
    -- Final update before leaving
    self:UpdatePlayerStats(player)
    
    -- Clean up cache (keep some data for recent players)
    -- Don't remove immediately in case they rejoin soon
end

function LeaderboardManager:UpdatePlayerVIPStatus(player)
    -- Get VIP status from VIP system
    local vipManager = _G.VIPManager
    if vipManager then
        local isVIP = vipManager:IsPlayerVIP(player)
        self.PlayerData[player.UserId].isVIP = isVIP
        
        if isVIP then
            self.VIPPlayers[player.UserId] = true
        else
            self.VIPPlayers[player.UserId] = nil
        end
    end
end

function LeaderboardManager:QueuePlayerUpdate(userId)
    if not self.UpdateQueue[userId] then
        self.UpdateQueue[userId] = {
            userId = userId,
            timestamp = tick()
        }
    end
end

function LeaderboardManager:ProcessUpdateQueue()
    local currentTime = tick()
    local processedCount = 0
    
    for userId, updateData in pairs(self.UpdateQueue) do
        -- Process updates that are at least 10 seconds old
        if currentTime - updateData.timestamp >= 10 then
            self:UpdatePlayerLeaderboardData(userId)
            self.UpdateQueue[userId] = nil
            processedCount = processedCount + 1
            
            -- Limit processing per batch
            if processedCount >= 10 then
                break
            end
        end
    end
    
    if processedCount > 0 then
        print("📊 LeaderboardManager: Processed", processedCount, "player updates")
    end
end

-- ==========================================
-- STATISTICS COLLECTION
-- ==========================================

function LeaderboardManager:UpdatePlayerStats(player)
    if not player or not player.Parent then return end
    
    local userId = player.UserId
    local stats = {}
    
    -- Collect stats from various managers
    stats.totalEarnings = self:GetPlayerTotalEarnings(player)
    stats.totalPlantsGrown = self:GetPlayerPlantsGrown(player)
    stats.level = self:GetPlayerLevel(player)
    stats.gardenValue = self:GetPlayerGardenValue(player)
    stats.dailyStreak = self:GetPlayerDailyStreak(player)
    stats.achievementCount = self:GetPlayerAchievementCount(player)
    
    -- Cache the stats
    if not self.PlayerData[userId] then
        self.PlayerData[userId] = {}
    end
    
    for key, value in pairs(stats) do
        self.PlayerData[userId][key] = value
    end
    
    -- Queue for leaderboard update
    self:QueuePlayerUpdate(userId)
    
    return stats
end

function LeaderboardManager:GetPlayerTotalEarnings(player)
    local economyManager = _G.EconomyManager
    if economyManager then
        return economyManager:GetPlayerTotalEarnings(player) or 0
    end
    return 0
end

function LeaderboardManager:GetPlayerPlantsGrown(player)
    local progressionManager = _G.ProgressionManager
    if progressionManager then
        return progressionManager:GetPlayerStat(player, "totalPlantsGrown") or 0
    end
    return 0
end

function LeaderboardManager:GetPlayerLevel(player)
    local progressionManager = _G.ProgressionManager
    if progressionManager then
        return progressionManager:GetPlayerLevel(player) or 1
    end
    return 1
end

function LeaderboardManager:GetPlayerGardenValue(player)
    local gardenManager = _G.GardenManager
    if gardenManager then
        return gardenManager:CalculatePlayerGardenValue(player) or 0
    end
    return 0
end

function LeaderboardManager:GetPlayerDailyStreak(player)
    local dailyBonusManager = _G.DailyBonusManager
    if dailyBonusManager then
        return dailyBonusManager:GetPlayerStreak(player) or 0
    end
    return 0
end

function LeaderboardManager:GetPlayerAchievementCount(player)
    local achievementSystem = _G.AchievementSystem
    if achievementSystem then
        return achievementSystem:GetPlayerAchievementCount(player) or 0
    end
    return 0
end

function LeaderboardManager:UpdatePlayerLeaderboardData(userId)
    local playerData = self.PlayerData[userId]
    if not playerData then return end
    
    -- Update each category's leaderboard
    for categoryId, categoryConfig in pairs(self.Categories) do
        local value = playerData[categoryConfig.dataKey]
        if value then
            self:UpdateCategoryLeaderboard(categoryId, userId, value)
        end
    end
    
    print("📊 LeaderboardManager: Updated leaderboard data for user", userId)
end

-- ==========================================
-- LEADERBOARD UPDATES
-- ==========================================

function LeaderboardManager:UpdateCategoryLeaderboard(categoryId, userId, value)
    local leaderboard = self.ActiveLeaderboards[categoryId]
    if not leaderboard then return end
    
    -- Update or add player entry
    local playerData = self.PlayerData[userId]
    local entry = {
        userId = userId,
        value = value,
        displayName = playerData.displayName or "Unknown",
        username = playerData.username or "Unknown",
        isVIP = playerData.isVIP or false,
        lastUpdate = tick()
    }
    
    -- Find existing entry or add new one
    local existingIndex = nil
    for i, existingEntry in ipairs(leaderboard.data) do
        if existingEntry.userId == userId then
            existingIndex = i
            break
        end
    end
    
    if existingIndex then
        leaderboard.data[existingIndex] = entry
    else
        table.insert(leaderboard.data, entry)
    end
    
    -- Sort leaderboard (descending order)
    table.sort(leaderboard.data, function(a, b)
        return a.value > b.value
    end)
    
    -- Trim to max entries
    if #leaderboard.data > self.MAX_ENTRIES_PER_BOARD then
        for i = self.MAX_ENTRIES_PER_BOARD + 1, #leaderboard.data do
            leaderboard.data[i] = nil
        end
    end
    
    leaderboard.needsUpdate = true
    leaderboard.lastUpdate = tick()
end

function LeaderboardManager:UpdateAllLeaderboards()
    local updateCount = 0
    
    -- Update stats for all online players
    for _, player in pairs(Players:GetPlayers()) do
        self:UpdatePlayerStats(player)
        updateCount = updateCount + 1
    end
    
    -- Mark all leaderboards as updated
    for categoryId, leaderboard in pairs(self.ActiveLeaderboards) do
        if leaderboard.needsUpdate then
            leaderboard.needsUpdate = false
            
            -- Notify clients of update
            self:NotifyClientsOfUpdate(categoryId)
        end
    end
    
    print("📊 LeaderboardManager: Updated leaderboards for", updateCount, "players")
end

function LeaderboardManager:NotifyClientsOfUpdate(categoryId)
    if self.LeaderboardUpdateEvent then
        self.LeaderboardUpdateEvent:FireAllClients(categoryId, self:GetLeaderboardData(categoryId))
    end
end

-- ==========================================
-- DATA RETRIEVAL
-- ==========================================

function LeaderboardManager:GetLeaderboardData(categoryId)
    local leaderboard = self.ActiveLeaderboards[categoryId]
    if not leaderboard then
        return {
            category = categoryId,
            data = {},
            lastUpdate = 0
        }
    end
    
    -- Prepare data for client
    local clientData = {
        category = categoryId,
        categoryInfo = self.Categories[categoryId],
        data = {},
        lastUpdate = leaderboard.lastUpdate
    }
    
    -- Format entries for client
    for i, entry in ipairs(leaderboard.data) do
        table.insert(clientData.data, {
            rank = i,
            userId = entry.userId,
            displayName = entry.displayName,
            username = entry.username,
            value = entry.value,
            formattedValue = self.Categories[categoryId].formatFunction(entry.value),
            isVIP = entry.isVIP,
            lastUpdate = entry.lastUpdate
        })
    end
    
    return clientData
end

function LeaderboardManager:GetPlayerRank(userId, categoryId)
    local leaderboard = self.ActiveLeaderboards[categoryId]
    if not leaderboard then return nil end
    
    for i, entry in ipairs(leaderboard.data) do
        if entry.userId == userId then
            return {
                rank = i,
                value = entry.value,
                formattedValue = self.Categories[categoryId].formatFunction(entry.value),
                totalPlayers = #leaderboard.data
            }
        end
    end
    
    return nil -- Player not on leaderboard
end

function LeaderboardManager:GetTopPlayers(categoryId, limit)
    limit = limit or 10
    
    local leaderboard = self.ActiveLeaderboards[categoryId]
    if not leaderboard then return {} end
    
    local topPlayers = {}
    for i = 1, math.min(limit, #leaderboard.data) do
        table.insert(topPlayers, leaderboard.data[i])
    end
    
    return topPlayers
end

function LeaderboardManager:GetPlayersAroundRank(userId, categoryId, range)
    range = range or 5
    
    local leaderboard = self.ActiveLeaderboards[categoryId]
    if not leaderboard then return {} end
    
    -- Find player's rank
    local playerRank = nil
    for i, entry in ipairs(leaderboard.data) do
        if entry.userId == userId then
            playerRank = i
            break
        end
    end
    
    if not playerRank then return {} end
    
    -- Get players around this rank
    local startRank = math.max(1, playerRank - range)
    local endRank = math.min(#leaderboard.data, playerRank + range)
    
    local nearbyPlayers = {}
    for i = startRank, endRank do
        table.insert(nearbyPlayers, leaderboard.data[i])
    end
    
    return nearbyPlayers
end

-- ==========================================
-- PERSISTENT STORAGE
-- ==========================================

function LeaderboardManager:LoadCachedLeaderboards()
    print("📊 LeaderboardManager: Loading cached leaderboard data...")
    
    for categoryId, categoryConfig in pairs(self.Categories) do
        spawn(function()
            self:LoadCategoryLeaderboard(categoryId)
        end)
    end
end

function LeaderboardManager:LoadCategoryLeaderboard(categoryId)
    local success, cachedData = pcall(function()
        return self.DataStore:GetAsync("leaderboard_" .. categoryId)
    end)
    
    if success and cachedData then
        self.ActiveLeaderboards[categoryId].data = cachedData.data or {}
        self.ActiveLeaderboards[categoryId].lastUpdate = cachedData.lastUpdate or 0
        
        print("📊 LeaderboardManager: Loaded cached data for", categoryId, "with", #self.ActiveLeaderboards[categoryId].data, "entries")
    else
        warn("⚠️ LeaderboardManager: Failed to load cached data for", categoryId)
    end
end

function LeaderboardManager:SaveCategoryLeaderboard(categoryId)
    local leaderboard = self.ActiveLeaderboards[categoryId]
    if not leaderboard then return end
    
    local dataToSave = {
        data = leaderboard.data,
        lastUpdate = leaderboard.lastUpdate,
        saveTime = tick()
    }
    
    local success, errorMessage = pcall(function()
        self.DataStore:SetAsync("leaderboard_" .. categoryId, dataToSave)
    end)
    
    if success then
        print("📊 LeaderboardManager: Saved leaderboard data for", categoryId)
    else
        warn("⚠️ LeaderboardManager: Failed to save leaderboard data for", categoryId, "-", errorMessage)
    end
end

function LeaderboardManager:SyncGlobalLeaderboards()
    print("📊 LeaderboardManager: Syncing global leaderboards...")
    
    for categoryId, leaderboard in pairs(self.ActiveLeaderboards) do
        if leaderboard.needsUpdate then
            spawn(function()
                self:SaveCategoryLeaderboard(categoryId)
            end)
        end
    end
end

-- ==========================================
-- SEASONAL & SPECIAL EVENTS
-- ==========================================

function LeaderboardManager:StartSeason(seasonName, categories, duration)
    print("🏆 LeaderboardManager: Starting season:", seasonName)
    
    -- Create seasonal leaderboards
    for _, categoryId in ipairs(categories) do
        local seasonCategoryId = "season_" .. seasonName .. "_" .. categoryId
        
        self.ActiveLeaderboards[seasonCategoryId] = {
            data = {},
            lastUpdate = tick(),
            needsUpdate = true,
            seasonal = true,
            seasonName = seasonName,
            endTime = tick() + duration
        }
        
        -- Copy category config
        self.Categories[seasonCategoryId] = {
            name = "Season " .. seasonName .. " - " .. self.Categories[categoryId].name,
            icon = "🏆",
            description = "Seasonal ranking for " .. self.Categories[categoryId].description,
            dataKey = self.Categories[categoryId].dataKey,
            formatFunction = self.Categories[categoryId].formatFunction,
            seasonal = true
        }
    end
end

function LeaderboardManager:EndSeason(seasonName)
    print("🏆 LeaderboardManager: Ending season:", seasonName)
    
    -- Archive seasonal leaderboards
    for categoryId, leaderboard in pairs(self.ActiveLeaderboards) do
        if leaderboard.seasonal and leaderboard.seasonName == seasonName then
            -- Save final results
            self:SaveSeasonResults(seasonName, categoryId, leaderboard)
            
            -- Remove from active leaderboards
            self.ActiveLeaderboards[categoryId] = nil
            self.Categories[categoryId] = nil
        end
    end
    
    -- Distribute season rewards
    self:DistributeSeasonRewards(seasonName)
end

function LeaderboardManager:SaveSeasonResults(seasonName, categoryId, leaderboard)
    local resultsData = {
        seasonName = seasonName,
        categoryId = categoryId,
        results = leaderboard.data,
        endTime = tick()
    }
    
    local success, errorMessage = pcall(function()
        self.GlobalDataStore:SetAsync("season_results_" .. seasonName .. "_" .. categoryId, resultsData)
    end)
    
    if success then
        print("🏆 LeaderboardManager: Saved season results for", seasonName, categoryId)
    else
        warn("⚠️ LeaderboardManager: Failed to save season results -", errorMessage)
    end
end

function LeaderboardManager:DistributeSeasonRewards(seasonName)
    -- This would integrate with the reward system
    print("🎁 LeaderboardManager: Distributing season rewards for", seasonName)
end

-- ==========================================
-- ACHIEVEMENT INTEGRATION
-- ==========================================

function LeaderboardManager:CheckRankingAchievements(userId, categoryId, newRank)
    if newRank == 1 then
        -- Player reached #1
        self:TriggerAchievement(userId, "first_place_" .. categoryId)
    elseif newRank <= 10 then
        -- Player reached top 10
        self:TriggerAchievement(userId, "top_ten_" .. categoryId)
    elseif newRank <= 100 then
        -- Player reached top 100
        self:TriggerAchievement(userId, "top_hundred_" .. categoryId)
    end
end

function LeaderboardManager:TriggerAchievement(userId, achievementId)
    local achievementSystem = _G.AchievementSystem
    if achievementSystem then
        local player = Players:GetPlayerByUserId(userId)
        if player then
            achievementSystem:UnlockAchievement(player, achievementId)
        end
    end
end

-- ==========================================
-- VIP FEATURES
-- ==========================================

function LeaderboardManager:GetVIPLeaderboard(categoryId)
    local leaderboard = self.ActiveLeaderboards[categoryId]
    if not leaderboard then return {} end
    
    local vipLeaderboard = {}
    for _, entry in ipairs(leaderboard.data) do
        if entry.isVIP then
            table.insert(vipLeaderboard, entry)
        end
    end
    
    return vipLeaderboard
end

function LeaderboardManager:GetVIPRank(userId, categoryId)
    local vipLeaderboard = self:GetVIPLeaderboard(categoryId)
    
    for i, entry in ipairs(vipLeaderboard) do
        if entry.userId == userId then
            return {
                rank = i,
                value = entry.value,
                totalVIPs = #vipLeaderboard
            }
        end
    end
    
    return nil
end

-- ==========================================
-- ANALYTICS & MONITORING
-- ==========================================

function LeaderboardManager:GetLeaderboardStats()
    local stats = {
        totalCategories = 0,
        totalPlayers = 0,
        vipPlayers = 0,
        lastUpdate = 0
    }
    
    for categoryId, leaderboard in pairs(self.ActiveLeaderboards) do
        if not leaderboard.seasonal then
            stats.totalCategories = stats.totalCategories + 1
            stats.totalPlayers = math.max(stats.totalPlayers, #leaderboard.data)
            stats.lastUpdate = math.max(stats.lastUpdate, leaderboard.lastUpdate)
        end
    end
    
    for userId, _ in pairs(self.VIPPlayers) do
        stats.vipPlayers = stats.vipPlayers + 1
    end
    
    return stats
end

function LeaderboardManager:GetCategoryStats(categoryId)
    local leaderboard = self.ActiveLeaderboards[categoryId]
    if not leaderboard then return nil end
    
    local stats = {
        totalPlayers = #leaderboard.data,
        vipPlayers = 0,
        averageValue = 0,
        topValue = 0,
        lastUpdate = leaderboard.lastUpdate
    }
    
    local totalValue = 0
    for _, entry in ipairs(leaderboard.data) do
        if entry.isVIP then
            stats.vipPlayers = stats.vipPlayers + 1
        end
        totalValue = totalValue + entry.value
        if entry.value > stats.topValue then
            stats.topValue = entry.value
        end
    end
    
    if stats.totalPlayers > 0 then
        stats.averageValue = totalValue / stats.totalPlayers
    end
    
    return stats
end

-- ==========================================
-- PUBLIC API
-- ==========================================

function LeaderboardManager:GetAllCategories()
    return self.Categories
end

function LeaderboardManager:ForceUpdate()
    self:UpdateAllLeaderboards()
end

function LeaderboardManager:AddCustomCategory(categoryId, config)
    self.Categories[categoryId] = config
    self.ActiveLeaderboards[categoryId] = {
        data = {},
        lastUpdate = 0,
        needsUpdate = true
    }
end

function LeaderboardManager:RemoveCategory(categoryId)
    self.Categories[categoryId] = nil
    self.ActiveLeaderboards[categoryId] = nil
end

-- ==========================================
-- CLEANUP
-- ==========================================

function LeaderboardManager:Cleanup()
    -- Save all leaderboard data
    for categoryId, leaderboard in pairs(self.ActiveLeaderboards) do
        if not leaderboard.seasonal then
            self:SaveCategoryLeaderboard(categoryId)
        end
    end
    
    print("📊 LeaderboardManager: Cleaned up and saved all data")
end

-- ==========================================
-- GLOBAL REGISTRATION
-- ==========================================

_G.LeaderboardManager = LeaderboardManager

return LeaderboardManager
