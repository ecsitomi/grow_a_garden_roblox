--[[
    PlotClickHandler.lua
    Client-Side Plot Interaction Manager
    
    Priority: 14 (Touch-optimized plot interaction)
    Dependencies: UIManager, PlotManager, PlantManager (server comm)
    Used by: Mobile touch interaction, plot UI panels
    
    Features:
    - Touch-optimized plot selection
    - Plot information panels
    - Plant/harvest action buttons
    - Real-time plot status updates
    - Mobile-friendly UI positioning
    - Visual feedback for interactions
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- Load required modules
local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)

local PlotClickHandler = {}
PlotClickHandler.__index = PlotClickHandler

-- ==========================================
-- TOUCH INTERACTION REFERENCES
-- ==========================================

PlotClickHandler.Player = Players.LocalPlayer
PlotClickHandler.PlayerGui = nil
PlotClickHandler.Camera = workspace.CurrentCamera
PlotClickHandler.LastTouchTime = 0
PlotClickHandler.TouchCooldown = 0.3 -- Prevent rapid tapping

-- UI References
PlotClickHandler.PlotInfoPanel = nil
PlotClickHandler.CurrentSelectedPlot = nil
PlotClickHandler.PlotHighlight = nil

-- Touch State
PlotClickHandler.IsTouchDevice = UserInputService.TouchEnabled
PlotClickHandler.IsInteractionActive = false

-- ==========================================
-- INITIALIZATION
-- ==========================================

function PlotClickHandler:Initialize()
    print("📱 PlotClickHandler: Initializing touch interaction system...")
    
    -- Wait for player GUI
    self.PlayerGui = self.Player:WaitForChild("PlayerGui")
    
    -- Create plot interaction UI
    self:CreatePlotInfoPanel()
    self:CreatePlotHighlight()
    
    -- Set up input connections
    self:SetupInputConnections()
    
    -- Set up plot detection
    self:SetupPlotDetection()
    
    -- Set up update loop
    self:SetupUpdateLoop()
    
    print("✅ PlotClickHandler: Touch interaction system initialized")
end

function PlotClickHandler:CreatePlotInfoPanel()
    -- Create plot info ScreenGui
    local plotInfoGui = Instance.new("ScreenGui")
    plotInfoGui.Name = "PlotInfoUI"
    plotInfoGui.ResetOnSpawn = false
    plotInfoGui.DisplayOrder = 15
    plotInfoGui.Parent = self.PlayerGui
    
    -- Create main plot info panel
    self.PlotInfoPanel = self:CreateMainPlotPanel(plotInfoGui)
    
    -- Initially hide panel
    self.PlotInfoPanel.Visible = false
    
    print("🎨 PlotClickHandler: Plot info panel created")
end

function PlotClickHandler:CreateMainPlotPanel(parent)
    local mainPanel = Instance.new("Frame")
    mainPanel.Name = "PlotInfoPanel"
    mainPanel.Size = UDim2.new(0, 300, 0, 200)
    mainPanel.Position = UDim2.new(0.5, -150, 1, -220)
    mainPanel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    mainPanel.BorderSizePixel = 0
    mainPanel.Parent = parent
    
    -- Add corner radius
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainPanel
    
    -- Add drop shadow
    local shadow = Instance.new("Frame")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 6, 1, 6)
    shadow.Position = UDim2.new(0, -3, 0, -3)
    shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow.BackgroundTransparency = 0.7
    shadow.ZIndex = mainPanel.ZIndex - 1
    shadow.Parent = mainPanel
    
    local shadowCorner = Instance.new("UICorner")
    shadowCorner.CornerRadius = UDim.new(0, 12)
    shadowCorner.Parent = shadow
    
    -- Create panel content
    self:CreatePanelHeader(mainPanel)
    self:CreatePanelContent(mainPanel)
    self:CreatePanelActions(mainPanel)
    
    return mainPanel
end

function PlotClickHandler:CreatePanelHeader(parent)
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 40)
    header.Position = UDim2.new(0, 0, 0, 0)
    header.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
    header.BorderSizePixel = 0
    header.Parent = parent
    
    -- Header corner radius
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = header
    
    -- Fix corner clipping
    local headerFix = Instance.new("Frame")
    headerFix.Size = UDim2.new(1, 0, 0, 12)
    headerFix.Position = UDim2.new(0, 0, 1, -12)
    headerFix.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
    headerFix.BorderSizePixel = 0
    headerFix.Parent = header
    
    -- Plot title
    local title = Instance.new("TextLabel")
    title.Name = "PlotTitle"
    title.Size = UDim2.new(0.8, 0, 1, 0)
    title.Position = UDim2.new(0.05, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "🌱 Plot #1"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header
    
    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -35, 0, 5)
    closeButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
    closeButton.BorderSizePixel = 0
    closeButton.Text = "✕"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextScaled = true
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Parent = header
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeButton
    
    closeButton.MouseButton1Click:Connect(function()
        self:HidePlotInfo()
    end)
end

function PlotClickHandler:CreatePanelContent(parent)
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -20, 0, 110)
    content.Position = UDim2.new(0, 10, 0, 45)
    content.BackgroundTransparency = 1
    content.Parent = parent
    
    -- Plant status frame
    local plantStatus = Instance.new("Frame")
    plantStatus.Name = "PlantStatus"
    plantStatus.Size = UDim2.new(1, 0, 0, 80)
    plantStatus.Position = UDim2.new(0, 0, 0, 0)
    plantStatus.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    plantStatus.BorderSizePixel = 0
    plantStatus.Parent = content
    
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 8)
    statusCorner.Parent = plantStatus
    
    -- Plant icon/preview
    local plantIcon = Instance.new("Frame")
    plantIcon.Name = "PlantIcon"
    plantIcon.Size = UDim2.new(0, 60, 0, 60)
    plantIcon.Position = UDim2.new(0, 10, 0, 10)
    plantIcon.BackgroundColor3 = Color3.fromRGB(100, 150, 100)
    plantIcon.BorderSizePixel = 0
    plantIcon.Parent = plantStatus
    
    local iconCorner = Instance.new("UICorner")
    iconCorner.CornerRadius = UDim.new(0, 6)
    iconCorner.Parent = plantIcon
    
    -- Plant emoji
    local plantEmoji = Instance.new("TextLabel")
    plantEmoji.Name = "PlantEmoji"
    plantEmoji.Size = UDim2.new(1, 0, 1, 0)
    plantEmoji.BackgroundTransparency = 1
    plantEmoji.Text = "🌱"
    plantEmoji.TextScaled = true
    plantEmoji.Font = Enum.Font.Gotham
    plantEmoji.Parent = plantIcon
    
    -- Plant info
    local plantInfo = Instance.new("Frame")
    plantInfo.Name = "PlantInfo"
    plantInfo.Size = UDim2.new(1, -80, 1, -20)
    plantInfo.Position = UDim2.new(0, 80, 0, 10)
    plantInfo.BackgroundTransparency = 1
    plantInfo.Parent = plantStatus
    
    -- Plant name
    local plantName = Instance.new("TextLabel")
    plantName.Name = "PlantName"
    plantName.Size = UDim2.new(1, 0, 0, 25)
    plantName.Position = UDim2.new(0, 0, 0, 0)
    plantName.BackgroundTransparency = 1
    plantName.Text = "Empty Plot"
    plantName.TextColor3 = Color3.fromRGB(255, 255, 255)
    plantName.TextScaled = true
    plantName.Font = Enum.Font.GothamBold
    plantName.TextXAlignment = Enum.TextXAlignment.Left
    plantName.Parent = plantInfo
    
    -- Plant stage/progress
    local plantProgress = Instance.new("TextLabel")
    plantProgress.Name = "PlantProgress"
    plantProgress.Size = UDim2.new(1, 0, 0, 20)
    plantProgress.Position = UDim2.new(0, 0, 0, 25)
    plantProgress.BackgroundTransparency = 1
    plantProgress.Text = "Ready to plant seeds"
    plantProgress.TextColor3 = Color3.fromRGB(200, 200, 200)
    plantProgress.TextScaled = true
    plantProgress.Font = Enum.Font.Gotham
    plantProgress.TextXAlignment = Enum.TextXAlignment.Left
    plantProgress.Parent = plantInfo
    
    -- Growth progress bar
    local progressBarBG = Instance.new("Frame")
    progressBarBG.Name = "ProgressBarBG"
    progressBarBG.Size = UDim2.new(1, 0, 0, 15)
    progressBarBG.Position = UDim2.new(0, 0, 0, 45)
    progressBarBG.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    progressBarBG.BorderSizePixel = 0
    progressBarBG.Parent = plantInfo
    
    local progressCorner = Instance.new("UICorner")
    progressCorner.CornerRadius = UDim.new(0, 3)
    progressCorner.Parent = progressBarBG
    
    local progressBar = Instance.new("Frame")
    progressBar.Name = "ProgressBar"
    progressBar.Size = UDim2.new(0, 0, 1, 0)
    progressBar.Position = UDim2.new(0, 0, 0, 0)
    progressBar.BackgroundColor3 = Color3.fromRGB(100, 180, 100)
    progressBar.BorderSizePixel = 0
    progressBar.Parent = progressBarBG
    
    local progressBarCorner = Instance.new("UICorner")
    progressBarCorner.CornerRadius = UDim.new(0, 3)
    progressBarCorner.Parent = progressBar
    
    -- Reward info
    local rewardInfo = Instance.new("TextLabel")
    rewardInfo.Name = "RewardInfo"
    rewardInfo.Size = UDim2.new(1, 0, 0, 25)
    rewardInfo.Position = UDim2.new(0, 0, 0, 85)
    rewardInfo.BackgroundTransparency = 1
    rewardInfo.Text = "💰 Reward: +0 coins, +0 XP"
    rewardInfo.TextColor3 = Color3.fromRGB(255, 215, 0)
    rewardInfo.TextScaled = true
    rewardInfo.Font = Enum.Font.Gotham
    rewardInfo.TextXAlignment = Enum.TextXAlignment.Left
    rewardInfo.Parent = content
end

function PlotClickHandler:CreatePanelActions(parent)
    local actions = Instance.new("Frame")
    actions.Name = "Actions"
    actions.Size = UDim2.new(1, -20, 0, 40)
    actions.Position = UDim2.new(0, 10, 1, -45)
    actions.BackgroundTransparency = 1
    actions.Parent = parent
    
    -- Primary action button (Plant/Harvest)
    local primaryButton = Instance.new("TextButton")
    primaryButton.Name = "PrimaryButton"
    primaryButton.Size = UDim2.new(0.48, 0, 1, 0)
    primaryButton.Position = UDim2.new(0, 0, 0, 0)
    primaryButton.BackgroundColor3 = Color3.fromRGB(80, 150, 80)
    primaryButton.BorderSizePixel = 0
    primaryButton.Text = "🌱 Plant Seed"
    primaryButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    primaryButton.TextScaled = true
    primaryButton.Font = Enum.Font.GothamBold
    primaryButton.Parent = actions
    
    local primaryCorner = Instance.new("UICorner")
    primaryCorner.CornerRadius = UDim.new(0, 8)
    primaryCorner.Parent = primaryButton
    
    -- Secondary action button (Shop/Info)
    local secondaryButton = Instance.new("TextButton")
    secondaryButton.Name = "SecondaryButton"
    secondaryButton.Size = UDim2.new(0.48, 0, 1, 0)
    secondaryButton.Position = UDim2.new(0.52, 0, 0, 0)
    secondaryButton.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
    secondaryButton.BorderSizePixel = 0
    secondaryButton.Text = "🛒 Shop"
    secondaryButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    secondaryButton.TextScaled = true
    secondaryButton.Font = Enum.Font.GothamBold
    secondaryButton.Parent = actions
    
    local secondaryCorner = Instance.new("UICorner")
    secondaryCorner.CornerRadius = UDim.new(0, 8)
    secondaryCorner.Parent = secondaryButton
    
    -- Set up button functionality
    primaryButton.MouseButton1Click:Connect(function()
        self:OnPrimaryActionClicked()
    end)
    
    secondaryButton.MouseButton1Click:Connect(function()
        self:OnSecondaryActionClicked()
    end)
    
    -- Add hover effects
    self:AddButtonHoverEffect(primaryButton, Color3.fromRGB(80, 150, 80), Color3.fromRGB(100, 170, 100))
    self:AddButtonHoverEffect(secondaryButton, Color3.fromRGB(120, 120, 120), Color3.fromRGB(140, 140, 140))
end

function PlotClickHandler:CreatePlotHighlight()
    -- Create highlight part that will follow selected plot
    self.PlotHighlight = Instance.new("Part")
    self.PlotHighlight.Name = "PlotHighlight"
    self.PlotHighlight.Size = Vector3.new(8, 0.1, 8)
    self.PlotHighlight.Material = Enum.Material.ForceField
    self.PlotHighlight.BrickColor = BrickColor.new("Bright green")
    self.PlotHighlight.Anchored = true
    self.PlotHighlight.CanCollide = false
    self.PlotHighlight.Transparency = 0.5
    self.PlotHighlight.Parent = workspace
    self.PlotHighlight.Visible = false
    
    -- Add selection effect
    local selectionBox = Instance.new("SelectionBox")
    selectionBox.Adornee = self.PlotHighlight
    selectionBox.Color3 = Color3.fromRGB(100, 255, 100)
    selectionBox.LineThickness = 0.2
    selectionBox.Transparency = 0.3
    selectionBox.Parent = self.PlotHighlight
end

-- ==========================================
-- INPUT CONNECTION SETUP
-- ==========================================

function PlotClickHandler:SetupInputConnections()
    -- Touch/Click input
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.UserInputType == Enum.UserInputType.Touch or 
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            self:OnTouchInput(input)
        end
    end)
    
    -- Handle mobile orientation changes
    if self.IsTouchDevice then
        UserInputService.DeviceOrientationChanged:Connect(function()
            self:OnOrientationChanged()
        end)
    end
    
    print("📱 PlotClickHandler: Input connections established")
end

function PlotClickHandler:OnTouchInput(input)
    -- Check cooldown
    local currentTime = tick()
    if currentTime - self.LastTouchTime < self.TouchCooldown then
        return
    end
    self.LastTouchTime = currentTime
    
    -- Get touch position
    local touchPosition = input.Position
    
    -- Raycast from camera through touch position
    local plotHit = self:RaycastForPlot(touchPosition)
    
    if plotHit then
        self:OnPlotClicked(plotHit.plotId, plotHit.position)
    else
        -- Clicked somewhere else, hide plot info if visible
        if self.PlotInfoPanel.Visible then
            self:HidePlotInfo()
        end
    end
end

function PlotClickHandler:RaycastForPlot(screenPosition)
    -- Create ray from camera through screen position
    local camera = workspace.CurrentCamera
    local ray = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)
    
    -- Perform raycast
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Whitelist
    raycastParams.FilterDescendantsInstances = {workspace:FindFirstChild("Plots")}
    
    local raycastResult = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
    
    if raycastResult then
        local hitPart = raycastResult.Instance
        
        -- Check if hit part is a plot
        local plotId = self:GetPlotIdFromPart(hitPart)
        if plotId then
            return {
                plotId = plotId,
                position = raycastResult.Position,
                part = hitPart
            }
        end
    end
    
    return nil
end

function PlotClickHandler:GetPlotIdFromPart(part)
    -- Check if part has plot ID attribute
    if part:GetAttribute("PlotId") then
        return part:GetAttribute("PlotId")
    end
    
    -- Check parent model
    local parent = part.Parent
    if parent and parent:GetAttribute("PlotId") then
        return parent:GetAttribute("PlotId")
    end
    
    -- Check for plot naming convention
    if part.Name:find("Plot") then
        local plotNumber = part.Name:match("Plot(%d+)")
        if plotNumber then
            return tonumber(plotNumber)
        end
    end
    
    return nil
end

-- ==========================================
-- PLOT INTERACTION LOGIC
-- ==========================================

function PlotClickHandler:OnPlotClicked(plotId, worldPosition)
    -- Validate plot ownership first
    if not self:IsPlayerPlot(plotId) then
        self:ShowNotification("❌ This is not your plot!", "error")
        return
    end
    
    self.CurrentSelectedPlot = plotId
    
    -- Update highlight
    self:UpdatePlotHighlight(plotId, worldPosition)
    
    -- Get plot status from server
    self:RequestPlotStatus(plotId)
    
    print("📱 PlotClickHandler: Selected plot", plotId)
end

function PlotClickHandler:UpdatePlotHighlight(plotId, worldPosition)
    if self.PlotHighlight then
        self.PlotHighlight.Position = Vector3.new(worldPosition.X, worldPosition.Y + 0.1, worldPosition.Z)
        self.PlotHighlight.Visible = true
        
        -- Animate highlight appearance
        self.PlotHighlight.Transparency = 1
        TweenService:Create(self.PlotHighlight, TweenInfo.new(0.3), {Transparency = 0.5}):Play()
    end
end

function PlotClickHandler:RequestPlotStatus(plotId)
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if remoteEvents then
        local getHarvestInfoFunction = remoteEvents:FindFirstChild("GetHarvestInfo")
        if getHarvestInfoFunction then
            local plotInfo = getHarvestInfoFunction:InvokeServer(plotId)
            self:UpdatePlotInfoPanel(plotInfo)
        end
    end
end

function PlotClickHandler:UpdatePlotInfoPanel(plotInfo)
    if not plotInfo then
        self:HidePlotInfo()
        return
    end
    
    local panel = self.PlotInfoPanel
    
    -- Update header
    local header = panel:FindFirstChild("Header")
    if header then
        local title = header:FindFirstChild("PlotTitle")
        if title then
            title.Text = "🌱 Plot #" .. plotInfo.plotId
        end
    end
    
    -- Update content
    local content = panel:FindFirstChild("Content")
    if content then
        self:UpdatePlantStatus(content, plotInfo)
        self:UpdateRewardInfo(content, plotInfo)
    end
    
    -- Update action buttons
    local actions = panel:FindFirstChild("Actions")
    if actions then
        self:UpdateActionButtons(actions, plotInfo)
    end
    
    -- Show panel
    self:ShowPlotInfo()
end

function PlotClickHandler:UpdatePlantStatus(content, plotInfo)
    local plantStatus = content:FindFirstChild("PlantStatus")
    if not plantStatus then return end
    
    local plantIcon = plantStatus:FindFirstChild("PlantIcon")
    local plantInfo = plantStatus:FindFirstChild("PlantInfo")
    
    if plotInfo.isEmpty then
        -- Empty plot
        if plantIcon then
            plantIcon.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
            local emoji = plantIcon:FindFirstChild("PlantEmoji")
            if emoji then emoji.Text = "❓" end
        end
        
        if plantInfo then
            local name = plantInfo:FindFirstChild("PlantName")
            local progress = plantInfo:FindFirstChild("PlantProgress")
            local progressBar = plantInfo:FindFirstChild("ProgressBarBG"):FindFirstChild("ProgressBar")
            
            if name then name.Text = "Empty Plot" end
            if progress then progress.Text = "Ready to plant seeds" end
            if progressBar then progressBar.Size = UDim2.new(0, 0, 1, 0) end
        end
    else
        -- Has plant
        local plantConfig = ConfigModule.Plants[plotInfo.plantType]
        
        if plantIcon then
            plantIcon.BackgroundColor3 = plantConfig.color or Color3.fromRGB(100, 150, 100)
            local emoji = plantIcon:FindFirstChild("PlantEmoji")
            if emoji then emoji.Text = plantConfig.emoji or "🌱" end
        end
        
        if plantInfo then
            local name = plantInfo:FindFirstChild("PlantName")
            local progress = plantInfo:FindFirstChild("PlantProgress")
            local progressBar = plantInfo:FindFirstChild("ProgressBarBG"):FindFirstChild("ProgressBar")
            
            if name then name.Text = plotInfo.plantType end
            
            if plotInfo.canHarvest then
                if progress then progress.Text = "🌟 Ready to harvest!" end
                if progressBar then progressBar.Size = UDim2.new(1, 0, 1, 0) end
            else
                local timeLeft = plotInfo.timeLeft or 0
                local minutes = math.floor(timeLeft / 60)
                local seconds = timeLeft % 60
                
                if progress then 
                    progress.Text = string.format("Growing... %dm %ds left", minutes, seconds)
                end
                
                if progressBar and plantConfig then
                    local totalTime = plantConfig.growthTime
                    local elapsed = totalTime - timeLeft
                    local progressPercent = elapsed / totalTime
                    progressBar.Size = UDim2.new(progressPercent, 0, 1, 0)
                end
            end
        end
    end
end

function PlotClickHandler:UpdateRewardInfo(content, plotInfo)
    local rewardInfo = content:FindFirstChild("RewardInfo")
    if not rewardInfo then return end
    
    if plotInfo.isEmpty then
        rewardInfo.Text = "💰 Reward: Plant seeds to earn!"
    else
        local rewards = plotInfo.rewards or {coins = 0, xp = 0}
        rewardInfo.Text = string.format("💰 Reward: +%d coins, +%d XP", rewards.coins, rewards.xp)
    end
end

function PlotClickHandler:UpdateActionButtons(actions, plotInfo)
    local primaryButton = actions:FindFirstChild("PrimaryButton")
    local secondaryButton = actions:FindFirstChild("SecondaryButton")
    
    if not primaryButton or not secondaryButton then return end
    
    if plotInfo.isEmpty then
        -- Empty plot - show plant options
        primaryButton.Text = "🌱 Plant Seed"
        primaryButton.BackgroundColor3 = Color3.fromRGB(80, 150, 80)
        primaryButton.Visible = true
        
        secondaryButton.Text = "🛒 Shop"
        secondaryButton.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
        secondaryButton.Visible = true
    elseif plotInfo.canHarvest then
        -- Ready to harvest
        primaryButton.Text = "🌾 Harvest"
        primaryButton.BackgroundColor3 = Color3.fromRGB(255, 165, 0)
        primaryButton.Visible = true
        
        secondaryButton.Text = "ℹ️ Info"
        secondaryButton.BackgroundColor3 = Color3.fromRGB(100, 100, 150)
        secondaryButton.Visible = true
    else
        -- Growing
        primaryButton.Text = "⏰ Growing..."
        primaryButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        primaryButton.Visible = true
        
        secondaryButton.Text = "ℹ️ Info"
        secondaryButton.BackgroundColor3 = Color3.fromRGB(100, 100, 150)
        secondaryButton.Visible = true
    end
end

-- ==========================================
-- ACTION HANDLING
-- ==========================================

function PlotClickHandler:OnPrimaryActionClicked()
    if not self.CurrentSelectedPlot then return end
    
    -- Get current plot status to determine action
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then return end
    
    local getHarvestInfoFunction = remoteEvents:FindFirstChild("GetHarvestInfo")
    if getHarvestInfoFunction then
        local plotInfo = getHarvestInfoFunction:InvokeServer(self.CurrentSelectedPlot)
        
        if plotInfo and plotInfo.isEmpty then
            -- Open plant selection
            self:OpenPlantSelection()
        elseif plotInfo and plotInfo.canHarvest then
            -- Harvest plant
            self:HarvestPlant()
        else
            -- Plant is growing, show info
            self:ShowNotification("🌱 Plant is still growing!", "info")
        end
    end
end

function PlotClickHandler:OnSecondaryActionClicked()
    if not self.CurrentSelectedPlot then return end
    
    -- Get current plot status
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then return end
    
    local getHarvestInfoFunction = remoteEvents:FindFirstChild("GetHarvestInfo")
    if getHarvestInfoFunction then
        local plotInfo = getHarvestInfoFunction:InvokeServer(self.CurrentSelectedPlot)
        
        if plotInfo and plotInfo.isEmpty then
            -- Open shop
            self:OpenShop()
        else
            -- Show plant details
            self:ShowPlantDetails(plotInfo)
        end
    end
end

function PlotClickHandler:OpenPlantSelection()
    -- Hide plot info temporarily
    self:HidePlotInfo()
    
    -- Open shop UI focused on seeds
    local shopUIHandler = require(script.Parent:FindFirstChild("ShopUIHandler"))
    if shopUIHandler then
        shopUIHandler:OpenShop()
        shopUIHandler:SwitchToTab("seeds")
    end
end

function PlotClickHandler:HarvestPlant()
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if remoteEvents then
        local harvestPlantEvent = remoteEvents:FindFirstChild("HarvestPlant")
        if harvestPlantEvent then
            harvestPlantEvent:FireServer(self.CurrentSelectedPlot)
            
            -- Hide plot info and update after a delay
            self:HidePlotInfo()
            
            wait(0.5) -- Give server time to process
            self:RequestPlotStatus(self.CurrentSelectedPlot)
        end
    end
end

function PlotClickHandler:OpenShop()
    local shopUIHandler = require(script.Parent:FindFirstChild("ShopUIHandler"))
    if shopUIHandler then
        shopUIHandler:OpenShop()
    end
end

function PlotClickHandler:ShowPlantDetails(plotInfo)
    -- Show detailed plant information
    local plantConfig = ConfigModule.Plants[plotInfo.plantType]
    if plantConfig then
        local detailMessage = string.format(
            "🌱 %s\n" ..
            "⏰ Growth Time: %ds\n" ..
            "💰 Sell Price: %d coins\n" ..
            "⭐ XP Reward: %d\n" ..
            "📈 Stage: %d/3",
            plotInfo.plantType,
            plantConfig.growthTime,
            plantConfig.sellPrice,
            plantConfig.xpReward,
            plotInfo.stage or 1
        )
        
        self:ShowNotification(detailMessage, "info")
    end
end

-- ==========================================
-- UI MANAGEMENT
-- ==========================================

function PlotClickHandler:ShowPlotInfo()
    if not self.PlotInfoPanel then return end
    
    self.PlotInfoPanel.Visible = true
    
    -- Animate panel sliding up
    self.PlotInfoPanel.Position = UDim2.new(0.5, -150, 1, 0)
    TweenService:Create(self.PlotInfoPanel, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Position = UDim2.new(0.5, -150, 1, -220)
    }):Play()
end

function PlotClickHandler:HidePlotInfo()
    if not self.PlotInfoPanel or not self.PlotInfoPanel.Visible then return end
    
    -- Animate panel sliding down
    local hideTween = TweenService:Create(self.PlotInfoPanel, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
        Position = UDim2.new(0.5, -150, 1, 0)
    })
    
    hideTween:Play()
    hideTween.Completed:Connect(function()
        self.PlotInfoPanel.Visible = false
        self.CurrentSelectedPlot = nil
        
        -- Hide highlight
        if self.PlotHighlight then
            self.PlotHighlight.Visible = false
        end
    end)
end

function PlotClickHandler:AddButtonHoverEffect(button, normalColor, hoverColor)
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = hoverColor}):Play()
    end)
    
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = normalColor}):Play()
    end)
end

-- ==========================================
-- UPDATE LOOP
-- ==========================================

function PlotClickHandler:SetupUpdateLoop()
    -- Update plot info every 5 seconds if panel is visible
    spawn(function()
        while true do
            wait(5)
            
            if self.PlotInfoPanel.Visible and self.CurrentSelectedPlot then
                self:RequestPlotStatus(self.CurrentSelectedPlot)
            end
        end
    end)
end

function PlotClickHandler:SetupPlotDetection()
    -- Continuously update plot ownership and states
    spawn(function()
        while true do
            wait(2)
            self:UpdateNearbyPlots()
        end
    end)
end

function PlotClickHandler:UpdateNearbyPlots()
    -- Check for new plots or changes in plot ownership
    local plotsFolder = workspace:FindFirstChild("Plots")
    if plotsFolder then
        for _, plot in pairs(plotsFolder:GetChildren()) do
            if plot:IsA("BasePart") and plot:GetAttribute("PlotId") then
                -- Ensure plot has proper click detection
                if not plot:FindFirstChild("ClickDetector") then
                    self:AddClickDetectorToPlot(plot)
                end
            end
        end
    end
end

function PlotClickHandler:AddClickDetectorToPlot(plot)
    local clickDetector = Instance.new("ClickDetector")
    clickDetector.MaxActivationDistance = 50
    clickDetector.Parent = plot
    
    clickDetector.MouseClick:Connect(function(player)
        if player == self.Player then
            local plotId = plot:GetAttribute("PlotId")
            if plotId then
                self:OnPlotClicked(plotId, plot.Position)
            end
        end
    end)
end

-- ==========================================
-- UTILITY FUNCTIONS
-- ==========================================

function PlotClickHandler:IsPlayerPlot(plotId)
    -- Check if the plot belongs to the current player
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if remoteEvents then
        local getPlayerDataFunction = remoteEvents:FindFirstChild("GetPlayerData")
        if getPlayerDataFunction then
            local playerData = getPlayerDataFunction:InvokeServer()
            if playerData and playerData.plots then
                for _, ownedPlotId in ipairs(playerData.plots) do
                    if ownedPlotId == plotId then
                        return true
                    end
                end
            end
        end
    end
    return false
end

function PlotClickHandler:OnOrientationChanged()
    -- Adjust UI for orientation changes on mobile
    if self.PlotInfoPanel and self.PlotInfoPanel.Visible then
        -- Temporarily hide and reshow with correct positioning
        local currentPlot = self.CurrentSelectedPlot
        self:HidePlotInfo()
        
        wait(0.1)
        
        if currentPlot then
            self:RequestPlotStatus(currentPlot)
        end
    end
end

function PlotClickHandler:ShowNotification(message, messageType)
    -- Show floating notification
    local notification = Instance.new("ScreenGui")
    notification.Name = "PlotNotification"
    notification.Parent = self.PlayerGui
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 250, 0, 50)
    frame.Position = UDim2.new(0.5, -125, 0, -60)
    frame.BorderSizePixel = 0
    frame.Parent = notification
    
    -- Color based on type
    local bgColor = Color3.fromRGB(60, 60, 60)
    if messageType == "error" then
        bgColor = Color3.fromRGB(150, 80, 80)
    elseif messageType == "info" then
        bgColor = Color3.fromRGB(80, 120, 150)
    end
    frame.BackgroundColor3 = bgColor
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 1, 0)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = message
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextScaled = true
    label.Font = Enum.Font.Gotham
    label.Parent = frame
    
    -- Animate notification
    TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Position = UDim2.new(0.5, -125, 0, 20)
    }):Play()
    
    -- Auto-hide
    wait(3)
    TweenService:Create(frame, TweenInfo.new(0.3), {
        Position = UDim2.new(0.5, -125, 0, -60),
        BackgroundTransparency = 1
    }):Play()
    
    wait(0.3)
    notification:Destroy()
end

-- ==========================================
-- PUBLIC API
-- ==========================================

function PlotClickHandler:GetSelectedPlot()
    return self.CurrentSelectedPlot
end

function PlotClickHandler:IsPlotInfoVisible()
    return self.PlotInfoPanel and self.PlotInfoPanel.Visible
end

function PlotClickHandler:SelectPlot(plotId)
    -- Programmatically select a plot
    if self:IsPlayerPlot(plotId) then
        self.CurrentSelectedPlot = plotId
        self:RequestPlotStatus(plotId)
    end
end

return PlotClickHandler
