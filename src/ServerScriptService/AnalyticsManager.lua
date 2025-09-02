--[[
    AnalyticsManager.lua
    Server-Side Analytics and Telemetry System
    
    Priority: 25 (VIP & Monetization phase)
    Dependencies: DataStoreService, MessagingService, HttpService
    Used by: All systems for data collection and insights
    
    Features:
    - Player behavior tracking
    - Game economy analytics
    - VIP conversion metrics
    - Performance monitoring
    - A/B testing framework
    - Real-time dashboard data
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

-- Load required modules
local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)

local AnalyticsManager = {}
AnalyticsManager.__index = AnalyticsManager

-- ==========================================
-- INITIALIZATION & SETUP
-- ==========================================

-- Data stores
AnalyticsManager.AnalyticsStore = DataStoreService:GetDataStore("AnalyticsData_v1")
AnalyticsManager.SessionStore = DataStoreService:GetDataStore("SessionData_v1")
AnalyticsManager.MetricsStore = DataStoreService:GetDataStore("MetricsData_v1")

-- Session tracking
AnalyticsManager.ActiveSessions = {}
AnalyticsManager.ServerMetrics = {}
AnalyticsManager.EventQueue = {}

-- Analytics configuration
AnalyticsManager.Config = {
    enableAnalytics = true,
    enableRealTimeTracking = true,
    batchSize = 50,
    flushInterval = 30, -- seconds
    maxQueueSize = 1000,
    enableDebugLogs = false
}

-- Event categories
AnalyticsManager.EventCategories = {
    PLAYER = "player",
    ECONOMY = "economy", 
    GAMEPLAY = "gameplay",
    VIP = "vip",
    PERFORMANCE = "performance",
    UI = "ui",
    SOCIAL = "social",
    RETENTION = "retention"
}

-- Metrics definitions
AnalyticsManager.MetricDefinitions = {
    -- Player metrics
    player_session_length = {category = "player", type = "duration"},
    player_level_progression = {category = "player", type = "increment"},
    player_daily_active = {category = "player", type = "unique_count"},
    player_retention_day1 = {category = "retention", type = "percentage"},
    player_retention_day7 = {category = "retention", type = "percentage"},
    player_retention_day30 = {category = "retention", type = "percentage"},
    
    -- Economy metrics
    currency_earned = {category = "economy", type = "sum"},
    currency_spent = {category = "economy", type = "sum"},
    plants_purchased = {category = "economy", type = "count"},
    decorations_purchased = {category = "economy", type = "count"},
    
    -- VIP metrics
    vip_conversions = {category = "vip", type = "count"},
    vip_revenue = {category = "vip", type = "sum"},
    vip_trial_starts = {category = "vip", type = "count"},
    vip_feature_usage = {category = "vip", type = "count"},
    
    -- Gameplay metrics
    plants_harvested = {category = "gameplay", type = "count"},
    garden_visits = {category = "gameplay", type = "count"},
    achievements_earned = {category = "gameplay", type = "count"},
    tutorial_completion = {category = "gameplay", type = "percentage"},
    
    -- Performance metrics
    server_performance = {category = "performance", type = "average"},
    client_fps = {category = "performance", type = "average"},
    load_times = {category = "performance", type = "average"},
    
    -- Social metrics
    friend_visits = {category = "social", type = "count"},
    gifts_sent = {category = "social", type = "count"},
    chat_messages = {category = "social", type = "count"}
}

-- A/B Test configurations
AnalyticsManager.ABTests = {
    vip_popup_timing = {
        variants = {"immediate", "delayed", "achievement_based"},
        activeVariant = "delayed",
        traffic_split = {33, 33, 34}
    },
    tutorial_flow = {
        variants = {"linear", "branching", "skip_option"},
        activeVariant = "linear", 
        traffic_split = {50, 25, 25}
    },
    ui_theme = {
        variants = {"classic", "modern", "compact"},
        activeVariant = "modern",
        traffic_split = {33, 34, 33}
    }
}

-- ==========================================
-- INITIALIZATION
-- ==========================================

function AnalyticsManager:Initialize()
    print("📊 AnalyticsManager: Initializing analytics system...")
    
    -- Initialize server metrics
    self:InitializeServerMetrics()
    
    -- Set up event processing
    self:StartEventProcessing()
    
    -- Set up remote events
    self:SetupRemoteEvents()
    
    -- Set up player connections
    self:SetupPlayerConnections()
    
    -- Start periodic tasks
    self:StartPeriodicTasks()
    
    -- Initialize A/B testing
    self:InitializeABTesting()
    
    print("✅ AnalyticsManager: Analytics system initialized")
end

function AnalyticsManager:InitializeServerMetrics()
    self.ServerMetrics = {
        startTime = tick(),
        playerCount = 0,
        peakPlayerCount = 0,
        totalSessions = 0,
        averageSessionLength = 0,
        serverPerformance = {
            cpu = 0,
            memory = 0,
            network = 0
        },
        gameVersion = ConfigModule.GAME_VERSION or "1.0.0",
        placeId = game.PlaceId,
        serverId = game.JobId
    }
end

function AnalyticsManager:SetupRemoteEvents()
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then
        remoteEvents = Instance.new("Folder")
        remoteEvents.Name = "RemoteEvents"
        remoteEvents.Parent = ReplicatedStorage
    end
    
    -- Event tracking
    local trackEventRemote = Instance.new("RemoteEvent")
    trackEventRemote.Name = "TrackAnalyticsEvent"
    trackEventRemote.Parent = remoteEvents
    trackEventRemote.OnServerEvent:Connect(function(player, eventData)
        self:TrackEvent(player, eventData)
    end)
    
    -- Performance data
    local performanceRemote = Instance.new("RemoteEvent")
    performanceRemote.Name = "ReportPerformanceData"
    performanceRemote.Parent = remoteEvents
    performanceRemote.OnServerEvent:Connect(function(player, performanceData)
        self:TrackPerformance(player, performanceData)
    end)
    
    -- A/B test assignment
    local abTestFunction = Instance.new("RemoteFunction")
    abTestFunction.Name = "GetABTestVariant"
    abTestFunction.Parent = remoteEvents
    abTestFunction.OnServerInvoke = function(player, testName)
        return self:GetABTestVariant(player, testName)
    end
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

function AnalyticsManager:StartEventProcessing()
    spawn(function()
        while true do
            if #self.EventQueue > 0 then
                self:ProcessEventQueue()
            end
            wait(self.Config.flushInterval)
        end
    end)
end

function AnalyticsManager:StartPeriodicTasks()
    -- Server metrics collection
    spawn(function()
        while true do
            self:CollectServerMetrics()
            wait(60) -- Every minute
        end
    end)
    
    -- Daily analytics aggregation
    spawn(function()
        while true do
            wait(86400) -- 24 hours
            self:GenerateDailyReport()
        end
    end)
    
    -- Real-time dashboard updates
    spawn(function()
        while true do
            self:UpdateRealTimeDashboard()
            wait(30) -- Every 30 seconds
        end
    end)
end

function AnalyticsManager:InitializeABTesting()
    for testName, config in pairs(self.ABTests) do
        print("🧪 AnalyticsManager: Initialized A/B test:", testName)
    end
end

-- ==========================================
-- EVENT TRACKING
-- ==========================================

function AnalyticsManager:TrackEvent(player, eventData)
    if not self.Config.enableAnalytics then return end
    
    -- Validate event data
    if not eventData or not eventData.category or not eventData.action then
        warn("❌ AnalyticsManager: Invalid event data")
        return
    end
    
    -- Enrich event data
    local enrichedEvent = self:EnrichEventData(player, eventData)
    
    -- Add to queue
    table.insert(self.EventQueue, enrichedEvent)
    
    -- Flush if queue is getting full
    if #self.EventQueue >= self.Config.maxQueueSize then
        self:ProcessEventQueue()
    end
    
    -- Real-time processing for critical events
    if eventData.realTime then
        self:ProcessEventImmediate(enrichedEvent)
    end
    
    if self.Config.enableDebugLogs then
        print("📊 Event tracked:", player.Name, eventData.category, eventData.action)
    end
end

function AnalyticsManager:EnrichEventData(player, eventData)
    local session = self.ActiveSessions[player.UserId]
    local currentTime = tick()
    
    local enrichedEvent = {
        -- Core event data
        category = eventData.category,
        action = eventData.action,
        label = eventData.label,
        value = eventData.value,
        
        -- Player data
        userId = player.UserId,
        username = player.Name,
        accountAge = player.AccountAge,
        membershipType = tostring(player.MembershipType),
        
        -- Session data
        sessionId = session and session.sessionId or HttpService:GenerateGUID(),
        sessionTime = session and (currentTime - session.startTime) or 0,
        
        -- Game state
        playerLevel = self:GetPlayerLevel(player),
        isVIP = self:IsPlayerVIP(player),
        currency = self:GetPlayerCurrency(player),
        
        -- Technical data
        timestamp = currentTime,
        serverId = game.JobId,
        placeId = game.PlaceId,
        gameVersion = self.ServerMetrics.gameVersion,
        
        -- Additional properties
        properties = eventData.properties or {}
    }
    
    return enrichedEvent
end

function AnalyticsManager:ProcessEventQueue()
    if #self.EventQueue == 0 then return end
    
    local batch = {}
    local batchSize = math.min(self.Config.batchSize, #self.EventQueue)
    
    -- Extract batch
    for i = 1, batchSize do
        table.insert(batch, table.remove(self.EventQueue, 1))
    end
    
    -- Process batch
    spawn(function()
        self:ProcessEventBatch(batch)
    end)
end

function AnalyticsManager:ProcessEventBatch(events)
    local success, error = pcall(function()
        -- Store events in DataStore
        local batchKey = "batch_" .. tick() .. "_" .. HttpService:GenerateGUID()
        self.AnalyticsStore:SetAsync(batchKey, {
            events = events,
            timestamp = tick(),
            serverData = self.ServerMetrics
        })
        
        -- Update real-time metrics
        for _, event in ipairs(events) do
            self:UpdateRealTimeMetrics(event)
        end
        
        -- Send to external analytics if configured
        self:SendToExternalAnalytics(events)
        
    end)
    
    if not success then
        warn("❌ AnalyticsManager: Failed to process event batch:", error)
        
        -- Re-queue events for retry
        for _, event in ipairs(events) do
            table.insert(self.EventQueue, event)
        end
    else
        if self.Config.enableDebugLogs then
            print("📊 AnalyticsManager: Processed batch of", #events, "events")
        end
    end
end

function AnalyticsManager:ProcessEventImmediate(event)
    -- Immediate processing for critical events
    spawn(function()
        self:UpdateRealTimeMetrics(event)
        
        -- Trigger immediate responses
        if event.category == self.EventCategories.VIP and event.action == "purchase" then
            self:OnVIPPurchase(event)
        elseif event.category == self.EventCategories.RETENTION and event.action == "new_player" then
            self:OnNewPlayer(event)
        end
    end)
end

-- ==========================================
-- PLAYER SESSION TRACKING
-- ==========================================

function AnalyticsManager:OnPlayerJoined(player)
    local currentTime = tick()
    local sessionId = HttpService:GenerateGUID()
    
    -- Create session record
    self.ActiveSessions[player.UserId] = {
        sessionId = sessionId,
        startTime = currentTime,
        player = player,
        events = {},
        abTestVariants = {}
    }
    
    -- Update server metrics
    self.ServerMetrics.playerCount = #Players:GetPlayers()
    self.ServerMetrics.peakPlayerCount = math.max(
        self.ServerMetrics.peakPlayerCount,
        self.ServerMetrics.playerCount
    )
    self.ServerMetrics.totalSessions = self.ServerMetrics.totalSessions + 1
    
    -- Track join event
    self:TrackEvent(player, {
        category = self.EventCategories.PLAYER,
        action = "session_start",
        label = "join",
        properties = {
            isNewPlayer = self:IsNewPlayer(player),
            deviceType = self:GetDeviceType(player),
            referralSource = self:GetReferralSource(player)
        }
    })
    
    -- Assign A/B test variants
    self:AssignABTestVariants(player)
    
    print("📊 AnalyticsManager: Player session started:", player.Name)
end

function AnalyticsManager:OnPlayerLeaving(player)
    local session = self.ActiveSessions[player.UserId]
    if not session then return end
    
    local currentTime = tick()
    local sessionLength = currentTime - session.startTime
    
    -- Track leave event
    self:TrackEvent(player, {
        category = self.EventCategories.PLAYER,
        action = "session_end",
        label = "leave",
        value = sessionLength,
        properties = {
            sessionLength = sessionLength,
            eventCount = #session.events,
            wasVIP = self:IsPlayerVIP(player)
        }
    })
    
    -- Update session analytics
    self:UpdateSessionAnalytics(player, sessionLength)
    
    -- Save session data
    spawn(function()
        self:SaveSessionData(player, session, sessionLength)
    end)
    
    -- Clean up
    self.ActiveSessions[player.UserId] = nil
    self.ServerMetrics.playerCount = #Players:GetPlayers()
    
    print("📊 AnalyticsManager: Player session ended:", player.Name, "Duration:", math.floor(sessionLength), "seconds")
end

function AnalyticsManager:SaveSessionData(player, session, sessionLength)
    local success, error = pcall(function()
        local sessionData = {
            sessionId = session.sessionId,
            userId = player.UserId,
            username = player.Name,
            startTime = session.startTime,
            endTime = tick(),
            duration = sessionLength,
            events = session.events,
            abTestVariants = session.abTestVariants,
            finalStats = self:GetPlayerStats(player)
        }
        
        local sessionKey = "session_" .. player.UserId .. "_" .. session.sessionId
        self.SessionStore:SetAsync(sessionKey, sessionData)
    end)
    
    if not success then
        warn("❌ AnalyticsManager: Failed to save session data:", error)
    end
end

-- ==========================================
-- METRICS COLLECTION
-- ==========================================

function AnalyticsManager:TrackMetric(metricName, value, userId)
    if not self.MetricDefinitions[metricName] then
        warn("❌ AnalyticsManager: Unknown metric:", metricName)
        return
    end
    
    local metric = self.MetricDefinitions[metricName]
    local currentTime = tick()
    
    local metricData = {
        name = metricName,
        category = metric.category,
        type = metric.type,
        value = value,
        userId = userId,
        timestamp = currentTime,
        date = os.date("%Y-%m-%d", currentTime),
        hour = os.date("%H", currentTime)
    }
    
    -- Store in metrics queue
    spawn(function()
        local success, error = pcall(function()
            local metricKey = string.format("metric_%s_%s_%d", 
                metricName, 
                metricData.date, 
                math.floor(currentTime))
            
            self.MetricsStore:SetAsync(metricKey, metricData)
        end)
        
        if not success then
            warn("❌ AnalyticsManager: Failed to store metric:", error)
        end
    end)
    
    if self.Config.enableDebugLogs then
        print("📊 Metric tracked:", metricName, "=", value)
    end
end

function AnalyticsManager:CollectServerMetrics()
    local stats = game:GetService("Stats")
    
    -- Performance metrics
    local heartbeat = RunService.Heartbeat:Wait()
    self.ServerMetrics.serverPerformance.cpu = 1 / heartbeat
    
    -- Memory usage
    local memoryStats = stats:FindFirstChild("MemoryStats")
    if memoryStats then
        self.ServerMetrics.serverPerformance.memory = memoryStats.GetTotalMemoryUsageMb()
    end
    
    -- Network stats
    local networkStats = stats:FindFirstChild("Network")
    if networkStats then
        local dataIn = networkStats:FindFirstChild("Data Received")
        local dataOut = networkStats:FindFirstChild("Data Sent")
        
        if dataIn and dataOut then
            self.ServerMetrics.serverPerformance.network = dataIn:GetValue() + dataOut:GetValue()
        end
    end
    
    -- Track server performance metric
    self:TrackMetric("server_performance", self.ServerMetrics.serverPerformance.cpu)
end

function AnalyticsManager:TrackPerformance(player, performanceData)
    -- Track client performance metrics
    if performanceData.fps then
        self:TrackMetric("client_fps", performanceData.fps, player.UserId)
    end
    
    if performanceData.loadTime then
        self:TrackMetric("load_times", performanceData.loadTime, player.UserId)
    end
    
    -- Store detailed performance data
    self:TrackEvent(player, {
        category = self.EventCategories.PERFORMANCE,
        action = "performance_report",
        properties = performanceData
    })
end

-- ==========================================
-- VIP ANALYTICS
-- ==========================================

function AnalyticsManager:TrackVIPEvent(player, action, details)
    self:TrackEvent(player, {
        category = self.EventCategories.VIP,
        action = action,
        label = details.label or action,
        value = details.value,
        properties = details.properties or {},
        realTime = true
    })
    
    -- Track specific VIP metrics
    if action == "purchase" then
        self:TrackMetric("vip_conversions", 1, player.UserId)
        self:TrackMetric("vip_revenue", details.value or 100, player.UserId)
        
    elseif action == "trial_start" then
        self:TrackMetric("vip_trial_starts", 1, player.UserId)
        
    elseif action == "feature_used" then
        self:TrackMetric("vip_feature_usage", 1, player.UserId)
    end
end

function AnalyticsManager:OnVIPPurchase(event)
    -- Real-time VIP purchase processing
    print("💰 AnalyticsManager: VIP purchase detected for user", event.userId)
    
    -- Send to revenue tracking
    MessagingService:PublishAsync("VIPPurchase", {
        userId = event.userId,
        amount = event.value,
        timestamp = event.timestamp
    })
    
    -- Update conversion funnel
    self:UpdateConversionFunnel(event.userId, "vip_purchase")
end

-- ==========================================
-- A/B TESTING
-- ==========================================

function AnalyticsManager:AssignABTestVariants(player)
    local session = self.ActiveSessions[player.UserId]
    if not session then return end
    
    for testName, config in pairs(self.ABTests) do
        local variant = self:GetABTestVariant(player, testName)
        session.abTestVariants[testName] = variant
        
        -- Track variant assignment
        self:TrackEvent(player, {
            category = "abtest",
            action = "variant_assigned",
            label = testName,
            value = variant,
            properties = {
                testName = testName,
                variant = variant
            }
        })
    end
end

function AnalyticsManager:GetABTestVariant(player, testName)
    local test = self.ABTests[testName]
    if not test then return nil end
    
    -- Consistent assignment based on user ID
    local hash = self:HashUserId(player.UserId, testName)
    local bucket = hash % 100
    
    local cumulative = 0
    for i, split in ipairs(test.traffic_split) do
        cumulative = cumulative + split
        if bucket < cumulative then
            return test.variants[i]
        end
    end
    
    return test.variants[1] -- Fallback
end

function AnalyticsManager:HashUserId(userId, salt)
    -- Simple hash function for consistent A/B test assignment
    local str = tostring(userId) .. salt
    local hash = 0
    
    for i = 1, #str do
        hash = (hash * 31 + string.byte(str, i)) % 2147483647
    end
    
    return hash
end

function AnalyticsManager:TrackABTestEvent(player, testName, action, value)
    local session = self.ActiveSessions[player.UserId]
    local variant = session and session.abTestVariants[testName]
    
    if variant then
        self:TrackEvent(player, {
            category = "abtest",
            action = action,
            label = testName,
            value = value,
            properties = {
                testName = testName,
                variant = variant
            }
        })
    end
end

-- ==========================================
-- ANALYTICS REPORTS
-- ==========================================

function AnalyticsManager:GenerateDailyReport()
    local today = os.date("%Y-%m-%d")
    print("📊 AnalyticsManager: Generating daily report for", today)
    
    spawn(function()
        local report = {
            date = today,
            timestamp = tick(),
            metrics = {},
            summary = {}
        }
        
        -- Collect daily metrics
        report.metrics = self:CollectDailyMetrics(today)
        
        -- Generate summary
        report.summary = self:GenerateDailySummary(report.metrics)
        
        -- Save report
        local success, error = pcall(function()
            local reportKey = "daily_report_" .. today
            self.MetricsStore:SetAsync(reportKey, report)
        end)
        
        if success then
            print("✅ AnalyticsManager: Daily report generated successfully")
        else
            warn("❌ AnalyticsManager: Failed to save daily report:", error)
        end
    end)
end

function AnalyticsManager:CollectDailyMetrics(date)
    -- This would typically query stored metrics for the day
    return {
        playerMetrics = {
            totalSessions = self.ServerMetrics.totalSessions,
            averageSessionLength = self.ServerMetrics.averageSessionLength,
            peakConcurrentPlayers = self.ServerMetrics.peakPlayerCount
        },
        economyMetrics = {
            currencyEarned = 0, -- Would be aggregated from stored data
            currencySpent = 0,
            transactionCount = 0
        },
        vipMetrics = {
            conversions = 0,
            revenue = 0,
            trialStarts = 0
        }
    }
end

function AnalyticsManager:GenerateDailySummary(metrics)
    return {
        highlightMetric = "Peak concurrent players: " .. metrics.playerMetrics.peakConcurrentPlayers,
        playerEngagement = metrics.playerMetrics.averageSessionLength > 300 and "High" or "Medium",
        revenueGrowth = metrics.vipMetrics.revenue > 0 and "Positive" or "None",
        recommendations = {
            "Monitor player retention",
            "Optimize VIP conversion funnel",
            "Analyze performance bottlenecks"
        }
    }
end

function AnalyticsManager:UpdateRealTimeDashboard()
    local dashboardData = {
        timestamp = tick(),
        serverMetrics = self.ServerMetrics,
        activePlayers = #Players:GetPlayers(),
        queueSize = #self.EventQueue,
        recentEvents = {} -- Would include recent events
    }
    
    -- Publish to real-time dashboard
    MessagingService:PublishAsync("DashboardUpdate", dashboardData)
end

-- ==========================================
-- HELPER FUNCTIONS
-- ==========================================

function AnalyticsManager:GetPlayerLevel(player)
    local levelManager = _G.LevelManager
    if levelManager then
        return levelManager:GetPlayerLevel(player)
    end
    return 1
end

function AnalyticsManager:IsPlayerVIP(player)
    local vipManager = _G.VIPManager
    if vipManager then
        return vipManager:IsPlayerVIP(player)
    end
    return false
end

function AnalyticsManager:GetPlayerCurrency(player)
    local currencyManager = _G.CurrencyManager
    if currencyManager then
        return currencyManager:GetPlayerCurrency(player)
    end
    return 0
end

function AnalyticsManager:GetPlayerStats(player)
    -- Collect comprehensive player statistics
    return {
        level = self:GetPlayerLevel(player),
        currency = self:GetPlayerCurrency(player),
        isVIP = self:IsPlayerVIP(player),
        joinDate = player.AccountAge,
        membershipType = tostring(player.MembershipType)
    }
end

function AnalyticsManager:IsNewPlayer(player)
    -- Check if this is the player's first session
    return player.AccountAge < 1
end

function AnalyticsManager:GetDeviceType(player)
    -- Would typically get this from client
    return "Unknown"
end

function AnalyticsManager:GetReferralSource(player)
    -- Track referral sources
    return "Direct"
end

function AnalyticsManager:UpdateSessionAnalytics(player, sessionLength)
    -- Update running averages
    local totalLength = self.ServerMetrics.averageSessionLength * (self.ServerMetrics.totalSessions - 1)
    self.ServerMetrics.averageSessionLength = (totalLength + sessionLength) / self.ServerMetrics.totalSessions
end

function AnalyticsManager:UpdateRealTimeMetrics(event)
    -- Update real-time metric aggregations
    -- This would update running totals, averages, etc.
end

function AnalyticsManager:UpdateConversionFunnel(userId, step)
    -- Track player progression through conversion funnel
    self:TrackEvent(Players:GetPlayerByUserId(userId), {
        category = "conversion",
        action = "funnel_step",
        label = step,
        properties = {
            step = step,
            userId = userId
        }
    })
end

function AnalyticsManager:SendToExternalAnalytics(events)
    -- Send to external analytics platforms if configured
    -- This would typically use HttpService to send to external APIs
end

function AnalyticsManager:OnNewPlayer(event)
    -- Handle new player analytics
    print("👋 AnalyticsManager: New player detected:", event.userId)
    
    -- Track retention baseline
    self:TrackMetric("player_retention_day1", 1, event.userId)
end

-- ==========================================
-- PUBLIC API
-- ==========================================

function AnalyticsManager:GetAnalytics(category, timeframe)
    -- Return aggregated analytics data
    return {
        category = category,
        timeframe = timeframe,
        data = {}, -- Would contain actual aggregated data
        generated = tick()
    }
end

function AnalyticsManager:GetPlayerAnalytics(userId)
    -- Return player-specific analytics
    return {
        userId = userId,
        sessions = {}, -- Would contain session data
        metrics = {}, -- Would contain player metrics
        abTests = {} -- Would contain A/B test participation
    }
end

function AnalyticsManager:ExportData(startDate, endDate)
    -- Export analytics data for external analysis
    return {
        startDate = startDate,
        endDate = endDate,
        events = {}, -- Would contain filtered events
        metrics = {}, -- Would contain aggregated metrics
        exported = tick()
    }
end

-- ==========================================
-- CLEANUP
-- ==========================================

function AnalyticsManager:Cleanup()
    -- Process remaining events
    if #self.EventQueue > 0 then
        self:ProcessEventQueue()
    end
    
    -- Save final server metrics
    spawn(function()
        local success, error = pcall(function()
            local finalMetrics = "server_metrics_final_" .. tick()
            self.MetricsStore:SetAsync(finalMetrics, self.ServerMetrics)
        end)
        
        if not success then
            warn("❌ AnalyticsManager: Failed to save final metrics:", error)
        end
    end)
    
    print("📊 AnalyticsManager: Analytics system cleaned up")
end

return AnalyticsManager
