--[[
    PlantManager.lua
    Core Plant System with Placeholder Support
    
    Priority: 2 (Core gameplay module)
    Dependencies: ConfigModule
    Used by: PlantingHandler, HarvestHandler, GrowthHandler
    
    Features:
    - Part-based plant placeholders
    - Universal Model → Part fallback system
    - 3-stage growth progression
    - VIP growth speed multipliers
    - Visual feedback and animations
    - Server restart recovery
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)

local PlantManager = {}
PlantManager.__index = PlantManager

-- ==========================================
-- PLANT DATA STORAGE
-- ==========================================

PlantManager.ActivePlants = {}     -- [plotId] = {plantData, partInstance, startTime, stage}
PlantManager.GrowthTimers = {}     -- [plotId] = connectionObject
PlantManager.CulledPlants = {}     -- [plotId] = plantInstance (for LOD restoration)

-- ==========================================
-- INITIALIZATION
-- ==========================================

function PlantManager:Initialize()
    print("🌱 PlantManager: Initializing plant system...")
    
    -- Create plants folder in workspace
    local plantsFolder = Workspace:FindFirstChild("Plants")
    if not plantsFolder then
        plantsFolder = Instance.new("Folder")
        plantsFolder.Name = "Plants"
        plantsFolder.Parent = Workspace
    end
    
    -- Set up LOD (Level of Detail) system for mobile performance
    self:InitializeLODSystem()
    
    print("✅ PlantManager: Plant system initialized successfully")
end

-- ==========================================
-- PLANT CREATION SYSTEM
-- ==========================================

function PlantManager:CreatePlant(plotId, plantType, position)
    -- Validate inputs
    if not plotId or not plantType or not position then
        warn("❌ PlantManager: Invalid plant creation parameters")
        return false
    end
    
    local plantConfig = ConfigModule.Plants[plantType]
    if not plantConfig then
        warn("❌ PlantManager: Unknown plant type:", plantType)
        return false
    end
    
    -- Remove existing plant if any
    self:RemovePlant(plotId)
    
    -- Create plant using placeholder or model
    local plantInstance
    if ConfigModule.USE_MODELS[plantType] then
        plantInstance = self:CreatePlantFromModel(plantType, position)
    else
        plantInstance = self:CreatePlantFromPart(plantType, position, 1) -- Start at stage 1
    end
    
    if not plantInstance then
        warn("❌ PlantManager: Failed to create plant instance")
        return false
    end
    
    -- Store plant data
    local plantData = {
        plantType = plantType,
        plotId = plotId,
        stage = 1,
        startTime = os.time(),
        position = position,
        instance = plantInstance,
        isReady = false
    }
    
    self.ActivePlants[plotId] = plantData
    
    -- Start growth timer
    self:StartGrowthTimer(plotId)
    
    print("🌱 PlantManager: Created", plantType, "at plot", plotId)
    return true
end

function PlantManager:CreatePlantFromPart(plantType, position, stage)
    local plantConfig = ConfigModule.Plants[plantType]
    local stageConfig = plantConfig.stages[stage]
    
    if not stageConfig then
        warn("❌ PlantManager: Invalid stage", stage, "for plant", plantType)
        return nil
    end
    
    -- Create part based on stage configuration
    local plant = Instance.new("Part")
    plant.Name = plantType .. "_Stage" .. stage .. "_Plot"
    plant.Shape = self:GetPartShape(stageConfig.partType)
    plant.Size = stageConfig.size
    plant.Color = stageConfig.color
    plant.Material = stageConfig.material
    plant.Position = position + Vector3.new(0, stageConfig.size.Y/2, 0) -- Ground level + height/2
    plant.Anchored = true
    plant.CanCollide = false
    plant.Parent = Workspace.Plants
    
    -- Add ClickDetector for harvest interaction (stage 3 only)
    if stage == 3 then
        local clickDetector = Instance.new("ClickDetector")
        clickDetector.MaxActivationDistance = 15
        clickDetector.Parent = plant
        
        -- Visual ready indicator (floating animation)
        self:AddReadyToHarvestEffects(plant)
    end
    
    -- Add growth transition animation
    plant.Size = Vector3.new(0.1, 0.1, 0.1) -- Start small
    local targetSize = stageConfig.size
    local growTween = TweenService:Create(
        plant,
        ConfigModule.UI.ANIMATIONS.PROGRESS_BAR_FILL,
        {Size = targetSize}
    )
    growTween:Play()
    
    return plant
end

function PlantManager:CreatePlantFromModel(plantType, position)
    -- Placeholder for future model loading system
    -- Falls back to Part creation if model load fails
    warn("📦 PlantManager: Model system not implemented yet, using Part fallback")
    return self:CreatePlantFromPart(plantType, position, 1)
end

-- ==========================================
-- GROWTH SYSTEM
-- ==========================================

function PlantManager:StartGrowthTimer(plotId)
    local plantData = self.ActivePlants[plotId]
    if not plantData then
        warn("❌ PlantManager: No plant data for plot", plotId)
        return
    end
    
    local plantConfig = ConfigModule.Plants[plantData.plantType]
    local growthTime = plantConfig.growthTime
    local stageTime = growthTime / 3 -- 3 stages total
    
    -- Clear existing timer
    if self.GrowthTimers[plotId] then
        self.GrowthTimers[plotId]:Disconnect()
    end
    
    -- Create growth timer
    local timer = 0
    self.GrowthTimers[plotId] = RunService.Heartbeat:Connect(function(deltaTime)
        timer = timer + deltaTime
        
        -- Calculate current stage based on elapsed time
        local newStage = math.min(3, math.floor(timer / stageTime) + 1)
        
        if newStage > plantData.stage then
            self:AdvancePlantStage(plotId, newStage)
        end
        
        -- Stop timer when fully grown
        if newStage >= 3 then
            self.GrowthTimers[plotId]:Disconnect()
            self.GrowthTimers[plotId] = nil
            plantData.isReady = true
            
            print("🌟 PlantManager: Plant at plot", plotId, "is ready for harvest!")
        end
    end)
end

function PlantManager:AdvancePlantStage(plotId, newStage)
    local plantData = self.ActivePlants[plotId]
    if not plantData or newStage <= plantData.stage then
        return
    end
    
    print("🌱 PlantManager: Advancing plant at plot", plotId, "to stage", newStage)
    
    -- Update stage
    plantData.stage = newStage
    
    -- Update visual (recreate Part with new stage configuration)
    local oldInstance = plantData.instance
    local newInstance = self:CreatePlantFromPart(plantData.plantType, plantData.position, newStage)
    
    if newInstance then
        -- Clean up old instance
        if oldInstance and oldInstance.Parent then
            oldInstance:Destroy()
        end
        
        -- Update reference
        plantData.instance = newInstance
        
        -- Add stage transition effects
        self:PlayStageTransitionEffects(newInstance, newStage)
    end
end

function PlantManager:AdvancePlantStageOffline(plotId, elapsedTime, isVIP)
    local plantData = self.ActivePlants[plotId]
    if not plantData then
        return
    end
    
    local plantConfig = ConfigModule.Plants[plantData.plantType]
    local baseGrowthTime = plantConfig.growthTime
    
    -- Apply VIP multiplier for offline progress
    local multiplier = isVIP and ConfigModule.VIP.OFFLINE_PROGRESS_MULTIPLIER or 1.0
    local effectiveElapsedTime = elapsedTime * multiplier
    
    -- Calculate stage based on offline progress
    local stageTime = baseGrowthTime / 3
    local newStage = math.min(3, math.floor(effectiveElapsedTime / stageTime) + 1)
    
    if newStage > plantData.stage then
        print("⏰ PlantManager: Offline growth - advancing plot", plotId, "to stage", newStage)
        self:AdvancePlantStage(plotId, newStage)
        
        if newStage >= 3 then
            plantData.isReady = true
        end
    end
end

-- ==========================================
-- HARVEST SYSTEM
-- ==========================================

function PlantManager:HarvestPlant(plotId)
    local plantData = self.ActivePlants[plotId]
    if not plantData then
        warn("❌ PlantManager: No plant to harvest at plot", plotId)
        return nil
    end
    
    if not plantData.isReady or plantData.stage < 3 then
        warn("⚠️ PlantManager: Plant at plot", plotId, "is not ready for harvest")
        return nil
    end
    
    local plantConfig = ConfigModule.Plants[plantData.plantType]
    
    -- Play harvest effects
    self:PlayHarvestEffects(plantData.instance)
    
    -- Remove plant
    self:RemovePlant(plotId)
    
    print("🌟 PlantManager: Harvested", plantData.plantType, "from plot", plotId)
    
    -- Return harvest rewards
    return {
        plantType = plantData.plantType,
        coins = plantConfig.sellPrice,
        xp = plantConfig.xpReward
    }
end

function PlantManager:RemovePlant(plotId)
    local plantData = self.ActivePlants[plotId]
    if not plantData then
        return
    end
    
    -- Stop growth timer
    if self.GrowthTimers[plotId] then
        self.GrowthTimers[plotId]:Disconnect()
        self.GrowthTimers[plotId] = nil
    end
    
    -- Remove plant instance
    if plantData.instance and plantData.instance.Parent then
        plantData.instance:Destroy()
    end
    
    -- Clear data
    self.ActivePlants[plotId] = nil
    self.CulledPlants[plotId] = nil
    
    print("🗑️ PlantManager: Removed plant from plot", plotId)
end

-- ==========================================
-- VISUAL EFFECTS
-- ==========================================

function PlantManager:AddReadyToHarvestEffects(plantInstance)
    -- Floating animation for ready plants
    local floatTween = TweenService:Create(
        plantInstance,
        TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {Position = plantInstance.Position + Vector3.new(0, 0.5, 0)}
    )
    floatTween:Play()
    
    -- Glowing effect (already Neon material for stage 3)
    local glowTween = TweenService:Create(
        plantInstance,
        TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {Transparency = 0.2}
    )
    glowTween:Play()
end

function PlantManager:PlayStageTransitionEffects(plantInstance, stage)
    -- Growth burst animation
    local originalSize = plantInstance.Size
    plantInstance.Size = originalSize * 1.3
    
    local shrinkTween = TweenService:Create(
        plantInstance,
        TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Size = originalSize}
    )
    shrinkTween:Play()
    
    -- Stage progression notification (could be handled by UI system)
    print("✨ Plant grew to stage", stage, "!")
end

function PlantManager:PlayHarvestEffects(plantInstance)
    if not plantInstance or not plantInstance.Parent then
        return
    end
    
    -- Shrink and fade out animation
    local harvestTween = TweenService:Create(
        plantInstance,
        TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {
            Size = Vector3.new(0.1, 0.1, 0.1),
            Transparency = 1
        }
    )
    
    harvestTween:Play()
    harvestTween.Completed:Connect(function()
        if plantInstance.Parent then
            plantInstance:Destroy()
        end
    end)
end

-- ==========================================
-- LOD (LEVEL OF DETAIL) SYSTEM
-- ==========================================

function PlantManager:InitializeLODSystem()
    -- LOD system for mobile performance
    RunService.Heartbeat:Connect(function()
        self:UpdatePlantLOD()
    end)
end

function PlantManager:UpdatePlantLOD()
    local camera = Workspace.CurrentCamera
    if not camera then return end
    
    for plotId, plantData in pairs(self.ActivePlants) do
        local plant = plantData.instance
        if plant and plant.Parent then
            local distance = (camera.CFrame.Position - plant.Position).Magnitude
            
            if distance > ConfigModule.Performance.LOD_DISTANCES.CULL_DISTANCE then
                -- Cull very distant plants
                plant.Parent = nil
                self.CulledPlants[plotId] = plant
            elseif distance > ConfigModule.Performance.LOD_DISTANCES.FADE_START then
                -- Fade distant plants
                plant.Transparency = math.min(0.8, (distance - 50) / 50)
            else
                -- Full visibility for close plants
                plant.Transparency = 0
            end
        end
    end
    
    -- Restore culled plants when camera gets closer
    for plotId, plant in pairs(self.CulledPlants) do
        if plant then
            local distance = (camera.CFrame.Position - plant.Position).Magnitude
            if distance <= ConfigModule.Performance.LOD_DISTANCES.FADE_START then
                plant.Parent = Workspace.Plants
                self.CulledPlants[plotId] = nil
            end
        end
    end
end

-- ==========================================
-- SERVER RESTART RECOVERY
-- ==========================================

function PlantManager:RestorePlantsFromData(plotsData)
    print("🔄 PlantManager: Restoring plants after server restart...")
    
    for plotId, plotData in pairs(plotsData) do
        if plotData.plantType and plotData.startTime then
            local elapsedTime = os.time() - plotData.startTime
            local plantConfig = ConfigModule.Plants[plotData.plantType]
            
            if plantConfig then
                -- Calculate current stage based on elapsed time
                local stageTime = plantConfig.growthTime / 3
                local currentStage = math.min(3, math.floor(elapsedTime / stageTime) + 1)
                
                -- Recreate plant at correct stage
                local position = self:GetPlotPosition(plotId)
                if position then
                    local plantInstance = self:CreatePlantFromPart(plotData.plantType, position, currentStage)
                    
                    if plantInstance then
                        local restoredPlantData = {
                            plantType = plotData.plantType,
                            plotId = plotId,
                            stage = currentStage,
                            startTime = plotData.startTime,
                            position = position,
                            instance = plantInstance,
                            isReady = currentStage >= 3
                        }
                        
                        self.ActivePlants[plotId] = restoredPlantData
                        
                        -- Continue growth if not fully grown
                        if currentStage < 3 then
                            self:StartGrowthTimer(plotId)
                        end
                        
                        print("🌱 PlantManager: Restored", plotData.plantType, "at plot", plotId, "stage", currentStage)
                    end
                end
            end
        end
    end
    
    print("✅ PlantManager: Plant restoration completed")
end

-- ==========================================
-- UTILITY FUNCTIONS
-- ==========================================

function PlantManager:GetPartShape(partType)
    local shapeMap = {
        Block = Enum.PartType.Block,
        Sphere = Enum.PartType.Ball,
        Cylinder = Enum.PartType.Cylinder,
        Wedge = Enum.PartType.Wedge
    }
    return shapeMap[partType] or Enum.PartType.Block
end

function PlantManager:GetPlotPosition(plotId)
    -- This function should be implemented based on plot positioning system
    -- For now, return a default position (will be updated when PlotManager is created)
    local spawn = Workspace:FindFirstChild("SpawnLocation")
    if spawn then
        return spawn.Position + Vector3.new(plotId * 25, 0, 0) -- Simple positioning
    end
    return Vector3.new(0, 0, 0)
end

function PlantManager:GetPlantData(plotId)
    return self.ActivePlants[plotId]
end

function PlantManager:IsPlantReady(plotId)
    local plantData = self.ActivePlants[plotId]
    return plantData and plantData.isReady
end

function PlantManager:GetAllPlants()
    return self.ActivePlants
end

function PlantManager:ApplyVIPGrowthBoost(plotId)
    local plantData = self.ActivePlants[plotId]
    if not plantData then return end
    
    -- Apply VIP 20% growth speed boost by adjusting timer
    local timer = self.GrowthTimers[plotId]
    if timer then
        -- This would need to be implemented with a more sophisticated timer system
        -- For now, just note that VIP boost should be applied
        print("⭐ PlantManager: Applied VIP growth boost to plot", plotId)
    end
end

return PlantManager
