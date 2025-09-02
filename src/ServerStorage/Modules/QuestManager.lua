--[[
    QuestManager.lua
    Server-Side Quest and Mission System
    
    Priority: 26 (Advanced Features phase)
    Dependencies: DataStoreService, Players, ReplicatedStorage
    Used by: UIManager, ProgressionManager, AchievementManager
    
    Features:
    - Daily and weekly quest system
    - Story-driven mission chains
    - VIP exclusive quests
    - Dynamic quest generation
    - Reward distribution
    - Progress tracking and persistence
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- Load required modules
local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)

local QuestManager = {}
QuestManager.__index = QuestManager

-- ==========================================
-- INITIALIZATION & SETUP
-- ==========================================

-- Data stores
QuestManager.QuestStore = DataStoreService:GetDataStore("QuestData_v1")
QuestManager.ProgressStore = DataStoreService:GetDataStore("QuestProgress_v1")

-- Quest state tracking
QuestManager.PlayerQuests = {} -- [userId] = {activeQuests, completedQuests, questHistory}
QuestManager.DailyQuests = {}
QuestManager.WeeklyQuests = {}
QuestManager.StoryQuests = {}

-- Quest generation
QuestManager.QuestTemplates = {}
QuestManager.LastDailyReset = 0
QuestManager.LastWeeklyReset = 0

-- Quest types
QuestManager.QuestTypes = {
    PLANT = "plant",
    HARVEST = "harvest",
    EARN = "earn",
    SPEND = "spend",
    VISIT = "visit",
    LEVEL = "level",
    VIP = "vip",
    SOCIAL = "social",
    COLLECT = "collect",
    STORY = "story"
}

-- Quest rarities and rewards
QuestManager.QuestRarities = {
    COMMON = {
        color = Color3.fromRGB(155, 155, 155),
        multiplier = 1.0,
        weight = 60
    },
    UNCOMMON = {
        color = Color3.fromRGB(30, 255, 0),
        multiplier = 1.5,
        weight = 25
    },
    RARE = {
        color = Color3.fromRGB(0, 112, 255),
        multiplier = 2.0,
        weight = 10
    },
    EPIC = {
        color = Color3.fromRGB(163, 53, 238),
        multiplier = 3.0,
        weight = 4
    },
    LEGENDARY = {
        color = Color3.fromRGB(255, 128, 0),
        multiplier = 5.0,
        weight = 1
    }
}

-- ==========================================
-- QUEST TEMPLATES DEFINITION
-- ==========================================

QuestManager.QuestTemplates = {
    -- Daily Quests
    daily_plant_seeds = {
        id = "daily_plant_seeds",
        type = QuestManager.QuestTypes.PLANT,
        category = "daily",
        name = "Green Thumb",
        description = "Plant {amount} seeds today",
        icon = "🌱",
        
        objectives = {
            {
                type = "plant_seeds",
                target = 5,
                current = 0
            }
        },
        
        rewards = {
            coins = 100,
            xp = 50,
            items = {"fertilizer", "water"}
        },
        
        rarity = "COMMON",
        timeLimit = 86400, -- 24 hours
        vipOnly = false
    },
    
    daily_harvest_plants = {
        id = "daily_harvest_plants",
        type = QuestManager.QuestTypes.HARVEST,
        category = "daily",
        name = "Bountiful Harvest",
        description = "Harvest {amount} mature plants",
        icon = "🌾",
        
        objectives = {
            {
                type = "harvest_plants",
                target = 10,
                current = 0
            }
        },
        
        rewards = {
            coins = 150,
            xp = 75,
            items = {"rare_seed"}
        },
        
        rarity = "COMMON",
        timeLimit = 86400,
        vipOnly = false
    },
    
    daily_earn_coins = {
        id = "daily_earn_coins",
        type = QuestManager.QuestTypes.EARN,
        category = "daily",
        name = "Profit Seeker",
        description = "Earn {amount} coins from sales",
        icon = "💰",
        
        objectives = {
            {
                type = "earn_coins",
                target = 500,
                current = 0
            }
        },
        
        rewards = {
            coins = 200,
            xp = 100
        },
        
        rarity = "UNCOMMON",
        timeLimit = 86400,
        vipOnly = false
    },
    
    -- VIP Daily Quests
    vip_daily_premium = {
        id = "vip_daily_premium",
        type = QuestManager.QuestTypes.VIP,
        category = "daily",
        name = "VIP Excellence",
        description = "Complete any 3 quests today",
        icon = "👑",
        
        objectives = {
            {
                type = "complete_quests",
                target = 3,
                current = 0
            }
        },
        
        rewards = {
            coins = 500,
            xp = 250,
            items = {"golden_fertilizer", "premium_seed"}
        },
        
        rarity = "RARE",
        timeLimit = 86400,
        vipOnly = true
    },
    
    -- Weekly Quests
    weekly_master_gardener = {
        id = "weekly_master_gardener",
        type = QuestManager.QuestTypes.PLANT,
        category = "weekly",
        name = "Master Gardener",
        description = "Plant 50 different types of seeds this week",
        icon = "🏆",
        
        objectives = {
            {
                type = "plant_variety",
                target = 50,
                current = 0,
                trackUnique = true
            }
        },
        
        rewards = {
            coins = 2000,
            xp = 1000,
            items = {"legendary_seed", "master_trophy"}
        },
        
        rarity = "EPIC",
        timeLimit = 604800, -- 7 days
        vipOnly = false
    },
    
    weekly_social_butterfly = {
        id = "weekly_social_butterfly",
        type = QuestManager.QuestTypes.SOCIAL,
        category = "weekly",
        name = "Social Butterfly",
        description = "Visit 10 friends' gardens this week",
        icon = "🦋",
        
        objectives = {
            {
                type = "visit_friends",
                target = 10,
                current = 0
            }
        },
        
        rewards = {
            coins = 1500,
            xp = 750,
            items = {"friendship_badge", "social_seed"}
        },
        
        rarity = "RARE",
        timeLimit = 604800,
        vipOnly = false
    },
    
    -- Story Quests
    story_first_garden = {
        id = "story_first_garden",
        type = QuestManager.QuestTypes.STORY,
        category = "story",
        name = "Welcome to Your Garden",
        description = "Plant your very first seed and watch it grow",
        icon = "🌸",
        
        objectives = {
            {
                type = "plant_first_seed",
                target = 1,
                current = 0
            },
            {
                type = "harvest_first_plant",
                target = 1,
                current = 0
            }
        },
        
        rewards = {
            coins = 50,
            xp = 100,
            items = {"starter_pack"}
        },
        
        rarity = "COMMON",
        timeLimit = nil, -- No time limit
        vipOnly = false,
        prerequisite = nil
    },
    
    story_expand_garden = {
        id = "story_expand_garden",
        type = QuestManager.QuestTypes.STORY,
        category = "story",
        name = "Growing Ambitions",
        description = "Unlock your second plot and plant 5 different crops",
        icon = "🌿",
        
        objectives = {
            {
                type = "unlock_plot",
                target = 2,
                current = 0
            },
            {
                type = "plant_variety",
                target = 5,
                current = 0,
                trackUnique = true
            }
        },
        
        rewards = {
            coins = 200,
            xp = 300,
            items = {"plot_expansion_deed"}
        },
        
        rarity = "UNCOMMON",
        timeLimit = nil,
        vipOnly = false,
        prerequisite = "story_first_garden"
    },
    
    story_market_trader = {
        id = "story_market_trader",
        type = QuestManager.QuestTypes.EARN,
        category = "story",
        name = "Market Trader",
        description = "Earn your first 1000 coins from selling crops",
        icon = "📊",
        
        objectives = {
            {
                type = "earn_total_coins",
                target = 1000,
                current = 0
            }
        },
        
        rewards = {
            coins = 300,
            xp = 400,
            items = {"trader_badge", "market_access"}
        },
        
        rarity = "UNCOMMON",
        timeLimit = nil,
        vipOnly = false,
        prerequisite = "story_expand_garden"
    }
}

-- ==========================================
-- INITIALIZATION
-- ==========================================

function QuestManager:Initialize()
    print("📋 QuestManager: Initializing quest system...")
    
    -- Initialize quest timers
    self:InitializeQuestTimers()
    
    -- Set up remote events
    self:SetupRemoteEvents()
    
    -- Set up player connections
    self:SetupPlayerConnections()
    
    -- Generate initial daily/weekly quests
    self:GenerateDailyQuests()
    self:GenerateWeeklyQuests()
    
    -- Start quest management loops
    self:StartQuestManagementLoop()
    
    print("✅ QuestManager: Quest system initialized")
end

function QuestManager:InitializeQuestTimers()
    local currentTime = tick()
    local currentDate = os.date("*t", currentTime)
    
    -- Calculate next daily reset (midnight)
    local nextMidnight = os.time({
        year = currentDate.year,
        month = currentDate.month,
        day = currentDate.day + 1,
        hour = 0,
        min = 0,
        sec = 0
    })
    
    self.LastDailyReset = nextMidnight - 86400 -- Previous midnight
    
    -- Calculate next weekly reset (Monday midnight)
    local daysUntilMonday = (9 - currentDate.wday) % 7
    if daysUntilMonday == 0 and currentDate.hour == 0 and currentDate.min == 0 then
        daysUntilMonday = 7 -- It's Monday midnight, next reset is next week
    end
    
    local nextWeeklyReset = nextMidnight + (daysUntilMonday * 86400)
    self.LastWeeklyReset = nextWeeklyReset - 604800 -- Previous Monday
end

function QuestManager:SetupRemoteEvents()
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then
        remoteEvents = Instance.new("Folder")
        remoteEvents.Name = "RemoteEvents"
        remoteEvents.Parent = ReplicatedStorage
    end
    
    -- Quest data requests
    local getQuestsFunction = Instance.new("RemoteFunction")
    getQuestsFunction.Name = "GetPlayerQuests"
    getQuestsFunction.Parent = remoteEvents
    getQuestsFunction.OnServerInvoke = function(player)
        return self:GetPlayerQuests(player)
    end
    
    -- Quest progress updates
    local updateQuestEvent = Instance.new("RemoteEvent")
    updateQuestEvent.Name = "UpdateQuestProgress"
    updateQuestEvent.Parent = remoteEvents
    
    -- Quest completion
    local completeQuestEvent = Instance.new("RemoteEvent")
    completeQuestEvent.Name = "QuestCompleted"
    completeQuestEvent.Parent = remoteEvents
    
    -- Quest abandonment
    local abandonQuestFunction = Instance.new("RemoteFunction")
    abandonQuestFunction.Name = "AbandonQuest"
    abandonQuestFunction.Parent = remoteEvents
    abandonQuestFunction.OnServerInvoke = function(player, questId)
        return self:AbandonQuest(player, questId)
    end
end

function QuestManager:SetupPlayerConnections()
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

function QuestManager:StartQuestManagementLoop()
    spawn(function()
        while true do
            local currentTime = tick()
            
            -- Check for daily quest reset
            if currentTime >= self.LastDailyReset + 86400 then
                self:ResetDailyQuests()
            end
            
            -- Check for weekly quest reset
            if currentTime >= self.LastWeeklyReset + 604800 then
                self:ResetWeeklyQuests()
            end
            
            -- Update quest progress for all players
            self:UpdateAllQuestProgress()
            
            -- Check for expired quests
            self:CheckExpiredQuests()
            
            wait(30) -- Check every 30 seconds
        end
    end)
end

-- ==========================================
-- PLAYER MANAGEMENT
-- ==========================================

function QuestManager:OnPlayerJoined(player)
    -- Initialize player quest data
    self.PlayerQuests[player.UserId] = {
        activeQuests = {},
        completedQuests = {},
        questHistory = {},
        lastDailyReset = self.LastDailyReset,
        lastWeeklyReset = self.LastWeeklyReset
    }
    
    -- Load player quest data
    spawn(function()
        self:LoadPlayerQuestData(player)
    end)
    
    print("📋 QuestManager: Player initialized:", player.Name)
end

function QuestManager:OnPlayerLeaving(player)
    -- Save player quest data
    spawn(function()
        self:SavePlayerQuestData(player)
    end)
    
    -- Clean up
    self.PlayerQuests[player.UserId] = nil
    
    print("📋 QuestManager: Player data saved:", player.Name)
end

function QuestManager:LoadPlayerQuestData(player)
    local success, playerData = pcall(function()
        return self.QuestStore:GetAsync("player_" .. player.UserId)
    end)
    
    if success and playerData then
        self.PlayerQuests[player.UserId] = playerData
        
        -- Assign new daily/weekly quests if needed
        self:CheckAndAssignNewQuests(player)
        
        print("📋 QuestManager: Loaded quest data for", player.Name)
    else
        -- New player - assign starter quests
        self:AssignStarterQuests(player)
        print("📋 QuestManager: New player, assigned starter quests:", player.Name)
    end
end

function QuestManager:SavePlayerQuestData(player)
    local playerData = self.PlayerQuests[player.UserId]
    if not playerData then return end
    
    local success, error = pcall(function()
        self.QuestStore:SetAsync("player_" .. player.UserId, playerData)
    end)
    
    if not success then
        warn("❌ QuestManager: Failed to save quest data for", player.Name, ":", error)
    end
end

-- ==========================================
-- QUEST GENERATION
-- ==========================================

function QuestManager:GenerateDailyQuests()
    self.DailyQuests = {}
    
    -- Regular daily quests (available to all players)
    local regularQuests = {
        "daily_plant_seeds",
        "daily_harvest_plants", 
        "daily_earn_coins"
    }
    
    for _, questId in ipairs(regularQuests) do
        local quest = self:CreateQuestFromTemplate(questId)
        if quest then
            self.DailyQuests[questId] = quest
        end
    end
    
    -- VIP daily quest
    local vipQuest = self:CreateQuestFromTemplate("vip_daily_premium")
    if vipQuest then
        self.DailyQuests["vip_daily_premium"] = vipQuest
    end
    
    print("📋 QuestManager: Generated", #self.DailyQuests, "daily quests")
end

function QuestManager:GenerateWeeklyQuests()
    self.WeeklyQuests = {}
    
    local weeklyQuestIds = {
        "weekly_master_gardener",
        "weekly_social_butterfly"
    }
    
    for _, questId in ipairs(weeklyQuestIds) do
        local quest = self:CreateQuestFromTemplate(questId)
        if quest then
            self.WeeklyQuests[questId] = quest
        end
    end
    
    print("📋 QuestManager: Generated", #self.WeeklyQuests, "weekly quests")
end

function QuestManager:CreateQuestFromTemplate(templateId)
    local template = self.QuestTemplates[templateId]
    if not template then
        warn("❌ QuestManager: Unknown quest template:", templateId)
        return nil
    end
    
    local quest = {
        id = HttpService:GenerateGUID(),
        templateId = templateId,
        type = template.type,
        category = template.category,
        name = template.name,
        description = template.description,
        icon = template.icon,
        
        objectives = self:DeepCopyTable(template.objectives),
        rewards = self:DeepCopyTable(template.rewards),
        
        rarity = template.rarity,
        timeLimit = template.timeLimit,
        vipOnly = template.vipOnly,
        prerequisite = template.prerequisite,
        
        startTime = tick(),
        endTime = template.timeLimit and (tick() + template.timeLimit) or nil,
        
        status = "active", -- active, completed, failed, abandoned
        progress = 0.0
    }
    
    -- Apply rarity multipliers to rewards
    local rarityData = self.QuestRarities[quest.rarity]
    if rarityData then
        if quest.rewards.coins then
            quest.rewards.coins = math.floor(quest.rewards.coins * rarityData.multiplier)
        end
        if quest.rewards.xp then
            quest.rewards.xp = math.floor(quest.rewards.xp * rarityData.multiplier)
        end
    end
    
    -- Randomize objectives for some quest types
    self:RandomizeQuestObjectives(quest)
    
    return quest
end

function QuestManager:RandomizeQuestObjectives(quest)
    -- Add some randomization to quest objectives to keep them fresh
    for _, objective in ipairs(quest.objectives) do
        if objective.type == "plant_seeds" then
            -- Randomize plant count (±20%)
            local variance = math.random(-20, 20) / 100
            objective.target = math.max(1, math.floor(objective.target * (1 + variance)))
            
        elseif objective.type == "earn_coins" then
            -- Randomize coin amount (±30%)
            local variance = math.random(-30, 30) / 100
            objective.target = math.max(10, math.floor(objective.target * (1 + variance)))
        end
    end
    
    -- Update description with actual values
    quest.description = string.gsub(quest.description, "{amount}", quest.objectives[1].target)
end

-- ==========================================
-- QUEST ASSIGNMENT
-- ==========================================

function QuestManager:AssignStarterQuests(player)
    local playerData = self.PlayerQuests[player.UserId]
    
    -- Assign first story quest
    local starterQuest = self:CreateQuestFromTemplate("story_first_garden")
    if starterQuest then
        playerData.activeQuests[starterQuest.id] = starterQuest
    end
    
    -- Assign some daily quests
    self:AssignDailyQuests(player)
end

function QuestManager:AssignDailyQuests(player)
    local playerData = self.PlayerQuests[player.UserId]
    local isVIP = self:IsPlayerVIP(player)
    
    -- Clear old daily quests
    for questId, quest in pairs(playerData.activeQuests) do
        if quest.category == "daily" then
            playerData.activeQuests[questId] = nil
        end
    end
    
    -- Assign new daily quests
    for questId, quest in pairs(self.DailyQuests) do
        if not quest.vipOnly or isVIP then
            local personalQuest = self:DeepCopyTable(quest)
            personalQuest.id = HttpService:GenerateGUID()
            personalQuest.startTime = tick()
            
            playerData.activeQuests[personalQuest.id] = personalQuest
        end
    end
    
    -- Send update to client
    self:SendQuestUpdateToPlayer(player)
end

function QuestManager:AssignWeeklyQuests(player)
    local playerData = self.PlayerQuests[player.UserId]
    
    -- Clear old weekly quests
    for questId, quest in pairs(playerData.activeQuests) do
        if quest.category == "weekly" then
            playerData.activeQuests[questId] = nil
        end
    end
    
    -- Assign new weekly quests
    for questId, quest in pairs(self.WeeklyQuests) do
        local personalQuest = self:DeepCopyTable(quest)
        personalQuest.id = HttpService:GenerateGUID()
        personalQuest.startTime = tick()
        
        playerData.activeQuests[personalQuest.id] = personalQuest
    end
    
    -- Send update to client
    self:SendQuestUpdateToPlayer(player)
end

function QuestManager:CheckAndAssignNewQuests(player)
    local playerData = self.PlayerQuests[player.UserId]
    
    -- Check if player needs new daily quests
    if playerData.lastDailyReset < self.LastDailyReset then
        self:AssignDailyQuests(player)
        playerData.lastDailyReset = self.LastDailyReset
    end
    
    -- Check if player needs new weekly quests
    if playerData.lastWeeklyReset < self.LastWeeklyReset then
        self:AssignWeeklyQuests(player)
        playerData.lastWeeklyReset = self.LastWeeklyReset
    end
    
    -- Check for available story quests
    self:CheckStoryQuestEligibility(player)
end

function QuestManager:CheckStoryQuestEligibility(player)
    local playerData = self.PlayerQuests[player.UserId]
    
    -- Check each story quest template
    for templateId, template in pairs(self.QuestTemplates) do
        if template.category == "story" then
            -- Check if player already has or completed this quest
            local hasQuest = false
            local completedQuest = false
            
            for _, quest in pairs(playerData.activeQuests) do
                if quest.templateId == templateId then
                    hasQuest = true
                    break
                end
            end
            
            for _, quest in pairs(playerData.completedQuests) do
                if quest.templateId == templateId then
                    completedQuest = true
                    break
                end
            end
            
            -- Check prerequisites
            local prerequisiteMet = true
            if template.prerequisite then
                prerequisiteMet = false
                for _, quest in pairs(playerData.completedQuests) do
                    if quest.templateId == template.prerequisite then
                        prerequisiteMet = true
                        break
                    end
                end
            end
            
            -- Assign quest if eligible
            if not hasQuest and not completedQuest and prerequisiteMet then
                local newQuest = self:CreateQuestFromTemplate(templateId)
                if newQuest then
                    playerData.activeQuests[newQuest.id] = newQuest
                    self:SendQuestUpdateToPlayer(player)
                    
                    -- Notify player
                    self:NotifyPlayerNewQuest(player, newQuest)
                end
            end
        end
    end
end

-- ==========================================
-- QUEST PROGRESS TRACKING
-- ==========================================

function QuestManager:UpdateQuestProgress(player, actionType, actionData)
    local playerData = self.PlayerQuests[player.UserId]
    if not playerData then return end
    
    local questsUpdated = false
    
    -- Update all active quests
    for questId, quest in pairs(playerData.activeQuests) do
        if quest.status == "active" then
            local questProgressUpdated = false
            
            -- Check each objective
            for i, objective in ipairs(quest.objectives) do
                if self:DoesActionMatchObjective(actionType, actionData, objective) then
                    -- Update objective progress
                    local oldProgress = objective.current
                    objective.current = objective.current + (actionData.amount or 1)
                    
                    -- Handle unique tracking
                    if objective.trackUnique and actionData.uniqueId then
                        if not objective.uniqueItems then
                            objective.uniqueItems = {}
                        end
                        
                        if not objective.uniqueItems[actionData.uniqueId] then
                            objective.uniqueItems[actionData.uniqueId] = true
                            objective.current = #objective.uniqueItems
                        end
                    end
                    
                    -- Cap at target
                    objective.current = math.min(objective.current, objective.target)
                    
                    if objective.current > oldProgress then
                        questProgressUpdated = true
                    end
                end
            end
            
            if questProgressUpdated then
                -- Update overall quest progress
                local totalProgress = 0
                local maxProgress = 0
                
                for _, objective in ipairs(quest.objectives) do
                    totalProgress = totalProgress + objective.current
                    maxProgress = maxProgress + objective.target
                end
                
                quest.progress = totalProgress / maxProgress
                questsUpdated = true
                
                -- Check if quest is completed
                if quest.progress >= 1.0 then
                    self:CompleteQuest(player, questId)
                end
            end
        end
    end
    
    if questsUpdated then
        -- Send update to client
        self:SendQuestUpdateToPlayer(player)
        
        -- Track analytics
        self:TrackQuestProgress(player, actionType, actionData)
    end
end

function QuestManager:DoesActionMatchObjective(actionType, actionData, objective)
    -- Match action types to objective types
    local matches = {
        ["plant_seed"] = {"plant_seeds", "plant_first_seed", "plant_variety"},
        ["harvest_plant"] = {"harvest_plants", "harvest_first_plant"},
        ["earn_coins"] = {"earn_coins", "earn_total_coins"},
        ["spend_coins"] = {"spend_coins"},
        ["visit_friend"] = {"visit_friends"},
        ["level_up"] = {"reach_level"},
        ["unlock_plot"] = {"unlock_plot"},
        ["complete_quest"] = {"complete_quests"}
    }
    
    local validTypes = matches[actionType]
    if not validTypes then return false end
    
    for _, validType in ipairs(validTypes) do
        if objective.type == validType then
            -- Additional validation based on objective type
            if objective.type == "plant_variety" and actionData.plantType then
                return true -- Will be handled by unique tracking
            elseif objective.type == "reach_level" and actionData.level then
                return actionData.level >= objective.target
            else
                return true
            end
        end
    end
    
    return false
end

function QuestManager:CompleteQuest(player, questId)
    local playerData = self.PlayerQuests[player.UserId]
    local quest = playerData.activeQuests[questId]
    
    if not quest or quest.status ~= "active" then return end
    
    -- Mark quest as completed
    quest.status = "completed"
    quest.endTime = tick()
    quest.progress = 1.0
    
    -- Move to completed quests
    playerData.completedQuests[questId] = quest
    playerData.activeQuests[questId] = nil
    
    -- Add to quest history
    table.insert(playerData.questHistory, {
        questId = questId,
        templateId = quest.templateId,
        completedTime = quest.endTime,
        rewards = quest.rewards
    })
    
    -- Distribute rewards
    self:DistributeQuestRewards(player, quest)
    
    -- Send completion notification
    self:NotifyPlayerQuestComplete(player, quest)
    
    -- Check for new story quests
    self:CheckStoryQuestEligibility(player)
    
    -- Update analytics
    self:TrackQuestCompletion(player, quest)
    
    -- Send update to client
    self:SendQuestUpdateToPlayer(player)
    
    print("📋 QuestManager: Quest completed:", player.Name, quest.name)
end

-- ==========================================
-- REWARD DISTRIBUTION
-- ==========================================

function QuestManager:DistributeQuestRewards(player, quest)
    local rewards = quest.rewards
    
    -- Distribute coin rewards
    if rewards.coins then
        local economyManager = _G.EconomyManager
        if economyManager then
            economyManager:AddPlayerCurrency(player, rewards.coins)
        end
    end
    
    -- Distribute XP rewards
    if rewards.xp then
        local progressionManager = _G.ProgressionManager
        if progressionManager then
            progressionManager:AddXP(player, rewards.xp)
        end
    end
    
    -- Distribute item rewards
    if rewards.items then
        local inventoryManager = _G.InventoryManager
        if inventoryManager then
            for _, item in ipairs(rewards.items) do
                inventoryManager:AddItem(player, item, 1)
            end
        end
    end
    
    print("📋 QuestManager: Distributed rewards to", player.Name, "- Coins:", rewards.coins or 0, "XP:", rewards.xp or 0)
end

-- ==========================================
-- QUEST MANAGEMENT
-- ==========================================

function QuestManager:AbandonQuest(player, questId)
    local playerData = self.PlayerQuests[player.UserId]
    local quest = playerData.activeQuests[questId]
    
    if not quest or quest.category == "story" then
        return false -- Cannot abandon story quests
    end
    
    -- Mark as abandoned
    quest.status = "abandoned"
    quest.endTime = tick()
    
    -- Remove from active quests
    playerData.activeQuests[questId] = nil
    
    -- Add to quest history
    table.insert(playerData.questHistory, {
        questId = questId,
        templateId = quest.templateId,
        abandonedTime = quest.endTime,
        progress = quest.progress
    })
    
    -- Send update to client
    self:SendQuestUpdateToPlayer(player)
    
    print("📋 QuestManager: Quest abandoned:", player.Name, quest.name)
    return true
end

function QuestManager:CheckExpiredQuests()
    local currentTime = tick()
    
    for userId, playerData in pairs(self.PlayerQuests) do
        for questId, quest in pairs(playerData.activeQuests) do
            if quest.endTime and currentTime >= quest.endTime then
                -- Quest expired
                quest.status = "failed"
                quest.endTime = currentTime
                
                -- Move to quest history
                table.insert(playerData.questHistory, {
                    questId = questId,
                    templateId = quest.templateId,
                    failedTime = quest.endTime,
                    reason = "expired",
                    progress = quest.progress
                })
                
                playerData.activeQuests[questId] = nil
                
                -- Notify player
                local player = Players:GetPlayerByUserId(userId)
                if player then
                    self:NotifyPlayerQuestExpired(player, quest)
                    self:SendQuestUpdateToPlayer(player)
                end
            end
        end
    end
end

function QuestManager:ResetDailyQuests()
    print("📋 QuestManager: Resetting daily quests...")
    
    -- Update reset timer
    self.LastDailyReset = self.LastDailyReset + 86400
    
    -- Generate new daily quests
    self:GenerateDailyQuests()
    
    -- Assign new daily quests to all players
    for userId, playerData in pairs(self.PlayerQuests) do
        local player = Players:GetPlayerByUserId(userId)
        if player then
            self:AssignDailyQuests(player)
            playerData.lastDailyReset = self.LastDailyReset
        end
    end
end

function QuestManager:ResetWeeklyQuests()
    print("📋 QuestManager: Resetting weekly quests...")
    
    -- Update reset timer
    self.LastWeeklyReset = self.LastWeeklyReset + 604800
    
    -- Generate new weekly quests
    self:GenerateWeeklyQuests()
    
    -- Assign new weekly quests to all players
    for userId, playerData in pairs(self.PlayerQuests) do
        local player = Players:GetPlayerByUserId(userId)
        if player then
            self:AssignWeeklyQuests(player)
            playerData.lastWeeklyReset = self.LastWeeklyReset
        end
    end
end

function QuestManager:UpdateAllQuestProgress()
    -- Periodic progress validation and cleanup
    local currentTime = tick()
    
    for userId, playerData in pairs(self.PlayerQuests) do
        for questId, quest in pairs(playerData.activeQuests) do
            -- Validate quest integrity
            if quest.status == "active" and quest.progress >= 1.0 then
                local player = Players:GetPlayerByUserId(userId)
                if player then
                    self:CompleteQuest(player, questId)
                end
            end
        end
    end
end

-- ==========================================
-- CLIENT COMMUNICATION
-- ==========================================

function QuestManager:GetPlayerQuests(player)
    local playerData = self.PlayerQuests[player.UserId]
    if not playerData then return {} end
    
    return {
        activeQuests = playerData.activeQuests,
        completedQuests = playerData.completedQuests,
        questHistory = playerData.questHistory,
        dailyResetTime = self.LastDailyReset + 86400,
        weeklyResetTime = self.LastWeeklyReset + 604800
    }
end

function QuestManager:SendQuestUpdateToPlayer(player)
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if remoteEvents then
        local updateEvent = remoteEvents:FindFirstChild("UpdateQuestProgress")
        if updateEvent then
            local questData = self:GetPlayerQuests(player)
            updateEvent:FireClient(player, questData)
        end
    end
end

-- ==========================================
-- NOTIFICATIONS
-- ==========================================

function QuestManager:NotifyPlayerNewQuest(player, quest)
    local notificationManager = _G.NotificationManager
    if notificationManager then
        notificationManager:ShowToast(
            "New Quest Available! 📋",
            quest.name,
            quest.icon,
            "quest"
        )
    end
end

function QuestManager:NotifyPlayerQuestComplete(player, quest)
    local notificationManager = _G.NotificationManager
    if notificationManager then
        local rewardText = ""
        if quest.rewards.coins then
            rewardText = rewardText .. quest.rewards.coins .. " coins "
        end
        if quest.rewards.xp then
            rewardText = rewardText .. quest.rewards.xp .. " XP"
        end
        
        notificationManager:ShowAchievementPopup(
            "Quest Completed! ✅",
            quest.name,
            rewardText,
            quest.icon,
            self.QuestRarities[quest.rarity].color
        )
    end
end

function QuestManager:NotifyPlayerQuestExpired(player, quest)
    local notificationManager = _G.NotificationManager
    if notificationManager then
        notificationManager:ShowToast(
            "Quest Expired ⏰",
            quest.name .. " has expired",
            "⏰",
            "warning"
        )
    end
end

-- ==========================================
-- ANALYTICS & TRACKING
-- ==========================================

function QuestManager:TrackQuestProgress(player, actionType, actionData)
    local analyticsManager = _G.AnalyticsManager
    if analyticsManager then
        analyticsManager:TrackEvent(player, {
            category = "quest",
            action = "progress",
            label = actionType,
            properties = {
                actionType = actionType,
                actionData = actionData
            }
        })
    end
end

function QuestManager:TrackQuestCompletion(player, quest)
    local analyticsManager = _G.AnalyticsManager
    if analyticsManager then
        analyticsManager:TrackEvent(player, {
            category = "quest",
            action = "completed",
            label = quest.templateId,
            value = quest.rewards.coins or 0,
            properties = {
                questType = quest.type,
                questCategory = quest.category,
                questRarity = quest.rarity,
                completionTime = quest.endTime - quest.startTime,
                rewards = quest.rewards
            }
        })
    end
end

-- ==========================================
-- HELPER FUNCTIONS
-- ==========================================

function QuestManager:IsPlayerVIP(player)
    local vipManager = _G.VIPManager
    if vipManager then
        return vipManager:IsPlayerVIP(player)
    end
    return false
end

function QuestManager:DeepCopyTable(original)
    local copy = {}
    for key, value in pairs(original) do
        if type(value) == "table" then
            copy[key] = self:DeepCopyTable(value)
        else
            copy[key] = value
        end
    end
    return copy
end

-- ==========================================
-- PUBLIC API
-- ==========================================

function QuestManager:GetQuestProgress(player, questId)
    local playerData = self.PlayerQuests[player.UserId]
    if playerData and playerData.activeQuests[questId] then
        return playerData.activeQuests[questId].progress
    end
    return 0
end

function QuestManager:GetPlayerQuestStats(player)
    local playerData = self.PlayerQuests[player.UserId]
    if not playerData then return {} end
    
    return {
        activeCount = #playerData.activeQuests,
        completedCount = #playerData.completedQuests,
        totalRewardsEarned = self:CalculateTotalRewards(playerData.completedQuests)
    }
end

function QuestManager:CalculateTotalRewards(completedQuests)
    local totalCoins = 0
    local totalXP = 0
    
    for _, quest in pairs(completedQuests) do
        if quest.rewards.coins then
            totalCoins = totalCoins + quest.rewards.coins
        end
        if quest.rewards.xp then
            totalXP = totalXP + quest.rewards.xp
        end
    end
    
    return {
        coins = totalCoins,
        xp = totalXP
    }
end

function QuestManager:ForceCompleteQuest(player, questId)
    -- Admin function for testing
    local playerData = self.PlayerQuests[player.UserId]
    local quest = playerData.activeQuests[questId]
    
    if quest then
        -- Complete all objectives
        for _, objective in ipairs(quest.objectives) do
            objective.current = objective.target
        end
        
        self:CompleteQuest(player, questId)
        return true
    end
    
    return false
end

-- ==========================================
-- CLEANUP
-- ==========================================

function QuestManager:Cleanup()
    -- Save all player quest data
    for userId, _ in pairs(self.PlayerQuests) do
        local player = Players:GetPlayerByUserId(userId)
        if player then
            self:SavePlayerQuestData(player)
        end
    end
    
    print("📋 QuestManager: Quest system cleaned up")
end

return QuestManager
