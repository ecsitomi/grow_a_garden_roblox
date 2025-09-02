--[[
    DecorationManager.lua
    Server-Side Garden Decoration System
    
    Priority: 29 (Advanced Features phase)
    Dependencies: DataStoreService, MarketplaceService, TweenService
    Used by: PlotManager, VIPManager, ShopManager
    
    Features:
    - Garden decoration placement and management
    - Decoration shop with various themes
    - VIP exclusive decorations
    - Decoration effects and bonuses
    - Seasonal decoration collections
    - Decoration trading and marketplace
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

-- Load required modules
local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)

local DecorationManager = {}
DecorationManager.__index = DecorationManager

-- ==========================================
-- INITIALIZATION & SETUP
-- ==========================================

-- Data stores
DecorationManager.DecorationStore = DataStoreService:GetDataStore("DecorationData_v1")
DecorationManager.PlacementStore = DataStoreService:GetDataStore("PlacementData_v1")

-- Decoration state tracking
DecorationManager.PlayerDecorations = {} -- [userId] = {owned = {}, placed = {}}
DecorationManager.PlacedDecorations = {} -- [decorationId] = {instance, data}
DecorationManager.DecorationShop = {}

-- Decoration categories and types
DecorationManager.DecorationCategories = {
    PLANTS = "plants",
    FURNITURE = "furniture",
    LIGHTING = "lighting",
    PATHWAYS = "pathways",
    WATER = "water",
    STATUES = "statues",
    SEASONAL = "seasonal",
    VIP = "vip"
}

-- Decoration rarities
DecorationManager.DecorationRarities = {
    COMMON = {
        color = Color3.fromRGB(155, 155, 155),
        priceMultiplier = 1.0,
        effectMultiplier = 1.0
    },
    UNCOMMON = {
        color = Color3.fromRGB(30, 255, 0),
        priceMultiplier = 2.0,
        effectMultiplier = 1.5
    },
    RARE = {
        color = Color3.fromRGB(0, 112, 255),
        priceMultiplier = 5.0,
        effectMultiplier = 2.0
    },
    EPIC = {
        color = Color3.fromRGB(163, 53, 238),
        priceMultiplier = 12.0,
        effectMultiplier = 3.0
    },
    LEGENDARY = {
        color = Color3.fromRGB(255, 128, 0),
        priceMultiplier = 25.0,
        effectMultiplier = 5.0
    }
}

-- Decoration definitions
DecorationManager.DecorationTypes = {
    -- Plants & Flowers
    flower_bed = {
        name = "Flower Bed",
        description = "Beautiful flowers that attract beneficial insects",
        category = DecorationManager.DecorationCategories.PLANTS,
        rarity = "COMMON",
        basePrice = 50,
        size = Vector3.new(4, 1, 4),
        model = "FlowerBedModel",
        effects = {
            {type = "beauty", radius = 10, value = 5},
            {type = "pollination", radius = 8, value = 1.1}
        },
        vipOnly = false,
        seasonal = false
    },
    
    rose_garden = {
        name = "Rose Garden",
        description = "Elegant roses that boost nearby plant growth",
        category = DecorationManager.DecorationCategories.PLANTS,
        rarity = "UNCOMMON",
        basePrice = 150,
        size = Vector3.new(6, 2, 6),
        model = "RoseGardenModel",
        effects = {
            {type = "beauty", radius = 15, value = 10},
            {type = "growth_boost", radius = 12, value = 1.15}
        },
        vipOnly = false,
        seasonal = false
    },
    
    rainbow_flowers = {
        name = "Rainbow Flowers",
        description = "Magical flowers that change colors and boost XP",
        category = DecorationManager.DecorationCategories.PLANTS,
        rarity = "RARE",
        basePrice = 500,
        size = Vector3.new(5, 3, 5),
        model = "RainbowFlowersModel",
        effects = {
            {type = "beauty", radius = 20, value = 20},
            {type = "xp_boost", radius = 15, value = 1.25}
        },
        vipOnly = false,
        seasonal = false
    },
    
    -- Furniture
    garden_bench = {
        name = "Garden Bench",
        description = "A comfortable place to rest and enjoy the garden",
        category = DecorationManager.DecorationCategories.FURNITURE,
        rarity = "COMMON",
        basePrice = 75,
        size = Vector3.new(3, 2, 1),
        model = "GardenBenchModel",
        effects = {
            {type = "beauty", radius = 8, value = 3},
            {type = "rest_bonus", radius = 5, value = 1.1}
        },
        vipOnly = false,
        seasonal = false
    },
    
    ornate_table = {
        name = "Ornate Garden Table",
        description = "Elegant table perfect for garden parties",
        category = DecorationManager.DecorationCategories.FURNITURE,
        rarity = "UNCOMMON",
        basePrice = 200,
        size = Vector3.new(4, 3, 4),
        model = "OrnateTableModel",
        effects = {
            {type = "beauty", radius = 12, value = 8},
            {type = "social_bonus", radius = 10, value = 1.2}
        },
        vipOnly = false,
        seasonal = false
    },
    
    royal_gazebo = {
        name = "Royal Gazebo",
        description = "Majestic gazebo fit for garden royalty",
        category = DecorationManager.DecorationCategories.FURNITURE,
        rarity = "EPIC",
        basePrice = 1500,
        size = Vector3.new(8, 6, 8),
        model = "RoyalGazeboModel",
        effects = {
            {type = "beauty", radius = 25, value = 30},
            {type = "prestige", radius = 20, value = 2.0},
            {type = "weather_protection", radius = 15, value = 1}
        },
        vipOnly = true,
        seasonal = false
    },
    
    -- Lighting
    garden_lantern = {
        name = "Garden Lantern",
        description = "Provides gentle lighting and extends growing hours",
        category = DecorationManager.DecorationCategories.LIGHTING,
        rarity = "COMMON",
        basePrice = 40,
        size = Vector3.new(1, 4, 1),
        model = "GardenLanternModel",
        effects = {
            {type = "beauty", radius = 6, value = 2},
            {type = "light", radius = 10, value = 1},
            {type = "night_growth", radius = 8, value = 1.1}
        },
        vipOnly = false,
        seasonal = false
    },
    
    fairy_lights = {
        name = "Fairy Lights",
        description = "Magical twinkling lights that boost plant happiness",
        category = DecorationManager.DecorationCategories.LIGHTING,
        rarity = "UNCOMMON",
        basePrice = 120,
        size = Vector3.new(6, 1, 1),
        model = "FairyLightsModel",
        effects = {
            {type = "beauty", radius = 12, value = 6},
            {type = "light", radius = 15, value = 1},
            {type = "happiness_boost", radius = 10, value = 1.2}
        },
        vipOnly = false,
        seasonal = false
    },
    
    crystal_chandelier = {
        name = "Crystal Chandelier",
        description = "Luxurious chandelier that creates rainbow effects",
        category = DecorationManager.DecorationCategories.LIGHTING,
        rarity = "LEGENDARY",
        basePrice = 3000,
        size = Vector3.new(4, 4, 4),
        model = "CrystalChandelierModel",
        effects = {
            {type = "beauty", radius = 30, value = 50},
            {type = "light", radius = 25, value = 2},
            {type = "rainbow_effect", radius = 20, value = 1},
            {type = "growth_boost", radius = 18, value = 1.3}
        },
        vipOnly = true,
        seasonal = false
    },
    
    -- Pathways
    stone_path = {
        name = "Stone Pathway",
        description = "Elegant stone path that improves garden accessibility",
        category = DecorationManager.DecorationCategories.PATHWAYS,
        rarity = "COMMON",
        basePrice = 20,
        size = Vector3.new(2, 0.2, 2),
        model = "StonePathModel",
        effects = {
            {type = "beauty", radius = 5, value = 1},
            {type = "movement_speed", radius = 2, value = 1.15}
        },
        vipOnly = false,
        seasonal = false,
        connectible = true
    },
    
    golden_pathway = {
        name = "Golden Pathway",
        description = "Luxurious golden path that attracts wealth",
        category = DecorationManager.DecorationCategories.PATHWAYS,
        rarity = "RARE",
        basePrice = 300,
        size = Vector3.new(2, 0.3, 2),
        model = "GoldenPathModel",
        effects = {
            {type = "beauty", radius = 8, value = 10},
            {type = "movement_speed", radius = 3, value = 1.25},
            {type = "coin_bonus", radius = 5, value = 1.1}
        },
        vipOnly = true,
        seasonal = false,
        connectible = true
    },
    
    -- Water Features
    fountain = {
        name = "Garden Fountain",
        description = "Refreshing fountain that provides water for plants",
        category = DecorationManager.DecorationCategories.WATER,
        rarity = "UNCOMMON",
        basePrice = 250,
        size = Vector3.new(4, 4, 4),
        model = "FountainModel",
        effects = {
            {type = "beauty", radius = 15, value = 12},
            {type = "water_source", radius = 12, value = 1},
            {type = "growth_boost", radius = 10, value = 1.15}
        },
        vipOnly = false,
        seasonal = false
    },
    
    koi_pond = {
        name = "Koi Pond",
        description = "Peaceful pond with koi fish that brings harmony",
        category = DecorationManager.DecorationCategories.WATER,
        rarity = "RARE",
        basePrice = 800,
        size = Vector3.new(8, 1, 8),
        model = "KoiPondModel",
        effects = {
            {type = "beauty", radius = 20, value = 25},
            {type = "water_source", radius = 15, value = 2},
            {type = "tranquility", radius = 18, value = 1.3},
            {type = "luck_boost", radius = 12, value = 1.2}
        },
        vipOnly = false,
        seasonal = false
    },
    
    -- Statues
    garden_gnome = {
        name = "Garden Gnome",
        description = "Protective gnome that wards off pests",
        category = DecorationManager.DecorationCategories.STATUES,
        rarity = "COMMON",
        basePrice = 60,
        size = Vector3.new(1, 2, 1),
        model = "GardenGnomeModel",
        effects = {
            {type = "beauty", radius = 8, value = 3},
            {type = "pest_protection", radius = 10, value = 1.2}
        },
        vipOnly = false,
        seasonal = false
    },
    
    angel_statue = {
        name = "Angel Statue",
        description = "Divine statue that blesses the garden with protection",
        category = DecorationManager.DecorationCategories.STATUES,
        rarity = "EPIC",
        basePrice = 1200,
        size = Vector3.new(3, 6, 3),
        model = "AngelStatueModel",
        effects = {
            {type = "beauty", radius = 25, value = 35},
            {type = "divine_protection", radius = 20, value = 1.5},
            {type = "healing_aura", radius = 15, value = 1.3}
        },
        vipOnly = false,
        seasonal = false
    },
    
    -- Seasonal Decorations
    pumpkin_patch = {
        name = "Pumpkin Patch",
        description = "Spooky Halloween decoration that boosts autumn crops",
        category = DecorationManager.DecorationCategories.SEASONAL,
        rarity = "UNCOMMON",
        basePrice = 100,
        size = Vector3.new(5, 2, 5),
        model = "PumpkinPatchModel",
        effects = {
            {type = "beauty", radius = 12, value = 8},
            {type = "autumn_bonus", radius = 10, value = 1.25}
        },
        vipOnly = false,
        seasonal = "autumn"
    },
    
    christmas_tree = {
        name = "Christmas Tree",
        description = "Festive tree that spreads holiday cheer",
        category = DecorationManager.DecorationCategories.SEASONAL,
        rarity = "RARE",
        basePrice = 400,
        size = Vector3.new(4, 8, 4),
        model = "ChristmasTreeModel",
        effects = {
            {type = "beauty", radius = 20, value = 20},
            {type = "holiday_cheer", radius = 15, value = 1.5},
            {type = "gift_bonus", radius = 12, value = 1.3}
        },
        vipOnly = false,
        seasonal = "winter"
    }
}

-- Decoration placement constraints
DecorationManager.PlacementRules = {
    maxDecorationsPerPlayer = 50,
    vipMaxDecorations = 100,
    minDistanceBetweenDecorations = 1,
    maxDistanceFromGarden = 50,
    allowOverlapping = false
}

-- ==========================================
-- INITIALIZATION
-- ==========================================

function DecorationManager:Initialize()
    print("🏡 DecorationManager: Initializing decoration system...")
    
    -- Set up remote events
    self:SetupRemoteEvents()
    
    -- Set up player connections
    self:SetupPlayerConnections()
    
    -- Initialize decoration shop
    self:InitializeDecorationShop()
    
    -- Start decoration effects loop
    self:StartDecorationEffectsLoop()
    
    -- Start seasonal rotation
    self:StartSeasonalRotation()
    
    print("✅ DecorationManager: Decoration system initialized")
end

function DecorationManager:SetupRemoteEvents()
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then
        remoteEvents = Instance.new("Folder")
        remoteEvents.Name = "RemoteEvents"
        remoteEvents.Parent = ReplicatedStorage
    end
    
    -- Decoration data requests
    local getDecorationsFunction = Instance.new("RemoteFunction")
    getDecorationsFunction.Name = "GetPlayerDecorations"
    getDecorationsFunction.Parent = remoteEvents
    getDecorationsFunction.OnServerInvoke = function(player)
        return self:GetPlayerDecorations(player)
    end
    
    -- Decoration placement
    local placeDecorationFunction = Instance.new("RemoteFunction")
    placeDecorationFunction.Name = "PlaceDecoration"
    placeDecorationFunction.Parent = remoteEvents
    placeDecorationFunction.OnServerInvoke = function(player, decorationType, position, rotation)
        return self:PlaceDecoration(player, decorationType, position, rotation)
    end
    
    -- Decoration removal
    local removeDecorationFunction = Instance.new("RemoteFunction")
    removeDecorationFunction.Name = "RemoveDecoration"
    removeDecorationFunction.Parent = remoteEvents
    removeDecorationFunction.OnServerInvoke = function(player, decorationId)
        return self:RemoveDecoration(player, decorationId)
    end
    
    -- Decoration purchase
    local purchaseDecorationFunction = Instance.new("RemoteFunction")
    purchaseDecorationFunction.Name = "PurchaseDecoration"
    purchaseDecorationFunction.Parent = remoteEvents
    purchaseDecorationFunction.OnServerInvoke = function(player, decorationType, quantity)
        return self:PurchaseDecoration(player, decorationType, quantity)
    end
    
    -- Shop data requests
    local getShopFunction = Instance.new("RemoteFunction")
    getShopFunction.Name = "GetDecorationShop"
    getShopFunction.Parent = remoteEvents
    getShopFunction.OnServerInvoke = function(player)
        return self:GetDecorationShop(player)
    end
end

function DecorationManager:SetupPlayerConnections()
    -- Player joined
    Players.PlayerAdded:Connect(function(player)
        self:OnPlayerJoined(player)
    end)
    
    -- Player leaving
    Players.PlayerRemoving:Connect(function(player)
        self:OnPlayerLeaving(player)
    end)
    
    -- Handle existing players
    for _, player in pairs(Players:GetPlayers()) do
        self:OnPlayerJoined(player)
    end
end

function DecorationManager:InitializeDecorationShop()
    -- Build shop inventory based on current season
    self:RefreshDecorationShop()
end

function DecorationManager:StartDecorationEffectsLoop()
    spawn(function()
        while true do
            self:UpdateDecorationEffects()
            wait(30) -- Update effects every 30 seconds
        end
    end)
end

function DecorationManager:StartSeasonalRotation()
    spawn(function()
        while true do
            wait(3600) -- Check every hour
            self:CheckSeasonalDecorations()
        end
    end)
end

-- ==========================================
-- PLAYER MANAGEMENT
-- ==========================================

function DecorationManager:OnPlayerJoined(player)
    -- Initialize player decoration data
    self.PlayerDecorations[player.UserId] = {
        owned = {},
        placed = {},
        maxDecorations = self:IsPlayerVIP(player) and 
            self.PlacementRules.vipMaxDecorations or 
            self.PlacementRules.maxDecorationsPerPlayer
    }
    
    -- Load player decoration data
    spawn(function()
        self:LoadPlayerDecorationData(player)
    end)
    
    print("🏡 DecorationManager: Player initialized:", player.Name)
end

function DecorationManager:OnPlayerLeaving(player)
    -- Save player decoration data
    spawn(function()
        self:SavePlayerDecorationData(player)
    end)
    
    -- Remove placed decorations from world
    self:RemovePlayerDecorationsFromWorld(player)
    
    -- Clean up
    self.PlayerDecorations[player.UserId] = nil
    
    print("🏡 DecorationManager: Player data saved:", player.Name)
end

function DecorationManager:LoadPlayerDecorationData(player)
    local success, playerData = pcall(function()
        return self.DecorationStore:GetAsync("player_" .. player.UserId)
    end)
    
    if success and playerData then
        self.PlayerDecorations[player.UserId] = playerData
        
        -- Update VIP decoration limit
        if self:IsPlayerVIP(player) then
            self.PlayerDecorations[player.UserId].maxDecorations = self.PlacementRules.vipMaxDecorations
        end
        
        -- Restore placed decorations to world
        self:RestorePlayerDecorations(player)
        
        print("🏡 DecorationManager: Loaded decoration data for", player.Name)
    else
        -- New player - give starter decoration
        self:GiveStarterDecoration(player)
        print("🏡 DecorationManager: New player, gave starter decoration:", player.Name)
    end
end

function DecorationManager:SavePlayerDecorationData(player)
    local playerData = self.PlayerDecorations[player.UserId]
    if not playerData then return end
    
    local success, error = pcall(function()
        self.DecorationStore:SetAsync("player_" .. player.UserId, playerData)
    end)
    
    if not success then
        warn("❌ DecorationManager: Failed to save decoration data for", player.Name, ":", error)
    end
end

function DecorationManager:GiveStarterDecoration(player)
    -- Give new players a basic garden gnome
    local playerData = self.PlayerDecorations[player.UserId]
    
    if not playerData.owned["garden_gnome"] then
        playerData.owned["garden_gnome"] = 1
    else
        playerData.owned["garden_gnome"] = playerData.owned["garden_gnome"] + 1
    end
    
    -- Notify player
    local notificationManager = _G.NotificationManager
    if notificationManager then
        notificationManager:ShowToast(
            "Welcome Gift! 🏡",
            "You received a Garden Gnome decoration!",
            "🧙‍♂️",
            "decoration"
        )
    end
end

-- ==========================================
-- DECORATION SHOP
-- ==========================================

function DecorationManager:RefreshDecorationShop()
    self.DecorationShop = {}
    
    -- Add all non-VIP decorations to shop
    for decorationType, decorationData in pairs(self.DecorationTypes) do
        if not decorationData.vipOnly then
            self.DecorationShop[decorationType] = {
                type = decorationType,
                data = decorationData,
                price = self:CalculateDecorationPrice(decorationData),
                inStock = true,
                featured = false
            }
        end
    end
    
    -- Add seasonal decorations if appropriate
    local currentSeason = self:GetCurrentSeason()
    for decorationType, decorationData in pairs(self.DecorationTypes) do
        if decorationData.seasonal == currentSeason then
            self.DecorationShop[decorationType] = {
                type = decorationType,
                data = decorationData,
                price = self:CalculateDecorationPrice(decorationData),
                inStock = true,
                featured = true,
                seasonal = true
            }
        end
    end
    
    -- Add VIP decorations for VIP players (handled in GetDecorationShop)
    
    print("🏡 DecorationManager: Decoration shop refreshed with", #self.DecorationShop, "items")
end

function DecorationManager:GetDecorationShop(player)
    local shop = {}
    
    -- Copy base shop
    for decorationType, shopItem in pairs(self.DecorationShop) do
        shop[decorationType] = shopItem
    end
    
    -- Add VIP items for VIP players
    if self:IsPlayerVIP(player) then
        for decorationType, decorationData in pairs(self.DecorationTypes) do
            if decorationData.vipOnly then
                shop[decorationType] = {
                    type = decorationType,
                    data = decorationData,
                    price = self:CalculateDecorationPrice(decorationData),
                    inStock = true,
                    featured = false,
                    vipOnly = true
                }
            end
        end
    end
    
    return shop
end

function DecorationManager:PurchaseDecoration(player, decorationType, quantity)
    local decorationData = self.DecorationTypes[decorationType]
    if not decorationData then
        return {success = false, message = "Invalid decoration type"}
    end
    
    -- Check VIP requirement
    if decorationData.vipOnly and not self:IsPlayerVIP(player) then
        return {success = false, message = "VIP membership required"}
    end
    
    -- Check seasonal availability
    if decorationData.seasonal then
        local currentSeason = self:GetCurrentSeason()
        if decorationData.seasonal ~= currentSeason then
            return {success = false, message = "Decoration not available this season"}
        end
    end
    
    -- Calculate total price
    local unitPrice = self:CalculateDecorationPrice(decorationData)
    local totalPrice = unitPrice * quantity
    
    -- Check if player has enough coins
    local economyManager = _G.EconomyManager
    if not economyManager or not economyManager:HasCurrency(player, totalPrice) then
        return {success = false, message = "Not enough coins"}
    end
    
    -- Purchase decoration
    economyManager:RemoveCurrency(player, totalPrice)
    
    -- Add to player's owned decorations
    local playerData = self.PlayerDecorations[player.UserId]
    if not playerData.owned[decorationType] then
        playerData.owned[decorationType] = 0
    end
    playerData.owned[decorationType] = playerData.owned[decorationType] + quantity
    
    -- Notify player
    local notificationManager = _G.NotificationManager
    if notificationManager then
        notificationManager:ShowToast(
            "Decoration Purchased! 🏡",
            "You bought " .. quantity .. "x " .. decorationData.name,
            "🛍️",
            "purchase"
        )
    end
    
    return {success = true, message = "Decoration purchased successfully"}
end

function DecorationManager:CalculateDecorationPrice(decorationData)
    local rarityData = self.DecorationRarities[decorationData.rarity]
    local basePrice = decorationData.basePrice
    local rarityMultiplier = rarityData.priceMultiplier
    
    return math.floor(basePrice * rarityMultiplier)
end

-- ==========================================
-- DECORATION PLACEMENT
-- ==========================================

function DecorationManager:PlaceDecoration(player, decorationType, position, rotation)
    local playerData = self.PlayerDecorations[player.UserId]
    local decorationData = self.DecorationTypes[decorationType]
    
    if not decorationData then
        return {success = false, message = "Invalid decoration type"}
    end
    
    -- Check if player owns this decoration
    if not playerData.owned[decorationType] or playerData.owned[decorationType] <= 0 then
        return {success = false, message = "You don't own this decoration"}
    end
    
    -- Check placement limits
    if #playerData.placed >= playerData.maxDecorations then
        return {success = false, message = "Maximum decorations reached"}
    end
    
    -- Validate placement position
    local placementResult = self:ValidatePlacement(player, decorationType, position)
    if not placementResult.valid then
        return {success = false, message = placementResult.reason}
    end
    
    -- Create decoration instance
    local decorationInstance = self:CreateDecorationInstance(decorationType, position, rotation)
    if not decorationInstance then
        return {success = false, message = "Failed to create decoration"}
    end
    
    -- Create decoration record
    local decorationId = HttpService:GenerateGUID()
    local decorationRecord = {
        id = decorationId,
        type = decorationType,
        position = position,
        rotation = rotation,
        placedTime = tick(),
        owner = player.UserId
    }
    
    -- Add to player's placed decorations
    playerData.placed[decorationId] = decorationRecord
    
    -- Add to global placed decorations
    self.PlacedDecorations[decorationId] = {
        instance = decorationInstance,
        data = decorationRecord
    }
    
    -- Consume decoration from inventory
    playerData.owned[decorationType] = playerData.owned[decorationType] - 1
    
    -- Apply decoration effects
    self:ApplyDecorationEffects(decorationId)
    
    -- Notify player
    local notificationManager = _G.NotificationManager
    if notificationManager then
        notificationManager:ShowToast(
            "Decoration Placed! 🏡",
            decorationData.name .. " placed successfully",
            "✨",
            "placement"
        )
    end
    
    return {success = true, message = "Decoration placed successfully", decorationId = decorationId}
end

function DecorationManager:RemoveDecoration(player, decorationId)
    local playerData = self.PlayerDecorations[player.UserId]
    local placedDecoration = playerData.placed[decorationId]
    
    if not placedDecoration then
        return {success = false, message = "Decoration not found"}
    end
    
    -- Check ownership
    if placedDecoration.owner ~= player.UserId then
        return {success = false, message = "You don't own this decoration"}
    end
    
    -- Remove decoration instance from world
    local globalDecoration = self.PlacedDecorations[decorationId]
    if globalDecoration and globalDecoration.instance then
        globalDecoration.instance:Destroy()
    end
    
    -- Return decoration to inventory
    local decorationType = placedDecoration.type
    if not playerData.owned[decorationType] then
        playerData.owned[decorationType] = 0
    end
    playerData.owned[decorationType] = playerData.owned[decorationType] + 1
    
    -- Remove from placed decorations
    playerData.placed[decorationId] = nil
    self.PlacedDecorations[decorationId] = nil
    
    -- Remove decoration effects
    self:RemoveDecorationEffects(decorationId)
    
    return {success = true, message = "Decoration removed successfully"}
end

function DecorationManager:ValidatePlacement(player, decorationType, position)
    local decorationData = self.DecorationTypes[decorationType]
    
    -- Check if position is within garden bounds
    local plotManager = _G.PlotManager
    if plotManager then
        local gardenCenter = plotManager:GetPlayerGardenCenter(player)
        if gardenCenter then
            local distance = (position - gardenCenter).Magnitude
            if distance > self.PlacementRules.maxDistanceFromGarden then
                return {valid = false, reason = "Too far from your garden"}
            end
        end
    end
    
    -- Check for overlapping decorations
    if not self.PlacementRules.allowOverlapping then
        for _, placedData in pairs(self.PlacedDecorations) do
            local placedPosition = placedData.data.position
            local distance = (position - placedPosition).Magnitude
            
            if distance < self.PlacementRules.minDistanceBetweenDecorations then
                return {valid = false, reason = "Too close to another decoration"}
            end
        end
    end
    
    -- Check if position is clear (no obstacles)
    if self:IsPositionObstructed(position, decorationData.size) then
        return {valid = false, reason = "Position is obstructed"}
    end
    
    return {valid = true}
end

function DecorationManager:IsPositionObstructed(position, size)
    -- Check for obstructions using raycasting
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {}
    
    -- Check multiple points around the decoration size
    local checkPoints = {
        position,
        position + Vector3.new(size.X/2, 0, 0),
        position + Vector3.new(-size.X/2, 0, 0),
        position + Vector3.new(0, 0, size.Z/2),
        position + Vector3.new(0, 0, -size.Z/2)
    }
    
    for _, point in ipairs(checkPoints) do
        local raycastResult = workspace:Raycast(
            point + Vector3.new(0, 10, 0),
            Vector3.new(0, -20, 0),
            raycastParams
        )
        
        if raycastResult and raycastResult.Instance.Name ~= "Baseplate" then
            return true -- Obstructed
        end
    end
    
    return false -- Clear
end

function DecorationManager:CreateDecorationInstance(decorationType, position, rotation)
    local decorationData = self.DecorationTypes[decorationType]
    
    -- Create decoration model (placeholder)
    local decorationModel = Instance.new("Model")
    decorationModel.Name = decorationData.name
    decorationModel.Parent = workspace
    
    -- Create decoration part
    local decorationPart = Instance.new("Part")
    decorationPart.Name = "DecorationBase"
    decorationPart.Size = decorationData.size
    decorationPart.Material = Enum.Material.Neon
    decorationPart.Anchored = true
    decorationPart.CanCollide = false
    decorationPart.Parent = decorationModel
    
    -- Set decoration color based on rarity
    local rarityData = self.DecorationRarities[decorationData.rarity]
    decorationPart.Color = rarityData.color
    
    -- Position and rotation
    decorationPart.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation or 0), 0)
    decorationModel.PrimaryPart = decorationPart
    
    -- Add name display
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Size = UDim2.new(0, 200, 0, 50)
    billboardGui.StudsOffset = Vector3.new(0, decorationData.size.Y + 1, 0)
    billboardGui.Parent = decorationPart
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = decorationData.name
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.SourceSansBold
    nameLabel.Parent = billboardGui
    
    -- Add special effects based on decoration type
    self:AddDecorationVisualEffects(decorationModel, decorationType)
    
    return decorationModel
end

function DecorationManager:AddDecorationVisualEffects(model, decorationType)
    local decorationData = self.DecorationTypes[decorationType]
    
    -- Add lighting effects for lighting category
    if decorationData.category == self.DecorationCategories.LIGHTING then
        local light = Instance.new("PointLight")
        light.Brightness = 1
        light.Range = 15
        light.Color = Color3.new(1, 1, 0.8)
        light.Parent = model.PrimaryPart
    end
    
    -- Add particle effects for special decorations
    if decorationType == "fountain" or decorationType == "koi_pond" then
        local attachment = Instance.new("Attachment")
        attachment.Parent = model.PrimaryPart
        
        local waterParticles = Instance.new("ParticleEmitter")
        waterParticles.Texture = "rbxasset://textures/particles/smoke_main.dds"
        waterParticles.Color = ColorSequence.new(Color3.fromRGB(173, 216, 230))
        waterParticles.Size = NumberSequence.new(0.1, 0.5)
        waterParticles.Transparency = NumberSequence.new(0.3, 1)
        waterParticles.Lifetime = NumberRange.new(1, 3)
        waterParticles.Rate = 20
        waterParticles.Speed = NumberRange.new(2, 5)
        waterParticles.Parent = attachment
    end
    
    -- Add sparkle effects for rare decorations
    if decorationData.rarity == "RARE" or decorationData.rarity == "EPIC" or decorationData.rarity == "LEGENDARY" then
        local attachment = Instance.new("Attachment")
        attachment.Parent = model.PrimaryPart
        
        local sparkles = Instance.new("ParticleEmitter")
        sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
        sparkles.Size = NumberSequence.new(0.2, 0.8)
        sparkles.Transparency = NumberSequence.new(0, 1)
        sparkles.Lifetime = NumberRange.new(0.5, 2)
        sparkles.Rate = 10
        sparkles.Speed = NumberRange.new(1, 3)
        sparkles.Parent = attachment
    end
end

-- ==========================================
-- DECORATION EFFECTS
-- ==========================================

function DecorationManager:ApplyDecorationEffects(decorationId)
    local placedDecoration = self.PlacedDecorations[decorationId]
    if not placedDecoration then return end
    
    local decorationData = self.DecorationTypes[placedDecoration.data.type]
    if not decorationData.effects then return end
    
    -- Apply each effect
    for _, effect in ipairs(decorationData.effects) do
        self:ApplySingleDecorationEffect(decorationId, effect)
    end
end

function DecorationManager:ApplySingleDecorationEffect(decorationId, effect)
    local placedDecoration = self.PlacedDecorations[decorationId]
    local position = placedDecoration.data.position
    
    if effect.type == "beauty" then
        -- Beauty effect increases garden aesthetics
        self:ApplyBeautyEffect(decorationId, position, effect.radius, effect.value)
        
    elseif effect.type == "growth_boost" then
        -- Growth boost affects nearby plants
        self:ApplyGrowthBoostEffect(decorationId, position, effect.radius, effect.value)
        
    elseif effect.type == "xp_boost" then
        -- XP boost affects player when nearby
        self:ApplyXPBoostEffect(decorationId, position, effect.radius, effect.value)
        
    elseif effect.type == "light" then
        -- Light effect for night growing
        self:ApplyLightEffect(decorationId, position, effect.radius, effect.value)
        
    elseif effect.type == "water_source" then
        -- Water source for plant hydration
        self:ApplyWaterSourceEffect(decorationId, position, effect.radius, effect.value)
        
    elseif effect.type == "pest_protection" then
        -- Protection from pests
        self:ApplyPestProtectionEffect(decorationId, position, effect.radius, effect.value)
    end
end

function DecorationManager:ApplyBeautyEffect(decorationId, position, radius, value)
    -- Beauty effect implementation
    -- This would typically affect garden rating and visitor attraction
end

function DecorationManager:ApplyGrowthBoostEffect(decorationId, position, radius, value)
    -- Apply growth boost to nearby plants
    local plotManager = _G.PlotManager
    if not plotManager then return end
    
    local nearbyPlots = plotManager:GetPlotsInRadius(position, radius)
    for _, plot in ipairs(nearbyPlots) do
        if plot.plant then
            plot.plant.growthMultiplier = (plot.plant.growthMultiplier or 1.0) * value
        end
    end
end

function DecorationManager:ApplyXPBoostEffect(decorationId, position, radius, value)
    -- XP boost effect for players in range
    -- This would be checked when players gain XP
end

function DecorationManager:ApplyLightEffect(decorationId, position, radius, value)
    -- Light effect for night growing
    local plotManager = _G.PlotManager
    if not plotManager then return end
    
    local nearbyPlots = plotManager:GetPlotsInRadius(position, radius)
    for _, plot in ipairs(nearbyPlots) do
        if plot.plant then
            plot.plant.hasLight = true
        end
    end
end

function DecorationManager:ApplyWaterSourceEffect(decorationId, position, radius, value)
    -- Water source effect
    local plotManager = _G.PlotManager
    if not plotManager then return end
    
    local nearbyPlots = plotManager:GetPlotsInRadius(position, radius)
    for _, plot in ipairs(nearbyPlots) do
        if plot.plant then
            plot.plant.waterLevel = math.min(100, (plot.plant.waterLevel or 50) + value * 10)
        end
    end
end

function DecorationManager:ApplyPestProtectionEffect(decorationId, position, radius, value)
    -- Pest protection effect
    local plotManager = _G.PlotManager
    if not plotManager then return end
    
    local nearbyPlots = plotManager:GetPlotsInRadius(position, radius)
    for _, plot in ipairs(nearbyPlots) do
        if plot.plant then
            plot.plant.pestProtection = (plot.plant.pestProtection or 1.0) * value
        end
    end
end

function DecorationManager:RemoveDecorationEffects(decorationId)
    -- Remove all effects applied by this decoration
    -- This would require tracking which effects belong to which decorations
end

function DecorationManager:UpdateDecorationEffects()
    -- Periodically update all decoration effects
    for decorationId, _ in pairs(self.PlacedDecorations) do
        self:ApplyDecorationEffects(decorationId)
    end
end

-- ==========================================
-- SEASONAL SYSTEM
-- ==========================================

function DecorationManager:GetCurrentSeason()
    local weatherManager = _G.WeatherManager
    if weatherManager then
        local weather = weatherManager:GetCurrentWeather()
        return weather.season
    end
    
    -- Fallback to real-world season
    local month = tonumber(os.date("%m"))
    if month >= 3 and month <= 5 then
        return "spring"
    elseif month >= 6 and month <= 8 then
        return "summer"
    elseif month >= 9 and month <= 11 then
        return "autumn"
    else
        return "winter"
    end
end

function DecorationManager:CheckSeasonalDecorations()
    local currentSeason = self:GetCurrentSeason()
    
    -- Refresh shop to include seasonal items
    self:RefreshDecorationShop()
    
    -- Notify players about seasonal decorations
    local notificationManager = _G.NotificationManager
    if notificationManager then
        for _, player in pairs(Players:GetPlayers()) do
            notificationManager:ShowToast(
                "Seasonal Decorations! 🗓️",
                "New " .. currentSeason .. " decorations available!",
                "🎉",
                "seasonal"
            )
        end
    end
end

-- ==========================================
-- HELPER FUNCTIONS
-- ==========================================

function DecorationManager:IsPlayerVIP(player)
    local vipManager = _G.VIPManager
    if vipManager then
        return vipManager:IsPlayerVIP(player)
    end
    return false
end

function DecorationManager:GetPlayerDecorations(player)
    local playerData = self.PlayerDecorations[player.UserId]
    if not playerData then return {} end
    
    return {
        owned = playerData.owned,
        placed = playerData.placed,
        maxDecorations = playerData.maxDecorations
    }
end

function DecorationManager:RestorePlayerDecorations(player)
    local playerData = self.PlayerDecorations[player.UserId]
    
    -- Recreate all placed decorations
    for decorationId, decorationRecord in pairs(playerData.placed) do
        local instance = self:CreateDecorationInstance(
            decorationRecord.type,
            decorationRecord.position,
            decorationRecord.rotation
        )
        
        if instance then
            self.PlacedDecorations[decorationId] = {
                instance = instance,
                data = decorationRecord
            }
            
            self:ApplyDecorationEffects(decorationId)
        end
    end
end

function DecorationManager:RemovePlayerDecorationsFromWorld(player)
    local playerData = self.PlayerDecorations[player.UserId]
    if not playerData then return end
    
    -- Remove all placed decorations from world
    for decorationId, _ in pairs(playerData.placed) do
        local globalDecoration = self.PlacedDecorations[decorationId]
        if globalDecoration and globalDecoration.instance then
            globalDecoration.instance:Destroy()
        end
        self.PlacedDecorations[decorationId] = nil
    end
end

-- ==========================================
-- PUBLIC API
-- ==========================================

function DecorationManager:GetDecorationEffectsForPlayer(player)
    -- Calculate total decoration effects affecting a player
    local totalEffects = {}
    
    local playerData = self.PlayerDecorations[player.UserId]
    if not playerData then return totalEffects end
    
    for decorationId, _ in pairs(playerData.placed) do
        local decorationRecord = playerData.placed[decorationId]
        local decorationData = self.DecorationTypes[decorationRecord.type]
        
        if decorationData.effects then
            for _, effect in ipairs(decorationData.effects) do
                if not totalEffects[effect.type] then
                    totalEffects[effect.type] = 0
                end
                totalEffects[effect.type] = totalEffects[effect.type] + effect.value
            end
        end
    end
    
    return totalEffects
end

function DecorationManager:GetGardenBeautyScore(player)
    local effects = self:GetDecorationEffectsForPlayer(player)
    return effects.beauty or 0
end

function DecorationManager:CanPlaceDecoration(player, decorationType, position)
    local validation = self:ValidatePlacement(player, decorationType, position)
    return validation.valid, validation.reason
end

-- ==========================================
-- CLEANUP
-- ==========================================

function DecorationManager:Cleanup()
    -- Remove all decoration instances from world
    for decorationId, decorationData in pairs(self.PlacedDecorations) do
        if decorationData.instance then
            decorationData.instance:Destroy()
        end
    end
    
    -- Save all player decoration data
    for userId, _ in pairs(self.PlayerDecorations) do
        local player = Players:GetPlayerByUserId(userId)
        if player then
            self:SavePlayerDecorationData(player)
        end
    end
    
    print("🏡 DecorationManager: Decoration system cleaned up")
end

return DecorationManager
