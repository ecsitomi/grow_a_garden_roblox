--[[
    ConfigModule.lua
    Universal Configuration System
    
    Priority: 1 (Foundation module)
    Dependencies: None
    Used by: All modules
    
    Features:
    - Universal placeholder configs (Plants + Shop + NPC)
    - VIP system constants
    - Mobile UI settings
    - Plant progression data
    - Economic balance
--]]

local ConfigModule = {}

-- ==========================================
-- UNIVERSAL PLACEHOLDER SYSTEM
-- ==========================================

-- Model availability flags (Part placeholder fallback system)
ConfigModule.USE_MODELS = {
    -- Plants (true = use .rbxm model, false = use Part placeholder)
    Tomato = false,        -- Part placeholder
    Carrot = false,        -- Part placeholder  
    Lettuce = false,       -- Part placeholder
    Corn = false,          -- Part placeholder
    
    -- Shop Elements  
    ShopBuilding = false,  -- Part placeholder (barna fa kocka)
    ShopNPC = false        -- Part placeholder (arany cylinder)
}

-- ==========================================
-- VIP SYSTEM CONFIGURATION
-- ==========================================

ConfigModule.VIP = {
    GAMEPASS_ID = 0,  -- TODO: Set actual GamePass ID after creation in Roblox Studio
    PRICE_ROBUX = 100,
    
    -- Daily Login Bonuses
    DAILY_BONUS = {
        FREE = {coins = 50, seeds = 1, xp = 0},
        VIP = {coins = 200, seeds = 3, xp = 50}
    },
    
    -- Gameplay Multipliers
    GROWTH_SPEED_MULTIPLIER = 1.2,     -- 20% faster growth
    OFFLINE_PROGRESS_MULTIPLIER = 2.0,  -- 2x offline speed
    MULTI_HARVEST_RADIUS = 2,           -- 2 stud radius harvest
    EXTRA_PLOTS = 1,                    -- +1 plot (5 → 6 total)
    
    -- Visual Settings
    NAME_COLOR = Color3.fromRGB(255, 215, 0),  -- Gold nametag
    BADGE_ICON = "👑"  -- Crown emoji for VIP badge
}

-- ==========================================
-- PLANT SYSTEM CONFIGURATION
-- ==========================================

ConfigModule.Plants = {
    Tomato = {
        name = "Tomato",
        buyPrice = 10,
        sellPrice = 25,
        growthTime = 120,  -- 2 minutes in seconds
        xpReward = 15,
        unlockLevel = 1,
        
        -- Part Placeholder Configuration
        stages = {
            {
                partType = "Cylinder",
                size = Vector3.new(0.5, 0.2, 0.5),
                color = Color3.fromRGB(139, 69, 19),  -- Brown sprout
                material = Enum.Material.Sand
            },
            {
                partType = "Cylinder", 
                size = Vector3.new(1, 1, 1),
                color = Color3.fromRGB(34, 139, 34),   -- Green plant
                material = Enum.Material.Grass
            },
            {
                partType = "Sphere",
                size = Vector3.new(1.5, 1.8, 1.5),
                color = Color3.fromRGB(255, 99, 71),   -- Red tomato (ready)
                material = Enum.Material.Neon
            }
        }
    },
    
    Carrot = {
        name = "Carrot",
        buyPrice = 15,
        sellPrice = 35,
        growthTime = 180,  -- 3 minutes
        xpReward = 20,
        unlockLevel = 3,
        
        stages = {
            {
                partType = "Cylinder",
                size = Vector3.new(0.4, 0.1, 0.4),
                color = Color3.fromRGB(139, 69, 19),   -- Brown seed
                material = Enum.Material.Sand
            },
            {
                partType = "Block",
                size = Vector3.new(0.8, 1.2, 0.8),
                color = Color3.fromRGB(34, 139, 34),   -- Green leaves
                material = Enum.Material.Grass
            },
            {
                partType = "Wedge",
                size = Vector3.new(1, 2, 1),
                color = Color3.fromRGB(255, 140, 0),   -- Orange carrot (ready)
                material = Enum.Material.Neon
            }
        }
    },
    
    Lettuce = {
        name = "Lettuce",
        buyPrice = 20,
        sellPrice = 50,
        growthTime = 240,  -- 4 minutes
        xpReward = 25,
        unlockLevel = 5,
        
        stages = {
            {
                partType = "Sphere",
                size = Vector3.new(0.3, 0.1, 0.3),
                color = Color3.fromRGB(139, 69, 19),   -- Brown seed
                material = Enum.Material.Sand
            },
            {
                partType = "Sphere",
                size = Vector3.new(1, 0.8, 1),
                color = Color3.fromRGB(34, 139, 34),   -- Small lettuce
                material = Enum.Material.Grass
            },
            {
                partType = "Sphere",
                size = Vector3.new(2, 1.2, 2),
                color = Color3.fromRGB(144, 238, 144), -- Light green lettuce (ready)
                material = Enum.Material.Neon
            }
        }
    },
    
    Corn = {
        name = "Corn",
        buyPrice = 30,
        sellPrice = 75,
        growthTime = 300,  -- 5 minutes
        xpReward = 35,
        unlockLevel = 8,
        
        stages = {
            {
                partType = "Cylinder",
                size = Vector3.new(0.3, 0.2, 0.3),
                color = Color3.fromRGB(139, 69, 19),   -- Brown seed
                material = Enum.Material.Sand
            },
            {
                partType = "Cylinder",
                size = Vector3.new(0.6, 2, 0.6),
                color = Color3.fromRGB(34, 139, 34),   -- Green stalk
                material = Enum.Material.Grass
            },
            {
                partType = "Cylinder",
                size = Vector3.new(1, 3, 1),
                color = Color3.fromRGB(255, 255, 0),   -- Yellow corn (ready)
                material = Enum.Material.Neon
            }
        }
    }
}

-- ==========================================
-- SHOP SYSTEM CONFIGURATION
-- ==========================================

ConfigModule.Shop = {
    -- Shop Building Placeholder
    BUILDING = {
        partType = "Block",
        size = Vector3.new(15, 8, 10),          -- Small shop size
        color = Color3.fromRGB(139, 115, 85),   -- Brown wood color
        material = Enum.Material.Wood,
        offsetFromSpawn = Vector3.new(0, 0, -50) -- 50 studs north of spawn
    },
    
    -- Shop NPC Placeholder (INTERACTION POINT!)
    NPC = {
        partType = "Cylinder",
        size = Vector3.new(2, 6, 2),            -- Human height
        color = Color3.fromRGB(255, 206, 84),   -- Gold shop keeper
        material = Enum.Material.Neon,          -- Glowing = interactable
        offsetFromSpawn = Vector3.new(0, 0, -42), -- In front of shop building
        name = "Shop Keeper",
        promptText = "Open Shop"
    }
}

-- ==========================================
-- PLOT SYSTEM CONFIGURATION
-- ==========================================

ConfigModule.Plots = {
    TOTAL_PLOTS = 8,
    PLOT_SIZE = 25,      -- 25x25 studs per plot
    PLOT_SPACING = 25,   -- 25 stud spacing between plots
    ROWS = 2,            -- 4x2 grid layout
    COLS = 4,
    
    -- Plot positions relative to spawn (automatic generation)
    GRID_OFFSET = {
        START_X = -75,    -- Northwest corner
        START_Z = 0,      -- North row
        ROW_SPACING = 50  -- Distance between north and south rows
    },
    
    -- Player plot assignment
    DEFAULT_PLOTS_FREE = 5,     -- Free players get 5 plots
    DEFAULT_PLOTS_VIP = 6,      -- VIP players get 6 plots (+1 bonus)
    MAX_PLOTS = 8               -- Maximum possible plots
}

-- ==========================================
-- MOBILE UI CONFIGURATION
-- ==========================================

ConfigModule.UI = {
    -- Touch Target Requirements (Apple HIG compliance)
    TOUCH_TARGETS = {
        MINIMUM = Vector2.new(44, 44),      -- 44x44 pixels minimum
        PREFERRED = Vector2.new(50, 50),    -- 50x50 pixels preferred  
        LARGE = Vector2.new(60, 60),        -- 60x60 for important actions
        SPACING = 8                         -- 8 pixel minimum between targets
    },
    
    -- Screen Density Adaptation
    SCREEN_SIZES = {
        PHONE = {maxX = 800, uiScale = 0.85, buttonPadding = 2},
        TABLET = {maxX = 1200, uiScale = 1.0, buttonPadding = 5},  
        DESKTOP = {maxX = 9999, uiScale = 1.15, buttonPadding = 8}
    },
    
    -- Color Palette
    COLORS = {
        PRIMARY = Color3.fromRGB(34, 139, 34),      -- Forest Green
        SECONDARY = Color3.fromRGB(255, 206, 84),    -- Gold (VIP/coins)
        BACKGROUND = Color3.fromRGB(240, 248, 255),  -- Light background  
        TEXT = Color3.fromRGB(25, 25, 25),          -- Dark text
        TEXT_SECONDARY = Color3.fromRGB(100, 100, 100), -- Light text
        SUCCESS = Color3.fromRGB(46, 204, 113),      -- Green success
        WARNING = Color3.fromRGB(241, 196, 15),      -- Yellow warning
        ERROR = Color3.fromRGB(231, 76, 60),         -- Red error
        VIP = Color3.fromRGB(255, 215, 0)            -- Gold VIP elements
    },
    
    -- Animation Settings
    ANIMATIONS = {
        PANEL_SLIDE_IN = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        PANEL_SLIDE_OUT = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        BUTTON_PRESS = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
        NOTIFICATION_POP = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        PROGRESS_BAR_FILL = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
    }
}

-- ==========================================
-- PROGRESSION SYSTEM CONFIGURATION
-- ==========================================

ConfigModule.Progression = {
    -- XP Requirements per level
    XP_PER_LEVEL = {
        [1] = 0,      -- Starting level
        [2] = 100,
        [3] = 250,
        [4] = 500,
        [5] = 1000,
        [6] = 1750,
        [7] = 2750,
        [8] = 4000,
        [9] = 5500,
        [10] = 7500
        -- Can be extended infinitely: level * 1000 XP after level 10
    },
    
    -- Level unlock rewards
    LEVEL_UNLOCKS = {
        [1] = {"Tomato"},
        [3] = {"Carrot"},
        [5] = {"Lettuce", "ExtraPlot"},
        [8] = {"Corn"},
        [10] = {"VIPDiscount"}  -- 50% off VIP pass
    }
}

-- ==========================================
-- ECONOMY CONFIGURATION
-- ==========================================

ConfigModule.Economy = {
    -- Starting values
    STARTING_COINS = 100,
    STARTING_XP = 0,
    STARTING_LEVEL = 1,
    
    -- Anti-cheat limits
    MAX_COINS_PER_HOUR = 10000,      -- Prevent exploitation
    MAX_XP_PER_HOUR = 2000,
    
    -- Auto-sell settings (VIP only)
    AUTO_SELL_DELAY = 5,             -- 5 seconds after harvest ready
    AUTO_SELL_NOTIFICATION_TIME = 3   -- 3 second notification
}

-- ==========================================
-- QUEST SYSTEM CONFIGURATION
-- ==========================================

ConfigModule.Quests = {
    DAILY_QUESTS = {
        {
            id = "harvest_plants",
            name = "Daily Harvest",
            description = "Harvest 5 plants",
            target = 5,
            rewards = {coins = 100, xp = 50}
        },
        {
            id = "plant_seeds",
            name = "Plant Seeds", 
            description = "Plant 3 seeds",
            target = 3,
            rewards = {coins = 75, xp = 30}
        },
        {
            id = "earn_coins",
            name = "Earn Coins",
            description = "Earn 200 coins",
            target = 200,
            rewards = {coins = 50, xp = 25}
        }
    },
    
    RESET_TIME = 24 * 60 * 60,  -- 24 hours in seconds
    MAX_DAILY_QUESTS = 3
}

-- ==========================================
-- PERFORMANCE SETTINGS
-- ==========================================

ConfigModule.Performance = {
    -- Mobile optimization targets
    TARGET_FPS = 60,
    MAX_SIMULTANEOUS_ANIMATIONS = 3,
    UPDATE_FREQUENCY = 0.1,              -- Update UI max 10fps
    
    -- LOD (Level of Detail) system
    LOD_DISTANCES = {
        FADE_START = 50,   -- Start fading plants at 50 studs
        CULL_DISTANCE = 100 -- Remove plants beyond 100 studs
    },
    
    -- Batch operation settings (mobile data saving)
    BATCH_SIZE = 10,
    BATCH_FREQUENCY = 2,  -- Send batches every 2 seconds
    
    -- Memory management
    MAX_CACHED_PLANTS = 50,
    UI_ELEMENT_POOL_SIZE = 20
}

-- ==========================================
-- SECURITY CONFIGURATION
-- ==========================================

ConfigModule.Security = {
    -- RemoteEvent rate limiting
    MAX_REMOTE_CALLS_PER_SECOND = 5,
    COOLDOWN_DURATION = 1,
    
    -- Walking distance validation for anti-cheat
    MAX_INTERACTION_DISTANCE = 15,  -- 15 studs max from plot/NPC
    TELEPORT_DETECTION_THRESHOLD = 50, -- Flag if player moves >50 studs instantly
    
    -- Data validation
    MAX_PLANT_VALUE = 1000,      -- Maximum single plant sell value
    MAX_COINS_PER_TRANSACTION = 5000
}

-- ==========================================
-- UTILITY FUNCTIONS
-- ==========================================

function ConfigModule:GetPlantByLevel(level)
    local availablePlants = {}
    for plantName, plantData in pairs(self.Plants) do
        if plantData.unlockLevel <= level then
            table.insert(availablePlants, plantName)
        end
    end
    return availablePlants
end

function ConfigModule:GetXPRequiredForLevel(level)
    if level <= 10 then
        return self.Progression.XP_PER_LEVEL[level] or 0
    else
        -- Formula for levels beyond 10: level * 1000 XP
        return level * 1000
    end
end

function ConfigModule:IsVIPFeatureEnabled(featureName)
    local vipFeatures = {
        "AutoSell", "MultiHarvest", "OfflineBonus", 
        "ExtraPlot", "GoldenTools", "VIPBadge"
    }
    return table.find(vipFeatures, featureName) ~= nil
end

function ConfigModule:GetScreenSizeCategory(screenSize)
    if screenSize.X <= self.UI.SCREEN_SIZES.PHONE.maxX then
        return "PHONE"
    elseif screenSize.X <= self.UI.SCREEN_SIZES.TABLET.maxX then
        return "TABLET"
    else
        return "DESKTOP"
    end
end

-- Validate configuration on load
function ConfigModule:Validate()
    assert(self.VIP.GAMEPASS_ID >= 0, "VIP GamePass ID must be set (0 for testing)")
    assert(self.Plots.GRID_OFFSET and self.Plots.GRID_OFFSET.START_X, "Plot grid configuration required")
    assert(self.Plants.Tomato, "At least one plant (Tomato) must be configured")
    assert(self.Plots.TOTAL_PLOTS > 0, "Plot count must be greater than 0")
    assert(self.Plots.PLOT_SIZE > 0, "Plot size must be greater than 0")
    print("✅ ConfigModule: All configurations validated successfully")
end

return ConfigModule
