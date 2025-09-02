--[[
    ShopUIHandler.lua
    Client-Side Shop UI Management
    
    Priority: 13 (Mobile shop interface)
    Dependencies: ConfigModule, UIManager (client-side)
    Used by: NPC interaction, shop buttons
    
    Features:
    - Mobile-optimized shop interface
    - Real-time plant unlock status
    - Seed purchase interface
    - VIP-exclusive items display
    - Responsive design for all screen sizes
    - Touch-friendly interaction buttons
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")

-- Load required modules
local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)

local ShopUIHandler = {}
ShopUIHandler.__index = ShopUIHandler

-- ==========================================
-- UI REFERENCES
-- ==========================================

ShopUIHandler.Player = Players.LocalPlayer
ShopUIHandler.PlayerGui = nil
ShopUIHandler.ShopFrame = nil
ShopUIHandler.SeedScrollingFrame = nil
ShopUIHandler.VIPFrame = nil
ShopUIHandler.CurrentShopTab = "seeds"

-- UI State
ShopUIHandler.IsShopOpen = false
ShopUIHandler.PlayerCoins = 0
ShopUIHandler.PlayerLevel = 1
ShopUIHandler.UnlockedPlants = {}
ShopUIHandler.IsVIP = false

-- ==========================================
-- INITIALIZATION
-- ==========================================

function ShopUIHandler:Initialize()
    print("🛒 ShopUIHandler: Initializing shop UI system...")
    
    -- Wait for player GUI
    self.PlayerGui = self.Player:WaitForChild("PlayerGui")
    
    -- Create shop UI
    self:CreateShopUI()
    
    -- Set up event connections
    self:SetupEventConnections()
    
    -- Set up NPC interaction
    self:SetupNPCInteraction()
    
    -- Update initial data
    self:UpdatePlayerData()
    
    print("✅ ShopUIHandler: Shop UI initialized successfully")
end

function ShopUIHandler:CreateShopUI()
    -- Create main shop ScreenGui
    local shopGui = Instance.new("ScreenGui")
    shopGui.Name = "ShopUI"
    shopGui.ResetOnSpawn = false
    shopGui.DisplayOrder = 10
    shopGui.Parent = self.PlayerGui
    
    -- Create main shop frame
    self.ShopFrame = self:CreateMainShopFrame(shopGui)
    
    -- Create content frames
    self.SeedScrollingFrame = self:CreateSeedShopContent(self.ShopFrame)
    self.VIPFrame = self:CreateVIPShopContent(self.ShopFrame)
    
    -- Initially hide shop
    self.ShopFrame.Visible = false
    
    print("🎨 ShopUIHandler: Shop UI created successfully")
end

function ShopUIHandler:CreateMainShopFrame(parent)
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "ShopFrame"
    mainFrame.Size = UDim2.new(0.9, 0, 0.8, 0)
    mainFrame.Position = UDim2.new(0.05, 0, 0.1, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = parent
    
    -- Add corner radius
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame
    
    -- Add drop shadow effect
    local shadow = Instance.new("Frame")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 6, 1, 6)
    shadow.Position = UDim2.new(0, -3, 0, -3)
    shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow.BackgroundTransparency = 0.7
    shadow.ZIndex = mainFrame.ZIndex - 1
    shadow.Parent = mainFrame
    
    local shadowCorner = Instance.new("UICorner")
    shadowCorner.CornerRadius = UDim.new(0, 12)
    shadowCorner.Parent = shadow
    
    -- Create header
    self:CreateShopHeader(mainFrame)
    
    -- Create tab buttons
    self:CreateTabButtons(mainFrame)
    
    return mainFrame
end

function ShopUIHandler:CreateShopHeader(parent)
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 60)
    header.Position = UDim2.new(0, 0, 0, 0)
    header.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
    header.BorderSizePixel = 0
    header.Parent = parent
    
    -- Add corner radius to header
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = header
    
    -- Fix corner clipping with additional frame
    local headerFix = Instance.new("Frame")
    headerFix.Size = UDim2.new(1, 0, 0, 12)
    headerFix.Position = UDim2.new(0, 0, 1, -12)
    headerFix.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
    headerFix.BorderSizePixel = 0
    headerFix.Parent = header
    
    -- Shop title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(0.7, 0, 1, 0)
    title.Position = UDim2.new(0.05, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "🛒 Garden Shop"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.Parent = header
    
    -- Coins display
    local coinsFrame = Instance.new("Frame")
    coinsFrame.Name = "CoinsFrame"
    coinsFrame.Size = UDim2.new(0.25, 0, 0.6, 0)
    coinsFrame.Position = UDim2.new(0.7, 0, 0.2, 0)
    coinsFrame.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
    coinsFrame.BorderSizePixel = 0
    coinsFrame.Parent = header
    
    local coinsCorner = Instance.new("UICorner")
    coinsCorner.CornerRadius = UDim.new(0, 6)
    coinsCorner.Parent = coinsFrame
    
    local coinsLabel = Instance.new("TextLabel")
    coinsLabel.Name = "CoinsLabel"
    coinsLabel.Size = UDim2.new(1, 0, 1, 0)
    coinsLabel.BackgroundTransparency = 1
    coinsLabel.Text = "💰 " .. self.PlayerCoins
    coinsLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
    coinsLabel.TextScaled = true
    coinsLabel.Font = Enum.Font.GothamBold
    coinsLabel.Parent = coinsFrame
    
    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 40, 0, 40)
    closeButton.Position = UDim2.new(1, -50, 0, 10)
    closeButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
    closeButton.BorderSizePixel = 0
    closeButton.Text = "✕"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextScaled = true
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Parent = header
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = closeButton
    
    closeButton.MouseButton1Click:Connect(function()
        self:CloseShop()
    end)
    
    -- Add hover effect to close button
    closeButton.MouseEnter:Connect(function()
        TweenService:Create(closeButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 70, 70)}):Play()
    end)
    
    closeButton.MouseLeave:Connect(function()
        TweenService:Create(closeButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(220, 50, 50)}):Play()
    end)
end

function ShopUIHandler:CreateTabButtons(parent)
    local tabFrame = Instance.new("Frame")
    tabFrame.Name = "TabFrame"
    tabFrame.Size = UDim2.new(1, 0, 0, 50)
    tabFrame.Position = UDim2.new(0, 0, 0, 60)
    tabFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    tabFrame.BorderSizePixel = 0
    tabFrame.Parent = parent
    
    -- Seeds tab
    local seedsTab = Instance.new("TextButton")
    seedsTab.Name = "SeedsTab"
    seedsTab.Size = UDim2.new(0.45, -5, 0.8, 0)
    seedsTab.Position = UDim2.new(0.05, 0, 0.1, 0)
    seedsTab.BackgroundColor3 = Color3.fromRGB(80, 150, 80)
    seedsTab.BorderSizePixel = 0
    seedsTab.Text = "🌱 Seeds"
    seedsTab.TextColor3 = Color3.fromRGB(255, 255, 255)
    seedsTab.TextScaled = true
    seedsTab.Font = Enum.Font.Gotham
    seedsTab.Parent = tabFrame
    
    local seedsCorner = Instance.new("UICorner")
    seedsCorner.CornerRadius = UDim.new(0, 8)
    seedsCorner.Parent = seedsTab
    
    -- VIP tab
    local vipTab = Instance.new("TextButton")
    vipTab.Name = "VIPTab"
    vipTab.Size = UDim2.new(0.45, -5, 0.8, 0)
    vipTab.Position = UDim2.new(0.5, 5, 0.1, 0)
    vipTab.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    vipTab.BorderSizePixel = 0
    vipTab.Text = "👑 VIP"
    vipTab.TextColor3 = Color3.fromRGB(255, 255, 255)
    vipTab.TextScaled = true
    vipTab.Font = Enum.Font.Gotham
    vipTab.Parent = tabFrame
    
    local vipCorner = Instance.new("UICorner")
    vipCorner.CornerRadius = UDim.new(0, 8)
    vipCorner.Parent = vipTab
    
    -- Tab switching logic
    seedsTab.MouseButton1Click:Connect(function()
        self:SwitchToTab("seeds")
    end)
    
    vipTab.MouseButton1Click:Connect(function()
        self:SwitchToTab("vip")
    end)
    
    -- Store tab references
    self.SeedsTab = seedsTab
    self.VIPTab = vipTab
end

function ShopUIHandler:CreateSeedShopContent(parent)
    local contentFrame = Instance.new("Frame")
    contentFrame.Name = "SeedContent"
    contentFrame.Size = UDim2.new(1, 0, 1, -110)
    contentFrame.Position = UDim2.new(0, 0, 0, 110)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = parent
    
    -- Create scrolling frame for seeds
    local scrollingFrame = Instance.new("ScrollingFrame")
    scrollingFrame.Name = "SeedScrolling"
    scrollingFrame.Size = UDim2.new(1, -20, 1, -10)
    scrollingFrame.Position = UDim2.new(0, 10, 0, 5)
    scrollingFrame.BackgroundTransparency = 1
    scrollingFrame.BorderSizePixel = 0
    scrollingFrame.ScrollBarThickness = 8
    scrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    scrollingFrame.Parent = contentFrame
    
    -- Grid layout for seeds
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0, 150, 0, 180)
    gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = scrollingFrame
    
    -- Update canvas size when layout changes
    gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, gridLayout.AbsoluteContentSize.Y + 20)
    end)
    
    return scrollingFrame
end

function ShopUIHandler:CreateVIPShopContent(parent)
    local contentFrame = Instance.new("Frame")
    contentFrame.Name = "VIPContent"
    contentFrame.Size = UDim2.new(1, 0, 1, -110)
    contentFrame.Position = UDim2.new(0, 0, 0, 110)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Visible = false
    contentFrame.Parent = parent
    
    -- VIP Purchase Frame
    local vipPurchaseFrame = Instance.new("Frame")
    vipPurchaseFrame.Name = "VIPPurchaseFrame"
    vipPurchaseFrame.Size = UDim2.new(0.8, 0, 0.6, 0)
    vipPurchaseFrame.Position = UDim2.new(0.1, 0, 0.2, 0)
    vipPurchaseFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    vipPurchaseFrame.BorderSizePixel = 0
    vipPurchaseFrame.Parent = contentFrame
    
    local vipCorner = Instance.new("UICorner")
    vipCorner.CornerRadius = UDim.new(0, 12)
    vipCorner.Parent = vipPurchaseFrame
    
    -- VIP Title
    local vipTitle = Instance.new("TextLabel")
    vipTitle.Name = "VIPTitle"
    vipTitle.Size = UDim2.new(1, 0, 0, 50)
    vipTitle.Position = UDim2.new(0, 0, 0, 10)
    vipTitle.BackgroundTransparency = 1
    vipTitle.Text = "👑 VIP Garden Pass"
    vipTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
    vipTitle.TextScaled = true
    vipTitle.Font = Enum.Font.GothamBold
    vipTitle.Parent = vipPurchaseFrame
    
    -- VIP Benefits
    local benefitsFrame = Instance.new("Frame")
    benefitsFrame.Name = "Benefits"
    benefitsFrame.Size = UDim2.new(1, -20, 0.6, 0)
    benefitsFrame.Position = UDim2.new(0, 10, 0, 60)
    benefitsFrame.BackgroundTransparency = 1
    benefitsFrame.Parent = vipPurchaseFrame
    
    local benefitsList = Instance.new("UIListLayout")
    benefitsList.SortOrder = Enum.SortOrder.LayoutOrder
    benefitsList.Padding = UDim.new(0, 5)
    benefitsList.Parent = benefitsFrame
    
    -- Create benefit items
    local benefits = {
        "✨ 2x Offline Progress",
        "🏃 20% Faster Plant Growth",
        "💰 2x Coin Earnings",
        "🌱 +1 Extra Plot",
        "🎁 3x Daily Bonus Rewards"
    }
    
    for i, benefit in ipairs(benefits) do
        local benefitLabel = Instance.new("TextLabel")
        benefitLabel.Name = "Benefit" .. i
        benefitLabel.Size = UDim2.new(1, 0, 0, 30)
        benefitLabel.BackgroundTransparency = 1
        benefitLabel.Text = benefit
        benefitLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        benefitLabel.TextScaled = true
        benefitLabel.Font = Enum.Font.Gotham
        benefitLabel.TextXAlignment = Enum.TextXAlignment.Left
        benefitLabel.LayoutOrder = i
        benefitLabel.Parent = benefitsFrame
    end
    
    -- VIP Purchase Button
    local purchaseButton = Instance.new("TextButton")
    purchaseButton.Name = "PurchaseButton"
    purchaseButton.Size = UDim2.new(0.8, 0, 0, 50)
    purchaseButton.Position = UDim2.new(0.1, 0, 1, -70)
    purchaseButton.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
    purchaseButton.BorderSizePixel = 0
    purchaseButton.Text = "💎 Purchase VIP (100 Robux)"
    purchaseButton.TextColor3 = Color3.fromRGB(0, 0, 0)
    purchaseButton.TextScaled = true
    purchaseButton.Font = Enum.Font.GothamBold
    purchaseButton.Parent = vipPurchaseFrame
    
    local purchaseCorner = Instance.new("UICorner")
    purchaseCorner.CornerRadius = UDim.new(0, 8)
    purchaseCorner.Parent = purchaseButton
    
    purchaseButton.MouseButton1Click:Connect(function()
        self:PurchaseVIP()
    end)
    
    return contentFrame
end

-- ==========================================
-- SEED SHOP POPULATION
-- ==========================================

function ShopUIHandler:UpdateSeedShop()
    -- Clear existing items
    for _, child in pairs(self.SeedScrollingFrame:GetChildren()) do
        if child:IsA("Frame") and child.Name:find("SeedItem") then
            child:Destroy()
        end
    end
    
    -- Create seed items for each plant type
    for plantName, plantConfig in pairs(ConfigModule.Plants) do
        self:CreateSeedItem(plantName, plantConfig)
    end
end

function ShopUIHandler:CreateSeedItem(plantName, plantConfig)
    local itemFrame = Instance.new("Frame")
    itemFrame.Name = "SeedItem_" .. plantName
    itemFrame.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    itemFrame.BorderSizePixel = 0
    itemFrame.Parent = self.SeedScrollingFrame
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = itemFrame
    
    -- Plant icon/preview
    local plantIcon = Instance.new("Frame")
    plantIcon.Name = "PlantIcon"
    plantIcon.Size = UDim2.new(1, -10, 0, 80)
    plantIcon.Position = UDim2.new(0, 5, 0, 5)
    plantIcon.BackgroundColor3 = plantConfig.color or Color3.fromRGB(100, 150, 100)
    plantIcon.BorderSizePixel = 0
    plantIcon.Parent = itemFrame
    
    local iconCorner = Instance.new("UICorner")
    iconCorner.CornerRadius = UDim.new(0, 6)
    iconCorner.Parent = plantIcon
    
    -- Plant emoji or icon
    local emojiLabel = Instance.new("TextLabel")
    emojiLabel.Size = UDim2.new(1, 0, 1, 0)
    emojiLabel.BackgroundTransparency = 1
    emojiLabel.Text = plantConfig.emoji or "🌱"
    emojiLabel.TextScaled = true
    emojiLabel.Font = Enum.Font.Gotham
    emojiLabel.Parent = plantIcon
    
    -- Plant name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "PlantName"
    nameLabel.Size = UDim2.new(1, -10, 0, 25)
    nameLabel.Position = UDim2.new(0, 5, 0, 90)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = plantName
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Parent = itemFrame
    
    -- Plant info
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "PlantInfo"
    infoLabel.Size = UDim2.new(1, -10, 0, 20)
    infoLabel.Position = UDim2.new(0, 5, 0, 115)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = string.format("Growth: %ds | XP: %d", plantConfig.growthTime, plantConfig.xpReward)
    infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    infoLabel.TextScaled = true
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.Parent = itemFrame
    
    -- Purchase button
    local purchaseButton = Instance.new("TextButton")
    purchaseButton.Name = "PurchaseButton"
    purchaseButton.Size = UDim2.new(1, -10, 0, 30)
    purchaseButton.Position = UDim2.new(0, 5, 1, -35)
    purchaseButton.BorderSizePixel = 0
    purchaseButton.TextScaled = true
    purchaseButton.Font = Enum.Font.GothamBold
    purchaseButton.Parent = itemFrame
    
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 6)
    buttonCorner.Parent = purchaseButton
    
    -- Check if plant is unlocked
    local isUnlocked = self:IsPlantUnlocked(plantName)
    local canAfford = self.PlayerCoins >= plantConfig.buyPrice
    
    if not isUnlocked then
        -- Plant locked
        purchaseButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        purchaseButton.Text = "🔒 Level " .. plantConfig.unlockLevel
        purchaseButton.TextColor3 = Color3.fromRGB(200, 200, 200)
        purchaseButton.Active = false
        
        -- Gray out the entire item
        itemFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        plantIcon.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    elseif not canAfford then
        -- Can't afford
        purchaseButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        purchaseButton.Text = "💰 " .. plantConfig.buyPrice .. " coins"
        purchaseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        purchaseButton.Active = false
    else
        -- Can purchase
        purchaseButton.BackgroundColor3 = Color3.fromRGB(80, 150, 80)
        purchaseButton.Text = "🌱 Buy " .. plantConfig.buyPrice .. " coins"
        purchaseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        purchaseButton.Active = true
        
        -- Add purchase functionality
        purchaseButton.MouseButton1Click:Connect(function()
            self:PurchaseSeed(plantName)
        end)
        
        -- Add hover effect
        purchaseButton.MouseEnter:Connect(function()
            TweenService:Create(purchaseButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(100, 170, 100)}):Play()
        end)
        
        purchaseButton.MouseLeave:Connect(function()
            TweenService:Create(purchaseButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(80, 150, 80)}):Play()
        end)
    end
end

-- ==========================================
-- SHOP FUNCTIONALITY
-- ==========================================

function ShopUIHandler:SwitchToTab(tabName)
    self.CurrentShopTab = tabName
    
    if tabName == "seeds" then
        self.SeedScrollingFrame.Parent.Visible = true
        self.VIPFrame.Visible = false
        
        -- Update tab appearance
        self.SeedsTab.BackgroundColor3 = Color3.fromRGB(80, 150, 80)
        self.VIPTab.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        
        -- Update seed shop
        self:UpdateSeedShop()
    elseif tabName == "vip" then
        self.SeedScrollingFrame.Parent.Visible = false
        self.VIPFrame.Visible = true
        
        -- Update tab appearance
        self.SeedsTab.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        self.VIPTab.BackgroundColor3 = Color3.fromRGB(150, 120, 80)
        
        -- Update VIP status
        self:UpdateVIPDisplay()
    end
end

function ShopUIHandler:OpenShop()
    if self.IsShopOpen then return end
    
    self.IsShopOpen = true
    self.ShopFrame.Visible = true
    
    -- Update data before showing
    self:UpdatePlayerData()
    self:UpdateSeedShop()
    
    -- Animate shop opening
    self.ShopFrame.Size = UDim2.new(0, 0, 0, 0)
    self.ShopFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    
    local openTween = TweenService:Create(self.ShopFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Size = UDim2.new(0.9, 0, 0.8, 0),
        Position = UDim2.new(0.05, 0, 0.1, 0)
    })
    openTween:Play()
    
    print("🛒 ShopUIHandler: Shop opened")
end

function ShopUIHandler:CloseShop()
    if not self.IsShopOpen then return end
    
    -- Animate shop closing
    local closeTween = TweenService:Create(self.ShopFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0)
    })
    
    closeTween:Play()
    closeTween.Completed:Connect(function()
        self.ShopFrame.Visible = false
        self.IsShopOpen = false
    end)
    
    print("🛒 ShopUIHandler: Shop closed")
end

function ShopUIHandler:PurchaseSeed(plantName)
    -- Send purchase request to server
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if remoteEvents then
        local purchaseSeedEvent = remoteEvents:FindFirstChild("PurchaseSeed")
        if purchaseSeedEvent then
            purchaseSeedEvent:FireServer(plantName, 1) -- Purchase 1 seed
            print("🌱 ShopUIHandler: Requesting purchase of", plantName)
        end
    end
end

function ShopUIHandler:PurchaseVIP()
    -- Attempt VIP purchase through MarketplaceService
    local vipGamePassId = ConfigModule.VIP.gamePassId
    
    if vipGamePassId then
        MarketplaceService:PromptGamePassPurchase(self.Player, vipGamePassId)
        print("👑 ShopUIHandler: Prompting VIP purchase")
    else
        warn("❌ ShopUIHandler: VIP GamePass ID not configured")
    end
end

-- ==========================================
-- EVENT CONNECTIONS
-- ==========================================

function ShopUIHandler:SetupEventConnections()
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then
        warn("❌ ShopUIHandler: RemoteEvents folder not found")
        return
    end
    
    -- Listen for player data updates
    local updatePlayerDataEvent = remoteEvents:FindFirstChild("UpdatePlayerData")
    if updatePlayerDataEvent then
        updatePlayerDataEvent.OnClientEvent:Connect(function(playerData)
            self:OnPlayerDataUpdated(playerData)
        end)
    end
    
    -- Listen for purchase confirmations
    local purchaseConfirmEvent = remoteEvents:FindFirstChild("PurchaseConfirmed")
    if purchaseConfirmEvent then
        purchaseConfirmEvent.OnClientEvent:Connect(function(itemType, itemName, success, message)
            self:OnPurchaseConfirmed(itemType, itemName, success, message)
        end)
    end
    
    -- Listen for notifications
    local showNotificationEvent = remoteEvents:FindFirstChild("ShowNotification")
    if showNotificationEvent then
        showNotificationEvent.OnClientEvent:Connect(function(message, messageType)
            self:ShowNotification(message, messageType)
        end)
    end
end

function ShopUIHandler:SetupNPCInteraction()
    -- Set up NPC click detection
    local function onNPCClicked(npc)
        if npc.Name == "ShopNPC" or (npc:FindFirstChild("ClickDetector") and npc:GetAttribute("IsShopNPC")) then
            self:OpenShop()
        end
    end
    
    -- Listen for NPC clicks in workspace
    workspace.ChildAdded:Connect(function(child)
        if child:IsA("Model") and (child.Name == "ShopNPC" or child:GetAttribute("IsShopNPC")) then
            local clickDetector = child:FindFirstChild("ClickDetector")
            if clickDetector then
                clickDetector.MouseClick:Connect(function()
                    onNPCClicked(child)
                end)
            end
        end
    end)
    
    -- Also check existing NPCs
    for _, child in pairs(workspace:GetChildren()) do
        if child:IsA("Model") and (child.Name == "ShopNPC" or child:GetAttribute("IsShopNPC")) then
            local clickDetector = child:FindFirstChild("ClickDetector")
            if clickDetector then
                clickDetector.MouseClick:Connect(function()
                    onNPCClicked(child)
                end)
            end
        end
    end
end

-- ==========================================
-- DATA MANAGEMENT
-- ==========================================

function ShopUIHandler:UpdatePlayerData()
    -- Request current player data from server
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if remoteEvents then
        local getPlayerDataFunction = remoteEvents:FindFirstChild("GetPlayerData")
        if getPlayerDataFunction then
            local playerData = getPlayerDataFunction:InvokeServer()
            if playerData then
                self:OnPlayerDataUpdated(playerData)
            end
        end
    end
end

function ShopUIHandler:OnPlayerDataUpdated(playerData)
    self.PlayerCoins = playerData.coins or 0
    self.PlayerLevel = playerData.level or 1
    self.UnlockedPlants = playerData.unlockedPlants or {}
    self.IsVIP = playerData.isVIP or false
    
    -- Update UI elements
    self:UpdateCoinsDisplay()
    
    if self.IsShopOpen then
        if self.CurrentShopTab == "seeds" then
            self:UpdateSeedShop()
        elseif self.CurrentShopTab == "vip" then
            self:UpdateVIPDisplay()
        end
    end
end

function ShopUIHandler:UpdateCoinsDisplay()
    local coinsLabel = self.ShopFrame:FindFirstChild("Header"):FindFirstChild("CoinsFrame"):FindFirstChild("CoinsLabel")
    if coinsLabel then
        coinsLabel.Text = "💰 " .. self.PlayerCoins
    end
end

function ShopUIHandler:UpdateVIPDisplay()
    local vipPurchaseFrame = self.VIPFrame:FindFirstChild("VIPPurchaseFrame")
    if not vipPurchaseFrame then return end
    
    local purchaseButton = vipPurchaseFrame:FindFirstChild("PurchaseButton")
    
    if self.IsVIP then
        -- Player already has VIP
        purchaseButton.Text = "✅ VIP Active"
        purchaseButton.BackgroundColor3 = Color3.fromRGB(80, 150, 80)
        purchaseButton.Active = false
    else
        -- Player doesn't have VIP
        purchaseButton.Text = "💎 Purchase VIP (100 Robux)"
        purchaseButton.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
        purchaseButton.Active = true
    end
end

function ShopUIHandler:IsPlantUnlocked(plantName)
    local plantConfig = ConfigModule.Plants[plantName]
    if not plantConfig then return false end
    
    local requiredLevel = plantConfig.unlockLevel or 1
    return self.PlayerLevel >= requiredLevel
end

-- ==========================================
-- NOTIFICATIONS
-- ==========================================

function ShopUIHandler:OnPurchaseConfirmed(itemType, itemName, success, message)
    if success then
        self:ShowNotification("✅ " .. message, "success")
        -- Update player data after successful purchase
        self:UpdatePlayerData()
    else
        self:ShowNotification("❌ " .. message, "error")
    end
end

function ShopUIHandler:ShowNotification(message, messageType)
    -- Create floating notification
    local notification = Instance.new("Frame")
    notification.Name = "Notification"
    notification.Size = UDim2.new(0, 300, 0, 60)
    notification.Position = UDim2.new(0.5, -150, 0, -70)
    notification.BorderSizePixel = 0
    notification.Parent = self.PlayerGui
    
    -- Notification color based on type
    local bgColor = Color3.fromRGB(60, 60, 60)
    if messageType == "success" then
        bgColor = Color3.fromRGB(80, 150, 80)
    elseif messageType == "error" then
        bgColor = Color3.fromRGB(150, 80, 80)
    elseif messageType == "warning" then
        bgColor = Color3.fromRGB(150, 150, 80)
    end
    
    notification.BackgroundColor3 = bgColor
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = notification
    
    local messageLabel = Instance.new("TextLabel")
    messageLabel.Size = UDim2.new(1, -10, 1, 0)
    messageLabel.Position = UDim2.new(0, 5, 0, 0)
    messageLabel.BackgroundTransparency = 1
    messageLabel.Text = message
    messageLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    messageLabel.TextScaled = true
    messageLabel.Font = Enum.Font.Gotham
    messageLabel.Parent = notification
    
    -- Animate notification
    local showTween = TweenService:Create(notification, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Position = UDim2.new(0.5, -150, 0, 20)
    })
    showTween:Play()
    
    -- Auto-hide after 3 seconds
    wait(3)
    local hideTween = TweenService:Create(notification, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
        Position = UDim2.new(0.5, -150, 0, -70),
        BackgroundTransparency = 1
    })
    hideTween:Play()
    
    hideTween.Completed:Connect(function()
        notification:Destroy()
    end)
end

-- ==========================================
-- UTILITY FUNCTIONS
-- ==========================================

function ShopUIHandler:IsShopOpen()
    return self.IsShopOpen
end

function ShopUIHandler:GetCurrentTab()
    return self.CurrentShopTab
end

function ShopUIHandler:RefreshShop()
    self:UpdatePlayerData()
    
    if self.IsShopOpen then
        if self.CurrentShopTab == "seeds" then
            self:UpdateSeedShop()
        elseif self.CurrentShopTab == "vip" then
            self:UpdateVIPDisplay()
        end
    end
end

return ShopUIHandler
