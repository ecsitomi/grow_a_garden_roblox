--[[
    DailyBonusManager.lua
    Server-Side Daily Login Rewards System
    
    Priority: 16 (VIP & Monetization phase)
    Dependencies: VIPManager, EconomyManager, ProgressionManager
    Used by: Player login events, UI reward displays
    
    Features:
    - Daily login streak tracking
    - Escalating rewards for consecutive days
    - VIP 3x multiplier for all rewards
    - Weekly bonus on day 7
    - Monthly special rewards
    - Offline time compensation
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

-- Load required modules
local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)
local VIPManager = require(ServerStorage.Modules.VIPManager)
local EconomyManager = require(ServerStorage.Modules.EconomyManager)
local ProgressionManager = require(ServerStorage.Modules.ProgressionManager)

local DailyBonusManager = {}
DailyBonusManager.__index = DailyBonusManager

-- ==========================================
-- DATA STORAGE & CONFIGURATION
-- ==========================================

DailyBonusManager.PlayerBonusData = {}     -- [userId] = {streak, lastClaim, totalClaimed}
DailyBonusManager.DailyBonusDataStore = nil

-- Daily Bonus Configuration
DailyBonusManager.DailyRewards = {
    -- Regular player rewards (base)
    regular = {
        [1] = {coins = 50, xp = 10},      -- Day 1
        [2] = {coins = 75, xp = 15},      -- Day 2  
        [3] = {coins = 100, xp = 20},     -- Day 3
        [4] = {coins = 125, xp = 25},     -- Day 4
        [5] = {coins = 150, xp = 30},     -- Day 5
        [6] = {coins = 200, xp = 40},     -- Day 6
        [7] = {coins = 500, xp = 100}     -- Day 7 (Weekly Bonus)
    },
    
    -- VIP rewards (3x multiplier + special items)
    vip_multiplier = 3,
    
    -- Special milestone rewards
    milestones = {
        [30] = {coins = 2000, xp = 500, special = "Golden Seed Pack"},   -- 30 days
        [60] = {coins = 5000, xp = 1000, special = "VIP Plot Expansion"}, -- 60 days
        [90] = {coins = 10000, xp = 2000, special = "Legendary Plant"}    -- 90 days
    }
}

-- Bonus Configuration
DailyBonusManager.StreakResetHours = 36     -- Hours before streak resets
DailyBonusManager.ClaimCooldownHours = 20   -- Minimum hours between claims
DailyBonusManager.MaxStreakDays = 365       -- Maximum streak tracking

-- ==========================================
-- INITIALIZATION
-- ==========================================

function DailyBonusManager:Initialize()
    print("🎁 DailyBonusManager: Initializing daily bonus system...")
    
    -- Initialize DataStore
    self:InitializeDataStore()
    
    -- Set up player tracking
    self:SetupPlayerTracking()
    
    -- Set up automatic reset checking
    self:SetupStreakResetSystem()
    
    -- Set up RemoteEvent handlers
    self:SetupRemoteEvents()
    
    print("✅ DailyBonusManager: Daily bonus system initialized successfully")
end

function DailyBonusManager:InitializeDataStore()
    local success, result = pcall(function()
        self.DailyBonusDataStore = DataStoreService:GetDataStore("DailyBonusData_v1")
    end)
    
    if success then
        print("💾 DailyBonusManager: DataStore connected successfully")
    else
        warn("❌ DailyBonusManager: Failed to connect to DataStore:", result)
        -- Continue without DataStore (data won't persist)
    end
end

function DailyBonusManager:SetupPlayerTracking()
    -- Track player joining
    Players.PlayerAdded:Connect(function(player)
        self:LoadPlayerBonusData(player)
    end)
    
    -- Track player leaving  
    Players.PlayerRemoving:Connect(function(player)
        self:SavePlayerBonusData(player)
    end)
    
    -- Initialize existing players
    for _, player in pairs(Players:GetPlayers()) do
        self:LoadPlayerBonusData(player)
    end
end

function DailyBonusManager:SetupRemoteEvents()
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then
        warn("❌ DailyBonusManager: RemoteEvents folder not found")
        return
    end
    
    -- Handle daily bonus claim requests
    local claimDailyBonusEvent = remoteEvents:FindFirstChild("ClaimDailyBonus")
    if claimDailyBonusEvent then
        claimDailyBonusEvent.OnServerEvent:Connect(function(player)
            self:HandleDailyBonusClaim(player)
        end)
        print("🔗 DailyBonusManager: Connected to ClaimDailyBonus RemoteEvent")
    end
    
    -- Handle daily bonus status requests
    local getDailyBonusStatusFunction = remoteEvents:FindFirstChild("GetDailyBonusStatus")
    if getDailyBonusStatusFunction then
        getDailyBonusStatusFunction.OnServerInvoke = function(player)
            return self:GetPlayerBonusStatus(player)
        end
        print("🔗 DailyBonusManager: Connected to GetDailyBonusStatus RemoteFunction")
    end
end

-- ==========================================
-- DATA MANAGEMENT
-- ==========================================

function DailyBonusManager:LoadPlayerBonusData(player)
    local userId = player.UserId
    local defaultData = {
        streak = 0,
        lastClaimTime = 0,
        totalClaimed = 0,
        totalDays = 0,
        milestonesReached = {},
        joinTime = os.time()
    }
    
    if self.DailyBonusDataStore then
        local success, savedData = pcall(function()
            return self.DailyBonusDataStore:GetAsync("Player_" .. userId)
        end)
        
        if success and savedData then
            self.PlayerBonusData[userId] = savedData
            print("💾 DailyBonusManager: Loaded bonus data for", player.Name, "- Streak:", savedData.streak)
        else
            self.PlayerBonusData[userId] = defaultData
            print("🆕 DailyBonusManager: Created new bonus data for", player.Name)
        end
    else
        self.PlayerBonusData[userId] = defaultData
    end
    
    -- Check if player can claim bonus
    self:CheckDailyBonusEligibility(player)
end

function DailyBonusManager:SavePlayerBonusData(player)
    local userId = player.UserId
    local bonusData = self.PlayerBonusData[userId]
    
    if not bonusData or not self.DailyBonusDataStore then
        return
    end
    
    local success, error = pcall(function()
        self.DailyBonusDataStore:SetAsync("Player_" .. userId, bonusData)
    end)
    
    if success then
        print("💾 DailyBonusManager: Saved bonus data for", player.Name)
    else
        warn("❌ DailyBonusManager: Failed to save bonus data for", player.Name, ":", error)
    end
end

-- ==========================================
-- DAILY BONUS LOGIC
-- ==========================================

function DailyBonusManager:HandleDailyBonusClaim(player)
    local userId = player.UserId
    local bonusData = self.PlayerBonusData[userId]
    
    if not bonusData then
        self:NotifyPlayer(player, "error", "Bonus data not found. Please rejoin.")
        return
    end
    
    -- Check eligibility
    local eligibilityCheck = self:CheckClaimEligibility(player)
    if not eligibilityCheck.canClaim then
        self:NotifyPlayer(player, "warning", eligibilityCheck.reason)
        return
    end
    
    -- Process the claim
    local claimResult = self:ProcessDailyBonusClaim(player)
    
    if claimResult.success then
        -- Update streak and claim time
        self:UpdatePlayerStreak(player)
        
        -- Give rewards
        self:GiveDailyRewards(player, claimResult.rewards)
        
        -- Save data
        self:SavePlayerBonusData(player)
        
        -- Notify success
        self:NotifySuccessfulClaim(player, claimResult.rewards)
        
        print("🎁 DailyBonusManager:", player.Name, "claimed daily bonus - Day", bonusData.streak, 
              "- Coins:", claimResult.rewards.coins, "XP:", claimResult.rewards.xp)
    else
        self:NotifyPlayer(player, "error", claimResult.reason)
    end
end

function DailyBonusManager:CheckClaimEligibility(player)
    local userId = player.UserId
    local bonusData = self.PlayerBonusData[userId]
    local currentTime = os.time()
    
    -- Check if enough time has passed since last claim
    local timeSinceLastClaim = currentTime - bonusData.lastClaimTime
    local minClaimInterval = self.ClaimCooldownHours * 3600 -- Convert to seconds
    
    if timeSinceLastClaim < minClaimInterval then
        local hoursLeft = math.ceil((minClaimInterval - timeSinceLastClaim) / 3600)
        return {
            canClaim = false,
            reason = "Daily bonus available in " .. hoursLeft .. " hours"
        }
    end
    
    -- Check if streak should be reset
    local maxStreakTime = self.StreakResetHours * 3600
    if timeSinceLastClaim > maxStreakTime then
        -- Streak will be reset, but they can still claim
        return {
            canClaim = true,
            streakReset = true,
            reason = "Streak reset due to long absence"
        }
    end
    
    return {
        canClaim = true,
        streakReset = false,
        reason = "Eligible for daily bonus"
    }
end

function DailyBonusManager:ProcessDailyBonusClaim(player)
    local userId = player.UserId
    local bonusData = self.PlayerBonusData[userId]
    
    -- Check if streak should be reset
    local eligibility = self:CheckClaimEligibility(player)
    if eligibility.streakReset then
        bonusData.streak = 0
    end
    
    -- Calculate new streak day
    local newStreakDay = math.min(bonusData.streak + 1, self.MaxStreakDays)
    
    -- Get base rewards for this streak day
    local baseRewards = self:GetBaseRewards(newStreakDay)
    
    -- Apply VIP multiplier
    local finalRewards = self:ApplyVIPMultiplier(player, baseRewards)
    
    -- Check for milestone rewards
    local milestoneRewards = self:CheckMilestoneRewards(player, newStreakDay)
    if milestoneRewards then
        finalRewards.coins = finalRewards.coins + milestoneRewards.coins
        finalRewards.xp = finalRewards.xp + milestoneRewards.xp
        finalRewards.special = milestoneRewards.special
    end
    
    return {
        success = true,
        rewards = finalRewards,
        newStreakDay = newStreakDay,
        milestone = milestoneRewards ~= nil
    }
end

function DailyBonusManager:GetBaseRewards(streakDay)
    -- Cycle through 7-day pattern, but increase base rewards every week
    local dayInCycle = ((streakDay - 1) % 7) + 1
    local weekNumber = math.floor((streakDay - 1) / 7) + 1
    local weekMultiplier = 1 + (weekNumber - 1) * 0.1 -- 10% increase per week
    
    local baseReward = self.DailyRewards.regular[dayInCycle]
    
    return {
        coins = math.floor(baseReward.coins * weekMultiplier),
        xp = math.floor(baseReward.xp * weekMultiplier),
        day = streakDay,
        dayInCycle = dayInCycle,
        week = weekNumber
    }
end

function DailyBonusManager:ApplyVIPMultiplier(player, baseRewards)
    local isVIP = VIPManager:IsPlayerVIP(player)
    local multiplier = isVIP and self.DailyRewards.vip_multiplier or 1
    
    return {
        coins = math.floor(baseRewards.coins * multiplier),
        xp = math.floor(baseRewards.xp * multiplier),
        day = baseRewards.day,
        dayInCycle = baseRewards.dayInCycle,
        week = baseRewards.week,
        isVIP = isVIP,
        multiplier = multiplier
    }
end

function DailyBonusManager:CheckMilestoneRewards(player, streakDay)
    local userId = player.UserId
    local bonusData = self.PlayerBonusData[userId]
    local milestoneReward = self.DailyRewards.milestones[streakDay]
    
    if milestoneReward and not bonusData.milestonesReached[streakDay] then
        -- Mark milestone as reached
        bonusData.milestonesReached[streakDay] = true
        return milestoneReward
    end
    
    return nil
end

function DailyBonusManager:UpdatePlayerStreak(player)
    local userId = player.UserId
    local bonusData = self.PlayerBonusData[userId]
    
    bonusData.streak = bonusData.streak + 1
    bonusData.lastClaimTime = os.time()
    bonusData.totalClaimed = bonusData.totalClaimed + 1
    bonusData.totalDays = bonusData.totalDays + 1
end

function DailyBonusManager:GiveDailyRewards(player, rewards)
    -- Give coins
    local coinsGiven = EconomyManager:AddCoins(player, rewards.coins, "Daily Bonus: Day " .. rewards.day)
    if not coinsGiven then
        warn("❌ DailyBonusManager: Failed to give coins to", player.Name)
    end
    
    -- Give XP  
    local xpGiven = ProgressionManager:AddXP(player, rewards.xp, "Daily Bonus: Day " .. rewards.day)
    if not xpGiven then
        warn("❌ DailyBonusManager: Failed to give XP to", player.Name)
    end
    
    -- Handle special rewards
    if rewards.special then
        self:GiveSpecialReward(player, rewards.special)
    end
end

function DailyBonusManager:GiveSpecialReward(player, specialItem)
    -- Handle special milestone rewards
    if specialItem == "Golden Seed Pack" then
        -- Give premium seeds
        EconomyManager:AddCoins(player, 1000, "Golden Seed Pack Bonus")
        
    elseif specialItem == "VIP Plot Expansion" then
        -- Give extra plot (handled by PlotManager)
        local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
        if remoteEvents then
            local grantPlotEvent = remoteEvents:FindFirstChild("GrantBonusPlot")
            if grantPlotEvent then
                grantPlotEvent:FireClient(player, "milestone_reward")
            end
        end
        
    elseif specialItem == "Legendary Plant" then
        -- Give access to exclusive plant
        ProgressionManager:UnlockSpecialPlant(player, "LegendaryPlant")
    end
    
    print("🌟 DailyBonusManager:", player.Name, "received special reward:", specialItem)
end

-- ==========================================
-- BONUS STATUS & INFORMATION
-- ==========================================

function DailyBonusManager:GetPlayerBonusStatus(player)
    local userId = player.UserId
    local bonusData = self.PlayerBonusData[userId]
    
    if not bonusData then
        return {
            error = "Bonus data not found",
            canClaim = false
        }
    end
    
    local currentTime = os.time()
    local timeSinceLastClaim = currentTime - bonusData.lastClaimTime
    local eligibility = self:CheckClaimEligibility(player)
    
    -- Calculate next reward preview
    local nextStreakDay = bonusData.streak + 1
    if eligibility.streakReset then
        nextStreakDay = 1
    end
    
    local nextRewards = self:GetBaseRewards(nextStreakDay)
    local nextRewardsWithVIP = self:ApplyVIPMultiplier(player, nextRewards)
    
    -- Check for upcoming milestone
    local nextMilestone = nil
    for day, reward in pairs(self.DailyRewards.milestones) do
        if day > bonusData.streak and (not nextMilestone or day < nextMilestone.day) then
            nextMilestone = {day = day, reward = reward}
        end
    end
    
    return {
        streak = bonusData.streak,
        totalClaimed = bonusData.totalClaimed,
        lastClaimTime = bonusData.lastClaimTime,
        canClaim = eligibility.canClaim,
        reason = eligibility.reason,
        streakWillReset = eligibility.streakReset or false,
        nextRewards = nextRewardsWithVIP,
        nextMilestone = nextMilestone,
        hoursUntilNextClaim = eligibility.canClaim and 0 or math.ceil((self.ClaimCooldownHours * 3600 - timeSinceLastClaim) / 3600),
        isVIP = VIPManager:IsPlayerVIP(player)
    }
end

function DailyBonusManager:CheckDailyBonusEligibility(player)
    local status = self:GetPlayerBonusStatus(player)
    
    if status.canClaim then
        -- Notify player they can claim
        self:NotifyPlayer(player, "info", "🎁 Daily bonus available! Day " .. (status.streak + 1))
        
        -- Send UI update
        local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
        if remoteEvents then
            local updateDailyBonusUIEvent = remoteEvents:FindFirstChild("UpdateDailyBonusUI")
            if updateDailyBonusUIEvent then
                updateDailyBonusUIEvent:FireClient(player, status)
            end
        end
    end
end

-- ==========================================
-- STREAK RESET SYSTEM
-- ==========================================

function DailyBonusManager:SetupStreakResetSystem()
    -- Check for streak resets every hour
    spawn(function()
        while true do
            wait(3600) -- 1 hour
            self:CheckAllStreakResets()
        end
    end)
end

function DailyBonusManager:CheckAllStreakResets()
    local currentTime = os.time()
    local resetThreshold = self.StreakResetHours * 3600
    
    for userId, bonusData in pairs(self.PlayerBonusData) do
        if bonusData.lastClaimTime > 0 then -- Player has claimed before
            local timeSinceLastClaim = currentTime - bonusData.lastClaimTime
            
            if timeSinceLastClaim > resetThreshold and bonusData.streak > 0 then
                -- Reset streak
                bonusData.streak = 0
                
                local player = Players:GetPlayerByUserId(userId)
                if player then
                    print("🔄 DailyBonusManager: Reset streak for", player.Name, "due to inactivity")
                    self:NotifyPlayer(player, "warning", "Daily bonus streak reset due to absence")
                end
            end
        end
    end
end

-- ==========================================
-- NOTIFICATION SYSTEM
-- ==========================================

function DailyBonusManager:NotifySuccessfulClaim(player, rewards)
    local message = string.format("🎁 Daily Bonus Claimed!\n💰 +%d coins\n⭐ +%d XP\n🔥 Day %d streak", 
        rewards.coins, rewards.xp, rewards.day)
    
    if rewards.isVIP then
        message = message .. "\n👑 VIP Bonus Applied!"
    end
    
    if rewards.special then
        message = message .. "\n🌟 Special: " .. rewards.special
    end
    
    self:NotifyPlayer(player, "success", message)
    
    -- Also trigger celebration effect
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if remoteEvents then
        local celebrateEvent = remoteEvents:FindFirstChild("PlayCelebrationEffect")
        if celebrateEvent then
            celebrateEvent:FireClient(player, "daily_bonus", rewards)
        end
    end
end

function DailyBonusManager:NotifyPlayer(player, messageType, message)
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if remoteEvents then
        local showNotificationEvent = remoteEvents:FindFirstChild("ShowNotification")
        if showNotificationEvent then
            showNotificationEvent:FireClient(player, message, messageType)
        end
    end
    
    -- Also print to console for debugging
    local prefix = messageType == "error" and "❌" or messageType == "warning" and "⚠️" or "✅"
    print(prefix .. " DailyBonusManager:", player.Name, "-", message:gsub("\n", " "))
end

-- ==========================================
-- STATISTICS & ANALYTICS
-- ==========================================

function DailyBonusManager:GetBonusStatistics()
    local totalPlayers = 0
    local totalClaims = 0
    local activeStreaks = 0
    local averageStreak = 0
    local vipPlayers = 0
    
    for userId, bonusData in pairs(self.PlayerBonusData) do
        totalPlayers = totalPlayers + 1
        totalClaims = totalClaims + bonusData.totalClaimed
        
        if bonusData.streak > 0 then
            activeStreaks = activeStreaks + 1
            averageStreak = averageStreak + bonusData.streak
        end
        
        local player = Players:GetPlayerByUserId(userId)
        if player and VIPManager:IsPlayerVIP(player) then
            vipPlayers = vipPlayers + 1
        end
    end
    
    return {
        totalPlayers = totalPlayers,
        totalClaims = totalClaims,
        activeStreaks = activeStreaks,
        averageStreak = activeStreaks > 0 and (averageStreak / activeStreaks) or 0,
        vipPlayers = vipPlayers,
        claimsPerPlayer = totalPlayers > 0 and (totalClaims / totalPlayers) or 0
    }
end

-- ==========================================
-- ADMIN FUNCTIONS
-- ==========================================

function DailyBonusManager:AdminGrantDailyBonus(player, day)
    -- Admin command to grant specific day bonus
    if not day or day < 1 or day > self.MaxStreakDays then
        return false, "Invalid day number"
    end
    
    local rewards = self:GetBaseRewards(day)
    local finalRewards = self:ApplyVIPMultiplier(player, rewards)
    
    self:GiveDailyRewards(player, finalRewards)
    
    print("🔧 DailyBonusManager: Admin granted day", day, "bonus to", player.Name)
    return true, "Bonus granted successfully"
end

function DailyBonusManager:AdminResetStreak(player)
    -- Admin command to reset player's streak
    local userId = player.UserId
    local bonusData = self.PlayerBonusData[userId]
    
    if bonusData then
        bonusData.streak = 0
        bonusData.lastClaimTime = 0
        self:SavePlayerBonusData(player)
        
        print("🔧 DailyBonusManager: Admin reset streak for", player.Name)
        return true, "Streak reset successfully"
    end
    
    return false, "Player bonus data not found"
end

function DailyBonusManager:AdminSetStreak(player, streakDay)
    -- Admin command to set player's streak
    if not streakDay or streakDay < 0 or streakDay > self.MaxStreakDays then
        return false, "Invalid streak day"
    end
    
    local userId = player.UserId
    local bonusData = self.PlayerBonusData[userId]
    
    if bonusData then
        bonusData.streak = streakDay
        self:SavePlayerBonusData(player)
        
        print("🔧 DailyBonusManager: Admin set streak to", streakDay, "for", player.Name)
        return true, "Streak set successfully"
    end
    
    return false, "Player bonus data not found"
end

function DailyBonusManager:PrintBonusStatistics()
    local stats = self:GetBonusStatistics()
    
    print("📊 DailyBonusManager Statistics:")
    print("   Total players:", stats.totalPlayers)
    print("   Total claims:", stats.totalClaims)
    print("   Active streaks:", stats.activeStreaks)
    print("   Average streak length:", math.floor(stats.averageStreak * 10) / 10)
    print("   VIP players:", stats.vipPlayers)
    print("   Claims per player:", math.floor(stats.claimsPerPlayer * 10) / 10)
end

-- ==========================================
-- CLEANUP & MAINTENANCE
-- ==========================================

function DailyBonusManager:PerformMaintenance()
    -- Save all player data
    for _, player in pairs(Players:GetPlayers()) do
        self:SavePlayerBonusData(player)
    end
    
    -- Clean up old milestone tracking
    local currentTime = os.time()
    for userId, bonusData in pairs(self.PlayerBonusData) do
        -- Remove very old inactive players (30 days offline)
        if bonusData.lastClaimTime > 0 and currentTime - bonusData.lastClaimTime > (30 * 24 * 3600) then
            local player = Players:GetPlayerByUserId(userId)
            if not player then -- Player is not online
                self.PlayerBonusData[userId] = nil
                print("🧹 DailyBonusManager: Cleaned up data for inactive userId", userId)
            end
        end
    end
    
    print("🔧 DailyBonusManager: Maintenance completed")
end

return DailyBonusManager
