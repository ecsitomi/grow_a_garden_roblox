--[[
    VIPManager.lua
    VIP Pass Core Logic & GamePass Detection
    
    Priority: 3 (Core monetization module)
    Dependencies: ConfigModule
    Used by: All modules requiring VIP status checks
    
    Features:
    - GamePass purchase detection
    - VIP status persistence 
    - VIP benefit calculations
    - Golden visual effects
    - Daily bonus multipliers
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)

local VIPManager = {}
VIPManager.__index = VIPManager

-- ==========================================
-- VIP DATA STORAGE
-- ==========================================

VIPManager.VIPPlayers = {}        -- [userId] = true/false
VIPManager.VIPCache = {}          -- [userId] = {status, lastChecked}
VIPManager.GoldenEffects = {}     -- [userId] = {effects table}

-- ==========================================
-- INITIALIZATION
-- ==========================================

function VIPManager:Initialize()
    print("👑 VIPManager: Initializing VIP system...")
    
    -- Set up GamePass purchase detection
    self:SetupGamePassEvents()
    
    -- Set up player join/leave events
    self:SetupPlayerEvents()
    
    print("✅ VIPManager: VIP system initialized successfully")
    print("💰 VIPManager: VIP GamePass Price:", ConfigModule.VIP.PRICE_ROBUX, "Robux")
end

-- ==========================================
-- GAMEPASS DETECTION
-- ==========================================

function VIPManager:SetupGamePassEvents()
    -- Handle GamePass purchases
    MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
        if gamePassId == ConfigModule.VIP.GAMEPASS_ID and wasPurchased then
            self:OnVIPPurchased(player)
        end
    end)
    
    print("🛒 VIPManager: GamePass events configured (ID:", ConfigModule.VIP.GAMEPASS_ID, ")")
end

function VIPManager:SetupPlayerEvents()
    Players.PlayerAdded:Connect(function(player)
        self:OnPlayerJoined(player)
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        self:OnPlayerLeaving(player)
    end)
end

function VIPManager:OnPlayerJoined(player)
    -- Check VIP status when player joins
    spawn(function()
        local isVIP = self:CheckVIPStatus(player)
        self:SetVIPStatus(player, isVIP)
        
        if isVIP then
            self:ApplyVIPEffects(player)
            print("👑 VIPManager:", player.Name, "joined as VIP member")
        else
            print("🎮 VIPManager:", player.Name, "joined as free player")
        end
    end)
end

function VIPManager:OnPlayerLeaving(player)
    local userId = player.UserId
    
    -- Clear VIP data
    self.VIPPlayers[userId] = nil
    self.VIPCache[userId] = nil
    self:RemoveVIPEffects(player)
    
    print("👋 VIPManager:", player.Name, "left the game")
end

function VIPManager:OnVIPPurchased(player)
    print("🎉 VIPManager:", player.Name, "purchased VIP Pass!")
    
    -- Update VIP status immediately
    self:SetVIPStatus(player, true)
    
    -- Apply VIP effects
    self:ApplyVIPEffects(player)
    
    -- Show purchase confirmation (could trigger UI notification)
    self:ShowVIPWelcomeMessage(player)
end

-- ==========================================
-- VIP STATUS MANAGEMENT
-- ==========================================

function VIPManager:CheckVIPStatus(player)
    local userId = player.UserId
    
    -- Check cache first (avoid repeated MarketplaceService calls)
    local cached = self.VIPCache[userId]
    if cached and (tick() - cached.lastChecked) < 300 then -- 5 minute cache
        return cached.status
    end
    
    -- Check GamePass ownership
    local success, hasGamePass = pcall(function()
        return MarketplaceService:PlayerOwnsAsset(player, ConfigModule.VIP.GAMEPASS_ID)
    end)
    
    local isVIP = success and hasGamePass
    
    -- Cache result
    self.VIPCache[userId] = {
        status = isVIP,
        lastChecked = tick()
    }
    
    return isVIP
end

function VIPManager:SetVIPStatus(player, isVIP)
    local userId = player.UserId
    self.VIPPlayers[userId] = isVIP
    
    -- Update cache
    self.VIPCache[userId] = {
        status = isVIP,
        lastChecked = tick()
    }
    
    print("📝 VIPManager: Set VIP status for", player.Name, ":", isVIP)
end

function VIPManager:IsPlayerVIP(player)
    if type(player) == "number" then
        -- Handle userId input
        return self.VIPPlayers[player] or false
    elseif player and player.UserId then
        -- Handle Player object input
        return self.VIPPlayers[player.UserId] or false
    end
    return false
end

-- ==========================================
-- VIP BENEFITS CALCULATION
-- ==========================================

function VIPManager:GetDailyBonus(player)
    local isVIP = self:IsPlayerVIP(player)
    
    if isVIP then
        return {
            coins = ConfigModule.VIP.DAILY_BONUS.VIP.coins,
            seeds = ConfigModule.VIP.DAILY_BONUS.VIP.seeds,
            xp = ConfigModule.VIP.DAILY_BONUS.VIP.xp
        }
    else
        return {
            coins = ConfigModule.VIP.DAILY_BONUS.FREE.coins,
            seeds = ConfigModule.VIP.DAILY_BONUS.FREE.seeds,
            xp = ConfigModule.VIP.DAILY_BONUS.FREE.xp
        }
    end
end

function VIPManager:GetGrowthSpeedMultiplier(player)
    local isVIP = self:IsPlayerVIP(player)
    return isVIP and ConfigModule.VIP.GROWTH_SPEED_MULTIPLIER or 1.0
end

function VIPManager:GetOfflineProgressMultiplier(player)
    local isVIP = self:IsPlayerVIP(player)
    return isVIP and ConfigModule.VIP.OFFLINE_PROGRESS_MULTIPLIER or 1.0
end

function VIPManager:GetMaxPlots(player)
    local isVIP = self:IsPlayerVIP(player)
    local basePlots = ConfigModule.Plots.DEFAULT_PLOTS_FREE
    return isVIP and (basePlots + ConfigModule.VIP.EXTRA_PLOTS) or basePlots
end

function VIPManager:CanUseMultiHarvest(player)
    return self:IsPlayerVIP(player)
end

function VIPManager:CanUseAutoSell(player)
    return self:IsPlayerVIP(player)
end

function VIPManager:GetMultiHarvestRadius(player)
    local isVIP = self:IsPlayerVIP(player)
    return isVIP and ConfigModule.VIP.MULTI_HARVEST_RADIUS or 0
end

-- ==========================================
-- VIP VISUAL EFFECTS
-- ==========================================

function VIPManager:ApplyVIPEffects(player)
    local userId = player.UserId
    
    -- Apply golden nametag
    self:ApplyGoldenNametag(player)
    
    -- Add VIP badge
    self:AddVIPBadge(player)
    
    -- Store effects reference
    self.GoldenEffects[userId] = {
        nametag = true,
        badge = true,
        goldenTools = true
    }
    
    print("✨ VIPManager: Applied VIP visual effects to", player.Name)
end

function VIPManager:ApplyGoldenNametag(player)
    -- Change player name color to gold
    spawn(function()
        wait(1) -- Wait for character to load
        
        local character = player.Character or player.CharacterAdded:Wait()
        local humanoid = character:WaitForChild("Humanoid")
        
        -- Set name color to VIP gold
        humanoid.NameDisplayDistance = 100
        humanoid.HealthDisplayDistance = 0
        
        -- Create custom golden nametag
        local head = character:WaitForChild("Head")
        local existingGui = head:FindFirstChild("VIPNametag")
        
        if not existingGui then
            local billboardGui = Instance.new("BillboardGui")
            billboardGui.Name = "VIPNametag"
            billboardGui.Adornee = head
            billboardGui.Size = UDim2.new(0, 200, 0, 50)
            billboardGui.StudsOffset = Vector3.new(0, 2, 0)
            billboardGui.Parent = head
            
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Name = "NameLabel"
            nameLabel.Size = UDim2.new(1, 0, 1, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = ConfigModule.VIP.BADGE_ICON .. " " .. player.Name
            nameLabel.TextColor3 = ConfigModule.VIP.NAME_COLOR
            nameLabel.TextScaled = true
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.TextStrokeTransparency = 0
            nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
            nameLabel.Parent = billboardGui
        end
    end)
end

function VIPManager:AddVIPBadge(player)
    -- Add VIP crown badge to player (could be implemented in UI)
    -- This is a placeholder for future UI integration
    print("👑 VIPManager: Added VIP badge to", player.Name)
end

function VIPManager:RemoveVIPEffects(player)
    local userId = player.UserId
    
    -- Remove golden nametag
    if player.Character then
        local head = player.Character:FindFirstChild("Head")
        if head then
            local nametag = head:FindFirstChild("VIPNametag")
            if nametag then
                nametag:Destroy()
            end
        end
    end
    
    -- Clear effects reference
    self.GoldenEffects[userId] = nil
    
    print("🗑️ VIPManager: Removed VIP effects from", player.Name)
end

-- ==========================================
-- VIP NOTIFICATIONS
-- ==========================================

function VIPManager:ShowVIPWelcomeMessage(player)
    -- Create welcome message for new VIP members
    print("🎉 VIPManager: Welcome to VIP,", player.Name, "!")
    print("🌟 VIPManager: You now have access to:")
    print("   💰 3x Daily Bonus (200 coins, 3 seeds, 50 XP)")
    print("   🌱 20% faster plant growth")
    print("   ⏰ 2x offline progress") 
    print("   🏠 +1 extra plot")
    print("   🌟 Multi-harvest ability")
    print("   🤖 Auto-sell toggle")
    print("   👑 Golden nametag & VIP badge")
    
    -- This could trigger a UI notification panel in the future
end

function VIPManager:PromptVIPUpgrade(player, context)
    -- Show VIP upgrade prompt (context could be "daily_bonus", "extra_plot", etc.)
    print("💎 VIPManager: Showing VIP upgrade prompt to", player.Name, "for", context)
    
    -- This would trigger the MarketplaceService prompt
    spawn(function()
        local success = pcall(function()
            MarketplaceService:PromptGamePassPurchase(player, ConfigModule.VIP.GAMEPASS_ID)
        end)
        
        if not success then
            warn("❌ VIPManager: Failed to show VIP purchase prompt")
        end
    end)
end

-- ==========================================
-- VIP FEATURE VALIDATION
-- ==========================================

function VIPManager:ValidateVIPFeature(player, featureName)
    local isVIP = self:IsPlayerVIP(player)
    local isVIPFeature = ConfigModule:IsVIPFeatureEnabled(featureName)
    
    if isVIPFeature and not isVIP then
        -- Show VIP upgrade prompt
        self:PromptVIPUpgrade(player, featureName)
        return false
    end
    
    return true
end

function VIPManager:CanAccessFeature(player, featureName)
    local isVIP = self:IsPlayerVIP(player)
    local isVIPFeature = ConfigModule:IsVIPFeatureEnabled(featureName)
    
    -- Free players can access all non-VIP features
    -- VIP players can access everything
    return not isVIPFeature or isVIP
end

-- ==========================================
-- UTILITY FUNCTIONS
-- ==========================================

function VIPManager:GetVIPPlayerCount()
    local count = 0
    for userId, isVIP in pairs(self.VIPPlayers) do
        if isVIP then
            count = count + 1
        end
    end
    return count
end

function VIPManager:GetAllVIPPlayers()
    local vipPlayers = {}
    for userId, isVIP in pairs(self.VIPPlayers) do
        if isVIP then
            local player = Players:GetPlayerByUserId(userId)
            if player then
                table.insert(vipPlayers, player)
            end
        end
    end
    return vipPlayers
end

function VIPManager:RefreshVIPStatus(player)
    -- Force refresh VIP status (clear cache and recheck)
    local userId = player.UserId
    self.VIPCache[userId] = nil
    
    local isVIP = self:CheckVIPStatus(player)
    self:SetVIPStatus(player, isVIP)
    
    if isVIP then
        self:ApplyVIPEffects(player)
    else
        self:RemoveVIPEffects(player)
    end
    
    print("🔄 VIPManager: Refreshed VIP status for", player.Name, ":", isVIP)
    return isVIP
end

function VIPManager:GetVIPStats()
    local totalPlayers = #Players:GetPlayers()
    local vipCount = self:GetVIPPlayerCount()
    local conversionRate = totalPlayers > 0 and (vipCount / totalPlayers * 100) or 0
    
    return {
        totalPlayers = totalPlayers,
        vipPlayers = vipCount,
        freePlayerss = totalPlayers - vipCount,
        conversionRate = conversionRate
    }
end

-- ==========================================
-- DEBUGGING & ADMIN COMMANDS
-- ==========================================

function VIPManager:ForceVIPStatus(player, isVIP)
    -- Admin command to force VIP status (for testing)
    self:SetVIPStatus(player, isVIP)
    
    if isVIP then
        self:ApplyVIPEffects(player)
    else
        self:RemoveVIPEffects(player)
    end
    
    print("🔧 VIPManager: Force set VIP status for", player.Name, "to", isVIP)
end

function VIPManager:PrintVIPDebugInfo()
    print("🐛 VIPManager Debug Info:")
    print("   GamePass ID:", ConfigModule.VIP.GAMEPASS_ID)
    print("   VIP Players:", self:GetVIPPlayerCount())
    print("   Cache Entries:", #self.VIPCache)
    print("   Active Effects:", #self.GoldenEffects)
    
    local stats = self:GetVIPStats()
    print("   Conversion Rate:", string.format("%.1f%%", stats.conversionRate))
end

return VIPManager
