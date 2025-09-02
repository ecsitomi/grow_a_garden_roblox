--[[
    PetManager.lua
    Server-Side Pet Companion System
    
    Priority: 28 (Advanced Features phase)
    Dependencies: DataStoreService, TweenService, PathfindingService
    Used by: PlantManager, QuestManager, VIPManager
    
    Features:
    - Pet collection and breeding system
    - Automated garden assistance
    - Pet training and evolution
    - VIP exclusive pets
    - Pet interactions and animations
    - Pet marketplace and trading
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local TweenService = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

-- Load required modules
local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)

local PetManager = {}
PetManager.__index = PetManager

-- ==========================================
-- INITIALIZATION & SETUP
-- ==========================================

-- Data stores
PetManager.PetStore = DataStoreService:GetDataStore("PetData_v1")
PetManager.BreedingStore = DataStoreService:GetDataStore("BreedingData_v1")

-- Pet state tracking
PetManager.PlayerPets = {} -- [userId] = {pets = {}, activePet = nil}
PetManager.ActivePets = {} -- [petId] = {pet instance, behavior state}
PetManager.PetMarketplace = {}

-- Pet types and rarities
PetManager.PetRarities = {
    COMMON = {
        color = Color3.fromRGB(155, 155, 155),
        multiplier = 1.0,
        dropRate = 0.7,
        maxStats = 50
    },
    UNCOMMON = {
        color = Color3.fromRGB(30, 255, 0),
        multiplier = 1.5,
        dropRate = 0.2,
        maxStats = 75
    },
    RARE = {
        color = Color3.fromRGB(0, 112, 255),
        multiplier = 2.0,
        dropRate = 0.07,
        maxStats = 100
    },
    EPIC = {
        color = Color3.fromRGB(163, 53, 238),
        multiplier = 3.0,
        dropRate = 0.025,
        maxStats = 150
    },
    LEGENDARY = {
        color = Color3.fromRGB(255, 128, 0),
        multiplier = 5.0,
        dropRate = 0.005,
        maxStats = 200
    }
}

-- Pet species definitions
PetManager.PetSpecies = {
    rabbit = {
        name = "Garden Rabbit",
        description = "A helpful rabbit that assists with planting",
        rarity = "COMMON",
        baseStats = {speed = 10, strength = 5, intelligence = 8},
        abilities = {"auto_plant", "dig_holes"},
        evolution = {level = 25, evolves_to = "super_rabbit"},
        model = "RabbitModel", -- Placeholder
        sounds = {"rabbit_hop", "rabbit_nibble"},
        vipOnly = false
    },
    
    bee = {
        name = "Busy Bee",
        description = "Increases plant growth speed with pollination",
        rarity = "COMMON",
        baseStats = {speed = 15, strength = 3, intelligence = 12},
        abilities = {"pollinate", "auto_harvest"},
        evolution = {level = 30, evolves_to = "queen_bee"},
        model = "BeeModel",
        sounds = {"bee_buzz", "bee_pollinate"},
        vipOnly = false
    },
    
    owl = {
        name = "Wise Owl",
        description = "Provides XP bonuses and predicts weather",
        rarity = "UNCOMMON",
        baseStats = {speed = 8, strength = 6, intelligence = 20},
        abilities = {"xp_boost", "weather_predict"},
        evolution = {level = 40, evolves_to = "ancient_owl"},
        model = "OwlModel",
        sounds = {"owl_hoot", "owl_wisdom"},
        vipOnly = false
    },
    
    cat = {
        name = "Garden Cat",
        description = "Protects crops from pests and brings luck",
        rarity = "UNCOMMON",
        baseStats = {speed = 12, strength = 10, intelligence = 15},
        abilities = {"pest_control", "luck_boost"},
        evolution = {level = 35, evolves_to = "mystical_cat"},
        model = "CatModel",
        sounds = {"cat_meow", "cat_purr"},
        vipOnly = false
    },
    
    dragon = {
        name = "Garden Dragon",
        description = "Powerful dragon that accelerates all garden activities",
        rarity = "RARE",
        baseStats = {speed = 20, strength = 25, intelligence = 30},
        abilities = {"fire_boost", "time_acceleration", "auto_sell"},
        evolution = {level = 50, evolves_to = "elder_dragon"},
        model = "DragonModel",
        sounds = {"dragon_roar", "dragon_fire"},
        vipOnly = false
    },
    
    phoenix = {
        name = "Golden Phoenix",
        description = "Legendary bird that doubles all rewards",
        rarity = "EPIC",
        baseStats = {speed = 25, strength = 20, intelligence = 35},
        abilities = {"rebirth", "double_rewards", "weather_control"},
        evolution = {level = 75, evolves_to = "eternal_phoenix"},
        model = "PhoenixModel",
        sounds = {"phoenix_song", "phoenix_flame"},
        vipOnly = true
    },
    
    unicorn = {
        name = "Rainbow Unicorn",
        description = "Magical unicorn with healing and growth powers",
        rarity = "LEGENDARY",
        baseStats = {speed = 30, strength = 15, intelligence = 40},
        abilities = {"healing_aura", "rainbow_growth", "instant_mature"},
        evolution = nil, -- Already max form
        model = "UnicornModel",
        sounds = {"unicorn_neigh", "magical_sparkle"},
        vipOnly = true
    }
}

-- Pet abilities and their effects
PetManager.PetAbilities = {
    auto_plant = {
        name = "Auto Plant",
        description = "Automatically plants seeds in empty plots",
        cooldown = 60,
        effect = function(pet, player) 
            return PetManager:AutoPlantSeeds(pet, player)
        end
    },
    
    auto_harvest = {
        name = "Auto Harvest",
        description = "Automatically harvests mature plants",
        cooldown = 45,
        effect = function(pet, player)
            return PetManager:AutoHarvestPlants(pet, player)
        end
    },
    
    auto_sell = {
        name = "Auto Sell",
        description = "Automatically sells harvested crops",
        cooldown = 30,
        effect = function(pet, player)
            return PetManager:AutoSellCrops(pet, player)
        end
    },
    
    pollinate = {
        name = "Pollinate",
        description = "Increases plant growth speed by 25%",
        cooldown = 120,
        duration = 300,
        effect = function(pet, player)
            return PetManager:BoostPlantGrowth(pet, player, 1.25, 300)
        end
    },
    
    xp_boost = {
        name = "XP Boost",
        description = "Increases XP gain by 50% for 5 minutes",
        cooldown = 600,
        duration = 300,
        effect = function(pet, player)
            return PetManager:BoostXPGain(pet, player, 1.5, 300)
        end
    },
    
    luck_boost = {
        name = "Luck Boost",
        description = "Increases rare seed drop chance",
        cooldown = 300,
        duration = 180,
        effect = function(pet, player)
            return PetManager:BoostLuck(pet, player, 2.0, 180)
        end
    },
    
    pest_control = {
        name = "Pest Control",
        description = "Prevents crop damage and disease",
        cooldown = 180,
        duration = 600,
        effect = function(pet, player)
            return PetManager:ActivatePestControl(pet, player, 600)
        end
    },
    
    weather_predict = {
        name = "Weather Predict",
        description = "Shows upcoming weather changes",
        cooldown = 900,
        effect = function(pet, player)
            return PetManager:PredictWeather(pet, player)
        end
    },
    
    fire_boost = {
        name = "Fire Boost",
        description = "Dragon fire accelerates all activities",
        cooldown = 1200,
        duration = 600,
        effect = function(pet, player)
            return PetManager:ActivateFireBoost(pet, player, 600)
        end
    },
    
    time_acceleration = {
        name = "Time Acceleration",
        description = "Speeds up plant growth by 200%",
        cooldown = 1800,
        duration = 300,
        effect = function(pet, player)
            return PetManager:AccelerateTime(pet, player, 3.0, 300)
        end
    },
    
    rebirth = {
        name = "Rebirth",
        description = "Instantly revives dead plants",
        cooldown = 3600,
        effect = function(pet, player)
            return PetManager:RevivePlants(pet, player)
        end
    },
    
    double_rewards = {
        name = "Double Rewards",
        description = "Doubles all harvest rewards",
        cooldown = 1800,
        duration = 900,
        effect = function(pet, player)
            return PetManager:DoubleRewards(pet, player, 900)
        end
    },
    
    weather_control = {
        name = "Weather Control",
        description = "Can change weather to sunny",
        cooldown = 7200,
        effect = function(pet, player)
            return PetManager:ControlWeather(pet, player, "sunny")
        end
    },
    
    healing_aura = {
        name = "Healing Aura",
        description = "Heals and protects all plants",
        cooldown = 1200,
        duration = 1800,
        effect = function(pet, player)
            return PetManager:ActivateHealingAura(pet, player, 1800)
        end
    },
    
    rainbow_growth = {
        name = "Rainbow Growth",
        description = "Plants grow in magical rainbow colors",
        cooldown = 900,
        duration = 600,
        effect = function(pet, player)
            return PetManager:ActivateRainbowGrowth(pet, player, 600)
        end
    },
    
    instant_mature = {
        name = "Instant Mature",
        description = "Instantly matures one random plant",
        cooldown = 1800,
        effect = function(pet, player)
            return PetManager:InstantMature(pet, player)
        end
    }
}

-- Pet behavior states
PetManager.PetBehaviors = {
    IDLE = "idle",
    FOLLOWING = "following",
    WORKING = "working",
    PLAYING = "playing",
    SLEEPING = "sleeping"
}

-- ==========================================
-- INITIALIZATION
-- ==========================================

function PetManager:Initialize()
    print("🐾 PetManager: Initializing pet system...")
    
    -- Set up remote events
    self:SetupRemoteEvents()
    
    -- Set up player connections
    self:SetupPlayerConnections()
    
    -- Start pet behavior loop
    self:StartPetBehaviorLoop()
    
    -- Initialize pet marketplace
    self:InitializePetMarketplace()
    
    print("✅ PetManager: Pet system initialized")
end

function PetManager:SetupRemoteEvents()
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then
        remoteEvents = Instance.new("Folder")
        remoteEvents.Name = "RemoteEvents"
        remoteEvents.Parent = ReplicatedStorage
    end
    
    -- Pet data requests
    local getPetsFunction = Instance.new("RemoteFunction")
    getPetsFunction.Name = "GetPlayerPets"
    getPetsFunction.Parent = remoteEvents
    getPetsFunction.OnServerInvoke = function(player)
        return self:GetPlayerPets(player)
    end
    
    -- Pet summoning
    local summonPetFunction = Instance.new("RemoteFunction")
    summonPetFunction.Name = "SummonPet"
    summonPetFunction.Parent = remoteEvents
    summonPetFunction.OnServerInvoke = function(player, petId)
        return self:SummonPet(player, petId)
    end
    
    -- Pet dismissal
    local dismissPetFunction = Instance.new("RemoteFunction")
    dismissPetFunction.Name = "DismissPet"
    dismissPetFunction.Parent = remoteEvents
    dismissPetFunction.OnServerInvoke = function(player)
        return self:DismissPet(player)
    end
    
    -- Pet ability usage
    local useAbilityFunction = Instance.new("RemoteFunction")
    useAbilityFunction.Name = "UsePetAbility"
    useAbilityFunction.Parent = remoteEvents
    useAbilityFunction.OnServerInvoke = function(player, abilityName)
        return self:UsePetAbility(player, abilityName)
    end
    
    -- Pet feeding
    local feedPetFunction = Instance.new("RemoteFunction")
    feedPetFunction.Name = "FeedPet"
    feedPetFunction.Parent = remoteEvents
    feedPetFunction.OnServerInvoke = function(player, petId, foodType)
        return self:FeedPet(player, petId, foodType)
    end
    
    -- Pet breeding
    local breedPetsFunction = Instance.new("RemoteFunction")
    breedPetsFunction.Name = "BreedPets"
    breedPetsFunction.Parent = remoteEvents
    breedPetsFunction.OnServerInvoke = function(player, pet1Id, pet2Id)
        return self:BreedPets(player, pet1Id, pet2Id)
    end
end

function PetManager:SetupPlayerConnections()
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

function PetManager:StartPetBehaviorLoop()
    spawn(function()
        while true do
            -- Update all active pets
            for petId, petData in pairs(self.ActivePets) do
                self:UpdatePetBehavior(petId, petData)
            end
            
            -- Process pet abilities
            self:ProcessPetAbilities()
            
            -- Update pet stats and experience
            self:UpdatePetStats()
            
            wait(5) -- Update every 5 seconds
        end
    end)
end

function PetManager:InitializePetMarketplace()
    -- Generate random pets for marketplace
    self:GenerateMarketplacePets()
    
    -- Start marketplace refresh cycle
    spawn(function()
        while true do
            wait(3600) -- Refresh every hour
            self:RefreshMarketplace()
        end
    end)
end

-- ==========================================
-- PLAYER MANAGEMENT
-- ==========================================

function PetManager:OnPlayerJoined(player)
    -- Initialize player pet data
    self.PlayerPets[player.UserId] = {
        pets = {},
        activePet = nil,
        petSlots = self:IsPlayerVIP(player) and 6 or 3,
        lastFeedTime = {},
        breedingCooldown = 0
    }
    
    -- Load player pet data
    spawn(function()
        self:LoadPlayerPetData(player)
    end)
    
    print("🐾 PetManager: Player initialized:", player.Name)
end

function PetManager:OnPlayerLeaving(player)
    -- Dismiss active pet
    self:DismissPet(player)
    
    -- Save player pet data
    spawn(function()
        self:SavePlayerPetData(player)
    end)
    
    -- Clean up
    self.PlayerPets[player.UserId] = nil
    
    print("🐾 PetManager: Player data saved:", player.Name)
end

function PetManager:LoadPlayerPetData(player)
    local success, playerData = pcall(function()
        return self.PetStore:GetAsync("player_" .. player.UserId)
    end)
    
    if success and playerData then
        self.PlayerPets[player.UserId] = playerData
        
        -- Ensure VIP has correct pet slots
        if self:IsPlayerVIP(player) then
            self.PlayerPets[player.UserId].petSlots = 6
        end
        
        print("🐾 PetManager: Loaded pet data for", player.Name)
    else
        -- New player - give starter pet
        self:GiveStarterPet(player)
        print("🐾 PetManager: New player, gave starter pet:", player.Name)
    end
end

function PetManager:SavePlayerPetData(player)
    local playerData = self.PlayerPets[player.UserId]
    if not playerData then return end
    
    local success, error = pcall(function()
        self.PetStore:SetAsync("player_" .. player.UserId, playerData)
    end)
    
    if not success then
        warn("❌ PetManager: Failed to save pet data for", player.Name, ":", error)
    end
end

function PetManager:GiveStarterPet(player)
    -- Give new players a basic rabbit pet
    local starterPet = self:CreateNewPet("rabbit", "COMMON", 1)
    
    local playerData = self.PlayerPets[player.UserId]
    playerData.pets[starterPet.id] = starterPet
    
    -- Notify player
    local notificationManager = _G.NotificationManager
    if notificationManager then
        notificationManager:ShowToast(
            "Welcome Gift! 🐾",
            "You received a Garden Rabbit companion!",
            "🐰",
            "pet"
        )
    end
end

-- ==========================================
-- PET CREATION & MANAGEMENT
-- ==========================================

function PetManager:CreateNewPet(species, rarity, level)
    local speciesData = self.PetSpecies[species]
    local rarityData = self.PetRarities[rarity]
    
    if not speciesData or not rarityData then
        warn("❌ PetManager: Invalid species or rarity:", species, rarity)
        return nil
    end
    
    local pet = {
        id = HttpService:GenerateGUID(),
        species = species,
        rarity = rarity,
        level = level or 1,
        experience = 0,
        experienceToNext = self:CalculateExperienceRequired(level or 1),
        
        -- Base stats with rarity multiplier
        stats = {
            speed = math.floor(speciesData.baseStats.speed * rarityData.multiplier),
            strength = math.floor(speciesData.baseStats.strength * rarityData.multiplier),
            intelligence = math.floor(speciesData.baseStats.intelligence * rarityData.multiplier)
        },
        
        -- Pet info
        name = speciesData.name,
        description = speciesData.description,
        abilities = speciesData.abilities,
        evolution = speciesData.evolution,
        model = speciesData.model,
        sounds = speciesData.sounds,
        vipOnly = speciesData.vipOnly,
        
        -- State
        happiness = 100,
        hunger = 100,
        energy = 100,
        
        -- Timestamps
        createdTime = tick(),
        lastFedTime = tick(),
        lastActiveTime = tick(),
        
        -- Ability cooldowns
        abilityCooldowns = {}
    }
    
    -- Initialize ability cooldowns
    for _, abilityName in ipairs(pet.abilities) do
        pet.abilityCooldowns[abilityName] = 0
    end
    
    return pet
end

function PetManager:SummonPet(player, petId)
    local playerData = self.PlayerPets[player.UserId]
    local pet = playerData.pets[petId]
    
    if not pet then
        return {success = false, message = "Pet not found"}
    end
    
    -- Dismiss current pet if any
    if playerData.activePet then
        self:DismissPet(player)
    end
    
    -- Create pet instance in world
    local petInstance = self:CreatePetInstance(player, pet)
    if not petInstance then
        return {success = false, message = "Failed to create pet instance"}
    end
    
    -- Set as active pet
    playerData.activePet = petId
    self.ActivePets[petId] = {
        instance = petInstance,
        pet = pet,
        player = player,
        behavior = self.PetBehaviors.FOLLOWING,
        lastBehaviorChange = tick(),
        targetPosition = nil,
        activeEffects = {}
    }
    
    -- Start following behavior
    self:StartFollowingBehavior(petId)
    
    -- Notify player
    local notificationManager = _G.NotificationManager
    if notificationManager then
        notificationManager:ShowToast(
            "Pet Summoned! 🐾",
            pet.name .. " is now following you!",
            "🐾",
            "pet"
        )
    end
    
    return {success = true, message = "Pet summoned successfully"}
end

function PetManager:DismissPet(player)
    local playerData = self.PlayerPets[player.UserId]
    if not playerData.activePet then
        return {success = false, message = "No active pet"}
    end
    
    local petId = playerData.activePet
    local petData = self.ActivePets[petId]
    
    if petData and petData.instance then
        petData.instance:Destroy()
    end
    
    -- Clean up
    self.ActivePets[petId] = nil
    playerData.activePet = nil
    
    return {success = true, message = "Pet dismissed"}
end

function PetManager:CreatePetInstance(player, pet)
    local spawnLocation = workspace:FindFirstChild("SpawnLocation")
    if not spawnLocation then return nil end
    
    -- Create pet model (placeholder)
    local petModel = Instance.new("Model")
    petModel.Name = pet.name
    petModel.Parent = workspace
    
    -- Create pet part (placeholder)
    local petPart = Instance.new("Part")
    petPart.Name = "Body"
    petPart.Size = Vector3.new(2, 2, 2)
    petPart.Material = Enum.Material.Neon
    petPart.BrickColor = BrickColor.new("Bright green")
    petPart.Shape = Enum.PartType.Ball
    petPart.CanCollide = false
    petPart.Anchored = false
    petPart.Parent = petModel
    
    -- Add humanoid for pathfinding
    local humanoid = Instance.new("Humanoid")
    humanoid.WalkSpeed = pet.stats.speed
    humanoid.JumpHeight = 0
    humanoid.Parent = petModel
    
    -- Set pet color based on rarity
    local rarityData = self.PetRarities[pet.rarity]
    if rarityData then
        petPart.Color = rarityData.color
    end
    
    -- Position near player
    local playerCharacter = player.Character
    if playerCharacter and playerCharacter:FindFirstChild("HumanoidRootPart") then
        petModel:SetPrimaryPartCFrame(
            playerCharacter.HumanoidRootPart.CFrame * CFrame.new(3, 0, 0)
        )
        petModel.PrimaryPart = petPart
    else
        petModel:SetPrimaryPartCFrame(spawnLocation.CFrame * CFrame.new(3, 3, 0))
        petModel.PrimaryPart = petPart
    end
    
    -- Add pet name display
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Size = UDim2.new(0, 100, 0, 50)
    billboardGui.StudsOffset = Vector3.new(0, 3, 0)
    billboardGui.Parent = petPart
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = pet.name
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.SourceSansBold
    nameLabel.Parent = billboardGui
    
    return petModel
end

-- ==========================================
-- PET BEHAVIOR SYSTEM
-- ==========================================

function PetManager:UpdatePetBehavior(petId, petData)
    local pet = petData.pet
    local instance = petData.instance
    local player = petData.player
    
    if not instance or not instance.Parent then
        -- Pet instance was destroyed, clean up
        self.ActivePets[petId] = nil
        return
    end
    
    -- Update pet needs
    self:UpdatePetNeeds(pet)
    
    -- Behavior state machine
    local currentTime = tick()
    local timeSinceBehaviorChange = currentTime - petData.lastBehaviorChange
    
    if petData.behavior == self.PetBehaviors.FOLLOWING then
        self:UpdateFollowingBehavior(petId, petData)
        
        -- Randomly switch to other behaviors
        if timeSinceBehaviorChange > 30 and math.random() < 0.1 then
            local newBehavior = math.random() < 0.5 and self.PetBehaviors.PLAYING or self.PetBehaviors.WORKING
            self:ChangePetBehavior(petId, newBehavior)
        end
        
    elseif petData.behavior == self.PetBehaviors.WORKING then
        self:UpdateWorkingBehavior(petId, petData)
        
        -- Return to following after work
        if timeSinceBehaviorChange > 60 then
            self:ChangePetBehavior(petId, self.PetBehaviors.FOLLOWING)
        end
        
    elseif petData.behavior == self.PetBehaviors.PLAYING then
        self:UpdatePlayingBehavior(petId, petData)
        
        -- Return to following after play
        if timeSinceBehaviorChange > 45 then
            self:ChangePetBehavior(petId, self.PetBehaviors.FOLLOWING)
        end
        
    elseif petData.behavior == self.PetBehaviors.SLEEPING then
        self:UpdateSleepingBehavior(petId, petData)
        
        -- Wake up after rest
        if timeSinceBehaviorChange > 120 then
            self:ChangePetBehavior(petId, self.PetBehaviors.FOLLOWING)
        end
    end
    
    -- Check if pet needs to sleep
    if pet.energy < 20 and petData.behavior ~= self.PetBehaviors.SLEEPING then
        self:ChangePetBehavior(petId, self.PetBehaviors.SLEEPING)
    end
end

function PetManager:StartFollowingBehavior(petId)
    local petData = self.ActivePets[petId]
    if not petData then return end
    
    spawn(function()
        while self.ActivePets[petId] and petData.behavior == self.PetBehaviors.FOLLOWING do
            local player = petData.player
            local instance = petData.instance
            
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and instance then
                local humanoid = instance:FindFirstChild("Humanoid")
                if humanoid then
                    local targetPosition = player.Character.HumanoidRootPart.Position + Vector3.new(
                        math.random(-5, 5), 0, math.random(-5, 5)
                    )
                    
                    humanoid:MoveTo(targetPosition)
                end
            end
            
            wait(2)
        end
    end)
end

function PetManager:UpdateFollowingBehavior(petId, petData)
    -- Following behavior is handled by StartFollowingBehavior
    -- This function can add additional following logic if needed
end

function PetManager:UpdateWorkingBehavior(petId, petData)
    local pet = petData.pet
    local player = petData.player
    
    -- Pet performs work based on its abilities
    for _, abilityName in ipairs(pet.abilities) do
        if self:IsAbilityReady(pet, abilityName) then
            local ability = self.PetAbilities[abilityName]
            if ability and ability.effect then
                local success = ability.effect(pet, player)
                if success then
                    -- Set cooldown
                    pet.abilityCooldowns[abilityName] = tick() + ability.cooldown
                    
                    -- Gain experience
                    self:GainPetExperience(pet, 5)
                end
            end
        end
    end
end

function PetManager:UpdatePlayingBehavior(petId, petData)
    local instance = petData.instance
    local pet = petData.pet
    
    if instance then
        -- Make pet do playful movements
        local humanoid = instance:FindFirstChild("Humanoid")
        if humanoid then
            local randomDirection = Vector3.new(
                math.random(-10, 10), 0, math.random(-10, 10)
            )
            local currentPosition = instance.PrimaryPart.Position
            humanoid:MoveTo(currentPosition + randomDirection)
        end
        
        -- Restore happiness and energy
        pet.happiness = math.min(100, pet.happiness + 1)
        pet.energy = math.min(100, pet.energy + 0.5)
    end
end

function PetManager:UpdateSleepingBehavior(petId, petData)
    local pet = petData.pet
    local instance = petData.instance
    
    -- Pet sleeps to restore energy
    pet.energy = math.min(100, pet.energy + 2)
    
    if instance then
        local humanoid = instance:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.Sit = true
        end
    end
end

function PetManager:ChangePetBehavior(petId, newBehavior)
    local petData = self.ActivePets[petId]
    if not petData then return end
    
    petData.behavior = newBehavior
    petData.lastBehaviorChange = tick()
    
    -- Special behavior setup
    if newBehavior == self.PetBehaviors.FOLLOWING then
        self:StartFollowingBehavior(petId)
    elseif newBehavior == self.PetBehaviors.SLEEPING then
        -- Pet sits down to sleep
        local instance = petData.instance
        if instance then
            local humanoid = instance:FindFirstChild("Humanoid")
            if humanoid then
                humanoid.Sit = true
            end
        end
    end
end

function PetManager:UpdatePetNeeds(pet)
    local currentTime = tick()
    local timeSinceLastUpdate = currentTime - pet.lastActiveTime
    
    -- Decrease needs over time
    pet.hunger = math.max(0, pet.hunger - (timeSinceLastUpdate / 3600) * 10) -- 10% per hour
    pet.happiness = math.max(0, pet.happiness - (timeSinceLastUpdate / 7200) * 5) -- 5% per 2 hours
    pet.energy = math.max(0, pet.energy - (timeSinceLastUpdate / 1800) * 15) -- 15% per 30 minutes
    
    pet.lastActiveTime = currentTime
end

-- ==========================================
-- PET ABILITIES
-- ==========================================

function PetManager:UsePetAbility(player, abilityName)
    local playerData = self.PlayerPets[player.UserId]
    if not playerData.activePet then
        return {success = false, message = "No active pet"}
    end
    
    local petData = self.ActivePets[playerData.activePet]
    if not petData then
        return {success = false, message = "Pet not found"}
    end
    
    local pet = petData.pet
    
    -- Check if pet has this ability
    local hasAbility = false
    for _, ability in ipairs(pet.abilities) do
        if ability == abilityName then
            hasAbility = true
            break
        end
    end
    
    if not hasAbility then
        return {success = false, message = "Pet doesn't have this ability"}
    end
    
    -- Check cooldown
    if not self:IsAbilityReady(pet, abilityName) then
        local remainingTime = pet.abilityCooldowns[abilityName] - tick()
        return {success = false, message = "Ability on cooldown: " .. math.ceil(remainingTime) .. "s"}
    end
    
    -- Check pet energy
    if pet.energy < 20 then
        return {success = false, message = "Pet is too tired to use abilities"}
    end
    
    -- Use ability
    local ability = self.PetAbilities[abilityName]
    if ability and ability.effect then
        local success = ability.effect(pet, player)
        if success then
            -- Set cooldown
            pet.abilityCooldowns[abilityName] = tick() + ability.cooldown
            
            -- Consume energy
            pet.energy = math.max(0, pet.energy - 10)
            
            -- Gain experience
            self:GainPetExperience(pet, 10)
            
            return {success = true, message = "Ability used successfully"}
        else
            return {success = false, message = "Ability failed to execute"}
        end
    end
    
    return {success = false, message = "Invalid ability"}
end

function PetManager:IsAbilityReady(pet, abilityName)
    local cooldownEnd = pet.abilityCooldowns[abilityName]
    return not cooldownEnd or tick() >= cooldownEnd
end

function PetManager:ProcessPetAbilities()
    -- Process ongoing ability effects
    for petId, petData in pairs(self.ActivePets) do
        for effectName, effectData in pairs(petData.activeEffects) do
            if tick() >= effectData.endTime then
                -- Effect expired
                self:RemovePetEffect(petId, effectName)
            end
        end
    end
end

function PetManager:AddPetEffect(petId, effectName, duration, data)
    local petData = self.ActivePets[petId]
    if petData then
        petData.activeEffects[effectName] = {
            endTime = tick() + duration,
            data = data
        }
    end
end

function PetManager:RemovePetEffect(petId, effectName)
    local petData = self.ActivePets[petId]
    if petData then
        petData.activeEffects[effectName] = nil
    end
end

-- ==========================================
-- SPECIFIC ABILITY IMPLEMENTATIONS
-- ==========================================

function PetManager:AutoPlantSeeds(pet, player)
    local plotManager = _G.PlotManager
    local economyManager = _G.EconomyManager
    
    if not plotManager or not economyManager then return false end
    
    -- Find empty plots for player
    local playerPlots = plotManager:GetPlayerPlots(player)
    local emptyPlots = {}
    
    for _, plot in ipairs(playerPlots) do
        if not plot.plant then
            table.insert(emptyPlots, plot)
        end
    end
    
    if #emptyPlots == 0 then return false end
    
    -- Get player's seeds
    local playerSeeds = economyManager:GetPlayerSeeds(player)
    if not playerSeeds or #playerSeeds == 0 then return false end
    
    -- Plant seed in random empty plot
    local plot = emptyPlots[math.random(1, #emptyPlots)]
    local seed = playerSeeds[math.random(1, #playerSeeds)]
    
    local plantManager = _G.PlantManager
    if plantManager then
        return plantManager:PlantSeed(player, plot.id, seed.type)
    end
    
    return false
end

function PetManager:AutoHarvestPlants(pet, player)
    local plotManager = _G.PlotManager
    local plantManager = _G.PlantManager
    
    if not plotManager or not plantManager then return false end
    
    -- Find mature plants for player
    local playerPlots = plotManager:GetPlayerPlots(player)
    local maturePlots = {}
    
    for _, plot in ipairs(playerPlots) do
        if plot.plant and plot.plant.stage >= 3 then -- Mature stage
            table.insert(maturePlots, plot)
        end
    end
    
    if #maturePlots == 0 then return false end
    
    -- Harvest random mature plant
    local plot = maturePlots[math.random(1, #maturePlots)]
    return plantManager:HarvestPlant(player, plot.id)
end

function PetManager:AutoSellCrops(pet, player)
    local economyManager = _G.EconomyManager
    if not economyManager then return false end
    
    -- Auto sell some of player's crops
    return economyManager:AutoSellCrops(player, 0.25) -- Sell 25% of crops
end

function PetManager:BoostPlantGrowth(pet, player, multiplier, duration)
    local plantManager = _G.PlantManager
    if not plantManager then return false end
    
    plantManager:ApplyGrowthBoost(player, multiplier, duration)
    
    -- Add visual effect
    self:AddPetEffect(pet.id, "growth_boost", duration, {
        multiplier = multiplier
    })
    
    return true
end

function PetManager:BoostXPGain(pet, player, multiplier, duration)
    local progressionManager = _G.ProgressionManager
    if not progressionManager then return false end
    
    progressionManager:ApplyXPBoost(player, multiplier, duration)
    return true
end

function PetManager:BoostLuck(pet, player, multiplier, duration)
    -- Implementation would boost rare drop chances
    return true
end

function PetManager:ActivatePestControl(pet, player, duration)
    -- Implementation would prevent crop damage
    return true
end

function PetManager:PredictWeather(pet, player)
    local weatherManager = _G.WeatherManager
    if not weatherManager then return false end
    
    local forecast = weatherManager:GetWeatherForecast(3)
    
    -- Send forecast to player
    local notificationManager = _G.NotificationManager
    if notificationManager then
        notificationManager:ShowToast(
            "Weather Prediction! 🦉",
            "Check your weather forecast for the next 3 days",
            "🌦️",
            "weather"
        )
    end
    
    return true
end

function PetManager:ActivateFireBoost(pet, player, duration)
    -- Dragon fire boost - accelerates all activities
    self:BoostPlantGrowth(pet, player, 2.0, duration)
    return true
end

function PetManager:AccelerateTime(pet, player, multiplier, duration)
    -- Time acceleration - super fast growth
    self:BoostPlantGrowth(pet, player, multiplier, duration)
    return true
end

function PetManager:RevivePlants(pet, player)
    local plotManager = _G.PlotManager
    local plantManager = _G.PlantManager
    
    if not plotManager or not plantManager then return false end
    
    -- Find dead plants and revive them
    local playerPlots = plotManager:GetPlayerPlots(player)
    local revivedCount = 0
    
    for _, plot in ipairs(playerPlots) do
        if plot.plant and plot.plant.health <= 0 then
            plot.plant.health = 100
            plot.plant.stage = 1 -- Reset to growing
            revivedCount = revivedCount + 1
        end
    end
    
    return revivedCount > 0
end

function PetManager:DoubleRewards(pet, player, duration)
    local economyManager = _G.EconomyManager
    if not economyManager then return false end
    
    economyManager:ApplyRewardMultiplier(player, 2.0, duration)
    return true
end

function PetManager:ControlWeather(pet, player, weatherType)
    local weatherManager = _G.WeatherManager
    if not weatherManager then return false end
    
    return weatherManager:ForceWeatherChange(weatherType)
end

function PetManager:ActivateHealingAura(pet, player, duration)
    -- Healing aura - heals and protects all plants
    local plotManager = _G.PlotManager
    if not plotManager then return false end
    
    local playerPlots = plotManager:GetPlayerPlots(player)
    for _, plot in ipairs(playerPlots) do
        if plot.plant then
            plot.plant.health = 100
            plot.plant.protected = true -- Temporary protection
        end
    end
    
    return true
end

function PetManager:ActivateRainbowGrowth(pet, player, duration)
    -- Rainbow growth - visual effect
    self:AddPetEffect(pet.id, "rainbow_growth", duration, {})
    return true
end

function PetManager:InstantMature(pet, player)
    local plotManager = _G.PlotManager
    if not plotManager then return false end
    
    -- Find growing plants
    local playerPlots = plotManager:GetPlayerPlots(player)
    local growingPlots = {}
    
    for _, plot in ipairs(playerPlots) do
        if plot.plant and plot.plant.stage < 3 then
            table.insert(growingPlots, plot)
        end
    end
    
    if #growingPlots == 0 then return false end
    
    -- Instantly mature one random plant
    local plot = growingPlots[math.random(1, #growingPlots)]
    plot.plant.stage = 3
    plot.plant.growthTime = 0
    
    return true
end

-- ==========================================
-- PET FEEDING & BREEDING
-- ==========================================

function PetManager:FeedPet(player, petId, foodType)
    local playerData = self.PlayerPets[player.UserId]
    local pet = playerData.pets[petId]
    
    if not pet then
        return {success = false, message = "Pet not found"}
    end
    
    -- Check if player has food
    local economyManager = _G.EconomyManager
    if not economyManager or not economyManager:HasItem(player, foodType, 1) then
        return {success = false, message = "You don't have this food"}
    end
    
    -- Check feeding cooldown (can feed every hour)
    local lastFeedTime = playerData.lastFeedTime[petId] or 0
    if tick() - lastFeedTime < 3600 then
        local remaining = 3600 - (tick() - lastFeedTime)
        return {success = false, message = "Can feed again in " .. math.ceil(remaining / 60) .. " minutes"}
    end
    
    -- Consume food
    economyManager:RemoveItem(player, foodType, 1)
    
    -- Feed pet
    pet.hunger = math.min(100, pet.hunger + 50)
    pet.happiness = math.min(100, pet.happiness + 25)
    
    -- Gain experience
    self:GainPetExperience(pet, 15)
    
    -- Update last feed time
    playerData.lastFeedTime[petId] = tick()
    
    return {success = true, message = "Pet fed successfully"}
end

function PetManager:BreedPets(player, pet1Id, pet2Id)
    local playerData = self.PlayerPets[player.UserId]
    
    if not self:IsPlayerVIP(player) then
        return {success = false, message = "VIP membership required for breeding"}
    end
    
    -- Check breeding cooldown
    if tick() < playerData.breedingCooldown then
        local remaining = playerData.breedingCooldown - tick()
        return {success = false, message = "Breeding cooldown: " .. math.ceil(remaining / 3600) .. " hours"}
    end
    
    local pet1 = playerData.pets[pet1Id]
    local pet2 = playerData.pets[pet2Id]
    
    if not pet1 or not pet2 then
        return {success = false, message = "Invalid pets for breeding"}
    end
    
    -- Check if pets are high enough level
    if pet1.level < 10 or pet2.level < 10 then
        return {success = false, message = "Pets must be level 10+ to breed"}
    end
    
    -- Check if player has space for new pet
    if #playerData.pets >= playerData.petSlots then
        return {success = false, message = "Not enough pet slots"}
    end
    
    -- Breed pets
    local offspring = self:CreateOffspring(pet1, pet2)
    if offspring then
        playerData.pets[offspring.id] = offspring
        playerData.breedingCooldown = tick() + 86400 -- 24 hour cooldown
        
        -- Notify player
        local notificationManager = _G.NotificationManager
        if notificationManager then
            notificationManager:ShowToast(
                "Breeding Success! 🥚",
                "A new " .. offspring.name .. " was born!",
                "🐣",
                "pet"
            )
        end
        
        return {success = true, message = "Breeding successful", offspring = offspring}
    end
    
    return {success = false, message = "Breeding failed"}
end

function PetManager:CreateOffspring(parent1, parent2)
    -- Simple breeding logic - inherits traits from both parents
    local species = math.random() < 0.5 and parent1.species or parent2.species
    
    -- Determine rarity (chance for upgrade)
    local rarity = parent1.rarity
    local rarityValues = {"COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY"}
    local rarityIndex = 1
    
    for i, r in ipairs(rarityValues) do
        if r == rarity then
            rarityIndex = i
            break
        end
    end
    
    -- Small chance to get higher rarity
    if math.random() < 0.1 and rarityIndex < #rarityValues then
        rarity = rarityValues[rarityIndex + 1]
    end
    
    return self:CreateNewPet(species, rarity, 1)
end

-- ==========================================
-- PET MARKETPLACE
-- ==========================================

function PetManager:GenerateMarketplacePets()
    self.PetMarketplace = {}
    
    -- Generate 5 random pets for sale
    for i = 1, 5 do
        local species = self:GetRandomSpecies()
        local rarity = self:GetRandomRarity()
        local pet = self:CreateNewPet(species, rarity, math.random(1, 10))
        
        if pet then
            pet.price = self:CalculatePetPrice(pet)
            table.insert(self.PetMarketplace, pet)
        end
    end
end

function PetManager:RefreshMarketplace()
    print("🐾 PetManager: Refreshing pet marketplace...")
    self:GenerateMarketplacePets()
    
    -- Notify all players
    local notificationManager = _G.NotificationManager
    if notificationManager then
        for _, player in pairs(Players:GetPlayers()) do
            notificationManager:ShowToast(
                "Pet Market Updated! 🏪",
                "New pets available in the marketplace!",
                "🐾",
                "market"
            )
        end
    end
end

function PetManager:GetRandomSpecies()
    local species = {}
    for speciesName, data in pairs(self.PetSpecies) do
        if not data.vipOnly then
            table.insert(species, speciesName)
        end
    end
    
    return species[math.random(1, #species)]
end

function PetManager:GetRandomRarity()
    local rand = math.random()
    
    if rand < 0.7 then return "COMMON"
    elseif rand < 0.9 then return "UNCOMMON"
    elseif rand < 0.97 then return "RARE"
    elseif rand < 0.995 then return "EPIC"
    else return "LEGENDARY"
    end
end

function PetManager:CalculatePetPrice(pet)
    local basePrice = 100
    local rarityMultiplier = self.PetRarities[pet.rarity].multiplier
    local levelMultiplier = pet.level * 0.5
    
    return math.floor(basePrice * rarityMultiplier * (1 + levelMultiplier))
end

-- ==========================================
-- PET EXPERIENCE & EVOLUTION
-- ==========================================

function PetManager:GainPetExperience(pet, amount)
    pet.experience = pet.experience + amount
    
    -- Check for level up
    while pet.experience >= pet.experienceToNext do
        pet.experience = pet.experience - pet.experienceToNext
        pet.level = pet.level + 1
        pet.experienceToNext = self:CalculateExperienceRequired(pet.level)
        
        -- Level up bonuses
        pet.stats.speed = pet.stats.speed + 1
        pet.stats.strength = pet.stats.strength + 1
        pet.stats.intelligence = pet.stats.intelligence + 1
        
        -- Check for evolution
        self:CheckPetEvolution(pet)
    end
end

function PetManager:CalculateExperienceRequired(level)
    return math.floor(100 * (level * 1.5))
end

function PetManager:CheckPetEvolution(pet)
    local speciesData = self.PetSpecies[pet.species]
    if speciesData.evolution and pet.level >= speciesData.evolution.level then
        -- Evolve pet
        local newSpecies = speciesData.evolution.evolves_to
        local newSpeciesData = self.PetSpecies[newSpecies]
        
        if newSpeciesData then
            pet.species = newSpecies
            pet.name = newSpeciesData.name
            pet.description = newSpeciesData.description
            pet.abilities = newSpeciesData.abilities
            pet.evolution = newSpeciesData.evolution
            pet.model = newSpeciesData.model
            
            -- Boost stats
            pet.stats.speed = pet.stats.speed + 10
            pet.stats.strength = pet.stats.strength + 10
            pet.stats.intelligence = pet.stats.intelligence + 10
            
            print("🐾 PetManager: Pet evolved to", newSpecies)
        end
    end
end

function PetManager:UpdatePetStats()
    -- Update stats for all pets
    for userId, playerData in pairs(self.PlayerPets) do
        for petId, pet in pairs(playerData.pets) do
            -- Happiness affects performance
            if pet.happiness < 50 then
                -- Reduce effectiveness when unhappy
                local effectiveness = pet.happiness / 100
                -- Apply effectiveness reduction (implementation specific)
            end
            
            -- Hunger affects energy regeneration
            if pet.hunger > 50 then
                pet.energy = math.min(100, pet.energy + 0.5)
            end
        end
    end
end

-- ==========================================
-- HELPER FUNCTIONS
-- ==========================================

function PetManager:IsPlayerVIP(player)
    local vipManager = _G.VIPManager
    if vipManager then
        return vipManager:IsPlayerVIP(player)
    end
    return false
end

function PetManager:GetPlayerPets(player)
    local playerData = self.PlayerPets[player.UserId]
    if not playerData then return {} end
    
    return {
        pets = playerData.pets,
        activePet = playerData.activePet,
        petSlots = playerData.petSlots,
        marketplace = self.PetMarketplace
    }
end

-- ==========================================
-- PUBLIC API
-- ==========================================

function PetManager:GetPetStats(player, petId)
    local playerData = self.PlayerPets[player.UserId]
    if playerData and playerData.pets[petId] then
        return playerData.pets[petId]
    end
    return nil
end

function PetManager:GetActivePet(player)
    local playerData = self.PlayerPets[player.UserId]
    if playerData and playerData.activePet then
        return playerData.pets[playerData.activePet]
    end
    return nil
end

function PetManager:GivePet(player, species, rarity, level)
    -- Admin function to give pets
    local playerData = self.PlayerPets[player.UserId]
    if not playerData then return false end
    
    if #playerData.pets >= playerData.petSlots then
        return false
    end
    
    local pet = self:CreateNewPet(species, rarity, level)
    if pet then
        playerData.pets[pet.id] = pet
        return true
    end
    
    return false
end

-- ==========================================
-- CLEANUP
-- ==========================================

function PetManager:Cleanup()
    -- Dismiss all active pets
    for petId, petData in pairs(self.ActivePets) do
        if petData.instance then
            petData.instance:Destroy()
        end
    end
    
    -- Save all player pet data
    for userId, _ in pairs(self.PlayerPets) do
        local player = Players:GetPlayerByUserId(userId)
        if player then
            self:SavePlayerPetData(player)
        end
    end
    
    print("🐾 PetManager: Pet system cleaned up")
end

return PetManager
