--[[
    EventManager.lua
    Server-Side Special Events and Seasonal Celebrations System
    
    Priority: 30 (Advanced Features phase)
    Dependencies: DataStoreService, ReplicatedStorage, TweenService
    Used by: NotificationManager, VIPManager, EconomyManager
    
    Features:
    - Special events and seasonal celebrations
    - Limited-time challenges and rewards
    - Community events and competitions
    - VIP exclusive events
    - Event leaderboards and achievements
    - Dynamic event content and progression
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

-- Load required modules
local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)

local EventManager = {}
EventManager.__index = EventManager

-- ==========================================
-- INITIALIZATION & SETUP
-- ==========================================

-- Data stores
EventManager.EventStore = DataStoreService:GetDataStore("EventData_v1")
EventManager.LeaderboardStore = DataStoreService:GetDataStore("EventLeaderboards_v1")

-- Event state tracking
EventManager.ActiveEvents = {} -- [eventId] = eventData
EventManager.PlayerEventData = {} -- [userId] = {events = {}, achievements = {}}
EventManager.EventLeaderboards = {} -- [eventId] = {players = {}}

-- Event types
EventManager.EventTypes = {
    SEASONAL = "seasonal",
    COMMUNITY = "community",
    CHALLENGE = "challenge",
    COMPETITION = "competition",
    VIP_EXCLUSIVE = "vip_exclusive",
    DAILY = "daily",
    WEEKLY = "weekly"
}

-- Event statuses
EventManager.EventStatus = {
    SCHEDULED = "scheduled",
    ACTIVE = "active",
    ENDING = "ending",
    COMPLETED = "completed",
    CANCELLED = "cancelled"
}

-- Predefined events
EventManager.EventTemplates = {
    -- Seasonal Events
    spring_festival = {
        name = "Spring Festival",
        description = "Celebrate the arrival of spring with special flower planting!",
        type = EventManager.EventTypes.SEASONAL,
        duration = 7 * 24 * 3600, -- 7 days
        season = "spring",
        requirements = {},
        vipOnly = false,
        rewards = {
            participation = {coins = 500, xp = 1000},
            milestone1 = {coins = 1000, xp = 2000, item = "spring_decoration"},
            milestone2 = {coins = 2000, xp = 4000, item = "rainbow_seeds"},
            completion = {coins = 5000, xp = 10000, item = "spring_crown", title = "Spring Guardian"}
        },
        tasks = {
            {id = "plant_flowers", name = "Plant 25 Flowers", target = 25, progress = 0},
            {id = "harvest_spring", name = "Harvest 50 Spring Crops", target = 50, progress = 0},
            {id = "beauty_score", name = "Achieve 100 Beauty Score", target = 100, progress = 0}
        }
    },
    
    summer_heat_wave = {
        name = "Summer Heat Wave",
        description = "Beat the heat and grow drought-resistant plants!",
        type = EventManager.EventTypes.SEASONAL,
        duration = 5 * 24 * 3600, -- 5 days
        season = "summer",
        requirements = {},
        vipOnly = false,
        rewards = {
            participation = {coins = 750, xp = 1500},
            milestone1 = {coins = 1500, xp = 3000, item = "cooling_fan"},
            milestone2 = {coins = 3000, xp = 6000, item = "heat_resistant_seeds"},
            completion = {coins = 7500, xp = 15000, item = "sun_hat", title = "Heat Master"}
        },
        tasks = {
            {id = "survive_drought", name = "Keep plants alive during drought", target = 1, progress = 0},
            {id = "water_plants", name = "Water plants 100 times", target = 100, progress = 0},
            {id = "grow_cacti", name = "Grow 15 Cacti", target = 15, progress = 0}
        }
    },
    
    autumn_harvest = {
        name = "Autumn Harvest Festival",
        description = "Celebrate the bounty of autumn with massive harvests!",
        type = EventManager.EventTypes.SEASONAL,
        duration = 10 * 24 * 3600, -- 10 days
        season = "autumn",
        requirements = {},
        vipOnly = false,
        rewards = {
            participation = {coins = 1000, xp = 2000},
            milestone1 = {coins = 2000, xp = 4000, item = "harvest_basket"},
            milestone2 = {coins = 4000, xp = 8000, item = "autumn_decoration_pack"},
            completion = {coins = 10000, xp = 20000, item = "harvest_crown", title = "Harvest King"}
        },
        tasks = {
            {id = "mega_harvest", name = "Harvest 200 Crops", target = 200, progress = 0},
            {id = "pumpkin_grow", name = "Grow 20 Pumpkins", target = 20, progress = 0},
            {id = "earn_coins", name = "Earn 50,000 Coins", target = 50000, progress = 0}
        }
    },
    
    winter_wonderland = {
        name = "Winter Wonderland",
        description = "Transform your garden into a magical winter paradise!",
        type = EventManager.EventTypes.SEASONAL,
        duration = 14 * 24 * 3600, -- 14 days
        season = "winter",
        requirements = {},
        vipOnly = false,
        rewards = {
            participation = {coins = 1250, xp = 2500},
            milestone1 = {coins = 2500, xp = 5000, item = "snowman_decoration"},
            milestone2 = {coins = 5000, xp = 10000, item = "winter_seed_pack"},
            completion = {coins = 12500, xp = 25000, item = "ice_crown", title = "Winter Wizard"}
        },
        tasks = {
            {id = "place_decorations", name = "Place 15 Winter Decorations", target = 15, progress = 0},
            {id = "grow_evergreens", name = "Grow 30 Evergreen Trees", target = 30, progress = 0},
            {id = "beauty_winter", name = "Achieve 200 Beauty Score", target = 200, progress = 0}
        }
    },
    
    -- Community Events
    global_garden_challenge = {
        name = "Global Garden Challenge",
        description = "Work together to reach the community goal!",
        type = EventManager.EventTypes.COMMUNITY,
        duration = 3 * 24 * 3600, -- 3 days
        season = nil,
        requirements = {},
        vipOnly = false,
        communityGoal = {
            target = 1000000, -- 1 million crops harvested by community
            progress = 0,
            metric = "crops_harvested"
        },
        rewards = {
            participation = {coins = 2000, xp = 4000},
            community_success = {coins = 10000, xp = 20000, item = "unity_badge", title = "Community Hero"}
        },
        tasks = {
            {id = "contribute_harvest", name = "Harvest crops for the community", target = 100, progress = 0}
        }
    },
    
    speed_growing_contest = {
        name = "Speed Growing Contest",
        description = "Who can grow plants the fastest?",
        type = EventManager.EventTypes.COMPETITION,
        duration = 2 * 3600, -- 2 hours
        season = nil,
        requirements = {},
        vipOnly = false,
        competitive = true,
        rewards = {
            rank1 = {coins = 50000, xp = 100000, item = "golden_watering_can", title = "Speed Master"},
            rank2 = {coins = 30000, xp = 60000, item = "silver_watering_can", title = "Quick Grower"},
            rank3 = {coins = 20000, xp = 40000, item = "bronze_watering_can", title = "Fast Farmer"},
            participation = {coins = 5000, xp = 10000}
        },
        tasks = {
            {id = "speed_harvest", name = "Harvest crops as fast as possible", target = 1000, progress = 0}
        }
    },
    
    -- VIP Exclusive Events
    diamond_garden_gala = {
        name = "Diamond Garden Gala",
        description = "Exclusive VIP event with premium rewards!",
        type = EventManager.EventTypes.VIP_EXCLUSIVE,
        duration = 5 * 24 * 3600, -- 5 days
        season = nil,
        requirements = {vip = true},
        vipOnly = true,
        rewards = {
            participation = {coins = 10000, xp = 20000, diamonds = 100},
            milestone1 = {coins = 20000, xp = 40000, diamonds = 200, item = "diamond_seeds"},
            milestone2 = {coins = 40000, xp = 80000, diamonds = 500, item = "platinum_decoration"},
            completion = {coins = 100000, xp = 200000, diamonds = 1000, item = "diamond_crown", title = "VIP Elite"}
        },
        tasks = {
            {id = "luxury_garden", name = "Create a luxury garden", target = 1, progress = 0},
            {id = "rare_plants", name = "Grow 50 Rare Plants", target = 50, progress = 0},
            {id = "spend_diamonds", name = "Spend 500 Diamonds", target = 500, progress = 0}
        }
    },
    
    -- Challenge Events
    pest_invasion = {
        name = "Pest Invasion",
        description = "Defend your garden from a massive pest invasion!",
        type = EventManager.EventTypes.CHALLENGE,
        duration = 24 * 3600, -- 1 day
        season = nil,
        requirements = {},
        vipOnly = false,
        difficulty = "hard",
        rewards = {
            participation = {coins = 3000, xp = 6000},
            victory = {coins = 15000, xp = 30000, item = "pest_defender_badge", title = "Garden Defender"}
        },
        tasks = {
            {id = "defend_plants", name = "Protect 100 plants from pests", target = 100, progress = 0},
            {id = "use_pesticide", name = "Use pesticide 50 times", target = 50, progress = 0}
        }
    },
    
    drought_survival = {
        name = "Drought Survival",
        description = "Survive a severe drought and keep your garden alive!",
        type = EventManager.EventTypes.CHALLENGE,
        duration = 12 * 3600, -- 12 hours
        season = nil,
        requirements = {},
        vipOnly = false,
        difficulty = "extreme",
        rewards = {
            participation = {coins = 5000, xp = 10000},
            survival = {coins = 25000, xp = 50000, item = "drought_survivor_medal", title = "Drought Master"}
        },
        tasks = {
            {id = "keep_alive", name = "Keep 75% of plants alive", target = 75, progress = 0},
            {id = "water_conservation", name = "Use water efficiently", target = 1, progress = 0}
        }
    }
}

-- Event schedule
EventManager.EventSchedule = {
    -- Daily events
    daily_challenges = {
        frequency = "daily",
        events = {"mini_harvest_challenge", "growth_speed_test", "beauty_contest"}
    },
    -- Weekly events
    weekly_specials = {
        frequency = "weekly",
        events = {"speed_growing_contest", "community_garden_build"}
    },
    -- Monthly events
    monthly_festivals = {
        frequency = "monthly",
        events = {"mega_harvest_festival", "rare_plant_exhibition"}
    }
}

-- ==========================================
-- INITIALIZATION
-- ==========================================

function EventManager:Initialize()
    print("🎉 EventManager: Initializing event system...")
    
    -- Set up remote events
    self:SetupRemoteEvents()
    
    -- Set up player connections
    self:SetupPlayerConnections()
    
    -- Load active events
    self:LoadActiveEvents()
    
    -- Start event scheduler
    self:StartEventScheduler()
    
    -- Start event update loop
    self:StartEventUpdateLoop()
    
    print("✅ EventManager: Event system initialized")
end

function EventManager:SetupRemoteEvents()
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then
        remoteEvents = Instance.new("Folder")
        remoteEvents.Name = "RemoteEvents"
        remoteEvents.Parent = ReplicatedStorage
    end
    
    -- Get active events
    local getActiveEventsFunction = Instance.new("RemoteFunction")
    getActiveEventsFunction.Name = "GetActiveEvents"
    getActiveEventsFunction.Parent = remoteEvents
    getActiveEventsFunction.OnServerInvoke = function(player)
        return self:GetActiveEventsForPlayer(player)
    end
    
    -- Join event
    local joinEventFunction = Instance.new("RemoteFunction")
    joinEventFunction.Name = "JoinEvent"
    joinEventFunction.Parent = remoteEvents
    joinEventFunction.OnServerInvoke = function(player, eventId)
        return self:JoinEvent(player, eventId)
    end
    
    -- Get event progress
    local getEventProgressFunction = Instance.new("RemoteFunction")
    getEventProgressFunction.Name = "GetEventProgress"
    getEventProgressFunction.Parent = remoteEvents
    getEventProgressFunction.OnServerInvoke = function(player, eventId)
        return self:GetEventProgress(player, eventId)
    end
    
    -- Claim event rewards
    local claimEventRewardFunction = Instance.new("RemoteFunction")
    claimEventRewardFunction.Name = "ClaimEventReward"
    claimEventRewardFunction.Parent = remoteEvents
    claimEventRewardFunction.OnServerInvoke = function(player, eventId, rewardType)
        return self:ClaimEventReward(player, eventId, rewardType)
    end
    
    -- Get leaderboard
    local getLeaderboardFunction = Instance.new("RemoteFunction")
    getLeaderboardFunction.Name = "GetEventLeaderboard"
    getLeaderboardFunction.Parent = remoteEvents
    getLeaderboardFunction.OnServerInvoke = function(player, eventId)
        return self:GetEventLeaderboard(eventId)
    end
end

function EventManager:SetupPlayerConnections()
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

function EventManager:LoadActiveEvents()
    -- Load events that should be active
    local success, eventData = pcall(function()
        return self.EventStore:GetAsync("active_events")
    end)
    
    if success and eventData then
        for eventId, event in pairs(eventData) do
            if self:IsEventStillActive(event) then
                self.ActiveEvents[eventId] = event
                print("🎉 EventManager: Loaded active event:", event.name)
            end
        end
    end
    
    -- Check if we need to start seasonal events
    self:CheckSeasonalEvents()
end

function EventManager:StartEventScheduler()
    spawn(function()
        while true do
            wait(3600) -- Check every hour
            self:ProcessEventSchedule()
        end
    end)
end

function EventManager:StartEventUpdateLoop()
    spawn(function()
        while true do
            self:UpdateActiveEvents()
            wait(60) -- Update every minute
        end
    end)
end

-- ==========================================
-- PLAYER MANAGEMENT
-- ==========================================

function EventManager:OnPlayerJoined(player)
    -- Initialize player event data
    self.PlayerEventData[player.UserId] = {
        events = {},
        achievements = {},
        joinedEvents = {}
    }
    
    -- Load player event data
    spawn(function()
        self:LoadPlayerEventData(player)
    end)
    
    print("🎉 EventManager: Player initialized:", player.Name)
end

function EventManager:OnPlayerLeaving(player)
    -- Save player event data
    spawn(function()
        self:SavePlayerEventData(player)
    end)
    
    -- Clean up
    self.PlayerEventData[player.UserId] = nil
    
    print("🎉 EventManager: Player data saved:", player.Name)
end

function EventManager:LoadPlayerEventData(player)
    local success, playerData = pcall(function()
        return self.EventStore:GetAsync("player_" .. player.UserId)
    end)
    
    if success and playerData then
        self.PlayerEventData[player.UserId] = playerData
        print("🎉 EventManager: Loaded event data for", player.Name)
    else
        print("🎉 EventManager: New player event data:", player.Name)
    end
end

function EventManager:SavePlayerEventData(player)
    local playerData = self.PlayerEventData[player.UserId]
    if not playerData then return end
    
    local success, error = pcall(function()
        self.EventStore:SetAsync("player_" .. player.UserId, playerData)
    end)
    
    if not success then
        warn("❌ EventManager: Failed to save event data for", player.Name, ":", error)
    end
end

-- ==========================================
-- EVENT MANAGEMENT
-- ==========================================

function EventManager:CreateEvent(eventTemplate, startTime, customDuration)
    local eventId = HttpService:GenerateGUID()
    
    local event = {
        id = eventId,
        template = eventTemplate,
        name = self.EventTemplates[eventTemplate].name,
        description = self.EventTemplates[eventTemplate].description,
        type = self.EventTemplates[eventTemplate].type,
        startTime = startTime or tick(),
        endTime = (startTime or tick()) + (customDuration or self.EventTemplates[eventTemplate].duration),
        status = EventManager.EventStatus.ACTIVE,
        participants = {},
        progress = {},
        rewards = self.EventTemplates[eventTemplate].rewards,
        tasks = self.EventTemplates[eventTemplate].tasks,
        requirements = self.EventTemplates[eventTemplate].requirements or {},
        vipOnly = self.EventTemplates[eventTemplate].vipOnly or false
    }
    
    -- Copy community goal if applicable
    if self.EventTemplates[eventTemplate].communityGoal then
        event.communityGoal = self.EventTemplates[eventTemplate].communityGoal
    end
    
    -- Initialize task progress
    for _, task in ipairs(event.tasks) do
        task.progress = 0
    end
    
    self.ActiveEvents[eventId] = event
    
    -- Initialize leaderboard for competitive events
    if self.EventTemplates[eventTemplate].competitive then
        self.EventLeaderboards[eventId] = {
            players = {},
            updated = tick()
        }
    end
    
    -- Notify all players
    self:NotifyEventStart(event)
    
    print("🎉 EventManager: Created event:", event.name, "Duration:", (event.endTime - event.startTime) / 3600, "hours")
    
    return eventId
end

function EventManager:JoinEvent(player, eventId)
    local event = self.ActiveEvents[eventId]
    if not event then
        return {success = false, message = "Event not found"}
    end
    
    if event.status ~= EventManager.EventStatus.ACTIVE then
        return {success = false, message = "Event is not active"}
    end
    
    -- Check requirements
    if event.vipOnly and not self:IsPlayerVIP(player) then
        return {success = false, message = "VIP membership required"}
    end
    
    -- Check if player already joined
    if event.participants[player.UserId] then
        return {success = false, message = "Already joined this event"}
    end
    
    -- Add player to event
    event.participants[player.UserId] = {
        playerId = player.UserId,
        playerName = player.Name,
        joinTime = tick(),
        progress = {},
        rewardsClaimed = {}
    }
    
    -- Initialize progress for player
    for _, task in ipairs(event.tasks) do
        event.participants[player.UserId].progress[task.id] = 0
    end
    
    -- Add to player's joined events
    local playerData = self.PlayerEventData[player.UserId]
    playerData.joinedEvents[eventId] = {
        eventId = eventId,
        joinTime = tick(),
        status = "active"
    }
    
    -- Notify player
    local notificationManager = _G.NotificationManager
    if notificationManager then
        notificationManager:ShowToast(
            "Event Joined! 🎉",
            "You joined: " .. event.name,
            "🎯",
            "event"
        )
    end
    
    print("🎉 EventManager: Player", player.Name, "joined event:", event.name)
    
    return {success = true, message = "Successfully joined event"}
end

function EventManager:GetActiveEventsForPlayer(player)
    local availableEvents = {}
    
    for eventId, event in pairs(self.ActiveEvents) do
        if event.status == EventManager.EventStatus.ACTIVE then
            -- Check if player can join
            if not event.vipOnly or self:IsPlayerVIP(player) then
                availableEvents[eventId] = {
                    id = eventId,
                    name = event.name,
                    description = event.description,
                    type = event.type,
                    endTime = event.endTime,
                    timeRemaining = event.endTime - tick(),
                    tasks = event.tasks,
                    rewards = event.rewards,
                    vipOnly = event.vipOnly,
                    joined = event.participants[player.UserId] ~= nil
                }
            end
        end
    end
    
    return availableEvents
end

function EventManager:GetEventProgress(player, eventId)
    local event = self.ActiveEvents[eventId]
    if not event then return {} end
    
    local participant = event.participants[player.UserId]
    if not participant then return {} end
    
    return {
        progress = participant.progress,
        rewardsClaimed = participant.rewardsClaimed,
        joinTime = participant.joinTime
    }
end

function EventManager:UpdatePlayerEventProgress(player, eventId, taskId, amount)
    local event = self.ActiveEvents[eventId]
    if not event then return end
    
    local participant = event.participants[player.UserId]
    if not participant then return end
    
    -- Update progress
    if not participant.progress[taskId] then
        participant.progress[taskId] = 0
    end
    
    participant.progress[taskId] = participant.progress[taskId] + amount
    
    -- Check if task is completed
    for _, task in ipairs(event.tasks) do
        if task.id == taskId and participant.progress[taskId] >= task.target then
            self:OnTaskCompleted(player, eventId, taskId)
        end
    end
    
    -- Update leaderboard for competitive events
    if event.competitive then
        self:UpdateLeaderboard(eventId, player, participant.progress[taskId] or 0)
    end
    
    -- Update community progress
    if event.communityGoal and event.communityGoal.metric == taskId then
        event.communityGoal.progress = event.communityGoal.progress + amount
    end
end

function EventManager:OnTaskCompleted(player, eventId, taskId)
    -- Notify player of task completion
    local notificationManager = _G.NotificationManager
    if notificationManager then
        notificationManager:ShowToast(
            "Task Completed! ✅",
            "You completed a task in the event!",
            "🎯",
            "task"
        )
    end
    
    print("🎉 EventManager: Player", player.Name, "completed task", taskId, "in event", eventId)
end

-- ==========================================
-- REWARD SYSTEM
-- ==========================================

function EventManager:ClaimEventReward(player, eventId, rewardType)
    local event = self.ActiveEvents[eventId]
    if not event then
        return {success = false, message = "Event not found"}
    end
    
    local participant = event.participants[player.UserId]
    if not participant then
        return {success = false, message = "Not participating in this event"}
    end
    
    -- Check if reward already claimed
    if participant.rewardsClaimed[rewardType] then
        return {success = false, message = "Reward already claimed"}
    end
    
    -- Check eligibility
    local eligible, reason = self:IsEligibleForReward(player, event, rewardType)
    if not eligible then
        return {success = false, message = reason}
    end
    
    -- Get reward data
    local rewardData = event.rewards[rewardType]
    if not rewardData then
        return {success = false, message = "Invalid reward type"}
    end
    
    -- Give rewards
    self:GiveRewards(player, rewardData)
    
    -- Mark as claimed
    participant.rewardsClaimed[rewardType] = tick()
    
    -- Notify player
    local notificationManager = _G.NotificationManager
    if notificationManager then
        notificationManager:ShowToast(
            "Reward Claimed! 🎁",
            "You received event rewards!",
            "🏆",
            "reward"
        )
    end
    
    return {success = true, message = "Reward claimed successfully"}
end

function EventManager:IsEligibleForReward(player, event, rewardType)
    local participant = event.participants[player.UserId]
    
    if rewardType == "participation" then
        return true, "Eligible"
    end
    
    if rewardType == "milestone1" then
        -- Check if at least one task is completed
        for _, task in ipairs(event.tasks) do
            if participant.progress[task.id] and participant.progress[task.id] >= task.target then
                return true, "Eligible"
            end
        end
        return false, "Complete at least one task"
    end
    
    if rewardType == "milestone2" then
        -- Check if at least half the tasks are completed
        local completedTasks = 0
        for _, task in ipairs(event.tasks) do
            if participant.progress[task.id] and participant.progress[task.id] >= task.target then
                completedTasks = completedTasks + 1
            end
        end
        if completedTasks >= math.ceil(#event.tasks / 2) then
            return true, "Eligible"
        end
        return false, "Complete more tasks"
    end
    
    if rewardType == "completion" then
        -- Check if all tasks are completed
        for _, task in ipairs(event.tasks) do
            if not participant.progress[task.id] or participant.progress[task.id] < task.target then
                return false, "Complete all tasks"
            end
        end
        return true, "Eligible"
    end
    
    if rewardType == "community_success" then
        if event.communityGoal and event.communityGoal.progress >= event.communityGoal.target then
            return true, "Eligible"
        end
        return false, "Community goal not reached"
    end
    
    -- Competitive rewards
    if string.find(rewardType, "rank") then
        local rank = self:GetPlayerRank(event.id, player)
        local targetRank = tonumber(string.sub(rewardType, 5)) -- Extract number from "rank1", "rank2", etc.
        if rank <= targetRank then
            return true, "Eligible"
        end
        return false, "Rank not achieved"
    end
    
    return false, "Unknown reward type"
end

function EventManager:GiveRewards(player, rewardData)
    local economyManager = _G.EconomyManager
    local inventoryManager = _G.InventoryManager
    local achievementManager = _G.AchievementManager
    
    -- Give coins
    if rewardData.coins and economyManager then
        economyManager:AddCurrency(player, rewardData.coins)
    end
    
    -- Give XP
    if rewardData.xp and economyManager then
        economyManager:AddExperience(player, rewardData.xp)
    end
    
    -- Give diamonds (premium currency)
    if rewardData.diamonds and economyManager then
        economyManager:AddPremiumCurrency(player, rewardData.diamonds)
    end
    
    -- Give items
    if rewardData.item and inventoryManager then
        inventoryManager:AddItem(player, rewardData.item, 1)
    end
    
    -- Give title
    if rewardData.title and achievementManager then
        achievementManager:UnlockTitle(player, rewardData.title)
    end
end

-- ==========================================
-- LEADERBOARD SYSTEM
-- ==========================================

function EventManager:UpdateLeaderboard(eventId, player, score)
    if not self.EventLeaderboards[eventId] then
        self.EventLeaderboards[eventId] = {
            players = {},
            updated = tick()
        }
    end
    
    local leaderboard = self.EventLeaderboards[eventId]
    
    -- Update player score
    local found = false
    for i, entry in ipairs(leaderboard.players) do
        if entry.userId == player.UserId then
            entry.score = score
            found = true
            break
        end
    end
    
    if not found then
        table.insert(leaderboard.players, {
            userId = player.UserId,
            playerName = player.Name,
            score = score
        })
    end
    
    -- Sort leaderboard
    table.sort(leaderboard.players, function(a, b)
        return a.score > b.score
    end)
    
    -- Keep only top 100
    if #leaderboard.players > 100 then
        for i = 101, #leaderboard.players do
            leaderboard.players[i] = nil
        end
    end
    
    leaderboard.updated = tick()
end

function EventManager:GetEventLeaderboard(eventId)
    return self.EventLeaderboards[eventId] or {players = {}, updated = 0}
end

function EventManager:GetPlayerRank(eventId, player)
    local leaderboard = self.EventLeaderboards[eventId]
    if not leaderboard then return 999 end
    
    for i, entry in ipairs(leaderboard.players) do
        if entry.userId == player.UserId then
            return i
        end
    end
    
    return 999 -- Not found
end

-- ==========================================
-- EVENT SCHEDULING
-- ==========================================

function EventManager:ProcessEventSchedule()
    -- Check for seasonal events
    self:CheckSeasonalEvents()
    
    -- Check for scheduled events
    self:CheckScheduledEvents()
    
    -- End expired events
    self:EndExpiredEvents()
end

function EventManager:CheckSeasonalEvents()
    local currentSeason = self:GetCurrentSeason()
    
    for templateName, template in pairs(self.EventTemplates) do
        if template.season == currentSeason then
            -- Check if this seasonal event is already active
            local alreadyActive = false
            for _, event in pairs(self.ActiveEvents) do
                if event.template == templateName and event.status == EventManager.EventStatus.ACTIVE then
                    alreadyActive = true
                    break
                end
            end
            
            if not alreadyActive then
                self:CreateEvent(templateName)
                print("🎉 EventManager: Started seasonal event:", template.name)
            end
        end
    end
end

function EventManager:CheckScheduledEvents()
    -- This would check for time-based event triggers
    -- Implementation depends on specific scheduling needs
end

function EventManager:EndExpiredEvents()
    for eventId, event in pairs(self.ActiveEvents) do
        if event.status == EventManager.EventStatus.ACTIVE and tick() >= event.endTime then
            self:EndEvent(eventId)
        end
    end
end

function EventManager:EndEvent(eventId)
    local event = self.ActiveEvents[eventId]
    if not event then return end
    
    event.status = EventManager.EventStatus.COMPLETED
    
    -- Notify participants
    for userId, participant in pairs(event.participants) do
        local player = Players:GetPlayerByUserId(userId)
        if player then
            local notificationManager = _G.NotificationManager
            if notificationManager then
                notificationManager:ShowToast(
                    "Event Ended! 🏁",
                    event.name .. " has ended. Check your rewards!",
                    "⏰",
                    "event_end"
                )
            end
        end
    end
    
    -- Save final leaderboard
    if event.competitive then
        self:SaveLeaderboard(eventId)
    end
    
    print("🎉 EventManager: Ended event:", event.name)
    
    -- Remove from active events after 24 hours
    spawn(function()
        wait(24 * 3600)
        self.ActiveEvents[eventId] = nil
    end)
end

function EventManager:SaveLeaderboard(eventId)
    local leaderboard = self.EventLeaderboards[eventId]
    if leaderboard then
        local success, error = pcall(function()
            self.LeaderboardStore:SetAsync("event_" .. eventId, leaderboard)
        end)
        
        if not success then
            warn("❌ EventManager: Failed to save leaderboard for event", eventId, ":", error)
        end
    end
end

-- ==========================================
-- EVENT UPDATES
-- ==========================================

function EventManager:UpdateActiveEvents()
    for eventId, event in pairs(self.ActiveEvents) do
        if event.status == EventManager.EventStatus.ACTIVE then
            -- Update community goals
            if event.communityGoal then
                self:UpdateCommunityGoal(eventId)
            end
            
            -- Check for event completion
            self:CheckEventCompletion(eventId)
        end
    end
end

function EventManager:UpdateCommunityGoal(eventId)
    local event = self.ActiveEvents[eventId]
    if not event.communityGoal then return end
    
    -- Calculate total community progress
    local totalProgress = 0
    for _, participant in pairs(event.participants) do
        totalProgress = totalProgress + (participant.progress[event.communityGoal.metric] or 0)
    end
    
    event.communityGoal.progress = totalProgress
    
    -- Check if goal is reached
    if event.communityGoal.progress >= event.communityGoal.target then
        self:OnCommunityGoalReached(eventId)
    end
end

function EventManager:OnCommunityGoalReached(eventId)
    local event = self.ActiveEvents[eventId]
    
    -- Notify all participants
    for userId, participant in pairs(event.participants) do
        local player = Players:GetPlayerByUserId(userId)
        if player then
            local notificationManager = _G.NotificationManager
            if notificationManager then
                notificationManager:ShowToast(
                    "Community Goal Reached! 🌟",
                    "The community has achieved the goal!",
                    "🎊",
                    "community_success"
                )
            end
        end
    end
    
    print("🎉 EventManager: Community goal reached for event:", event.name)
end

function EventManager:CheckEventCompletion(eventId)
    -- Check for automatic event completion conditions
    local event = self.ActiveEvents[eventId]
    
    -- Example: End event early if all participants completed all tasks
    local allCompleted = true
    for _, participant in pairs(event.participants) do
        for _, task in ipairs(event.tasks) do
            if not participant.progress[task.id] or participant.progress[task.id] < task.target then
                allCompleted = false
                break
            end
        end
        if not allCompleted then break end
    end
    
    if allCompleted and #event.participants > 0 then
        self:EndEvent(eventId)
    end
end

-- ==========================================
-- HELPER FUNCTIONS
-- ==========================================

function EventManager:IsPlayerVIP(player)
    local vipManager = _G.VIPManager
    if vipManager then
        return vipManager:IsPlayerVIP(player)
    end
    return false
end

function EventManager:GetCurrentSeason()
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

function EventManager:IsEventStillActive(event)
    return event.status == EventManager.EventStatus.ACTIVE and tick() < event.endTime
end

-- ==========================================
-- PUBLIC API
-- ==========================================

function EventManager:TriggerEventProgress(player, action, amount)
    -- This function is called by other systems to update event progress
    for eventId, event in pairs(self.ActiveEvents) do
        if event.participants[player.UserId] then
            for _, task in ipairs(event.tasks) do
                if self:DoesActionMatchTask(action, task) then
                    self:UpdatePlayerEventProgress(player, eventId, task.id, amount or 1)
                end
            end
        end
    end
end

function EventManager:DoesActionMatchTask(action, task)
    -- Map game actions to event tasks
    local actionTaskMap = {
        plant_crop = {"plant_flowers", "grow_cacti", "grow_evergreens", "rare_plants"},
        harvest_crop = {"harvest_spring", "mega_harvest", "speed_harvest", "contribute_harvest"},
        water_plant = {"water_plants"},
        place_decoration = {"place_decorations"},
        earn_coins = {"earn_coins"},
        spend_diamonds = {"spend_diamonds"}
    }
    
    local matchingTasks = actionTaskMap[action]
    if matchingTasks then
        for _, taskType in ipairs(matchingTasks) do
            if task.id == taskType then
                return true
            end
        end
    end
    
    return false
end

function EventManager:GetPlayerEventStats(player)
    local playerData = self.PlayerEventData[player.UserId]
    if not playerData then return {} end
    
    return {
        eventsJoined = #playerData.joinedEvents,
        eventsCompleted = self:CountCompletedEvents(player),
        achievementsEarned = #playerData.achievements
    }
end

function EventManager:CountCompletedEvents(player)
    local count = 0
    local playerData = self.PlayerEventData[player.UserId]
    
    for _, eventRecord in pairs(playerData.joinedEvents) do
        if eventRecord.status == "completed" then
            count = count + 1
        end
    end
    
    return count
end

-- ==========================================
-- CLEANUP
-- ==========================================

function EventManager:Cleanup()
    -- Save all active events
    local activeEventsData = {}
    for eventId, event in pairs(self.ActiveEvents) do
        activeEventsData[eventId] = event
    end
    
    local success, error = pcall(function()
        self.EventStore:SetAsync("active_events", activeEventsData)
    end)
    
    if not success then
        warn("❌ EventManager: Failed to save active events:", error)
    end
    
    -- Save all player event data
    for userId, _ in pairs(self.PlayerEventData) do
        local player = Players:GetPlayerByUserId(userId)
        if player then
            self:SavePlayerEventData(player)
        end
    end
    
    print("🎉 EventManager: Event system cleaned up")
end

return EventManager
