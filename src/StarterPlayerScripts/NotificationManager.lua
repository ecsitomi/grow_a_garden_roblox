--[[
    NotificationManager.lua
    Client-Side Notification System
    
    Priority: 21 (VIP & Monetization phase)
    Dependencies: TweenService, SoundService, UIManager
    Used by: All game systems, achievements, economy, VIP features
    
    Features:
    - Toast notifications
    - Achievement unlocks
    - Economy alerts
    - VIP exclusive notifications
    - Sound integration
    - Queue management
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Load required modules
local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)

local NotificationManager = {}
NotificationManager.__index = NotificationManager

-- ==========================================
-- INITIALIZATION & SETUP
-- ==========================================

NotificationManager.Player = Players.LocalPlayer
NotificationManager.PlayerGui = NotificationManager.Player:WaitForChild("PlayerGui")

-- Notification containers
NotificationManager.NotificationGui = nil
NotificationManager.ToastContainer = nil
NotificationManager.AchievementContainer = nil
NotificationManager.AlertContainer = nil

-- Notification queue and state
NotificationManager.NotificationQueue = {}
NotificationManager.ActiveNotifications = {}
NotificationManager.ProcessingQueue = false
NotificationManager.MaxActiveNotifications = 5

-- Notification types and configurations
NotificationManager.NotificationTypes = {
    toast = {
        duration = 3,
        maxWidth = 300,
        backgroundColor = Color3.fromRGB(40, 40, 40),
        textColor = Color3.fromRGB(255, 255, 255),
        sound = "rbxasset://sounds/electronicpingset_01.wav"
    },
    
    achievement = {
        duration = 5,
        maxWidth = 400,
        backgroundColor = Color3.fromRGB(255, 215, 0),
        textColor = Color3.fromRGB(0, 0, 0),
        sound = "rbxasset://sounds/action_get_up.mp3"
    },
    
    economy = {
        duration = 4,
        maxWidth = 350,
        backgroundColor = Color3.fromRGB(46, 204, 113),
        textColor = Color3.fromRGB(255, 255, 255),
        sound = "rbxasset://sounds/impact_generic_light_03.wav"
    },
    
    warning = {
        duration = 6,
        maxWidth = 350,
        backgroundColor = Color3.fromRGB(231, 76, 60),
        textColor = Color3.fromRGB(255, 255, 255),
        sound = "rbxasset://sounds/action_footsteps_plastic.mp3"
    },
    
    vip = {
        duration = 6,
        maxWidth = 400,
        backgroundColor = Color3.fromRGB(155, 89, 182),
        textColor = Color3.fromRGB(255, 255, 255),
        sound = "rbxasset://sounds/action_get_up.mp3"
    },
    
    system = {
        duration = 4,
        maxWidth = 320,
        backgroundColor = Color3.fromRGB(52, 152, 219),
        textColor = Color3.fromRGB(255, 255, 255),
        sound = "rbxasset://sounds/electronicpingset_02.wav"
    }
}

-- VIP notification enhancements
NotificationManager.VIPEnhancements = {
    goldenBorder = true,
    sparkleEffect = true,
    enhancedSound = true,
    priorityQueue = true
}

-- ==========================================
-- INITIALIZATION
-- ==========================================

function NotificationManager:Initialize()
    print("🔔 NotificationManager: Initializing notification system...")
    
    -- Create notification GUI
    self:CreateNotificationGUI()
    
    -- Set up remote event listeners
    self:SetupRemoteEvents()
    
    -- Start queue processing
    self:StartQueueProcessing()
    
    -- Set up mobile optimizations
    self:SetupMobileOptimizations()
    
    print("✅ NotificationManager: Notification system initialized")
end

function NotificationManager:CreateNotificationGUI()
    -- Create main notification GUI
    self.NotificationGui = Instance.new("ScreenGui")
    self.NotificationGui.Name = "NotificationSystem"
    self.NotificationGui.ResetOnSpawn = false
    self.NotificationGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    self.NotificationGui.Parent = self.PlayerGui
    
    -- Create toast container (top-right)
    self.ToastContainer = Instance.new("Frame")
    self.ToastContainer.Name = "ToastContainer"
    self.ToastContainer.Size = UDim2.new(0, 350, 1, 0)
    self.ToastContainer.Position = UDim2.new(1, -370, 0, 20)
    self.ToastContainer.BackgroundTransparency = 1
    self.ToastContainer.Parent = self.NotificationGui
    
    -- Create achievement container (center-top)
    self.AchievementContainer = Instance.new("Frame")
    self.AchievementContainer.Name = "AchievementContainer"
    self.AchievementContainer.Size = UDim2.new(0, 450, 0, 200)
    self.AchievementContainer.Position = UDim2.new(0.5, -225, 0, 50)
    self.AchievementContainer.BackgroundTransparency = 1
    self.AchievementContainer.Parent = self.NotificationGui
    
    -- Create alert container (center)
    self.AlertContainer = Instance.new("Frame")
    self.AlertContainer.Name = "AlertContainer"
    self.AlertContainer.Size = UDim2.new(0, 400, 0, 300)
    self.AlertContainer.Position = UDim2.new(0.5, -200, 0.5, -150)
    self.AlertContainer.BackgroundTransparency = 1
    self.AlertContainer.Parent = self.NotificationGui
    
    -- Add layout for toast notifications
    local toastLayout = Instance.new("UIListLayout")
    toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
    toastLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    toastLayout.Padding = UDim.new(0, 10)
    toastLayout.Parent = self.ToastContainer
end

function NotificationManager:SetupRemoteEvents()
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then
        warn("❌ NotificationManager: RemoteEvents folder not found")
        return
    end
    
    -- Listen for server notifications
    local notificationEvent = remoteEvents:FindFirstChild("ShowNotification")
    if notificationEvent then
        notificationEvent.OnClientEvent:Connect(function(notificationData)
            self:ShowNotification(notificationData)
        end)
    end
    
    -- Listen for achievement unlocks
    local achievementEvent = remoteEvents:FindFirstChild("AchievementUnlocked")
    if achievementEvent then
        achievementEvent.OnClientEvent:Connect(function(achievementData)
            self:ShowAchievementNotification(achievementData)
        end)
    end
    
    -- Listen for economy updates
    local economyEvent = remoteEvents:FindFirstChild("EconomyUpdate")
    if economyEvent then
        economyEvent.OnClientEvent:Connect(function(updateType, amount, reason)
            self:ShowEconomyNotification(updateType, amount, reason)
        end)
    end
    
    -- Listen for VIP status changes
    local vipEvent = remoteEvents:FindFirstChild("VIPStatusUpdate")
    if vipEvent then
        vipEvent.OnClientEvent:Connect(function(isVIP, justPurchased)
            if justPurchased then
                self:ShowVIPWelcomeNotification()
            end
        end)
    end
end

function NotificationManager:StartQueueProcessing()
    spawn(function()
        while true do
            if not self.ProcessingQueue and #self.NotificationQueue > 0 then
                self:ProcessNotificationQueue()
            end
            wait(0.1)
        end
    end)
end

function NotificationManager:SetupMobileOptimizations()
    -- Adjust for mobile screens
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        -- Move containers for mobile
        self.ToastContainer.Position = UDim2.new(1, -360, 0, 10)
        self.ToastContainer.Size = UDim2.new(0, 340, 1, 0)
        
        self.AchievementContainer.Size = UDim2.new(0, 380, 0, 180)
        self.AchievementContainer.Position = UDim2.new(0.5, -190, 0, 40)
    end
end

-- ==========================================
-- QUEUE MANAGEMENT
-- ==========================================

function NotificationManager:QueueNotification(notificationData)
    -- Add priority for VIP notifications
    local priority = notificationData.priority or 1
    
    if self:IsVIPPlayer() and (notificationData.type == "vip" or notificationData.vipEnhanced) then
        priority = priority + 10
    end
    
    notificationData.priority = priority
    notificationData.timestamp = tick()
    
    table.insert(self.NotificationQueue, notificationData)
    
    -- Sort by priority (higher first)
    table.sort(self.NotificationQueue, function(a, b)
        return a.priority > b.priority
    end)
end

function NotificationManager:ProcessNotificationQueue()
    if #self.NotificationQueue == 0 then return end
    
    self.ProcessingQueue = true
    
    while #self.NotificationQueue > 0 and #self.ActiveNotifications < self.MaxActiveNotifications do
        local notification = table.remove(self.NotificationQueue, 1)
        self:DisplayNotification(notification)
        wait(0.2) -- Small delay between notifications
    end
    
    self.ProcessingQueue = false
end

function NotificationManager:DisplayNotification(notificationData)
    local notificationType = notificationData.type or "toast"
    
    if notificationType == "achievement" then
        self:CreateAchievementNotification(notificationData)
    elseif notificationType == "economy" then
        self:CreateEconomyNotification(notificationData)
    elseif notificationType == "alert" then
        self:CreateAlertNotification(notificationData)
    else
        self:CreateToastNotification(notificationData)
    end
    
    -- Play notification sound
    self:PlayNotificationSound(notificationType)
end

-- ==========================================
-- TOAST NOTIFICATIONS
-- ==========================================

function NotificationManager:CreateToastNotification(data)
    local config = self.NotificationTypes[data.type] or self.NotificationTypes.toast
    
    -- Create notification frame
    local notification = Instance.new("Frame")
    notification.Name = "ToastNotification"
    notification.Size = UDim2.new(0, config.maxWidth, 0, 80)
    notification.Position = UDim2.new(1, 0, 0, 0) -- Start off-screen
    notification.BackgroundColor3 = config.backgroundColor
    notification.BorderSizePixel = 0
    notification.LayoutOrder = tick()
    notification.Parent = self.ToastContainer
    
    -- Add corner radius
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = notification
    
    -- Add VIP enhancements if applicable
    if self:IsVIPPlayer() and data.vipEnhanced then
        self:AddVIPEnhancements(notification)
    end
    
    -- Create icon
    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(0, 40, 0, 40)
    icon.Position = UDim2.new(0, 15, 0.5, -20)
    icon.BackgroundTransparency = 1
    icon.Text = data.icon or "🔔"
    icon.TextScaled = true
    icon.TextColor3 = config.textColor
    icon.Font = Enum.Font.SourceSansBold
    icon.Parent = notification
    
    -- Create title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -70, 0, 25)
    title.Position = UDim2.new(0, 60, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = data.title or "Notification"
    title.TextScaled = true
    title.TextColor3 = config.textColor
    title.Font = Enum.Font.SourceSansBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = notification
    
    -- Create message
    local message = Instance.new("TextLabel")
    message.Size = UDim2.new(1, -70, 0, 20)
    message.Position = UDim2.new(0, 60, 0, 35)
    message.BackgroundTransparency = 1
    message.Text = data.message or ""
    message.TextScaled = true
    message.TextColor3 = config.textColor
    message.Font = Enum.Font.SourceSans
    message.TextXAlignment = Enum.TextXAlignment.Left
    message.TextWrapped = true
    message.Parent = notification
    
    -- Add to active notifications
    table.insert(self.ActiveNotifications, notification)
    
    -- Animate in
    self:AnimateToastIn(notification, config.duration)
end

function NotificationManager:AnimateToastIn(notification, duration)
    -- Slide in animation
    local slideIn = TweenService:Create(
        notification,
        TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = UDim2.new(0, 0, 0, 0)}
    )
    
    slideIn:Play()
    
    -- Auto-dismiss after duration
    spawn(function()
        wait(duration)
        self:DismissToastNotification(notification)
    end)
    
    -- Click to dismiss
    local clickDetector = Instance.new("TextButton")
    clickDetector.Size = UDim2.new(1, 0, 1, 0)
    clickDetector.BackgroundTransparency = 1
    clickDetector.Text = ""
    clickDetector.Parent = notification
    
    clickDetector.Activated:Connect(function()
        self:DismissToastNotification(notification)
    end)
end

function NotificationManager:DismissToastNotification(notification)
    if not notification or not notification.Parent then return end
    
    -- Slide out animation
    local slideOut = TweenService:Create(
        notification,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {Position = UDim2.new(1, 50, 0, 0), Size = UDim2.new(0, 0, 0, 80)}
    )
    
    slideOut:Play()
    slideOut.Completed:Connect(function()
        -- Remove from active notifications
        for i, activeNotification in ipairs(self.ActiveNotifications) do
            if activeNotification == notification then
                table.remove(self.ActiveNotifications, i)
                break
            end
        end
        
        notification:Destroy()
    end)
end

-- ==========================================
-- ACHIEVEMENT NOTIFICATIONS
-- ==========================================

function NotificationManager:CreateAchievementNotification(data)
    local config = self.NotificationTypes.achievement
    
    -- Create achievement frame
    local achievement = Instance.new("Frame")
    achievement.Name = "AchievementNotification"
    achievement.Size = UDim2.new(0, 450, 0, 120)
    achievement.Position = UDim2.new(0.5, -225, 0, -150) -- Start above screen
    achievement.BackgroundColor3 = config.backgroundColor
    achievement.BorderSizePixel = 0
    achievement.ZIndex = 10
    achievement.Parent = self.AchievementContainer
    
    -- Add gradient background
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 235, 59)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 193, 7))
    }
    gradient.Parent = achievement
    
    -- Add corner radius
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 15)
    corner.Parent = achievement
    
    -- Add VIP enhancements
    if self:IsVIPPlayer() then
        self:AddVIPEnhancements(achievement, true)
    end
    
    -- Create header
    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, -20, 0, 30)
    header.Position = UDim2.new(0, 10, 0, 5)
    header.BackgroundTransparency = 1
    header.Text = "🏆 ACHIEVEMENT UNLOCKED! 🏆"
    header.TextScaled = true
    header.TextColor3 = Color3.fromRGB(139, 69, 19)
    header.Font = Enum.Font.SourceSansBold
    header.Parent = achievement
    
    -- Create achievement icon
    local achievementIcon = Instance.new("TextLabel")
    achievementIcon.Size = UDim2.new(0, 50, 0, 50)
    achievementIcon.Position = UDim2.new(0, 15, 0, 40)
    achievementIcon.BackgroundTransparency = 1
    achievementIcon.Text = data.icon or "🏆"
    achievementIcon.TextScaled = true
    achievementIcon.TextColor3 = Color3.fromRGB(139, 69, 19)
    achievementIcon.Font = Enum.Font.SourceSansBold
    achievementIcon.Parent = achievement
    
    -- Create achievement name
    local achievementName = Instance.new("TextLabel")
    achievementName.Size = UDim2.new(1, -80, 0, 25)
    achievementName.Position = UDim2.new(0, 70, 0, 40)
    achievementName.BackgroundTransparency = 1
    achievementName.Text = data.name or "Achievement"
    achievementName.TextScaled = true
    achievementName.TextColor3 = Color3.fromRGB(139, 69, 19)
    achievementName.Font = Enum.Font.SourceSansBold
    achievementName.TextXAlignment = Enum.TextXAlignment.Left
    achievementName.Parent = achievement
    
    -- Create achievement description
    local achievementDesc = Instance.new("TextLabel")
    achievementDesc.Size = UDim2.new(1, -80, 0, 20)
    achievementDesc.Position = UDim2.new(0, 70, 0, 65)
    achievementDesc.BackgroundTransparency = 1
    achievementDesc.Text = data.description or ""
    achievementDesc.TextScaled = true
    achievementDesc.TextColor3 = Color3.fromRGB(101, 67, 33)
    achievementDesc.Font = Enum.Font.SourceSans
    achievementDesc.TextXAlignment = Enum.TextXAlignment.Left
    achievementDesc.TextWrapped = true
    achievementDesc.Parent = achievement
    
    -- Create rewards text
    if data.rewards then
        local rewardsText = self:FormatRewards(data.rewards)
        local rewards = Instance.new("TextLabel")
        rewards.Size = UDim2.new(1, -80, 0, 15)
        rewards.Position = UDim2.new(0, 70, 0, 90)
        rewards.BackgroundTransparency = 1
        rewards.Text = rewardsText
        rewards.TextScaled = true
        rewards.TextColor3 = Color3.fromRGB(76, 175, 80)
        rewards.Font = Enum.Font.SourceSansBold
        rewards.TextXAlignment = Enum.TextXAlignment.Left
        rewards.Parent = achievement
    end
    
    -- Add to active notifications
    table.insert(self.ActiveNotifications, achievement)
    
    -- Animate achievement
    self:AnimateAchievementIn(achievement)
end

function NotificationManager:AnimateAchievementIn(achievement)
    -- Bounce in animation
    local bounceIn = TweenService:Create(
        achievement,
        TweenInfo.new(0.8, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5, -225, 0, 0)}
    )
    
    bounceIn:Play()
    
    -- Create sparkle effect if VIP
    if self:IsVIPPlayer() then
        self:CreateSparkleEffect(achievement)
    end
    
    -- Auto-dismiss after 5 seconds
    spawn(function()
        wait(5)
        self:DismissAchievementNotification(achievement)
    end)
    
    -- Click to dismiss
    local clickDetector = Instance.new("TextButton")
    clickDetector.Size = UDim2.new(1, 0, 1, 0)
    clickDetector.BackgroundTransparency = 1
    clickDetector.Text = ""
    clickDetector.Parent = achievement
    
    clickDetector.Activated:Connect(function()
        self:DismissAchievementNotification(achievement)
    end)
end

function NotificationManager:DismissAchievementNotification(achievement)
    if not achievement or not achievement.Parent then return end
    
    -- Slide up and fade
    local dismissTween = TweenService:Create(
        achievement,
        TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {Position = UDim2.new(0.5, -225, 0, -150), BackgroundTransparency = 1}
    )
    
    dismissTween:Play()
    dismissTween.Completed:Connect(function()
        -- Remove from active notifications
        for i, activeNotification in ipairs(self.ActiveNotifications) do
            if activeNotification == achievement then
                table.remove(self.ActiveNotifications, i)
                break
            end
        end
        
        achievement:Destroy()
    end)
end

-- ==========================================
-- ECONOMY NOTIFICATIONS
-- ==========================================

function NotificationManager:CreateEconomyNotification(updateType, amount, reason)
    local title = ""
    local icon = ""
    local message = ""
    
    if updateType == "coins_gained" then
        title = "Coins Earned!"
        icon = "💰"
        message = "+" .. ConfigModule.FormatNumber(amount) .. " coins"
        if reason then
            message = message .. " (" .. reason .. ")"
        end
    elseif updateType == "coins_spent" then
        title = "Purchase Complete"
        icon = "🛒"
        message = "-" .. ConfigModule.FormatNumber(amount) .. " coins"
    elseif updateType == "xp_gained" then
        title = "Experience Gained!"
        icon = "⭐"
        message = "+" .. amount .. " XP"
    elseif updateType == "level_up" then
        title = "Level Up!"
        icon = "🎉"
        message = "You reached level " .. amount .. "!"
    end
    
    local notificationData = {
        type = "economy",
        title = title,
        message = message,
        icon = icon,
        priority = 3,
        vipEnhanced = true
    }
    
    self:QueueNotification(notificationData)
end

-- ==========================================
-- VIP ENHANCEMENTS
-- ==========================================

function NotificationManager:AddVIPEnhancements(notification, isAchievement)
    isAchievement = isAchievement or false
    
    if not self:IsVIPPlayer() then return end
    
    -- Add golden border
    local border = Instance.new("UIStroke")
    border.Color = Color3.fromRGB(255, 215, 0)
    border.Thickness = 3
    border.Transparency = 0.3
    border.Parent = notification
    
    -- Add subtle glow effect
    local glow = Instance.new("ImageLabel")
    glow.Size = UDim2.new(1, 20, 1, 20)
    glow.Position = UDim2.new(0, -10, 0, -10)
    glow.BackgroundTransparency = 1
    glow.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png" -- Replace with glow texture
    glow.ImageColor3 = Color3.fromRGB(255, 215, 0)
    glow.ImageTransparency = 0.7
    glow.ZIndex = notification.ZIndex - 1
    glow.Parent = notification
    
    if isAchievement then
        -- Add crown for VIP achievements
        local crown = Instance.new("TextLabel")
        crown.Size = UDim2.new(0, 30, 0, 30)
        crown.Position = UDim2.new(1, -35, 0, 5)
        crown.BackgroundTransparency = 1
        crown.Text = "👑"
        crown.TextScaled = true
        crown.ZIndex = 15
        crown.Parent = notification
        
        -- Animate crown
        local crownTween = TweenService:Create(
            crown,
            TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            {Rotation = 10}
        )
        crownTween:Play()
    end
end

function NotificationManager:CreateSparkleEffect(parent)
    for i = 1, 8 do
        local sparkle = Instance.new("TextLabel")
        sparkle.Size = UDim2.new(0, 15, 0, 15)
        sparkle.Position = UDim2.new(
            math.random(0, 100) / 100,
            math.random(-20, 20),
            math.random(0, 100) / 100,
            math.random(-20, 20)
        )
        sparkle.BackgroundTransparency = 1
        sparkle.Text = "✨"
        sparkle.TextScaled = true
        sparkle.TextColor3 = Color3.fromRGB(255, 215, 0)
        sparkle.ZIndex = 20
        sparkle.Parent = parent
        
        -- Animate sparkle
        local sparkleAnim = TweenService:Create(
            sparkle,
            TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {
                Position = UDim2.new(
                    sparkle.Position.X.Scale + (math.random(-50, 50) / 100),
                    sparkle.Position.X.Offset,
                    sparkle.Position.Y.Scale + (math.random(-50, 50) / 100),
                    sparkle.Position.Y.Offset
                ),
                TextTransparency = 1,
                Size = UDim2.new(0, 5, 0, 5)
            }
        )
        
        sparkleAnim:Play()
        sparkleAnim.Completed:Connect(function()
            sparkle:Destroy()
        end)
    end
end

function NotificationManager:ShowVIPWelcomeNotification()
    local notificationData = {
        type = "vip",
        title = "Welcome to VIP! 👑",
        message = "You now have access to exclusive VIP features and 3x bonuses!",
        icon = "💎",
        priority = 10,
        vipEnhanced = true
    }
    
    self:QueueNotification(notificationData)
    
    -- Show special achievement-style notification
    spawn(function()
        wait(1)
        local achievementData = {
            name = "VIP Garden Club Member",
            description = "Welcome to the exclusive VIP experience!",
            icon = "👑",
            rewards = {coins = 5000, xp = 500}
        }
        self:CreateAchievementNotification(achievementData)
    end)
end

-- ==========================================
-- UTILITY FUNCTIONS
-- ==========================================

function NotificationManager:FormatRewards(rewards)
    local rewardTexts = {}
    
    if rewards.coins then
        table.insert(rewardTexts, "💰 " .. ConfigModule.FormatNumber(rewards.coins) .. " coins")
    end
    
    if rewards.xp then
        table.insert(rewardTexts, "⭐ " .. rewards.xp .. " XP")
    end
    
    if rewards.special_plant then
        table.insert(rewardTexts, "🌟 Special Plant: " .. rewards.special_plant)
    end
    
    if rewards.title then
        table.insert(rewardTexts, "🏷️ Title: " .. rewards.title)
    end
    
    return table.concat(rewardTexts, " • ")
end

function NotificationManager:PlayNotificationSound(notificationType)
    local config = self.NotificationTypes[notificationType] or self.NotificationTypes.toast
    
    if config.sound then
        local sound = Instance.new("Sound")
        sound.SoundId = config.sound
        sound.Volume = 0.5
        
        -- Enhanced sound for VIP
        if self:IsVIPPlayer() then
            sound.Volume = 0.7
            sound.Pitch = 1.1
        end
        
        sound.Parent = SoundService
        sound:Play()
        
        sound.Ended:Connect(function()
            sound:Destroy()
        end)
    end
end

function NotificationManager:IsVIPPlayer()
    -- Check VIP status from VIP manager
    local vipManager = _G.VIPManager
    if vipManager then
        return vipManager:IsPlayerVIP(self.Player)
    end
    return false
end

-- ==========================================
-- PUBLIC API
-- ==========================================

function NotificationManager:ShowNotification(data)
    self:QueueNotification(data)
end

function NotificationManager:ShowToast(title, message, icon, notificationType)
    local data = {
        type = notificationType or "toast",
        title = title,
        message = message,
        icon = icon or "🔔",
        priority = 1
    }
    
    self:QueueNotification(data)
end

function NotificationManager:ShowWarning(title, message)
    local data = {
        type = "warning",
        title = title,
        message = message,
        icon = "⚠️",
        priority = 5
    }
    
    self:QueueNotification(data)
end

function NotificationManager:ShowSystemMessage(message)
    local data = {
        type = "system",
        title = "System",
        message = message,
        icon = "ℹ️",
        priority = 2
    }
    
    self:QueueNotification(data)
end

function NotificationManager:ShowAchievementNotification(achievementData)
    self:CreateAchievementNotification(achievementData)
end

function NotificationManager:ShowEconomyNotification(updateType, amount, reason)
    self:CreateEconomyNotification(updateType, amount, reason)
end

function NotificationManager:ClearAllNotifications()
    -- Clear queue
    self.NotificationQueue = {}
    
    -- Dismiss all active notifications
    for _, notification in ipairs(self.ActiveNotifications) do
        if notification and notification.Parent then
            self:DismissToastNotification(notification)
        end
    end
end

function NotificationManager:GetActiveNotificationCount()
    return #self.ActiveNotifications
end

function NotificationManager:GetQueuedNotificationCount()
    return #self.NotificationQueue
end

-- ==========================================
-- CLEANUP
-- ==========================================

function NotificationManager:Cleanup()
    self:ClearAllNotifications()
    
    if self.NotificationGui then
        self.NotificationGui:Destroy()
    end
    
    print("🔔 NotificationManager: Cleaned up notification system")
end

return NotificationManager
