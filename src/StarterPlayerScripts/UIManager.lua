--[[
    UIManager.lua
    Main Client UI Controller (Mobile-First)
    
    Priority: 1 (Client entry point)
    Dependencies: ConfigModule
    
    Features:
    - Mobile-responsive UI layout
    - HUD management (coins, XP, level)
    - Touch-optimized controls
    - Screen size adaptation
    - UI context switching
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Load configuration
local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)

local UIManager = {}
UIManager.__index = UIManager

-- ==========================================
-- UI DATA STORAGE
-- ==========================================

UIManager.MainScreenGui = nil
UIManager.HUD = nil
UIManager.CurrentScreenSize = nil
UIManager.UIScale = 1.0
UIManager.IsUIHidden = false

-- UI State tracking
UIManager.PlayerData = {
    coins = 0,
    xp = 0,
    level = 1,
    isVIP = false,
    plots = {},
    unlockedPlants = {}
}

-- ==========================================
-- INITIALIZATION
-- ==========================================

function UIManager:Initialize()
    print("📱 UIManager: Initializing mobile UI system...")
    
    -- Detect screen size and adapt UI
    self:DetectScreenSize()
    
    -- Create main UI structure
    self:CreateMainScreenGui()
    self:CreateHUD()
    
    -- Set up UI event handlers
    self:SetupUIEvents()
    
    -- Set up remote event listeners
    self:SetupRemoteEvents()
    
    -- Initialize UI handlers
    self:InitializeUIHandlers()
    
    print("✅ UIManager: Mobile UI system initialized successfully")
end

function UIManager:DetectScreenSize()
    local screenSize = workspace.CurrentCamera.ViewportSize
    self.CurrentScreenSize = screenSize
    
    -- Determine screen category and UI scale
    local category = ConfigModule:GetScreenSizeCategory(screenSize)
    local config = ConfigModule.UI.SCREEN_SIZES[category]
    
    self.UIScale = config.uiScale
    
    print("📱 UIManager: Detected", category, "screen (" .. screenSize.X .. "x" .. screenSize.Y .. ") - UI Scale:", self.UIScale)
end

-- ==========================================
-- MAIN UI STRUCTURE
-- ==========================================

function UIManager:CreateMainScreenGui()
    -- Create main ScreenGui container
    local mainScreenGui = Instance.new("ScreenGui")
    mainScreenGui.Name = "MainScreenGui"
    mainScreenGui.ResetOnSpawn = false
    mainScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    mainScreenGui.Parent = playerGui
    
    self.MainScreenGui = mainScreenGui
    
    print("📱 UIManager: Created main ScreenGui container")
end

function UIManager:CreateHUD()
    -- Create HUD frame (always visible elements)
    local hudFrame = Instance.new("Frame")
    hudFrame.Name = "HUD"
    hudFrame.Size = UDim2.new(1, 0, 1, 0)
    hudFrame.Position = UDim2.new(0, 0, 0, 0)
    hudFrame.BackgroundTransparency = 1
    hudFrame.Parent = self.MainScreenGui
    
    self.HUD = hudFrame
    
    -- Create HUD elements
    self:CreateTopLeftHUD()
    self:CreateTopRightHUD()
    self:CreateBottomCenterHUD()
    
    print("📱 UIManager: Created HUD layout")
end

-- ==========================================
-- HUD COMPONENTS
-- ==========================================

function UIManager:CreateTopLeftHUD()
    -- Top-left frame for coins and level
    local topLeftFrame = Instance.new("Frame")
    topLeftFrame.Name = "TopLeftFrame"
    topLeftFrame.Size = UDim2.new(0, 200 * self.UIScale, 0, 80 * self.UIScale)
    topLeftFrame.Position = UDim2.new(0, 10, 0, 10)
    topLeftFrame.BackgroundTransparency = 1
    topLeftFrame.Parent = self.HUD
    
    -- Coins display
    local coinsFrame = Instance.new("Frame")
    coinsFrame.Name = "CoinsFrame"
    coinsFrame.Size = UDim2.new(1, 0, 0.45, 0)
    coinsFrame.Position = UDim2.new(0, 0, 0, 0)
    coinsFrame.BackgroundColor3 = ConfigModule.UI.COLORS.PRIMARY
    coinsFrame.BackgroundTransparency = 0.2
    coinsFrame.BorderSizePixel = 0
    coinsFrame.Parent = topLeftFrame
    
    -- Add corner radius
    local coinsCorner = Instance.new("UICorner")
    coinsCorner.CornerRadius = UDim.new(0, 8)
    coinsCorner.Parent = coinsFrame
    
    -- Coin icon
    local coinIcon = Instance.new("TextLabel")
    coinIcon.Name = "CoinIcon"
    coinIcon.Size = UDim2.new(0, 32 * self.UIScale, 0, 32 * self.UIScale)
    coinIcon.Position = UDim2.new(0, 5, 0.5, -16 * self.UIScale)
    coinIcon.BackgroundTransparency = 1
    coinIcon.Text = "💰"
    coinIcon.TextColor3 = ConfigModule.UI.COLORS.SECONDARY
    coinIcon.TextScaled = true
    coinIcon.Font = Enum.Font.Gotham
    coinIcon.Parent = coinsFrame
    
    -- Coin label
    local coinLabel = Instance.new("TextLabel")
    coinLabel.Name = "CoinLabel"
    coinLabel.Size = UDim2.new(1, -40 * self.UIScale, 1, 0)
    coinLabel.Position = UDim2.new(0, 40 * self.UIScale, 0, 0)
    coinLabel.BackgroundTransparency = 1
    coinLabel.Text = "0"
    coinLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    coinLabel.TextScaled = true
    coinLabel.Font = Enum.Font.GothamBold
    coinLabel.TextXAlignment = Enum.TextXAlignment.Left
    coinLabel.Parent = coinsFrame
    
    -- Level display
    local levelFrame = Instance.new("Frame")
    levelFrame.Name = "LevelFrame"
    levelFrame.Size = UDim2.new(1, 0, 0.45, 0)
    levelFrame.Position = UDim2.new(0, 0, 0.55, 0)
    levelFrame.BackgroundColor3 = ConfigModule.UI.COLORS.SUCCESS
    levelFrame.BackgroundTransparency = 0.2
    levelFrame.BorderSizePixel = 0
    levelFrame.Parent = topLeftFrame
    
    -- Add corner radius
    local levelCorner = Instance.new("UICorner")
    levelCorner.CornerRadius = UDim.new(0, 8)
    levelCorner.Parent = levelFrame
    
    -- Level icon
    local levelIcon = Instance.new("TextLabel")
    levelIcon.Name = "LevelIcon"
    levelIcon.Size = UDim2.new(0, 32 * self.UIScale, 0, 32 * self.UIScale)
    levelIcon.Position = UDim2.new(0, 5, 0.5, -16 * self.UIScale)
    levelIcon.BackgroundTransparency = 1
    levelIcon.Text = "⭐"
    levelIcon.TextColor3 = ConfigModule.UI.COLORS.SECONDARY
    levelIcon.TextScaled = true
    levelIcon.Font = Enum.Font.Gotham
    levelIcon.Parent = levelFrame
    
    -- Level label
    local levelLabel = Instance.new("TextLabel")
    levelLabel.Name = "LevelLabel"
    levelLabel.Size = UDim2.new(1, -40 * self.UIScale, 1, 0)
    levelLabel.Position = UDim2.new(0, 40 * self.UIScale, 0, 0)
    levelLabel.BackgroundTransparency = 1
    levelLabel.Text = "Level 1"
    levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    levelLabel.TextScaled = true
    levelLabel.Font = Enum.Font.GothamBold
    levelLabel.TextXAlignment = Enum.TextXAlignment.Left
    levelLabel.Parent = levelFrame
end

function UIManager:CreateTopRightHUD()
    -- Top-right frame for settings and hide UI
    local topRightFrame = Instance.new("Frame")
    topRightFrame.Name = "TopRightFrame"
    topRightFrame.Size = UDim2.new(0, 100 * self.UIScale, 0, 50 * self.UIScale)
    topRightFrame.Position = UDim2.new(1, -110 * self.UIScale, 0, 10)
    topRightFrame.BackgroundTransparency = 1
    topRightFrame.Parent = self.HUD
    
    -- Hide UI button
    local hideUIButton = Instance.new("TextButton")
    hideUIButton.Name = "HideUIButton"
    hideUIButton.Size = UDim2.new(0, 44 * self.UIScale, 0, 44 * self.UIScale)
    hideUIButton.Position = UDim2.new(1, -50 * self.UIScale, 0, 0)
    hideUIButton.BackgroundColor3 = ConfigModule.UI.COLORS.PRIMARY
    hideUIButton.BackgroundTransparency = 0.2
    hideUIButton.BorderSizePixel = 0
    hideUIButton.Text = "👁️"
    hideUIButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    hideUIButton.TextScaled = true
    hideUIButton.Font = Enum.Font.Gotham
    hideUIButton.Parent = topRightFrame
    
    -- Add corner radius
    local hideUICorner = Instance.new("UICorner")
    hideUICorner.CornerRadius = UDim.new(0, 8)
    hideUICorner.Parent = hideUIButton
    
    -- Hide UI button functionality
    hideUIButton.MouseButton1Click:Connect(function()
        self:ToggleUIVisibility()
    end)
    
    -- Settings button
    local settingsButton = Instance.new("TextButton")
    settingsButton.Name = "SettingsButton"
    settingsButton.Size = UDim2.new(0, 44 * self.UIScale, 0, 44 * self.UIScale)
    settingsButton.Position = UDim2.new(1, -100 * self.UIScale, 0, 0)
    settingsButton.BackgroundColor3 = ConfigModule.UI.COLORS.TEXT_SECONDARY
    settingsButton.BackgroundTransparency = 0.2
    settingsButton.BorderSizePixel = 0
    settingsButton.Text = "⚙️"
    settingsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    settingsButton.TextScaled = true
    settingsButton.Font = Enum.Font.Gotham
    settingsButton.Parent = topRightFrame
    
    -- Add corner radius
    local settingsCorner = Instance.new("UICorner")
    settingsCorner.CornerRadius = UDim.new(0, 8)
    settingsCorner.Parent = settingsButton
end

function UIManager:CreateBottomCenterHUD()
    -- Bottom-center frame for XP progress bar
    local bottomCenterFrame = Instance.new("Frame")
    bottomCenterFrame.Name = "BottomCenterFrame"
    bottomCenterFrame.Size = UDim2.new(0, 200 * self.UIScale, 0, 20 * self.UIScale)
    bottomCenterFrame.Position = UDim2.new(0.5, -100 * self.UIScale, 1, -30 * self.UIScale)
    bottomCenterFrame.BackgroundTransparency = 1
    bottomCenterFrame.Parent = self.HUD
    
    -- XP Progress Bar Background
    local xpBarBG = Instance.new("Frame")
    xpBarBG.Name = "XPProgressBarBG"
    xpBarBG.Size = UDim2.new(1, 0, 1, 0)
    xpBarBG.Position = UDim2.new(0, 0, 0, 0)
    xpBarBG.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    xpBarBG.BackgroundTransparency = 0.5
    xpBarBG.BorderSizePixel = 0
    xpBarBG.Parent = bottomCenterFrame
    
    -- Add corner radius
    local xpBGCorner = Instance.new("UICorner")
    xpBGCorner.CornerRadius = UDim.new(0, 10)
    xpBGCorner.Parent = xpBarBG
    
    -- XP Progress Bar Fill
    local xpBarFill = Instance.new("Frame")
    xpBarFill.Name = "XPProgressBarFill"
    xpBarFill.Size = UDim2.new(0, 0, 1, 0) -- Start empty
    xpBarFill.Position = UDim2.new(0, 0, 0, 0)
    xpBarFill.BackgroundColor3 = ConfigModule.UI.COLORS.SUCCESS
    xpBarFill.BorderSizePixel = 0
    xpBarFill.Parent = xpBarBG
    
    -- Add corner radius
    local xpFillCorner = Instance.new("UICorner")
    xpFillCorner.CornerRadius = UDim.new(0, 10)
    xpFillCorner.Parent = xpBarFill
    
    -- XP Progress Label
    local xpLabel = Instance.new("TextLabel")
    xpLabel.Name = "XPLabel"
    xpLabel.Size = UDim2.new(1, 0, 1, 0)
    xpLabel.Position = UDim2.new(0, 0, 0, 0)
    xpLabel.BackgroundTransparency = 1
    xpLabel.Text = "XP: 0 / 100"
    xpLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    xpLabel.TextScaled = true
    xpLabel.Font = Enum.Font.Gotham
    xpLabel.TextStrokeTransparency = 0
    xpLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    xpLabel.Parent = xpBarBG
end

-- ==========================================
-- UI UPDATE FUNCTIONS
-- ==========================================

function UIManager:UpdatePlayerData(newData)
    -- Update stored player data
    for key, value in pairs(newData) do
        self.PlayerData[key] = value
    end
    
    -- Update UI elements
    self:UpdateHUD()
end

function UIManager:UpdateHUD()
    -- Update coins display
    local coinLabel = self.HUD.TopLeftFrame.CoinsFrame.CoinLabel
    if coinLabel then
        coinLabel.Text = tostring(self.PlayerData.coins)
    end
    
    -- Update level display
    local levelLabel = self.HUD.TopLeftFrame.LevelFrame.LevelLabel
    if levelLabel then
        levelLabel.Text = "Level " .. tostring(self.PlayerData.level)
    end
    
    -- Update XP progress bar (placeholder for now)
    local xpLabel = self.HUD.BottomCenterFrame.XPProgressBarBG.XPLabel
    if xpLabel then
        xpLabel.Text = "XP: " .. tostring(self.PlayerData.xp)
    end
    
    -- Update VIP status visual indicator
    if self.PlayerData.isVIP then
        local levelIcon = self.HUD.TopLeftFrame.LevelFrame.LevelIcon
        if levelIcon then
            levelIcon.Text = "👑" -- Crown for VIP
            levelIcon.TextColor3 = ConfigModule.VIP.NAME_COLOR
        end
    end
end

-- ==========================================
-- UI INTERACTION FUNCTIONS
-- ==========================================

function UIManager:ToggleUIVisibility()
    self.IsUIHidden = not self.IsUIHidden
    
    -- Animate UI elements
    local targetTransparency = self.IsUIHidden and 1 or 0
    local tweenInfo = ConfigModule.UI.ANIMATIONS.PANEL_SLIDE_OUT
    
    -- Fade HUD elements
    local elementsToFade = {
        self.HUD.TopLeftFrame,
        self.HUD.BottomCenterFrame
    }
    
    for _, element in ipairs(elementsToFade) do
        if element then
            local tween = TweenService:Create(element, tweenInfo, {
                BackgroundTransparency = targetTransparency
            })
            tween:Play()
        end
    end
    
    print("📱 UIManager: UI visibility toggled -", self.IsUIHidden and "Hidden" or "Visible")
end

-- ==========================================
-- EVENT HANDLING
-- ==========================================

function UIManager:SetupUIEvents()
    -- Handle screen size changes
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        self:OnScreenSizeChanged()
    end)
    
    -- Handle touch/click input (mobile support)
    UserInputService.TouchTapInWorld:Connect(function(position, processedByUI)
        if not processedByUI then
            self:OnWorldTapped(position)
        end
    end)
end

function UIManager:OnScreenSizeChanged()
    local newScreenSize = workspace.CurrentCamera.ViewportSize
    
    -- Only update if size significantly changed
    if math.abs(newScreenSize.X - self.CurrentScreenSize.X) > 50 then
        print("📱 UIManager: Screen size changed, adapting UI...")
        self:DetectScreenSize()
        -- Could rebuild UI with new scale here
    end
end

function UIManager:OnWorldTapped(position)
    -- Handle world tapping for plot interaction
    print("📱 UIManager: World tapped at", position)
    -- This could trigger plot selection UI
end

-- ==========================================
-- REMOTE EVENT HANDLING
-- ==========================================

function UIManager:SetupRemoteEvents()
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then
        warn("⚠️ UIManager: RemoteEvents folder not found")
        return
    end
    
    -- Listen for UI updates from server
    local updateUIEvent = remoteEvents:FindFirstChild("UpdateUI")
    if updateUIEvent then
        updateUIEvent.OnClientEvent:Connect(function(playerData)
            self:UpdatePlayerData(playerData)
        end)
    end
    
    -- Listen for notifications
    local showNotificationEvent = remoteEvents:FindFirstChild("ShowNotification")
    if showNotificationEvent then
        showNotificationEvent.OnClientEvent:Connect(function(message, type)
            self:ShowNotification(message, type)
        end)
    end
end

function UIManager:ShowNotification(message, notificationType)
    print("🔔 UIManager: Notification -", message, "(Type:", notificationType, ")")
    -- Could create a proper notification UI here
end

-- ==========================================
-- UI HANDLERS INITIALIZATION
-- ==========================================

function UIManager:InitializeUIHandlers()
    print("🎨 UIManager: Initializing UI handlers...")
    
    -- Initialize Shop UI Handler
    local success, ShopUIHandler = pcall(function()
        return require(ReplicatedStorage.ClientModules.ShopUIHandler)
    end)
    
    if success and ShopUIHandler then
        local initSuccess, result = pcall(function()
            ShopUIHandler:Initialize()
        end)
        
        if initSuccess then
            print("✅ UIManager: ShopUIHandler initialized successfully")
        else
            warn("❌ UIManager: Failed to initialize ShopUIHandler:", result)
        end
    else
        warn("❌ UIManager: Failed to load ShopUIHandler module:", ShopUIHandler)
    end
end

-- ==========================================
-- INITIALIZATION
-- ==========================================

-- Auto-initialize when script loads
UIManager:Initialize()

return UIManager
