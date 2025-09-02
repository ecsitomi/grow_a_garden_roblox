# Grow the Garden - Roblox Játék Fejlesztési Terv

## 🎮 Játék Koncepció

**Típus:** Idle Garden Management Játék
- **Platform:** Roblox Mobile-First (max 8 játékos/server)
- **Nézet:** 3D környezet (touch-optimalizált)
- **Mechanika:** Idle növekedés + aktív management
- **Főbb elemek:** Gazdasági rendszer + Progression rendszer

### **📱 Mobil Optimalizációs Szempontok**
- **Performance:** 60 FPS target mobil eszközökön
- **Touch Zones:** Minimum 44x44 pixel tap területek  
- **Screen Density:** UDim2 Scale használata Offset helyett
- **Memory Management:** Texture streaming, part culling
- **Network:** Minimális data usage, batch operations
- **Battery:** Efficient rendering, idle power management
- **Accessibility:** Haptic feedback, audio cues

### **🎮 Mobil-Specifikus Interakciók**
- **Tap to Plant:** Single tap ültetés
- **Hold to Harvest:** Long press aratáshoz  
- **Swipe Navigation:** UI panel váltás
- **Pinch Zoom:** Kamera közelítés/távolítás
- **Double Tap:** Gyors akciók (instant sell, etc.)
- **Hide UI Button:** Clean view toggle (landscape módhoz)

---

## 📱 UI Architektúra Specifikáció (Mobile-First)

### **🎨 UI Design Principles**
- **Touch-First Design**: Minimum 44x44 pixel touch targets
- **Responsive Scaling**: UDim2.new(Scale, Offset) - Scale prioritás
- **Context-Sensitive**: UI elemek automatikus hide/show logika
- **Performance Optimized**: Minimum GUI elemek, efficient animations
- **Accessibility**: High contrast, clear typography, haptic feedback

### **📐 Screen Layout Architecture**

#### **Core ScreenGui Hierarchy:**
```lua
-- PlayerGui structure minden UI handler-hez
PlayerGui/
├── MainScreenGui (ResetOnSpawn = false, ZIndexBehavior = Sibling)
│   ├── HUD (DisplayOrder = 1) -- Always visible elements
│   ├── GameUI (DisplayOrder = 2) -- Context-sensitive panels  
│   ├── ShopUI (DisplayOrder = 3) -- Modal interfaces
│   └── NotificationUI (DisplayOrder = 10) -- Highest priority
```

### **🎯 HUD (Always Visible) - UIManager.lua**
```lua
-- HUD Layout (top-left + top-right anchor)
HUD/
├── TopLeftFrame (AnchorPoint = 0,0 | Position = UDim2.new(0, 10, 0, 10))
│   ├── CoinsDisplay 
│   │   ├── CoinIcon (Size = UDim2.new(0, 32, 0, 32))
│   │   └── CoinLabel (TextScaled = true, Font = Gotham)
│   └── LevelDisplay
│       ├── LevelIcon (Size = UDim2.new(0, 32, 0, 32))  
│       └── LevelLabel (TextScaled = true)
│
├── TopRightFrame (AnchorPoint = 1,0 | Position = UDim2.new(1, -10, 0, 10))
│   ├── HideUIButton (Size = UDim2.new(0, 44, 0, 44)) -- Toggle clean view
│   └── SettingsButton (Size = UDim2.new(0, 44, 0, 44))
│
└── BottomCenterFrame (AnchorPoint = 0.5,1 | Position = UDim2.new(0.5, 0, 1, -10))
    └── XPProgressBar (Size = UDim2.new(0, 200, 0, 8)) -- Thin progress bar
```

### **🌱 Plot Interaction UI - PlotClickHandler.lua**
```lua
-- Dynamic plot info panel (appears on plot tap)
GameUI/PlotInfoPanel/
├── PlotInfoFrame (Size = UDim2.new(0, 280, 0, 160)) -- Mobile-optimized size
│   ├── BackgroundFrame (BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.3)
│   ├── PlotStatusLabel ("Plot #1 - Ready to Plant")
│   ├── PlantPreview (ViewportFrame showing current plant/empty plot)
│   ├── ActionButtonsFrame
│   │   ├── PlantButton (Size = UDim2.new(0.45, 0, 0, 50)) -- Large touch target
│   │   └── HarvestButton (Size = UDim2.new(0.45, 0, 0, 50)) -- Conditional visibility
│   └── CloseButton (Size = UDim2.new(0, 32, 0, 32), Position = top-right corner)

-- Positioning logic (follow player touch point)
PlotInfoPanel.Position = UDim2.new(0, touchPosition.X + 20, 0, touchPosition.Y - 80)
```

### **🏪 Shop Interface - ShopUIHandler.lua**
```lua
-- Full-screen modal shop interface
ShopUI/ShopFrame/
├── ShopFrame (Size = UDim2.new(0.9, 0, 0.8, 0), AnchorPoint = 0.5,0.5)
│   ├── BackgroundFrame (BackgroundColor3 = Color3.fromRGB(240, 240, 240))
│   ├── HeaderFrame (Size = UDim2.new(1, 0, 0, 60))
│   │   ├── ShopTitle ("Garden Shop", TextSize = 24)
│   │   └── CloseButton (Size = UDim2.new(0, 50, 0, 50), Position = top-right)
│   ├── TabsFrame (Size = UDim2.new(1, 0, 0, 50)) 
│   │   ├── SeedsTab (Size = UDim2.new(0.33, 0, 1, 0))
│   │   ├── ToolsTab (Size = UDim2.new(0.33, 0, 1, 0))  
│   │   └── DecorTab (Size = UDim2.new(0.34, 0, 1, 0))
│   ├── ItemsScrollFrame (Size = UDim2.new(1, -20, 1, -120)) -- Scrollable content
│   │   └── ItemsListLayout (UIListLayout, Padding = UDim2.new(0, 5, 0, 0))
│   │       └── ItemTemplate (Size = UDim2.new(1, 0, 0, 80)) -- Each shop item
│   │           ├── ItemIcon (Size = UDim2.new(0, 60, 0, 60))
│   │           ├── ItemInfo 
│   │           │   ├── ItemName (TextSize = 18, Font = GothamSemibold)
│   │           │   ├── ItemDescription (TextSize = 14)  
│   │           │   └── ItemPrice (TextSize = 16, Color = gold)
│   │           └── BuyButton (Size = UDim2.new(0, 80, 0, 40))
│   └── PlayerCoinsDisplay (Bottom of frame, always visible during shopping)
```

### **📊 Progression UI - ProgressionUIHandler.lua**
```lua
-- Level up notifications + stats overlay
GameUI/ProgressionPanel/
├── LevelUpNotification (Tweened animation from off-screen)
│   ├── LevelUpFrame (Size = UDim2.new(0, 300, 0, 100))
│   ├── LevelUpText ("LEVEL UP!", TextSize = 24, Color = gold)
│   ├── NewLevelText ("Level 5", TextSize = 20)
│   └── UnlockedItemsText ("New plants unlocked!", TextSize = 16)
│
└── StatsOverlay (Toggle via settings)
    ├── StatsFrame (Size = UDim2.new(0, 200, 0, 150))
    ├── TotalCoinsEarned
    ├── PlantsHarvested  
    ├── GardenLevel
    └── TimePlayedToday
```

### **🎯 Quest System UI - QuestUIHandler.lua**
```lua
-- Quest panel (slide in from right edge)
GameUI/QuestPanel/
├── QuestFrame (Size = UDim2.new(0, 280, 0.7, 0)) -- Tall panel for quest list
│   ├── QuestHeader 
│   │   ├── QuestTitle ("Daily Quests")
│   │   └── QuestTimer ("Resets in 14:32:05")
│   ├── QuestScrollFrame
│   │   └── QuestTemplate (Size = UDim2.new(1, 0, 0, 60))
│   │       ├── QuestIcon (32x32 quest type indicator)
│   │       ├── QuestText ("Harvest 5 Tomatoes") 
│   │       ├── QuestProgress ("3/5", ProgressBar visual)
│   │       └── QuestReward ("+50 XP, +100 Coins")
│   └── ClaimAllButton (Size = UDim2.new(1, -20, 0, 50))
│
└── QuestToggleButton (Fixed position, always accessible)
    ├── Size = UDim2.new(0, 50, 0, 50)
    ├── Position = UDim2.new(1, -60, 0.5, -25) -- Right edge
    └── QuestIcon + notification badge
```

### **💰 Daily Bonus UI - DailyBonusUIHandler.lua**
```lua
-- Daily login popup (full-screen modal)
GameUI/DailyBonusModal/
├── ModalBackground (Full screen, semi-transparent black)
├── BonusFrame (Size = UDim2.new(0, 350, 0, 400), AnchorPoint = 0.5,0.5)
│   ├── HeaderText ("Daily Bonus!", TextSize = 28)
│   ├── StreakInfo ("Login Streak: 3 days")
│   ├── RewardDisplay
│   │   ├── CoinsReward 
│   │   │   ├── CoinIcon (64x64)
│   │   │   └── CoinAmount ("+200 Coins" for VIP, "+50" for free)
│   │   ├── SeedsReward
│   │   │   ├── SeedIcon (64x64)  
│   │   │   └── SeedAmount ("+3 Seeds" for VIP, "+1" for free)
│   │   └── XPReward (VIP only)
│   │       ├── XPIcon (64x64)
│   │       └── XPAmount ("+50 XP")
│   ├── VIPBadge (Visible only for VIP players)
│   ├── ClaimButton (Size = UDim2.new(0.8, 0, 0, 60)) -- Large, prominent
│   └── StreakCalendar (7-day visual streak indicator)
```

### **🔧 Settings & UI Controls - HideUIHandler.lua + MobileUIController.lua**
```lua
-- Hide UI system (clean screenshot mode)
HideUIStates = {
    Full = {visible = {"HUD", "GameUI", "ShopUI"}}, -- Normal gameplay
    Minimal = {visible = {"CoinsDisplay", "XPBar"}}, -- Reduced UI
    Hidden = {visible = {}}, -- Clean view (screenshot mode)
    Menu = {visible = {"SettingsPanel"}} -- Settings only
}

-- Mobile UI density adaptation
ScreenSizes = {
    Phone = {maxX = 800, UIScale = 0.85, ButtonPadding = 2},
    Tablet = {maxX = 1200, UIScale = 1.0, ButtonPadding = 5},  
    Desktop = {maxX = 9999, UIScale = 1.15, ButtonPadding = 8}
}

-- Settings Panel
GameUI/SettingsPanel/
├── SettingsFrame (Size = UDim2.new(0, 300, 0, 400))
│   ├── SettingsHeader ("Settings")
│   ├── UIScaleSlider ("UI Size", 0.7 to 1.3 range)
│   ├── SoundToggle ("Sound Effects")  
│   ├── HideUIToggle ("Hide UI Mode")
│   ├── AutoSellToggle ("Auto-Sell Plants" - VIP only)
│   └── ResetDataButton ("Reset Progress" - confirmation required)
```

### **🎨 Visual Design Standards**

#### **Color Palette:**
```lua
ColorScheme = {
    Primary = Color3.fromRGB(34, 139, 34),      -- Forest Green
    Secondary = Color3.fromRGB(255, 206, 84),    -- Gold (VIP/coins)
    Background = Color3.fromRGB(240, 248, 255),  -- Light background  
    Text = Color3.fromRGB(25, 25, 25),          -- Dark text
    TextSecondary = Color3.fromRGB(100, 100, 100), -- Light text
    Success = Color3.fromRGB(46, 204, 113),      -- Green success
    Warning = Color3.fromRGB(241, 196, 15),      -- Yellow warning
    Error = Color3.fromRGB(231, 76, 60),         -- Red error
    VIP = Color3.fromRGB(255, 215, 0)            -- Gold VIP elements
}
```

#### **Typography:**
```lua
FontSettings = {
    Header = {Font = "GothamBold", TextSize = 24},
    Subheader = {Font = "GothamSemibold", TextSize = 18},
    Body = {Font = "Gotham", TextSize = 16}, 
    Caption = {Font = "Gotham", TextSize = 14},
    Button = {Font = "GothamSemibold", TextSize = 16}
}
```

#### **Animation Patterns:**
```lua
-- Standard UI animations for smooth mobile experience
Animations = {
    PanelSlideIn = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    PanelSlideOut = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
    ButtonPress = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
    NotificationPop = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
    ProgressBarFill = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
}
```

### **📱 Touch Interaction Guidelines**

#### **Touch Target Requirements:**
```lua
TouchTargets = {
    Minimum = Vector2.new(44, 44),      -- 44x44 pixels minimum (Apple HIG)
    Preferred = Vector2.new(50, 50),    -- 50x50 pixels preferred  
    Large = Vector2.new(60, 60),        -- 60x60 for important actions
    Spacing = 8                         -- 8 pixel minimum between targets
}
```

#### **Gesture Support:**
```lua
-- MobileUIController.lua gesture handling
Gestures = {
    Tap = "Primary interaction (plant, harvest, UI buttons)",
    LongPress = "Secondary actions (quick sell, plot info)",
    Swipe = "Panel navigation (shop tabs, quest scroll)",
    Pinch = "Camera zoom (3D world navigation)",  
    DoubleTap = "Quick actions (instant plant favorite seed)"
}
```

### **🔄 UI State Management**

#### **Context-Sensitive Display:**
```lua
-- UIManager.lua automatic UI context switching
UIContexts = {
    Spawn = {show = ["HUD"], hide = ["PlotInfo", "Shop"]},
    PlotInteraction = {show = ["HUD", "PlotInfo"], hide = ["Shop", "Quest"]},
    ShopNPC = {show = ["HUD", "Shop"], hide = ["PlotInfo", "Quest"]},
    MenuOpen = {show = ["Settings"], hide = ["HUD", "GameUI"]},
    Screenshot = {show = [], hide = ["all"]}  -- Hide UI mode
}
```

#### **Performance Optimization:**
```lua
-- UI performance guidelines for mobile
UIOptimization = {
    MaxSimultaneousAnimations = 3,      -- Limit concurrent tweens
    LazyLoadPanels = true,              -- Create panels only when needed
    RecycleListItems = true,            -- Reuse shop/quest item frames
    UpdateFrequency = 0.1,              -- Update UI elements max 10fps
    CullOffscreenUI = true              -- Hide UI outside viewport
}
```

---

## **🤖 AI-Specifikus Fejlesztési Előnyök**

### **Moduláris Biztonság AI számára:**
- **Egy modul/iteráció**: AI fókuszálhat egyetlen konkrét feladatra
- **Dependency validation**: Nem tudja rossz sorrendben implementálni
- **Clear success criteria**: Pontosan tudja mikor van kész egy modul
- **Interface-driven development**: Modulok között clean API-k

### **Folyamatos Validáció:**
- **Integration test every step**: Mindig működő játékállapot
- **Regression protection**: Korábbi modulok nem törhetnek el  
- **Error prevention**: Dependency hiány esetén automatikus hiba
- **Quality assurance**: Minden lépés validált és tesztelt

### **Tesztelhetőség példa:**
```lua
-- Iteration 13: PlantingHandler.lua
Test Flow: 
UI click → RemoteEvent → Server validation → Plant creation
Expected Result: New Part appears at correct plot with correct properties
Success Criteria: ✅ Plant spawns ✅ Growth starts ✅ Data persists
```

### **AI Fejlesztési Mérföldkövek:**
- **Iteration 5**: Alapvető növény rendszer (Part placeholders working)
- **Iteration 10**: Teljes gameplay loop (plant → grow → harvest functional)  
- **Iteration 15**: Gazdasági rendszer + Shop (buy/sell working)
- **Iteration 25**: Mobile UI foundation (touch controls working)
- **Iteration 35**: Teljes játék features (all systems integrated)
- **Iteration 40**: Production ready (optimized + polished)

### **Error Recovery Guidance AI számára:**
```lua
-- Ha egy iteráció sikertelen:
1. Check dependencies: Vannak-e az előfeltételek?
2. Review interface: Megfelelő API-t implementált?
3. Validate tests: Minden test criteria teljesül?
4. Integration check: Együttműködik a többi modullal?
5. Rollback if needed: Térjen vissza az utolsó working state-hez
```

---

## ⚙️ Kritikus Technikai Megoldások

### **🔄 Server Restart Recovery**
```lua
-- ServerRestartHandler.lua
function OnServerStart()
    -- DataStore-ból visszaolvasás minden player growing plants
    for userId, plotData in pairs(SavedPlots) do
        if plotData.growthStartTime then
            local elapsedTime = os.time() - plotData.growthStartTime
            local newStage = CalculateGrowthStage(elapsedTime, plotData.plantType)
            PlantManager:SetPlantStage(plotData.plotId, newStage)  -- Instant grow to correct stage
        end
    end
end

-- DataStore save format minden plot-hoz:
PlayerData.plots = {
    {plotId = 1, plantType = "Tomato", stage = 2, growthStartTime = 1693821234}
}
```

### **🏠 Automatic Plot Assignment + Positioning**
```lua
-- PlotManager.lua - SpawnLocation-relative positioning  
function PlotManager:InitializePlots()
    local spawnPos = workspace.SpawnLocation.Position
    
    -- Generate 8 plots in 4x2 grid around spawn
    local plotPositions = {
        spawnPos + Vector3.new(-75, 0, 0),   -- P1-P4 (északi sor)
        spawnPos + Vector3.new(-25, 0, 0), 
        spawnPos + Vector3.new(25, 0, 0),
        spawnPos + Vector3.new(75, 0, 0),
        spawnPos + Vector3.new(-75, 0, 50),  -- P5-P8 (déli sor)
        spawnPos + Vector3.new(-25, 0, 50),
        spawnPos + Vector3.new(25, 0, 50),
        spawnPos + Vector3.new(75, 0, 50)
    }
    
    for i, position in ipairs(plotPositions) do
        CreatePlotBoundary(i, position)  -- Invisible Part collision detection
    end
end

PlotAssignments = {
    [userId] = {assignedPlots = {1, 3, 5}, maxPlots = 5},      -- Free player
    [vipUserId] = {assignedPlots = {2, 4, 6, 7}, maxPlots = 6}  -- VIP player (+1 plot)
}

function AssignPlotsOnJoin(player)
    local savedPlots = DataManager:GetPlayerPlots(player.UserId)
    if not savedPlots then
        savedPlots = FindAvailablePlots(player)  -- First available plots
        DataManager:SavePlayerPlots(player.UserId, savedPlots)
    end
end
```

### **💤 Offline Progress Formula**
```lua
-- OfflineProgressCalculator.lua - Konkrét számítások
function CalculateOfflineProgress(player, lastPlayTime)
    local offlineMinutes = (os.time() - lastPlayTime) / 60
    local isVIP = VIPManager:IsPlayerVIP(player)
    local multiplier = isVIP and 2.0 or 1.0  -- VIP 2x offline speed
    
    for plotId, plotData in pairs(playerPlots) do
        if plotData.plantType then
            local growthTimeNeeded = ConfigModule.Plants[plotData.plantType].growthTime
            local progressGained = (offlineMinutes * multiplier) / growthTimeNeeded
            UpdatePlantStage(plotId, progressGained)  -- Auto-advance stages
        end
    end
    
    -- VIP Auto-Sell Offline Earnings
    if isVIP and player.Settings.AutoSellEnabled then
        local offlineEarnings = CalculateAutoSellEarnings(offlineMinutes)
        EconomyManager:AddCoins(player, offlineEarnings)
    end
end
```

### **🏆 Leaderboard Multi-Metric System**
```lua
-- LeaderboardManager.lua - Weekly rotating metrics
LeaderboardMetrics = {
    TotalEarnings = function(player) return player.Data.TotalCoinsEarned end,
    PlayerLevel = function(player) return player.Data.Level end,
    PlantsGrown = function(player) return player.Data.TotalPlantsHarvested end,
    GardenValue = function(player) return CalculateCurrentGardenWorth(player) end
}

CurrentWeekMetric = "TotalEarnings"  -- Changes every Monday for variety
```

### **📱 Mobile UI Density Management**
```lua
-- MobileUIController.lua - Context-sensitive UI switching
UIStates = {
    Minimal = {visible = {"CoinsDisplay", "LevelDisplay"}},                           -- Clean view
    Gaming = {visible = {"CoinsDisplay", "LevelDisplay", "PlotInfo", "QuickActions"}}, -- Active play
    Shop = {visible = {"CoinsDisplay", "ShopInterface"}},                             -- Shop context
    Full = {visible = "all"}                                                          -- Debug/settings
}

-- Auto screen density adaptation
function AdaptToScreenSize()
    local screenSize = player.PlayerGui.ScreenGui.AbsoluteSize
    if screenSize.X < 800 then  -- Small screen (phones)
        UIScale.Scale = 0.8
        ButtonPadding = UDim2.new(0, 2, 0, 2)  -- Tighter spacing
    end
end
```

### **🎯 60 FPS Performance Target**
```lua
-- PerformanceManager.lua - LOD (Level of Detail) system
function UpdatePlantLOD()
    local camera = workspace.CurrentCamera
    
    for plotId, plant in pairs(ActivePlants) do
        local distance = (camera.CFrame.Position - plant.Position).Magnitude
        
        if distance > 50 then
            plant.Transparency = 0.5  -- Fade distant plants
        elseif distance > 100 then
            plant.Parent = nil  -- Cull very distant plants
            CulledPlants[plotId] = plant  -- Store for restoration when closer
        end
    end
end

-- Batch operations instead of individual updates (mobile data saving)
GrowthUpdateQueue = {}  -- Batch plant updates every 5 seconds instead of continuous
```

### **🛡️ Error Handling System**
```lua
-- ErrorHandler.lua - Graceful fallbacks minden modulhoz
function ErrorHandler:SafeDataOperation(operation, fallbackData)
    local success, result = pcall(operation)
    if not success then
        warn("Data operation failed, using fallback:", result)
        return fallbackData
    end
    return result
end

-- Usage example minden modulban:
local playerData = ErrorHandler:SafeDataOperation(
    function() return DataStore:GetAsync(userId) end,
    DefaultPlayerData  -- Fallback if load fails
)
```

### **🌐 Network Optimization (Mobile Data Saving)**
```lua
-- NetworkOptimizer.lua - Batch RemoteEvent calls
local BatchedEvents = {}

function NetworkOptimizer:QueueEvent(eventName, data)
    BatchedEvents[eventName] = BatchedEvents[eventName] or {}
    table.insert(BatchedEvents[eventName], data)
end

-- Send batches every 2 seconds instead of individual calls
RunService.Heartbeat:Connect(function()
    if tick() % 2 == 0 then
        for eventName, batchData in pairs(BatchedEvents) do
            RemoteEvents[eventName]:FireAllClients(batchData)
            BatchedEvents[eventName] = {}
        end
    end
end)
```

---

## 🔷 Univerzális Placeholder Rendszer

### **🎨 Development-Friendly Megközelítés**
A játék **teljesen játékható** 3D modellek nélkül - minden elem Part placeholder-rel helyettesíthető.

**Part-Based Systems:**

**🌱 Plant Placeholders:**
```lua
-- PlantManager.lua automatikus Part generálás
PlantStages = {
    Tomato_Stage1 = { partType = "Cylinder", size = Vector3.new(0.5, 0.2, 0.5), 
                      color = Color3.fromRGB(139, 69, 19), material = Enum.Material.Sand }     -- Barna csíra
}
```

**🏪 Shop Building Placeholder:**
```lua
-- ShopManager.lua automatikus building generálás (spawn-relative)
function ShopManager:CreateShopBuilding()
    local spawnPos = workspace.SpawnLocation.Position
    local shopPos = spawnPos + Vector3.new(0, 0, -50)  -- 50 stud északra spawn-tól
    
    local shopBuilding = Instance.new("Part")
    shopBuilding.Name = "ShopBuilding"
    shopBuilding.Size = Vector3.new(15, 8, 10)
    shopBuilding.Position = shopPos + Vector3.new(0, 4, 0)  -- Ground level + height/2
    shopBuilding.Color = Color3.fromRGB(139, 115, 85)       -- Barna fa szín
    shopBuilding.Material = Enum.Material.Wood
    shopBuilding.Anchored = true
    shopBuilding.Parent = workspace
end
```

**👤 Shop NPC Placeholder (INTERACTION PONT):**
```lua
-- NPCManager.lua automatikus NPC generálás (shop előtt)
function NPCManager:CreateShopNPC()
    local spawnPos = workspace.SpawnLocation.Position
    local npcPos = spawnPos + Vector3.new(0, 0, -42)  -- Shop building előtt 8 stud
    
    local shopNPC = Instance.new("Part")
    shopNPC.Name = "ShopNPC"
    shopNPC.Shape = Enum.PartType.Cylinder
    shopNPC.Size = Vector3.new(2, 6, 2)                -- Ember magasság
    shopNPC.Position = npcPos + Vector3.new(0, 3, 0)   -- Ground + height/2
    shopNPC.Color = Color3.fromRGB(255, 206, 84)       -- Arany fényes keeper
    shopNPC.Material = Enum.Material.Neon               -- Interactable indicator
    shopNPC.Anchored = true
    shopNPC.Parent = workspace
    
    -- ProximityPrompt for interaction
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Open Shop"
    prompt.ObjectText = "Shop Keeper" 
    prompt.Parent = shopNPC
end
```

### **🔄 Universal Migration System**
```lua
-- ConfigModule.lua - Minden elemhez
USE_MODELS = {
    -- Plants
    Tomato = false,        -- Part placeholder
    Carrot = false,        -- Part placeholder  
    Lettuce = true,        -- Model ready (.rbxm használata)
    
    -- Shop Elements  
    ShopBuilding = false,  -- Part placeholder (barna fa kocka)
    ShopNPC = false        -- Part placeholder (arany cylinder)
}

-- Universal fallback logic minden elemhez
if ModelExists then UseModel() else UsePartPlaceholder()
```

### **✨ Visual Effects & Interactions**

**Shop NPC Interakciók:**
- **ProximityPrompt**: NPC Part-on (nem building-en!)
- **Visual Cue**: Neon material + floating BillboardGui "Shop Keeper"
- **Sell/Buy Logic**: Minden tranzakció az NPC-vel történik
- **Distance Validation**: Anti-cheat walking distance ellenőrzés

**Minden Placeholder Common Features:**
- **Smart Positioning**: Automatikus térkép elhelyezés
- **Click/Proximity Detection**: Interakció minden placeholderrel  
- **Visual Feedback**: Material és Color alapú state indication
- **Smooth Transitions**: Part → Model migration build közben

**🎯 Előnyök**

**Fejlesztési:**
- ⚡ **Azonnali start**: Teljes játék működik modellek nélkül
- 🔧 **Gyors iteráció**: Part tulajdonságok könnyen módosíthatók
- 🐛 **Debug friendly**: Part-ok egyszerűbbek mint modellek
- 📊 **Performance**: Part-ok kevesebb memória/polygon
- 🏗️ **No art blockage**: Programozás nem várhat 3D modellezésre

**Production:**
- 🔄 **Universal migration**: Bármely elem Part → Model átváltás
- 🛡️ **Fallback safety**: Model betöltési hiba esetén Part backup
- 📱 **Mobile optimization**: Part-ok könnyebb rendering minden eszközön
- 🎮 **Gameplay first**: Teljes mechanika működik visual-ok nélkül
- 💰 **Cost effective**: Nem kell minden elemhez professional 3D art

**Player Experience:**
- 🚀 **Fast loading**: Part-ok azonnal betöltődnek
- 🎨 **Clear feedback**: Színkódolás egyértelmű progression  
- 💡 **Intuitive**: Egyszerű formák, könnyen érthető states
- 🔍 **No confusion**: Minden interactable elem világos (Neon material)

---

## 👑 VIP Pass Rendszer & Monetization

### **💎 VIP Pass - 100 Robux GamePass**

**Technikai Setup:**
- **GamePass ID**: Roblox Studio → Game Settings → Monetization 
- **Detection**: `MarketplaceService:PlayerOwnsAsset(player, VIP_GAMEPASS_ID)`
- **Permanent Purchase**: Egyszeri vásárlás, örök érvényű

### **🎁 VIP Benefits**

**Daily Login Bonus:**
```
Free Player: 50 coins, 1 seed
VIP Player:  200 coins, 3 seeds, 50 XP
```

**Gameplay Boosts:**
- **Extra Plot**: +1 parcella (5 → 6 total)
- **Offline Progress**: 2x gyorsabb növekedés offline módban
- **Growth Speed**: 20% gyorsabb általános növekedés
- **Multi-Harvest**: 2 stud radius harvest egy kattintással  
- **Auto-Sell**: Toggle opció érett növények automatikus eladására

**Kozmetikai Előnyök:**
- **Arany nametag**: Név színe arany (Color3.fromRGB(255, 215, 0))
- **VIP Badge**: Korona ikon a név mellett
- **Golden Tools**: Arany öntözőkanna és kerti eszközök
- **Exclusive Decorations**: VIP-only díszítőelemek

### **⚖️ Balansz Filozófia: "Pay for Convenience"**

**Free Player Experience:**
- ✅ Teljes játék elérhető (minden növény, feature)
- ✅ Kompetitív lehetőségek (top leaderboard helyezés)
- ✅ Szórakoztató játékélmény (nem érzi hátrányát)

**VIP Value Proposition:**
- ⏰ Időmegtakarítás (gyorsabb progression)
- 🎯 Kényelem (auto-sell, multi-harvest)
- 👑 Státusz (vizuális megkülönböztetés)
- 💰 Gazdasági előny (magasabb daily income)

### **📊 Free vs VIP Comparison**

| Feature | Free Player | VIP Player |
|---------|-------------|------------|
| **Plots** | 5 parcella | 6 parcella |
| **Daily Bonus** | 50 coins, 1 seed | 200 coins, 3 seeds, 50 XP |
| **Offline Progress** | 1x speed | 2x speed |
| **Harvest** | 1 plot/click | Multi-harvest (2 stud radius) |
| **Growth Speed** | Normal | 20% gyorsabb |
| **Auto-Sell** | ❌ | ✅ (toggle) |
| **Name Color** | Fehér | Arany |
| **Exclusive Items** | ❌ | Golden tools, decorations |

### **🔧 VIP Implementation Modules**

**Új VIP-specifikus modulok:**
- **VIPManager.lua**: Core VIP logic és benefit management
- **DailyBonusManager.lua**: Login rewards Free vs VIP
- **VIPHandler.lua**: GamePass purchase event handling
- **DailyLoginHandler.lua**: Daily reset és reward logic
- **VIPUIHandler.lua**: VIP exclusive UI elements
- **DailyBonusUIHandler.lua**: Claim rewards interface

**Frissített modulok VIP integrációval:**
- **PlantManager.lua**: Growth speed multiplier VIP játékosoknak
- **EconomyManager.lua**: Auto-sell functionality
- **DataManager.lua**: VIP status tracking és persistence
- **ConfigModule.lua**: VIP konstansok és GamePass ID

---

## 🗺️ Térbeli Architektúra & Setup

### **🏪 Térbeli Shop Rendszer (Placeholder Support)**

**Shop Building + NPC Placeholder rendszer:**
```lua
-- ConfigModule.lua
USE_SHOP_MODELS = {
    ShopBuilding = false,  -- Part placeholder használata
    ShopNPC = false        -- Part placeholder használata
}

-- Shop Building placeholder
ShopBuildingConfig = {
    partType = "Block",
    size = Vector3.new(15, 8, 10),           -- Kis bolt méret
    color = Color3.fromRGB(139, 115, 85),    -- Barna fa szín
    material = Enum.Material.Wood,
    position = Vector3.new(0, 4, 0)          -- Térkép közép
}

-- Shop NPC placeholder (INTERACTION PONT!)
ShopNPCConfig = {
    partType = "Cylinder", 
    size = Vector3.new(2, 6, 2),             -- Ember magasság
    color = Color3.fromRGB(255, 206, 84),    -- Arany shop keeper
    material = Enum.Material.Neon,           -- Fényes = interactable
    position = "ShopBuilding.Position + Vector3.new(0, 0, 8)"  -- Épület előtt
}
```

**Interaction System:**
- **ProximityPrompt**: Shop NPC Part-on (nem a building-en!)
- **Sell/Buy Logic**: NPC-vel történik minden tranzakció
- **Visual Cue**: NPC Neon material + "Shop Keeper" BillboardGui text

**Térkép Layout (Automatic Positioning):**
```
Script automatikusan detektálja a SpawnLocation-t és ahhoz képest helyez el mindent:

     [Shop Building]
          🏪           ← spawn + Vector3.new(0, 0, -50)
    
🏠    🏠    🏠    🏠      ← spawn + Vector3.new(-50, 0, 0) to (+50, 0, 0)
P1    P2    P3    P4

🏠    🏠    🏠    🏠      ← spawn + Vector3.new(-50, 0, 50) to (+50, 0, 50)  
P5    P6    P7    P8

    [Default Spawn]
        👥             ← workspace.SpawnLocation.Position (0, 0, 0 relatív)
```

**Automatikus pozicionálás logic:**
```lua
-- Minden elem workspace.SpawnLocation.Position-höz képest
local spawnPos = workspace.SpawnLocation.Position

-- Shop Building: 50 stud északra (negative Z)
local shopPos = spawnPos + Vector3.new(0, 0, -50)

-- Shop NPC: Shop előtt 8 stud (negative Z)  
local npcPos = spawnPos + Vector3.new(0, 0, -42)

-- Plot grid: 4x2 layout spawn körül (25x25 stud/plot + 25 stud spacing)
local plotGrid = {
    spawnPos + Vector3.new(-75, 0, 0),   -- P1 (northwest)
    spawnPos + Vector3.new(-25, 0, 0),   -- P2 (north)
    spawnPos + Vector3.new(25, 0, 0),    -- P3 (north)  
    spawnPos + Vector3.new(75, 0, 0),    -- P4 (northeast)
    spawnPos + Vector3.new(-75, 0, 50),  -- P5 (southwest)
    spawnPos + Vector3.new(-25, 0, 50),  -- P6 (south)
    spawnPos + Vector3.new(25, 0, 50),   -- P7 (south)
    spawnPos + Vector3.new(75, 0, 50)    -- P8 (southeast)
}
```

**Térkép mérete:** ~150x100 studs (spawn-centered, automatic)

### **📋 Manual Setup Checklist (Fejlesztőnek)**

**Kötelező manuális munkák:**
1. **🗺️ Térkép alapok**: Ground terrain, boundaries, decorations

**Opcionális munkák (Part placeholder-ek használhatók):**
2. **🏪 Shop Building**: Épület model (.rbxm) - *Ha nincs → barna fa Part*
3. **👤 Shop NPC**: Karakter model (.rbxm) - *Ha nincs → arany Cylinder Part*
4. **🌱 3D Növény modellek**: Blender/Studio assets (.rbxm formátum)
   ```
   ServerStorage/PlantModels/
   ├── Tomato_Stage1.rbxm    -- Opcionális: Part helyett
   ├── Tomato_Stage2.rbxm    -- Opcionális: Part helyett  
   ├── Tomato_Stage3.rbxm    -- Opcionális: Part helyett
   └── ... (minden növénytípushoz 3 stage)
   ```
5. **🎨 Környezet**: Skybox, világítás beállítások

**Script automatikusan kezeli:**
- ✅ **SpawnLocation detection**: `workspace.SpawnLocation.Position` használata bázisként
- ✅ **Relatív pozicionálás**: Shop (-50Z), Plot grid (-75 to +75X, 0 to +50Z)  
- ✅ Plot grid generálás (8 plot 4x2 layout, 25x25 stud/plot + boundaries)
- ✅ Shop Building + NPC automatikus spawn-relative elhelyezés
- ✅ Player plot assignment (első szabad plot-ok alapértelmezetten)
- ✅ Shop interaction detection (ProximityPrompt + walking distance validation)
- ✅ Növény model spawning/management (3 stage system)
- ✅ Plot boundary collision detection

**Script automatikusan kezeli:**
- ✅ Plot grid generálás (8 player = 8 plot, 25x25 stud/plot)
- ✅ Player plot assignment (első szabad plot)
- ✅ Shop interaction detection (ProximityPrompt + walking distance validation)
- ✅ Növény model spawning/management (3 stage system)
- ✅ Plot boundary collision detection
- ✅ UI megjelenítés shop közelében

### **🌱 Növény Rendszerek**

**Placeholder Part Rendszer (Development):**
Amíg a 3D modellek nem készek el, színes Part-okkal helyettesítjük a növényeket:

```lua
-- Stage progression Part-okkal
PlantStages = {
    Tomato = {
        Stage1 = { partType = "Cylinder", size = Vector3.new(0.5, 0.2, 0.5), 
                   color = Color3.fromRGB(139, 69, 19), material = Enum.Material.Sand },    -- Barna csíra
        Stage2 = { partType = "Cylinder", size = Vector3.new(1, 1, 1), 
                   color = Color3.fromRGB(34, 139, 34), material = Enum.Material.Grass },   -- Zöld növény  
        Stage3 = { partType = "Sphere", size = Vector3.new(1.5, 1.8, 1.5), 
                   color = Color3.fromRGB(255, 99, 71), material = Enum.Material.Neon }    -- Piros paradicsom (ready)
    }
}
```

**Model Migration Strategy:**
```lua
-- Fokozatos átváltás Part → Model
USE_MODELS = {
    Tomato = false,    -- Part placeholder használata
    Carrot = false,    -- Part placeholder használata  
    Lettuce = true,    -- Model ready, használjuk a .rbxm-et
    Corn = true        -- Model ready, használjuk a .rbxm-et
}
```

**Vizuális Feedback:**
- **Stage Transition**: TweenService smooth méret/szín váltás
- **Ready to Harvest**: Neon material + floating animáció
- **Click Detection**: ClickDetector minden érett növényen
- **Fallback Safety**: Ha model betöltés fail → Part backup

---

## 🎮 Játékélmény Elemek

### **💡 Advanced Features**
- **Random Events:** Időjárás hatások (eső → gyorsabb növekedés, szárazság → lassabb)
- **NPC karakterek:** Kertész mentor (tippek, küldetések), Shop manager
- **Quest rendszer:** Napi/heti feladatok extra jutalommal
- **Pet rendszer:** Automatikus booster segítők (méhek, kutya)

### **🎨 UI/UX Elemek (Mobile-First)**  
- **Responsive HUD:** Pénz, XP, szint (adaptív screen méretekhez)
- **Touch-Friendly Controls:** Nagy tap területek, swipe gestures
- **Hide UI funkcionalitás:** Tiszta 3D nézet toggle
- **Progress Bar:** Vizuális feedback növény éréshez (mobil-optimalizált)
- **Compact Layout:** Minimális screen space használat
- **Auto-Hide panels:** Inaktivitás után UI elemek eltűnnek
- **Gesture Support:** Pinch-to-zoom, swipe navigation
- **Portrait + Landscape:** Mindkét orientáció támogatása

### **🔒 Biztonsági Megoldások**
- **Server-side validation:** Minden számítás szerveren történik
- **Anti-exploit:** RemoteEvent sebességlimitálás és input validáció  
- **Data integrity:** ProfileService használata stabilitásért
- **Client trust:** Soha ne a kliens számolja a pénzt/XP-t

---

## 📋 Fejlesztési Ütemterv

### **1. Fázis: Alap Infrastructure (1-2 hét)**
- 3D map design parcellákkal (Part-okból)
- Player data rendszer (GlobalDataStore)
- Folder struktúra kialakítása
- Alapvető script architektúra

### **2. Fázis: Core Gameplay (2-3 hét)**
- **Ültetési rendszer:** Click detection + RemoteEvent
- **Idle growth mechanika:** Timer-based növekedés
- **Gazdasági alapok:** Pénzkeresés, shop rendszer
- **Aratás:** Automatikus + manuális opciók

### **3. Fázis: Progression & Monetization (1-2 hét)**
- XP és szintlépés mechanika
- Növény unlock rendszer
- **VIP Pass implementáció (100 Robux GamePass)**
- Upgrade opciók (parcella bővítés, gyorsítás)
- Daily login bonus rendszer (Free vs VIP)

### **4. Fázis: Multiplayer & Advanced Features (2 hét)**
- Visit system (mások kertjének megtekintése)
- Leaderboard implementáció
- **Random Event rendszer** (eső, szárazság, időjárás effektek)
- **NPC karakterek** (kertész mentor, shop manager)
- **Quest rendszer** (napi/heti feladatok)

### **5. Fázis: Gameplay Enrichment (1-2 hét)**
- **Pet rendszer** (automatikus booster segítők)
- Advanced progression mechanics
- Ritkaság és balansz finomítás

### **6. Fázis: Polish & UX (1 hét)**
- **Progress bar** növényeknél (vizuális feedback)
- **Egyszerű HUD** (pénz, XP, szint always visible)
- **Feedback animációk** minden interakcióhoz
- Hangeffektek és polish
- Performance optimalizáció

---

## 🏗️ Moduláris Script Architektúra

### **ServerStorage/Modules/**
```
├── DataManager.lua          -- PlayerData (ProfileService ajánlott)
├── PlantManager.lua         -- Növény logika, growth timer
├── EconomyManager.lua       -- Pénzrendszer, shop, árak
├── ProgressionManager.lua   -- XP, szintek, unlock mechanika
├── EventManager.lua         -- Random eventek (eső, szárazság)
├── QuestManager.lua         -- Napi/heti feladatok
├── PetManager.lua           -- Pet rendszer és boosterek
├── NPCManager.lua           -- NPC interakciók és dialógusok
├── ShopManager.lua          -- Shop Building + NPC placeholder generálás
├── VIPManager.lua           -- VIP Pass core logic
├── DailyBonusManager.lua    -- Login rewards (Free vs VIP)
├── OfflineProgressCalculator.lua -- Offline growth formula & VIP multipliers
├── LeaderboardManager.lua   -- Multi-metric ranking system
├── PerformanceManager.lua   -- LOD system & mobile optimization
└── ConfigModule.lua         -- Universal configs (Plants, Shop, NPC, VIP)
```

### **ServerScriptService/**
```
├── MainGameHandler.lua      -- Modulok inicializálása
├── PlantingHandler.lua      -- Ültetés RemoteEvent handler
├── ShopHandler.lua          -- Vásárlás RemoteFunction handler
├── HarvestHandler.lua       -- Aratás logika
├── QuestHandler.lua         -- Quest teljesítés validation
├── EventHandler.lua         -- Random event trigger
├── SecurityHandler.lua      -- Anti-exploit protection
├── VIPHandler.lua           -- GamePass purchase events
├── DailyLoginHandler.lua    -- Daily reset logic
├── ServerRestartHandler.lua -- Growth state backup/restore + cleanup
├── NetworkOptimizer.lua     -- Batch RemoteEvent calls (mobile data saving)
└── PlayerJoinHandler.lua    -- Player join/leave events
```

### **ReplicatedStorage/**
```
├── Modules/
│   ├── PlantConfig.lua      -- Növény adatok (shared)
│   └── GameConstants.lua    -- Globális konstansok
└── RemoteEvents/
    ├── PlantSeed           -- Ültetés event
    ├── HarvestPlant        -- Aratás event
    └── PurchaseItem        -- Shop vásárlás
```

### **StarterPlayerScripts/**
```
├── UIManager.lua            -- Fő UI kontroller (Mobile-responsive)
├── PlotClickHandler.lua     -- Touch detection (tap-friendly)
├── ShopUIHandler.lua        -- Shop interface (mobile layout)
├── ProgressionUIHandler.lua -- XP/Level/Stats display
├── QuestUIHandler.lua       -- Quest progress display  
├── EventUIHandler.lua       -- Random event notifications
├── NPCInteractionHandler.lua-- NPC dialógus rendszer
├── FeedbackManager.lua      -- Progress bars, animációk
├── MobileUIController.lua   -- Responsive layout manager
├── HideUIHandler.lua        -- UI elrejtés/megjelenítés
├── VIPUIHandler.lua         -- VIP exclusive UI elements
├── DailyBonusUIHandler.lua  -- Claim rewards interface
└── SoundManager.lua         -- Audio effects manager
```

---

## 🔧 Technikai Stack

- **Server Logic:** ServerScript modulok + kritikus fallback rendszerek
- **Client UI:** LocalScript + ScreenGui (Mobile-First Design)
- **Kommunikáció:** RemoteEvents/RemoteFunctions (secured + batched)
- **Adattárolás:** GlobalDataStore (ProfileService ajánlott nagy adatmennyiségnél)
- **Performance:** LOD system, Part culling, 60 FPS target mobil eszközökön
- **Animációk:** TweenService
- **3D Elemek:** Part-based building system (touch-optimalizált)
- **UI Rendering:** UDim2 responsive scaling + density adaptation
- **Input:** Touch detection + UserInputService
- **Error Recovery:** Graceful fallbacks + server restart handling
- **Network:** Batch operations (mobile data optimization)
- **Biztonság:** Anti-exploit védelem (server-side validation)

---

## ✅ Fejlesztési Elvek

- **Moduláris kód:** Minden funkció külön script/modul (30 total modules)
- **Tiszta architektúra:** Egyértelmű függőségek + error handling
- **Mobile-First:** Touch-optimalizált UI és interakciók
- **Gameplay-First:** Mechanika működik visual-ok nélkül is (Part placeholder)
- **Smart Fallbacks:** Part → Model migration + automatic fallback safety
- **Pay-for-Convenience:** VIP ad előnyt, de free játék teljes értékű
- **Fair Monetization:** Minden tartalom elérhető ingyen, Robux időt spórol
- **Performance:** 60 FPS target + LOD system mobil eszközökhöz
- **Reliability:** Server restart recovery + graceful error handling
- **Network Efficiency:** Batch operations + mobile data optimization
- **Skálázhatóság:** Könnyű új funkciók hozzáadása
- **Debugging:** Strukturált error handling minden modulban

---

## 🎯 Következő Lépések

**Prioritás alapján (Universal Placeholder System):**
1. **ConfigModule.lua** - Universal placeholder configs (Plants + Shop + NPC)
2. **PlantManager.lua** - Part-based növény rendszer (CreatePlantPart function)
3. **ShopManager.lua** - Shop Building + NPC placeholder generálás
4. **VIPManager.lua** - Core VIP logic és GamePass detection
5. **DailyBonusManager.lua** - Login rewards rendszer
6. **MobileUIController.lua** - Responsive layout alapok (UDim2 Scale)
7. **HideUIHandler.lua** - UI toggle funkcionalitás
8. **SecurityHandler.lua** - Anti-exploit alapok (input validation)
9. **DataManager.lua** - Player data save/load (VIP status tracking)
10. **Touch-optimalizált PlotClickHandler.lua** - Tap detection és feedback

---

*Utolsó frissítés: 2025.09.02 - AI-optimalizált dependency-driven fejlesztési terv (40 iteráció, folyamatos integráció)*