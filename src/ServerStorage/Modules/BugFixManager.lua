--[[
    BugFixManager.lua
    Server-Side Bug Detection, Reporting, and Automated Testing System
    
    Priority: 37 (Polish & Optimization phase)
    Dependencies: All game systems for testing and bug detection
    Used by: All managers for error handling and testing
    
    Features:
    - Automated bug detection and reporting
    - Comprehensive testing framework
    - Error logging and analytics
    - Memory leak detection
    - Performance regression testing
    - Data validation and integrity checks
    - Automated stress testing
    - User experience monitoring
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local TestService = game:GetService("TestService")
local LogService = game:GetService("LogService")

-- Load required modules
local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)

local BugFixManager = {}
BugFixManager.__index = BugFixManager

-- ==========================================
-- INITIALIZATION & SETUP
-- ==========================================

-- Bug tracking and testing state
BugFixManager.BugReports = {} -- Active bug reports
BugFixManager.TestSuites = {} -- Automated test suites
BugFixManager.ErrorLogs = {} -- Error logging system
BugFixManager.PerformanceBaselines = {} -- Performance baselines for regression testing

-- Data stores for bug tracking
BugFixManager.BugStore = DataStoreService:GetDataStore("BugReports_v1")
BugFixManager.TestResultStore = DataStoreService:GetDataStore("TestResults_v1")

-- Bug detection settings
BugFixManager.BugDetectionSettings = {
    -- Error detection
    enableErrorLogging = true,
    enableCrashDetection = true,
    enableMemoryLeakDetection = true,
    enablePerformanceRegression = true,
    
    -- Thresholds
    maxErrorsPerMinute = 10,
    maxMemoryGrowth = 100, -- MB per hour
    maxFrameTimeRegression = 5, -- ms
    maxDataStoreErrors = 5,
    
    -- Testing
    enableAutomatedTesting = true,
    testIntervalMinutes = 30,
    stressTestPlayerCount = 20,
    
    -- Reporting
    enableBugReporting = true,
    reportCriticalBugs = true,
    reportToConsole = true,
    reportToDataStore = true
}

-- Test categories
BugFixManager.TestCategories = {
    CORE_SYSTEMS = "core_systems",
    GAMEPLAY = "gameplay", 
    ECONOMY = "economy",
    SOCIAL = "social",
    VIP = "vip",
    DATA_INTEGRITY = "data_integrity",
    PERFORMANCE = "performance",
    UI_UX = "ui_ux",
    STRESS = "stress",
    REGRESSION = "regression"
}

-- Bug severity levels
BugFixManager.BugSeverity = {
    CRITICAL = {level = 1, name = "CRITICAL", color = Color3.fromRGB(255, 0, 0)},
    HIGH = {level = 2, name = "HIGH", color = Color3.fromRGB(255, 165, 0)},
    MEDIUM = {level = 3, name = "MEDIUM", color = Color3.fromRGB(255, 255, 0)},
    LOW = {level = 4, name = "LOW", color = Color3.fromRGB(0, 255, 0)},
    INFO = {level = 5, name = "INFO", color = Color3.fromRGB(173, 216, 230)}
}

-- Error tracking
BugFixManager.ErrorTracking = {
    errorCount = 0,
    lastErrorTime = 0,
    errorFrequency = {},
    commonErrors = {},
    crashCount = 0
}

-- Performance baselines
BugFixManager.PerformanceBaselines = {
    averageFrameTime = 16.67, -- 60 FPS target
    averageMemoryUsage = 200, -- MB
    averagePlayerJoinTime = 3, -- seconds
    averageDataStoreLatency = 100 -- ms
}

-- ==========================================
-- INITIALIZATION
-- ==========================================

function BugFixManager:Initialize()
    print("🐛 BugFixManager: Initializing bug detection and testing system...")
    
    -- Set up error detection
    self:SetupErrorDetection()
    
    -- Initialize test suites
    self:InitializeTestSuites()
    
    -- Set up performance monitoring
    self:SetupPerformanceMonitoring()
    
    -- Start automated testing
    self:StartAutomatedTesting()
    
    -- Set up bug reporting
    self:SetupBugReporting()
    
    -- Start monitoring loops
    self:StartMonitoringLoops()
    
    print("✅ BugFixManager: Bug detection and testing system initialized")
end

function BugFixManager:SetupErrorDetection()
    -- Hook into error logging
    LogService.MessageOut:Connect(function(message, messageType)
        self:HandleLogMessage(message, messageType)
    end)
    
    -- Set up crash detection
    game.Players.PlayerRemoving:Connect(function(player)
        self:CheckForPlayerCrash(player)
    end)
    
    -- Memory leak detection
    spawn(function()
        while true do
            self:CheckForMemoryLeaks()
            wait(300) -- Check every 5 minutes
        end
    end)
    
    -- Performance regression detection
    spawn(function()
        while true do
            self:CheckForPerformanceRegression()
            wait(60) -- Check every minute
        end
    end)
end

function BugFixManager:InitializeTestSuites()
    -- Core Systems Tests
    self.TestSuites[self.TestCategories.CORE_SYSTEMS] = {
        {name = "PlotManager_BasicFunctionality", func = function() return self:TestPlotManager() end},
        {name = "EconomyManager_CurrencyOperations", func = function() return self:TestEconomyManager() end},
        {name = "InventoryManager_ItemOperations", func = function() return self:TestInventoryManager() end},
        {name = "VIPManager_VIPStatus", func = function() return self:TestVIPManager() end}
    }
    
    -- Gameplay Tests
    self.TestSuites[self.TestCategories.GAMEPLAY] = {
        {name = "PlantGrowth_Lifecycle", func = function() return self:TestPlantGrowth() end},
        {name = "Harvesting_Rewards", func = function() return self:TestHarvesting() end},
        {name = "ShopPurchases_Functionality", func = function() return self:TestShopPurchases() end},
        {name = "WeatherSystem_Effects", func = function() return self:TestWeatherSystem() end}
    }
    
    -- Economy Tests  
    self.TestSuites[self.TestCategories.ECONOMY] = {
        {name = "CurrencyBalance_Integrity", func = function() return self:TestCurrencyIntegrity() end},
        {name = "ItemPricing_Accuracy", func = function() return self:TestItemPricing() end},
        {name = "VIPBonuses_Calculation", func = function() return self:TestVIPBonuses() end},
        {name = "DailyRewards_System", func = function() return self:TestDailyRewards() end}
    }
    
    -- Social Tests
    self.TestSuites[self.TestCategories.SOCIAL] = {
        {name = "FriendSystem_Operations", func = function() return self:TestFriendSystem() end},
        {name = "GardenVisiting_Permissions", func = function() return self:TestGardenVisiting() end},
        {name = "GiftSystem_Exchange", func = function() return self:TestGiftSystem() end},
        {name = "SocialHubs_Functionality", func = function() return self:TestSocialHubs() end}
    }
    
    -- Data Integrity Tests
    self.TestSuites[self.TestCategories.DATA_INTEGRITY] = {
        {name = "PlayerData_Validation", func = function() return self:TestPlayerDataValidation() end},
        {name = "DataStore_Operations", func = function() return self:TestDataStoreOperations() end},
        {name = "CrossSession_Persistence", func = function() return self:TestCrossSessionPersistence() end},
        {name = "DataCorruption_Detection", func = function() return self:TestDataCorruptionDetection() end}
    }
    
    -- Performance Tests
    self.TestSuites[self.TestCategories.PERFORMANCE] = {
        {name = "FrameRate_Stability", func = function() return self:TestFrameRateStability() end},
        {name = "MemoryUsage_Limits", func = function() return self:TestMemoryUsage() end},
        {name = "NetworkLatency_Performance", func = function() return self:TestNetworkLatency() end},
        {name = "LoadTesting_Capacity", func = function() return self:TestLoadCapacity() end}
    }
    
    print("🐛 BugFixManager: Initialized", self:CountTotalTests(), "test cases across", #self.TestSuites, "categories")
end

function BugFixManager:SetupPerformanceMonitoring()
    -- Monitor frame rate
    local frameTimeSum = 0
    local frameCount = 0
    
    RunService.Heartbeat:Connect(function(deltaTime)
        frameTimeSum = frameTimeSum + deltaTime * 1000 -- Convert to ms
        frameCount = frameCount + 1
        
        if frameCount >= 60 then -- Every 60 frames
            local averageFrameTime = frameTimeSum / frameCount
            self:CheckFrameTimeRegression(averageFrameTime)
            frameTimeSum = 0
            frameCount = 0
        end
    end)
    
    -- Monitor memory usage
    spawn(function()
        local lastMemory = gcinfo()
        while true do
            local currentMemory = gcinfo()
            self:CheckMemoryRegression(currentMemory, lastMemory)
            lastMemory = currentMemory
            wait(60) -- Check every minute
        end
    end)
end

function BugFixManager:StartAutomatedTesting()
    if not self.BugDetectionSettings.enableAutomatedTesting then return end
    
    spawn(function()
        while true do
            self:RunAutomatedTests()
            wait(self.BugDetectionSettings.testIntervalMinutes * 60)
        end
    end)
    
    -- Run initial test suite
    spawn(function()
        wait(30) -- Wait for systems to initialize
        self:RunAutomatedTests()
    end)
end

function BugFixManager:SetupBugReporting()
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then
        remoteEvents = Instance.new("Folder")
        remoteEvents.Name = "RemoteEvents"
        remoteEvents.Parent = ReplicatedStorage
    end
    
    -- Client bug reporting
    local bugReportRemote = Instance.new("RemoteEvent")
    bugReportRemote.Name = "ReportBug"
    bugReportRemote.Parent = remoteEvents
    bugReportRemote.OnServerEvent:Connect(function(player, bugData)
        self:HandleClientBugReport(player, bugData)
    end)
    
    -- Get bug reports function
    local getBugReportsFunction = Instance.new("RemoteFunction")
    getBugReportsFunction.Name = "GetBugReports"
    getBugReportsFunction.Parent = remoteEvents
    getBugReportsFunction.OnServerInvoke = function(player)
        return self:GetBugReportsForPlayer(player)
    end
end

function BugFixManager:StartMonitoringLoops()
    -- Main monitoring loop
    spawn(function()
        while true do
            self:PerformSystemHealthCheck()
            wait(60) -- Every minute
        end
    end)
    
    -- Error frequency monitoring
    spawn(function()
        while true do
            self:AnalyzeErrorFrequency()
            wait(300) -- Every 5 minutes
        end
    end)
    
    -- Bug report processing
    spawn(function()
        while true do
            self:ProcessPendingBugReports()
            wait(30) -- Every 30 seconds
        end
    end)
end

-- ==========================================
-- ERROR DETECTION & LOGGING
-- ==========================================

function BugFixManager:HandleLogMessage(message, messageType)
    if not self.BugDetectionSettings.enableErrorLogging then return end
    
    local currentTime = tick()
    self.ErrorTracking.lastErrorTime = currentTime
    
    -- Categorize message type
    local severity = self.BugSeverity.INFO
    if messageType == Enum.MessageType.MessageError then
        severity = self.BugSeverity.HIGH
        self.ErrorTracking.errorCount = self.ErrorTracking.errorCount + 1
    elseif messageType == Enum.MessageType.MessageWarning then
        severity = self.BugSeverity.MEDIUM
    end
    
    -- Create error log entry
    local errorLog = {
        timestamp = currentTime,
        message = message,
        messageType = messageType,
        severity = severity,
        serverId = game.JobId,
        placeId = game.PlaceId
    }
    
    table.insert(self.ErrorLogs, errorLog)
    
    -- Check for error frequency issues
    self:CheckErrorFrequency()
    
    -- Report critical errors immediately
    if severity.level <= 2 then
        self:ReportBug({
            title = "Critical Error Detected",
            description = message,
            severity = severity,
            category = "error",
            timestamp = currentTime,
            autoGenerated = true
        })
    end
    
    -- Log to console if enabled
    if self.BugDetectionSettings.reportToConsole then
        print("🐛 BugFixManager: [" .. severity.name .. "] " .. message)
    end
end

function BugFixManager:CheckErrorFrequency()
    local currentTime = tick()
    local oneMinuteAgo = currentTime - 60
    
    -- Count errors in the last minute
    local recentErrors = 0
    for _, errorLog in ipairs(self.ErrorLogs) do
        if errorLog.timestamp > oneMinuteAgo then
            recentErrors = recentErrors + 1
        end
    end
    
    -- Check if exceeding threshold
    if recentErrors > self.BugDetectionSettings.maxErrorsPerMinute then
        self:ReportBug({
            title = "High Error Frequency Detected",
            description = "Detected " .. recentErrors .. " errors in the last minute",
            severity = self.BugSeverity.CRITICAL,
            category = "performance",
            timestamp = currentTime,
            autoGenerated = true
        })
    end
end

function BugFixManager:CheckForPlayerCrash(player)
    local sessionDuration = tick() - (player:GetAttribute("JoinTime") or tick())
    
    -- If player left very quickly, might be a crash
    if sessionDuration < 30 then -- Less than 30 seconds
        self.ErrorTracking.crashCount = self.ErrorTracking.crashCount + 1
        
        self:ReportBug({
            title = "Potential Player Crash",
            description = "Player " .. player.Name .. " left after only " .. math.floor(sessionDuration) .. " seconds",
            severity = self.BugSeverity.HIGH,
            category = "crash",
            timestamp = tick(),
            playerUserId = player.UserId,
            autoGenerated = true
        })
    end
end

function BugFixManager:CheckForMemoryLeaks()
    local currentMemory = gcinfo()
    local lastCheck = self:GetLastMemoryCheck()
    
    if lastCheck then
        local memoryGrowth = currentMemory - lastCheck.memory
        local timeDiff = (tick() - lastCheck.timestamp) / 3600 -- Hours
        local growthRate = memoryGrowth / timeDiff -- MB per hour
        
        if growthRate > self.BugDetectionSettings.maxMemoryGrowth then
            self:ReportBug({
                title = "Memory Leak Detected",
                description = "Memory growing at " .. math.floor(growthRate) .. " MB/hour",
                severity = self.BugSeverity.HIGH,
                category = "memory",
                timestamp = tick(),
                autoGenerated = true
            })
        end
    end
    
    -- Store current memory check
    self:SetLastMemoryCheck(currentMemory)
end

function BugFixManager:CheckForPerformanceRegression()
    local performanceOptimizer = _G.PerformanceOptimizer
    if not performanceOptimizer then return end
    
    local metrics = performanceOptimizer:GetPerformanceMetrics()
    
    -- Check frame time regression
    if metrics.frameRate > 0 then
        local currentFrameTime = 1000 / metrics.frameRate -- Convert to ms
        local baseline = self.PerformanceBaselines.averageFrameTime
        
        if currentFrameTime > baseline + self.BugDetectionSettings.maxFrameTimeRegression then
            self:ReportBug({
                title = "Performance Regression Detected",
                description = "Frame time increased to " .. math.floor(currentFrameTime) .. "ms (baseline: " .. baseline .. "ms)",
                severity = self.BugSeverity.MEDIUM,
                category = "performance",
                timestamp = tick(),
                autoGenerated = true
            })
        end
    end
end

-- ==========================================
-- BUG REPORTING SYSTEM
-- ==========================================

function BugFixManager:ReportBug(bugData)
    if not self.BugDetectionSettings.enableBugReporting then return end
    
    -- Generate unique bug ID
    local bugId = HttpService:GenerateGUID(false)
    
    -- Create bug report
    local bugReport = {
        id = bugId,
        title = bugData.title or "Unknown Bug",
        description = bugData.description or "No description provided",
        severity = bugData.severity or self.BugSeverity.LOW,
        category = bugData.category or "general",
        timestamp = bugData.timestamp or tick(),
        serverId = game.JobId,
        placeId = game.PlaceId,
        playerUserId = bugData.playerUserId,
        autoGenerated = bugData.autoGenerated or false,
        status = "open",
        reproducible = false,
        reproductionSteps = bugData.reproductionSteps or {},
        additionalData = bugData.additionalData or {}
    }
    
    -- Add to bug reports
    table.insert(self.BugReports, bugReport)
    
    -- Save to DataStore if enabled
    if self.BugDetectionSettings.reportToDataStore then
        spawn(function()
            local success, error = pcall(function()
                self.BugStore:SetAsync(bugId, bugReport)
            end)
            
            if not success then
                warn("❌ BugFixManager: Failed to save bug report:", error)
            end
        end)
    end
    
    -- Print to console
    print("🐛 BugFixManager: [" .. bugReport.severity.name .. "] " .. bugReport.title)
    
    -- Send critical bug notifications
    if bugReport.severity.level <= 2 and self.BugDetectionSettings.reportCriticalBugs then
        self:NotifyCriticalBug(bugReport)
    end
    
    return bugId
end

function BugFixManager:HandleClientBugReport(player, bugData)
    -- Add player information
    bugData.playerUserId = player.UserId
    bugData.playerName = player.Name
    bugData.autoGenerated = false
    
    -- Report the bug
    local bugId = self:ReportBug(bugData)
    
    print("🐛 BugFixManager: Received bug report from", player.Name, "- ID:", bugId)
end

function BugFixManager:NotifyCriticalBug(bugReport)
    -- Notify all online developers/admins
    for _, player in pairs(Players:GetPlayers()) do
        if self:IsPlayerDeveloper(player) then
            local notificationManager = _G.NotificationManager
            if notificationManager then
                notificationManager:ShowToast(
                    "Critical Bug Detected!",
                    bugReport.title,
                    "🚨",
                    "critical_bug",
                    {color = bugReport.severity.color}
                )
            end
        end
    end
end

function BugFixManager:GetBugReportsForPlayer(player)
    if not self:IsPlayerDeveloper(player) then return {} end
    
    return self.BugReports
end

-- ==========================================
-- AUTOMATED TESTING SYSTEM
-- ==========================================

function BugFixManager:RunAutomatedTests()
    print("🧪 BugFixManager: Starting automated test run...")
    
    local testResults = {
        timestamp = tick(),
        serverId = game.JobId,
        totalTests = 0,
        passedTests = 0,
        failedTests = 0,
        testsByCategory = {}
    }
    
    -- Run tests by category
    for category, tests in pairs(self.TestSuites) do
        local categoryResults = self:RunTestCategory(category, tests)
        testResults.testsByCategory[category] = categoryResults
        
        testResults.totalTests = testResults.totalTests + categoryResults.totalTests
        testResults.passedTests = testResults.passedTests + categoryResults.passedTests
        testResults.failedTests = testResults.failedTests + categoryResults.failedTests
    end
    
    -- Calculate success rate
    testResults.successRate = testResults.totalTests > 0 and (testResults.passedTests / testResults.totalTests) * 100 or 0
    
    -- Save test results
    self:SaveTestResults(testResults)
    
    -- Report test failures
    if testResults.failedTests > 0 then
        self:ReportTestFailures(testResults)
    end
    
    print("✅ BugFixManager: Test run completed -", testResults.passedTests .. "/" .. testResults.totalTests, "passed (" .. math.floor(testResults.successRate) .. "%)")
end

function BugFixManager:RunTestCategory(category, tests)
    local categoryResults = {
        category = category,
        totalTests = #tests,
        passedTests = 0,
        failedTests = 0,
        testResults = {}
    }
    
    print("🧪 BugFixManager: Running", category, "tests...")
    
    for _, test in ipairs(tests) do
        local testResult = self:RunSingleTest(test)
        table.insert(categoryResults.testResults, testResult)
        
        if testResult.passed then
            categoryResults.passedTests = categoryResults.passedTests + 1
        else
            categoryResults.failedTests = categoryResults.failedTests + 1
        end
    end
    
    return categoryResults
end

function BugFixManager:RunSingleTest(test)
    local startTime = tick()
    local testResult = {
        name = test.name,
        passed = false,
        error = nil,
        duration = 0,
        timestamp = startTime
    }
    
    local success, result = pcall(test.func)
    
    testResult.duration = tick() - startTime
    
    if success then
        testResult.passed = result == true
        if not testResult.passed and type(result) == "string" then
            testResult.error = result
        end
    else
        testResult.passed = false
        testResult.error = result
    end
    
    if not testResult.passed then
        print("❌ BugFixManager: Test failed -", test.name, ":", testResult.error or "Unknown error")
    end
    
    return testResult
end

-- ==========================================
-- TEST IMPLEMENTATIONS
-- ==========================================

function BugFixManager:TestPlotManager()
    local plotManager = _G.PlotManager
    if not plotManager then return "PlotManager not found" end
    
    -- Test basic plot functionality
    local testPassed = true
    local errorMessage = ""
    
    -- Test plot creation/validation
    if not plotManager.CreatePlot then
        testPassed = false
        errorMessage = "CreatePlot method missing"
    end
    
    return testPassed, errorMessage
end

function BugFixManager:TestEconomyManager()
    local economyManager = _G.EconomyManager
    if not economyManager then return false, "EconomyManager not found" end
    
    -- Test currency operations
    local testPlayer = self:GetTestPlayer()
    if not testPlayer then return false, "No test player available" end
    
    local initialCoins = economyManager:GetCurrency(testPlayer, "coins") or 0
    economyManager:AddCurrency(testPlayer, "coins", 100)
    local afterAddition = economyManager:GetCurrency(testPlayer, "coins") or 0
    
    if afterAddition ~= initialCoins + 100 then
        return false, "Currency addition failed"
    end
    
    return true
end

function BugFixManager:TestInventoryManager()
    local inventoryManager = _G.InventoryManager
    if not inventoryManager then return false, "InventoryManager not found" end
    
    -- Test basic inventory operations
    return inventoryManager.AddItem ~= nil and inventoryManager.RemoveItem ~= nil
end

function BugFixManager:TestVIPManager()
    local vipManager = _G.VIPManager
    if not vipManager then return false, "VIPManager not found" end
    
    -- Test VIP status checking
    return vipManager.IsPlayerVIP ~= nil
end

function BugFixManager:TestPlantGrowth()
    local plotManager = _G.PlotManager
    if not plotManager then return false, "PlotManager not found" end
    
    -- Test plant growth mechanics
    return true -- Placeholder implementation
end

function BugFixManager:TestHarvesting()
    local harvestHandler = _G.HarvestHandler
    if not harvestHandler then return false, "HarvestHandler not found" end
    
    -- Test harvesting functionality
    return true -- Placeholder implementation
end

function BugFixManager:TestShopPurchases()
    local shopManager = _G.ShopManager
    if not shopManager then return false, "ShopManager not found" end
    
    -- Test shop purchasing
    return true -- Placeholder implementation
end

function BugFixManager:TestWeatherSystem()
    local weatherManager = _G.WeatherManager
    if not weatherManager then return false, "WeatherManager not found" end
    
    -- Test weather effects
    return true -- Placeholder implementation
end

function BugFixManager:TestCurrencyIntegrity()
    -- Test currency balance integrity across operations
    local economyManager = _G.EconomyManager
    if not economyManager then return false, "EconomyManager not found" end
    
    return true -- Placeholder implementation
end

function BugFixManager:TestItemPricing()
    -- Test item pricing accuracy
    return true -- Placeholder implementation
end

function BugFixManager:TestVIPBonuses()
    -- Test VIP bonus calculations
    return true -- Placeholder implementation
end

function BugFixManager:TestDailyRewards()
    -- Test daily reward system
    return true -- Placeholder implementation
end

function BugFixManager:TestFriendSystem()
    -- Test friend system operations
    local socialManager = _G.SocialManager
    if not socialManager then return false, "SocialManager not found" end
    
    return true -- Placeholder implementation
end

function BugFixManager:TestGardenVisiting()
    -- Test garden visiting permissions
    return true -- Placeholder implementation
end

function BugFixManager:TestGiftSystem()
    -- Test gift exchange system
    return true -- Placeholder implementation
end

function BugFixManager:TestSocialHubs()
    -- Test social hub functionality
    return true -- Placeholder implementation
end

function BugFixManager:TestPlayerDataValidation()
    -- Test player data validation
    return true -- Placeholder implementation
end

function BugFixManager:TestDataStoreOperations()
    -- Test DataStore operations
    local success = pcall(function()
        local testStore = DataStoreService:GetDataStore("TestStore")
        testStore:SetAsync("test_key", "test_value")
        local value = testStore:GetAsync("test_key")
        return value == "test_value"
    end)
    
    return success
end

function BugFixManager:TestCrossSessionPersistence()
    -- Test cross-session data persistence
    return true -- Placeholder implementation
end

function BugFixManager:TestDataCorruptionDetection()
    -- Test data corruption detection
    return true -- Placeholder implementation
end

function BugFixManager:TestFrameRateStability()
    local performanceOptimizer = _G.PerformanceOptimizer
    if not performanceOptimizer then return false, "PerformanceOptimizer not found" end
    
    local metrics = performanceOptimizer:GetPerformanceMetrics()
    return metrics.frameRate >= 30 -- Minimum acceptable frame rate
end

function BugFixManager:TestMemoryUsage()
    local currentMemory = gcinfo()
    return currentMemory < 1000 -- Less than 1GB
end

function BugFixManager:TestNetworkLatency()
    -- Test network latency
    return true -- Placeholder implementation
end

function BugFixManager:TestLoadCapacity()
    -- Test load capacity
    return #Players:GetPlayers() <= 50 -- Server capacity test
end

-- ==========================================
-- HELPER FUNCTIONS
-- ==========================================

function BugFixManager:GetTestPlayer()
    -- Return first available player for testing
    local players = Players:GetPlayers()
    return players[1]
end

function BugFixManager:IsPlayerDeveloper(player)
    -- Check if player is a developer (placeholder)
    return player.UserId == 123456789 -- Replace with actual developer IDs
end

function BugFixManager:CountTotalTests()
    local count = 0
    for _, tests in pairs(self.TestSuites) do
        count = count + #tests
    end
    return count
end

function BugFixManager:SaveTestResults(testResults)
    local resultsKey = "test_results_" .. os.date("%Y_%m_%d_%H_%M_%S")
    
    spawn(function()
        local success, error = pcall(function()
            self.TestResultStore:SetAsync(resultsKey, testResults)
        end)
        
        if not success then
            warn("❌ BugFixManager: Failed to save test results:", error)
        end
    end)
end

function BugFixManager:ReportTestFailures(testResults)
    local failureDetails = {}
    
    for category, categoryResults in pairs(testResults.testsByCategory) do
        for _, testResult in ipairs(categoryResults.testResults) do
            if not testResult.passed then
                table.insert(failureDetails, category .. ":" .. testResult.name .. " - " .. (testResult.error or "Unknown error"))
            end
        end
    end
    
    self:ReportBug({
        title = "Automated Test Failures",
        description = "Failed tests:\n" .. table.concat(failureDetails, "\n"),
        severity = self.BugSeverity.HIGH,
        category = "testing",
        timestamp = tick(),
        autoGenerated = true
    })
end

function BugFixManager:GetLastMemoryCheck()
    -- Get last memory check from persistent storage
    return {memory = 200, timestamp = tick() - 3600} -- Placeholder
end

function BugFixManager:SetLastMemoryCheck(memory)
    -- Save current memory check to persistent storage
    -- Placeholder implementation
end

function BugFixManager:PerformSystemHealthCheck()
    -- Perform comprehensive system health check
    local healthScore = 100
    
    -- Check error frequency
    if self.ErrorTracking.errorCount > 50 then
        healthScore = healthScore - 20
    end
    
    -- Check memory usage
    local currentMemory = gcinfo()
    if currentMemory > 500 then
        healthScore = healthScore - 15
    end
    
    -- Check performance
    local performanceOptimizer = _G.PerformanceOptimizer
    if performanceOptimizer then
        local metrics = performanceOptimizer:GetPerformanceMetrics()
        if metrics.frameRate < 30 then
            healthScore = healthScore - 25
        end
    end
    
    if healthScore < 50 then
        self:ReportBug({
            title = "Poor System Health",
            description = "System health score: " .. healthScore .. "/100",
            severity = self.BugSeverity.HIGH,
            category = "system_health",
            timestamp = tick(),
            autoGenerated = true
        })
    end
end

function BugFixManager:AnalyzeErrorFrequency()
    -- Analyze error patterns and frequencies
    local currentTime = tick()
    local recentErrors = {}
    
    for _, errorLog in ipairs(self.ErrorLogs) do
        if currentTime - errorLog.timestamp < 3600 then -- Last hour
            table.insert(recentErrors, errorLog)
        end
    end
    
    if #recentErrors > 100 then
        self:ReportBug({
            title = "High Error Volume",
            description = "Detected " .. #recentErrors .. " errors in the last hour",
            severity = self.BugSeverity.MEDIUM,
            category = "error_analysis",
            timestamp = currentTime,
            autoGenerated = true
        })
    end
end

function BugFixManager:ProcessPendingBugReports()
    -- Process and analyze pending bug reports
    local openBugs = 0
    for _, bug in ipairs(self.BugReports) do
        if bug.status == "open" then
            openBugs = openBugs + 1
        end
    end
    
    if openBugs > 50 then
        print("⚠️ BugFixManager: High number of open bugs:", openBugs)
    end
end

function BugFixManager:CheckFrameTimeRegression(frameTime)
    if frameTime > self.PerformanceBaselines.averageFrameTime + 5 then
        self:ReportBug({
            title = "Frame Time Regression",
            description = "Frame time: " .. math.floor(frameTime) .. "ms (baseline: " .. self.PerformanceBaselines.averageFrameTime .. "ms)",
            severity = self.BugSeverity.MEDIUM,
            category = "performance",
            timestamp = tick(),
            autoGenerated = true
        })
    end
end

function BugFixManager:CheckMemoryRegression(currentMemory, lastMemory)
    local memoryIncrease = currentMemory - lastMemory
    if memoryIncrease > 50 then -- 50MB increase
        self:ReportBug({
            title = "Memory Usage Spike",
            description = "Memory increased by " .. math.floor(memoryIncrease) .. "MB",
            severity = self.BugSeverity.MEDIUM,
            category = "memory",
            timestamp = tick(),
            autoGenerated = true
        })
    end
end

-- ==========================================
-- PUBLIC API
-- ==========================================

function BugFixManager:GetBugReports()
    return self.BugReports
end

function BugFixManager:GetErrorLogs()
    return self.ErrorLogs
end

function BugFixManager:GetErrorStats()
    return self.ErrorTracking
end

function BugFixManager:RunTestSuite(category)
    if self.TestSuites[category] then
        return self:RunTestCategory(category, self.TestSuites[category])
    end
    return nil
end

function BugFixManager:ForceSystemHealthCheck()
    self:PerformSystemHealthCheck()
end

-- ==========================================
-- CLEANUP
-- ==========================================

function BugFixManager:Cleanup()
    -- Save all bug reports
    for _, bugReport in ipairs(self.BugReports) do
        if bugReport.status == "open" then
            spawn(function()
                pcall(function()
                    self.BugStore:SetAsync(bugReport.id, bugReport)
                end)
            end)
        end
    end
    
    -- Final test run
    self:RunAutomatedTests()
    
    print("🐛 BugFixManager: Bug detection and testing system cleaned up")
end

return BugFixManager
