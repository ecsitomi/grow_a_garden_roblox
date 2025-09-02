--[[
    PlantingHandler.lua
    Server-Side Plant Seeding Logic
    
    Priority: 11 (Core gameplay interaction)
    Dependencies: PlantManager, PlotManager, EconomyManager, ProgressionManager, RemoteEvents
    Used by: Client PlotClickHandler, Shop purchases
    
    Features:
    - Validate player plot ownership
    - Process seed purchases
    - Create plants at correct positions
    - Anti-cheat distance validation
    - VIP growth speed bonuses
    - Plant unlock level checking
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

-- Load required modules
local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)
local PlantManager = require(ServerStorage.Modules.PlantManager)
local PlotManager = require(ServerStorage.Modules.PlotManager)
local EconomyManager = require(ServerStorage.Modules.EconomyManager)
local ProgressionManager = require(ServerStorage.Modules.ProgressionManager)
local VIPManager = require(ServerStorage.Modules.VIPManager)

local PlantingHandler = {}
PlantingHandler.__index = PlantingHandler

-- ==========================================
-- PLANTING DATA STORAGE
-- ==========================================

PlantingHandler.PlantingCooldowns = {}    -- [userId] = lastPlantTime (anti-spam)
PlantingHandler.PlantingStats = {}        -- [userId] = {totalPlanted, plantsThisHour}

-- ==========================================
-- INITIALIZATION
-- ==========================================

function PlantingHandler:Initialize()
    print("🌱 PlantingHandler: Initializing planting system...")
    
    -- Set up RemoteEvent handlers
    self:SetupRemoteEvents()
    
    -- Set up anti-spam system
    self:SetupAntiSpamSystem()
    
    print("✅ PlantingHandler: Planting system initialized successfully")
end

function PlantingHandler:SetupRemoteEvents()
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then
        warn("❌ PlantingHandler: RemoteEvents folder not found")
        return
    end
    
    -- Handle PlantSeed events
    local plantSeedEvent = remoteEvents:FindFirstChild("PlantSeed")
    if plantSeedEvent then
        plantSeedEvent.OnServerEvent:Connect(function(player, plotId, plantType)
            self:HandlePlantSeedRequest(player, plotId, plantType)
        end)
        print("🔗 PlantingHandler: Connected to PlantSeed RemoteEvent")
    else
        warn("❌ PlantingHandler: PlantSeed RemoteEvent not found")
    end
    
    -- Handle GetPlantStatus requests
    local getPlantStatusFunction = remoteEvents:FindFirstChild("GetPlantStatus")
    if getPlantStatusFunction then
        getPlantStatusFunction.OnServerInvoke = function(player, plotId)
            return self:GetPlotStatus(player, plotId)
        end
        print("🔗 PlantingHandler: Connected to GetPlantStatus RemoteFunction")
    end
end

-- ==========================================
-- MAIN PLANTING LOGIC
-- ==========================================

function PlantingHandler:HandlePlantSeedRequest(player, plotId, plantType)
    -- Comprehensive validation before planting
    local validationResult = self:ValidatePlantingRequest(player, plotId, plantType)
    
    if not validationResult.success then
        warn("❌ PlantingHandler:", player.Name, "planting failed:", validationResult.reason)
        self:NotifyPlayer(player, "error", validationResult.reason)
        return false
    end
    
    -- Process the planting
    local plantingResult = self:ProcessPlanting(player, plotId, plantType)
    
    if plantingResult.success then
        -- Update statistics
        self:UpdatePlantingStats(player, plantType)
        
        -- Notify success
        self:NotifyPlayer(player, "success", "Successfully planted " .. plantType .. "!")
        
        print("🌱 PlantingHandler:", player.Name, "successfully planted", plantType, "at plot", plotId)
        return true
    else
        warn("❌ PlantingHandler:", player.Name, "planting processing failed:", plantingResult.reason)
        self:NotifyPlayer(player, "error", plantingResult.reason)
        return false
    end
end

function PlantingHandler:ValidatePlantingRequest(player, plotId, plantType)
    -- Input validation
    if not player or not plotId or not plantType then
        return {success = false, reason = "Invalid parameters"}
    end
    
    -- Check anti-spam cooldown
    local cooldownCheck = self:CheckPlantingCooldown(player)
    if not cooldownCheck.success then
        return cooldownCheck
    end
    
    -- Validate plot ownership
    local ownershipCheck = self:ValidatePlotOwnership(player, plotId)
    if not ownershipCheck.success then
        return ownershipCheck
    end
    
    -- Check if plot is empty
    local emptyCheck = self:ValidatePlotEmpty(plotId)
    if not emptyCheck.success then
        return emptyCheck
    end
    
    -- Validate walking distance (anti-cheat)
    local distanceCheck = self:ValidatePlayerDistance(player, plotId)
    if not distanceCheck.success then
        return distanceCheck
    end
    
    -- Check plant unlock status
    local unlockCheck = self:ValidatePlantUnlocked(player, plantType)
    if not unlockCheck.success then
        return unlockCheck
    end
    
    -- Validate plant type exists
    local plantCheck = self:ValidatePlantType(plantType)
    if not plantCheck.success then
        return plantCheck
    end
    
    -- Check if player can afford seeds
    local affordabilityCheck = self:ValidateAffordability(player, plantType)
    if not affordabilityCheck.success then
        return affordabilityCheck
    end
    
    return {success = true, reason = "All validations passed"}
end

-- ==========================================
-- VALIDATION FUNCTIONS
-- ==========================================

function PlantingHandler:CheckPlantingCooldown(player)
    local userId = player.UserId
    local currentTime = os.time()
    local lastPlantTime = self.PlantingCooldowns[userId] or 0
    local cooldownDuration = 1 -- 1 second cooldown
    
    if currentTime - lastPlantTime < cooldownDuration then
        return {success = false, reason = "Planting too quickly! Wait a moment."}
    end
    
    return {success = true}
end

function PlantingHandler:ValidatePlotOwnership(player, plotId)
    local isOwner = PlotManager:IsPlotOwnedByPlayer(plotId, player)
    
    if not isOwner then
        return {success = false, reason = "You don't own this plot"}
    end
    
    return {success = true}
end

function PlantingHandler:ValidatePlotEmpty(plotId)
    local plantData = PlantManager:GetPlantData(plotId)
    
    if plantData then
        return {success = false, reason = "Plot already has a plant"}
    end
    
    return {success = true}
end

function PlantingHandler:ValidatePlayerDistance(player, plotId)
    local isValid, message = PlotManager:ValidatePlotInteraction(player, plotId)
    
    if not isValid then
        return {success = false, reason = message or "Too far from plot"}
    end
    
    return {success = true}
end

function PlantingHandler:ValidatePlantUnlocked(player, plantType)
    local isUnlocked = ProgressionManager:IsPlantUnlocked(player, plantType)
    
    if not isUnlocked then
        local plantConfig = ConfigModule.Plants[plantType]
        local requiredLevel = plantConfig and plantConfig.unlockLevel or "Unknown"
        return {success = false, reason = "Plant requires level " .. requiredLevel}
    end
    
    return {success = true}
end

function PlantingHandler:ValidatePlantType(plantType)
    local plantConfig = ConfigModule.Plants[plantType]
    
    if not plantConfig then
        return {success = false, reason = "Unknown plant type"}
    end
    
    return {success = true}
end

function PlantingHandler:ValidateAffordability(player, plantType)
    local plantConfig = ConfigModule.Plants[plantType]
    local canAfford = EconomyManager:CanAfford(player, plantConfig.buyPrice)
    
    if not canAfford then
        return {success = false, reason = "Not enough coins (Need: " .. plantConfig.buyPrice .. ")"}
    end
    
    return {success = true}
end

-- ==========================================
-- PLANTING PROCESSING
-- ==========================================

function PlantingHandler:ProcessPlanting(player, plotId, plantType)
    -- Step 1: Purchase the seed
    local purchaseResult = self:PurchaseSeed(player, plantType)
    if not purchaseResult.success then
        return purchaseResult
    end
    
    -- Step 2: Get plot position
    local plotPosition = PlotManager:GetPlotPosition(plotId)
    if not plotPosition then
        -- Refund if position invalid
        self:RefundSeed(player, plantType, "Invalid plot position")
        return {success = false, reason = "Invalid plot position"}
    end
    
    -- Step 3: Create the plant
    local plantCreated = PlantManager:CreatePlant(plotId, plantType, plotPosition)
    if not plantCreated then
        -- Refund if plant creation failed
        self:RefundSeed(player, plantType, "Plant creation failed")
        return {success = false, reason = "Failed to create plant"}
    end
    
    -- Step 4: Apply VIP growth boost if applicable
    if VIPManager:IsPlayerVIP(player) then
        PlantManager:ApplyVIPGrowthBoost(plotId)
    end
    
    -- Step 5: Update cooldown
    self.PlantingCooldowns[player.UserId] = os.time()
    
    return {success = true, reason = "Plant created successfully"}
end

function PlantingHandler:PurchaseSeed(player, plantType)
    local success, result = EconomyManager:ProcessSeedPurchase(player, plantType, 1)
    
    if success then
        return {success = true, quantity = result}
    else
        return {success = false, reason = result}
    end
end

function PlantingHandler:RefundSeed(player, plantType, reason)
    local plantConfig = ConfigModule.Plants[plantType]
    if plantConfig then
        EconomyManager:AddCoins(player, plantConfig.buyPrice, "Planting Failed - Refund: " .. reason)
        print("💰 PlantingHandler: Refunded", plantConfig.buyPrice, "coins to", player.Name, "for failed planting")
    end
end

-- ==========================================
-- PLOT STATUS INFORMATION
-- ==========================================

function PlantingHandler:GetPlotStatus(player, plotId)
    -- Validate plot ownership
    if not PlotManager:IsPlotOwnedByPlayer(plotId, player) then
        return {
            error = "You don't own this plot",
            plotId = plotId,
            isEmpty = true
        }
    end
    
    -- Get plant data if exists
    local plantData = PlantManager:GetPlantData(plotId)
    
    if plantData then
        -- Plot has a plant
        return {
            plotId = plotId,
            isEmpty = false,
            plantType = plantData.plantType,
            stage = plantData.stage,
            isReady = plantData.isReady,
            startTime = plantData.startTime,
            position = plantData.position
        }
    else
        -- Plot is empty
        return {
            plotId = plotId,
            isEmpty = true,
            canPlant = true
        }
    end
end

-- ==========================================
-- STATISTICS & TRACKING
-- ==========================================

function PlantingHandler:UpdatePlantingStats(player, plantType)
    local userId = player.UserId
    
    if not self.PlantingStats[userId] then
        self.PlantingStats[userId] = {
            totalPlanted = 0,
            plantsThisHour = 0,
            lastHourReset = os.time()
        }
    end
    
    local stats = self.PlantingStats[userId]
    
    -- Reset hourly counter if needed
    if os.time() - stats.lastHourReset > 3600 then -- 1 hour
        stats.plantsThisHour = 0
        stats.lastHourReset = os.time()
    end
    
    -- Update counters
    stats.totalPlanted = stats.totalPlanted + 1
    stats.plantsThisHour = stats.plantsThisHour + 1
    
    print("📊 PlantingHandler:", player.Name, "planting stats - Total:", stats.totalPlanted, "This hour:", stats.plantsThisHour)
end

function PlantingHandler:SetupAntiSpamSystem()
    -- Reset hourly stats periodically
    spawn(function()
        while true do
            wait(3600) -- 1 hour
            
            for userId, stats in pairs(self.PlantingStats) do
                if stats then
                    stats.plantsThisHour = 0
                    stats.lastHourReset = os.time()
                end
            end
            
            print("🔄 PlantingHandler: Hourly planting stats reset")
        end
    end)
end

-- ==========================================
-- NOTIFICATION SYSTEM
-- ==========================================

function PlantingHandler:NotifyPlayer(player, messageType, message)
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if remoteEvents then
        local showNotificationEvent = remoteEvents:FindFirstChild("ShowNotification")
        if showNotificationEvent then
            showNotificationEvent:FireClient(player, message, messageType)
        end
    end
    
    -- Also print to console for debugging
    local prefix = messageType == "error" and "❌" or "✅"
    print(prefix .. " PlantingHandler:", player.Name, "-", message)
end

-- ==========================================
-- UTILITY FUNCTIONS
-- ==========================================

function PlantingHandler:GetPlayerPlantingStats(player)
    local userId = player.UserId
    return self.PlantingStats[userId] or {
        totalPlanted = 0,
        plantsThisHour = 0,
        lastHourReset = os.time()
    }
end

function PlantingHandler:CanPlayerPlant(player, plotId, plantType)
    local validation = self:ValidatePlantingRequest(player, plotId, plantType)
    return validation.success, validation.reason
end

function PlantingHandler:GetAvailablePlants(player)
    local unlockedPlants = ProgressionManager:GetUnlockedPlants(player)
    local availablePlants = {}
    
    for _, plantName in ipairs(unlockedPlants) do
        local plantConfig = ConfigModule.Plants[plantName]
        if plantConfig then
            table.insert(availablePlants, {
                name = plantName,
                buyPrice = plantConfig.buyPrice,
                sellPrice = plantConfig.sellPrice,
                growthTime = plantConfig.growthTime,
                xpReward = plantConfig.xpReward,
                canAfford = EconomyManager:CanAfford(player, plantConfig.buyPrice)
            })
        end
    end
    
    return availablePlants
end

-- ==========================================
-- ADMIN & DEBUG FUNCTIONS
-- ==========================================

function PlantingHandler:AdminPlantSeed(player, plotId, plantType)
    -- Admin command to plant without validation/cost
    local plotPosition = PlotManager:GetPlotPosition(plotId)
    if plotPosition then
        local success = PlantManager:CreatePlant(plotId, plantType, plotPosition)
        if success then
            print("🔧 PlantingHandler: Admin planted", plantType, "at plot", plotId, "for", player.Name)
            return true
        end
    end
    return false
end

function PlantingHandler:PrintPlantingDebugInfo()
    local totalPlayers = 0
    local totalPlanted = 0
    
    for userId, stats in pairs(self.PlantingStats) do
        totalPlayers = totalPlayers + 1
        totalPlanted = totalPlanted + stats.totalPlanted
    end
    
    print("🐛 PlantingHandler Debug Info:")
    print("   Active planters:", totalPlayers)
    print("   Total plants planted:", totalPlanted)
    print("   Average plants per player:", totalPlayers > 0 and (totalPlanted / totalPlayers) or 0)
    
    -- Show top planters
    local sortedStats = {}
    for userId, stats in pairs(self.PlantingStats) do
        local player = Players:GetPlayerByUserId(userId)
        if player then
            table.insert(sortedStats, {
                name = player.Name,
                planted = stats.totalPlanted
            })
        end
    end
    
    table.sort(sortedStats, function(a, b) return a.planted > b.planted end)
    
    print("   Top planters:")
    for i = 1, math.min(3, #sortedStats) do
        local planter = sortedStats[i]
        print("     " .. i .. ".", planter.name, "-", planter.planted, "plants")
    end
end

return PlantingHandler
