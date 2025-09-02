--[[
    TutorialManager.lua
    Client-Side Interactive Tutorial System
    
    Priority: 23 (VIP & Monetization phase)
    Dependencies: UserInputService, TweenService, UIManager
    Used by: New player onboarding, feature introduction
    
    Features:
    - Interactive step-by-step tutorials
    - Contextual hints and tooltips
    - Progress tracking and skipping
    - VIP tutorial enhancements
    - Mobile-optimized instructions
    - Achievement integration
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

-- Load required modules
local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)

local TutorialManager = {}
TutorialManager.__index = TutorialManager

-- ==========================================
-- INITIALIZATION & SETUP
-- ==========================================

TutorialManager.Player = Players.LocalPlayer
TutorialManager.PlayerGui = TutorialManager.Player:WaitForChild("PlayerGui")

-- Tutorial state
TutorialManager.TutorialGui = nil
TutorialManager.OverlayFrame = nil
TutorialManager.TooltipFrame = nil
TutorialManager.HighlightFrame = nil

-- Tutorial data
TutorialManager.ActiveTutorial = nil
TutorialManager.CurrentStep = 0
TutorialManager.TutorialProgress = {}
TutorialManager.CompletedTutorials = {}
TutorialManager.IsInTutorial = false
TutorialManager.CanSkip = true

-- UI References
TutorialManager.TargetElements = {}
TutorialManager.OriginalProperties = {}

-- Mobile optimization
TutorialManager.IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ==========================================
-- TUTORIAL DEFINITIONS
-- ==========================================

TutorialManager.Tutorials = {
    first_time_player = {
        id = "first_time_player",
        name = "Garden Basics",
        description = "Learn the basics of garden management",
        required = true,
        vipEnhanced = false,
        steps = {
            {
                id = "welcome",
                title = "Welcome to Garden Paradise! 🌱",
                description = "Let's start your gardening journey! Tap anywhere to continue.",
                type = "welcome",
                canSkip = false,
                duration = 3
            },
            {
                id = "plot_selection",
                title = "Your First Plot",
                description = "Tap on this highlighted plot to select it.",
                type = "highlight",
                target = "plot_1",
                waitForAction = "plot_click",
                canSkip = false
            },
            {
                id = "plant_seed",
                title = "Plant Your First Seed",
                description = "Tap the 'Plant' button to plant your first seed!",
                type = "highlight",
                target = "plant_button",
                waitForAction = "plant_action",
                canSkip = false
            },
            {
                id = "wait_for_growth",
                title = "Plant Growth",
                description = "Great! Your plant will grow over time. Watch the progress bar.",
                type = "info",
                duration = 4,
                canSkip = true
            },
            {
                id = "speed_up",
                title = "Speed Up Growth (Optional)",
                description = "You can use fertilizer to speed up growth, or wait naturally.",
                type = "highlight",
                target = "fertilizer_button",
                duration = 3,
                canSkip = true,
                optional = true
            },
            {
                id = "harvest_ready",
                title = "Harvest Time!",
                description = "When your plant is ready, tap it to harvest and earn coins!",
                type = "highlight",
                target = "plot_1",
                waitForAction = "harvest_action",
                canSkip = false,
                condition = "plant_ready"
            },
            {
                id = "shop_introduction",
                title = "The Shop",
                description = "Use coins to buy new seeds and upgrades in the shop.",
                type = "highlight",
                target = "shop_button",
                duration = 3,
                canSkip = true
            },
            {
                id = "tutorial_complete",
                title = "Tutorial Complete! 🎉",
                description = "You're ready to build your garden empire! Keep growing!",
                type = "celebration",
                duration = 3,
                canSkip = true
            }
        }
    },
    
    vip_features = {
        id = "vip_features",
        name = "VIP Features Tour",
        description = "Discover your exclusive VIP benefits",
        required = false,
        vipEnhanced = true,
        vipOnly = true,
        steps = {
            {
                id = "vip_welcome",
                title = "Welcome VIP Member! 👑",
                description = "Let's explore your exclusive VIP features!",
                type = "welcome",
                duration = 3
            },
            {
                id = "vip_multipliers",
                title = "VIP Bonuses",
                description = "You get 3x daily bonuses and 2x offline progress!",
                type = "info",
                duration = 4
            },
            {
                id = "vip_effects",
                title = "Golden Glow",
                description = "Notice your golden glow effect - other players know you're VIP!",
                type = "info",
                duration = 4
            },
            {
                id = "daily_bonus",
                title = "Enhanced Daily Bonus",
                description = "Check your daily bonus with VIP multipliers!",
                type = "highlight",
                target = "daily_bonus_button",
                duration = 3
            },
            {
                id = "vip_shop",
                title = "VIP Shop Section",
                description = "Access exclusive VIP items in the shop!",
                type = "highlight",
                target = "vip_shop_section",
                duration = 3
            }
        }
    },
    
    advanced_features = {
        id = "advanced_features",
        name = "Advanced Features",
        description = "Learn about advanced game mechanics",
        required = false,
        vipEnhanced = true,
        unlockLevel = 5,
        steps = {
            {
                id = "achievements",
                title = "Achievements System",
                description = "Unlock achievements to earn rewards and show your progress!",
                type = "highlight",
                target = "achievements_button",
                duration = 4
            },
            {
                id = "leaderboards",
                title = "Compete with Others",
                description = "Check the leaderboards to see how you rank globally!",
                type = "highlight",
                target = "leaderboards_button",
                duration = 4
            },
            {
                id = "social_features",
                title = "Social Features",
                description = "Visit friends' gardens and send gifts!",
                type = "highlight",
                target = "friends_button",
                duration = 4
            },
            {
                id = "offline_progress",
                title = "Offline Progress",
                description = "Your garden keeps growing even when you're away!",
                type = "info",
                duration = 4
            }
        }
    },
    
    mobile_controls = {
        id = "mobile_controls",
        name = "Mobile Controls",
        description = "Learn mobile-specific gestures and controls",
        required = false,
        mobileOnly = true,
        steps = {
            {
                id = "tap_controls",
                title = "Tap Controls",
                description = "Tap to select plots and interact with your garden.",
                type = "info",
                duration = 3
            },
            {
                id = "swipe_navigation",
                title = "Swipe Navigation",
                description = "Swipe to navigate between different areas of your garden.",
                type = "info",
                duration = 3
            },
            {
                id = "pinch_zoom",
                title = "Pinch to Zoom",
                description = "Pinch to zoom in and out for better garden management.",
                type = "info",
                duration = 3
            }
        }
    }
}

-- ==========================================
-- INITIALIZATION
-- ==========================================

function TutorialManager:Initialize()
    print("📚 TutorialManager: Initializing tutorial system...")
    
    -- Create tutorial GUI
    self:CreateTutorialGUI()
    
    -- Set up remote events
    self:SetupRemoteEvents()
    
    -- Load tutorial progress
    self:LoadTutorialProgress()
    
    -- Check for auto-start tutorials
    self:CheckAutoStartTutorials()
    
    print("✅ TutorialManager: Tutorial system initialized")
end

function TutorialManager:CreateTutorialGUI()
    -- Create main tutorial GUI
    self.TutorialGui = Instance.new("ScreenGui")
    self.TutorialGui.Name = "TutorialSystem"
    self.TutorialGui.ResetOnSpawn = false
    self.TutorialGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    self.TutorialGui.Parent = self.PlayerGui
    
    -- Create overlay frame (semi-transparent background)
    self.OverlayFrame = Instance.new("Frame")
    self.OverlayFrame.Name = "TutorialOverlay"
    self.OverlayFrame.Size = UDim2.new(1, 0, 1, 0)
    self.OverlayFrame.Position = UDim2.new(0, 0, 0, 0)
    self.OverlayFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    self.OverlayFrame.BackgroundTransparency = 0.7
    self.OverlayFrame.BorderSizePixel = 0
    self.OverlayFrame.Visible = false
    self.OverlayFrame.ZIndex = 100
    self.OverlayFrame.Parent = self.TutorialGui
    
    -- Create tooltip frame
    self.TooltipFrame = Instance.new("Frame")
    self.TooltipFrame.Name = "TutorialTooltip"
    self.TooltipFrame.Size = UDim2.new(0, 400, 0, 200)
    self.TooltipFrame.Position = UDim2.new(0.5, -200, 0.5, -100)
    self.TooltipFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    self.TooltipFrame.BorderSizePixel = 0
    self.TooltipFrame.Visible = false
    self.TooltipFrame.ZIndex = 105
    self.TooltipFrame.Parent = self.TutorialGui
    
    -- Add corner radius to tooltip
    local tooltipCorner = Instance.new("UICorner")
    tooltipCorner.CornerRadius = UDim.new(0, 15)
    tooltipCorner.Parent = self.TooltipFrame
    
    -- Create highlight frame
    self.HighlightFrame = Instance.new("Frame")
    self.HighlightFrame.Name = "TutorialHighlight"
    self.HighlightFrame.BackgroundTransparency = 1
    self.HighlightFrame.BorderSizePixel = 0
    self.HighlightFrame.Visible = false
    self.HighlightFrame.ZIndex = 102
    self.HighlightFrame.Parent = self.TutorialGui
    
    -- Create highlight border
    local highlightBorder = Instance.new("UIStroke")
    highlightBorder.Color = Color3.fromRGB(0, 255, 0)
    highlightBorder.Thickness = 4
    highlightBorder.Transparency = 0
    highlightBorder.Parent = self.HighlightFrame
    
    -- Add pulsing animation to highlight
    local pulseAnimation = TweenService:Create(
        highlightBorder,
        TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {Transparency = 0.5}
    )
    pulseAnimation:Play()
    
    -- Mobile optimizations
    if self.IsMobile then
        self.TooltipFrame.Size = UDim2.new(0, 350, 0, 180)
        self.TooltipFrame.Position = UDim2.new(0.5, -175, 0.5, -90)
    end
end

function TutorialManager:SetupRemoteEvents()
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then
        warn("❌ TutorialManager: RemoteEvents folder not found")
        return
    end
    
    -- Tutorial progress sync
    local tutorialProgressEvent = remoteEvents:FindFirstChild("TutorialProgress")
    if tutorialProgressEvent then
        tutorialProgressEvent.OnClientEvent:Connect(function(progressData)
            self:UpdateTutorialProgress(progressData)
        end)
    end
    
    -- Start tutorial remotely
    local startTutorialEvent = remoteEvents:FindFirstChild("StartTutorial")
    if startTutorialEvent then
        startTutorialEvent.OnClientEvent:Connect(function(tutorialId)
            self:StartTutorial(tutorialId)
        end)
    end
end

function TutorialManager:LoadTutorialProgress()
    -- Load tutorial progress from server
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if remoteEvents then
        local getTutorialProgressFunction = remoteEvents:FindFirstChild("GetTutorialProgress")
        if getTutorialProgressFunction then
            local success, progressData = pcall(function()
                return getTutorialProgressFunction:InvokeServer()
            end)
            
            if success and progressData then
                self.TutorialProgress = progressData.progress or {}
                self.CompletedTutorials = progressData.completed or {}
            end
        end
    end
end

function TutorialManager:CheckAutoStartTutorials()
    -- Check if first time player needs tutorial
    if not self.CompletedTutorials["first_time_player"] then
        -- Delay to ensure all systems are loaded
        spawn(function()
            wait(3)
            self:StartTutorial("first_time_player")
        end)
    end
    
    -- Check VIP tutorial
    if self:IsVIPPlayer() and not self.CompletedTutorials["vip_features"] then
        spawn(function()
            wait(8) -- Start after main tutorial or with delay
            if not self.IsInTutorial then
                self:StartTutorial("vip_features")
            end
        end)
    end
    
    -- Check mobile tutorial
    if self.IsMobile and not self.CompletedTutorials["mobile_controls"] then
        spawn(function()
            wait(15)
            if not self.IsInTutorial then
                self:StartTutorial("mobile_controls")
            end
        end)
    end
end

-- ==========================================
-- TUTORIAL EXECUTION
-- ==========================================

function TutorialManager:StartTutorial(tutorialId)
    local tutorial = self.Tutorials[tutorialId]
    if not tutorial then
        warn("❌ TutorialManager: Tutorial not found:", tutorialId)
        return false
    end
    
    -- Check if already completed
    if self.CompletedTutorials[tutorialId] then
        print("📚 TutorialManager: Tutorial already completed:", tutorialId)
        return false
    end
    
    -- Check VIP requirements
    if tutorial.vipOnly and not self:IsVIPPlayer() then
        return false
    end
    
    -- Check level requirements
    if tutorial.unlockLevel and self:GetPlayerLevel() < tutorial.unlockLevel then
        return false
    end
    
    -- Check mobile requirements
    if tutorial.mobileOnly and not self.IsMobile then
        return false
    end
    
    -- Stop any active tutorial
    if self.IsInTutorial then
        self:StopTutorial()
    end
    
    -- Initialize tutorial state
    self.ActiveTutorial = tutorial
    self.CurrentStep = 0
    self.IsInTutorial = true
    
    -- Show tutorial overlay
    self:ShowTutorialOverlay()
    
    -- Start first step
    self:NextStep()
    
    print("📚 TutorialManager: Started tutorial:", tutorial.name)
    return true
end

function TutorialManager:NextStep()
    if not self.ActiveTutorial then return end
    
    self.CurrentStep = self.CurrentStep + 1
    
    if self.CurrentStep > #self.ActiveTutorial.steps then
        -- Tutorial complete
        self:CompleteTutorial()
        return
    end
    
    local step = self.ActiveTutorial.steps[self.CurrentStep]
    self:ExecuteStep(step)
end

function TutorialManager:ExecuteStep(step)
    print("📚 TutorialManager: Executing step:", step.id)
    
    -- Hide previous highlights
    self:HideHighlight()
    
    if step.type == "welcome" then
        self:ShowWelcomeStep(step)
        
    elseif step.type == "highlight" then
        self:ShowHighlightStep(step)
        
    elseif step.type == "info" then
        self:ShowInfoStep(step)
        
    elseif step.type == "celebration" then
        self:ShowCelebrationStep(step)
    end
    
    -- Handle step timing
    if step.duration and not step.waitForAction then
        spawn(function()
            wait(step.duration)
            if self.IsInTutorial and self.ActiveTutorial.steps[self.CurrentStep] == step then
                self:NextStep()
            end
        end)
    end
    
    -- Update progress
    self:UpdateStepProgress()
end

function TutorialManager:ShowWelcomeStep(step)
    self:ShowTooltip(step.title, step.description, nil, true)
    
    -- Add VIP enhancement if applicable
    if self.ActiveTutorial.vipEnhanced and self:IsVIPPlayer() then
        self:AddVIPEnhancementToTooltip()
    end
end

function TutorialManager:ShowHighlightStep(step)
    -- Find target element
    local targetElement = self:FindTargetElement(step.target)
    
    if targetElement then
        self:HighlightElement(targetElement)
        
        -- Position tooltip near target
        local tooltipPosition = self:CalculateTooltipPosition(targetElement)
        self:ShowTooltip(step.title, step.description, tooltipPosition)
        
        -- Set up action waiting if needed
        if step.waitForAction then
            self:WaitForAction(step.waitForAction, targetElement)
        end
    else
        warn("❌ TutorialManager: Target element not found:", step.target)
        -- Show tooltip at center as fallback
        self:ShowTooltip(step.title, step.description)
    end
end

function TutorialManager:ShowInfoStep(step)
    self:ShowTooltip(step.title, step.description)
end

function TutorialManager:ShowCelebrationStep(step)
    self:ShowTooltip(step.title, step.description, nil, true)
    
    -- Add celebration effects
    self:PlayCelebrationEffects()
end

-- ==========================================
-- UI MANAGEMENT
-- ==========================================

function TutorialManager:ShowTutorialOverlay()
    self.OverlayFrame.Visible = true
    
    -- Fade in animation
    self.OverlayFrame.BackgroundTransparency = 1
    local fadeIn = TweenService:Create(
        self.OverlayFrame,
        TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundTransparency = 0.7}
    )
    fadeIn:Play()
end

function TutorialManager:HideTutorialOverlay()
    -- Fade out animation
    local fadeOut = TweenService:Create(
        self.OverlayFrame,
        TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {BackgroundTransparency = 1}
    )
    
    fadeOut:Play()
    fadeOut.Completed:Connect(function()
        self.OverlayFrame.Visible = false
    end)
end

function TutorialManager:ShowTooltip(title, description, position, isCelebration)
    -- Clear existing content
    for _, child in pairs(self.TooltipFrame:GetChildren()) do
        if child:IsA("TextLabel") or child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    -- Create title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -20, 0, 40)
    titleLabel.Position = UDim2.new(0, 10, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextScaled = true
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.Font = Enum.Font.SourceSansBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = self.TooltipFrame
    
    -- Create description
    local descLabel = Instance.new("TextLabel")
    descLabel.Size = UDim2.new(1, -20, 0, 80)
    descLabel.Position = UDim2.new(0, 10, 0, 50)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = description
    descLabel.TextScaled = true
    descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    descLabel.Font = Enum.Font.SourceSans
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextWrapped = true
    descLabel.Parent = self.TooltipFrame
    
    -- Create continue button
    local continueButton = Instance.new("TextButton")
    continueButton.Size = UDim2.new(0, 100, 0, 30)
    continueButton.Position = UDim2.new(1, -110, 1, -40)
    continueButton.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
    continueButton.BorderSizePixel = 0
    continueButton.Text = isCelebration and "Finish" or "Continue"
    continueButton.TextScaled = true
    continueButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    continueButton.Font = Enum.Font.SourceSansBold
    continueButton.Parent = self.TooltipFrame
    
    -- Add corner radius to button
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 8)
    buttonCorner.Parent = continueButton
    
    -- Continue button functionality
    continueButton.Activated:Connect(function()
        self:NextStep()
    end)
    
    -- Create skip button if allowed
    local currentStep = self.ActiveTutorial and self.ActiveTutorial.steps[self.CurrentStep]
    if self.CanSkip and currentStep and currentStep.canSkip ~= false then
        local skipButton = Instance.new("TextButton")
        skipButton.Size = UDim2.new(0, 80, 0, 25)
        skipButton.Position = UDim2.new(0, 10, 1, -35)
        skipButton.BackgroundColor3 = Color3.fromRGB(149, 165, 166)
        skipButton.BorderSizePixel = 0
        skipButton.Text = "Skip"
        skipButton.TextScaled = true
        skipButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        skipButton.Font = Enum.Font.SourceSans
        skipButton.Parent = self.TooltipFrame
        
        local skipCorner = Instance.new("UICorner")
        skipCorner.CornerRadius = UDim.new(0, 6)
        skipCorner.Parent = skipButton
        
        skipButton.Activated:Connect(function()
            self:SkipTutorial()
        end)
    end
    
    -- Position tooltip
    if position then
        self.TooltipFrame.Position = position
    else
        self.TooltipFrame.Position = UDim2.new(0.5, -200, 0.5, -100)
    end
    
    -- Show tooltip
    self.TooltipFrame.Visible = true
    
    -- Animate in
    self.TooltipFrame.Size = UDim2.new(0, 0, 0, 0)
    local animateIn = TweenService:Create(
        self.TooltipFrame,
        TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, self.IsMobile and 350 or 400, 0, 200)}
    )
    animateIn:Play()
end

function TutorialManager:HideTooltip()
    if not self.TooltipFrame.Visible then return end
    
    local animateOut = TweenService:Create(
        self.TooltipFrame,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {Size = UDim2.new(0, 0, 0, 0)}
    )
    
    animateOut:Play()
    animateOut.Completed:Connect(function()
        self.TooltipFrame.Visible = false
    end)
end

function TutorialManager:HighlightElement(element)
    if not element then return end
    
    -- Store original properties for restoration
    self.OriginalProperties[element] = {
        ZIndex = element.ZIndex,
        BackgroundTransparency = element.BackgroundTransparency
    }
    
    -- Create cutout in overlay
    self:CreateOverlayCutout(element)
    
    -- Position highlight frame
    local absolutePosition = element.AbsolutePosition
    local absoluteSize = element.AbsoluteSize
    
    self.HighlightFrame.Position = UDim2.new(0, absolutePosition.X - 5, 0, absolutePosition.Y - 5)
    self.HighlightFrame.Size = UDim2.new(0, absoluteSize.X + 10, 0, absoluteSize.Y + 10)
    self.HighlightFrame.Visible = true
    
    -- Bring element forward
    element.ZIndex = 110
end

function TutorialManager:CreateOverlayCutout(element)
    -- This would create a "hole" in the overlay to show the highlighted element
    -- For now, we'll adjust the element's visibility
    if element.BackgroundTransparency < 1 then
        element.BackgroundTransparency = math.max(0, element.BackgroundTransparency - 0.3)
    end
end

function TutorialManager:HideHighlight()
    self.HighlightFrame.Visible = false
    
    -- Restore original properties
    for element, properties in pairs(self.OriginalProperties) do
        if element and element.Parent then
            element.ZIndex = properties.ZIndex
            element.BackgroundTransparency = properties.BackgroundTransparency
        end
    end
    
    self.OriginalProperties = {}
end

-- ==========================================
-- TARGET ELEMENT FINDING
-- ==========================================

function TutorialManager:FindTargetElement(targetId)
    -- Define target element mappings
    local targetMappings = {
        plot_1 = function() return self:FindPlotElement(1) end,
        plant_button = function() return self:FindUIElement("PlantButton") end,
        fertilizer_button = function() return self:FindUIElement("FertilizerButton") end,
        shop_button = function() return self:FindUIElement("ShopButton") end,
        daily_bonus_button = function() return self:FindUIElement("DailyBonusButton") end,
        achievements_button = function() return self:FindUIElement("AchievementsButton") end,
        leaderboards_button = function() return self:FindUIElement("LeaderboardsButton") end,
        friends_button = function() return self:FindUIElement("FriendsButton") end,
        vip_shop_section = function() return self:FindUIElement("VIPShopSection") end
    }
    
    local finder = targetMappings[targetId]
    if finder then
        return finder()
    end
    
    return nil
end

function TutorialManager:FindPlotElement(plotNumber)
    -- Look for plot in workspace
    local plots = workspace:FindFirstChild("Plots")
    if plots then
        for _, plot in pairs(plots:GetChildren()) do
            if plot:GetAttribute("PlotId") == plotNumber then
                return plot
            end
        end
    end
    
    return nil
end

function TutorialManager:FindUIElement(elementName)
    -- Search through player GUI for the element
    local function searchInGui(parent)
        for _, child in pairs(parent:GetChildren()) do
            if child.Name == elementName or child:GetAttribute("TutorialTarget") == elementName then
                return child
            end
            
            local found = searchInGui(child)
            if found then return found end
        end
        return nil
    end
    
    return searchInGui(self.PlayerGui)
end

function TutorialManager:CalculateTooltipPosition(targetElement)
    if not targetElement then
        return UDim2.new(0.5, -200, 0.5, -100)
    end
    
    local absolutePosition = targetElement.AbsolutePosition
    local absoluteSize = targetElement.AbsoluteSize
    local screenSize = self.PlayerGui.AbsoluteSize
    
    -- Try to position tooltip near but not overlapping the target
    local tooltipWidth = self.IsMobile and 350 or 400
    local tooltipHeight = 200
    
    local x = absolutePosition.X + absoluteSize.X + 20
    local y = absolutePosition.Y
    
    -- Check if tooltip would go off-screen
    if x + tooltipWidth > screenSize.X then
        x = absolutePosition.X - tooltipWidth - 20
    end
    
    if y + tooltipHeight > screenSize.Y then
        y = screenSize.Y - tooltipHeight - 20
    end
    
    -- Ensure minimum margins
    x = math.max(10, math.min(x, screenSize.X - tooltipWidth - 10))
    y = math.max(10, math.min(y, screenSize.Y - tooltipHeight - 10))
    
    return UDim2.new(0, x, 0, y)
end

-- ==========================================
-- ACTION WAITING
-- ==========================================

function TutorialManager:WaitForAction(actionType, targetElement)
    if actionType == "plot_click" then
        self:WaitForPlotClick(targetElement)
    elseif actionType == "plant_action" then
        self:WaitForPlantAction()
    elseif actionType == "harvest_action" then
        self:WaitForHarvestAction()
    end
end

function TutorialManager:WaitForPlotClick(plotElement)
    if not plotElement then return end
    
    local clickDetector = plotElement:FindFirstChild("ClickDetector")
    if clickDetector then
        local connection = clickDetector.MouseClick:Connect(function(player)
            if player == self.Player then
                self:NextStep()
            end
        end)
        
        -- Store connection for cleanup
        self.TargetElements[plotElement] = connection
    end
end

function TutorialManager:WaitForPlantAction()
    -- Listen for planting action via remote events
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if remoteEvents then
        local plantEvent = remoteEvents:FindFirstChild("PlantSeed")
        if plantEvent then
            local connection = plantEvent.OnClientEvent:Connect(function()
                self:NextStep()
            end)
            
            -- Store for cleanup
            table.insert(self.TargetElements, connection)
        end
    end
end

function TutorialManager:WaitForHarvestAction()
    -- Listen for harvest action
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if remoteEvents then
        local harvestEvent = remoteEvents:FindFirstChild("HarvestPlant")
        if harvestEvent then
            local connection = harvestEvent.OnClientEvent:Connect(function()
                self:NextStep()
            end)
            
            table.insert(self.TargetElements, connection)
        end
    end
end

-- ==========================================
-- TUTORIAL COMPLETION
-- ==========================================

function TutorialManager:CompleteTutorial()
    if not self.ActiveTutorial then return end
    
    local tutorialId = self.ActiveTutorial.id
    
    -- Mark as completed
    self.CompletedTutorials[tutorialId] = true
    
    -- Save progress to server
    self:SaveTutorialProgress()
    
    -- Show completion celebration
    self:ShowTutorialCompletionCelebration()
    
    -- Clean up
    self:CleanupTutorial()
    
    -- Give completion rewards
    self:GiveTutorialRewards(tutorialId)
    
    print("📚 TutorialManager: Completed tutorial:", self.ActiveTutorial.name)
end

function TutorialManager:SkipTutorial()
    if not self.ActiveTutorial then return end
    
    local tutorialId = self.ActiveTutorial.id
    
    -- Mark as completed (skipped)
    self.CompletedTutorials[tutorialId] = true
    
    -- Save progress
    self:SaveTutorialProgress()
    
    -- Clean up
    self:CleanupTutorial()
    
    print("📚 TutorialManager: Skipped tutorial:", self.ActiveTutorial.name)
end

function TutorialManager:StopTutorial()
    if not self.IsInTutorial then return end
    
    self:CleanupTutorial()
    print("📚 TutorialManager: Stopped tutorial")
end

function TutorialManager:CleanupTutorial()
    -- Hide UI
    self:HideTooltip()
    self:HideHighlight()
    self:HideTutorialOverlay()
    
    -- Clean up connections
    for element, connection in pairs(self.TargetElements) do
        if typeof(connection) == "RBXScriptConnection" then
            connection:Disconnect()
        end
    end
    self.TargetElements = {}
    
    -- Reset state
    self.ActiveTutorial = nil
    self.CurrentStep = 0
    self.IsInTutorial = false
end

function TutorialManager:ShowTutorialCompletionCelebration()
    -- Show celebration effects
    self:PlayCelebrationEffects()
    
    -- Notify achievement system
    local achievementSystem = _G.AchievementSystem
    if achievementSystem then
        achievementSystem:IncrementPlayerStat(self.Player, "tutorialsCompleted", 1)
    end
end

function TutorialManager:PlayCelebrationEffects()
    -- Create sparkle effects on tooltip
    for i = 1, 10 do
        local sparkle = Instance.new("TextLabel")
        sparkle.Size = UDim2.new(0, 20, 0, 20)
        sparkle.Position = UDim2.new(
            math.random(0, 100) / 100,
            math.random(-10, 10),
            math.random(0, 100) / 100,
            math.random(-10, 10)
        )
        sparkle.BackgroundTransparency = 1
        sparkle.Text = "✨"
        sparkle.TextScaled = true
        sparkle.TextColor3 = Color3.fromRGB(255, 215, 0)
        sparkle.ZIndex = 120
        sparkle.Parent = self.TooltipFrame
        
        -- Animate sparkle
        local sparkleAnim = TweenService:Create(
            sparkle,
            TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {
                Position = UDim2.new(
                    sparkle.Position.X.Scale + (math.random(-50, 50) / 100),
                    sparkle.Position.X.Offset,
                    sparkle.Position.Y.Scale - 0.5,
                    sparkle.Position.Y.Offset
                ),
                TextTransparency = 1
            }
        )
        
        sparkleAnim:Play()
        sparkleAnim.Completed:Connect(function()
            sparkle:Destroy()
        end)
    end
end

-- ==========================================
-- PROGRESS TRACKING
-- ==========================================

function TutorialManager:UpdateStepProgress()
    if not self.ActiveTutorial then return end
    
    local tutorialId = self.ActiveTutorial.id
    self.TutorialProgress[tutorialId] = self.CurrentStep
end

function TutorialManager:SaveTutorialProgress()
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if remoteEvents then
        local saveTutorialProgressFunction = remoteEvents:FindFirstChild("SaveTutorialProgress")
        if saveTutorialProgressFunction then
            saveTutorialProgressFunction:InvokeServer({
                progress = self.TutorialProgress,
                completed = self.CompletedTutorials
            })
        end
    end
end

function TutorialManager:UpdateTutorialProgress(progressData)
    self.TutorialProgress = progressData.progress or {}
    self.CompletedTutorials = progressData.completed or {}
end

function TutorialManager:GiveTutorialRewards(tutorialId)
    -- Give coins for completing tutorials
    local economyManager = _G.EconomyManager
    if economyManager then
        local rewardAmount = 250
        if tutorialId == "first_time_player" then
            rewardAmount = 500
        elseif tutorialId == "vip_features" then
            rewardAmount = 1000
        end
        
        economyManager:AddCoins(self.Player, rewardAmount, "tutorial_complete")
    end
    
    -- Show reward notification
    local notificationManager = _G.NotificationManager
    if notificationManager then
        notificationManager:ShowToast(
            "Tutorial Complete! 🎉",
            "You earned " .. (rewardAmount or 250) .. " coins!",
            "📚",
            "achievement"
        )
    end
end

-- ==========================================
-- VIP ENHANCEMENTS
-- ==========================================

function TutorialManager:AddVIPEnhancementToTooltip()
    if not self:IsVIPPlayer() then return end
    
    -- Add VIP crown to title
    local titleLabel = self.TooltipFrame:FindFirstChild("TitleLabel")
    if titleLabel then
        titleLabel.Text = "👑 " .. titleLabel.Text
    end
    
    -- Add golden border
    local vipBorder = Instance.new("UIStroke")
    vipBorder.Color = Color3.fromRGB(255, 215, 0)
    vipBorder.Thickness = 2
    vipBorder.Transparency = 0.3
    vipBorder.Parent = self.TooltipFrame
end

-- ==========================================
-- UTILITY FUNCTIONS
-- ==========================================

function TutorialManager:IsVIPPlayer()
    local vipManager = _G.VIPManager
    if vipManager then
        return vipManager:IsPlayerVIP(self.Player)
    end
    return false
end

function TutorialManager:GetPlayerLevel()
    local progressionManager = _G.ProgressionManager
    if progressionManager then
        return progressionManager:GetPlayerLevel(self.Player) or 1
    end
    return 1
end

-- ==========================================
-- PUBLIC API
-- ==========================================

function TutorialManager:StartTutorialById(tutorialId)
    return self:StartTutorial(tutorialId)
end

function TutorialManager:IsTutorialCompleted(tutorialId)
    return self.CompletedTutorials[tutorialId] == true
end

function TutorialManager:GetCompletedTutorials()
    return self.CompletedTutorials
end

function TutorialManager:GetAvailableTutorials()
    local available = {}
    
    for tutorialId, tutorial in pairs(self.Tutorials) do
        if not self.CompletedTutorials[tutorialId] then
            -- Check requirements
            local canStart = true
            
            if tutorial.vipOnly and not self:IsVIPPlayer() then
                canStart = false
            end
            
            if tutorial.unlockLevel and self:GetPlayerLevel() < tutorial.unlockLevel then
                canStart = false
            end
            
            if tutorial.mobileOnly and not self.IsMobile then
                canStart = false
            end
            
            if canStart then
                table.insert(available, tutorial)
            end
        end
    end
    
    return available
end

function TutorialManager:ForceStopAllTutorials()
    self:StopTutorial()
end

-- ==========================================
-- CLEANUP
-- ==========================================

function TutorialManager:Cleanup()
    self:CleanupTutorial()
    
    if self.TutorialGui then
        self.TutorialGui:Destroy()
    end
    
    print("📚 TutorialManager: Cleaned up tutorial system")
end

return TutorialManager
