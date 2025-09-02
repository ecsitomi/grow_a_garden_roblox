--[[
    HarvestHandler.lua
    Server-Side Plant Harvesting Logic
    
    Priority: 12 (Core gameplay interaction)
    Dependencies: PlantManager, PlotManager, EconomyManager, ProgressionManager, VIPManager
    Used by: Client PlotClickHandler, auto-harvest systems
    
    Features:
    - Validate plant maturity for harvest
    - Process harvest rewards (coins + XP)
    - Apply VIP multipliers to rewards
    - Clear plot after successful harvest
    - Anti-cheat validation for harvest timing
    - Bulk harvest support for multiple plots
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Load required modules
local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)
local PlantManager = require(ServerStorage.Modules.PlantManager)
local PlotManager = require(ServerStorage.Modules.PlotManager)
local EconomyManager = require(ServerStorage.Modules.EconomyManager)
local ProgressionManager = require(ServerStorage.Modules.ProgressionManager)
local VIPManager = require(ServerStorage.Modules.VIPManager)

local HarvestHandler = {}
HarvestHandler.__index = HarvestHandler

-- ==========================================
-- HARVEST DATA STORAGE
-- ==========================================

HarvestHandler.HarvestCooldowns = {}      -- [userId] = lastHarvestTime (anti-spam)
HarvestHandler.HarvestStats = {}          -- [userId] = {totalHarvested, coinsEarned, xpGained}
HarvestHandler.OfflineHarvests = {}       -- [userId] = {harvests while offline}

-- ==========================================
-- INITIALIZATION
-- ==========================================

function HarvestHandler:Initialize()
    print("🌾 HarvestHandler: Initializing harvest system...")
    
    -- Set up RemoteEvent handlers
    self:SetupRemoteEvents()
    
    -- Set up auto-harvest detection
    self:SetupAutoHarvestSystem()
    
    -- Set up offline harvest tracking
    self:SetupOfflineHarvestTracking()
    
    print("✅ HarvestHandler: Harvest system initialized successfully")
end

function HarvestHandler:SetupRemoteEvents()
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then
        warn("❌ HarvestHandler: RemoteEvents folder not found")
        return
    end
    
    -- Handle HarvestPlant events
    local harvestPlantEvent = remoteEvents:FindFirstChild("HarvestPlant")
    if harvestPlantEvent then
        harvestPlantEvent.OnServerEvent:Connect(function(player, plotId)
            self:HandleHarvestRequest(player, plotId)
        end)
        print("🔗 HarvestHandler: Connected to HarvestPlant RemoteEvent")
    else
        warn("❌ HarvestHandler: HarvestPlant RemoteEvent not found")
    end
    
    -- Handle BulkHarvest events
    local bulkHarvestEvent = remoteEvents:FindFirstChild("BulkHarvest")
    if bulkHarvestEvent then
        bulkHarvestEvent.OnServerEvent:Connect(function(player, plotIds)
            self:HandleBulkHarvestRequest(player, plotIds)
        end)
        print("🔗 HarvestHandler: Connected to BulkHarvest RemoteEvent")
    end
    
    -- Handle GetHarvestInfo requests
    local getHarvestInfoFunction = remoteEvents:FindFirstChild("GetHarvestInfo")
    if getHarvestInfoFunction then
        getHarvestInfoFunction.OnServerInvoke = function(player, plotId)
            return self:GetHarvestInfo(player, plotId)
        end
        print("🔗 HarvestHandler: Connected to GetHarvestInfo RemoteFunction")
    end
end

-- ==========================================
-- MAIN HARVEST LOGIC
-- ==========================================

function HarvestHandler:HandleHarvestRequest(player, plotId)
    -- Comprehensive validation before harvesting
    local validationResult = self:ValidateHarvestRequest(player, plotId)
    
    if not validationResult.success then
        warn("❌ HarvestHandler:", player.Name, "harvest failed:", validationResult.reason)
        self:NotifyPlayer(player, "error", validationResult.reason)
        return false
    end
    
    -- Process the harvest
    local harvestResult = self:ProcessHarvest(player, plotId)
    
    if harvestResult.success then
        -- Update statistics
        self:UpdateHarvestStats(player, harvestResult.rewards)
        
        -- Notify success with rewards
        local rewardMessage = string.format("Harvested! +%d coins, +%d XP", 
            harvestResult.rewards.coins, harvestResult.rewards.xp)
        self:NotifyPlayer(player, "success", rewardMessage)
        
        print("🌾 HarvestHandler:", player.Name, "successfully harvested plot", plotId, 
              "- Coins:", harvestResult.rewards.coins, "XP:", harvestResult.rewards.xp)
        return true
    else
        warn("❌ HarvestHandler:", player.Name, "harvest processing failed:", harvestResult.reason)
        self:NotifyPlayer(player, "error", harvestResult.reason)
        return false
    end
end

function HarvestHandler:HandleBulkHarvestRequest(player, plotIds)
    if not plotIds or #plotIds == 0 then
        self:NotifyPlayer(player, "error", "No plots selected for harvest")
        return
    end
    
    if #plotIds > 8 then
        self:NotifyPlayer(player, "error", "Too many plots selected (max 8)")
        return
    end
    
    local successfulHarvests = 0
    local totalRewards = {coins = 0, xp = 0}
    local failedPlots = {}
    
    for _, plotId in ipairs(plotIds) do
        local harvestResult = self:ProcessHarvest(player, plotId, true) -- true = suppress individual notifications
        
        if harvestResult.success then
            successfulHarvests = successfulHarvests + 1
            totalRewards.coins = totalRewards.coins + harvestResult.rewards.coins
            totalRewards.xp = totalRewards.xp + harvestResult.rewards.xp
        else
            table.insert(failedPlots, plotId)
        end
    end
    
    -- Update statistics
    if successfulHarvests > 0 then
        self:UpdateHarvestStats(player, totalRewards)
        
        local rewardMessage = string.format("Bulk Harvest: %d plants! +%d coins, +%d XP", 
            successfulHarvests, totalRewards.coins, totalRewards.xp)
        self:NotifyPlayer(player, "success", rewardMessage)
    end
    
    if #failedPlots > 0 then
        self:NotifyPlayer(player, "warning", #failedPlots .. " plots couldn't be harvested")
    end
    
    print("🌾 HarvestHandler:", player.Name, "bulk harvest completed -", successfulHarvests, "successful,", #failedPlots, "failed")
end

-- ==========================================
-- VALIDATION FUNCTIONS
-- ==========================================

function HarvestHandler:ValidateHarvestRequest(player, plotId)
    -- Input validation
    if not player or not plotId then
        return {success = false, reason = "Invalid parameters"}
    end
    
    -- Check anti-spam cooldown
    local cooldownCheck = self:CheckHarvestCooldown(player)
    if not cooldownCheck.success then
        return cooldownCheck
    end
    
    -- Validate plot ownership
    local ownershipCheck = self:ValidatePlotOwnership(player, plotId)
    if not ownershipCheck.success then
        return ownershipCheck
    end
    
    -- Check if plot has a plant
    local plantExistsCheck = self:ValidatePlantExists(plotId)
    if not plantExistsCheck.success then
        return plantExistsCheck
    end
    
    -- Check if plant is ready for harvest
    local maturityCheck = self:ValidatePlantMaturity(plotId)
    if not maturityCheck.success then
        return maturityCheck
    end
    
    -- Validate walking distance (anti-cheat)
    local distanceCheck = self:ValidatePlayerDistance(player, plotId)
    if not distanceCheck.success then
        return distanceCheck
    end
    
    return {success = true, reason = "All validations passed"}
end

function HarvestHandler:CheckHarvestCooldown(player)
    local userId = player.UserId
    local currentTime = os.time()
    local lastHarvestTime = self.HarvestCooldowns[userId] or 0
    local cooldownDuration = 0.5 -- 0.5 second cooldown
    
    if currentTime - lastHarvestTime < cooldownDuration then
        return {success = false, reason = "Harvesting too quickly! Wait a moment."}
    end
    
    return {success = true}
end

function HarvestHandler:ValidatePlotOwnership(player, plotId)
    local isOwner = PlotManager:IsPlotOwnedByPlayer(plotId, player)
    
    if not isOwner then
        return {success = false, reason = "You don't own this plot"}
    end
    
    return {success = true}
end

function HarvestHandler:ValidatePlantExists(plotId)
    local plantData = PlantManager:GetPlantData(plotId)
    
    if not plantData then
        return {success = false, reason = "No plant found on this plot"}
    end
    
    return {success = true}
end

function HarvestHandler:ValidatePlantMaturity(plotId)
    local plantData = PlantManager:GetPlantData(plotId)
    
    if not plantData then
        return {success = false, reason = "No plant found on this plot"}
    end
    
    if not plantData.isReady then
        local timeLeft = PlantManager:GetTimeUntilReady(plotId)
        if timeLeft and timeLeft > 0 then
            local minutes = math.floor(timeLeft / 60)
            local seconds = timeLeft % 60
            return {success = false, reason = string.format("Plant not ready yet (%dm %ds left)", minutes, seconds)}
        else
            return {success = false, reason = "Plant not ready for harvest"}
        end
    end
    
    return {success = true}
end

function HarvestHandler:ValidatePlayerDistance(player, plotId)
    local isValid, message = PlotManager:ValidatePlotInteraction(player, plotId)
    
    if not isValid then
        return {success = false, reason = message or "Too far from plot"}
    end
    
    return {success = true}
end

-- ==========================================
-- HARVEST PROCESSING
-- ==========================================

function HarvestHandler:ProcessHarvest(player, plotId, suppressNotification)
    suppressNotification = suppressNotification or false
    
    -- Get plant data before harvesting
    local plantData = PlantManager:GetPlantData(plotId)
    if not plantData then
        return {success = false, reason = "Plant data not found"}
    end
    
    -- Calculate rewards
    local rewards = self:CalculateHarvestRewards(player, plantData)
    
    -- Remove the plant from the plot
    local plantRemoved = PlantManager:RemovePlant(plotId)
    if not plantRemoved then
        return {success = false, reason = "Failed to remove plant"}
    end
    
    -- Give rewards to player
    local rewardsGiven = self:GiveHarvestRewards(player, rewards)
    if not rewardsGiven then
        -- If reward giving failed, try to restore the plant
        PlantManager:RestorePlant(plotId, plantData)
        return {success = false, reason = "Failed to give rewards"}
    end
    
    -- Update cooldown
    self.HarvestCooldowns[player.UserId] = os.time()
    
    return {
        success = true, 
        rewards = rewards,
        plantType = plantData.plantType
    }
end

function HarvestHandler:CalculateHarvestRewards(player, plantData)
    local plantConfig = ConfigModule.Plants[plantData.plantType]
    if not plantConfig then
        warn("❌ HarvestHandler: Plant config not found for", plantData.plantType)
        return {coins = 0, xp = 0}
    end
    
    -- Base rewards
    local baseCoins = plantConfig.sellPrice or 0
    local baseXP = plantConfig.xpReward or 0
    
    -- Apply VIP multipliers
    local coinMultiplier = 1
    local xpMultiplier = 1
    
    if VIPManager:IsPlayerVIP(player) then
        coinMultiplier = ConfigModule.VIP.Benefits.earningsMultiplier or 1
        xpMultiplier = 1.5 -- VIP gets 50% bonus XP
    end
    
    -- Apply progression multipliers
    local playerLevel = ProgressionManager:GetPlayerLevel(player)
    local levelBonus = math.floor(playerLevel / 10) * 0.1 -- 10% bonus per 10 levels
    
    -- Calculate final rewards
    local finalCoins = math.floor(baseCoins * coinMultiplier * (1 + levelBonus))
    local finalXP = math.floor(baseXP * xpMultiplier * (1 + levelBonus))
    
    return {
        coins = finalCoins,
        xp = finalXP,
        coinMultiplier = coinMultiplier,
        xpMultiplier = xpMultiplier,
        levelBonus = levelBonus
    }
end

function HarvestHandler:GiveHarvestRewards(player, rewards)
    -- Give coins
    local coinsGiven = EconomyManager:AddCoins(player, rewards.coins, "Harvest: " .. rewards.coins .. " coins")
    if not coinsGiven then
        warn("❌ HarvestHandler: Failed to give coins to", player.Name)
        return false
    end
    
    -- Give XP
    local xpGiven = ProgressionManager:AddXP(player, rewards.xp, "Harvest: " .. rewards.xp .. " XP")
    if not xpGiven then
        warn("❌ HarvestHandler: Failed to give XP to", player.Name)
        -- Don't return false here, coins were already given
    end
    
    return true
end

-- ==========================================
-- HARVEST INFORMATION
-- ==========================================

function HarvestHandler:GetHarvestInfo(player, plotId)
    -- Validate plot ownership
    if not PlotManager:IsPlotOwnedByPlayer(plotId, player) then
        return {
            error = "You don't own this plot",
            plotId = plotId,
            canHarvest = false
        }
    end
    
    -- Get plant data
    local plantData = PlantManager:GetPlantData(plotId)
    
    if not plantData then
        return {
            plotId = plotId,
            canHarvest = false,
            reason = "No plant found"
        }
    end
    
    -- Calculate potential rewards
    local rewards = self:CalculateHarvestRewards(player, plantData)
    
    -- Check if ready for harvest
    local isReady = plantData.isReady
    local timeLeft = isReady and 0 or PlantManager:GetTimeUntilReady(plotId)
    
    return {
        plotId = plotId,
        plantType = plantData.plantType,
        stage = plantData.stage,
        canHarvest = isReady,
        timeLeft = timeLeft or 0,
        rewards = rewards,
        startTime = plantData.startTime
    }
end

-- ==========================================
-- AUTO-HARVEST SYSTEM
-- ==========================================

function HarvestHandler:SetupAutoHarvestSystem()
    -- Check for ready plants every 30 seconds
    local heartbeat
    heartbeat = RunService.Heartbeat:Connect(function()
        wait(30) -- Check every 30 seconds
        self:CheckForAutoHarvests()
    end)
    
    print("🔄 HarvestHandler: Auto-harvest detection system started")
end

function HarvestHandler:CheckForAutoHarvests()
    -- Check if any VIP players have ready plants for notifications
    for _, player in pairs(Players:GetPlayers()) do
        if VIPManager:IsPlayerVIP(player) then
            local readyPlots = self:GetReadyPlotsForPlayer(player)
            if #readyPlots > 0 then
                self:NotifyPlayerOfReadyHarvests(player, readyPlots)
            end
        end
    end
end

function HarvestHandler:GetReadyPlotsForPlayer(player)
    local readyPlots = {}
    local playerPlots = PlotManager:GetPlayerPlots(player)
    
    for _, plotId in ipairs(playerPlots or {}) do
        local plantData = PlantManager:GetPlantData(plotId)
        if plantData and plantData.isReady then
            table.insert(readyPlots, {
                plotId = plotId,
                plantType = plantData.plantType
            })
        end
    end
    
    return readyPlots
end

function HarvestHandler:NotifyPlayerOfReadyHarvests(player, readyPlots)
    if #readyPlots == 1 then
        self:NotifyPlayer(player, "info", "Your " .. readyPlots[1].plantType .. " is ready to harvest!")
    elseif #readyPlots > 1 then
        self:NotifyPlayer(player, "info", #readyPlots .. " plants are ready to harvest!")
    end
end

-- ==========================================
-- OFFLINE HARVEST TRACKING
-- ==========================================

function HarvestHandler:SetupOfflineHarvestTracking()
    -- Track when players leave
    Players.PlayerRemoving:Connect(function(player)
        self:RecordPlayerLeaving(player)
    end)
    
    -- Process offline harvests when players join
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function()
            wait(5) -- Wait for player to fully load
            self:ProcessOfflineHarvests(player)
        end)
    end)
    
    print("🕐 HarvestHandler: Offline harvest tracking enabled")
end

function HarvestHandler:RecordPlayerLeaving(player)
    local userId = player.UserId
    self.OfflineHarvests[userId] = {
        leaveTime = os.time(),
        plotStates = {}
    }
    
    -- Record current plot states
    local playerPlots = PlotManager:GetPlayerPlots(player)
    for _, plotId in ipairs(playerPlots or {}) do
        local plantData = PlantManager:GetPlantData(plotId)
        if plantData then
            self.OfflineHarvests[userId].plotStates[plotId] = {
                plantType = plantData.plantType,
                startTime = plantData.startTime,
                isReady = plantData.isReady
            }
        end
    end
    
    print("🕐 HarvestHandler: Recorded offline state for", player.Name)
end

function HarvestHandler:ProcessOfflineHarvests(player)
    local userId = player.UserId
    local offlineData = self.OfflineHarvests[userId]
    
    if not offlineData then
        return -- No offline data
    end
    
    local currentTime = os.time()
    local offlineTime = currentTime - offlineData.leaveTime
    local maxOfflineTime = ConfigModule.VIP.Benefits.maxOfflineTime or 14400 -- 4 hours default
    
    -- Limit offline time for non-VIP players
    if not VIPManager:IsPlayerVIP(player) then
        offlineTime = math.min(offlineTime, 1800) -- 30 minutes max for non-VIP
    else
        offlineTime = math.min(offlineTime, maxOfflineTime)
    end
    
    if offlineTime < 60 then -- Less than 1 minute offline
        return
    end
    
    local offlineRewards = self:CalculateOfflineHarvests(player, offlineData, offlineTime)
    
    if offlineRewards.totalCoins > 0 then
        self:GiveOfflineRewards(player, offlineRewards, offlineTime)
    end
    
    -- Clear offline data
    self.OfflineHarvests[userId] = nil
end

function HarvestHandler:CalculateOfflineHarvests(player, offlineData, offlineTime)
    local totalCoins = 0
    local totalXP = 0
    local harvestedPlants = 0
    
    for plotId, plantState in pairs(offlineData.plotStates) do
        local plantConfig = ConfigModule.Plants[plantState.plantType]
        if plantConfig then
            local growthTime = plantConfig.growthTime
            local timeInGround = offlineTime + (os.time() - plantState.startTime)
            
            if timeInGround >= growthTime then
                -- Plant would have been ready
                local harvestCount = math.floor(timeInGround / growthTime)
                
                -- Apply VIP multiplier for offline harvests
                local multiplier = VIPManager:IsPlayerVIP(player) and 
                    (ConfigModule.VIP.Benefits.offlineMultiplier or 2) or 1
                
                totalCoins = totalCoins + (plantConfig.sellPrice * harvestCount * multiplier)
                totalXP = totalXP + (plantConfig.xpReward * harvestCount)
                harvestedPlants = harvestedPlants + harvestCount
            end
        end
    end
    
    return {
        totalCoins = totalCoins,
        totalXP = totalXP,
        harvestedPlants = harvestedPlants
    }
end

function HarvestHandler:GiveOfflineRewards(player, rewards, offlineTime)
    -- Give rewards
    EconomyManager:AddCoins(player, rewards.totalCoins, "Offline Harvest: " .. rewards.harvestedPlants .. " plants")
    ProgressionManager:AddXP(player, rewards.totalXP, "Offline Harvest XP")
    
    -- Update statistics
    self:UpdateHarvestStats(player, {coins = rewards.totalCoins, xp = rewards.totalXP})
    
    -- Notify player
    local offlineHours = math.floor(offlineTime / 3600)
    local offlineMinutes = math.floor((offlineTime % 3600) / 60)
    
    local message = string.format("Welcome back! While offline (%dh %dm): +%d coins, +%d XP from %d plants", 
        offlineHours, offlineMinutes, rewards.totalCoins, rewards.totalXP, rewards.harvestedPlants)
    
    self:NotifyPlayer(player, "success", message)
    
    print("🕐 HarvestHandler:", player.Name, "received offline rewards -", 
          "Coins:", rewards.totalCoins, "XP:", rewards.totalXP, "Plants:", rewards.harvestedPlants)
end

-- ==========================================
-- STATISTICS & TRACKING
-- ==========================================

function HarvestHandler:UpdateHarvestStats(player, rewards)
    local userId = player.UserId
    
    if not self.HarvestStats[userId] then
        self.HarvestStats[userId] = {
            totalHarvested = 0,
            coinsEarned = 0,
            xpGained = 0,
            lastHarvestTime = os.time()
        }
    end
    
    local stats = self.HarvestStats[userId]
    stats.totalHarvested = stats.totalHarvested + 1
    stats.coinsEarned = stats.coinsEarned + (rewards.coins or 0)
    stats.xpGained = stats.xpGained + (rewards.xp or 0)
    stats.lastHarvestTime = os.time()
    
    print("📊 HarvestHandler:", player.Name, "harvest stats - Total:", stats.totalHarvested, 
          "Coins earned:", stats.coinsEarned, "XP gained:", stats.xpGained)
end

-- ==========================================
-- NOTIFICATION SYSTEM
-- ==========================================

function HarvestHandler:NotifyPlayer(player, messageType, message)
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if remoteEvents then
        local showNotificationEvent = remoteEvents:FindFirstChild("ShowNotification")
        if showNotificationEvent then
            showNotificationEvent:FireClient(player, message, messageType)
        end
    end
    
    -- Also print to console for debugging
    local prefix = messageType == "error" and "❌" or messageType == "warning" and "⚠️" or "✅"
    print(prefix .. " HarvestHandler:", player.Name, "-", message)
end

-- ==========================================
-- UTILITY FUNCTIONS
-- ==========================================

function HarvestHandler:GetPlayerHarvestStats(player)
    local userId = player.UserId
    return self.HarvestStats[userId] or {
        totalHarvested = 0,
        coinsEarned = 0,
        xpGained = 0,
        lastHarvestTime = 0
    }
end

function HarvestHandler:GetAllReadyPlotsForPlayer(player)
    return self:GetReadyPlotsForPlayer(player)
end

function HarvestHandler:CanPlayerHarvest(player, plotId)
    local validation = self:ValidateHarvestRequest(player, plotId)
    return validation.success, validation.reason
end

-- ==========================================
-- ADMIN & DEBUG FUNCTIONS
-- ==========================================

function HarvestHandler:AdminInstantHarvest(player, plotId)
    -- Admin command to harvest without validation
    local plantData = PlantManager:GetPlantData(plotId)
    if plantData then
        local rewards = self:CalculateHarvestRewards(player, plantData)
        PlantManager:RemovePlant(plotId)
        self:GiveHarvestRewards(player, rewards)
        print("🔧 HarvestHandler: Admin harvested plot", plotId, "for", player.Name)
        return true
    end
    return false
end

function HarvestHandler:PrintHarvestDebugInfo()
    local totalPlayers = 0
    local totalHarvested = 0
    local totalCoinsEarned = 0
    
    for userId, stats in pairs(self.HarvestStats) do
        totalPlayers = totalPlayers + 1
        totalHarvested = totalHarvested + stats.totalHarvested
        totalCoinsEarned = totalCoinsEarned + stats.coinsEarned
    end
    
    print("🐛 HarvestHandler Debug Info:")
    print("   Active harvesters:", totalPlayers)
    print("   Total plants harvested:", totalHarvested)
    print("   Total coins earned from harvests:", totalCoinsEarned)
    print("   Average harvests per player:", totalPlayers > 0 and (totalHarvested / totalPlayers) or 0)
    print("   Average coins per harvest:", totalHarvested > 0 and (totalCoinsEarned / totalHarvested) or 0)
end

return HarvestHandler
