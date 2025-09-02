--[[
    SettingsManager.lua
    Client-Side Settings Management System
    
    Priority: 24 (VIP & Monetization phase)
    Dependencies: UserInputService, SoundService, DataStoreService
    Used by: All client systems, UI, audio, graphics
    
    Features:
    - Graphics and performance settings
    - Audio and music controls
    - Accessibility options
    - VIP exclusive settings
    - Cloud save synchronization
    - Device-specific optimizations
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

-- Load required modules
local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)

local SettingsManager = {}
SettingsManager.__index = SettingsManager

-- ==========================================
-- INITIALIZATION & SETUP
-- ==========================================

SettingsManager.Player = Players.LocalPlayer
SettingsManager.PlayerGui = SettingsManager.Player:WaitForChild("PlayerGui")

-- Settings state
SettingsManager.CurrentSettings = {}
SettingsManager.DefaultSettings = {}
SettingsManager.SettingsGui = nil
SettingsManager.IsSettingsOpen = false

-- Mobile detection
SettingsManager.IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
SettingsManager.IsVIP = false

-- Performance monitoring
SettingsManager.PerformanceData = {
    fps = 60,
    ping = 0,
    memory = 0,
    lastUpdate = 0
}

-- ==========================================
-- DEFAULT SETTINGS CONFIGURATION
-- ==========================================

SettingsManager.DefaultSettings = {
    -- Graphics Settings
    graphics = {
        quality = SettingsManager.IsMobile and "Medium" or "High", -- Low, Medium, High, Ultra
        particleEffects = true,
        shadows = not SettingsManager.IsMobile,
        lighting = SettingsManager.IsMobile and "Medium" or "High",
        renderDistance = SettingsManager.IsMobile and "Medium" or "High",
        antiAliasing = not SettingsManager.IsMobile,
        bloomEffect = true,
        colorCorrection = true,
        vipEffects = true -- VIP visual enhancements
    },
    
    -- Audio Settings
    audio = {
        masterVolume = 0.7,
        musicVolume = 0.5,
        soundEffectsVolume = 0.8,
        uiSoundsVolume = 0.6,
        voiceVolume = 0.7,
        muteWhenMinimized = true,
        spatialAudio = true
    },
    
    -- Gameplay Settings
    gameplay = {
        autoHarvest = false,
        autoPlant = false, -- VIP exclusive
        showDamageNumbers = true,
        showTooltips = true,
        tutorialMode = true,
        fastAnimations = false,
        confirmActions = true,
        autoClaim = false -- VIP exclusive
    },
    
    -- UI Settings
    ui = {
        hudScale = 1.0,
        uiTransparency = 0.0,
        chatEnabled = true,
        notificationsEnabled = true,
        achievementPopups = true,
        compactMode = SettingsManager.IsMobile,
        colorTheme = "Default", -- Default, Dark, Light, VIP Gold
        language = "en"
    },
    
    -- Accessibility Settings
    accessibility = {
        colorBlindMode = "None", -- None, Protanopia, Deuteranopia, Tritanopia
        highContrast = false,
        largeText = false,
        reduceMotion = false,
        screenReader = false,
        subtitles = false,
        buttonPrompts = true
    },
    
    -- Performance Settings
    performance = {
        autoQuality = true,
        targetFPS = 60,
        powerSavingMode = SettingsManager.IsMobile,
        backgroundThrottling = true,
        cacheOptimization = true,
        memoryManagement = true
    },
    
    -- Privacy Settings
    privacy = {
        allowFriendRequests = true,
        allowVisitors = true,
        showOnlineStatus = true,
        allowGifts = true,
        shareGardenStats = true,
        allowDataCollection = true -- For analytics
    },
    
    -- VIP Exclusive Settings
    vip = {
        goldenTheme = false,
        exclusiveEffects = true,
        priorityNotifications = true,
        enhancedAnimations = true,
        customizableUI = true
    }
}

-- ==========================================
-- SETTINGS CATEGORIES FOR UI
-- ==========================================

SettingsManager.SettingsCategories = {
    {
        id = "graphics",
        name = "Graphics",
        icon = "🎨",
        description = "Visual quality and effects"
    },
    {
        id = "audio",
        name = "Audio",
        icon = "🔊",
        description = "Sound and music settings"
    },
    {
        id = "gameplay",
        name = "Gameplay",
        icon = "🎮",
        description = "Game mechanics and automation"
    },
    {
        id = "ui",
        name = "Interface",
        icon = "📱",
        description = "UI appearance and behavior"
    },
    {
        id = "accessibility",
        name = "Accessibility",
        icon = "♿",
        description = "Accessibility and comfort options"
    },
    {
        id = "performance",
        name = "Performance",
        icon = "⚡",
        description = "Performance and optimization"
    },
    {
        id = "privacy",
        name = "Privacy",
        icon = "🔒",
        description = "Privacy and social settings"
    },
    {
        id = "vip",
        name = "VIP Exclusive",
        icon = "👑",
        description = "VIP member exclusive settings",
        vipOnly = true
    }
}

-- ==========================================
-- INITIALIZATION
-- ==========================================

function SettingsManager:Initialize()
    print("⚙️ SettingsManager: Initializing settings system...")
    
    -- Initialize settings with defaults
    self:InitializeSettings()
    
    -- Check VIP status
    self:UpdateVIPStatus()
    
    -- Load saved settings
    self:LoadSettings()
    
    -- Apply initial settings
    self:ApplyAllSettings()
    
    -- Set up remote events
    self:SetupRemoteEvents()
    
    -- Set up performance monitoring
    self:StartPerformanceMonitoring()
    
    -- Set up device optimization
    self:OptimizeForDevice()
    
    print("✅ SettingsManager: Settings system initialized")
end

function SettingsManager:InitializeSettings()
    -- Deep copy default settings
    self.CurrentSettings = self:DeepCopyTable(self.DefaultSettings)
end

function SettingsManager:UpdateVIPStatus()
    local vipManager = _G.VIPManager
    if vipManager then
        self.IsVIP = vipManager:IsPlayerVIP(self.Player)
    end
end

function SettingsManager:SetupRemoteEvents()
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then
        warn("❌ SettingsManager: RemoteEvents folder not found")
        return
    end
    
    -- Settings synchronization
    local saveSettingsFunction = remoteEvents:FindFirstChild("SavePlayerSettings")
    if saveSettingsFunction then
        -- Function exists, ready to use
    end
    
    local loadSettingsFunction = remoteEvents:FindFirstChild("LoadPlayerSettings")
    if loadSettingsFunction then
        -- Function exists, ready to use
    end
    
    -- VIP status updates
    local vipStatusEvent = remoteEvents:FindFirstChild("VIPStatusUpdate")
    if vipStatusEvent then
        vipStatusEvent.OnClientEvent:Connect(function(isVIP)
            self:OnVIPStatusChanged(isVIP)
        end)
    end
end

function SettingsManager:StartPerformanceMonitoring()
    spawn(function()
        while true do
            self:UpdatePerformanceData()
            
            -- Auto-adjust quality if enabled
            if self.CurrentSettings.performance.autoQuality then
                self:AutoAdjustQuality()
            end
            
            wait(5) -- Update every 5 seconds
        end
    end)
end

function SettingsManager:OptimizeForDevice()
    if self.IsMobile then
        -- Mobile optimizations
        self:ApplyMobileOptimizations()
    end
    
    -- Check for low-end device
    if self:IsLowEndDevice() then
        self:ApplyLowEndOptimizations()
    end
end

-- ==========================================
-- SETTINGS LOADING & SAVING
-- ==========================================

function SettingsManager:LoadSettings()
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if remoteEvents then
        local loadSettingsFunction = remoteEvents:FindFirstChild("LoadPlayerSettings")
        if loadSettingsFunction then
            local success, savedSettings = pcall(function()
                return loadSettingsFunction:InvokeServer()
            end)
            
            if success and savedSettings then
                self:MergeSettings(savedSettings)
                print("⚙️ SettingsManager: Loaded saved settings")
            else
                print("⚙️ SettingsManager: Using default settings")
            end
        end
    end
end

function SettingsManager:SaveSettings()
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if remoteEvents then
        local saveSettingsFunction = remoteEvents:FindFirstChild("SavePlayerSettings")
        if saveSettingsFunction then
            local success, result = pcall(function()
                return saveSettingsFunction:InvokeServer(self.CurrentSettings)
            end)
            
            if success then
                print("⚙️ SettingsManager: Settings saved successfully")
            else
                warn("⚠️ SettingsManager: Failed to save settings")
            end
        end
    end
end

function SettingsManager:MergeSettings(savedSettings)
    -- Merge saved settings with defaults, preserving structure
    for category, categorySettings in pairs(savedSettings) do
        if self.CurrentSettings[category] then
            for setting, value in pairs(categorySettings) do
                if self.CurrentSettings[category][setting] ~= nil then
                    self.CurrentSettings[category][setting] = value
                end
            end
        end
    end
end

-- ==========================================
-- SETTINGS APPLICATION
-- ==========================================

function SettingsManager:ApplyAllSettings()
    self:ApplyGraphicsSettings()
    self:ApplyAudioSettings()
    self:ApplyGameplaySettings()
    self:ApplyUISettings()
    self:ApplyAccessibilitySettings()
    self:ApplyPerformanceSettings()
    self:ApplyVIPSettings()
end

function SettingsManager:ApplyGraphicsSettings()
    local graphics = self.CurrentSettings.graphics
    
    -- Quality level adjustments
    if graphics.quality == "Low" then
        self:SetGraphicsQuality(1)
    elseif graphics.quality == "Medium" then
        self:SetGraphicsQuality(2)
    elseif graphics.quality == "High" then
        self:SetGraphicsQuality(3)
    elseif graphics.quality == "Ultra" then
        self:SetGraphicsQuality(4)
    end
    
    -- Particle effects
    self:SetParticleEffects(graphics.particleEffects)
    
    -- Lighting quality
    self:SetLightingQuality(graphics.lighting)
    
    -- Shadows
    self:SetShadowsEnabled(graphics.shadows)
    
    -- Other visual effects
    self:SetBloomEffect(graphics.bloomEffect)
    self:SetColorCorrection(graphics.colorCorrection)
    
    print("⚙️ SettingsManager: Applied graphics settings")
end

function SettingsManager:SetGraphicsQuality(level)
    local settings = UserSettings():GetService("UserGameSettings")
    if settings then
        settings.GraphicsQualityLevel = level
    end
end

function SettingsManager:SetParticleEffects(enabled)
    -- Apply to all VIP effects managers
    local vipEffectsManager = _G.VIPEffectsManager
    if vipEffectsManager then
        vipEffectsManager:SetEffectsEnabled(enabled)
    end
end

function SettingsManager:SetLightingQuality(quality)
    if quality == "Low" then
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 500
    elseif quality == "Medium" then
        Lighting.GlobalShadows = true
        Lighting.FogEnd = 1000
    elseif quality == "High" then
        Lighting.GlobalShadows = true
        Lighting.FogEnd = 2000
    end
end

function SettingsManager:SetShadowsEnabled(enabled)
    Lighting.GlobalShadows = enabled
end

function SettingsManager:SetBloomEffect(enabled)
    local bloom = Lighting:FindFirstChild("Bloom")
    if bloom then
        bloom.Enabled = enabled
    end
end

function SettingsManager:SetColorCorrection(enabled)
    local colorCorrection = Lighting:FindFirstChild("ColorCorrectionEffect")
    if colorCorrection then
        colorCorrection.Enabled = enabled
    end
end

function SettingsManager:ApplyAudioSettings()
    local audio = self.CurrentSettings.audio
    
    -- Master volume
    SoundService.Volume = audio.masterVolume
    
    -- Apply to specific sound groups if they exist
    local musicGroup = SoundService:FindFirstChild("MusicGroup")
    if musicGroup then
        musicGroup.Volume = audio.musicVolume
    end
    
    local sfxGroup = SoundService:FindFirstChild("SFXGroup")
    if sfxGroup then
        sfxGroup.Volume = audio.soundEffectsVolume
    end
    
    local uiGroup = SoundService:FindFirstChild("UIGroup")
    if uiGroup then
        uiGroup.Volume = audio.uiSoundsVolume
    end
    
    print("⚙️ SettingsManager: Applied audio settings")
end

function SettingsManager:ApplyGameplaySettings()
    local gameplay = self.CurrentSettings.gameplay
    
    -- Apply automation settings to relevant managers
    local gardenManager = _G.GardenManager
    if gardenManager then
        gardenManager:SetAutoHarvest(gameplay.autoHarvest)
        
        if self.IsVIP then
            gardenManager:SetAutoPlant(gameplay.autoPlant)
            gardenManager:SetAutoClaim(gameplay.autoClaim)
        end
    end
    
    -- UI feedback settings
    local uiManager = _G.UIManager
    if uiManager then
        uiManager:SetShowTooltips(gameplay.showTooltips)
        uiManager:SetFastAnimations(gameplay.fastAnimations)
    end
    
    print("⚙️ SettingsManager: Applied gameplay settings")
end

function SettingsManager:ApplyUISettings()
    local ui = self.CurrentSettings.ui
    
    -- HUD scaling
    self:SetHUDScale(ui.hudScale)
    
    -- UI transparency
    self:SetUITransparency(ui.uiTransparency)
    
    -- Color theme
    self:ApplyColorTheme(ui.colorTheme)
    
    -- Notifications
    local notificationManager = _G.NotificationManager
    if notificationManager then
        notificationManager:SetNotificationsEnabled(ui.notificationsEnabled)
        notificationManager:SetAchievementPopupsEnabled(ui.achievementPopups)
    end
    
    print("⚙️ SettingsManager: Applied UI settings")
end

function SettingsManager:SetHUDScale(scale)
    -- Apply scaling to main UI elements
    for _, gui in pairs(self.PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Name ~= "SettingsGUI" then
            if gui:FindFirstChild("MainFrame") then
                gui.MainFrame.Size = UDim2.new(
                    gui.MainFrame.Size.X.Scale * scale,
                    gui.MainFrame.Size.X.Offset,
                    gui.MainFrame.Size.Y.Scale * scale,
                    gui.MainFrame.Size.Y.Offset
                )
            end
        end
    end
end

function SettingsManager:SetUITransparency(transparency)
    -- Apply transparency to UI backgrounds
    for _, gui in pairs(self.PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") then
            for _, frame in pairs(gui:GetDescendants()) do
                if frame:IsA("Frame") and frame.BackgroundTransparency < 1 then
                    frame.BackgroundTransparency = math.min(1, frame.BackgroundTransparency + transparency)
                end
            end
        end
    end
end

function SettingsManager:ApplyColorTheme(theme)
    local colors = self:GetThemeColors(theme)
    
    -- Apply theme colors to UI elements
    for _, gui in pairs(self.PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") then
            self:ApplyThemeToGui(gui, colors)
        end
    end
end

function SettingsManager:GetThemeColors(theme)
    local themes = {
        Default = {
            primary = Color3.fromRGB(52, 152, 219),
            secondary = Color3.fromRGB(46, 204, 113),
            background = Color3.fromRGB(40, 40, 40),
            text = Color3.fromRGB(255, 255, 255)
        },
        Dark = {
            primary = Color3.fromRGB(100, 100, 100),
            secondary = Color3.fromRGB(150, 150, 150),
            background = Color3.fromRGB(20, 20, 20),
            text = Color3.fromRGB(255, 255, 255)
        },
        Light = {
            primary = Color3.fromRGB(70, 130, 180),
            secondary = Color3.fromRGB(60, 179, 113),
            background = Color3.fromRGB(245, 245, 245),
            text = Color3.fromRGB(0, 0, 0)
        },
        ["VIP Gold"] = {
            primary = Color3.fromRGB(255, 215, 0),
            secondary = Color3.fromRGB(255, 165, 0),
            background = Color3.fromRGB(139, 69, 19),
            text = Color3.fromRGB(255, 255, 255)
        }
    }
    
    return themes[theme] or themes.Default
end

function SettingsManager:ApplyThemeToGui(gui, colors)
    for _, element in pairs(gui:GetDescendants()) do
        if element:IsA("Frame") then
            if element:GetAttribute("ThemeRole") == "primary" then
                element.BackgroundColor3 = colors.primary
            elseif element:GetAttribute("ThemeRole") == "secondary" then
                element.BackgroundColor3 = colors.secondary
            elseif element:GetAttribute("ThemeRole") == "background" then
                element.BackgroundColor3 = colors.background
            end
        elseif element:IsA("TextLabel") or element:IsA("TextButton") then
            if element:GetAttribute("ThemeRole") == "text" then
                element.TextColor3 = colors.text
            end
        end
    end
end

function SettingsManager:ApplyAccessibilitySettings()
    local accessibility = self.CurrentSettings.accessibility
    
    -- Color blind support
    self:ApplyColorBlindMode(accessibility.colorBlindMode)
    
    -- High contrast
    if accessibility.highContrast then
        self:EnableHighContrast()
    end
    
    -- Large text
    if accessibility.largeText then
        self:EnableLargeText()
    end
    
    -- Reduce motion
    if accessibility.reduceMotion then
        self:ReduceAnimations()
    end
    
    print("⚙️ SettingsManager: Applied accessibility settings")
end

function SettingsManager:ApplyColorBlindMode(mode)
    local colorCorrection = Lighting:FindFirstChild("ColorCorrectionEffect")
    if not colorCorrection then
        colorCorrection = Instance.new("ColorCorrectionEffect")
        colorCorrection.Parent = Lighting
    end
    
    if mode == "Protanopia" then
        colorCorrection.TintColor = Color3.fromRGB(255, 200, 200)
    elseif mode == "Deuteranopia" then
        colorCorrection.TintColor = Color3.fromRGB(200, 255, 200)
    elseif mode == "Tritanopia" then
        colorCorrection.TintColor = Color3.fromRGB(200, 200, 255)
    else
        colorCorrection.TintColor = Color3.fromRGB(255, 255, 255)
    end
end

function SettingsManager:EnableHighContrast()
    -- Increase contrast for all UI elements
    for _, gui in pairs(self.PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") then
            for _, element in pairs(gui:GetDescendants()) do
                if element:IsA("Frame") then
                    if element.BackgroundTransparency < 0.5 then
                        element.BackgroundTransparency = 0
                    end
                end
            end
        end
    end
end

function SettingsManager:EnableLargeText()
    -- Increase text size for all UI elements
    for _, gui in pairs(self.PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") then
            for _, element in pairs(gui:GetDescendants()) do
                if element:IsA("TextLabel") or element:IsA("TextButton") then
                    element.TextScaled = true
                end
            end
        end
    end
end

function SettingsManager:ReduceAnimations()
    -- Disable or reduce animations
    for _, tween in pairs(TweenService:GetChildren()) do
        if tween:IsA("Tween") then
            tween:Cancel()
        end
    end
end

function SettingsManager:ApplyPerformanceSettings()
    local performance = self.CurrentSettings.performance
    
    -- Target FPS
    if performance.targetFPS then
        local settings = UserSettings():GetService("UserGameSettings")
        if settings then
            settings.FrameRateManager = performance.targetFPS
        end
    end
    
    -- Power saving mode
    if performance.powerSavingMode then
        self:EnablePowerSavingMode()
    end
    
    print("⚙️ SettingsManager: Applied performance settings")
end

function SettingsManager:EnablePowerSavingMode()
    -- Reduce quality settings for better performance
    self.CurrentSettings.graphics.quality = "Low"
    self.CurrentSettings.graphics.particleEffects = false
    self.CurrentSettings.graphics.shadows = false
    
    self:ApplyGraphicsSettings()
end

function SettingsManager:ApplyVIPSettings()
    if not self.IsVIP then return end
    
    local vip = self.CurrentSettings.vip
    
    -- Golden theme
    if vip.goldenTheme then
        self:ApplyColorTheme("VIP Gold")
    end
    
    -- Enhanced effects
    local vipEffectsManager = _G.VIPEffectsManager
    if vipEffectsManager then
        vipEffectsManager:SetEnhancedEffects(vip.exclusiveEffects)
        vipEffectsManager:SetEnhancedAnimations(vip.enhancedAnimations)
    end
    
    print("⚙️ SettingsManager: Applied VIP settings")
end

-- ==========================================
-- PERFORMANCE MONITORING
-- ==========================================

function SettingsManager:UpdatePerformanceData()
    local stats = game:GetService("Stats")
    
    -- FPS
    self.PerformanceData.fps = math.floor(1 / RunService.Heartbeat:Wait())
    
    -- Ping (approximation)
    local networkStats = stats:FindFirstChild("Network")
    if networkStats then
        local ping = networkStats:FindFirstChild("ServerStatsItem")
        if ping then
            self.PerformanceData.ping = ping["Data Ping"]:GetValue()
        end
    end
    
    -- Memory usage
    local memoryStats = stats:FindFirstChild("MemoryStats")
    if memoryStats then
        self.PerformanceData.memory = memoryStats.GetTotalMemoryUsageMb()
    end
    
    self.PerformanceData.lastUpdate = tick()
end

function SettingsManager:AutoAdjustQuality()
    local fps = self.PerformanceData.fps
    local currentQuality = self.CurrentSettings.graphics.quality
    
    -- Adjust quality based on FPS
    if fps < 30 and currentQuality ~= "Low" then
        self:SetSetting("graphics", "quality", "Low")
        self:ApplyGraphicsSettings()
        print("⚙️ SettingsManager: Auto-reduced quality due to low FPS")
        
    elseif fps > 50 and currentQuality == "Low" then
        self:SetSetting("graphics", "quality", "Medium")
        self:ApplyGraphicsSettings()
        print("⚙️ SettingsManager: Auto-increased quality due to good FPS")
    end
end

function SettingsManager:IsLowEndDevice()
    -- Detect low-end devices based on available information
    local totalMemory = self.PerformanceData.memory
    local fps = self.PerformanceData.fps
    
    return totalMemory < 2048 or fps < 30 -- Less than 2GB RAM or low FPS
end

function SettingsManager:ApplyMobileOptimizations()
    -- Mobile-specific optimizations
    self.CurrentSettings.graphics.quality = "Medium"
    self.CurrentSettings.graphics.shadows = false
    self.CurrentSettings.graphics.antiAliasing = false
    self.CurrentSettings.performance.powerSavingMode = true
    self.CurrentSettings.ui.compactMode = true
    
    print("⚙️ SettingsManager: Applied mobile optimizations")
end

function SettingsManager:ApplyLowEndOptimizations()
    -- Low-end device optimizations
    self.CurrentSettings.graphics.quality = "Low"
    self.CurrentSettings.graphics.particleEffects = false
    self.CurrentSettings.graphics.shadows = false
    self.CurrentSettings.graphics.lighting = "Low"
    self.CurrentSettings.performance.autoQuality = true
    
    print("⚙️ SettingsManager: Applied low-end device optimizations")
end

-- ==========================================
-- SETTINGS MODIFICATION
-- ==========================================

function SettingsManager:SetSetting(category, setting, value)
    if self.CurrentSettings[category] and self.CurrentSettings[category][setting] ~= nil then
        self.CurrentSettings[category][setting] = value
        
        -- Apply the specific setting change
        self:ApplySettingChange(category, setting, value)
        
        -- Auto-save after a delay
        spawn(function()
            wait(2)
            self:SaveSettings()
        end)
        
        return true
    end
    
    return false
end

function SettingsManager:ApplySettingChange(category, setting, value)
    if category == "graphics" then
        self:ApplyGraphicsSettings()
    elseif category == "audio" then
        self:ApplyAudioSettings()
    elseif category == "gameplay" then
        self:ApplyGameplaySettings()
    elseif category == "ui" then
        self:ApplyUISettings()
    elseif category == "accessibility" then
        self:ApplyAccessibilitySettings()
    elseif category == "performance" then
        self:ApplyPerformanceSettings()
    elseif category == "vip" then
        self:ApplyVIPSettings()
    end
end

function SettingsManager:GetSetting(category, setting)
    if self.CurrentSettings[category] then
        return self.CurrentSettings[category][setting]
    end
    return nil
end

function SettingsManager:ResetToDefaults()
    self.CurrentSettings = self:DeepCopyTable(self.DefaultSettings)
    self:ApplyAllSettings()
    self:SaveSettings()
    
    print("⚙️ SettingsManager: Reset all settings to defaults")
end

function SettingsManager:ResetCategory(category)
    if self.DefaultSettings[category] then
        self.CurrentSettings[category] = self:DeepCopyTable(self.DefaultSettings[category])
        self:ApplySettingChange(category, nil, nil)
        self:SaveSettings()
        
        print("⚙️ SettingsManager: Reset", category, "settings to defaults")
    end
end

-- ==========================================
-- VIP STATUS HANDLING
-- ==========================================

function SettingsManager:OnVIPStatusChanged(isVIP)
    local wasVIP = self.IsVIP
    self.IsVIP = isVIP
    
    if isVIP and not wasVIP then
        -- Became VIP - unlock VIP settings
        self:UnlockVIPSettings()
    elseif not isVIP and wasVIP then
        -- Lost VIP - disable VIP settings
        self:DisableVIPSettings()
    end
end

function SettingsManager:UnlockVIPSettings()
    -- Enable VIP exclusive features
    self.CurrentSettings.gameplay.autoPlant = false -- Available but not auto-enabled
    self.CurrentSettings.gameplay.autoClaim = false
    self.CurrentSettings.vip.goldenTheme = false
    self.CurrentSettings.vip.exclusiveEffects = true
    
    -- Notify player
    local notificationManager = _G.NotificationManager
    if notificationManager then
        notificationManager:ShowToast(
            "VIP Settings Unlocked! 👑",
            "Check the settings menu for exclusive VIP options!",
            "⚙️",
            "vip"
        )
    end
    
    print("⚙️ SettingsManager: Unlocked VIP settings")
end

function SettingsManager:DisableVIPSettings()
    -- Disable VIP exclusive features
    self.CurrentSettings.gameplay.autoPlant = false
    self.CurrentSettings.gameplay.autoClaim = false
    self.CurrentSettings.vip.goldenTheme = false
    self.CurrentSettings.vip.exclusiveEffects = false
    
    -- Apply changes
    self:ApplyAllSettings()
    
    print("⚙️ SettingsManager: Disabled VIP settings")
end

-- ==========================================
-- UTILITY FUNCTIONS
-- ==========================================

function SettingsManager:DeepCopyTable(original)
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

function SettingsManager:GetPerformanceData()
    return self.PerformanceData
end

function SettingsManager:GetDeviceInfo()
    return {
        isMobile = self.IsMobile,
        isLowEnd = self:IsLowEndDevice(),
        isVIP = self.IsVIP
    }
end

-- ==========================================
-- PUBLIC API
-- ==========================================

function SettingsManager:GetCurrentSettings()
    return self.CurrentSettings
end

function SettingsManager:GetSettingsCategories()
    local categories = {}
    
    for _, category in ipairs(self.SettingsCategories) do
        if not category.vipOnly or self.IsVIP then
            table.insert(categories, category)
        end
    end
    
    return categories
end

function SettingsManager:GetDefaultSettings()
    return self.DefaultSettings
end

function SettingsManager:ExportSettings()
    -- Export settings for backup/sharing
    local exported = {
        settings = self.CurrentSettings,
        version = "1.0",
        timestamp = tick(),
        deviceInfo = self:GetDeviceInfo()
    }
    
    return HttpService:JSONEncode(exported)
end

function SettingsManager:ImportSettings(settingsJson)
    local success, imported = pcall(function()
        return HttpService:JSONDecode(settingsJson)
    end)
    
    if success and imported.settings then
        self:MergeSettings(imported.settings)
        self:ApplyAllSettings()
        self:SaveSettings()
        return true
    end
    
    return false
end

function SettingsManager:ToggleSetting(category, setting)
    local currentValue = self:GetSetting(category, setting)
    if type(currentValue) == "boolean" then
        self:SetSetting(category, setting, not currentValue)
        return not currentValue
    end
    return nil
end

function SettingsManager:IncrementSetting(category, setting, increment)
    local currentValue = self:GetSetting(category, setting)
    if type(currentValue) == "number" then
        local newValue = math.max(0, math.min(1, currentValue + increment))
        self:SetSetting(category, setting, newValue)
        return newValue
    end
    return nil
end

-- ==========================================
-- CLEANUP
-- ==========================================

function SettingsManager:Cleanup()
    -- Save current settings
    self:SaveSettings()
    
    -- Clean up GUI if exists
    if self.SettingsGui then
        self.SettingsGui:Destroy()
    end
    
    print("⚙️ SettingsManager: Cleaned up settings system")
end

return SettingsManager
