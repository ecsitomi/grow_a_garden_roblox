--[[
    AchievementManager.lua
    Server-Side Achievement and Progress Tracking System
    
    Priority: 34 (Advanced Features phase)
    Dependencies: DataStoreService, ReplicatedStorage, NotificationManager
    Used by: All game systems for achievement tracking
    
    Features:
    - Comprehensive achievement system
    - Progress tracking and milestones
    - Title and badge rewards
    - Achievement categories and collections
    - Social sharing and showcase
    - Seasonal and limited-time achievements
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

-- Load required modules
local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)

local AchievementManager = {}
AchievementManager.__index = AchievementManager

-- ==========================================
-- INITIALIZATION & SETUP
-- ==========================================

-- Data stores
AchievementManager.AchievementStore = DataStoreService:GetDataStore("AchievementData_v1")
AchievementManager.ProgressStore = DataStoreService:GetDataStore("ProgressData_v1")

-- Achievement state tracking
AchievementManager.PlayerAchievements = {} -- [userId] = achievementData
AchievementManager.PlayerProgress = {} -- [userId] = progressData
AchievementManager.GlobalStats = {} -- Global achievement statistics

-- Achievement categories
AchievementManager.AchievementCategories = {
    FARMING = "farming",
    SOCIAL = "social",
    EXPLORATION = "exploration",
    COLLECTION = "collection",
    ECONOMY = "economy",
    MINI_GAMES = "mini_games",
    DECORATION = "decoration",
    SEASONAL = "seasonal",
    SPECIAL = "special",
    VIP = "vip"
}

-- Achievement rarities
AchievementManager.AchievementRarities = {
    COMMON = {
        color = Color3.fromRGB(155, 155, 155),
        points = 10,
        icon = "⭐"
    },
    UNCOMMON = {
        color = Color3.fromRGB(30, 255, 0),
        points = 25,
        icon = "🌟"
    },
    RARE = {
        color = Color3.fromRGB(0, 112, 255),
        points = 50,
        icon = "💫"
    },
    EPIC = {
        color = Color3.fromRGB(163, 53, 238),
        points = 100,
        icon = "✨"
    },
    LEGENDARY = {
        color = Color3.fromRGB(255, 128, 0),
        points = 250,
        icon = "🌠"
    },
    MYTHIC = {
        color = Color3.fromRGB(255, 0, 128),
        points = 500,
        icon = "👑"
    }
}

-- Achievement definitions
AchievementManager.Achievements = {
    -- FARMING ACHIEVEMENTS
    first_plant = {
        id = "first_plant",
        name = "Green Thumb",
        description = "Plant your first crop",
        category = AchievementManager.AchievementCategories.FARMING,
        rarity = "COMMON",
        requirements = {
            plants_planted = 1
        },
        rewards = {
            coins = 100,
            xp = 200,
            title = "Novice Gardener"
        },
        hidden = false
    },
    
    hundred_plants = {
        id = "hundred_plants",
        name = "Dedicated Farmer",
        description = "Plant 100 crops",
        category = AchievementManager.AchievementCategories.FARMING,
        rarity = "UNCOMMON",
        requirements = {
            plants_planted = 100
        },
        rewards = {
            coins = 1000,
            xp = 2000,
            title = "Dedicated Farmer",
            item = "farmer_hat"
        },
        hidden = false
    },
    
    thousand_plants = {
        id = "thousand_plants",
        name = "Master Cultivator",
        description = "Plant 1,000 crops",
        category = AchievementManager.AchievementCategories.FARMING,
        rarity = "RARE",
        requirements = {
            plants_planted = 1000
        },
        rewards = {
            coins = 10000,
            xp = 20000,
            title = "Master Cultivator",
            item = "golden_hoe"
        },
        hidden = false
    },
    
    first_harvest = {
        id = "first_harvest",
        name = "First Harvest",
        description = "Harvest your first crop",
        category = AchievementManager.AchievementCategories.FARMING,
        rarity = "COMMON",
        requirements = {
            crops_harvested = 1
        },
        rewards = {
            coins = 150,
            xp = 300
        },
        hidden = false
    },
    
    mega_harvest = {
        id = "mega_harvest",
        name = "Mega Harvester",
        description = "Harvest 10,000 crops",
        category = AchievementManager.AchievementCategories.FARMING,
        rarity = "EPIC",
        requirements = {
            crops_harvested = 10000
        },
        rewards = {
            coins = 50000,
            xp = 100000,
            title = "Harvest King",
            item = "harvest_crown"
        },
        hidden = false
    },
    
    perfect_garden = {
        id = "perfect_garden",
        name = "Perfect Garden",
        description = "Achieve 100% garden health",
        category = AchievementManager.AchievementCategories.FARMING,
        rarity = "RARE",
        requirements = {
            garden_health = 100
        },
        rewards = {
            coins = 5000,
            xp = 10000,
            title = "Garden Perfectionist"
        },
        hidden = false
    },
    
    -- SOCIAL ACHIEVEMENTS
    first_friend = {
        id = "first_friend",
        name = "Social Butterfly",
        description = "Make your first friend",
        category = AchievementManager.AchievementCategories.SOCIAL,
        rarity = "COMMON",
        requirements = {
            friends_made = 1
        },
        rewards = {
            coins = 200,
            xp = 400,
            title = "Friendly Gardener"
        },
        hidden = false
    },
    
    popular_gardener = {
        id = "popular_gardener",
        name = "Popular Gardener",
        description = "Have 50 friends",
        category = AchievementManager.AchievementCategories.SOCIAL,
        rarity = "RARE",
        requirements = {
            friends_made = 50
        },
        rewards = {
            coins = 15000,
            xp = 30000,
            title = "Popular Gardener",
            item = "friendship_ring"
        },
        hidden = false
    },
    
    gift_giver = {
        id = "gift_giver",
        name = "Generous Soul",
        description = "Send 100 gifts to friends",
        category = AchievementManager.AchievementCategories.SOCIAL,
        rarity = "UNCOMMON",
        requirements = {
            gifts_sent = 100
        },
        rewards = {
            coins = 2500,
            xp = 5000,
            title = "Gift Giver"
        },
        hidden = false
    },
    
    visitor = {
        id = "visitor",
        name = "Garden Tourist",
        description = "Visit 25 different gardens",
        category = AchievementManager.AchievementCategories.SOCIAL,
        rarity = "UNCOMMON",
        requirements = {
            gardens_visited = 25
        },
        rewards = {
            coins = 3000,
            xp = 6000,
            title = "Garden Tourist",
            item = "travel_boots"
        },
        hidden = false
    },
    
    -- COLLECTION ACHIEVEMENTS
    seed_collector = {
        id = "seed_collector",
        name = "Seed Collector",
        description = "Collect 50 different seed types",
        category = AchievementManager.AchievementCategories.COLLECTION,
        rarity = "RARE",
        requirements = {
            unique_seeds = 50
        },
        rewards = {
            coins = 8000,
            xp = 16000,
            title = "Seed Collector",
            item = "seed_vault"
        },
        hidden = false
    },
    
    rare_finder = {
        id = "rare_finder",
        name = "Rare Plant Hunter",
        description = "Discover 10 rare plants",
        category = AchievementManager.AchievementCategories.COLLECTION,
        rarity = "EPIC",
        requirements = {
            rare_plants_found = 10
        },
        rewards = {
            coins = 25000,
            xp = 50000,
            title = "Rare Plant Hunter",
            item = "magnifying_glass"
        },
        hidden = false
    },
    
    decoration_collector = {
        id = "decoration_collector",
        name = "Decoration Enthusiast",
        description = "Own 100 different decorations",
        category = AchievementManager.AchievementCategories.DECORATION,
        rarity = "RARE",
        requirements = {
            unique_decorations = 100
        },
        rewards = {
            coins = 12000,
            xp = 24000,
            title = "Decoration Enthusiast"
        },
        hidden = false
    },
    
    -- ECONOMY ACHIEVEMENTS
    first_million = {
        id = "first_million",
        name = "Millionaire",
        description = "Earn 1,000,000 coins total",
        category = AchievementManager.AchievementCategories.ECONOMY,
        rarity = "EPIC",
        requirements = {
            total_coins_earned = 1000000
        },
        rewards = {
            coins = 100000,
            xp = 200000,
            title = "Millionaire",
            item = "golden_coin"
        },
        hidden = false
    },
    
    big_spender = {
        id = "big_spender",
        name = "Big Spender",
        description = "Spend 500,000 coins",
        category = AchievementManager.AchievementCategories.ECONOMY,
        rarity = "RARE",
        requirements = {
            total_coins_spent = 500000
        },
        rewards = {
            coins = 50000,
            xp = 100000,
            title = "Big Spender"
        },
        hidden = false
    },
    
    -- MINI-GAME ACHIEVEMENTS
    game_master = {
        id = "game_master",
        name = "Game Master",
        description = "Win 100 mini-games",
        category = AchievementManager.AchievementCategories.MINI_GAMES,
        rarity = "EPIC",
        requirements = {
            mini_games_won = 100
        },
        rewards = {
            coins = 30000,
            xp = 60000,
            title = "Game Master",
            item = "trophy"
        },
        hidden = false
    },
    
    perfect_player = {
        id = "perfect_player",
        name = "Perfectionist",
        description = "Achieve perfect scores in 10 mini-games",
        category = AchievementManager.AchievementCategories.MINI_GAMES,
        rarity = "LEGENDARY",
        requirements = {
            perfect_scores = 10
        },
        rewards = {
            coins = 75000,
            xp = 150000,
            title = "Perfectionist",
            item = "perfect_medal"
        },
        hidden = false
    },
    
    -- SEASONAL ACHIEVEMENTS
    spring_festival = {
        id = "spring_festival",
        name = "Spring Celebration",
        description = "Complete the Spring Festival event",
        category = AchievementManager.AchievementCategories.SEASONAL,
        rarity = "RARE",
        requirements = {
            events_completed = {"spring_festival"}
        },
        rewards = {
            coins = 10000,
            xp = 20000,
            title = "Spring Guardian",
            item = "spring_crown"
        },
        hidden = false,
        seasonal = "spring"
    },
    
    winter_survivor = {
        id = "winter_survivor",
        name = "Winter Survivor",
        description = "Complete the Winter Wonderland event",
        category = AchievementManager.AchievementCategories.SEASONAL,
        rarity = "RARE",
        requirements = {
            events_completed = {"winter_wonderland"}
        },
        rewards = {
            coins = 12000,
            xp = 24000,
            title = "Winter Wizard",
            item = "ice_crown"
        },
        hidden = false,
        seasonal = "winter"
    },
    
    -- VIP ACHIEVEMENTS
    vip_member = {
        id = "vip_member",
        name = "VIP Member",
        description = "Become a VIP member",
        category = AchievementManager.AchievementCategories.VIP,
        rarity = "EPIC",
        requirements = {
            vip_status = true
        },
        rewards = {
            coins = 20000,
            xp = 40000,
            title = "VIP Gardener",
            item = "vip_badge"
        },
        hidden = false
    },
    
    diamond_spender = {
        id = "diamond_spender",
        name = "Diamond Connoisseur",
        description = "Spend 1,000 diamonds",
        category = AchievementManager.AchievementCategories.VIP,
        rarity = "LEGENDARY",
        requirements = {
            diamonds_spent = 1000
        },
        rewards = {
            coins = 100000,
            xp = 200000,
            title = "Diamond Elite",
            item = "diamond_ring"
        },
        hidden = false
    },
    
    -- SPECIAL/HIDDEN ACHIEVEMENTS
    early_bird = {
        id = "early_bird",
        name = "Early Bird",
        description = "Log in before 6 AM",
        category = AchievementManager.AchievementCategories.SPECIAL,
        rarity = "UNCOMMON",
        requirements = {
            early_login = true
        },
        rewards = {
            coins = 1000,
            xp = 2000,
            title = "Early Bird"
        },
        hidden = true
    },
    
    night_owl = {
        id = "night_owl",
        name = "Night Owl",
        description = "Log in after midnight",
        category = AchievementManager.AchievementCategories.SPECIAL,
        rarity = "UNCOMMON",
        requirements = {
            late_login = true
        },
        rewards = {
            coins = 1000,
            xp = 2000,
            title = "Night Owl"
        },
        hidden = true
    },
    
    lucky_find = {
        id = "lucky_find",
        name = "Lucky Find",
        description = "Find a legendary item with 0.1% chance",
        category = AchievementManager.AchievementCategories.SPECIAL,
        rarity = "MYTHIC",
        requirements = {
            legendary_finds = 1
        },
        rewards = {
            coins = 250000,
            xp = 500000,
            title = "Fortune's Favorite",
            item = "lucky_charm"
        },
        hidden = true
    },
    
    -- EXPLORATION ACHIEVEMENTS
    world_explorer = {
        id = "world_explorer",
        name = "World Explorer",
        description = "Visit all available areas",
        category = AchievementManager.AchievementCategories.EXPLORATION,
        rarity = "RARE",
        requirements = {
            areas_visited = 10
        },
        rewards = {
            coins = 15000,
            xp = 30000,
            title = "World Explorer",
            item = "explorer_map"
        },
        hidden = false
    }
}

-- Progress tracking events
AchievementManager.ProgressEvents = {
    "plant_planted",
    "crop_harvested",
    "friend_made",
    "gift_sent",
    "garden_visited",
    "coins_earned",
    "coins_spent",
    "mini_game_won",
    "perfect_score_achieved",
    "event_completed",
    "area_visited",
    "decoration_purchased",
    "rare_plant_found",
    "diamonds_spent"
}

-- ==========================================
-- INITIALIZATION
-- ==========================================

function AchievementManager:Initialize()
    print("🏆 AchievementManager: Initializing achievement system...")
    
    -- Set up remote events
    self:SetupRemoteEvents()
    
    -- Set up player connections
    self:SetupPlayerConnections()
    
    -- Load global achievement stats
    self:LoadGlobalStats()
    
    -- Start achievement updates
    self:StartAchievementUpdates()
    
    print("✅ AchievementManager: Achievement system initialized")
end

function AchievementManager:SetupRemoteEvents()
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
    
    -- Get available titles
    local getTitlesFunction = Instance.new("RemoteFunction")
    getTitlesFunction.Name = "GetAvailableTitles"
    getTitlesFunction.Parent = remoteEvents
    getTitlesFunction.OnServerInvoke = function(player)
        return self:GetAvailableTitles(player)
    end
    
    -- Set active title
    local setTitleFunction = Instance.new("RemoteFunction")
    setTitleFunction.Name = "SetActiveTitle"
    setTitleFunction.Parent = remoteEvents
    setTitleFunction.OnServerInvoke = function(player, titleId)
        return self:SetActiveTitle(player, titleId)
    end
    
    -- Get achievement statistics
    local getStatsFunction = Instance.new("RemoteFunction")
    getStatsFunction.Name = "GetAchievementStats"
    getStatsFunction.Parent = remoteEvents
    getStatsFunction.OnServerInvoke = function(player)
        return self:GetAchievementStats(player)
    end
end

function AchievementManager:SetupPlayerConnections()
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

function AchievementManager:LoadGlobalStats()
    local success, globalData = pcall(function()
        return self.AchievementStore:GetAsync("global_achievement_stats")
    end)
    
    if success and globalData then
        self.GlobalStats = globalData
    else
        self.GlobalStats = {
            totalAchievementsUnlocked = 0,
            achievementCounts = {},
            lastUpdated = tick()
        }
    end
end

function AchievementManager:StartAchievementUpdates()
    spawn(function()
        while true do
            self:UpdateGlobalStats()
            self:CheckSeasonalAchievements()
            wait(300) -- Update every 5 minutes
        end
    end)
end

-- ==========================================
-- PLAYER MANAGEMENT
-- ==========================================

function AchievementManager:OnPlayerJoined(player)
    -- Initialize player achievement data
    self.PlayerAchievements[player.UserId] = {
        unlockedAchievements = {},
        achievementPoints = 0,
        titles = {},
        activeTitle = nil,
        lastUnlocked = nil
    }
    
    -- Initialize player progress data
    self.PlayerProgress[player.UserId] = {}
    
    -- Load player achievement data
    spawn(function()
        self:LoadPlayerAchievementData(player)
        self:CheckLoginAchievements(player)
    end)
    
    print("🏆 AchievementManager: Player", player.Name, "initialized")
end

function AchievementManager:OnPlayerLeaving(player)
    -- Save player achievement data
    spawn(function()
        self:SavePlayerAchievementData(player)
        self:SavePlayerProgressData(player)
    end)
    
    -- Clean up
    self.PlayerAchievements[player.UserId] = nil
    self.PlayerProgress[player.UserId] = nil
    
    print("🏆 AchievementManager: Player", player.Name, "data saved")
end

function AchievementManager:LoadPlayerAchievementData(player)
    local success, achievementData = pcall(function()
        return self.AchievementStore:GetAsync("achievements_" .. player.UserId)
    end)
    
    if success and achievementData then
        self.PlayerAchievements[player.UserId] = achievementData
        print("🏆 AchievementManager: Loaded achievements for", player.Name)
    else
        print("🏆 AchievementManager: New achievement data for", player.Name)
    end
    
    -- Load progress data
    local progressSuccess, progressData = pcall(function()
        return self.ProgressStore:GetAsync("progress_" .. player.UserId)
    end)
    
    if progressSuccess and progressData then
        self.PlayerProgress[player.UserId] = progressData
        print("🏆 AchievementManager: Loaded progress for", player.Name)
    else
        -- Initialize progress tracking
        for _, eventType in ipairs(self.ProgressEvents) do
            self.PlayerProgress[player.UserId][eventType] = 0
        end
        print("🏆 AchievementManager: New progress data for", player.Name)
    end
end

function AchievementManager:SavePlayerAchievementData(player)
    local achievementData = self.PlayerAchievements[player.UserId]
    if not achievementData then return end
    
    local success, error = pcall(function()
        self.AchievementStore:SetAsync("achievements_" .. player.UserId, achievementData)
    end)
    
    if not success then
        warn("❌ AchievementManager: Failed to save achievements for", player.Name, ":", error)
    end
end

function AchievementManager:SavePlayerProgressData(player)
    local progressData = self.PlayerProgress[player.UserId]
    if not progressData then return end
    
    local success, error = pcall(function()
        self.ProgressStore:SetAsync("progress_" .. player.UserId, progressData)
    end)
    
    if not success then
        warn("❌ AchievementManager: Failed to save progress for", player.Name, ":", error)
    end
end

-- ==========================================
-- PROGRESS TRACKING
-- ==========================================

function AchievementManager:UpdateProgress(player, eventType, amount, additionalData)
    local progressData = self.PlayerProgress[player.UserId]
    if not progressData then return end
    
    amount = amount or 1
    
    -- Update progress counter
    if progressData[eventType] then
        progressData[eventType] = progressData[eventType] + amount
    else
        progressData[eventType] = amount
    end
    
    -- Handle special progress tracking
    if additionalData then
        self:HandleSpecialProgress(player, eventType, additionalData)
    end
    
    -- Check for achievement unlocks
    self:CheckAchievementUnlocks(player, eventType)
    
    print("🏆 AchievementManager: Updated", eventType, "for", player.Name, "to", progressData[eventType])
end

function AchievementManager:HandleSpecialProgress(player, eventType, data)
    local progressData = self.PlayerProgress[player.UserId]
    
    if eventType == "event_completed" then
        if not progressData.events_completed then
            progressData.events_completed = {}
        end
        table.insert(progressData.events_completed, data.eventId)
        
    elseif eventType == "area_visited" then
        if not progressData.areas_visited then
            progressData.areas_visited = {}
        end
        if not progressData.areas_visited[data.areaId] then
            progressData.areas_visited[data.areaId] = true
            progressData.unique_areas_visited = (progressData.unique_areas_visited or 0) + 1
        end
        
    elseif eventType == "rare_plant_found" then
        if not progressData.rare_plants_found then
            progressData.rare_plants_found = {}
        end
        table.insert(progressData.rare_plants_found, data.plantType)
        
    elseif eventType == "decoration_purchased" then
        if not progressData.unique_decorations then
            progressData.unique_decorations = {}
        end
        if not progressData.unique_decorations[data.decorationType] then
            progressData.unique_decorations[data.decorationType] = true
            progressData.decoration_count = (progressData.decoration_count or 0) + 1
        end
        
    elseif eventType == "friend_made" then
        progressData.friends_made = (progressData.friends_made or 0) + 1
        
    elseif eventType == "gift_sent" then
        progressData.gifts_sent = (progressData.gifts_sent or 0) + 1
        
    elseif eventType == "garden_visited" then
        if not progressData.gardens_visited then
            progressData.gardens_visited = {}
        end
        if not progressData.gardens_visited[data.hostUserId] then
            progressData.gardens_visited[data.hostUserId] = true
            progressData.unique_gardens_visited = (progressData.unique_gardens_visited or 0) + 1
        end
    end
end

function AchievementManager:CheckAchievementUnlocks(player, triggeredEvent)
    local playerAchievements = self.PlayerAchievements[player.UserId]
    local progressData = self.PlayerProgress[player.UserId]
    
    for achievementId, achievement in pairs(self.Achievements) do
        -- Skip if already unlocked
        if playerAchievements.unlockedAchievements[achievementId] then
            goto continue
        end
        
        -- Check if all requirements are met
        local requirementsMet = true
        for requirementType, threshold in pairs(achievement.requirements) do
            local currentProgress = 0
            
            if requirementType == "plants_planted" then
                currentProgress = progressData.plant_planted or 0
            elseif requirementType == "crops_harvested" then
                currentProgress = progressData.crop_harvested or 0
            elseif requirementType == "friends_made" then
                currentProgress = progressData.friends_made or 0
            elseif requirementType == "gifts_sent" then
                currentProgress = progressData.gifts_sent or 0
            elseif requirementType == "gardens_visited" then
                currentProgress = progressData.unique_gardens_visited or 0
            elseif requirementType == "total_coins_earned" then
                currentProgress = progressData.coins_earned or 0
            elseif requirementType == "total_coins_spent" then
                currentProgress = progressData.coins_spent or 0
            elseif requirementType == "mini_games_won" then
                currentProgress = progressData.mini_game_won or 0
            elseif requirementType == "perfect_scores" then
                currentProgress = progressData.perfect_score_achieved or 0
            elseif requirementType == "unique_seeds" then
                currentProgress = progressData.seed_count or 0
            elseif requirementType == "rare_plants_found" then
                currentProgress = #(progressData.rare_plants_found or {})
            elseif requirementType == "unique_decorations" then
                currentProgress = progressData.decoration_count or 0
            elseif requirementType == "areas_visited" then
                currentProgress = progressData.unique_areas_visited or 0
            elseif requirementType == "events_completed" then
                if type(threshold) == "table" then
                    -- Check if specific events were completed
                    local completedEvents = progressData.events_completed or {}
                    for _, requiredEvent in ipairs(threshold) do
                        local found = false
                        for _, completedEvent in ipairs(completedEvents) do
                            if completedEvent == requiredEvent then
                                found = true
                                break
                            end
                        end
                        if not found then
                            requirementsMet = false
                            break
                        end
                    end
                    goto checkNext
                else
                    currentProgress = #(progressData.events_completed or {})
                end
            elseif requirementType == "vip_status" then
                currentProgress = self:IsPlayerVIP(player) and 1 or 0
            elseif requirementType == "diamonds_spent" then
                currentProgress = progressData.diamonds_spent or 0
            elseif requirementType == "garden_health" then
                currentProgress = self:GetPlayerGardenHealth(player)
            elseif requirementType == "early_login" then
                local hour = tonumber(os.date("%H"))
                currentProgress = hour < 6 and 1 or 0
            elseif requirementType == "late_login" then
                local hour = tonumber(os.date("%H"))
                currentProgress = hour >= 0 and hour < 6 and 1 or 0
            elseif requirementType == "legendary_finds" then
                currentProgress = progressData.legendary_finds or 0
            end
            
            ::checkNext::
            if type(threshold) == "number" and currentProgress < threshold then
                requirementsMet = false
                break
            elseif type(threshold) == "boolean" and currentProgress == 0 then
                requirementsMet = false
                break
            end
        end
        
        -- Unlock achievement if requirements met
        if requirementsMet then
            self:UnlockAchievement(player, achievementId)
        end
        
        ::continue::
    end
end

-- ==========================================
-- ACHIEVEMENT UNLOCKING
-- ==========================================

function AchievementManager:UnlockAchievement(player, achievementId)
    local achievement = self.Achievements[achievementId]
    if not achievement then return end
    
    local playerAchievements = self.PlayerAchievements[player.UserId]
    
    -- Mark as unlocked
    playerAchievements.unlockedAchievements[achievementId] = {
        unlockedTime = tick(),
        achievementId = achievementId
    }
    
    -- Add achievement points
    local rarity = self.AchievementRarities[achievement.rarity]
    playerAchievements.achievementPoints = playerAchievements.achievementPoints + rarity.points
    
    -- Add title if provided
    if achievement.rewards.title then
        playerAchievements.titles[achievement.rewards.title] = {
            unlockedTime = tick(),
            source = achievementId
        }
    end
    
    -- Set as last unlocked
    playerAchievements.lastUnlocked = {
        achievementId = achievementId,
        time = tick()
    }
    
    -- Give rewards
    self:GiveAchievementRewards(player, achievement.rewards)
    
    -- Update global stats
    self:UpdateGlobalAchievementStats(achievementId)
    
    -- Notify player
    self:NotifyAchievementUnlock(player, achievement)
    
    print("🏆 AchievementManager: Player", player.Name, "unlocked achievement:", achievement.name)
end

function AchievementManager:GiveAchievementRewards(player, rewards)
    local economyManager = _G.EconomyManager
    local inventoryManager = _G.InventoryManager
    
    if rewards.coins and economyManager then
        economyManager:AddCurrency(player, rewards.coins)
    end
    
    if rewards.xp and economyManager then
        economyManager:AddExperience(player, rewards.xp)
    end
    
    if rewards.item and inventoryManager then
        inventoryManager:AddItem(player, rewards.item, 1)
    end
    
    -- Title is handled in UnlockAchievement
end

function AchievementManager:NotifyAchievementUnlock(player, achievement)
    local rarity = self.AchievementRarities[achievement.rarity]
    
    local notificationManager = _G.NotificationManager
    if notificationManager then
        notificationManager:ShowToast(
            "Achievement Unlocked! " .. rarity.icon,
            achievement.name,
            "🏆",
            "achievement",
            {
                color = rarity.color,
                duration = 5000 -- Show longer for achievements
            }
        )
    end
    
    -- Also show in chat
    local message = string.format("🏆 %s unlocked the achievement: %s %s", 
        player.Name, achievement.name, rarity.icon)
    
    -- Broadcast to all players for rare achievements
    if achievement.rarity == "EPIC" or achievement.rarity == "LEGENDARY" or achievement.rarity == "MYTHIC" then
        for _, otherPlayer in pairs(Players:GetPlayers()) do
            if notificationManager then
                notificationManager:ShowToast(
                    "Rare Achievement!",
                    message,
                    rarity.icon,
                    "global_achievement",
                    {color = rarity.color}
                )
            end
        end
    end
end

-- ==========================================
-- TITLE SYSTEM
-- ==========================================

function AchievementManager:SetActiveTitle(player, titleId)
    local playerAchievements = self.PlayerAchievements[player.UserId]
    
    if not playerAchievements.titles[titleId] then
        return {success = false, message = "Title not unlocked"}
    end
    
    playerAchievements.activeTitle = titleId
    
    -- Update player's display name or badge
    self:UpdatePlayerTitle(player, titleId)
    
    return {success = true, message = "Title equipped successfully"}
end

function AchievementManager:UpdatePlayerTitle(player, titleId)
    -- This would update the player's visual representation
    -- For now, we'll just store it in their leaderstats
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local titleValue = leaderstats:FindFirstChild("Title")
        if titleValue then
            titleValue.Value = titleId or "None"
        end
    end
end

function AchievementManager:GetAvailableTitles(player)
    local playerAchievements = self.PlayerAchievements[player.UserId]
    if not playerAchievements then return {} end
    
    local availableTitles = {}
    for titleId, titleData in pairs(playerAchievements.titles) do
        availableTitles[titleId] = {
            titleId = titleId,
            unlockedTime = titleData.unlockedTime,
            source = titleData.source,
            active = playerAchievements.activeTitle == titleId
        }
    end
    
    return availableTitles
end

-- ==========================================
-- STATISTICS & PROGRESS
-- ==========================================

function AchievementManager:GetPlayerAchievements(player)
    local playerAchievements = self.PlayerAchievements[player.UserId]
    if not playerAchievements then return {} end
    
    local achievementList = {}
    
    for achievementId, achievement in pairs(self.Achievements) do
        local isUnlocked = playerAchievements.unlockedAchievements[achievementId] ~= nil
        local progress = self:GetAchievementProgress(player, achievementId)
        
        -- Only show non-hidden achievements or unlocked hidden ones
        if not achievement.hidden or isUnlocked then
            achievementList[achievementId] = {
                id = achievementId,
                name = achievement.name,
                description = achievement.description,
                category = achievement.category,
                rarity = achievement.rarity,
                unlocked = isUnlocked,
                unlockedTime = isUnlocked and playerAchievements.unlockedAchievements[achievementId].unlockedTime or nil,
                progress = progress,
                rewards = achievement.rewards
            }
        end
    end
    
    return {
        achievements = achievementList,
        totalPoints = playerAchievements.achievementPoints,
        unlockedCount = self:CountUnlockedAchievements(player),
        totalCount = self:CountTotalAchievements()
    }
end

function AchievementManager:GetAchievementProgress(player, achievementId)
    local achievement = self.Achievements[achievementId]
    if not achievement then return {} end
    
    local progressData = self.PlayerProgress[player.UserId]
    local progress = {}
    
    for requirementType, threshold in pairs(achievement.requirements) do
        local currentProgress = 0
        
        if requirementType == "plants_planted" then
            currentProgress = progressData.plant_planted or 0
        elseif requirementType == "crops_harvested" then
            currentProgress = progressData.crop_harvested or 0
        elseif requirementType == "friends_made" then
            currentProgress = progressData.friends_made or 0
        elseif requirementType == "gifts_sent" then
            currentProgress = progressData.gifts_sent or 0
        elseif requirementType == "gardens_visited" then
            currentProgress = progressData.unique_gardens_visited or 0
        elseif requirementType == "total_coins_earned" then
            currentProgress = progressData.coins_earned or 0
        elseif requirementType == "total_coins_spent" then
            currentProgress = progressData.coins_spent or 0
        elseif requirementType == "mini_games_won" then
            currentProgress = progressData.mini_game_won or 0
        elseif requirementType == "perfect_scores" then
            currentProgress = progressData.perfect_score_achieved or 0
        elseif requirementType == "unique_seeds" then
            currentProgress = progressData.seed_count or 0
        elseif requirementType == "rare_plants_found" then
            currentProgress = #(progressData.rare_plants_found or {})
        elseif requirementType == "unique_decorations" then
            currentProgress = progressData.decoration_count or 0
        elseif requirementType == "areas_visited" then
            currentProgress = progressData.unique_areas_visited or 0
        elseif requirementType == "vip_status" then
            currentProgress = self:IsPlayerVIP(player) and 1 or 0
            threshold = 1
        elseif requirementType == "diamonds_spent" then
            currentProgress = progressData.diamonds_spent or 0
        elseif requirementType == "garden_health" then
            currentProgress = self:GetPlayerGardenHealth(player)
        end
        
        progress[requirementType] = {
            current = currentProgress,
            required = threshold,
            percentage = type(threshold) == "number" and math.min(currentProgress / threshold * 100, 100) or 0
        }
    end
    
    return progress
end

function AchievementManager:GetAchievementStats(player)
    local playerAchievements = self.PlayerAchievements[player.UserId]
    local progressData = self.PlayerProgress[player.UserId]
    
    if not playerAchievements or not progressData then return {} end
    
    return {
        totalAchievements = self:CountUnlockedAchievements(player),
        achievementPoints = playerAchievements.achievementPoints,
        categoryCounts = self:GetCategoryCounts(player),
        rarityCounts = self:GetRarityCounts(player),
        lastUnlocked = playerAchievements.lastUnlocked,
        completionPercentage = self:GetCompletionPercentage(player)
    }
end

function AchievementManager:CountUnlockedAchievements(player)
    local playerAchievements = self.PlayerAchievements[player.UserId]
    if not playerAchievements then return 0 end
    
    local count = 0
    for _, _ in pairs(playerAchievements.unlockedAchievements) do
        count = count + 1
    end
    return count
end

function AchievementManager:CountTotalAchievements()
    local count = 0
    for _, achievement in pairs(self.Achievements) do
        if not achievement.hidden then
            count = count + 1
        end
    end
    return count
end

function AchievementManager:GetCategoryCounts(player)
    local playerAchievements = self.PlayerAchievements[player.UserId]
    local categoryCounts = {}
    
    for _, achievement in pairs(self.Achievements) do
        local category = achievement.category
        if not categoryCounts[category] then
            categoryCounts[category] = {total = 0, unlocked = 0}
        end
        
        categoryCounts[category].total = categoryCounts[category].total + 1
        
        if playerAchievements.unlockedAchievements[achievement.id] then
            categoryCounts[category].unlocked = categoryCounts[category].unlocked + 1
        end
    end
    
    return categoryCounts
end

function AchievementManager:GetRarityCounts(player)
    local playerAchievements = self.PlayerAchievements[player.UserId]
    local rarityCounts = {}
    
    for _, achievement in pairs(self.Achievements) do
        local rarity = achievement.rarity
        if not rarityCounts[rarity] then
            rarityCounts[rarity] = {total = 0, unlocked = 0}
        end
        
        rarityCounts[rarity].total = rarityCounts[rarity].total + 1
        
        if playerAchievements.unlockedAchievements[achievement.id] then
            rarityCounts[rarity].unlocked = rarityCounts[rarity].unlocked + 1
        end
    end
    
    return rarityCounts
end

function AchievementManager:GetCompletionPercentage(player)
    local totalUnlocked = self:CountUnlockedAchievements(player)
    local totalAchievements = self:CountTotalAchievements()
    
    if totalAchievements == 0 then return 0 end
    
    return math.floor((totalUnlocked / totalAchievements) * 100)
end

-- ==========================================
-- SPECIAL CHECKS
-- ==========================================

function AchievementManager:CheckLoginAchievements(player)
    local hour = tonumber(os.date("%H"))
    
    -- Early bird achievement
    if hour < 6 then
        self:UpdateProgress(player, "early_login", 1)
    end
    
    -- Night owl achievement
    if hour >= 0 and hour < 6 then
        self:UpdateProgress(player, "late_login", 1)
    end
end

function AchievementManager:CheckSeasonalAchievements()
    -- This would check for seasonal achievement availability
    -- For now, seasonal achievements are handled by event completion
end

function AchievementManager:UpdateGlobalStats()
    -- Update global achievement statistics
    self.GlobalStats.lastUpdated = tick()
    
    -- Save global stats
    local success, error = pcall(function()
        self.AchievementStore:SetAsync("global_achievement_stats", self.GlobalStats)
    end)
    
    if not success then
        warn("❌ AchievementManager: Failed to save global stats:", error)
    end
end

function AchievementManager:UpdateGlobalAchievementStats(achievementId)
    self.GlobalStats.totalAchievementsUnlocked = self.GlobalStats.totalAchievementsUnlocked + 1
    
    if not self.GlobalStats.achievementCounts[achievementId] then
        self.GlobalStats.achievementCounts[achievementId] = 0
    end
    self.GlobalStats.achievementCounts[achievementId] = self.GlobalStats.achievementCounts[achievementId] + 1
end

-- ==========================================
-- HELPER FUNCTIONS
-- ==========================================

function AchievementManager:IsPlayerVIP(player)
    local vipManager = _G.VIPManager
    if vipManager then
        return vipManager:IsPlayerVIP(player)
    end
    return false
end

function AchievementManager:GetPlayerGardenHealth(player)
    local plotManager = _G.PlotManager
    if plotManager then
        return plotManager:GetGardenHealth(player)
    end
    return 0
end

-- ==========================================
-- PUBLIC API
-- ==========================================

function AchievementManager:UnlockTitle(player, titleId)
    local playerAchievements = self.PlayerAchievements[player.UserId]
    if not playerAchievements then return end
    
    playerAchievements.titles[titleId] = {
        unlockedTime = tick(),
        source = "external"
    }
end

function AchievementManager:AddLegendaryFind(player)
    self:UpdateProgress(player, "legendary_finds", 1)
end

function AchievementManager:GetPlayerTitle(player)
    local playerAchievements = self.PlayerAchievements[player.UserId]
    if playerAchievements and playerAchievements.activeTitle then
        return playerAchievements.activeTitle
    end
    return nil
end

-- ==========================================
-- CLEANUP
-- ==========================================

function AchievementManager:Cleanup()
    -- Save all player achievement data
    for userId, _ in pairs(self.PlayerAchievements) do
        local player = Players:GetPlayerByUserId(userId)
        if player then
            self:SavePlayerAchievementData(player)
            self:SavePlayerProgressData(player)
        end
    end
    
    -- Save global stats
    self:UpdateGlobalStats()
    
    print("🏆 AchievementManager: Achievement system cleaned up")
end

return AchievementManager
