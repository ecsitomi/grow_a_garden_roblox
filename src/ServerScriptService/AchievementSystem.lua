--[[
    AchievementSystem.lua
    Server-Side Achievement & Badge System
    
    Priority: 20 (VIP & Monetization phase)
    Dependencies: DataStoreService, BadgeService, Players
    Used by: All gameplay systems, UI, progression
    
    Features:
    - Achievement tracking and unlocking
    - Roblox badge integration
    - Progress-based achievements
    - VIP exclusive achievements
    - Reward distribution
    - Social sharing
--]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

-- Load required modules
local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)

local AchievementSystem = {}
AchievementSystem.__index = AchievementSystem

-- ==========================================
-- DATASTORE SETUP
-- ==========================================

AchievementSystem.DataStore = DataStoreService:GetDataStore("Achievements_v1")
AchievementSystem.ProgressDataStore = DataStoreService:GetDataStore("AchievementProgress_v1")

-- ==========================================
-- ACHIEVEMENT DEFINITIONS
-- ==========================================

AchievementSystem.Achievements = {
    -- Planting Achievements
    first_plant = {
        id = "first_plant",
        name = "Green Thumb",
        description = "Plant your very first seed",
        icon = "🌱",
        badgeId = 2124000001, -- Replace with actual badge ID
        category = "planting",
        tier = 1,
        requirement = {type = "plants_grown", value = 1},
        rewards = {coins = 50, xp = 10},
        isSecret = false
    },
    
    plant_collector = {
        id = "plant_collector",
        name = "Plant Collector",
        description = "Grow 100 different plants",
        icon = "🌿",
        badgeId = 2124000002,
        category = "planting",
        tier = 3,
        requirement = {type = "plants_grown", value = 100},
        rewards = {coins = 1000, xp = 200},
        isSecret = false
    },
    
    master_gardener = {
        id = "master_gardener",
        name = "Master Gardener",
        description = "Grow 1,000 plants",
        icon = "🌳",
        badgeId = 2124000003,
        category = "planting",
        tier = 5,
        requirement = {type = "plants_grown", value = 1000},
        rewards = {coins = 10000, xp = 1000, special_plant = "rainbow_flower"},
        isSecret = false
    },
    
    -- Economy Achievements
    first_coin = {
        id = "first_coin",
        name = "First Earnings",
        description = "Earn your first coin",
        icon = "💰",
        badgeId = 2124000004,
        category = "economy",
        tier = 1,
        requirement = {type = "total_earnings", value = 1},
        rewards = {coins = 25, xp = 5},
        isSecret = false
    },
    
    millionaire = {
        id = "millionaire",
        name = "Millionaire",
        description = "Earn 1,000,000 total coins",
        icon = "💎",
        badgeId = 2124000005,
        category = "economy",
        tier = 4,
        requirement = {type = "total_earnings", value = 1000000},
        rewards = {coins = 50000, xp = 2500, title = "Millionaire"},
        isSecret = false
    },
    
    -- Progression Achievements
    level_up = {
        id = "level_up",
        name = "Rising Star",
        description = "Reach level 10",
        icon = "⭐",
        badgeId = 2124000006,
        category = "progression",
        tier = 2,
        requirement = {type = "level", value = 10},
        rewards = {coins = 500, xp = 100},
        isSecret = false
    },
    
    max_level = {
        id = "max_level",
        name = "Garden Master",
        description = "Reach the maximum level",
        icon = "👑",
        badgeId = 2124000007,
        category = "progression",
        tier = 5,
        requirement = {type = "level", value = 100},
        rewards = {coins = 100000, xp = 10000, title = "Garden Master"},
        isSecret = false
    },
    
    -- Social Achievements
    daily_streak_7 = {
        id = "daily_streak_7",
        name = "Dedicated Gardener",
        description = "Play for 7 consecutive days",
        icon = "🔥",
        badgeId = 2124000008,
        category = "social",
        tier = 2,
        requirement = {type = "daily_streak", value = 7},
        rewards = {coins = 1000, xp = 200},
        isSecret = false
    },
    
    daily_streak_30 = {
        id = "daily_streak_30",
        name = "Devoted Botanist",
        description = "Play for 30 consecutive days",
        icon = "🔥",
        badgeId = 2124000009,
        category = "social",
        tier = 4,
        requirement = {type = "daily_streak", value = 30},
        rewards = {coins = 10000, xp = 1000, title = "Devoted Botanist"},
        isSecret = false
    },
    
    -- VIP Exclusive Achievements
    vip_member = {
        id = "vip_member",
        name = "VIP Garden Club",
        description = "Join the exclusive VIP Garden Club",
        icon = "👑",
        badgeId = 2124000010,
        category = "vip",
        tier = 3,
        requirement = {type = "vip_status", value = true},
        rewards = {coins = 5000, xp = 500, exclusive_decoration = "golden_fountain"},
        isSecret = false,
        vipOnly = true
    },
    
    vip_supporter = {
        id = "vip_supporter",
        name = "Garden Patron",
        description = "Support the garden for 30 days as VIP",
        icon = "💎",
        badgeId = 2124000011,
        category = "vip",
        tier = 4,
        requirement = {type = "vip_days", value = 30},
        rewards = {coins = 25000, xp = 2000, title = "Garden Patron"},
        isSecret = false,
        vipOnly = true
    },
    
    -- Secret Achievements
    rainbow_harvest = {
        id = "rainbow_harvest",
        name = "Rainbow Harvest",
        description = "Harvest plants of all 7 rainbow colors in one session",
        icon = "🌈",
        badgeId = 2124000012,
        category = "secret",
        tier = 3,
        requirement = {type = "rainbow_colors", value = 7},
        rewards = {coins = 7777, xp = 777, special_plant = "rainbow_tree"},
        isSecret = true
    },
    
    midnight_gardener = {
        id = "midnight_gardener",
        name = "Midnight Gardener",
        description = "Plant a seed at exactly midnight",
        icon = "🌙",
        badgeId = 2124000013,
        category = "secret",
        tier = 2,
        requirement = {type = "midnight_plant", value = 1},
        rewards = {coins = 2000, xp = 300, decoration = "moon_lantern"},
        isSecret = true
    },
    
    -- Competitive Achievements
    leaderboard_top10 = {
        id = "leaderboard_top10",
        name = "Elite Gardener",
        description = "Reach top 10 in any leaderboard",
        icon = "🏆",
        badgeId = 2124000014,
        category = "competitive",
        tier = 4,
        requirement = {type = "leaderboard_rank", value = 10},
        rewards = {coins = 15000, xp = 1500, title = "Elite Gardener"},
        isSecret = false
    },
    
    leaderboard_first = {
        id = "leaderboard_first",
        name = "Garden Champion",
        description = "Reach #1 in any leaderboard",
        icon = "👑",
        badgeId = 2124000015,
        category = "competitive",
        tier = 5,
        requirement = {type = "leaderboard_rank", value = 1},
        rewards = {coins = 50000, xp = 5000, title = "Garden Champion", crown = "champion_crown"},
        isSecret = false
    }
}

-- ==========================================
-- STATE MANAGEMENT
-- ==========================================

AchievementSystem.PlayerAchievements = {}     -- [userId] = {achievement_id = unlock_data}
AchievementSystem.PlayerProgress = {}         -- [userId] = {stat_name = current_value}
AchievementSystem.PendingChecks = {}          -- Players needing achievement checks
AchievementSystem.RecentUnlocks = {}          -- Recent unlocks for notifications

-- ==========================================
-- INITIALIZATION
-- ==========================================

function AchievementSystem:Initialize()
    print("🏆 AchievementSystem: Initializing achievement system...")
    
    -- Set up remote events
    self:SetupRemoteEvents()
    
    -- Set up player tracking
    self:SetupPlayerTracking()
    
    -- Set up achievement checking
    self:SetupAchievementChecking()
    
    -- Load achievement data
    self:LoadAchievementData()
    
    print("✅ AchievementSystem: Achievement system initialized with", self:GetAchievementCount(), "achievements")
end

function AchievementSystem:SetupRemoteEvents()
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then
        remoteEvents = Instance.new("Folder")
        remoteEvents.Name = "RemoteEvents"
        remoteEvents.Parent = ReplicatedStorage
    end
    
    -- Get player achievements
    local getAchievementsFunction = Instance.new("RemoteFunction")
    getAchievementsFunction.Name = "GetPlayerAchievements"
    getAchievementsFunction.Parent = remoteEvents
    getAchievementsFunction.OnServerInvoke = function(player)
        return self:GetPlayerAchievements(player)
    end
    
    -- Get achievement progress
    local getProgressFunction = Instance.new("RemoteFunction")
    getProgressFunction.Name = "GetAchievementProgress"
    getProgressFunction.Parent = remoteEvents
    getProgressFunction.OnServerInvoke = function(player, achievementId)
        return self:GetAchievementProgress(player, achievementId)
    end
    
    -- Achievement unlock notification
    local achievementUnlockEvent = Instance.new("RemoteEvent")
    achievementUnlockEvent.Name = "AchievementUnlocked"
    achievementUnlockEvent.Parent = remoteEvents
    self.UnlockEvent = achievementUnlockEvent
    
    -- Progress update event
    local progressUpdateEvent = Instance.new("RemoteEvent")
    progressUpdateEvent.Name = "AchievementProgressUpdate"
    progressUpdateEvent.Parent = remoteEvents
    self.ProgressEvent = progressUpdateEvent
end

function AchievementSystem:SetupPlayerTracking()
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

function AchievementSystem:SetupAchievementChecking()
    -- Regular achievement checking
    spawn(function()
        while true do
            wait(10) -- Check every 10 seconds
            self:ProcessPendingChecks()
        end
    end)
    
    -- Progress saving
    spawn(function()
        while true do
            wait(300) -- Save every 5 minutes
            self:SaveAllPlayerProgress()
        end
    end)
end

function AchievementSystem:LoadAchievementData()
    -- Pre-validate all achievement definitions
    for achievementId, achievement in pairs(self.Achievements) do
        if not self:ValidateAchievement(achievement) then
            warn("⚠️ AchievementSystem: Invalid achievement definition:", achievementId)
        end
    end
end

-- ==========================================
-- PLAYER DATA MANAGEMENT
-- ==========================================

function AchievementSystem:OnPlayerJoined(player)
    local userId = player.UserId
    
    -- Initialize data structures
    self.PlayerAchievements[userId] = {}
    self.PlayerProgress[userId] = {}
    
    -- Load player data
    self:LoadPlayerAchievements(player)
    self:LoadPlayerProgress(player)
    
    -- Check initial achievements
    self:QueueAchievementCheck(player)
    
    print("🏆 AchievementSystem: Initialized achievement data for", player.Name)
end

function AchievementSystem:OnPlayerLeaving(player)
    -- Save player data
    self:SavePlayerAchievements(player)
    self:SavePlayerProgress(player)
    
    -- Clean up memory
    local userId = player.UserId
    self.PlayerAchievements[userId] = nil
    self.PlayerProgress[userId] = nil
    self.PendingChecks[userId] = nil
end

function AchievementSystem:LoadPlayerAchievements(player)
    local userId = player.UserId
    
    local success, achievementData = pcall(function()
        return self.DataStore:GetAsync("achievements_" .. userId)
    end)
    
    if success and achievementData then
        self.PlayerAchievements[userId] = achievementData
        print("🏆 AchievementSystem: Loaded", table.getn(achievementData or {}), "achievements for", player.Name)
    else
        self.PlayerAchievements[userId] = {}
        print("🏆 AchievementSystem: Starting fresh achievement data for", player.Name)
    end
end

function AchievementSystem:LoadPlayerProgress(player)
    local userId = player.UserId
    
    local success, progressData = pcall(function()
        return self.ProgressDataStore:GetAsync("progress_" .. userId)
    end)
    
    if success and progressData then
        self.PlayerProgress[userId] = progressData
    else
        self.PlayerProgress[userId] = {}
    end
end

function AchievementSystem:SavePlayerAchievements(player)
    local userId = player.UserId
    local achievementData = self.PlayerAchievements[userId]
    
    if not achievementData then return end
    
    local success, errorMessage = pcall(function()
        self.DataStore:SetAsync("achievements_" .. userId, achievementData)
    end)
    
    if not success then
        warn("⚠️ AchievementSystem: Failed to save achievements for", player.Name, "-", errorMessage)
    end
end

function AchievementSystem:SavePlayerProgress(player)
    local userId = player.UserId
    local progressData = self.PlayerProgress[userId]
    
    if not progressData then return end
    
    local success, errorMessage = pcall(function()
        self.ProgressDataStore:SetAsync("progress_" .. userId, progressData)
    end)
    
    if not success then
        warn("⚠️ AchievementSystem: Failed to save progress for", player.Name, "-", errorMessage)
    end
end

function AchievementSystem:SaveAllPlayerProgress()
    for _, player in pairs(Players:GetPlayers()) do
        self:SavePlayerProgress(player)
    end
end

-- ==========================================
-- PROGRESS TRACKING
-- ==========================================

function AchievementSystem:UpdatePlayerStat(player, statName, value, operation)
    operation = operation or "set" -- "set", "add", "max"
    
    local userId = player.UserId
    if not self.PlayerProgress[userId] then return end
    
    local currentValue = self.PlayerProgress[userId][statName] or 0
    local newValue = currentValue
    
    if operation == "set" then
        newValue = value
    elseif operation == "add" then
        newValue = currentValue + value
    elseif operation == "max" then
        newValue = math.max(currentValue, value)
    end
    
    -- Update the value
    self.PlayerProgress[userId][statName] = newValue
    
    -- Notify client of progress update
    if self.ProgressEvent then
        self.ProgressEvent:FireClient(player, statName, newValue, currentValue)
    end
    
    -- Queue achievement check
    self:QueueAchievementCheck(player)
    
    return newValue
end

function AchievementSystem:GetPlayerStat(player, statName)
    local userId = player.UserId
    if not self.PlayerProgress[userId] then return 0 end
    
    return self.PlayerProgress[userId][statName] or 0
end

function AchievementSystem:IncrementPlayerStat(player, statName, amount)
    amount = amount or 1
    return self:UpdatePlayerStat(player, statName, amount, "add")
end

function AchievementSystem:SetPlayerStat(player, statName, value)
    return self:UpdatePlayerStat(player, statName, value, "set")
end

function AchievementSystem:MaxPlayerStat(player, statName, value)
    return self:UpdatePlayerStat(player, statName, value, "max")
end

-- ==========================================
-- ACHIEVEMENT CHECKING
-- ==========================================

function AchievementSystem:QueueAchievementCheck(player)
    local userId = player.UserId
    self.PendingChecks[userId] = {
        player = player,
        timestamp = tick()
    }
end

function AchievementSystem:ProcessPendingChecks()
    local currentTime = tick()
    local processedCount = 0
    
    for userId, checkData in pairs(self.PendingChecks) do
        -- Process checks that are at least 5 seconds old to batch updates
        if currentTime - checkData.timestamp >= 5 then
            if checkData.player and checkData.player.Parent then
                self:CheckPlayerAchievements(checkData.player)
                processedCount = processedCount + 1
            end
            
            self.PendingChecks[userId] = nil
            
            -- Limit processing per batch
            if processedCount >= 5 then
                break
            end
        end
    end
end

function AchievementSystem:CheckPlayerAchievements(player)
    local userId = player.UserId
    local unlockedAchievements = {}
    
    for achievementId, achievement in pairs(self.Achievements) do
        if not self:HasAchievement(player, achievementId) then
            if self:CheckAchievementRequirement(player, achievement) then
                self:UnlockAchievement(player, achievementId)
                table.insert(unlockedAchievements, achievementId)
            end
        end
    end
    
    if #unlockedAchievements > 0 then
        print("🏆 AchievementSystem:", player.Name, "unlocked", #unlockedAchievements, "achievements")
    end
    
    return unlockedAchievements
end

function AchievementSystem:CheckAchievementRequirement(player, achievement)
    local requirement = achievement.requirement
    if not requirement then return false end
    
    -- Check VIP-only achievements
    if achievement.vipOnly then
        local vipManager = _G.VIPManager
        if not vipManager or not vipManager:IsPlayerVIP(player) then
            return false
        end
    end
    
    local requirementType = requirement.type
    local requiredValue = requirement.value
    
    if requirementType == "plants_grown" then
        return self:GetPlayerStat(player, "totalPlantsGrown") >= requiredValue
        
    elseif requirementType == "total_earnings" then
        return self:GetPlayerStat(player, "totalEarnings") >= requiredValue
        
    elseif requirementType == "level" then
        return self:GetPlayerStat(player, "level") >= requiredValue
        
    elseif requirementType == "daily_streak" then
        return self:GetPlayerStat(player, "dailyStreak") >= requiredValue
        
    elseif requirementType == "vip_status" then
        local vipManager = _G.VIPManager
        return vipManager and vipManager:IsPlayerVIP(player)
        
    elseif requirementType == "vip_days" then
        return self:GetPlayerStat(player, "vipDays") >= requiredValue
        
    elseif requirementType == "rainbow_colors" then
        return self:GetPlayerStat(player, "rainbowColorsHarvested") >= requiredValue
        
    elseif requirementType == "midnight_plant" then
        return self:GetPlayerStat(player, "midnightPlants") >= requiredValue
        
    elseif requirementType == "leaderboard_rank" then
        return self:CheckLeaderboardRank(player, requiredValue)
    end
    
    return false
end

function AchievementSystem:CheckLeaderboardRank(player, maxRank)
    local leaderboardManager = _G.LeaderboardManager
    if not leaderboardManager then return false end
    
    -- Check all leaderboard categories
    for categoryId, _ in pairs(leaderboardManager.Categories) do
        local rankData = leaderboardManager:GetPlayerRank(player.UserId, categoryId)
        if rankData and rankData.rank <= maxRank then
            return true
        end
    end
    
    return false
end

-- ==========================================
-- ACHIEVEMENT UNLOCKING
-- ==========================================

function AchievementSystem:UnlockAchievement(player, achievementId)
    local achievement = self.Achievements[achievementId]
    if not achievement then
        warn("⚠️ AchievementSystem: Attempted to unlock invalid achievement:", achievementId)
        return false
    end
    
    local userId = player.UserId
    
    -- Check if already unlocked
    if self:HasAchievement(player, achievementId) then
        return false
    end
    
    -- Create unlock data
    local unlockData = {
        achievementId = achievementId,
        unlockedAt = tick(),
        playerLevel = self:GetPlayerStat(player, "level"),
        isNew = true
    }
    
    -- Store the unlock
    self.PlayerAchievements[userId][achievementId] = unlockData
    
    -- Award Roblox badge if available
    self:AwardBadge(player, achievement.badgeId)
    
    -- Give rewards
    self:GiveAchievementRewards(player, achievement)
    
    -- Notify client
    self:NotifyAchievementUnlock(player, achievement)
    
    -- Track for analytics
    self:TrackAchievementUnlock(player, achievement)
    
    print("🏆 AchievementSystem:", player.Name, "unlocked achievement:", achievement.name)
    
    return true
end

function AchievementSystem:AwardBadge(player, badgeId)
    if not badgeId then return end
    
    local success, errorMessage = pcall(function()
        BadgeService:AwardBadge(player.UserId, badgeId)
    end)
    
    if not success then
        warn("⚠️ AchievementSystem: Failed to award badge", badgeId, "to", player.Name, "-", errorMessage)
    end
end

function AchievementSystem:GiveAchievementRewards(player, achievement)
    local rewards = achievement.rewards
    if not rewards then return end
    
    -- Give coin rewards
    if rewards.coins then
        local economyManager = _G.EconomyManager
        if economyManager then
            economyManager:AddCoins(player, rewards.coins, "achievement_" .. achievement.id)
        end
    end
    
    -- Give XP rewards
    if rewards.xp then
        local progressionManager = _G.ProgressionManager
        if progressionManager then
            progressionManager:AddExperience(player, rewards.xp, "achievement_" .. achievement.id)
        end
    end
    
    -- Give special items
    if rewards.special_plant then
        local inventoryManager = _G.InventoryManager
        if inventoryManager then
            inventoryManager:AddItem(player, "plant", rewards.special_plant, 1)
        end
    end
    
    if rewards.decoration then
        local inventoryManager = _G.InventoryManager
        if inventoryManager then
            inventoryManager:AddItem(player, "decoration", rewards.decoration, 1)
        end
    end
    
    if rewards.title then
        self:GivePlayerTitle(player, rewards.title)
    end
    
    print("🎁 AchievementSystem: Gave rewards to", player.Name, "for achievement", achievement.id)
end

function AchievementSystem:GivePlayerTitle(player, title)
    -- This would integrate with a title system
    local titleManager = _G.TitleManager
    if titleManager then
        titleManager:UnlockTitle(player, title)
    end
end

function AchievementSystem:NotifyAchievementUnlock(player, achievement)
    if self.UnlockEvent then
        self.UnlockEvent:FireClient(player, {
            id = achievement.id,
            name = achievement.name,
            description = achievement.description,
            icon = achievement.icon,
            tier = achievement.tier,
            rewards = achievement.rewards,
            isSecret = achievement.isSecret
        })
    end
    
    -- Store for recent unlocks
    local userId = player.UserId
    if not self.RecentUnlocks[userId] then
        self.RecentUnlocks[userId] = {}
    end
    
    table.insert(self.RecentUnlocks[userId], {
        achievement = achievement,
        timestamp = tick()
    })
end

function AchievementSystem:TrackAchievementUnlock(player, achievement)
    -- This would integrate with analytics
    print("📊 AchievementSystem: Player", player.Name, "unlocked", achievement.name, "(Tier", achievement.tier .. ")")
end

-- ==========================================
-- DATA RETRIEVAL
-- ==========================================

function AchievementSystem:HasAchievement(player, achievementId)
    local userId = player.UserId
    if not self.PlayerAchievements[userId] then return false end
    
    return self.PlayerAchievements[userId][achievementId] ~= nil
end

function AchievementSystem:GetPlayerAchievements(player)
    local userId = player.UserId
    local playerAchievements = self.PlayerAchievements[userId] or {}
    
    local result = {
        unlocked = {},
        progress = {},
        total = self:GetAchievementCount(),
        unlockedCount = 0
    }
    
    -- Add unlocked achievements
    for achievementId, unlockData in pairs(playerAchievements) do
        local achievement = self.Achievements[achievementId]
        if achievement then
            table.insert(result.unlocked, {
                id = achievementId,
                name = achievement.name,
                description = achievement.description,
                icon = achievement.icon,
                tier = achievement.tier,
                category = achievement.category,
                unlockedAt = unlockData.unlockedAt,
                rewards = achievement.rewards
            })
            result.unlockedCount = result.unlockedCount + 1
        end
    end
    
    -- Add progress for locked achievements
    for achievementId, achievement in pairs(self.Achievements) do
        if not playerAchievements[achievementId] then
            -- Don't show secret achievements until unlocked
            if not achievement.isSecret then
                local progress = self:GetAchievementProgress(player, achievementId)
                result.progress[achievementId] = {
                    id = achievementId,
                    name = achievement.name,
                    description = achievement.description,
                    icon = achievement.icon,
                    tier = achievement.tier,
                    category = achievement.category,
                    progress = progress.current,
                    required = progress.required,
                    percentage = progress.percentage
                }
            end
        end
    end
    
    return result
end

function AchievementSystem:GetAchievementProgress(player, achievementId)
    local achievement = self.Achievements[achievementId]
    if not achievement or not achievement.requirement then
        return {current = 0, required = 1, percentage = 0}
    end
    
    local requirement = achievement.requirement
    local currentValue = 0
    local requiredValue = requirement.value
    
    if requirement.type == "plants_grown" then
        currentValue = self:GetPlayerStat(player, "totalPlantsGrown")
    elseif requirement.type == "total_earnings" then
        currentValue = self:GetPlayerStat(player, "totalEarnings")
    elseif requirement.type == "level" then
        currentValue = self:GetPlayerStat(player, "level")
    elseif requirement.type == "daily_streak" then
        currentValue = self:GetPlayerStat(player, "dailyStreak")
    elseif requirement.type == "vip_days" then
        currentValue = self:GetPlayerStat(player, "vipDays")
    elseif requirement.type == "rainbow_colors" then
        currentValue = self:GetPlayerStat(player, "rainbowColorsHarvested")
    elseif requirement.type == "midnight_plants" then
        currentValue = self:GetPlayerStat(player, "midnightPlants")
    end
    
    local percentage = math.min(100, (currentValue / requiredValue) * 100)
    
    return {
        current = currentValue,
        required = requiredValue,
        percentage = percentage
    }
end

function AchievementSystem:GetPlayerAchievementCount(player)
    local userId = player.UserId
    if not self.PlayerAchievements[userId] then return 0 end
    
    local count = 0
    for _, _ in pairs(self.PlayerAchievements[userId]) do
        count = count + 1
    end
    
    return count
end

function AchievementSystem:GetAchievementsByCategory(category)
    local categoryAchievements = {}
    
    for achievementId, achievement in pairs(self.Achievements) do
        if achievement.category == category then
            table.insert(categoryAchievements, achievement)
        end
    end
    
    -- Sort by tier
    table.sort(categoryAchievements, function(a, b)
        return a.tier < b.tier
    end)
    
    return categoryAchievements
end

function AchievementSystem:GetRecentUnlocks(player, limit)
    limit = limit or 5
    
    local userId = player.UserId
    local recentUnlocks = self.RecentUnlocks[userId] or {}
    
    -- Sort by timestamp (newest first)
    table.sort(recentUnlocks, function(a, b)
        return a.timestamp > b.timestamp
    end)
    
    -- Return limited list
    local result = {}
    for i = 1, math.min(limit, #recentUnlocks) do
        table.insert(result, recentUnlocks[i])
    end
    
    return result
end

-- ==========================================
-- ACHIEVEMENT MANAGEMENT
-- ==========================================

function AchievementSystem:ValidateAchievement(achievement)
    if not achievement.id or not achievement.name or not achievement.description then
        return false
    end
    
    if not achievement.requirement or not achievement.requirement.type then
        return false
    end
    
    if not achievement.tier or achievement.tier < 1 or achievement.tier > 5 then
        return false
    end
    
    return true
end

function AchievementSystem:GetAchievementCount()
    local count = 0
    for _, _ in pairs(self.Achievements) do
        count = count + 1
    end
    return count
end

function AchievementSystem:GetAchievementById(achievementId)
    return self.Achievements[achievementId]
end

function AchievementSystem:AddCustomAchievement(achievementData)
    if self:ValidateAchievement(achievementData) then
        self.Achievements[achievementData.id] = achievementData
        return true
    end
    return false
end

-- ==========================================
-- STATISTICS & ANALYTICS
-- ==========================================

function AchievementSystem:GetSystemStats()
    local stats = {
        totalAchievements = self:GetAchievementCount(),
        totalPlayers = 0,
        totalUnlocks = 0,
        averageAchievementsPerPlayer = 0,
        categoryBreakdown = {}
    }
    
    -- Count categories
    for _, achievement in pairs(self.Achievements) do
        local category = achievement.category
        if not stats.categoryBreakdown[category] then
            stats.categoryBreakdown[category] = 0
        end
        stats.categoryBreakdown[category] = stats.categoryBreakdown[category] + 1
    end
    
    -- Count player achievements
    for userId, achievements in pairs(self.PlayerAchievements) do
        stats.totalPlayers = stats.totalPlayers + 1
        for _, _ in pairs(achievements) do
            stats.totalUnlocks = stats.totalUnlocks + 1
        end
    end
    
    if stats.totalPlayers > 0 then
        stats.averageAchievementsPerPlayer = stats.totalUnlocks / stats.totalPlayers
    end
    
    return stats
end

function AchievementSystem:GetAchievementStats(achievementId)
    local achievement = self.Achievements[achievementId]
    if not achievement then return nil end
    
    local unlockCount = 0
    local totalPlayers = 0
    
    for userId, achievements in pairs(self.PlayerAchievements) do
        totalPlayers = totalPlayers + 1
        if achievements[achievementId] then
            unlockCount = unlockCount + 1
        end
    end
    
    local unlockRate = 0
    if totalPlayers > 0 then
        unlockRate = (unlockCount / totalPlayers) * 100
    end
    
    return {
        achievement = achievement,
        unlockCount = unlockCount,
        totalPlayers = totalPlayers,
        unlockRate = unlockRate
    }
end

-- ==========================================
-- SPECIAL EVENTS
-- ==========================================

function AchievementSystem:TriggerSpecialEvent(eventType, data)
    if eventType == "rainbow_harvest" then
        self:HandleRainbowHarvest(data.player, data.colors)
    elseif eventType == "midnight_plant" then
        self:HandleMidnightPlant(data.player)
    end
end

function AchievementSystem:HandleRainbowHarvest(player, colorsHarvested)
    if #colorsHarvested >= 7 then
        self:IncrementPlayerStat(player, "rainbowColorsHarvested", 7)
    end
end

function AchievementSystem:HandleMidnightPlant(player)
    local currentTime = os.date("*t")
    if currentTime.hour == 0 and currentTime.min == 0 then
        self:IncrementPlayerStat(player, "midnightPlants", 1)
    end
end

-- ==========================================
-- PUBLIC API
-- ==========================================

function AchievementSystem:ForceCheckAchievements(player)
    return self:CheckPlayerAchievements(player)
end

function AchievementSystem:DebugPlayerData(player)
    local userId = player.UserId
    print("🏆 Achievement Debug for", player.Name, ":")
    print("  Achievements:", self.PlayerAchievements[userId])
    print("  Progress:", self.PlayerProgress[userId])
end

-- ==========================================
-- CLEANUP
-- ==========================================

function AchievementSystem:Cleanup()
    -- Save all player data
    for _, player in pairs(Players:GetPlayers()) do
        self:SavePlayerAchievements(player)
        self:SavePlayerProgress(player)
    end
    
    print("🏆 AchievementSystem: Cleaned up and saved all data")
end

-- ==========================================
-- GLOBAL REGISTRATION
-- ==========================================

_G.AchievementSystem = AchievementSystem

return AchievementSystem
