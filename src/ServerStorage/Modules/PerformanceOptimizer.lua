--[[
    PerformanceOptimizer.lua
    Server-Side Performance Optimization and Resource Management System
    
    Priority: 36 (Polish & Optimization phase)
    Dependencies: All game systems for optimization
    Used by: All managers for performance monitoring and optimization
    
    Features:
    - Memory management and garbage collection
    - Object pooling for frequently created objects
    - Network optimization and batching
    - Frame rate optimization
    - Database query optimization
    - Client-server communication optimization
    - Resource loading optimization
    - Automated performance monitoring
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ContentProvider = game:GetService("ContentProvider")

-- Load required modules
local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)

local PerformanceOptimizer = {}
PerformanceOptimizer.__index = PerformanceOptimizer

-- ==========================================
-- INITIALIZATION & SETUP
-- ==========================================

-- Performance monitoring
PerformanceOptimizer.PerformanceMetrics = {
    frameRate = 60,
    memoryUsage = 0,
    networkLatency = 0,
    scriptExecutionTime = 0,
    dataStoreCallCount = 0,
    objectCount = 0,
    lastOptimization = 0
}

-- Object pools for frequently created objects
PerformanceOptimizer.ObjectPools = {
    particles = {},
    effects = {},
    coins = {},
    notifications = {},
    plants = {},
    decorations = {}
}

-- Network optimization
PerformanceOptimizer.NetworkBatches = {
    playerUpdates = {},
    gardenUpdates = {},
    economyUpdates = {},
    socialUpdates = {}
}

-- Performance optimization settings
PerformanceOptimizer.OptimizationSettings = {
    -- Memory management
    maxMemoryUsage = 500, -- MB
    garbageCollectionInterval = 30, -- seconds
    objectPoolSizes = {
        particles = 100,
        effects = 50,
        coins = 200,
        notifications = 30,
        plants = 500,
        decorations = 200
    },
    
    -- Network optimization
    batchUpdateInterval = 0.1, -- seconds
    maxBatchSize = 50,
    compressionEnabled = true,
    
    -- Performance targets
    targetFrameRate = 60,
    maxScriptExecutionTime = 16, -- ms (60 FPS = 16.67ms per frame)
    
    -- DataStore optimization
    maxDataStoreCallsPerMinute = 60,
    dataStoreBatchSize = 10,
    cacheExpirationTime = 300, -- 5 minutes
    
    -- Client optimization
    renderDistance = 500,
    maxVisiblePlants = 200,
    particleLimit = 100,
    effectLimit = 50
}

-- Performance cache
PerformanceOptimizer.Cache = {
    dataStoreCache = {}, -- [key] = {data, timestamp}
    playerDataCache = {}, -- [userId] = {data, timestamp}
    gardenDataCache = {}, -- [plotId] = {data, timestamp}
    assetCache = {} -- [assetId] = {asset, timestamp}
}

-- Resource preloading
PerformanceOptimizer.PreloadAssets = {
    -- Plant models
    "rbxassetid://123456789", -- Carrot
    "rbxassetid://123456790", -- Tomato
    "rbxassetid://123456791", -- Corn
    "rbxassetid://123456792", -- Pumpkin
    
    -- Effect assets
    "rbxassetid://123456800", -- Harvest particles
    "rbxassetid://123456801", -- Plant growth effect
    "rbxassetid://123456802", -- Coin pickup effect
    
    -- UI assets
    "rbxassetid://123456810", -- Button textures
    "rbxassetid://123456811", -- Background images
    "rbxassetid://123456812", -- Icon atlas
    
    -- Audio assets
    "rbxassetid://123456820", -- Plant sound
    "rbxassetid://123456821", -- Harvest sound
    "rbxassetid://123456822", -- UI click sound
}

-- ==========================================
-- INITIALIZATION
-- ==========================================

function PerformanceOptimizer:Initialize()
    print("⚡ PerformanceOptimizer: Initializing performance optimization system...")
    
    -- Set up performance monitoring
    self:SetupPerformanceMonitoring()
    
    -- Initialize object pools
    self:InitializeObjectPools()
    
    -- Set up network optimization
    self:SetupNetworkOptimization()
    
    -- Start memory management
    self:StartMemoryManagement()
    
    -- Preload critical assets
    self:PreloadCriticalAssets()
    
    -- Set up DataStore optimization
    self:SetupDataStoreOptimization()
    
    -- Start performance optimization loops
    self:StartOptimizationLoops()
    
    print("✅ PerformanceOptimizer: Performance optimization system initialized")
end

function PerformanceOptimizer:SetupPerformanceMonitoring()
    -- Monitor frame rate
    RunService.Heartbeat:Connect(function(deltaTime)
        self.PerformanceMetrics.frameRate = 1 / deltaTime
        self:CheckPerformanceThresholds()
    end)
    
    -- Monitor memory usage
    spawn(function()
        while true do
            self.PerformanceMetrics.memoryUsage = gcinfo()
            self:CheckMemoryUsage()
            wait(5)
        end
    end)
    
    -- Monitor script execution time
    self:SetupScriptProfiler()
end

function PerformanceOptimizer:SetupScriptProfiler()
    local scriptStartTime = 0
    
    RunService.PreSimulation:Connect(function()
        scriptStartTime = tick()
    end)
    
    RunService.PostSimulation:Connect(function()
        self.PerformanceMetrics.scriptExecutionTime = (tick() - scriptStartTime) * 1000
    end)
end

function PerformanceOptimizer:InitializeObjectPools()
    for poolName, poolSize in pairs(self.OptimizationSettings.objectPoolSizes) do
        self.ObjectPools[poolName] = {}
        
        -- Pre-create objects for the pool
        for i = 1, poolSize do
            local obj = self:CreatePooledObject(poolName)
            if obj then
                obj.Parent = nil -- Keep objects out of workspace until needed
                table.insert(self.ObjectPools[poolName], obj)
            end
        end
        
        print("⚡ PerformanceOptimizer: Initialized", poolName, "pool with", poolSize, "objects")
    end
end

function PerformanceOptimizer:CreatePooledObject(objectType)
    if objectType == "particles" then
        local attachment = Instance.new("Attachment")
        local particles = Instance.new("ParticleEmitter")
        particles.Parent = attachment
        particles.Enabled = false
        return attachment
        
    elseif objectType == "effects" then
        local part = Instance.new("Part")
        part.Size = Vector3.new(1, 1, 1)
        part.Transparency = 1
        part.CanCollide = false
        part.Anchored = true
        return part
        
    elseif objectType == "coins" then
        local coin = Instance.new("Part")
        coin.Name = "Coin"
        coin.Shape = Enum.PartType.Ball
        coin.Size = Vector3.new(0.5, 0.5, 0.5)
        coin.Color = Color3.fromRGB(255, 215, 0)
        coin.CanCollide = false
        
        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        bodyVelocity.Parent = coin
        
        return coin
        
    elseif objectType == "notifications" then
        local gui = Instance.new("BillboardGui")
        gui.Size = UDim2.new(4, 0, 2, 0)
        gui.StudsOffset = Vector3.new(0, 3, 0)
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.TextScaled = true
        label.Font = Enum.Font.GothamBold
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.Parent = gui
        
        return gui
        
    elseif objectType == "plants" then
        local plantModel = Instance.new("Model")
        plantModel.Name = "Plant"
        
        local stem = Instance.new("Part")
        stem.Name = "Stem"
        stem.Size = Vector3.new(0.2, 1, 0.2)
        stem.Color = Color3.fromRGB(34, 139, 34)
        stem.Parent = plantModel
        
        return plantModel
        
    elseif objectType == "decorations" then
        local decoration = Instance.new("Part")
        decoration.Name = "Decoration"
        decoration.Size = Vector3.new(2, 2, 2)
        decoration.CanCollide = false
        decoration.Anchored = true
        
        return decoration
    end
    
    return nil
end

function PerformanceOptimizer:SetupNetworkOptimization()
    -- Set up remote events for batched updates
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then
        remoteEvents = Instance.new("Folder")
        remoteEvents.Name = "RemoteEvents"
        remoteEvents.Parent = ReplicatedStorage
    end
    
    -- Batched update remote
    local batchUpdateRemote = Instance.new("RemoteEvent")
    batchUpdateRemote.Name = "BatchedUpdates"
    batchUpdateRemote.Parent = remoteEvents
    
    -- Start batch processing
    spawn(function()
        while true do
            self:ProcessNetworkBatches()
            wait(self.OptimizationSettings.batchUpdateInterval)
        end
    end)
end

function PerformanceOptimizer:StartMemoryManagement()
    spawn(function()
        while true do
            self:PerformGarbageCollection()
            self:CleanupUnusedObjects()
            self:OptimizeCache()
            wait(self.OptimizationSettings.garbageCollectionInterval)
        end
    end)
end

function PerformanceOptimizer:PreloadCriticalAssets()
    spawn(function()
        print("⚡ PerformanceOptimizer: Preloading critical assets...")
        
        local assetsToPreload = {}
        for _, assetId in ipairs(self.PreloadAssets) do
            table.insert(assetsToPreload, assetId)
        end
        
        local success, failedAssets = pcall(function()
            ContentProvider:PreloadAsync(assetsToPreload)
        end)
        
        if success then
            print("✅ PerformanceOptimizer: Preloaded", #assetsToPreload, "assets successfully")
        else
            warn("❌ PerformanceOptimizer: Failed to preload some assets:", failedAssets)
        end
    end)
end

function PerformanceOptimizer:SetupDataStoreOptimization()
    -- Create cache management
    spawn(function()
        while true do
            self:CleanupExpiredCache()
            wait(60) -- Check every minute
        end
    end)
    
    -- Batch DataStore operations
    spawn(function()
        while true do
            self:ProcessDataStoreBatches()
            wait(1) -- Process batches every second
        end
    end)
end

function PerformanceOptimizer:StartOptimizationLoops()
    -- Main optimization loop
    spawn(function()
        while true do
            self:PerformOptimizationPass()
            wait(10) -- Run optimization every 10 seconds
        end
    end)
    
    -- Client-specific optimizations
    spawn(function()
        while true do
            self:OptimizeClientPerformance()
            wait(5) -- Update client optimizations every 5 seconds
        end
    end)
end

-- ==========================================
-- OBJECT POOLING
-- ==========================================

function PerformanceOptimizer:GetPooledObject(objectType)
    local pool = self.ObjectPools[objectType]
    if not pool or #pool == 0 then
        -- Create new object if pool is empty
        return self:CreatePooledObject(objectType)
    end
    
    -- Return object from pool
    local obj = table.remove(pool, #pool)
    return obj
end

function PerformanceOptimizer:ReturnPooledObject(objectType, obj)
    local pool = self.ObjectPools[objectType]
    if not pool then return end
    
    -- Reset object properties
    self:ResetPooledObject(objectType, obj)
    
    -- Return to pool if not at capacity
    if #pool < self.OptimizationSettings.objectPoolSizes[objectType] then
        obj.Parent = nil
        table.insert(pool, obj)
    else
        -- Destroy excess objects
        obj:Destroy()
    end
end

function PerformanceOptimizer:ResetPooledObject(objectType, obj)
    if objectType == "particles" then
        local particles = obj:FindFirstChild("ParticleEmitter")
        if particles then
            particles.Enabled = false
        end
        
    elseif objectType == "effects" then
        obj.CFrame = CFrame.new(0, -1000, 0) -- Move out of view
        obj.Transparency = 1
        
    elseif objectType == "coins" then
        obj.CFrame = CFrame.new(0, -1000, 0)
        local bodyVelocity = obj:FindFirstChild("BodyVelocity")
        if bodyVelocity then
            bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        end
        
    elseif objectType == "notifications" then
        local label = obj:FindFirstChild("TextLabel")
        if label then
            label.Text = ""
            label.TextTransparency = 0
        end
        obj.StudsOffset = Vector3.new(0, 3, 0)
        
    elseif objectType == "plants" then
        obj.PrimaryPart = obj:FindFirstChild("Stem")
        if obj.PrimaryPart then
            obj:SetPrimaryPartCFrame(CFrame.new(0, -1000, 0))
        end
        
    elseif objectType == "decorations" then
        obj.CFrame = CFrame.new(0, -1000, 0)
        obj.Transparency = 0
    end
end

-- ==========================================
-- NETWORK OPTIMIZATION
-- ==========================================

function PerformanceOptimizer:QueueNetworkUpdate(updateType, data)
    local batch = self.NetworkBatches[updateType]
    if not batch then
        self.NetworkBatches[updateType] = {}
        batch = self.NetworkBatches[updateType]
    end
    
    table.insert(batch, data)
    
    -- Process immediately if batch is full
    if #batch >= self.OptimizationSettings.maxBatchSize then
        self:ProcessNetworkBatch(updateType)
    end
end

function PerformanceOptimizer:ProcessNetworkBatches()
    for updateType, batch in pairs(self.NetworkBatches) do
        if #batch > 0 then
            self:ProcessNetworkBatch(updateType)
        end
    end
end

function PerformanceOptimizer:ProcessNetworkBatch(updateType)
    local batch = self.NetworkBatches[updateType]
    if not batch or #batch == 0 then return end
    
    -- Compress data if enabled
    local batchData = batch
    if self.OptimizationSettings.compressionEnabled then
        batchData = self:CompressBatchData(batch)
    end
    
    -- Send to all clients
    local remoteEvent = ReplicatedStorage.RemoteEvents:FindFirstChild("BatchedUpdates")
    if remoteEvent then
        remoteEvent:FireAllClients(updateType, batchData)
    end
    
    -- Clear batch
    self.NetworkBatches[updateType] = {}
    
    print("⚡ PerformanceOptimizer: Processed", #batch, updateType, "updates")
end

function PerformanceOptimizer:CompressBatchData(data)
    -- Simple compression by grouping similar updates
    local compressed = {}
    local grouped = {}
    
    for _, update in ipairs(data) do
        local key = update.type .. "_" .. (update.id or "global")
        if not grouped[key] then
            grouped[key] = {}
        end
        table.insert(grouped[key], update)
    end
    
    -- Merge similar updates
    for key, updates in pairs(grouped) do
        if #updates == 1 then
            table.insert(compressed, updates[1])
        else
            -- Merge multiple updates of same type
            local merged = self:MergeUpdates(updates)
            table.insert(compressed, merged)
        end
    end
    
    return compressed
end

function PerformanceOptimizer:MergeUpdates(updates)
    if #updates == 0 then return nil end
    
    local merged = updates[1]
    for i = 2, #updates do
        local update = updates[i]
        -- Merge properties
        for key, value in pairs(update.data or {}) do
            merged.data[key] = value
        end
        merged.timestamp = math.max(merged.timestamp or 0, update.timestamp or 0)
    end
    
    return merged
end

-- ==========================================
-- MEMORY MANAGEMENT
-- ==========================================

function PerformanceOptimizer:CheckMemoryUsage()
    local memoryUsage = self.PerformanceMetrics.memoryUsage
    local maxMemory = self.OptimizationSettings.maxMemoryUsage
    
    if memoryUsage > maxMemory then
        print("⚠️ PerformanceOptimizer: High memory usage detected:", memoryUsage, "MB")
        self:PerformEmergencyCleanup()
    elseif memoryUsage > maxMemory * 0.8 then
        print("⚠️ PerformanceOptimizer: Memory usage warning:", memoryUsage, "MB")
        self:PerformGarbageCollection()
    end
end

function PerformanceOptimizer:PerformGarbageCollection()
    local beforeMemory = gcinfo()
    
    -- Force garbage collection
    collectgarbage("collect")
    
    local afterMemory = gcinfo()
    local freed = beforeMemory - afterMemory
    
    if freed > 10 then -- Only log if significant memory was freed
        print("⚡ PerformanceOptimizer: Garbage collection freed", math.floor(freed), "MB")
    end
end

function PerformanceOptimizer:PerformEmergencyCleanup()
    print("🚨 PerformanceOptimizer: Performing emergency cleanup...")
    
    -- Clear all caches
    self.Cache.dataStoreCache = {}
    self.Cache.playerDataCache = {}
    self.Cache.gardenDataCache = {}
    self.Cache.assetCache = {}
    
    -- Clean up object pools
    for poolName, pool in pairs(self.ObjectPools) do
        local originalSize = #pool
        local targetSize = math.floor(self.OptimizationSettings.objectPoolSizes[poolName] * 0.5)
        
        while #pool > targetSize do
            local obj = table.remove(pool)
            if obj then
                obj:Destroy()
            end
        end
        
        print("⚡ PerformanceOptimizer: Reduced", poolName, "pool from", originalSize, "to", #pool)
    end
    
    -- Force garbage collection
    self:PerformGarbageCollection()
    
    print("✅ PerformanceOptimizer: Emergency cleanup completed")
end

function PerformanceOptimizer:CleanupUnusedObjects()
    -- Clean up orphaned objects in workspace
    local workspace = game.Workspace
    local cleanupCount = 0
    
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj.Name == "TempObject" or obj.Name:find("Cleanup") then
            obj:Destroy()
            cleanupCount = cleanupCount + 1
        end
    end
    
    if cleanupCount > 0 then
        print("⚡ PerformanceOptimizer: Cleaned up", cleanupCount, "unused objects")
    end
end

-- ==========================================
-- CACHE OPTIMIZATION
-- ==========================================

function PerformanceOptimizer:OptimizeCache()
    local currentTime = tick()
    local expiredCount = 0
    
    -- Clean up expired cache entries
    for cacheType, cache in pairs(self.Cache) do
        for key, entry in pairs(cache) do
            if entry.timestamp and currentTime - entry.timestamp > self.OptimizationSettings.cacheExpirationTime then
                cache[key] = nil
                expiredCount = expiredCount + 1
            end
        end
    end
    
    if expiredCount > 0 then
        print("⚡ PerformanceOptimizer: Cleaned up", expiredCount, "expired cache entries")
    end
end

function PerformanceOptimizer:CleanupExpiredCache()
    local currentTime = tick()
    local totalCleaned = 0
    
    for cacheType, cache in pairs(self.Cache) do
        local cleaned = 0
        for key, entry in pairs(cache) do
            if entry.timestamp and currentTime - entry.timestamp > self.OptimizationSettings.cacheExpirationTime then
                cache[key] = nil
                cleaned = cleaned + 1
            end
        end
        totalCleaned = totalCleaned + cleaned
    end
    
    if totalCleaned > 0 then
        print("⚡ PerformanceOptimizer: Cache cleanup removed", totalCleaned, "expired entries")
    end
end

function PerformanceOptimizer:GetCachedData(cacheType, key)
    local cache = self.Cache[cacheType]
    if not cache then return nil end
    
    local entry = cache[key]
    if not entry then return nil end
    
    -- Check if expired
    local currentTime = tick()
    if entry.timestamp and currentTime - entry.timestamp > self.OptimizationSettings.cacheExpirationTime then
        cache[key] = nil
        return nil
    end
    
    return entry.data
end

function PerformanceOptimizer:SetCachedData(cacheType, key, data)
    local cache = self.Cache[cacheType]
    if not cache then
        self.Cache[cacheType] = {}
        cache = self.Cache[cacheType]
    end
    
    cache[key] = {
        data = data,
        timestamp = tick()
    }
end

-- ==========================================
-- PERFORMANCE MONITORING
-- ==========================================

function PerformanceOptimizer:CheckPerformanceThresholds()
    local metrics = self.PerformanceMetrics
    local settings = self.OptimizationSettings
    
    -- Check frame rate
    if metrics.frameRate < settings.targetFrameRate * 0.8 then
        self:HandleLowFrameRate()
    end
    
    -- Check script execution time
    if metrics.scriptExecutionTime > settings.maxScriptExecutionTime then
        self:HandleHighScriptTime()
    end
    
    -- Update object count
    metrics.objectCount = #game.Workspace:GetDescendants()
end

function PerformanceOptimizer:HandleLowFrameRate()
    print("⚠️ PerformanceOptimizer: Low frame rate detected:", self.PerformanceMetrics.frameRate)
    
    -- Reduce visual effects
    self:ReduceVisualEffects()
    
    -- Optimize render distance
    self:OptimizeRenderDistance()
    
    -- Clean up unnecessary objects
    self:CleanupUnusedObjects()
end

function PerformanceOptimizer:HandleHighScriptTime()
    print("⚠️ PerformanceOptimizer: High script execution time:", self.PerformanceMetrics.scriptExecutionTime, "ms")
    
    -- Spread operations across multiple frames
    self:EnableFrameSpreadOptimization()
end

function PerformanceOptimizer:ReduceVisualEffects()
    -- Reduce particle limits
    local originalParticleLimit = self.OptimizationSettings.particleLimit
    self.OptimizationSettings.particleLimit = math.floor(originalParticleLimit * 0.7)
    
    -- Reduce effect limits
    local originalEffectLimit = self.OptimizationSettings.effectLimit
    self.OptimizationSettings.effectLimit = math.floor(originalEffectLimit * 0.7)
    
    print("⚡ PerformanceOptimizer: Reduced visual effects limits")
end

function PerformanceOptimizer:OptimizeRenderDistance()
    local originalDistance = self.OptimizationSettings.renderDistance
    self.OptimizationSettings.renderDistance = originalDistance * 0.8
    
    print("⚡ PerformanceOptimizer: Reduced render distance to", self.OptimizationSettings.renderDistance)
end

function PerformanceOptimizer:EnableFrameSpreadOptimization()
    -- This would implement frame spreading for heavy operations
    print("⚡ PerformanceOptimizer: Enabled frame spread optimization")
end

-- ==========================================
-- CLIENT OPTIMIZATION
-- ==========================================

function PerformanceOptimizer:OptimizeClientPerformance()
    -- Send optimization settings to clients
    local optimizationData = {
        renderDistance = self.OptimizationSettings.renderDistance,
        maxVisiblePlants = self.OptimizationSettings.maxVisiblePlants,
        particleLimit = self.OptimizationSettings.particleLimit,
        effectLimit = self.OptimizationSettings.effectLimit
    }
    
    -- Send to all clients
    local remoteEvent = ReplicatedStorage.RemoteEvents:FindFirstChild("OptimizationSettings")
    if not remoteEvent then
        remoteEvent = Instance.new("RemoteEvent")
        remoteEvent.Name = "OptimizationSettings"
        remoteEvent.Parent = ReplicatedStorage.RemoteEvents
    end
    
    remoteEvent:FireAllClients(optimizationData)
end

-- ==========================================
-- DATASTORE OPTIMIZATION
-- ==========================================

function PerformanceOptimizer:ProcessDataStoreBatches()
    -- This would implement batched DataStore operations
    -- For now, just monitor call count
    if self.PerformanceMetrics.dataStoreCallCount > self.OptimizationSettings.maxDataStoreCallsPerMinute then
        print("⚠️ PerformanceOptimizer: DataStore call limit approaching")
    end
end

-- ==========================================
-- MAIN OPTIMIZATION PASS
-- ==========================================

function PerformanceOptimizer:PerformOptimizationPass()
    local startTime = tick()
    
    print("⚡ PerformanceOptimizer: Starting optimization pass...")
    
    -- Memory optimization
    self:OptimizeMemoryUsage()
    
    -- Network optimization
    self:OptimizeNetworkUsage()
    
    -- Object optimization
    self:OptimizeObjectCount()
    
    -- Cache optimization
    self:OptimizeCache()
    
    -- Update metrics
    self:UpdatePerformanceMetrics()
    
    local duration = tick() - startTime
    print("✅ PerformanceOptimizer: Optimization pass completed in", math.floor(duration * 1000), "ms")
    
    self.PerformanceMetrics.lastOptimization = tick()
end

function PerformanceOptimizer:OptimizeMemoryUsage()
    if self.PerformanceMetrics.memoryUsage > self.OptimizationSettings.maxMemoryUsage * 0.7 then
        self:PerformGarbageCollection()
    end
end

function PerformanceOptimizer:OptimizeNetworkUsage()
    -- Process any pending network batches
    self:ProcessNetworkBatches()
end

function PerformanceOptimizer:OptimizeObjectCount()
    local objectCount = self.PerformanceMetrics.objectCount
    if objectCount > 10000 then -- Arbitrary threshold
        self:CleanupUnusedObjects()
    end
end

function PerformanceOptimizer:UpdatePerformanceMetrics()
    local metrics = self.PerformanceMetrics
    
    -- Update current metrics
    metrics.memoryUsage = gcinfo()
    metrics.objectCount = #game.Workspace:GetDescendants()
    
    -- Calculate performance score
    local score = 100
    if metrics.frameRate < self.OptimizationSettings.targetFrameRate then
        score = score - (self.OptimizationSettings.targetFrameRate - metrics.frameRate)
    end
    if metrics.memoryUsage > self.OptimizationSettings.maxMemoryUsage then
        score = score - ((metrics.memoryUsage - self.OptimizationSettings.maxMemoryUsage) / 10)
    end
    
    metrics.performanceScore = math.max(score, 0)
end

-- ==========================================
-- PUBLIC API
-- ==========================================

function PerformanceOptimizer:GetPerformanceMetrics()
    return self.PerformanceMetrics
end

function PerformanceOptimizer:GetOptimizationSettings()
    return self.OptimizationSettings
end

function PerformanceOptimizer:UpdateOptimizationSetting(setting, value)
    if self.OptimizationSettings[setting] ~= nil then
        self.OptimizationSettings[setting] = value
        print("⚡ PerformanceOptimizer: Updated", setting, "to", value)
    end
end

function PerformanceOptimizer:ForceOptimization()
    self:PerformOptimizationPass()
end

function PerformanceOptimizer:GetCacheStats()
    local stats = {}
    for cacheType, cache in pairs(self.Cache) do
        local count = 0
        for _ in pairs(cache) do
            count = count + 1
        end
        stats[cacheType] = count
    end
    return stats
end

function PerformanceOptimizer:GetPoolStats()
    local stats = {}
    for poolName, pool in pairs(self.ObjectPools) do
        stats[poolName] = {
            available = #pool,
            max = self.OptimizationSettings.objectPoolSizes[poolName]
        }
    end
    return stats
end

-- ==========================================
-- CLEANUP
-- ==========================================

function PerformanceOptimizer:Cleanup()
    -- Final optimization pass
    self:PerformOptimizationPass()
    
    -- Clean up object pools
    for poolName, pool in pairs(self.ObjectPools) do
        for _, obj in ipairs(pool) do
            if obj then
                obj:Destroy()
            end
        end
    end
    
    -- Clear all caches
    for cacheType in pairs(self.Cache) do
        self.Cache[cacheType] = {}
    end
    
    print("⚡ PerformanceOptimizer: Performance optimization system cleaned up")
end

return PerformanceOptimizer
