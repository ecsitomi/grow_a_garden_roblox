--[[
    OfflineProgressUI.lua
    Client-Side Offline Earnings Display System
    
    Priority: 17 (VIP & Monetization phase)
    Dependencies: VIPManager, UIManager, ConfigModule
    Used by: Player login events, offline progress calculations
    
    Features:
    - Welcome back screen with offline earnings
    - VIP 2x multiplier visualization
    - Time away calculation display
    - Animated rewards counter
    - Mobile-optimized layout
    - Claim button integration
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- Load required modules
local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)

local OfflineProgressUI = {}
OfflineProgressUI.__index = OfflineProgressUI

-- ==========================================
-- UI REFERENCES & STATE
-- ==========================================

OfflineProgressUI.Player = Players.LocalPlayer
OfflineProgressUI.PlayerGui = nil
OfflineProgressUI.OfflineProgressGui = nil
OfflineProgressUI.IsShowing = false

-- Animation states
OfflineProgressUI.CountingTweens = {}
OfflineProgressUI.ShowDuration = 8 -- Show UI for 8 seconds

-- ==========================================
-- INITIALIZATION
-- ==========================================

function OfflineProgressUI:Initialize()
    print("⏰ OfflineProgressUI: Initializing offline progress display...")
    
    -- Wait for player GUI
    self.Player.CharacterAdded:Connect(function()
        wait(2) -- Wait for character to load
        self.PlayerGui = self.Player:WaitForChild("PlayerGui")
        self:SetupRemoteEvents()
    end)
    
    -- If character already exists
    if self.Player.Character then
        self.PlayerGui = self.Player:WaitForChild("PlayerGui")
        self:SetupRemoteEvents()
    end
    
    print("✅ OfflineProgressUI: Offline progress UI initialized")
end

function OfflineProgressUI:SetupRemoteEvents()
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then
        warn("❌ OfflineProgressUI: RemoteEvents folder not found")
        return
    end
    
    -- Listen for offline progress data
    local showOfflineProgressEvent = remoteEvents:FindFirstChild("ShowOfflineProgress")
    if showOfflineProgressEvent then
        showOfflineProgressEvent.OnClientEvent:Connect(function(progressData)
            self:ShowOfflineProgress(progressData)
        end)
        print("🔗 OfflineProgressUI: Connected to ShowOfflineProgress event")
    end
end

-- ==========================================
-- MAIN UI CREATION
-- ==========================================

function OfflineProgressUI:ShowOfflineProgress(progressData)
    if not progressData or self.IsShowing then
        return
    end
    
    -- Validate progress data
    if not progressData.timeOffline or progressData.timeOffline < 60 then
        return -- Don't show for less than 1 minute offline
    end
    
    self.IsShowing = true
    
    -- Create the UI
    self:CreateOfflineProgressUI(progressData)
    
    -- Animate the appearance
    self:AnimateProgressAppearance(progressData)
    
    print("⏰ OfflineProgressUI: Showing offline progress for", progressData.timeOffline, "seconds")
end

function OfflineProgressUI:CreateOfflineProgressUI(progressData)
    -- Create main ScreenGui
    self.OfflineProgressGui = Instance.new("ScreenGui")
    self.OfflineProgressGui.Name = "OfflineProgressUI"
    self.OfflineProgressGui.ResetOnSpawn = false
    self.OfflineProgressGui.DisplayOrder = 100 -- High priority overlay
    self.OfflineProgressGui.Parent = self.PlayerGui
    
    -- Create background overlay
    local backgroundOverlay = self:CreateBackgroundOverlay()
    backgroundOverlay.Parent = self.OfflineProgressGui
    
    -- Create main content frame
    local mainFrame = self:CreateMainContentFrame(progressData)
    mainFrame.Parent = self.OfflineProgressGui
    
    -- Create header section
    self:CreateHeaderSection(mainFrame, progressData)
    
    -- Create offline time display
    self:CreateOfflineTimeDisplay(mainFrame, progressData)
    
    -- Create earnings display
    self:CreateEarningsDisplay(mainFrame, progressData)
    
    -- Create VIP benefits display (if applicable)
    if progressData.isVIP then
        self:CreateVIPBenefitsDisplay(mainFrame, progressData)
    end
    
    -- Create action buttons
    self:CreateActionButtons(mainFrame, progressData)
end

function OfflineProgressUI:CreateBackgroundOverlay()
    local overlay = Instance.new("Frame")
    overlay.Name = "BackgroundOverlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.Position = UDim2.new(0, 0, 0, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.3
    overlay.BorderSizePixel = 0
    
    return overlay
end

function OfflineProgressUI:CreateMainContentFrame(progressData)
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainContentFrame"
    mainFrame.Size = UDim2.new(0.85, 0, 0.7, 0)
    mainFrame.Position = UDim2.new(0.075, 0, 0.15, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    mainFrame.BorderSizePixel = 0
    
    -- Add corner radius
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = mainFrame
    
    -- Add drop shadow
    local shadow = Instance.new("Frame")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 8, 1, 8)
    shadow.Position = UDim2.new(0, -4, 0, -4)
    shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow.BackgroundTransparency = 0.6
    shadow.ZIndex = mainFrame.ZIndex - 1
    shadow.Parent = mainFrame
    
    local shadowCorner = Instance.new("UICorner")
    shadowCorner.CornerRadius = UDim.new(0, 16)
    shadowCorner.Parent = shadow
    
    -- Add content layout
    local contentLayout = Instance.new("UIListLayout")
    contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    contentLayout.Padding = UDim.new(0, 10)
    contentLayout.Parent = mainFrame
    
    return mainFrame
end

function OfflineProgressUI:CreateHeaderSection(parent, progressData)
    local headerFrame = Instance.new("Frame")
    headerFrame.Name = "HeaderFrame"
    headerFrame.Size = UDim2.new(1, -20, 0, 80)
    headerFrame.Position = UDim2.new(0, 10, 0, 10)
    headerFrame.BackgroundColor3 = Color3.fromRGB(60, 120, 180)
    headerFrame.BorderSizePixel = 0
    headerFrame.LayoutOrder = 1
    headerFrame.Parent = parent
    
    -- Header corner radius
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 12)
    headerCorner.Parent = headerFrame
    
    -- Welcome back title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(1, -20, 0, 40)
    titleLabel.Position = UDim2.new(0, 10, 0, 5)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "🌅 Welcome Back!"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextScaled = true
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Parent = headerFrame
    
    -- Subtitle
    local subtitleLabel = Instance.new("TextLabel")
    subtitleLabel.Name = "SubtitleLabel"  
    subtitleLabel.Size = UDim2.new(1, -20, 0, 30)
    subtitleLabel.Position = UDim2.new(0, 10, 0, 45)
    subtitleLabel.BackgroundTransparency = 1
    subtitleLabel.Text = "Your garden continued growing while you were away"
    subtitleLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
    subtitleLabel.TextScaled = true
    subtitleLabel.Font = Enum.Font.Gotham
    subtitleLabel.Parent = headerFrame
end

function OfflineProgressUI:CreateOfflineTimeDisplay(parent, progressData)
    local timeFrame = Instance.new("Frame")
    timeFrame.Name = "OfflineTimeFrame"
    timeFrame.Size = UDim2.new(1, -20, 0, 60)
    timeFrame.Position = UDim2.new(0, 10, 0, 0)
    timeFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    timeFrame.BorderSizePixel = 0
    timeFrame.LayoutOrder = 2
    timeFrame.Parent = parent
    
    local timeCorner = Instance.new("UICorner")
    timeCorner.CornerRadius = UDim.new(0, 10)
    timeCorner.Parent = timeFrame
    
    -- Time away icon
    local timeIcon = Instance.new("TextLabel")
    timeIcon.Name = "TimeIcon"
    timeIcon.Size = UDim2.new(0, 50, 1, 0)
    timeIcon.Position = UDim2.new(0, 10, 0, 0)
    timeIcon.BackgroundTransparency = 1
    timeIcon.Text = "⏰"
    timeIcon.TextScaled = true
    timeIcon.Font = Enum.Font.Gotham
    timeIcon.Parent = timeFrame
    
    -- Time away text
    local timeText = Instance.new("TextLabel")
    timeText.Name = "TimeAwayText"
    timeText.Size = UDim2.new(1, -70, 1, 0)
    timeText.Position = UDim2.new(0, 60, 0, 0)
    timeText.BackgroundTransparency = 1
    timeText.TextColor3 = Color3.fromRGB(255, 255, 255)
    timeText.TextScaled = true
    timeText.Font = Enum.Font.GothamBold
    timeText.TextXAlignment = Enum.TextXAlignment.Left
    timeText.Parent = timeFrame
    
    -- Format offline time
    local timeOffline = progressData.timeOffline
    local hours = math.floor(timeOffline / 3600)
    local minutes = math.floor((timeOffline % 3600) / 60)
    
    if hours > 0 then
        timeText.Text = string.format("Time Away: %d hours %d minutes", hours, minutes)
    else
        timeText.Text = string.format("Time Away: %d minutes", minutes)
    end
end

function OfflineProgressUI:CreateEarningsDisplay(parent, progressData)
    local earningsFrame = Instance.new("Frame")
    earningsFrame.Name = "EarningsFrame"
    earningsFrame.Size = UDim2.new(1, -20, 0, 120)
    earningsFrame.Position = UDim2.new(0, 10, 0, 0)
    earningsFrame.BackgroundColor3 = Color3.fromRGB(50, 80, 50)
    earningsFrame.BorderSizePixel = 0
    earningsFrame.LayoutOrder = 3
    earningsFrame.Parent = parent
    
    local earningsCorner = Instance.new("UICorner")
    earningsCorner.CornerRadius = UDim.new(0, 10)
    earningsCorner.Parent = earningsFrame
    
    -- Earnings title
    local earningsTitle = Instance.new("TextLabel")
    earningsTitle.Name = "EarningsTitle"
    earningsTitle.Size = UDim2.new(1, -20, 0, 30)
    earningsTitle.Position = UDim2.new(0, 10, 0, 10)
    earningsTitle.BackgroundTransparency = 1
    earningsTitle.Text = "💰 Offline Earnings"
    earningsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    earningsTitle.TextScaled = true
    earningsTitle.Font = Enum.Font.GothamBold
    earningsTitle.TextXAlignment = Enum.TextXAlignment.Left
    earningsTitle.Parent = earningsFrame
    
    -- Create earnings grid
    local earningsGrid = Instance.new("Frame")
    earningsGrid.Name = "EarningsGrid"
    earningsGrid.Size = UDim2.new(1, -20, 0, 70)
    earningsGrid.Position = UDim2.new(0, 10, 0, 40)
    earningsGrid.BackgroundTransparency = 1
    earningsGrid.Parent = earningsFrame
    
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0.5, -10, 0, 30)
    gridLayout.CellPadding = UDim2.new(0, 10, 0, 5)
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = earningsGrid
    
    -- Coins earned
    local coinsEarned = self:CreateEarningItem("💰 Coins", progressData.totalCoins or 0, 1)
    coinsEarned.Parent = earningsGrid
    
    -- XP earned
    local xpEarned = self:CreateEarningItem("⭐ XP", progressData.totalXP or 0, 2)
    xpEarned.Parent = earningsGrid
    
    -- Plants harvested
    local plantsHarvested = self:CreateEarningItem("🌱 Plants", progressData.harvestedPlants or 0, 3)
    plantsHarvested.Parent = earningsGrid
    
    -- Store references for animation
    self.CoinsLabel = coinsEarned:FindFirstChild("ValueLabel")
    self.XPLabel = xpEarned:FindFirstChild("ValueLabel")
    self.PlantsLabel = plantsHarvested:FindFirstChild("ValueLabel")
end

function OfflineProgressUI:CreateEarningItem(label, value, layoutOrder)
    local itemFrame = Instance.new("Frame")
    itemFrame.Name = label:gsub(" ", "") .. "Item"
    itemFrame.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    itemFrame.BorderSizePixel = 0
    itemFrame.LayoutOrder = layoutOrder
    
    local itemCorner = Instance.new("UICorner")
    itemCorner.CornerRadius = UDim.new(0, 6)
    itemCorner.Parent = itemFrame
    
    -- Label
    local itemLabel = Instance.new("TextLabel")
    itemLabel.Name = "ItemLabel"
    itemLabel.Size = UDim2.new(1, -10, 0.5, 0)
    itemLabel.Position = UDim2.new(0, 5, 0, 0)
    itemLabel.BackgroundTransparency = 1
    itemLabel.Text = label
    itemLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    itemLabel.TextScaled = true
    itemLabel.Font = Enum.Font.Gotham
    itemLabel.Parent = itemFrame
    
    -- Value
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Name = "ValueLabel"
    valueLabel.Size = UDim2.new(1, -10, 0.5, 0)
    valueLabel.Position = UDim2.new(0, 5, 0.5, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = "0" -- Will be animated to actual value
    valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    valueLabel.TextScaled = true
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.Parent = itemFrame
    
    return itemFrame
end

function OfflineProgressUI:CreateVIPBenefitsDisplay(parent, progressData)
    local vipFrame = Instance.new("Frame")
    vipFrame.Name = "VIPBenefitsFrame"
    vipFrame.Size = UDim2.new(1, -20, 0, 80)
    vipFrame.Position = UDim2.new(0, 10, 0, 0)
    vipFrame.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
    vipFrame.BorderSizePixel = 0
    vipFrame.LayoutOrder = 4
    vipFrame.Parent = parent
    
    local vipCorner = Instance.new("UICorner")
    vipCorner.CornerRadius = UDim.new(0, 10)
    vipCorner.Parent = vipFrame
    
    -- VIP crown icon
    local crownIcon = Instance.new("TextLabel")
    crownIcon.Name = "CrownIcon"
    crownIcon.Size = UDim2.new(0, 60, 1, 0)
    crownIcon.Position = UDim2.new(0, 10, 0, 0)
    crownIcon.BackgroundTransparency = 1
    crownIcon.Text = "👑"
    crownIcon.TextScaled = true
    crownIcon.Font = Enum.Font.Gotham
    crownIcon.Parent = vipFrame
    
    -- VIP benefit text
    local vipText = Instance.new("TextLabel")
    vipText.Name = "VIPBenefitText"
    vipText.Size = UDim2.new(1, -80, 1, -20)
    vipText.Position = UDim2.new(0, 70, 0, 10)
    vipText.BackgroundTransparency = 1
    vipText.Text = "VIP Bonus Applied!\n2x Offline Earnings"
    vipText.TextColor3 = Color3.fromRGB(0, 0, 0)
    vipText.TextScaled = true
    vipText.Font = Enum.Font.GothamBold
    vipText.TextXAlignment = Enum.TextXAlignment.Left
    vipText.Parent = vipFrame
    
    -- Add golden glow effect
    local glowEffect = Instance.new("UIStroke")
    glowEffect.Color = Color3.fromRGB(255, 255, 0)
    glowEffect.Thickness = 2
    glowEffect.Transparency = 0.5
    glowEffect.Parent = vipFrame
end

function OfflineProgressUI:CreateActionButtons(parent, progressData)
    local buttonsFrame = Instance.new("Frame")
    buttonsFrame.Name = "ActionButtonsFrame"
    buttonsFrame.Size = UDim2.new(1, -20, 0, 60)
    buttonsFrame.Position = UDim2.new(0, 10, 0, 0)
    buttonsFrame.BackgroundTransparency = 1
    buttonsFrame.LayoutOrder = 5
    buttonsFrame.Parent = parent
    
    -- Claim button
    local claimButton = Instance.new("TextButton")
    claimButton.Name = "ClaimButton"
    claimButton.Size = UDim2.new(0.6, -5, 1, 0)
    claimButton.Position = UDim2.new(0, 0, 0, 0)
    claimButton.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
    claimButton.BorderSizePixel = 0
    claimButton.Text = "🎁 Claim Rewards"
    claimButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    claimButton.TextScaled = true
    claimButton.Font = Enum.Font.GothamBold
    claimButton.Parent = buttonsFrame
    
    local claimCorner = Instance.new("UICorner")
    claimCorner.CornerRadius = UDim.new(0, 10)
    claimCorner.Parent = claimButton
    
    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0.4, -5, 1, 0)
    closeButton.Position = UDim2.new(0.6, 5, 0, 0)
    closeButton.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
    closeButton.BorderSizePixel = 0
    closeButton.Text = "✕ Close"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextScaled = true
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Parent = buttonsFrame
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 10)
    closeCorner.Parent = closeButton
    
    -- Button functionality
    claimButton.MouseButton1Click:Connect(function()
        self:ClaimOfflineRewards(progressData)
    end)
    
    closeButton.MouseButton1Click:Connect(function()
        self:HideOfflineProgress()
    end)
    
    -- Add hover effects
    self:AddButtonHoverEffect(claimButton, Color3.fromRGB(80, 200, 80), Color3.fromRGB(100, 220, 100))
    self:AddButtonHoverEffect(closeButton, Color3.fromRGB(120, 120, 120), Color3.fromRGB(140, 140, 140))
end

-- ==========================================
-- ANIMATION SYSTEM
-- ==========================================

function OfflineProgressUI:AnimateProgressAppearance(progressData)
    local mainFrame = self.OfflineProgressGui:FindFirstChild("MainContentFrame")
    if not mainFrame then return end
    
    -- Start with invisible and small
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    
    -- Animate appearance
    local appearTween = TweenService:Create(mainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
        Size = UDim2.new(0.85, 0, 0.7, 0),
        Position = UDim2.new(0.075, 0, 0.15, 0)
    })
    
    appearTween:Play()
    
    -- Wait for appearance to complete, then animate numbers
    appearTween.Completed:Connect(function()
        self:AnimateNumbers(progressData)
    end)
end

function OfflineProgressUI:AnimateNumbers(progressData)
    -- Animate coins
    if self.CoinsLabel then
        self:AnimateCounter(self.CoinsLabel, 0, progressData.totalCoins or 0, 2.0)
    end
    
    -- Animate XP (start after 0.5 seconds)
    if self.XPLabel then
        wait(0.5)
        self:AnimateCounter(self.XPLabel, 0, progressData.totalXP or 0, 1.5)
    end
    
    -- Animate plants (start after 1 second)
    if self.PlantsLabel then
        wait(0.5)
        self:AnimateCounter(self.PlantsLabel, 0, progressData.harvestedPlants or 0, 1.0)
    end
    
    -- Auto-hide after duration
    spawn(function()
        wait(self.ShowDuration)
        if self.IsShowing then
            self:HideOfflineProgress()
        end
    end)
end

function OfflineProgressUI:AnimateCounter(label, startValue, endValue, duration)
    if endValue <= 0 then
        label.Text = "0"
        return
    end
    
    local frameCount = duration * 60 -- 60 FPS
    local increment = (endValue - startValue) / frameCount
    local currentValue = startValue
    
    local tween = TweenService:Create({Value = startValue}, TweenInfo.new(duration, Enum.EasingStyle.Quad), {Value = endValue})
    
    local connection
    connection = tween.GetPropertyChangedSignal("PlaybackState"):Connect(function()
        if tween.PlaybackState == Enum.PlaybackState.Playing then
            -- Update counter during animation
            spawn(function()
                while tween.PlaybackState == Enum.PlaybackState.Playing and label.Parent do
                    currentValue = currentValue + increment
                    label.Text = math.floor(currentValue)
                    wait(1/60) -- 60 FPS update
                end
                
                -- Ensure final value is correct
                if label.Parent then
                    label.Text = tostring(endValue)
                end
            end)
        end
    end)
    
    tween:Play()
    
    -- Store tween for cleanup
    table.insert(self.CountingTweens, tween)
end

-- ==========================================
-- USER ACTIONS
-- ==========================================

function OfflineProgressUI:ClaimOfflineRewards(progressData)
    -- Send claim request to server
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if remoteEvents then
        local claimOfflineRewardsEvent = remoteEvents:FindFirstChild("ClaimOfflineRewards")
        if claimOfflineRewardsEvent then
            claimOfflineRewardsEvent:FireServer(progressData)
        end
    end
    
    -- Play claim animation
    self:PlayClaimAnimation()
    
    -- Hide UI after claim
    wait(1.5)
    self:HideOfflineProgress()
end

function OfflineProgressUI:PlayClaimAnimation()
    -- Create celebration effect
    local celebrationFrame = Instance.new("Frame")
    celebrationFrame.Name = "CelebrationFrame"
    celebrationFrame.Size = UDim2.new(1, 0, 1, 0)
    celebrationFrame.Position = UDim2.new(0, 0, 0, 0)
    celebrationFrame.BackgroundTransparency = 1
    celebrationFrame.Parent = self.OfflineProgressGui
    
    -- Create floating coins animation
    for i = 1, 10 do
        local coin = Instance.new("TextLabel")
        coin.Size = UDim2.new(0, 30, 0, 30)
        coin.Position = UDim2.new(0.5, math.random(-100, 100), 0.5, math.random(-50, 50))
        coin.BackgroundTransparency = 1
        coin.Text = "💰"
        coin.TextScaled = true
        coin.Parent = celebrationFrame
        
        -- Animate coin floating up
        local floatTween = TweenService:Create(coin, TweenInfo.new(2, Enum.EasingStyle.Quad), {
            Position = UDim2.new(coin.Position.X.Scale, coin.Position.X.Offset, -0.2, 0),
            TextTransparency = 1
        })
        
        floatTween:Play()
        floatTween.Completed:Connect(function()
            coin:Destroy()
        end)
        
        wait(0.1)
    end
    
    -- Clean up celebration frame
    wait(2)
    celebrationFrame:Destroy()
end

function OfflineProgressUI:HideOfflineProgress()
    if not self.IsShowing or not self.OfflineProgressGui then
        return
    end
    
    self.IsShowing = false
    
    -- Stop all counting tweens
    for _, tween in ipairs(self.CountingTweens) do
        if tween then
            tween:Cancel()
        end
    end
    self.CountingTweens = {}
    
    -- Animate hiding
    local mainFrame = self.OfflineProgressGui:FindFirstChild("MainContentFrame")
    if mainFrame then
        local hideTween = TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
            Size = UDim2.new(0, 0, 0, 0),
            Position = UDim2.new(0.5, 0, 0.5, 0)
        })
        
        hideTween:Play()
        hideTween.Completed:Connect(function()
            self.OfflineProgressGui:Destroy()
            self.OfflineProgressGui = nil
        end)
    else
        self.OfflineProgressGui:Destroy()
        self.OfflineProgressGui = nil
    end
    
    print("⏰ OfflineProgressUI: Offline progress UI hidden")
end

-- ==========================================
-- UTILITY FUNCTIONS
-- ==========================================

function OfflineProgressUI:AddButtonHoverEffect(button, normalColor, hoverColor)
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = hoverColor}):Play()
    end)
    
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = normalColor}):Play()
    end)
end

function OfflineProgressUI:IsCurrentlyShowing()
    return self.IsShowing
end

function OfflineProgressUI:ForceHide()
    if self.IsShowing then
        self:HideOfflineProgress()
    end
end

-- ==========================================
-- PUBLIC API
-- ==========================================

function OfflineProgressUI:ShowCustomProgress(customData)
    -- Allow external systems to show custom offline progress
    if self.IsShowing then
        self:HideOfflineProgress()
        wait(0.5)
    end
    
    self:ShowOfflineProgress(customData)
end

return OfflineProgressUI
