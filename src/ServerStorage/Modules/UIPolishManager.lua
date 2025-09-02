--[[
    UIPolishManager.lua
    Server-Side UI/UX Polish and Enhancement System
    
    Priority: 38 (Polish & Optimization phase)
    Dependencies: All UI systems for enhancement and polish
    Used by: All game systems for improved user experience
    
    Features:
    - UI animation and transition system
    - Accessibility improvements
    - Mobile optimization
    - Visual feedback enhancement
    - Loading state management
    - Error state handling
    - Responsive design adaptation
    - User preference management
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

-- Load required modules
local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)

local UIPolishManager = {}
UIPolishManager.__index = UIPolishManager

-- ==========================================
-- INITIALIZATION & SETUP
-- ==========================================

-- UI Polish state
UIPolishManager.PlayerUIPreferences = {} -- [userId] = preferences
UIPolishManager.AnimationQueue = {} -- Queued animations
UIPolishManager.LoadingStates = {} -- Active loading states
UIPolishManager.TooltipData = {} -- Tooltip information

-- Data store for UI preferences
UIPolishManager.UIPreferencesStore = DataStoreService:GetDataStore("UIPreferences_v1")

-- Animation presets
UIPolishManager.AnimationPresets = {
    -- Button animations
    button_hover = {
        scaleFactor = 1.05,
        duration = 0.1,
        easingStyle = Enum.EasingStyle.Quad,
        easingDirection = Enum.EasingDirection.Out
    },
    
    button_press = {
        scaleFactor = 0.95,
        duration = 0.05,
        easingStyle = Enum.EasingStyle.Quad,
        easingDirection = Enum.EasingDirection.Out
    },
    
    -- Panel animations
    panel_slide_in = {
        startPosition = UDim2.new(1, 0, 0, 0),
        endPosition = UDim2.new(0, 0, 0, 0),
        duration = 0.3,
        easingStyle = Enum.EasingStyle.Back,
        easingDirection = Enum.EasingDirection.Out
    },
    
    panel_slide_out = {
        startPosition = UDim2.new(0, 0, 0, 0),
        endPosition = UDim2.new(1, 0, 0, 0),
        duration = 0.2,
        easingStyle = Enum.EasingStyle.Quad,
        easingDirection = Enum.EasingDirection.In
    },
    
    -- Fade animations
    fade_in = {
        startTransparency = 1,
        endTransparency = 0,
        duration = 0.2,
        easingStyle = Enum.EasingStyle.Quad,
        easingDirection = Enum.EasingDirection.Out
    },
    
    fade_out = {
        startTransparency = 0,
        endTransparency = 1,
        duration = 0.15,
        easingStyle = Enum.EasingStyle.Quad,
        easingDirection = Enum.EasingDirection.In
    },
    
    -- Pop animations
    pop_in = {
        startScale = 0.1,
        endScale = 1,
        duration = 0.25,
        easingStyle = Enum.EasingStyle.Back,
        easingDirection = Enum.EasingDirection.Out
    },
    
    pop_out = {
        startScale = 1,
        endScale = 0.1,
        duration = 0.15,
        easingStyle = Enum.EasingStyle.Back,
        easingDirection = Enum.EasingDirection.In
    },
    
    -- Notification animations
    notification_slide = {
        startPosition = UDim2.new(1, 10, 0, 0),
        endPosition = UDim2.new(1, -220, 0, 0),
        duration = 0.4,
        easingStyle = Enum.EasingStyle.Back,
        easingDirection = Enum.EasingDirection.Out
    },
    
    -- Loading animations
    loading_pulse = {
        minTransparency = 0.3,
        maxTransparency = 0.8,
        duration = 1.0,
        easingStyle = Enum.EasingStyle.Sine,
        easingDirection = Enum.EasingDirection.InOut
    }
}

-- Color schemes
UIPolishManager.ColorSchemes = {
    default = {
        primary = Color3.fromRGB(46, 125, 50),
        secondary = Color3.fromRGB(139, 195, 74),
        accent = Color3.fromRGB(255, 193, 7),
        background = Color3.fromRGB(245, 245, 245),
        surface = Color3.fromRGB(255, 255, 255),
        text_primary = Color3.fromRGB(33, 33, 33),
        text_secondary = Color3.fromRGB(117, 117, 117),
        success = Color3.fromRGB(76, 175, 80),
        warning = Color3.fromRGB(255, 152, 0),
        error = Color3.fromRGB(244, 67, 54),
        info = Color3.fromRGB(33, 150, 243)
    },
    
    dark = {
        primary = Color3.fromRGB(46, 125, 50),
        secondary = Color3.fromRGB(139, 195, 74),
        accent = Color3.fromRGB(255, 193, 7),
        background = Color3.fromRGB(18, 18, 18),
        surface = Color3.fromRGB(33, 33, 33),
        text_primary = Color3.fromRGB(255, 255, 255),
        text_secondary = Color3.fromRGB(158, 158, 158),
        success = Color3.fromRGB(76, 175, 80),
        warning = Color3.fromRGB(255, 152, 0),
        error = Color3.fromRGB(244, 67, 54),
        info = Color3.fromRGB(33, 150, 243)
    },
    
    accessibility_high_contrast = {
        primary = Color3.fromRGB(0, 0, 0),
        secondary = Color3.fromRGB(255, 255, 255),
        accent = Color3.fromRGB(255, 255, 0),
        background = Color3.fromRGB(255, 255, 255),
        surface = Color3.fromRGB(240, 240, 240),
        text_primary = Color3.fromRGB(0, 0, 0),
        text_secondary = Color3.fromRGB(85, 85, 85),
        success = Color3.fromRGB(0, 128, 0),
        warning = Color3.fromRGB(255, 165, 0),
        error = Color3.fromRGB(255, 0, 0),
        info = Color3.fromRGB(0, 0, 255)
    }
}

-- UI Polish settings
UIPolishManager.PolishSettings = {
    -- Animation settings
    enableAnimations = true,
    animationSpeed = 1.0,
    reduceMotion = false,
    
    -- Visual settings
    enableParticleEffects = true,
    enableSoundEffects = true,
    enableHapticFeedback = true,
    
    -- Accessibility settings
    enableHighContrast = false,
    enableLargeText = false,
    enableScreenReader = false,
    enableColorBlindAssist = false,
    
    -- Mobile optimizations
    enableMobileOptimizations = true,
    mobileUIScale = 1.0,
    touchOptimizations = true,
    
    -- Performance settings
    maxSimultaneousAnimations = 10,
    animationQuality = "high", -- "low", "medium", "high"
    enableUIDistanceCulling = true
}

-- Default UI preferences
UIPolishManager.DefaultPreferences = {
    colorScheme = "default",
    animationsEnabled = true,
    soundEffectsEnabled = true,
    hapticFeedbackEnabled = true,
    notificationDuration = 5000,
    tooltipDelay = 500,
    autoHideControls = false,
    uiScale = 1.0,
    language = "en"
}

-- Responsive breakpoints for different screen sizes
UIPolishManager.ResponsiveBreakpoints = {
    mobile_small = {maxWidth = 480, uiScale = 0.8},
    mobile_large = {maxWidth = 768, uiScale = 0.9},
    tablet = {maxWidth = 1024, uiScale = 1.0},
    desktop = {maxWidth = 99999, uiScale = 1.1}
}

-- ==========================================
-- INITIALIZATION
-- ==========================================

function UIPolishManager:Initialize()
    print("✨ UIPolishManager: Initializing UI/UX polish system...")
    
    -- Set up remote events
    self:SetupRemoteEvents()
    
    -- Set up player connections
    self:SetupPlayerConnections()
    
    -- Initialize animation system
    self:InitializeAnimationSystem()
    
    -- Set up responsive design
    self:SetupResponsiveDesign()
    
    -- Start UI optimization loops
    self:StartOptimizationLoops()
    
    print("✅ UIPolishManager: UI/UX polish system initialized")
end

function UIPolishManager:SetupRemoteEvents()
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then
        remoteEvents = Instance.new("Folder")
        remoteEvents.Name = "RemoteEvents"
        remoteEvents.Parent = ReplicatedStorage
    end
    
    -- Update UI preferences
    local updatePreferencesRemote = Instance.new("RemoteEvent")
    updatePreferencesRemote.Name = "UpdateUIPreferences"
    updatePreferencesRemote.Parent = remoteEvents
    updatePreferencesRemote.OnServerEvent:Connect(function(player, preferences)
        self:UpdatePlayerPreferences(player, preferences)
    end)
    
    -- Get UI preferences
    local getPreferencesFunction = Instance.new("RemoteFunction")
    getPreferencesFunction.Name = "GetUIPreferences"
    getPreferencesFunction.Parent = remoteEvents
    getPreferencesFunction.OnServerInvoke = function(player)
        return self:GetPlayerPreferences(player)
    end
    
    -- Trigger UI animation
    local triggerAnimationRemote = Instance.new("RemoteEvent")
    triggerAnimationRemote.Name = "TriggerUIAnimation"
    triggerAnimationRemote.Parent = remoteEvents
    triggerAnimationRemote.OnServerEvent:Connect(function(player, animationData)
        self:TriggerAnimation(player, animationData)
    end)
    
    -- Show loading state
    local showLoadingRemote = Instance.new("RemoteEvent")
    showLoadingRemote.Name = "ShowLoadingState"
    showLoadingRemote.Parent = remoteEvents
    showLoadingRemote.OnServerEvent:Connect(function(player, loadingId, message)
        self:ShowLoadingState(player, loadingId, message)
    end)
    
    -- Hide loading state
    local hideLoadingRemote = Instance.new("RemoteEvent")
    hideLoadingRemote.Name = "HideLoadingState"
    hideLoadingRemote.Parent = remoteEvents
    hideLoadingRemote.OnServerEvent:Connect(function(player, loadingId)
        self:HideLoadingState(player, loadingId)
    end)
    
    -- Show tooltip
    local showTooltipRemote = Instance.new("RemoteEvent")
    showTooltipRemote.Name = "ShowTooltip"
    showTooltipRemote.Parent = remoteEvents
    showTooltipRemote.OnServerEvent:Connect(function(player, tooltipData)
        self:ShowTooltip(player, tooltipData)
    end)
    
    -- Update responsive design
    local updateResponsiveRemote = Instance.new("RemoteEvent")
    updateResponsiveRemote.Name = "UpdateResponsiveDesign"
    updateResponsiveRemote.Parent = remoteEvents
    updateResponsiveRemote.OnServerEvent:Connect(function(player, screenData)
        self:UpdateResponsiveDesign(player, screenData)
    end)
end

function UIPolishManager:SetupPlayerConnections()
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

function UIPolishManager:InitializeAnimationSystem()
    -- Initialize animation queue processing
    self.AnimationQueue = {}
    
    -- Start animation processing loop
    spawn(function()
        while true do
            self:ProcessAnimationQueue()
            RunService.Heartbeat:Wait()
        end
    end)
end

function UIPolishManager:SetupResponsiveDesign()
    -- Initialize responsive design system
    print("✨ UIPolishManager: Setting up responsive design system")
end

function UIPolishManager:StartOptimizationLoops()
    -- UI performance optimization loop
    spawn(function()
        while true do
            self:OptimizeUIPerformance()
            wait(5) -- Every 5 seconds
        end
    end)
    
    -- Animation cleanup loop
    spawn(function()
        while true do
            self:CleanupCompletedAnimations()
            wait(1) -- Every second
        end
    end)
    
    -- Loading state timeout loop
    spawn(function()
        while true do
            self:CheckLoadingStateTimeouts()
            wait(10) -- Every 10 seconds
        end
    end)
end

-- ==========================================
-- PLAYER MANAGEMENT
-- ==========================================

function UIPolishManager:OnPlayerJoined(player)
    -- Initialize player UI preferences
    self.PlayerUIPreferences[player.UserId] = table.clone(self.DefaultPreferences)
    
    -- Load saved preferences
    spawn(function()
        self:LoadPlayerPreferences(player)
    end)
    
    -- Initialize responsive design for player
    self:InitializePlayerResponsiveDesign(player)
    
    -- Send initial UI polish data to client
    self:SendInitialUIData(player)
    
    print("✨ UIPolishManager: Initialized UI polish for", player.Name)
end

function UIPolishManager:OnPlayerLeaving(player)
    -- Save player preferences
    spawn(function()
        self:SavePlayerPreferences(player)
    end)
    
    -- Clean up player data
    self.PlayerUIPreferences[player.UserId] = nil
    
    -- Clean up player-specific loading states
    for loadingId, loadingData in pairs(self.LoadingStates) do
        if loadingData.playerId == player.UserId then
            self.LoadingStates[loadingId] = nil
        end
    end
    
    print("✨ UIPolishManager: Cleaned up UI data for", player.Name)
end

function UIPolishManager:LoadPlayerPreferences(player)
    local success, preferences = pcall(function()
        return self.UIPreferencesStore:GetAsync("preferences_" .. player.UserId)
    end)
    
    if success and preferences then
        -- Merge with defaults to ensure all preferences exist
        for key, value in pairs(preferences) do
            if self.PlayerUIPreferences[player.UserId][key] ~= nil then
                self.PlayerUIPreferences[player.UserId][key] = value
            end
        end
        print("✨ UIPolishManager: Loaded preferences for", player.Name)
    else
        print("✨ UIPolishManager: Using default preferences for", player.Name)
    end
end

function UIPolishManager:SavePlayerPreferences(player)
    local preferences = self.PlayerUIPreferences[player.UserId]
    if not preferences then return end
    
    local success, error = pcall(function()
        self.UIPreferencesStore:SetAsync("preferences_" .. player.UserId, preferences)
    end)
    
    if not success then
        warn("❌ UIPolishManager: Failed to save preferences for", player.Name, ":", error)
    end
end

function UIPolishManager:SendInitialUIData(player)
    -- Send color schemes
    local colorSchemesRemote = ReplicatedStorage.RemoteEvents:FindFirstChild("UpdateColorSchemes")
    if not colorSchemesRemote then
        colorSchemesRemote = Instance.new("RemoteEvent")
        colorSchemesRemote.Name = "UpdateColorSchemes"
        colorSchemesRemote.Parent = ReplicatedStorage.RemoteEvents
    end
    colorSchemesRemote:FireClient(player, self.ColorSchemes)
    
    -- Send animation presets
    local animationPresetsRemote = ReplicatedStorage.RemoteEvents:FindFirstChild("UpdateAnimationPresets")
    if not animationPresetsRemote then
        animationPresetsRemote = Instance.new("RemoteEvent")
        animationPresetsRemote.Name = "UpdateAnimationPresets"
        animationPresetsRemote.Parent = ReplicatedStorage.RemoteEvents
    end
    animationPresetsRemote:FireClient(player, self.AnimationPresets)
    
    -- Send polish settings
    local polishSettingsRemote = ReplicatedStorage.RemoteEvents:FindFirstChild("UpdatePolishSettings")
    if not polishSettingsRemote then
        polishSettingsRemote = Instance.new("RemoteEvent")
        polishSettingsRemote.Name = "UpdatePolishSettings"
        polishSettingsRemote.Parent = ReplicatedStorage.RemoteEvents
    end
    polishSettingsRemote:FireClient(player, self.PolishSettings)
end

-- ==========================================
-- PREFERENCE MANAGEMENT
-- ==========================================

function UIPolishManager:UpdatePlayerPreferences(player, newPreferences)
    local preferences = self.PlayerUIPreferences[player.UserId]
    if not preferences then return end
    
    -- Update preferences
    for key, value in pairs(newPreferences) do
        if preferences[key] ~= nil then
            preferences[key] = value
        end
    end
    
    -- Apply changes immediately
    self:ApplyPreferenceChanges(player, newPreferences)
    
    print("✨ UIPolishManager: Updated preferences for", player.Name)
end

function UIPolishManager:GetPlayerPreferences(player)
    return self.PlayerUIPreferences[player.UserId] or table.clone(self.DefaultPreferences)
end

function UIPolishManager:ApplyPreferenceChanges(player, changes)
    -- Apply color scheme changes
    if changes.colorScheme then
        local colorScheme = self.ColorSchemes[changes.colorScheme]
        if colorScheme then
            local updateColorSchemeRemote = ReplicatedStorage.RemoteEvents:FindFirstChild("ApplyColorScheme")
            if updateColorSchemeRemote then
                updateColorSchemeRemote:FireClient(player, colorScheme)
            end
        end
    end
    
    -- Apply animation settings
    if changes.animationsEnabled ~= nil then
        local updateAnimationsRemote = ReplicatedStorage.RemoteEvents:FindFirstChild("UpdateAnimationsEnabled")
        if updateAnimationsRemote then
            updateAnimationsRemote:FireClient(player, changes.animationsEnabled)
        end
    end
    
    -- Apply UI scale changes
    if changes.uiScale then
        local updateUIScaleRemote = ReplicatedStorage.RemoteEvents:FindFirstChild("UpdateUIScale")
        if updateUIScaleRemote then
            updateUIScaleRemote:FireClient(player, changes.uiScale)
        end
    end
    
    -- Apply accessibility settings
    self:ApplyAccessibilitySettings(player, changes)
end

function UIPolishManager:ApplyAccessibilitySettings(player, settings)
    local accessibilityData = {}
    
    if settings.enableHighContrast ~= nil then
        accessibilityData.highContrast = settings.enableHighContrast
    end
    
    if settings.enableLargeText ~= nil then
        accessibilityData.largeText = settings.enableLargeText
    end
    
    if settings.enableColorBlindAssist ~= nil then
        accessibilityData.colorBlindAssist = settings.enableColorBlindAssist
    end
    
    if next(accessibilityData) then
        local applyAccessibilityRemote = ReplicatedStorage.RemoteEvents:FindFirstChild("ApplyAccessibilitySettings")
        if not applyAccessibilityRemote then
            applyAccessibilityRemote = Instance.new("RemoteEvent")
            applyAccessibilityRemote.Name = "ApplyAccessibilitySettings"
            applyAccessibilityRemote.Parent = ReplicatedStorage.RemoteEvents
        end
        applyAccessibilityRemote:FireClient(player, accessibilityData)
    end
end

-- ==========================================
-- ANIMATION SYSTEM
-- ==========================================

function UIPolishManager:TriggerAnimation(player, animationData)
    if not self.PolishSettings.enableAnimations then return end
    
    -- Add to animation queue
    local animationId = HttpService:GenerateGUID(false)
    local animation = {
        id = animationId,
        playerId = player.UserId,
        type = animationData.type,
        target = animationData.target,
        preset = animationData.preset,
        customProperties = animationData.customProperties,
        callback = animationData.callback,
        timestamp = tick(),
        status = "queued"
    }
    
    table.insert(self.AnimationQueue, animation)
    
    return animationId
end

function UIPolishManager:ProcessAnimationQueue()
    local maxAnimations = self.PolishSettings.maxSimultaneousAnimations
    local activeAnimations = 0
    
    -- Count active animations
    for _, animation in ipairs(self.AnimationQueue) do
        if animation.status == "playing" then
            activeAnimations = activeAnimations + 1
        end
    end
    
    -- Process queued animations if under limit
    for i, animation in ipairs(self.AnimationQueue) do
        if animation.status == "queued" and activeAnimations < maxAnimations then
            self:StartAnimation(animation)
            activeAnimations = activeAnimations + 1
        elseif animation.status == "completed" then
            table.remove(self.AnimationQueue, i)
        end
    end
end

function UIPolishManager:StartAnimation(animation)
    animation.status = "playing"
    
    -- Get player
    local player = Players:GetPlayerByUserId(animation.playerId)
    if not player then
        animation.status = "completed"
        return
    end
    
    -- Send animation to client
    local playAnimationRemote = ReplicatedStorage.RemoteEvents:FindFirstChild("PlayUIAnimation")
    if not playAnimationRemote then
        playAnimationRemote = Instance.new("RemoteEvent")
        playAnimationRemote.Name = "PlayUIAnimation"
        playAnimationRemote.Parent = ReplicatedStorage.RemoteEvents
    end
    
    playAnimationRemote:FireClient(player, animation)
    
    -- Set completion timer based on animation duration
    local preset = self.AnimationPresets[animation.preset]
    local duration = preset and preset.duration or 0.3
    
    spawn(function()
        wait(duration + 0.1) -- Small buffer
        animation.status = "completed"
        
        if animation.callback then
            animation.callback()
        end
    end)
end

function UIPolishManager:CleanupCompletedAnimations()
    for i = #self.AnimationQueue, 1, -1 do
        local animation = self.AnimationQueue[i]
        if animation.status == "completed" or (tick() - animation.timestamp) > 30 then
            table.remove(self.AnimationQueue, i)
        end
    end
end

-- ==========================================
-- LOADING STATE MANAGEMENT
-- ==========================================

function UIPolishManager:ShowLoadingState(player, loadingId, message)
    -- Create loading state
    local loadingState = {
        id = loadingId,
        playerId = player.UserId,
        message = message or "Loading...",
        timestamp = tick(),
        timeout = 30 -- 30 second timeout
    }
    
    self.LoadingStates[loadingId] = loadingState
    
    -- Send to client
    local showLoadingRemote = ReplicatedStorage.RemoteEvents:FindFirstChild("DisplayLoadingState")
    if not showLoadingRemote then
        showLoadingRemote = Instance.new("RemoteEvent")
        showLoadingRemote.Name = "DisplayLoadingState"
        showLoadingRemote.Parent = ReplicatedStorage.RemoteEvents
    end
    
    showLoadingRemote:FireClient(player, loadingState)
    
    print("✨ UIPolishManager: Showing loading state for", player.Name, ":", message)
end

function UIPolishManager:HideLoadingState(player, loadingId)
    local loadingState = self.LoadingStates[loadingId]
    if not loadingState or loadingState.playerId ~= player.UserId then return end
    
    -- Remove loading state
    self.LoadingStates[loadingId] = nil
    
    -- Send hide command to client
    local hideLoadingRemote = ReplicatedStorage.RemoteEvents:FindFirstChild("HideLoadingState")
    if not hideLoadingRemote then
        hideLoadingRemote = Instance.new("RemoteEvent")
        hideLoadingRemote.Name = "HideLoadingState"
        hideLoadingRemote.Parent = ReplicatedStorage.RemoteEvents
    end
    
    hideLoadingRemote:FireClient(player, loadingId)
    
    print("✨ UIPolishManager: Hiding loading state for", player.Name, ":", loadingId)
end

function UIPolishManager:CheckLoadingStateTimeouts()
    local currentTime = tick()
    
    for loadingId, loadingState in pairs(self.LoadingStates) do
        if currentTime - loadingState.timestamp > loadingState.timeout then
            local player = Players:GetPlayerByUserId(loadingState.playerId)
            if player then
                self:HideLoadingState(player, loadingId)
                warn("⚠️ UIPolishManager: Loading state timed out:", loadingId)
            else
                self.LoadingStates[loadingId] = nil
            end
        end
    end
end

-- ==========================================
-- TOOLTIP SYSTEM
-- ==========================================

function UIPolishManager:ShowTooltip(player, tooltipData)
    -- Validate tooltip data
    if not tooltipData.text or tooltipData.text == "" then return end
    
    -- Create tooltip entry
    local tooltip = {
        id = HttpService:GenerateGUID(false),
        playerId = player.UserId,
        text = tooltipData.text,
        position = tooltipData.position,
        delay = tooltipData.delay or self:GetPlayerPreferences(player).tooltipDelay,
        duration = tooltipData.duration or 5000,
        style = tooltipData.style or "default",
        timestamp = tick()
    }
    
    -- Send to client
    local showTooltipRemote = ReplicatedStorage.RemoteEvents:FindFirstChild("DisplayTooltip")
    if not showTooltipRemote then
        showTooltipRemote = Instance.new("RemoteEvent")
        showTooltipRemote.Name = "DisplayTooltip"
        showTooltipRemote.Parent = ReplicatedStorage.RemoteEvents
    end
    
    showTooltipRemote:FireClient(player, tooltip)
end

-- ==========================================
-- RESPONSIVE DESIGN
-- ==========================================

function UIPolishManager:InitializePlayerResponsiveDesign(player)
    -- Request screen size from client
    local requestScreenSizeRemote = ReplicatedStorage.RemoteEvents:FindFirstChild("RequestScreenSize")
    if not requestScreenSizeRemote then
        requestScreenSizeRemote = Instance.new("RemoteEvent")
        requestScreenSizeRemote.Name = "RequestScreenSize"
        requestScreenSizeRemote.Parent = ReplicatedStorage.RemoteEvents
    end
    
    requestScreenSizeRemote:FireClient(player)
end

function UIPolishManager:UpdateResponsiveDesign(player, screenData)
    local screenWidth = screenData.width or 1920
    local screenHeight = screenData.height or 1080
    local deviceType = screenData.deviceType or "desktop"
    
    -- Determine appropriate breakpoint
    local breakpoint = self:GetBreakpointForScreen(screenWidth)
    
    -- Calculate responsive UI scale
    local responsiveScale = self:CalculateResponsiveScale(screenWidth, screenHeight, deviceType)
    
    -- Send responsive updates to client
    local updateResponsiveRemote = ReplicatedStorage.RemoteEvents:FindFirstChild("ApplyResponsiveDesign")
    if not updateResponsiveRemote then
        updateResponsiveRemote = Instance.new("RemoteEvent")
        updateResponsiveRemote.Name = "ApplyResponsiveDesign"
        updateResponsiveRemote.Parent = ReplicatedStorage.RemoteEvents
    end
    
    updateResponsiveRemote:FireClient(player, {
        breakpoint = breakpoint,
        scale = responsiveScale,
        deviceType = deviceType,
        optimizations = self:GetDeviceOptimizations(deviceType)
    })
    
    print("✨ UIPolishManager: Applied responsive design for", player.Name, "- Scale:", responsiveScale)
end

function UIPolishManager:GetBreakpointForScreen(width)
    for breakpointName, breakpoint in pairs(self.ResponsiveBreakpoints) do
        if width <= breakpoint.maxWidth then
            return breakpointName
        end
    end
    return "desktop"
end

function UIPolishManager:CalculateResponsiveScale(width, height, deviceType)
    local baseScale = 1.0
    
    -- Device-specific scaling
    if deviceType == "mobile" then
        baseScale = 0.8
    elseif deviceType == "tablet" then
        baseScale = 0.9
    end
    
    -- Width-based scaling adjustments
    if width < 480 then
        baseScale = baseScale * 0.85
    elseif width < 768 then
        baseScale = baseScale * 0.9
    elseif width > 1920 then
        baseScale = baseScale * 1.1
    end
    
    return math.max(0.5, math.min(2.0, baseScale))
end

function UIPolishManager:GetDeviceOptimizations(deviceType)
    local optimizations = {}
    
    if deviceType == "mobile" then
        optimizations = {
            enableTouchOptimizations = true,
            increaseButtonSizes = true,
            simplifyAnimations = true,
            reduceParticleEffects = true,
            enableHapticFeedback = true
        }
    elseif deviceType == "tablet" then
        optimizations = {
            enableTouchOptimizations = true,
            increaseButtonSizes = false,
            simplifyAnimations = false,
            reduceParticleEffects = false,
            enableHapticFeedback = true
        }
    else -- desktop
        optimizations = {
            enableTouchOptimizations = false,
            increaseButtonSizes = false,
            simplifyAnimations = false,
            reduceParticleEffects = false,
            enableHapticFeedback = false
        }
    end
    
    return optimizations
end

-- ==========================================
-- UI PERFORMANCE OPTIMIZATION
-- ==========================================

function UIPolishManager:OptimizeUIPerformance()
    -- Check animation queue size
    if #self.AnimationQueue > 50 then
        self:CleanupCompletedAnimations()
        print("⚠️ UIPolishManager: Large animation queue detected, cleaning up")
    end
    
    -- Check loading states
    local activeLoadingStates = 0
    for _ in pairs(self.LoadingStates) do
        activeLoadingStates = activeLoadingStates + 1
    end
    
    if activeLoadingStates > 20 then
        print("⚠️ UIPolishManager: Many active loading states:", activeLoadingStates)
    end
    
    -- Monitor frame rate impact
    local performanceOptimizer = _G.PerformanceOptimizer
    if performanceOptimizer then
        local metrics = performanceOptimizer:GetPerformanceMetrics()
        if metrics.frameRate < 30 then
            self:ReduceUIComplexity()
        end
    end
end

function UIPolishManager:ReduceUIComplexity()
    -- Temporarily reduce animation quality
    if self.PolishSettings.animationQuality == "high" then
        self.PolishSettings.animationQuality = "medium"
        print("✨ UIPolishManager: Reduced animation quality for performance")
    end
    
    -- Reduce maximum simultaneous animations
    if self.PolishSettings.maxSimultaneousAnimations > 5 then
        self.PolishSettings.maxSimultaneousAnimations = 5
        print("✨ UIPolishManager: Reduced max simultaneous animations")
    end
    
    -- Send performance mode update to all clients
    local performanceModeRemote = ReplicatedStorage.RemoteEvents:FindFirstChild("UpdatePerformanceMode")
    if not performanceModeRemote then
        performanceModeRemote = Instance.new("RemoteEvent")
        performanceModeRemote.Name = "UpdatePerformanceMode"
        performanceModeRemote.Parent = ReplicatedStorage.RemoteEvents
    end
    
    performanceModeRemote:FireAllClients({
        animationQuality = self.PolishSettings.animationQuality,
        maxAnimations = self.PolishSettings.maxSimultaneousAnimations,
        reduceEffects = true
    })
end

-- ==========================================
-- PUBLIC API
-- ==========================================

function UIPolishManager:GetAnimationPresets()
    return self.AnimationPresets
end

function UIPolishManager:GetColorSchemes()
    return self.ColorSchemes
end

function UIPolishManager:GetPolishSettings()
    return self.PolishSettings
end

function UIPolishManager:UpdatePolishSetting(setting, value)
    if self.PolishSettings[setting] ~= nil then
        self.PolishSettings[setting] = value
        print("✨ UIPolishManager: Updated", setting, "to", tostring(value))
        
        -- Broadcast to all clients
        local updateSettingRemote = ReplicatedStorage.RemoteEvents:FindFirstChild("UpdatePolishSetting")
        if not updateSettingRemote then
            updateSettingRemote = Instance.new("RemoteEvent")
            updateSettingRemote.Name = "UpdatePolishSetting"
            updateSettingRemote.Parent = ReplicatedStorage.RemoteEvents
        end
        
        updateSettingRemote:FireAllClients(setting, value)
    end
end

function UIPolishManager:CreateLoadingState(player, message)
    local loadingId = HttpService:GenerateGUID(false)
    self:ShowLoadingState(player, loadingId, message)
    return loadingId
end

function UIPolishManager:GetActiveAnimationsCount()
    local count = 0
    for _, animation in ipairs(self.AnimationQueue) do
        if animation.status == "playing" then
            count = count + 1
        end
    end
    return count
end

function UIPolishManager:GetActiveLoadingStatesCount()
    local count = 0
    for _ in pairs(self.LoadingStates) do
        count = count + 1
    end
    return count
end

-- ==========================================
-- CLEANUP
-- ==========================================

function UIPolishManager:Cleanup()
    -- Save all player preferences
    for userId, preferences in pairs(self.PlayerUIPreferences) do
        local player = Players:GetPlayerByUserId(userId)
        if player then
            self:SavePlayerPreferences(player)
        end
    end
    
    -- Clean up animation queue
    self.AnimationQueue = {}
    
    -- Clean up loading states
    self.LoadingStates = {}
    
    print("✨ UIPolishManager: UI/UX polish system cleaned up")
end

return UIPolishManager
