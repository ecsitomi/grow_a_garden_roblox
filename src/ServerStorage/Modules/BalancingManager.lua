--[[
    BalancingManager.lua
    Server-Side Game Balance and Economy Tuning System
    
    Priority: 39 (Polish & Optimization phase)
    Dependencies: All game systems for balance adjustments
    Used by: All managers for balanced gameplay
    
    Features:
    - Dynamic economy balancing
    - Player progression curve optimization
    - Reward system tuning
    - Difficulty scaling adjustments
    - Player behavior analysis
    - A/B testing for balance changes
    - Real-time balance monitoring
    - Automated balance corrections
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

-- Load required modules
local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)

local BalancingManager = {}
BalancingManager.__index = BalancingManager

-- ==========================================
-- INITIALIZATION & SETUP
-- ==========================================

-- Balance tracking and analytics
BalancingManager.BalanceMetrics = {} -- Real-time balance metrics
BalancingManager.PlayerProgression = {} -- Player progression tracking
BalancingManager.EconomyData = {} -- Economy health metrics
BalancingManager.BalanceTests = {} -- Active balance testing

-- Data stores for balance data
BalancingManager.BalanceStore = DataStoreService:GetDataStore("GameBalance_v1")
BalancingManager.MetricsStore = DataStoreService:GetDataStore("BalanceMetrics_v1")

-- Balance configuration
BalancingManager.BalanceConfig = {
    -- Economy balance targets
    economy = {
        targetInflationRate = 0.05, -- 5% per week
        maxCurrencyPerPlayer = 1000000,
        dailyCurrencyTargetPerPlayer = 5000,
        currencySourceDistribution = {
            farming = 0.60,
            mini_games = 0.20,
            daily_rewards = 0.10,
            social = 0.05,
            vip_bonuses = 0.05
        }
    },
    
    -- Progression balance
    progression = {
        averageSessionDuration = 1800, -- 30 minutes target
        levelsPerWeek = 3,
        maxLevelGap = 20, -- Between players
        experienceSourceDistribution = {
            farming = 0.50,
            achievements = 0.20,
            mini_games = 0.15,
            social = 0.10,
            exploration = 0.05
        }
    },
    
    -- Difficulty scaling
    difficulty = {
        baseGrowthTime = 300, -- 5 minutes
        maxGrowthTime = 3600, -- 1 hour
        difficultyRampRate = 0.1, -- 10% increase per level
        rewardScaling = 1.2, -- 20% reward increase per difficulty level
        playerSkillFactor = 0.3 -- How much player skill affects difficulty
    },
    
    -- Social balance
    social = {
        friendsListOptimalSize = 20,
        dailyGiftLimit = 10,
        visitRewardCooldown = 3600, -- 1 hour
        guildOptimalSize = 25,
        socialBonusDecay = 0.9 -- Daily decay for inactive social features
    },
    
    -- VIP balance
    vip = {
        bonusMultiplier = 1.5,
        exclusiveContentPercentage = 0.15, -- 15% of content VIP only
        vipProgressionBonus = 0.25, -- 25% faster progression
        vipRetentionTarget = 0.80 -- 80% monthly retention
    }
}

-- Balance thresholds for automatic adjustments
BalancingManager.BalanceThresholds = {
    economy = {
        inflationRate = {min = 0.02, max = 0.08, critical = 0.15},
        currencyDistribution = {variance = 0.15}, -- Max 15% variance from target
        playerWealth = {gini = 0.6}, -- Gini coefficient threshold
        priceStability = {volatility = 0.2} -- Max 20% price volatility
    },
    
    progression = {
        sessionDuration = {min = 900, max = 3600}, -- 15min - 1hr
        levelDistribution = {standardDeviation = 15},
        playerRetention = {day1 = 0.6, day7 = 0.3, day30 = 0.15},
        engagementRate = {min = 0.4, max = 0.8}
    },
    
    difficulty = {
        completionRate = {min = 0.7, max = 0.9}, -- 70-90% task completion
        frustrationLevel = {max = 0.3}, -- Max 30% frustrated players
        skillGap = {max = 0.4}, -- Max skill gap between players
        learningCurve = {optimal = 0.15} -- 15% improvement per session
    },
    
    social = {
        socialParticipation = {min = 0.5}, -- 50% of players use social features
        friendActivityRate = {min = 0.3}, -- 30% of friends active daily
        guildParticipation = {target = 0.6}, -- 60% guild participation rate
        socialRetention = {bonus = 0.2} -- 20% better retention for social players
    }
}

-- Auto-balancing rules
BalancingManager.AutoBalanceRules = {
    {
        condition = function(metrics) 
            return metrics.economy.inflationRate > BalancingManager.BalanceThresholds.economy.inflationRate.max
        end,
        action = function() 
            BalancingManager:ReduceCurrencyRewards(0.1) 
        end,
        description = "Reduce currency rewards due to high inflation"
    },
    
    {
        condition = function(metrics)
            return metrics.progression.averageSessionDuration < BalancingManager.BalanceThresholds.progression.sessionDuration.min
        end,
        action = function()
            BalancingManager:IncreaseRewardFrequency(0.2)
        end,
        description = "Increase reward frequency for short sessions"
    },
    
    {
        condition = function(metrics)
            return metrics.difficulty.completionRate < BalancingManager.BalanceThresholds.difficulty.completionRate.min
        end,
        action = function()
            BalancingManager:ReduceDifficulty(0.15)
        end,
        description = "Reduce difficulty due to low completion rate"
    },
    
    {
        condition = function(metrics)
            return metrics.social.socialParticipation < BalancingManager.BalanceThresholds.social.socialParticipation.min
        end,
        action = function()
            BalancingManager:IncreaseSocialIncentives(0.25)
        end,
        description = "Increase social incentives due to low participation"
    }
}

-- Balance testing configurations
BalancingManager.BalanceTests = {
    currency_rates = {
        active = true,
        variants = {
            control = {currencyMultiplier = 1.0},
            increased = {currencyMultiplier = 1.2},
            decreased = {currencyMultiplier = 0.8}
        },
        metrics = {"session_duration", "retention", "engagement"},
        duration = 7 * 24 * 60 * 60 -- 7 days
    },
    
    difficulty_scaling = {
        active = true,
        variants = {
            control = {difficultyRamp = 0.1},
            gentle = {difficultyRamp = 0.05},
            steep = {difficultyRamp = 0.15}
        },
        metrics = {"completion_rate", "frustration", "skill_improvement"},
        duration = 14 * 24 * 60 * 60 -- 14 days
    },
    
    social_rewards = {
        active = false,
        variants = {
            control = {socialBonus = 1.0},
            enhanced = {socialBonus = 1.5}
        },
        metrics = {"social_participation", "friend_activity", "retention"},
        duration = 10 * 24 * 60 * 60 -- 10 days
    }
}

-- ==========================================
-- INITIALIZATION
-- ==========================================

function BalancingManager:Initialize()
    print("⚖️ BalancingManager: Initializing game balance system...")
    
    -- Load balance configuration
    self:LoadBalanceConfiguration()
    
    -- Set up balance monitoring
    self:SetupBalanceMonitoring()
    
    -- Initialize balance testing
    self:InitializeBalanceTesting()
    
    -- Start balance analysis loops
    self:StartBalanceAnalysis()
    
    -- Set up remote events
    self:SetupRemoteEvents()
    
    print("✅ BalancingManager: Game balance system initialized")
end

function BalancingManager:LoadBalanceConfiguration()
    -- Load saved balance configuration
    local success, balanceData = pcall(function()
        return self.BalanceStore:GetAsync("balance_config")
    end)
    
    if success and balanceData then
        -- Merge with defaults
        for category, settings in pairs(balanceData) do
            if self.BalanceConfig[category] then
                for key, value in pairs(settings) do
                    self.BalanceConfig[category][key] = value
                end
            end
        end
        print("⚖️ BalancingManager: Loaded saved balance configuration")
    else
        print("⚖️ BalancingManager: Using default balance configuration")
    end
end

function BalancingManager:SetupBalanceMonitoring()
    -- Initialize balance metrics
    self.BalanceMetrics = {
        economy = {
            totalCurrency = 0,
            currencyGeneration = 0,
            currencySpending = 0,
            inflationRate = 0,
            wealthDistribution = {},
            priceStability = 1.0
        },
        
        progression = {
            averageLevel = 1,
            levelDistribution = {},
            experienceGeneration = 0,
            sessionDurations = {},
            retentionRates = {}
        },
        
        difficulty = {
            averageCompletionRate = 0.8,
            frustrationMetrics = {},
            skillProgression = {},
            difficultyAdjustments = 0
        },
        
        social = {
            activeConnections = 0,
            socialParticipation = 0,
            friendActivityRates = {},
            guildParticipation = 0
        },
        
        lastUpdated = tick()
    }
end

function BalancingManager:InitializeBalanceTesting()
    -- Initialize A/B testing for balance
    for testName, testConfig in pairs(self.BalanceTests) do
        if testConfig.active then
            self:StartBalanceTest(testName, testConfig)
        end
    end
end

function BalancingManager:StartBalanceAnalysis()
    -- Main balance analysis loop
    spawn(function()
        while true do
            self:AnalyzeGameBalance()
            wait(300) -- Every 5 minutes
        end
    end)
    
    -- Economy monitoring
    spawn(function()
        while true do
            self:MonitorEconomyHealth()
            wait(60) -- Every minute
        end
    end)
    
    -- Progression tracking
    spawn(function()
        while true do
            self:TrackPlayerProgression()
            wait(180) -- Every 3 minutes
        end
    end)
    
    -- Auto-balancing check
    spawn(function()
        while true do
            self:CheckAutoBalanceRules()
            wait(600) -- Every 10 minutes
        end
    end)
end

function BalancingManager:SetupRemoteEvents()
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then
        remoteEvents = Instance.new("Folder")
        remoteEvents.Name = "RemoteEvents"
        remoteEvents.Parent = ReplicatedStorage
    end
    
    -- Get balance metrics
    local getBalanceMetricsFunction = Instance.new("RemoteFunction")
    getBalanceMetricsFunction.Name = "GetBalanceMetrics"
    getBalanceMetricsFunction.Parent = remoteEvents
    getBalanceMetricsFunction.OnServerInvoke = function(player)
        return self:GetBalanceMetricsForPlayer(player)
    end
    
    -- Apply balance adjustment
    local applyBalanceAdjustmentRemote = Instance.new("RemoteEvent")
    applyBalanceAdjustmentRemote.Name = "ApplyBalanceAdjustment"
    applyBalanceAdjustmentRemote.Parent = remoteEvents
    applyBalanceAdjustmentRemote.OnServerEvent:Connect(function(player, adjustmentData)
        self:ApplyManualBalanceAdjustment(player, adjustmentData)
    end)
end

-- ==========================================
-- BALANCE MONITORING
-- ==========================================

function BalancingManager:AnalyzeGameBalance()
    print("⚖️ BalancingManager: Analyzing game balance...")
    
    -- Update all balance metrics
    self:UpdateEconomyMetrics()
    self:UpdateProgressionMetrics()
    self:UpdateDifficultyMetrics()
    self:UpdateSocialMetrics()
    
    -- Check for balance issues
    local issues = self:IdentifyBalanceIssues()
    
    -- Generate balance report
    local balanceReport = self:GenerateBalanceReport(issues)
    
    -- Save metrics
    self:SaveBalanceMetrics(balanceReport)
    
    if #issues > 0 then
        print("⚠️ BalancingManager: Found", #issues, "balance issues")
        self:HandleBalanceIssues(issues)
    else
        print("✅ BalancingManager: Game balance is healthy")
    end
    
    self.BalanceMetrics.lastUpdated = tick()
end

function BalancingManager:UpdateEconomyMetrics()
    local economyManager = _G.EconomyManager
    if not economyManager then return end
    
    local totalCurrency = 0
    local currencyGeneration = 0
    local currencySpending = 0
    local playerWealth = {}
    
    -- Collect currency data from all players
    for _, player in pairs(Players:GetPlayers()) do
        local playerCoins = economyManager:GetCurrency(player, "coins") or 0
        totalCurrency = totalCurrency + playerCoins
        table.insert(playerWealth, playerCoins)
        
        -- Get currency generation/spending rates (would need tracking in EconomyManager)
        local generationRate = economyManager:GetPlayerCurrencyGeneration(player) or 0
        local spendingRate = economyManager:GetPlayerCurrencySpending(player) or 0
        
        currencyGeneration = currencyGeneration + generationRate
        currencySpending = currencySpending + spendingRate
    end
    
    -- Calculate inflation rate
    local previousTotal = self.BalanceMetrics.economy.totalCurrency
    local inflationRate = previousTotal > 0 and (totalCurrency - previousTotal) / previousTotal or 0
    
    -- Update metrics
    self.BalanceMetrics.economy.totalCurrency = totalCurrency
    self.BalanceMetrics.economy.currencyGeneration = currencyGeneration
    self.BalanceMetrics.economy.currencySpending = currencySpending
    self.BalanceMetrics.economy.inflationRate = inflationRate
    self.BalanceMetrics.economy.wealthDistribution = playerWealth
    
    -- Calculate wealth inequality (Gini coefficient)
    self.BalanceMetrics.economy.giniCoefficient = self:CalculateGiniCoefficient(playerWealth)
end

function BalancingManager:UpdateProgressionMetrics()
    local economyManager = _G.EconomyManager
    if not economyManager then return end
    
    local totalLevel = 0
    local levelDistribution = {}
    local sessionDurations = {}
    
    for _, player in pairs(Players:GetPlayers()) do
        local playerLevel = economyManager:GetPlayerLevel(player) or 1
        totalLevel = totalLevel + playerLevel
        
        -- Track level distribution
        levelDistribution[playerLevel] = (levelDistribution[playerLevel] or 0) + 1
        
        -- Get session duration (would need tracking)
        local sessionDuration = self:GetPlayerSessionDuration(player)
        if sessionDuration then
            table.insert(sessionDurations, sessionDuration)
        end
    end
    
    -- Calculate averages
    local playerCount = #Players:GetPlayers()
    local averageLevel = playerCount > 0 and totalLevel / playerCount or 1
    local averageSessionDuration = #sessionDurations > 0 and self:CalculateAverage(sessionDurations) or 0
    
    -- Update metrics
    self.BalanceMetrics.progression.averageLevel = averageLevel
    self.BalanceMetrics.progression.levelDistribution = levelDistribution
    self.BalanceMetrics.progression.averageSessionDuration = averageSessionDuration
end

function BalancingManager:UpdateDifficultyMetrics()
    -- This would integrate with various game systems to track difficulty
    local plotManager = _G.PlotManager
    local miniGameManager = _G.MiniGameManager
    
    local completionRates = {}
    local frustrationMetrics = {}
    
    -- Collect completion rate data
    if plotManager then
        local farmingCompletionRate = plotManager:GetAverageCompletionRate() or 0.8
        table.insert(completionRates, farmingCompletionRate)
    end
    
    if miniGameManager then
        local gameCompletionRate = miniGameManager:GetAverageCompletionRate() or 0.7
        table.insert(completionRates, gameCompletionRate)
    end
    
    -- Calculate average completion rate
    local averageCompletionRate = #completionRates > 0 and self:CalculateAverage(completionRates) or 0.8
    
    self.BalanceMetrics.difficulty.averageCompletionRate = averageCompletionRate
end

function BalancingManager:UpdateSocialMetrics()
    local socialManager = _G.SocialManager
    if not socialManager then return end
    
    local activeConnections = 0
    local socialParticipation = 0
    local guildParticipation = 0
    local playerCount = #Players:GetPlayers()
    
    for _, player in pairs(Players:GetPlayers()) do
        -- Count active friend connections
        local friendCount = socialManager:GetFriendCount(player) or 0
        activeConnections = activeConnections + friendCount
        
        -- Check social participation
        if socialManager:IsPlayerSociallyActive(player) then
            socialParticipation = socialParticipation + 1
        end
        
        -- Check guild participation
        if socialManager:IsPlayerInGuild(player) then
            guildParticipation = guildParticipation + 1
        end
    end
    
    -- Calculate rates
    self.BalanceMetrics.social.activeConnections = activeConnections
    self.BalanceMetrics.social.socialParticipation = playerCount > 0 and socialParticipation / playerCount or 0
    self.BalanceMetrics.social.guildParticipation = playerCount > 0 and guildParticipation / playerCount or 0
end

-- ==========================================
-- BALANCE ISSUE DETECTION
-- ==========================================

function BalancingManager:IdentifyBalanceIssues()
    local issues = {}
    
    -- Check economy issues
    local economyIssues = self:CheckEconomyBalance()
    for _, issue in ipairs(economyIssues) do
        table.insert(issues, issue)
    end
    
    -- Check progression issues
    local progressionIssues = self:CheckProgressionBalance()
    for _, issue in ipairs(progressionIssues) do
        table.insert(issues, issue)
    end
    
    -- Check difficulty issues
    local difficultyIssues = self:CheckDifficultyBalance()
    for _, issue in ipairs(difficultyIssues) do
        table.insert(issues, issue)
    end
    
    -- Check social issues
    local socialIssues = self:CheckSocialBalance()
    for _, issue in ipairs(socialIssues) do
        table.insert(issues, issue)
    end
    
    return issues
end

function BalancingManager:CheckEconomyBalance()
    local issues = {}
    local metrics = self.BalanceMetrics.economy
    local thresholds = self.BalanceThresholds.economy
    
    -- Check inflation rate
    if metrics.inflationRate > thresholds.inflationRate.critical then
        table.insert(issues, {
            type = "economy",
            severity = "critical",
            issue = "hyperinflation",
            description = "Inflation rate is critically high: " .. math.floor(metrics.inflationRate * 100) .. "%",
            currentValue = metrics.inflationRate,
            threshold = thresholds.inflationRate.critical
        })
    elseif metrics.inflationRate > thresholds.inflationRate.max then
        table.insert(issues, {
            type = "economy",
            severity = "high",
            issue = "high_inflation",
            description = "Inflation rate is above target: " .. math.floor(metrics.inflationRate * 100) .. "%",
            currentValue = metrics.inflationRate,
            threshold = thresholds.inflationRate.max
        })
    elseif metrics.inflationRate < thresholds.inflationRate.min then
        table.insert(issues, {
            type = "economy",
            severity = "medium",
            issue = "deflation",
            description = "Inflation rate is below minimum: " .. math.floor(metrics.inflationRate * 100) .. "%",
            currentValue = metrics.inflationRate,
            threshold = thresholds.inflationRate.min
        })
    end
    
    -- Check wealth inequality
    if metrics.giniCoefficient and metrics.giniCoefficient > thresholds.playerWealth.gini then
        table.insert(issues, {
            type = "economy",
            severity = "medium",
            issue = "wealth_inequality",
            description = "Wealth inequality is too high (Gini: " .. math.floor(metrics.giniCoefficient * 100) .. ")",
            currentValue = metrics.giniCoefficient,
            threshold = thresholds.playerWealth.gini
        })
    end
    
    return issues
end

function BalancingManager:CheckProgressionBalance()
    local issues = {}
    local metrics = self.BalanceMetrics.progression
    local thresholds = self.BalanceThresholds.progression
    
    -- Check session duration
    if metrics.averageSessionDuration < thresholds.sessionDuration.min then
        table.insert(issues, {
            type = "progression",
            severity = "high",
            issue = "short_sessions",
            description = "Average session duration is too short: " .. math.floor(metrics.averageSessionDuration / 60) .. " minutes",
            currentValue = metrics.averageSessionDuration,
            threshold = thresholds.sessionDuration.min
        })
    elseif metrics.averageSessionDuration > thresholds.sessionDuration.max then
        table.insert(issues, {
            type = "progression",
            severity = "medium",
            issue = "long_sessions",
            description = "Average session duration is very long: " .. math.floor(metrics.averageSessionDuration / 60) .. " minutes",
            currentValue = metrics.averageSessionDuration,
            threshold = thresholds.sessionDuration.max
        })
    end
    
    return issues
end

function BalancingManager:CheckDifficultyBalance()
    local issues = {}
    local metrics = self.BalanceMetrics.difficulty
    local thresholds = self.BalanceThresholds.difficulty
    
    -- Check completion rate
    if metrics.averageCompletionRate < thresholds.completionRate.min then
        table.insert(issues, {
            type = "difficulty",
            severity = "high",
            issue = "too_difficult",
            description = "Completion rate is too low: " .. math.floor(metrics.averageCompletionRate * 100) .. "%",
            currentValue = metrics.averageCompletionRate,
            threshold = thresholds.completionRate.min
        })
    elseif metrics.averageCompletionRate > thresholds.completionRate.max then
        table.insert(issues, {
            type = "difficulty",
            severity = "medium",
            issue = "too_easy",
            description = "Completion rate is too high: " .. math.floor(metrics.averageCompletionRate * 100) .. "%",
            currentValue = metrics.averageCompletionRate,
            threshold = thresholds.completionRate.max
        })
    end
    
    return issues
end

function BalancingManager:CheckSocialBalance()
    local issues = {}
    local metrics = self.BalanceMetrics.social
    local thresholds = self.BalanceThresholds.social
    
    -- Check social participation
    if metrics.socialParticipation < thresholds.socialParticipation.min then
        table.insert(issues, {
            type = "social",
            severity = "medium",
            issue = "low_social_engagement",
            description = "Social participation is low: " .. math.floor(metrics.socialParticipation * 100) .. "%",
            currentValue = metrics.socialParticipation,
            threshold = thresholds.socialParticipation.min
        })
    end
    
    return issues
end

-- ==========================================
-- AUTO-BALANCING SYSTEM
-- ==========================================

function BalancingManager:CheckAutoBalanceRules()
    for _, rule in ipairs(self.AutoBalanceRules) do
        if rule.condition(self.BalanceMetrics) then
            print("⚖️ BalancingManager: Executing auto-balance rule:", rule.description)
            rule.action()
            
            -- Log the adjustment
            self:LogBalanceAdjustment("automatic", rule.description, tick())
        end
    end
end

function BalancingManager:ReduceCurrencyRewards(reductionPercentage)
    -- Reduce currency rewards across all systems
    local economyManager = _G.EconomyManager
    if economyManager then
        economyManager:AdjustRewardMultiplier("currency", 1 - reductionPercentage)
        print("⚖️ BalancingManager: Reduced currency rewards by", math.floor(reductionPercentage * 100) .. "%")
    end
end

function BalancingManager:IncreaseRewardFrequency(increasePercentage)
    -- Increase reward frequency to boost engagement
    local plotManager = _G.PlotManager
    if plotManager then
        plotManager:AdjustRewardFrequency(1 + increasePercentage)
        print("⚖️ BalancingManager: Increased reward frequency by", math.floor(increasePercentage * 100) .. "%")
    end
end

function BalancingManager:ReduceDifficulty(reductionPercentage)
    -- Reduce difficulty across game systems
    local plotManager = _G.PlotManager
    local miniGameManager = _G.MiniGameManager
    
    if plotManager then
        plotManager:AdjustDifficulty(1 - reductionPercentage)
    end
    
    if miniGameManager then
        miniGameManager:AdjustDifficulty(1 - reductionPercentage)
    end
    
    print("⚖️ BalancingManager: Reduced difficulty by", math.floor(reductionPercentage * 100) .. "%")
end

function BalancingManager:IncreaseSocialIncentives(increasePercentage)
    -- Increase social feature incentives
    local socialManager = _G.SocialManager
    if socialManager then
        socialManager:AdjustSocialRewards(1 + increasePercentage)
        print("⚖️ BalancingManager: Increased social incentives by", math.floor(increasePercentage * 100) .. "%")
    end
end

-- ==========================================
-- BALANCE TESTING
-- ==========================================

function BalancingManager:StartBalanceTest(testName, testConfig)
    print("⚖️ BalancingManager: Starting balance test:", testName)
    
    -- Initialize test
    local test = {
        name = testName,
        config = testConfig,
        startTime = tick(),
        participants = {},
        results = {}
    }
    
    -- Assign players to test variants
    for _, player in pairs(Players:GetPlayers()) do
        self:AssignPlayerToBalanceTest(player, test)
    end
    
    self.BalanceTests[testName] = test
end

function BalancingManager:AssignPlayerToBalanceTest(player, test)
    -- Use consistent hashing for assignment
    local seed = player.UserId + test.startTime
    math.randomseed(seed)
    
    local variants = {}
    for variantName, _ in pairs(test.config.variants) do
        table.insert(variants, variantName)
    end
    
    local selectedVariant = variants[math.random(1, #variants)]
    
    test.participants[player.UserId] = {
        variant = selectedVariant,
        startTime = tick(),
        metrics = {}
    }
    
    -- Apply test variant to player
    self:ApplyBalanceTestVariant(player, test.config.variants[selectedVariant])
end

function BalancingManager:ApplyBalanceTestVariant(player, variant)
    -- Apply variant configuration to player
    for setting, value in pairs(variant) do
        if setting == "currencyMultiplier" then
            self:SetPlayerCurrencyMultiplier(player, value)
        elseif setting == "difficultyRamp" then
            self:SetPlayerDifficultyRamp(player, value)
        elseif setting == "socialBonus" then
            self:SetPlayerSocialBonus(player, value)
        end
    end
end

-- ==========================================
-- HELPER FUNCTIONS
-- ==========================================

function BalancingManager:CalculateGiniCoefficient(wealthData)
    if #wealthData < 2 then return 0 end
    
    table.sort(wealthData)
    
    local n = #wealthData
    local index = 0
    for i, wealth in ipairs(wealthData) do
        index = index + (2 * i - n - 1) * wealth
    end
    
    local total = 0
    for _, wealth in ipairs(wealthData) do
        total = total + wealth
    end
    
    return total > 0 and index / (n * total) or 0
end

function BalancingManager:CalculateAverage(numbers)
    if #numbers == 0 then return 0 end
    
    local sum = 0
    for _, number in ipairs(numbers) do
        sum = sum + number
    end
    
    return sum / #numbers
end

function BalancingManager:GetPlayerSessionDuration(player)
    -- This would get actual session duration from analytics
    local analyticsManager = _G.AnalyticsManager
    if analyticsManager then
        local analytics = analyticsManager:GetPlayerAnalytics(player)
        return analytics.session_duration
    end
    return nil
end

function BalancingManager:GenerateBalanceReport(issues)
    local report = {
        timestamp = tick(),
        metrics = self.BalanceMetrics,
        issues = issues,
        recommendations = self:GenerateRecommendations(issues),
        healthScore = self:CalculateBalanceHealthScore(issues)
    }
    
    return report
end

function BalancingManager:GenerateRecommendations(issues)
    local recommendations = {}
    
    for _, issue in ipairs(issues) do
        if issue.type == "economy" and issue.issue == "high_inflation" then
            table.insert(recommendations, "Consider reducing currency generation rates or increasing currency sinks")
        elseif issue.type == "progression" and issue.issue == "short_sessions" then
            table.insert(recommendations, "Add more engaging content or increase reward frequency")
        elseif issue.type == "difficulty" and issue.issue == "too_difficult" then
            table.insert(recommendations, "Consider reducing difficulty or providing better tutorials")
        elseif issue.type == "social" and issue.issue == "low_social_engagement" then
            table.insert(recommendations, "Increase social feature visibility and rewards")
        end
    end
    
    return recommendations
end

function BalancingManager:CalculateBalanceHealthScore(issues)
    local score = 100
    
    for _, issue in ipairs(issues) do
        if issue.severity == "critical" then
            score = score - 20
        elseif issue.severity == "high" then
            score = score - 10
        elseif issue.severity == "medium" then
            score = score - 5
        end
    end
    
    return math.max(0, score)
end

function BalancingManager:SaveBalanceMetrics(balanceReport)
    local metricsKey = "balance_metrics_" .. os.date("%Y_%m_%d_%H")
    
    spawn(function()
        local success, error = pcall(function()
            self.MetricsStore:SetAsync(metricsKey, balanceReport)
        end)
        
        if not success then
            warn("❌ BalancingManager: Failed to save balance metrics:", error)
        end
    end)
end

function BalancingManager:LogBalanceAdjustment(adjustmentType, description, timestamp)
    print("⚖️ BalancingManager: [" .. adjustmentType:upper() .. "] " .. description)
    
    -- This would log to analytics system
    local analyticsManager = _G.AnalyticsManager
    if analyticsManager then
        analyticsManager:TrackServerEvent({
            category = "balance",
            action = "adjustment",
            properties = {
                type = adjustmentType,
                description = description,
                timestamp = timestamp
            }
        })
    end
end

-- ==========================================
-- PUBLIC API
-- ==========================================

function BalancingManager:GetBalanceMetrics()
    return self.BalanceMetrics
end

function BalancingManager:GetBalanceConfig()
    return self.BalanceConfig
end

function BalancingManager:GetBalanceMetricsForPlayer(player)
    -- Return sanitized metrics for developer players
    if self:IsPlayerDeveloper(player) then
        return self.BalanceMetrics
    end
    
    return {
        healthScore = self:CalculateBalanceHealthScore({}),
        lastUpdated = self.BalanceMetrics.lastUpdated
    }
end

function BalancingManager:ApplyManualBalanceAdjustment(player, adjustmentData)
    if not self:IsPlayerDeveloper(player) then return end
    
    print("⚖️ BalancingManager: Manual adjustment by", player.Name, ":", adjustmentData.description)
    
    -- Apply the adjustment based on type
    if adjustmentData.type == "currency_multiplier" then
        self:SetGlobalCurrencyMultiplier(adjustmentData.value)
    elseif adjustmentData.type == "difficulty_adjustment" then
        self:SetGlobalDifficultyMultiplier(adjustmentData.value)
    elseif adjustmentData.type == "reward_frequency" then
        self:SetGlobalRewardFrequency(adjustmentData.value)
    end
    
    -- Log the manual adjustment
    self:LogBalanceAdjustment("manual", adjustmentData.description, tick())
end

function BalancingManager:SetGlobalCurrencyMultiplier(multiplier)
    local economyManager = _G.EconomyManager
    if economyManager then
        economyManager:SetGlobalCurrencyMultiplier(multiplier)
    end
end

function BalancingManager:SetGlobalDifficultyMultiplier(multiplier)
    -- Apply to all difficulty-related systems
    local plotManager = _G.PlotManager
    local miniGameManager = _G.MiniGameManager
    
    if plotManager then
        plotManager:SetDifficultyMultiplier(multiplier)
    end
    
    if miniGameManager then
        miniGameManager:SetDifficultyMultiplier(multiplier)
    end
end

function BalancingManager:SetGlobalRewardFrequency(frequency)
    -- Apply to all reward systems
    local plotManager = _G.PlotManager
    if plotManager then
        plotManager:SetRewardFrequency(frequency)
    end
end

function BalancingManager:SetPlayerCurrencyMultiplier(player, multiplier)
    -- Set player-specific currency multiplier for testing
    player:SetAttribute("CurrencyMultiplier", multiplier)
end

function BalancingManager:SetPlayerDifficultyRamp(player, ramp)
    -- Set player-specific difficulty ramp for testing
    player:SetAttribute("DifficultyRamp", ramp)
end

function BalancingManager:SetPlayerSocialBonus(player, bonus)
    -- Set player-specific social bonus for testing
    player:SetAttribute("SocialBonus", bonus)
end

function BalancingManager:IsPlayerDeveloper(player)
    -- Check if player is a developer (placeholder)
    return player.UserId == 123456789 -- Replace with actual developer IDs
end

function BalancingManager:ForceBalanceAnalysis()
    self:AnalyzeGameBalance()
end

function BalancingManager:GetBalanceHealthScore()
    local issues = self:IdentifyBalanceIssues()
    return self:CalculateBalanceHealthScore(issues)
end

-- ==========================================
-- CLEANUP
-- ==========================================

function BalancingManager:Cleanup()
    -- Save final balance configuration
    local success, error = pcall(function()
        self.BalanceStore:SetAsync("balance_config", self.BalanceConfig)
    end)
    
    if not success then
        warn("❌ BalancingManager: Failed to save balance config:", error)
    end
    
    -- Generate final balance report
    local issues = self:IdentifyBalanceIssues()
    local finalReport = self:GenerateBalanceReport(issues)
    self:SaveBalanceMetrics(finalReport)
    
    print("⚖️ BalancingManager: Game balance system cleaned up")
end

return BalancingManager
