--[[
    ProgressionManager.lua
    Player Progression & Level System
    
    Priority: 7 (Core progression module)
    Dependencies: ConfigModule, VIPManager
    Used by: HarvestHandler, QuestHandler, DailyBonusManager
    
    Features:
    - XP and level management
    - Plant unlock system
    - Level-based rewards
    - Progression tracking
    - VIP progression bonuses
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)

local ProgressionManager = {}
ProgressionManager.__index = ProgressionManager

-- ==========================================
-- PROGRESSION DATA STORAGE
-- ==========================================

ProgressionManager.PlayerXP = {}         -- [userId] = currentXP
ProgressionManager.PlayerLevels = {}     -- [userId] = currentLevel
ProgressionManager.LevelUpHistory = {}   -- [userId] = {levelUpEvents}
ProgressionManager.UnlockedPlants = {}   -- [userId] = {plantTypes}

-- ==========================================
-- INITIALIZATION
-- ==========================================

function ProgressionManager:Initialize()
    print("📈 ProgressionManager: Initializing progression system...")
    
    -- Set up player events
    self:SetupPlayerEvents()
    
    print("✅ ProgressionManager: Progression system initialized successfully")
end

function ProgressionManager:SetupPlayerEvents()
    Players.PlayerAdded:Connect(function(player)
        self:OnPlayerJoined(player)
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        self:OnPlayerLeaving(player)
    end)
end

function ProgressionManager:OnPlayerJoined(player)
    local userId = player.UserId
    
    -- Initialize player progression data
    self.PlayerXP[userId] = ConfigModule.Economy.STARTING_XP
    self.PlayerLevels[userId] = ConfigModule.Economy.STARTING_LEVEL
    self.LevelUpHistory[userId] = {}
    
    -- Initialize unlocked plants based on starting level
    self:InitializeUnlockedPlants(player)
    
    print("📈 ProgressionManager:", player.Name, "joined at level", self.PlayerLevels[userId], "with", self.PlayerXP[userId], "XP")
end

function ProgressionManager:OnPlayerLeaving(player)
    local userId = player.UserId
    
    -- Clear progression data (will be saved to DataStore)
    self.PlayerXP[userId] = nil
    self.PlayerLevels[userId] = nil
    self.LevelUpHistory[userId] = nil
    self.UnlockedPlants[userId] = nil
    
    print("📈 ProgressionManager:", player.Name, "left the game")
end

-- ==========================================
-- XP MANAGEMENT
-- ==========================================

function ProgressionManager:GetPlayerXP(player)
    local userId = self:GetUserId(player)
    return self.PlayerXP[userId] or 0
end

function ProgressionManager:GetPlayerLevel(player)
    local userId = self:GetUserId(player)
    return self.PlayerLevels[userId] or 1
end

function ProgressionManager:AddXP(player, amount, reason)
    if amount <= 0 then
        warn("❌ ProgressionManager: Cannot add negative or zero XP")
        return false
    end
    
    local userId = self:GetUserId(player)
    local currentXP = self.PlayerXP[userId] or 0
    local currentLevel = self.PlayerLevels[userId] or 1
    
    -- Apply VIP XP bonus
    local VIPManager = self:GetVIPManager()
    if VIPManager and VIPManager:IsPlayerVIP(player) then
        amount = math.floor(amount * 1.1) -- 10% XP bonus for VIP
    end
    
    -- Add XP
    local newXP = currentXP + amount
    self.PlayerXP[userId] = newXP
    
    -- Check for level up
    local newLevel = self:CalculateLevelFromXP(newXP)
    if newLevel > currentLevel then
        self:LevelUpPlayer(player, newLevel)
    end
    
    print("📈 ProgressionManager:", self:GetPlayerName(player), "gained", amount, "XP (Total:", newXP, ") -", reason or "Unknown")
    return true
end

function ProgressionManager:SetPlayerXP(player, amount)
    local userId = self:GetUserId(player)
    
    -- Validate amount
    amount = math.max(0, math.floor(amount))
    
    local oldXP = self.PlayerXP[userId] or 0
    self.PlayerXP[userId] = amount
    
    -- Recalculate level
    local newLevel = self:CalculateLevelFromXP(amount)
    local oldLevel = self.PlayerLevels[userId] or 1
    
    if newLevel ~= oldLevel then
        self:SetPlayerLevel(player, newLevel)
    end
    
    print("📈 ProgressionManager: Set", self:GetPlayerName(player), "XP to", amount)
    return amount
end

-- ==========================================
-- LEVEL MANAGEMENT
-- ==========================================

function ProgressionManager:CalculateLevelFromXP(totalXP)
    -- Calculate level based on total XP
    for level = 1, 10 do
        local xpRequired = ConfigModule:GetXPRequiredForLevel(level)
        if totalXP < xpRequired then
            return level - 1
        end
    end
    
    -- For levels beyond 10, use formula: level * 1000 XP
    local level = math.floor(totalXP / 1000) + 1
    return math.max(1, level)
end

function ProgressionManager:GetXPRequiredForNextLevel(player)
    local currentLevel = self:GetPlayerLevel(player)
    local nextLevel = currentLevel + 1
    local currentXP = self:GetPlayerXP(player)
    
    local xpRequiredForNext = ConfigModule:GetXPRequiredForLevel(nextLevel)
    local xpProgress = currentXP
    
    if currentLevel > 1 then
        local xpRequiredForCurrent = ConfigModule:GetXPRequiredForLevel(currentLevel)
        xpProgress = currentXP - xpRequiredForCurrent
        xpRequiredForNext = xpRequiredForNext - xpRequiredForCurrent
    end
    
    return {
        current = xpProgress,
        required = xpRequiredForNext,
        percentage = (xpProgress / xpRequiredForNext) * 100
    }
end

function ProgressionManager:LevelUpPlayer(player, newLevel)
    local userId = self:GetUserId(player)
    local oldLevel = self.PlayerLevels[userId] or 1
    
    -- Update level
    self.PlayerLevels[userId] = newLevel
    
    -- Record level up event
    local levelUpEvent = {
        oldLevel = oldLevel,
        newLevel = newLevel,
        timestamp = os.time()
    }
    table.insert(self.LevelUpHistory[userId], levelUpEvent)
    
    -- Process level up rewards
    local rewards = self:ProcessLevelUpRewards(player, newLevel)
    
    -- Notify about level up
    self:NotifyLevelUp(player, newLevel, rewards)
    
    print("🎉 ProgressionManager:", self:GetPlayerName(player), "leveled up from", oldLevel, "to", newLevel)
    
    return rewards
end

function ProgressionManager:SetPlayerLevel(player, level)
    local userId = self:GetUserId(player)
    
    -- Validate level
    level = math.max(1, level)
    
    local oldLevel = self.PlayerLevels[userId] or 1
    self.PlayerLevels[userId] = level
    
    -- Update unlocked plants
    self:UpdateUnlockedPlants(player, level)
    
    print("📈 ProgressionManager: Set", self:GetPlayerName(player), "level to", level)
    return level
end

-- ==========================================
-- LEVEL UP REWARDS
-- ==========================================

function ProgressionManager:ProcessLevelUpRewards(player, newLevel)
    local rewards = {
        coins = 0,
        plants = {},
        features = {}
    }
    
    -- Check for unlocks at this level
    local unlocks = ConfigModule.Progression.LEVEL_UNLOCKS[newLevel]
    if unlocks then
        for _, unlock in ipairs(unlocks) do
            if ConfigModule.Plants[unlock] then
                -- Plant unlock
                table.insert(rewards.plants, unlock)
                self:UnlockPlant(player, unlock)
            else
                -- Feature unlock
                table.insert(rewards.features, unlock)
                self:UnlockFeature(player, unlock)
            end
        end
    end
    
    -- Base level up coin reward
    local coinReward = newLevel * 50 -- 50 coins per level
    rewards.coins = coinReward
    
    -- Give coin reward
    local EconomyManager = self:GetEconomyManager()
    if EconomyManager then
        EconomyManager:AddCoins(player, coinReward, "Level Up Reward")
    end
    
    return rewards
end

function ProgressionManager:NotifyLevelUp(player, newLevel, rewards)
    print("🎉 ProgressionManager: LEVEL UP NOTIFICATION for", player.Name)
    print("   New Level:", newLevel)
    print("   Coin Reward:", rewards.coins)
    
    if #rewards.plants > 0 then
        print("   Unlocked Plants:", table.concat(rewards.plants, ", "))
    end
    
    if #rewards.features > 0 then
        print("   Unlocked Features:", table.concat(rewards.features, ", "))
    end
    
    -- This could trigger a UI notification in the future
    -- For now, just print to console
end

-- ==========================================
-- PLANT UNLOCK SYSTEM
-- ==========================================

function ProgressionManager:InitializeUnlockedPlants(player)
    local userId = self:GetUserId(player)
    local currentLevel = self:GetPlayerLevel(player)
    
    self.UnlockedPlants[userId] = {}
    
    -- Unlock plants based on current level
    for plantName, plantData in pairs(ConfigModule.Plants) do
        if plantData.unlockLevel <= currentLevel then
            table.insert(self.UnlockedPlants[userId], plantName)
        end
    end
    
    print("🌱 ProgressionManager:", self:GetPlayerName(player), "has", #self.UnlockedPlants[userId], "plants unlocked")
end

function ProgressionManager:UpdateUnlockedPlants(player, newLevel)
    local userId = self:GetUserId(player)
    
    if not self.UnlockedPlants[userId] then
        self.UnlockedPlants[userId] = {}
    end
    
    -- Check for new plant unlocks
    for plantName, plantData in pairs(ConfigModule.Plants) do
        if plantData.unlockLevel <= newLevel then
            if not table.find(self.UnlockedPlants[userId], plantName) then
                table.insert(self.UnlockedPlants[userId], plantName)
                print("🌱 ProgressionManager:", self:GetPlayerName(player), "unlocked", plantName, "!")
            end
        end
    end
end

function ProgressionManager:UnlockPlant(player, plantName)
    local userId = self:GetUserId(player)
    
    if not self.UnlockedPlants[userId] then
        self.UnlockedPlants[userId] = {}
    end
    
    if not table.find(self.UnlockedPlants[userId], plantName) then
        table.insert(self.UnlockedPlants[userId], plantName)
        print("🌱 ProgressionManager:", self:GetPlayerName(player), "unlocked", plantName, "!")
        return true
    end
    
    return false
end

function ProgressionManager:IsPlantUnlocked(player, plantName)
    local userId = self:GetUserId(player)
    local unlockedPlants = self.UnlockedPlants[userId] or {}
    return table.find(unlockedPlants, plantName) ~= nil
end

function ProgressionManager:GetUnlockedPlants(player)
    local userId = self:GetUserId(player)
    return self.UnlockedPlants[userId] or {}
end

function ProgressionManager:GetLockedPlants(player)
    local userId = self:GetUserId(player)
    local unlockedPlants = self.UnlockedPlants[userId] or {}
    local lockedPlants = {}
    
    for plantName, plantData in pairs(ConfigModule.Plants) do
        if not table.find(unlockedPlants, plantName) then
            table.insert(lockedPlants, {
                name = plantName,
                unlockLevel = plantData.unlockLevel
            })
        end
    end
    
    return lockedPlants
end

-- ==========================================
-- FEATURE UNLOCKS
-- ==========================================

function ProgressionManager:UnlockFeature(player, featureName)
    print("🔓 ProgressionManager:", self:GetPlayerName(player), "unlocked feature:", featureName)
    
    if featureName == "ExtraPlot" then
        -- Expand player plots
        local PlotManager = self:GetPlotManager()
        if PlotManager then
            PlotManager:ExpandPlayerPlots(player)
        end
    elseif featureName == "VIPDiscount" then
        -- Could trigger a VIP discount notification
        print("💎 ProgressionManager:", player.Name, "unlocked VIP discount!")
    end
end

-- ==========================================
-- PROGRESSION STATISTICS
-- ==========================================

function ProgressionManager:GetPlayerProgressionStats(player)
    local userId = self:GetUserId(player)
    local currentXP = self:GetPlayerXP(player)
    local currentLevel = self:GetPlayerLevel(player)
    local nextLevelProgress = self:GetXPRequiredForNextLevel(player)
    
    return {
        currentXP = currentXP,
        currentLevel = currentLevel,
        nextLevelProgress = nextLevelProgress,
        unlockedPlants = #(self.UnlockedPlants[userId] or {}),
        totalPlants = self:GetTotalPlantCount(),
        levelUpHistory = #(self.LevelUpHistory[userId] or {})
    }
end

function ProgressionManager:GetTotalPlantCount()
    local count = 0
    for plantName, plantData in pairs(ConfigModule.Plants) do
        count = count + 1
    end
    return count
end

function ProgressionManager:GetProgressionLeaderboard(limit)
    limit = limit or 10
    
    local playerProgression = {}
    
    -- Collect all player progression data
    for userId, level in pairs(self.PlayerLevels) do
        local player = Players:GetPlayerByUserId(userId)
        if player then
            table.insert(playerProgression, {
                name = player.Name,
                level = level,
                xp = self.PlayerXP[userId] or 0
            })
        end
    end
    
    -- Sort by level, then by XP
    table.sort(playerProgression, function(a, b)
        if a.level == b.level then
            return a.xp > b.xp
        end
        return a.level > b.level
    end)
    
    -- Return top players
    local leaderboard = {}
    for i = 1, math.min(limit, #playerProgression) do
        table.insert(leaderboard, playerProgression[i])
    end
    
    return leaderboard
end

-- ==========================================
-- UTILITY FUNCTIONS
-- ==========================================

function ProgressionManager:GetUserId(player)
    if type(player) == "number" then
        return player
    elseif player and player.UserId then
        return player.UserId
    else
        error("Invalid player input to ProgressionManager")
    end
end

function ProgressionManager:GetPlayerName(player)
    if type(player) == "number" then
        local playerObj = Players:GetPlayerByUserId(player)
        return playerObj and playerObj.Name or "Unknown"
    elseif player and player.Name then
        return player.Name
    else
        return "Unknown"
    end
end

function ProgressionManager:GetVIPManager()
    -- Safely get VIPManager to avoid circular dependency
    local success, VIPManager = pcall(function()
        return require(game.ServerStorage.Modules.VIPManager)
    end)
    return success and VIPManager or nil
end

function ProgressionManager:GetEconomyManager()
    -- Safely get EconomyManager to avoid circular dependency
    local success, EconomyManager = pcall(function()
        return require(game.ServerStorage.Modules.EconomyManager)
    end)
    return success and EconomyManager or nil
end

function ProgressionManager:GetPlotManager()
    -- Safely get PlotManager to avoid circular dependency
    local success, PlotManager = pcall(function()
        return require(game.ServerStorage.Modules.PlotManager)
    end)
    return success and PlotManager or nil
end

-- ==========================================
-- ADMIN & DEBUG FUNCTIONS
-- ==========================================

function ProgressionManager:AdminSetLevel(player, level)
    -- Admin command to set player level
    local requiredXP = ConfigModule:GetXPRequiredForLevel(level)
    self:SetPlayerXP(player, requiredXP)
    
    print("🔧 ProgressionManager: Admin set", self:GetPlayerName(player), "to level", level)
end

function ProgressionManager:AdminAddXP(player, amount)
    -- Admin command to give XP without validation
    local userId = self:GetUserId(player)
    local currentXP = self.PlayerXP[userId] or 0
    self:SetPlayerXP(player, currentXP + amount)
    
    print("🔧 ProgressionManager: Admin gave", amount, "XP to", self:GetPlayerName(player))
end

function ProgressionManager:PrintProgressionDebugInfo()
    local totalPlayers = 0
    local totalLevels = 0
    local highestLevel = 0
    
    for userId, level in pairs(self.PlayerLevels) do
        totalPlayers = totalPlayers + 1
        totalLevels = totalLevels + level
        highestLevel = math.max(highestLevel, level)
    end
    
    local averageLevel = totalPlayers > 0 and (totalLevels / totalPlayers) or 0
    
    print("🐛 ProgressionManager Debug Info:")
    print("   Total players with progression:", totalPlayers)
    print("   Average level:", string.format("%.1f", averageLevel))
    print("   Highest level:", highestLevel)
    print("   Total plant types:", self:GetTotalPlantCount())
    
    local leaderboard = self:GetProgressionLeaderboard(3)
    print("   Top 3 players:")
    for i, player in ipairs(leaderboard) do
        print("     " .. i .. ".", player.name, "- Level", player.level, "(" .. player.xp .. " XP)")
    end
end

return ProgressionManager
