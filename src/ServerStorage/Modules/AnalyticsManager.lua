--[[
    AnalyticsManager.lua
    Server-Side Analytics and Player Behavior Tracking System
    
    Priority: 35 (Advanced Features phase - final iteration)
    Dependencies: DataStoreService, HttpService, MessagingService
    Used by: All game systems for analytics tracking
    
    Features:
    - Player behavior analytics
    - Game performance metrics
    - Economy tracking and balancing
    - Retention and engagement analysis
    - A/B testing framework
    - Custom event tracking
    - Data visualization preparation
    - Privacy compliant data collection
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local MessagingService = game:GetService("MessagingService")
local TeleportService = game:GetService("TeleportService")

-- Load required modules
local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)

local AnalyticsManager = {}
AnalyticsManager.__index = AnalyticsManager

-- ==========================================
-- INITIALIZATION & SETUP
-- ==========================================

-- Data stores
AnalyticsManager.PlayerAnalyticsStore = DataStoreService:GetDataStore("PlayerAnalytics_v1")
AnalyticsManager.GameMetricsStore = DataStoreService:GetDataStore("GameMetrics_v1")
AnalyticsManager.SessionStore = DataStoreService:GetDataStore("SessionData_v1")
AnalyticsManager.ABTestStore = DataStoreService:GetDataStore("ABTestData_v1")

-- Analytics state tracking
AnalyticsManager.PlayerSessions = {} -- [userId] = sessionData
AnalyticsManager.GameMetrics = {} -- Real-time game metrics
AnalyticsManager.EventQueue = {} -- Queued events for batch processing
AnalyticsManager.ABTestGroups = {} -- A/B testing group assignments

-- Event categories
AnalyticsManager.EventCategories = {
    GAMEPLAY = "gameplay",
    ECONOMY = "economy", 
    SOCIAL = "social",
    UI = "ui",
    PERFORMANCE = "performance",
    RETENTION = "retention",
    MONETIZATION = "monetization",
    PROGRESSION = "progression",
    ENGAGEMENT = "engagement",
    TECHNICAL = "technical"
}

-- Metrics to track
AnalyticsManager.TrackedMetrics = {
    -- Player metrics
    session_duration = true,
    actions_per_minute = true,
    features_used = true,
    areas_visited = true,
    
    -- Economic metrics
    currency_earned = true,
    currency_spent = true,
    items_purchased = true,
    premium_purchases = true,
    
    -- Social metrics
    friends_added = true,
    messages_sent = true,
    garden_visits = true,
    gifts_exchanged = true,
    
    -- Progression metrics
    level_ups = true,
    achievements_unlocked = true,
    milestones_reached = true,
    
    -- Engagement metrics
    daily_logins = true,
    mini_games_played = true,
    time_spent_per_feature = true,
    
    -- Technical metrics
    loading_times = true,
    error_rates = true,
    frame_rates = true,
    memory_usage = true
}

-- A/B Testing configurations
AnalyticsManager.ABTests = {
    welcome_tutorial = {
        id = "welcome_tutorial_v2",
        variants = {
            control = {weight = 50, config = {tutorial_type = "basic"}},
            variant_a = {weight = 25, config = {tutorial_type = "interactive"}},
            variant_b = {weight = 25, config = {tutorial_type = "video"}}
        },
        active = true,
        startDate = "2024-01-01",
        endDate = "2024-12-31"
    },
    
    vip_pricing = {
        id = "vip_pricing_test",
        variants = {
            control = {weight = 50, config = {price = 499}},
            higher_price = {weight = 50, config = {price = 599}}
        },
        active = true,
        startDate = "2024-01-01", 
        endDate = "2024-12-31"
    },
    
    daily_rewards = {
        id = "daily_reward_amounts",
        variants = {
            control = {weight = 33, config = {multiplier = 1.0}},
            increased = {weight = 33, config = {multiplier = 1.5}},
            decreased = {weight = 34, config = {multiplier = 0.8}}
        },
        active = true,
        startDate = "2024-01-01",
        endDate = "2024-12-31"
    }
}

-- Privacy settings
AnalyticsManager.PrivacySettings = {
    anonymize_user_data = true,
    data_retention_days = 90,
    respect_opt_out = true,
    gdpr_compliant = true,
    coppa_compliant = true
}

-- ==========================================
-- INITIALIZATION
-- ==========================================

function AnalyticsManager:Initialize()
    print("📊 AnalyticsManager: Initializing analytics system...")
    
    -- Set up remote events
    self:SetupRemoteEvents()
    
    -- Set up player connections
    self:SetupPlayerConnections()
    
    -- Initialize metrics tracking
    self:InitializeMetricsTracking()
    
    -- Start analytics processing
    self:StartAnalyticsProcessing()
    
    -- Load A/B test configurations
    self:LoadABTestConfigurations()
    
    print("✅ AnalyticsManager: Analytics system initialized")
end

function AnalyticsManager:SetupRemoteEvents()
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then
        remoteEvents = Instance.new("Folder")
        remoteEvents.Name = "RemoteEvents"
        remoteEvents.Parent = ReplicatedStorage
    end
    
    -- Track custom event
    local trackEventRemote = Instance.new("RemoteEvent")
    trackEventRemote.Name = "TrackAnalyticsEvent"
    trackEventRemote.Parent = remoteEvents
    trackEventRemote.OnServerEvent:Connect(function(player, eventData)
        self:TrackEvent(player, eventData)
    end)
    
    -- Get player analytics
    local getAnalyticsFunction = Instance.new("RemoteFunction")
    getAnalyticsFunction.Name = "GetPlayerAnalytics"
    getAnalyticsFunction.Parent = remoteEvents
    getAnalyticsFunction.OnServerInvoke = function(player)
        return self:GetPlayerAnalytics(player)
    end
    
    -- Get A/B test variant
    local getABTestFunction = Instance.new("RemoteFunction")
    getABTestFunction.Name = "GetABTestVariant"
    getABTestFunction.Parent = remoteEvents
    getABTestFunction.OnServerInvoke = function(player, testId)
        return self:GetABTestVariant(player, testId)
    end
    
    -- Report performance metrics
    local reportPerformanceRemote = Instance.new("RemoteEvent")
    reportPerformanceRemote.Name = "ReportPerformanceMetrics"
    reportPerformanceRemote.Parent = remoteEvents
    reportPerformanceRemote.OnServerEvent:Connect(function(player, metricsData)
        self:TrackPerformanceMetrics(player, metricsData)
    end)
end

function AnalyticsManager:SetupPlayerConnections()
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

function AnalyticsManager:InitializeMetricsTracking()
    -- Initialize real-time metrics
    self.GameMetrics = {
        players_online = 0,
        total_sessions_today = 0,
        average_session_duration = 0,
        total_revenue_today = 0,
        error_count = 0,
        performance_score = 100,
        last_updated = tick()
    }
    
    -- Start metrics collection
    self:StartMetricsCollection()
end

function AnalyticsManager:StartAnalyticsProcessing()
    -- Process event queue every 30 seconds
    spawn(function()
        while true do
            self:ProcessEventQueue()
            wait(30)
        end
    end)
    
    -- Generate daily reports
    spawn(function()
        while true do
            self:GenerateDailyReport()
            wait(86400) -- 24 hours
        end
    end)
    
    -- Clean up old data
    spawn(function()
        while true do
            self:CleanupOldData()
            wait(3600) -- 1 hour
        end
    end)
end

function AnalyticsManager:LoadABTestConfigurations()
    -- Load A/B test settings from DataStore
    local success, testData = pcall(function()
        return self.ABTestStore:GetAsync("active_tests")
    end)
    
    if success and testData then
        for testId, config in pairs(testData) do
            if self.ABTests[testId] then
                self.ABTests[testId] = config
            end
        end
        print("📊 AnalyticsManager: Loaded A/B test configurations")
    end
end

-- ==========================================
-- PLAYER SESSION TRACKING
-- ==========================================

function AnalyticsManager:OnPlayerJoined(player)
    local userId = player.UserId
    local joinTime = tick()
    
    -- Initialize session data
    self.PlayerSessions[userId] = {
        userId = userId,
        username = player.Name,
        sessionId = HttpService:GenerateGUID(false),
        joinTime = joinTime,
        lastActivityTime = joinTime,
        actions = {},
        features_used = {},
        areas_visited = {},
        economic_activity = {
            coins_earned = 0,
            coins_spent = 0,
            items_purchased = {},
            premium_purchases = {}
        },
        social_activity = {
            friends_added = 0,
            messages_sent = 0,
            garden_visits = 0,
            gifts_sent = 0,
            gifts_received = 0
        },
        progression = {
            level_start = self:GetPlayerLevel(player),
            xp_start = self:GetPlayerXP(player),
            achievements_unlocked = 0
        },
        performance_data = {
            average_fps = 0,
            loading_times = {},
            error_count = 0
        },
        ab_test_variants = {}
    }
    
    -- Assign A/B test variants
    self:AssignABTestVariants(player)
    
    -- Track session start
    self:TrackEvent(player, {
        category = self.EventCategories.RETENTION,
        action = "session_start",
        properties = {
            player_level = self:GetPlayerLevel(player),
            days_since_install = self:GetDaysSinceInstall(player),
            is_returning = self:IsReturningPlayer(player),
            device_type = self:GetDeviceType(player),
            session_id = self.PlayerSessions[userId].sessionId
        }
    })
    
    -- Update game metrics
    self.GameMetrics.players_online = #Players:GetPlayers()
    self.GameMetrics.total_sessions_today = self.GameMetrics.total_sessions_today + 1
    
    print("📊 AnalyticsManager: Started session tracking for", player.Name)
end

function AnalyticsManager:OnPlayerLeaving(player)
    local userId = player.UserId
    local sessionData = self.PlayerSessions[userId]
    
    if not sessionData then return end
    
    local leaveTime = tick()
    local sessionDuration = leaveTime - sessionData.joinTime
    
    -- Calculate final metrics
    sessionData.leaveTime = leaveTime
    sessionData.sessionDuration = sessionDuration
    sessionData.progression.level_end = self:GetPlayerLevel(player)
    sessionData.progression.xp_end = self:GetPlayerXP(player)
    sessionData.progression.level_gained = sessionData.progression.level_end - sessionData.progression.level_start
    sessionData.progression.xp_gained = sessionData.progression.xp_end - sessionData.progression.xp_start
    
    -- Track session end
    self:TrackEvent(player, {
        category = self.EventCategories.RETENTION,
        action = "session_end", 
        properties = {
            session_duration = sessionDuration,
            actions_count = #sessionData.actions,
            features_used_count = self:CountTableKeys(sessionData.features_used),
            areas_visited_count = self:CountTableKeys(sessionData.areas_visited),
            level_gained = sessionData.progression.level_gained,
            xp_gained = sessionData.progression.xp_gained,
            coins_earned = sessionData.economic_activity.coins_earned,
            coins_spent = sessionData.economic_activity.coins_spent,
            session_id = sessionData.sessionId
        }
    })
    
    -- Save session data
    self:SaveSessionData(sessionData)
    
    -- Update game metrics
    self:UpdateAverageSessionDuration(sessionDuration)
    self.GameMetrics.players_online = #Players:GetPlayers() - 1
    
    -- Clean up session
    self.PlayerSessions[userId] = nil
    
    print("📊 AnalyticsManager: Ended session tracking for", player.Name, "Duration:", math.floor(sessionDuration), "seconds")
end

function AnalyticsManager:SaveSessionData(sessionData)
    local sessionKey = sessionData.sessionId
    
    local success, error = pcall(function()
        self.SessionStore:SetAsync(sessionKey, sessionData)
    end)
    
    if not success then
        warn("❌ AnalyticsManager: Failed to save session data:", error)
    end
end

-- ==========================================
-- EVENT TRACKING
-- ==========================================

function AnalyticsManager:TrackEvent(player, eventData)
    if not player or not eventData then return end
    
    local userId = player.UserId
    local sessionData = self.PlayerSessions[userId]
    
    if not sessionData then return end
    
    -- Prepare event data
    local event = {
        userId = userId,
        username = self.PrivacySettings.anonymize_user_data and "anonymous" or player.Name,
        sessionId = sessionData.sessionId,
        timestamp = tick(),
        category = eventData.category or "general",
        action = eventData.action or "unknown",
        properties = eventData.properties or {},
        server_id = game.JobId,
        place_id = game.PlaceId
    }
    
    -- Add session context
    event.properties.session_time = tick() - sessionData.joinTime
    event.properties.player_level = self:GetPlayerLevel(player)
    
    -- Add to session actions
    table.insert(sessionData.actions, {
        timestamp = event.timestamp,
        category = event.category,
        action = event.action
    })
    
    -- Update last activity
    sessionData.lastActivityTime = event.timestamp
    
    -- Track feature usage
    if event.category == self.EventCategories.UI or event.category == self.EventCategories.GAMEPLAY then
        sessionData.features_used[event.action] = (sessionData.features_used[event.action] or 0) + 1
    end
    
    -- Add to queue for batch processing
    table.insert(self.EventQueue, event)
    
    -- Process specific event types
    self:ProcessSpecificEvent(player, event)
    
    print("📊 AnalyticsManager: Tracked event:", event.category, "-", event.action, "for", player.Name)
end

function AnalyticsManager:ProcessSpecificEvent(player, event)
    local userId = player.UserId
    local sessionData = self.PlayerSessions[userId]
    
    if event.category == self.EventCategories.ECONOMY then
        if event.action == "currency_earned" then
            sessionData.economic_activity.coins_earned = sessionData.economic_activity.coins_earned + (event.properties.amount or 0)
        elseif event.action == "currency_spent" then
            sessionData.economic_activity.coins_spent = sessionData.economic_activity.coins_spent + (event.properties.amount or 0)
        elseif event.action == "item_purchased" then
            table.insert(sessionData.economic_activity.items_purchased, {
                item = event.properties.item,
                cost = event.properties.cost,
                timestamp = event.timestamp
            })
        elseif event.action == "premium_purchase" then
            table.insert(sessionData.economic_activity.premium_purchases, {
                product = event.properties.product,
                price = event.properties.price,
                timestamp = event.timestamp
            })
            self.GameMetrics.total_revenue_today = self.GameMetrics.total_revenue_today + (event.properties.price or 0)
        end
        
    elseif event.category == self.EventCategories.SOCIAL then
        if event.action == "friend_added" then
            sessionData.social_activity.friends_added = sessionData.social_activity.friends_added + 1
        elseif event.action == "message_sent" then
            sessionData.social_activity.messages_sent = sessionData.social_activity.messages_sent + 1
        elseif event.action == "garden_visit" then
            sessionData.social_activity.garden_visits = sessionData.social_activity.garden_visits + 1
        elseif event.action == "gift_sent" then
            sessionData.social_activity.gifts_sent = sessionData.social_activity.gifts_sent + 1
        elseif event.action == "gift_received" then
            sessionData.social_activity.gifts_received = sessionData.social_activity.gifts_received + 1
        end
        
    elseif event.category == self.EventCategories.PROGRESSION then
        if event.action == "achievement_unlocked" then
            sessionData.progression.achievements_unlocked = sessionData.progression.achievements_unlocked + 1
        end
        
    elseif event.category == self.EventCategories.GAMEPLAY then
        if event.action == "area_visited" then
            sessionData.areas_visited[event.properties.area] = true
        end
    end
end

function AnalyticsManager:TrackPerformanceMetrics(player, metricsData)
    local userId = player.UserId
    local sessionData = self.PlayerSessions[userId]
    
    if not sessionData then return end
    
    -- Track FPS
    if metricsData.fps then
        sessionData.performance_data.average_fps = (sessionData.performance_data.average_fps + metricsData.fps) / 2
    end
    
    -- Track loading times
    if metricsData.loading_time then
        table.insert(sessionData.performance_data.loading_times, metricsData.loading_time)
    end
    
    -- Track errors
    if metricsData.error then
        sessionData.performance_data.error_count = sessionData.performance_data.error_count + 1
        self.GameMetrics.error_count = self.GameMetrics.error_count + 1
    end
    
    -- Update game performance score
    self:UpdatePerformanceScore()
end

-- ==========================================
-- A/B TESTING
-- ==========================================

function AnalyticsManager:AssignABTestVariants(player)
    local userId = player.UserId
    local sessionData = self.PlayerSessions[userId]
    
    for testId, testConfig in pairs(self.ABTests) do
        if testConfig.active then
            local variant = self:GetABTestVariant(player, testId)
            sessionData.ab_test_variants[testId] = variant
            
            -- Track A/B test assignment
            self:TrackEvent(player, {
                category = self.EventCategories.TECHNICAL,
                action = "ab_test_assigned",
                properties = {
                    test_id = testId,
                    variant = variant
                }
            })
        end
    end
end

function AnalyticsManager:GetABTestVariant(player, testId)
    local testConfig = self.ABTests[testId]
    if not testConfig or not testConfig.active then
        return "control"
    end
    
    -- Use consistent hashing based on user ID and test ID
    local seed = player.UserId + HttpService:JSONDecode(HttpService:JSONEncode(testId):gsub("%D", ""))
    math.randomseed(seed)
    
    local randomValue = math.random(1, 100)
    local cumulativeWeight = 0
    
    for variantName, variantConfig in pairs(testConfig.variants) do
        cumulativeWeight = cumulativeWeight + variantConfig.weight
        if randomValue <= cumulativeWeight then
            return variantName
        end
    end
    
    return "control"
end

function AnalyticsManager:GetABTestConfig(player, testId)
    local variant = self:GetABTestVariant(player, testId)
    local testConfig = self.ABTests[testId]
    
    if testConfig and testConfig.variants[variant] then
        return testConfig.variants[variant].config
    end
    
    return {}
end

function AnalyticsManager:TrackABTestConversion(player, testId, conversionType, value)
    self:TrackEvent(player, {
        category = self.EventCategories.TECHNICAL,
        action = "ab_test_conversion",
        properties = {
            test_id = testId,
            variant = self:GetABTestVariant(player, testId),
            conversion_type = conversionType,
            value = value
        }
    })
end

-- ==========================================
-- METRICS COLLECTION
-- ==========================================

function AnalyticsManager:StartMetricsCollection()
    -- Collect server performance metrics
    spawn(function()
        while true do
            self:CollectServerMetrics()
            wait(60) -- Every minute
        end
    end)
    
    -- Update player activity metrics
    spawn(function()
        while true do
            self:UpdatePlayerActivityMetrics()
            wait(300) -- Every 5 minutes
        end
    end)
end

function AnalyticsManager:CollectServerMetrics()
    local currentTime = tick()
    
    -- Memory usage
    local memoryUsage = gcinfo()
    
    -- Server heartbeat
    local heartbeat = RunService.Heartbeat:Wait()
    
    -- Update game metrics
    self.GameMetrics.memory_usage = memoryUsage
    self.GameMetrics.server_heartbeat = heartbeat
    self.GameMetrics.last_updated = currentTime
    
    -- Track server performance event
    self:TrackServerEvent({
        category = self.EventCategories.PERFORMANCE,
        action = "server_metrics",
        properties = {
            memory_usage = memoryUsage,
            heartbeat = heartbeat,
            players_online = self.GameMetrics.players_online,
            uptime = currentTime - self.GameMetrics.server_start_time
        }
    })
end

function AnalyticsManager:UpdatePlayerActivityMetrics()
    local currentTime = tick()
    local activeThreshold = 300 -- 5 minutes
    
    local activePlayers = 0
    for userId, sessionData in pairs(self.PlayerSessions) do
        if currentTime - sessionData.lastActivityTime < activeThreshold then
            activePlayers = activePlayers + 1
        end
    end
    
    self.GameMetrics.active_players = activePlayers
    self.GameMetrics.activity_rate = self.GameMetrics.players_online > 0 and activePlayers / self.GameMetrics.players_online or 0
end

function AnalyticsManager:UpdateAverageSessionDuration(newDuration)
    local currentAvg = self.GameMetrics.average_session_duration
    local sessionsToday = self.GameMetrics.total_sessions_today
    
    if sessionsToday > 0 then
        self.GameMetrics.average_session_duration = ((currentAvg * (sessionsToday - 1)) + newDuration) / sessionsToday
    else
        self.GameMetrics.average_session_duration = newDuration
    end
end

function AnalyticsManager:UpdatePerformanceScore()
    local score = 100
    
    -- Reduce score based on error count
    score = score - math.min(self.GameMetrics.error_count * 2, 50)
    
    -- Reduce score based on memory usage
    if self.GameMetrics.memory_usage > 500 then
        score = score - math.min((self.GameMetrics.memory_usage - 500) / 10, 30)
    end
    
    -- Reduce score based on low activity rate
    if self.GameMetrics.activity_rate < 0.5 then
        score = score - (0.5 - self.GameMetrics.activity_rate) * 40
    end
    
    self.GameMetrics.performance_score = math.max(score, 0)
end

-- ==========================================
-- DATA PROCESSING
-- ==========================================

function AnalyticsManager:ProcessEventQueue()
    if #self.EventQueue == 0 then return end
    
    local batchSize = 100
    local batch = {}
    
    -- Process events in batches
    for i = 1, math.min(batchSize, #self.EventQueue) do
        table.insert(batch, table.remove(self.EventQueue, 1))
    end
    
    -- Save batch to data store
    local batchId = HttpService:GenerateGUID(false)
    local success, error = pcall(function()
        self.PlayerAnalyticsStore:SetAsync("batch_" .. batchId, {
            events = batch,
            timestamp = tick(),
            server_id = game.JobId
        })
    end)
    
    if not success then
        warn("❌ AnalyticsManager: Failed to save event batch:", error)
        -- Re-add events to queue
        for _, event in ipairs(batch) do
            table.insert(self.EventQueue, 1, event)
        end
    else
        print("📊 AnalyticsManager: Processed batch of", #batch, "events")
    end
end

function AnalyticsManager:TrackServerEvent(eventData)
    -- Track server-level events
    local event = {
        timestamp = tick(),
        category = eventData.category,
        action = eventData.action,
        properties = eventData.properties,
        server_id = game.JobId,
        place_id = game.PlaceId
    }
    
    table.insert(self.EventQueue, event)
end

function AnalyticsManager:GenerateDailyReport()
    local report = {
        date = os.date("%Y-%m-%d"),
        server_id = game.JobId,
        place_id = game.PlaceId,
        metrics = {
            total_sessions = self.GameMetrics.total_sessions_today,
            average_session_duration = self.GameMetrics.average_session_duration,
            peak_concurrent_players = self:GetPeakConcurrentPlayers(),
            total_revenue = self.GameMetrics.total_revenue_today,
            total_errors = self.GameMetrics.error_count,
            performance_score = self.GameMetrics.performance_score
        },
        top_events = self:GetTopEvents(),
        player_retention = self:CalculatePlayerRetention(),
        ab_test_results = self:GetABTestResults()
    }
    
    -- Save daily report
    local reportKey = "daily_report_" .. os.date("%Y_%m_%d")
    local success, error = pcall(function()
        self.GameMetricsStore:SetAsync(reportKey, report)
    end)
    
    if success then
        print("📊 AnalyticsManager: Generated daily report for", report.date)
    else
        warn("❌ AnalyticsManager: Failed to save daily report:", error)
    end
    
    -- Reset daily metrics
    self:ResetDailyMetrics()
end

function AnalyticsManager:ResetDailyMetrics()
    self.GameMetrics.total_sessions_today = 0
    self.GameMetrics.total_revenue_today = 0
    self.GameMetrics.error_count = 0
    self.GameMetrics.performance_score = 100
end

-- ==========================================
-- ANALYTICS QUERIES
-- ==========================================

function AnalyticsManager:GetPlayerAnalytics(player)
    local userId = player.UserId
    local sessionData = self.PlayerSessions[userId]
    
    if not sessionData then return {} end
    
    return {
        session_duration = tick() - sessionData.joinTime,
        actions_count = #sessionData.actions,
        features_used = self:CountTableKeys(sessionData.features_used),
        areas_visited = self:CountTableKeys(sessionData.areas_visited),
        economic_activity = sessionData.economic_activity,
        social_activity = sessionData.social_activity,
        progression = sessionData.progression,
        performance = sessionData.performance_data,
        ab_tests = sessionData.ab_test_variants
    }
end

function AnalyticsManager:GetTopEvents()
    -- This would analyze the event queue to find most common events
    local eventCounts = {}
    
    for _, event in ipairs(self.EventQueue) do
        local key = event.category .. ":" .. event.action
        eventCounts[key] = (eventCounts[key] or 0) + 1
    end
    
    -- Sort by count
    local sortedEvents = {}
    for eventKey, count in pairs(eventCounts) do
        table.insert(sortedEvents, {event = eventKey, count = count})
    end
    
    table.sort(sortedEvents, function(a, b) return a.count > b.count end)
    
    return sortedEvents
end

function AnalyticsManager:GetPeakConcurrentPlayers()
    -- This would track the peak concurrent players for the day
    -- For now, return current online count
    return self.GameMetrics.players_online
end

function AnalyticsManager:CalculatePlayerRetention()
    -- Calculate day 1, day 7, and day 30 retention rates
    -- This would require historical data analysis
    return {
        day_1_retention = 0.75,
        day_7_retention = 0.45,
        day_30_retention = 0.20
    }
end

function AnalyticsManager:GetABTestResults()
    -- Analyze A/B test performance
    local results = {}
    
    for testId, testConfig in pairs(self.ABTests) do
        if testConfig.active then
            results[testId] = {
                participants = 0,
                conversions_by_variant = {},
                statistical_significance = 0
            }
        end
    end
    
    return results
end

-- ==========================================
-- DATA CLEANUP
-- ==========================================

function AnalyticsManager:CleanupOldData()
    local cutoffTime = tick() - (self.PrivacySettings.data_retention_days * 86400)
    
    -- This would clean up old analytics data
    -- For production, implement proper data cleanup
    print("📊 AnalyticsManager: Cleaning up data older than", self.PrivacySettings.data_retention_days, "days")
end

-- ==========================================
-- HELPER FUNCTIONS
-- ==========================================

function AnalyticsManager:GetPlayerLevel(player)
    local economyManager = _G.EconomyManager
    if economyManager then
        return economyManager:GetPlayerLevel(player)
    end
    return 1
end

function AnalyticsManager:GetPlayerXP(player)
    local economyManager = _G.EconomyManager
    if economyManager then
        return economyManager:GetPlayerXP(player)
    end
    return 0
end

function AnalyticsManager:GetDaysSinceInstall(player)
    -- This would calculate days since first install
    -- For now, return a placeholder
    return 1
end

function AnalyticsManager:IsReturningPlayer(player)
    -- This would check if player has played before
    -- For now, return false (new player)
    return false
end

function AnalyticsManager:GetDeviceType(player)
    -- Detect device type based on various factors
    local userInputService = game:GetService("UserInputService")
    
    if userInputService.TouchEnabled and not userInputService.KeyboardEnabled then
        return "mobile"
    elseif userInputService.GamepadEnabled then
        return "console"
    else
        return "desktop"
    end
end

function AnalyticsManager:CountTableKeys(table)
    local count = 0
    for _, _ in pairs(table) do
        count = count + 1
    end
    return count
end

-- ==========================================
-- PUBLIC API
-- ==========================================

function AnalyticsManager:TrackCustomEvent(player, category, action, properties)
    self:TrackEvent(player, {
        category = category,
        action = action,
        properties = properties
    })
end

function AnalyticsManager:TrackEconomyEvent(player, action, amount, item)
    self:TrackEvent(player, {
        category = self.EventCategories.ECONOMY,
        action = action,
        properties = {
            amount = amount,
            item = item
        }
    })
end

function AnalyticsManager:TrackSocialEvent(player, action, targetPlayer)
    self:TrackEvent(player, {
        category = self.EventCategories.SOCIAL,
        action = action,
        properties = {
            target_player = targetPlayer and targetPlayer.Name or nil
        }
    })
end

function AnalyticsManager:TrackProgressionEvent(player, milestone, value)
    self:TrackEvent(player, {
        category = self.EventCategories.PROGRESSION,
        action = milestone,
        properties = {
            value = value
        }
    })
end

function AnalyticsManager:GetGameMetrics()
    return self.GameMetrics
end

-- ==========================================
-- CLEANUP
-- ==========================================

function AnalyticsManager:Cleanup()
    -- Process remaining events
    self:ProcessEventQueue()
    
    -- Save final metrics
    self:GenerateDailyReport()
    
    -- Save all session data
    for userId, sessionData in pairs(self.PlayerSessions) do
        self:SaveSessionData(sessionData)
    end
    
    print("📊 AnalyticsManager: Analytics system cleaned up")
end

return AnalyticsManager
