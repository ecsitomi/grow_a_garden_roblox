--[[
    ShopManager.lua
    Shop Building + NPC Placeholder Management
    
    Priority: 4 (Core infrastructure module)
    Dependencies: ConfigModule
    Used by: ShopHandler, NPCInteractionHandler
    
    Features:
    - Automatic shop building placement (Part placeholder)
    - Shop NPC creation with ProximityPrompt
    - Spawn-relative positioning system
    - Interaction validation (walking distance)
    - Universal Model → Part fallback system
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local ProximityPromptService = game:GetService("ProximityPromptService")

local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)

local ShopManager = {}
ShopManager.__index = ShopManager

-- ==========================================
-- SHOP DATA STORAGE
-- ==========================================

ShopManager.ShopBuilding = nil      -- Shop building instance
ShopManager.ShopNPC = nil           -- Shop NPC instance
ShopManager.ShopPrompt = nil        -- ProximityPrompt for interaction
ShopManager.SpawnPosition = nil     -- Reference spawn position

-- ==========================================
-- INITIALIZATION
-- ==========================================

function ShopManager:Initialize()
    print("🏪 ShopManager: Initializing shop system...")
    
    -- Get spawn position for relative positioning
    self:FindSpawnPosition()
    
    -- Create shop building and NPC
    self:CreateShopBuilding()
    self:CreateShopNPC()
    
    -- Set up interaction system
    self:SetupShopInteraction()
    
    print("✅ ShopManager: Shop system initialized successfully")
end

function ShopManager:FindSpawnPosition()
    local spawnLocation = Workspace:FindFirstChild("SpawnLocation")
    
    if spawnLocation then
        self.SpawnPosition = spawnLocation.Position
        print("📍 ShopManager: Found spawn at position:", self.SpawnPosition)
    else
        -- Default to origin if no SpawnLocation found
        self.SpawnPosition = Vector3.new(0, 0, 0)
        warn("⚠️ ShopManager: No SpawnLocation found, using origin (0,0,0)")
    end
end

-- ==========================================
-- SHOP BUILDING CREATION
-- ==========================================

function ShopManager:CreateShopBuilding()
    -- Check if using model or placeholder
    if ConfigModule.USE_MODELS.ShopBuilding then
        self.ShopBuilding = self:CreateShopBuildingFromModel()
    else
        self.ShopBuilding = self:CreateShopBuildingFromPart()
    end
    
    if self.ShopBuilding then
        print("🏗️ ShopManager: Shop building created successfully")
    else
        warn("❌ ShopManager: Failed to create shop building")
    end
end

function ShopManager:CreateShopBuildingFromPart()
    local config = ConfigModule.Shop.BUILDING
    local position = self.SpawnPosition + config.offsetFromSpawn
    
    -- Create shop building Part
    local building = Instance.new("Part")
    building.Name = "ShopBuilding"
    building.Shape = Enum.PartType.Block
    building.Size = config.size
    building.Color = config.color
    building.Material = config.material
    building.Position = position + Vector3.new(0, config.size.Y/2, 0) -- Ground level + height/2
    building.Anchored = true
    building.CanCollide = true
    building.Parent = Workspace
    
    -- Add simple shop sign
    local signGui = Instance.new("SurfaceGui")
    signGui.Name = "ShopSign"
    signGui.Face = Enum.NormalId.Front
    signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    signGui.PixelsPerStud = 20
    signGui.Parent = building
    
    local signLabel = Instance.new("TextLabel")
    signLabel.Name = "SignText"
    signLabel.Size = UDim2.new(1, 0, 1, 0)
    signLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    signLabel.BackgroundTransparency = 0.2
    signLabel.Text = "🏪 GARDEN SHOP 🏪"
    signLabel.TextColor3 = Color3.fromRGB(25, 25, 25)
    signLabel.TextScaled = true
    signLabel.Font = Enum.Font.GothamBold
    signLabel.Parent = signGui
    
    print("🏗️ ShopManager: Created shop building placeholder at", position)
    return building
end

function ShopManager:CreateShopBuildingFromModel()
    -- Placeholder for future model loading system
    -- Falls back to Part creation if model load fails
    warn("📦 ShopManager: Model system not implemented yet, using Part fallback")
    return self:CreateShopBuildingFromPart()
end

-- ==========================================
-- SHOP NPC CREATION
-- ==========================================

function ShopManager:CreateShopNPC()
    -- Check if using model or placeholder
    if ConfigModule.USE_MODELS.ShopNPC then
        self.ShopNPC = self:CreateShopNPCFromModel()
    else
        self.ShopNPC = self:CreateShopNPCFromPart()
    end
    
    if self.ShopNPC then
        print("👤 ShopManager: Shop NPC created successfully")
    else
        warn("❌ ShopManager: Failed to create shop NPC")
    end
end

function ShopManager:CreateShopNPCFromPart()
    local config = ConfigModule.Shop.NPC
    local position = self.SpawnPosition + config.offsetFromSpawn
    
    -- Create shop NPC Part (INTERACTION POINT!)
    local npc = Instance.new("Part")
    npc.Name = "ShopNPC"
    npc.Shape = Enum.PartType.Cylinder
    npc.Size = config.size
    npc.Color = config.color
    npc.Material = config.material
    npc.Position = position + Vector3.new(0, config.size.Y/2, 0) -- Ground level + height/2
    npc.Anchored = true
    npc.CanCollide = false -- Players can walk through the NPC
    npc.Parent = Workspace
    
    -- Rotate cylinder to look like a person (standing upright)
    npc.Rotation = Vector3.new(0, 0, 90)
    
    -- Add floating nametag
    local nameGui = Instance.new("BillboardGui")
    nameGui.Name = "NPCNametag"
    nameGui.Adornee = npc
    nameGui.Size = UDim2.new(0, 200, 0, 50)
    nameGui.StudsOffset = Vector3.new(0, 4, 0)
    nameGui.Parent = npc
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = config.name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLabel.Parent = nameGui
    
    print("👤 ShopManager: Created shop NPC placeholder at", position)
    return npc
end

function ShopManager:CreateShopNPCFromModel()
    -- Placeholder for future model loading system
    -- Falls back to Part creation if model load fails
    warn("📦 ShopManager: Model system not implemented yet, using Part fallback")
    return self:CreateShopNPCFromPart()
end

-- ==========================================
-- INTERACTION SYSTEM
-- ==========================================

function ShopManager:SetupShopInteraction()
    if not self.ShopNPC then
        warn("❌ ShopManager: Cannot setup interaction - no Shop NPC found")
        return
    end
    
    -- Create ProximityPrompt on the NPC (not the building!)
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "ShopPrompt"
    prompt.ActionText = ConfigModule.Shop.NPC.promptText
    prompt.ObjectText = ConfigModule.Shop.NPC.name
    prompt.HoldDuration = 0 -- Instant activation
    prompt.MaxActivationDistance = 15
    prompt.RequiresLineOfSight = false
    prompt.Style = Enum.ProximityPromptStyle.Default
    prompt.Parent = self.ShopNPC
    
    self.ShopPrompt = prompt
    
    -- Handle interaction events
    prompt.Triggered:Connect(function(player)
        self:OnShopInteraction(player)
    end)
    
    print("🔗 ShopManager: Shop interaction system configured")
end

function ShopManager:OnShopInteraction(player)
    -- Validate interaction (anti-cheat: walking distance check)
    if not self:ValidatePlayerDistance(player) then
        warn("🚫 ShopManager: Player", player.Name, "too far from shop for interaction")
        return
    end
    
    print("🛒 ShopManager:", player.Name, "interacted with shop")
    
    -- This event will be handled by ShopUIHandler
    -- Fire custom event to notify UI system
    local remoteEvents = game.ReplicatedStorage:FindFirstChild("RemoteEvents")
    if remoteEvents then
        local shopOpenEvent = remoteEvents:FindFirstChild("OpenShop")
        if shopOpenEvent then
            shopOpenEvent:FireClient(player)
        end
    end
end

function ShopManager:ValidatePlayerDistance(player)
    if not player.Character or not player.Character.PrimaryPart then
        return false
    end
    
    local playerPosition = player.Character.PrimaryPart.Position
    local npcPosition = self.ShopNPC.Position
    local distance = (playerPosition - npcPosition).Magnitude
    
    -- Check if player is within reasonable interaction distance
    local maxDistance = ConfigModule.Security.MAX_INTERACTION_DISTANCE
    return distance <= maxDistance
end

-- ==========================================
-- SHOP POSITIONING UTILITIES
-- ==========================================

function ShopManager:GetShopBuildingPosition()
    return self.ShopBuilding and self.ShopBuilding.Position or nil
end

function ShopManager:GetShopNPCPosition()
    return self.ShopNPC and self.ShopNPC.Position or nil
end

function ShopManager:GetDistanceFromSpawn()
    if not self.ShopBuilding then return 0 end
    
    return (self.ShopBuilding.Position - self.SpawnPosition).Magnitude
end

function ShopManager:IsPlayerNearShop(player, maxDistance)
    if not player.Character or not player.Character.PrimaryPart then
        return false
    end
    
    if not self.ShopNPC then
        return false
    end
    
    local playerPosition = player.Character.PrimaryPart.Position
    local shopPosition = self.ShopNPC.Position
    local distance = (playerPosition - shopPosition).Magnitude
    
    maxDistance = maxDistance or 25 -- Default 25 stud radius
    return distance <= maxDistance
end

-- ==========================================
-- SHOP CUSTOMIZATION
-- ==========================================

function ShopManager:UpdateShopSign(newText)
    if not self.ShopBuilding then return end
    
    local signGui = self.ShopBuilding:FindFirstChild("ShopSign")
    if signGui then
        local signLabel = signGui:FindFirstChild("SignText")
        if signLabel then
            signLabel.Text = newText
            print("📝 ShopManager: Updated shop sign to:", newText)
        end
    end
end

function ShopManager:UpdateNPCName(newName)
    if not self.ShopNPC then return end
    
    local nameGui = self.ShopNPC:FindFirstChild("NPCNametag")
    if nameGui then
        local nameLabel = nameGui:FindFirstChild("NameLabel")
        if nameLabel then
            nameLabel.Text = newName
            print("📝 ShopManager: Updated NPC name to:", newName)
        end
    end
    
    -- Update prompt text
    if self.ShopPrompt then
        self.ShopPrompt.ObjectText = newName
    end
end

-- ==========================================
-- SHOP EFFECTS & ANIMATIONS
-- ==========================================

function ShopManager:AddShopEffects()
    if not self.ShopNPC then return end
    
    -- Add glowing effect to NPC (already Neon material)
    local originalTransparency = self.ShopNPC.Transparency
    
    -- Gentle pulsing effect
    spawn(function()
        while self.ShopNPC and self.ShopNPC.Parent do
            for i = 1, 10 do
                if self.ShopNPC and self.ShopNPC.Parent then
                    self.ShopNPC.Transparency = originalTransparency + (i / 50) -- Subtle fade
                    wait(0.1)
                end
            end
            for i = 10, 1, -1 do
                if self.ShopNPC and self.ShopNPC.Parent then
                    self.ShopNPC.Transparency = originalTransparency + (i / 50) -- Subtle fade
                    wait(0.1)
                end
            end
        end
    end)
    
    print("✨ ShopManager: Added glowing effects to shop NPC")
end

-- ==========================================
-- CLEANUP & MAINTENANCE
-- ==========================================

function ShopManager:CleanupShop()
    -- Remove shop building
    if self.ShopBuilding and self.ShopBuilding.Parent then
        self.ShopBuilding:Destroy()
        self.ShopBuilding = nil
    end
    
    -- Remove shop NPC
    if self.ShopNPC and self.ShopNPC.Parent then
        self.ShopNPC:Destroy()
        self.ShopNPC = nil
    end
    
    -- Clear prompt reference
    self.ShopPrompt = nil
    
    print("🗑️ ShopManager: Shop cleanup completed")
end

function ShopManager:RefreshShop()
    print("🔄 ShopManager: Refreshing shop system...")
    
    -- Cleanup existing shop
    self:CleanupShop()
    
    -- Recreate shop
    self:FindSpawnPosition()
    self:CreateShopBuilding()
    self:CreateShopNPC()
    self:SetupShopInteraction()
    self:AddShopEffects()
    
    print("✅ ShopManager: Shop refresh completed")
end

-- ==========================================
-- UTILITY FUNCTIONS
-- ==========================================

function ShopManager:GetShopInfo()
    return {
        buildingExists = self.ShopBuilding ~= nil,
        npcExists = self.ShopNPC ~= nil,
        promptExists = self.ShopPrompt ~= nil,
        buildingPosition = self:GetShopBuildingPosition(),
        npcPosition = self:GetShopNPCPosition(),
        distanceFromSpawn = self:GetDistanceFromSpawn(),
        usingModels = {
            building = ConfigModule.USE_MODELS.ShopBuilding,
            npc = ConfigModule.USE_MODELS.ShopNPC
        }
    }
end

function ShopManager:PrintShopDebugInfo()
    local info = self:GetShopInfo()
    
    print("🐛 ShopManager Debug Info:")
    print("   Building exists:", info.buildingExists)
    print("   NPC exists:", info.npcExists)
    print("   Prompt exists:", info.promptExists)
    print("   Building position:", info.buildingPosition)
    print("   NPC position:", info.npcPosition)
    print("   Distance from spawn:", string.format("%.1f studs", info.distanceFromSpawn))
    print("   Using building model:", info.usingModels.building)
    print("   Using NPC model:", info.usingModels.npc)
end

return ShopManager
