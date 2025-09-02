--[[
    EconomyManager.lua
    Core Economic System & Shop Transactions
    
    Priority: 5 (Core gameplay module)
    Dependencies: ConfigModule, VIPManager
    Used by: ShopHandler, HarvestHandler, PlantingHandler
    
    Features:
    - Coin management (earn, spend, validate)
    - Shop transaction processing
    - Anti-cheat validation
    - VIP auto-sell functionality
    - Economic balance tracking
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)
-- VIPManager will be loaded later to avoid circular dependency

local EconomyManager = {}
EconomyManager.__index = EconomyManager

-- ==========================================
-- ECONOMIC DATA STORAGE
-- ==========================================

EconomyManager.PlayerCoins = {}      -- [userId] = coinAmount
EconomyManager.TransactionHistory = {} -- [userId] = {transactions}
EconomyManager.EarningsPerHour = {}  -- [userId] = hourlyEarnings (anti-cheat)
EconomyManager.AutoSellQueue = {}    -- [userId] = {plotIds ready for auto-sell}

-- Economic tracking for balancing
EconomyManager.EconomicStats = {
    totalCoinsInCirculation = 0,
    totalTransactions = 0,
    averagePlayerWealth = 0,
    topEarners = {}
}

-- ==========================================
-- INITIALIZATION
-- ==========================================

function EconomyManager:Initialize()
    print("💰 EconomyManager: Initializing economic system...")
    
    -- Set up player events
    self:SetupPlayerEvents()
    
    -- Start hourly earnings tracker (anti-cheat)
    self:StartEarningsTracker()
    
    -- Start auto-sell system for VIP players
    self:StartAutoSellSystem()
    
    print("✅ EconomyManager: Economic system initialized successfully")
end

function EconomyManager:SetupPlayerEvents()
    Players.PlayerAdded:Connect(function(player)
        self:OnPlayerJoined(player)
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        self:OnPlayerLeaving(player)
    end)
end

function EconomyManager:OnPlayerJoined(player)
    local userId = player.UserId
    
    -- Initialize player coins (will be loaded from DataStore later)
    self.PlayerCoins[userId] = ConfigModule.Economy.STARTING_COINS
    self.TransactionHistory[userId] = {}
    self.EarningsPerHour[userId] = 0
    
    print("💰 EconomyManager:", player.Name, "joined with", self.PlayerCoins[userId], "coins")
end

function EconomyManager:OnPlayerLeaving(player)
    local userId = player.UserId
    
    -- Clear economic data (will be saved to DataStore)
    self.PlayerCoins[userId] = nil
    self.TransactionHistory[userId] = nil
    self.EarningsPerHour[userId] = nil
    self.AutoSellQueue[userId] = nil
    
    print("💰 EconomyManager:", player.Name, "left the game")
end

-- ==========================================
-- COIN MANAGEMENT
-- ==========================================

function EconomyManager:GetPlayerCoins(player)
    local userId = self:GetUserId(player)
    return self.PlayerCoins[userId] or 0
end

function EconomyManager:SetPlayerCoins(player, amount)
    local userId = self:GetUserId(player)
    
    -- Validate amount
    amount = math.max(0, math.floor(amount)) -- No negative coins, integers only
    
    local oldAmount = self.PlayerCoins[userId] or 0
    self.PlayerCoins[userId] = amount
    
    -- Track economic stats
    self:UpdateEconomicStats(amount - oldAmount)
    
    -- Log transaction
    self:LogTransaction(userId, "set_coins", amount - oldAmount, "Admin/System")
    
    print("💰 EconomyManager: Set", self:GetPlayerName(player), "coins to", amount)
    return amount
end

function EconomyManager:AddCoins(player, amount, reason)
    if amount <= 0 then
        warn("❌ EconomyManager: Cannot add negative or zero coins")
        return false
    end
    
    local userId = self:GetUserId(player)
    local currentCoins = self.PlayerCoins[userId] or 0
    
    -- Anti-cheat: Check hourly earnings limit
    if not self:ValidateEarnings(userId, amount) then
        warn("🚫 EconomyManager: Hourly earnings limit exceeded for", self:GetPlayerName(player))
        return false
    end
    
    local newAmount = currentCoins + amount
    self.PlayerCoins[userId] = newAmount
    
    -- Track earnings for anti-cheat
    self.EarningsPerHour[userId] = (self.EarningsPerHour[userId] or 0) + amount
    
    -- Track economic stats
    self:UpdateEconomicStats(amount)
    
    -- Log transaction
    self:LogTransaction(userId, "earn", amount, reason or "Unknown")
    
    print("💰 EconomyManager:", self:GetPlayerName(player), "earned", amount, "coins (Total:", newAmount, ")")
    return true
end

function EconomyManager:SpendCoins(player, amount, reason)
    if amount <= 0 then
        warn("❌ EconomyManager: Cannot spend negative or zero coins")
        return false
    end
    
    local userId = self:GetUserId(player)
    local currentCoins = self.PlayerCoins[userId] or 0
    
    -- Check if player has enough coins
    if currentCoins < amount then
        warn("❌ EconomyManager:", self:GetPlayerName(player), "insufficient coins (Has:", currentCoins, "Needs:", amount, ")")
        return false
    end
    
    local newAmount = currentCoins - amount
    self.PlayerCoins[userId] = newAmount
    
    -- Track economic stats
    self:UpdateEconomicStats(-amount)
    
    -- Log transaction
    self:LogTransaction(userId, "spend", -amount, reason or "Unknown")
    
    print("💰 EconomyManager:", self:GetPlayerName(player), "spent", amount, "coins (Remaining:", newAmount, ")")
    return true
end

function EconomyManager:CanAfford(player, amount)
    local currentCoins = self:GetPlayerCoins(player)
    return currentCoins >= amount
end

-- ==========================================
-- SHOP TRANSACTIONS
-- ==========================================

function EconomyManager:ProcessSeedPurchase(player, plantType, quantity)
    quantity = quantity or 1
    
    local plantConfig = ConfigModule.Plants[plantType]
    if not plantConfig then
        warn("❌ EconomyManager: Unknown plant type for purchase:", plantType)
        return false
    end
    
    local totalCost = plantConfig.buyPrice * quantity
    
    -- Check if player can afford
    if not self:CanAfford(player, totalCost) then
        return false, "Insufficient coins"
    end
    
    -- Process payment
    local success = self:SpendCoins(player, totalCost, "Seed Purchase: " .. plantType)
    
    if success then
        print("🛒 EconomyManager:", self:GetPlayerName(player), "bought", quantity, plantType, "seeds for", totalCost, "coins")
        return true, quantity
    else
        return false, "Payment failed"
    end
end

function EconomyManager:ProcessPlantSale(player, plantType, quantity)
    quantity = quantity or 1
    
    local plantConfig = ConfigModule.Plants[plantType]
    if not plantConfig then
        warn("❌ EconomyManager: Unknown plant type for sale:", plantType)
        return false
    end
    
    local totalEarnings = plantConfig.sellPrice * quantity
    
    -- Apply VIP multiplier if available
    local VIPManager = self:GetVIPManager()
    if VIPManager and VIPManager:IsPlayerVIP(player) then
        -- VIP players could get a 10% bonus (optional)
        -- totalEarnings = math.floor(totalEarnings * 1.1)
    end
    
    -- Process sale
    local success = self:AddCoins(player, totalEarnings, "Plant Sale: " .. plantType)
    
    if success then
        print("💰 EconomyManager:", self:GetPlayerName(player), "sold", quantity, plantType, "for", totalEarnings, "coins")
        return true, totalEarnings
    else
        return false, "Sale failed"
    end
end

-- ==========================================
-- VIP AUTO-SELL SYSTEM
-- ==========================================

function EconomyManager:StartAutoSellSystem()
    -- Check for VIP auto-sell every 5 seconds
    spawn(function()
        while true do
            wait(ConfigModule.Economy.AUTO_SELL_DELAY)
            self:ProcessAutoSellQueue()
        end
    end)
    
    print("🤖 EconomyManager: Auto-sell system started")
end

function EconomyManager:AddToAutoSellQueue(player, plotId, plantType)
    local VIPManager = self:GetVIPManager()
    if not VIPManager or not VIPManager:IsPlayerVIP(player) then
        return false -- Only VIP players can use auto-sell
    end
    
    local userId = self:GetUserId(player)
    if not self.AutoSellQueue[userId] then
        self.AutoSellQueue[userId] = {}
    end
    
    table.insert(self.AutoSellQueue[userId], {
        plotId = plotId,
        plantType = plantType,
        queueTime = os.time()
    })
    
    print("🤖 EconomyManager: Added plot", plotId, "to auto-sell queue for", self:GetPlayerName(player))
    return true
end

function EconomyManager:ProcessAutoSellQueue()
    for userId, queue in pairs(self.AutoSellQueue) do
        if #queue > 0 then
            local player = Players:GetPlayerByUserId(userId)
            if player then
                -- Process first item in queue
                local item = table.remove(queue, 1)
                
                if item then
                    local success, earnings = self:ProcessPlantSale(player, item.plantType, 1)
                    if success then
                        print("🤖 EconomyManager: Auto-sold", item.plantType, "from plot", item.plotId, "for", earnings, "coins")
                        
                        -- Notify player about auto-sale
                        self:NotifyAutoSale(player, item.plantType, earnings)
                    end
                end
            end
        end
    end
end

function EconomyManager:NotifyAutoSale(player, plantType, earnings)
    -- This could trigger a UI notification
    -- For now, just print to console
    print("🔔 EconomyManager: Auto-sell notification for", self:GetPlayerName(player), ":", plantType, "sold for", earnings, "coins")
end

-- ==========================================
-- ANTI-CHEAT VALIDATION
-- ==========================================

function EconomyManager:ValidateEarnings(userId, amount)
    local currentHourlyEarnings = self.EarningsPerHour[userId] or 0
    local newHourlyEarnings = currentHourlyEarnings + amount
    
    -- Check against maximum earnings per hour
    local maxEarnings = ConfigModule.Economy.MAX_COINS_PER_HOUR
    
    return newHourlyEarnings <= maxEarnings
end

function EconomyManager:StartEarningsTracker()
    -- Reset hourly earnings every hour
    spawn(function()
        while true do
            wait(3600) -- 1 hour
            for userId, _ in pairs(self.EarningsPerHour) do
                self.EarningsPerHour[userId] = 0
            end
            print("🔄 EconomyManager: Hourly earnings reset")
        end
    end)
end

function EconomyManager:ValidateTransaction(player, transactionType, amount)
    local userId = self:GetUserId(player)
    
    -- Check for rapid transactions (potential exploit)
    local lastTransaction = self:GetLastTransaction(userId)
    if lastTransaction and (os.time() - lastTransaction.timestamp) < 1 then
        warn("🚫 EconomyManager: Rapid transaction detected for", self:GetPlayerName(player))
        return false
    end
    
    -- Check amount limits
    if transactionType == "spend" and amount > ConfigModule.Security.MAX_COINS_PER_TRANSACTION then
        warn("🚫 EconomyManager: Transaction amount too large for", self:GetPlayerName(player))
        return false
    end
    
    return true
end

-- ==========================================
-- TRANSACTION LOGGING
-- ==========================================

function EconomyManager:LogTransaction(userId, transactionType, amount, reason)
    if not self.TransactionHistory[userId] then
        self.TransactionHistory[userId] = {}
    end
    
    local transaction = {
        type = transactionType,
        amount = amount,
        reason = reason,
        timestamp = os.time(),
        balance = self.PlayerCoins[userId] or 0
    }
    
    table.insert(self.TransactionHistory[userId], transaction)
    
    -- Keep only last 100 transactions per player
    if #self.TransactionHistory[userId] > 100 then
        table.remove(self.TransactionHistory[userId], 1)
    end
    
    -- Update total transactions counter
    self.EconomicStats.totalTransactions = self.EconomicStats.totalTransactions + 1
end

function EconomyManager:GetLastTransaction(userId)
    local history = self.TransactionHistory[userId]
    if history and #history > 0 then
        return history[#history]
    end
    return nil
end

function EconomyManager:GetTransactionHistory(player, limit)
    local userId = self:GetUserId(player)
    local history = self.TransactionHistory[userId] or {}
    
    limit = limit or 10
    local startIndex = math.max(1, #history - limit + 1)
    local recentHistory = {}
    
    for i = startIndex, #history do
        table.insert(recentHistory, history[i])
    end
    
    return recentHistory
end

-- ==========================================
-- ECONOMIC STATISTICS
-- ==========================================

function EconomyManager:UpdateEconomicStats(deltaCoins)
    self.EconomicStats.totalCoinsInCirculation = self.EconomicStats.totalCoinsInCirculation + deltaCoins
    
    -- Calculate average player wealth
    local totalPlayers = 0
    local totalWealth = 0
    
    for userId, coins in pairs(self.PlayerCoins) do
        totalPlayers = totalPlayers + 1
        totalWealth = totalWealth + coins
    end
    
    if totalPlayers > 0 then
        self.EconomicStats.averagePlayerWealth = totalWealth / totalPlayers
    end
end

function EconomyManager:GetEconomicStats()
    return {
        totalCoins = self.EconomicStats.totalCoinsInCirculation,
        totalTransactions = self.EconomicStats.totalTransactions,
        averageWealth = self.EconomicStats.averagePlayerWealth,
        activePlayers = self:GetActivePlayerCount(),
        wealthDistribution = self:GetWealthDistribution()
    }
end

function EconomyManager:GetActivePlayerCount()
    local count = 0
    for userId, _ in pairs(self.PlayerCoins) do
        count = count + 1
    end
    return count
end

function EconomyManager:GetWealthDistribution()
    local distribution = {
        poor = 0,      -- 0-100 coins
        middle = 0,    -- 101-1000 coins
        rich = 0,      -- 1001-5000 coins
        wealthy = 0    -- 5000+ coins
    }
    
    for userId, coins in pairs(self.PlayerCoins) do
        if coins <= 100 then
            distribution.poor = distribution.poor + 1
        elseif coins <= 1000 then
            distribution.middle = distribution.middle + 1
        elseif coins <= 5000 then
            distribution.rich = distribution.rich + 1
        else
            distribution.wealthy = distribution.wealthy + 1
        end
    end
    
    return distribution
end

-- ==========================================
-- UTILITY FUNCTIONS
-- ==========================================

function EconomyManager:GetUserId(player)
    if type(player) == "number" then
        return player
    elseif player and player.UserId then
        return player.UserId
    else
        error("Invalid player input to EconomyManager")
    end
end

function EconomyManager:GetPlayerName(player)
    if type(player) == "number" then
        local playerObj = Players:GetPlayerByUserId(player)
        return playerObj and playerObj.Name or "Unknown"
    elseif player and player.Name then
        return player.Name
    else
        return "Unknown"
    end
end

function EconomyManager:GetVIPManager()
    -- Safely get VIPManager to avoid circular dependency
    local success, VIPManager = pcall(function()
        return require(game.ServerStorage.Modules.VIPManager)
    end)
    return success and VIPManager or nil
end

-- ==========================================
-- ADMIN & DEBUG FUNCTIONS
-- ==========================================

function EconomyManager:AdminAddCoins(player, amount)
    -- Admin command to give coins without validation
    local userId = self:GetUserId(player)
    local currentCoins = self.PlayerCoins[userId] or 0
    self.PlayerCoins[userId] = currentCoins + amount
    
    self:LogTransaction(userId, "admin_add", amount, "Admin Command")
    
    print("🔧 EconomyManager: Admin gave", amount, "coins to", self:GetPlayerName(player))
end

function EconomyManager:PrintEconomicDebugInfo()
    local stats = self:GetEconomicStats()
    
    print("🐛 EconomyManager Debug Info:")
    print("   Total coins in circulation:", stats.totalCoins)
    print("   Total transactions:", stats.totalTransactions)
    print("   Average player wealth:", string.format("%.1f", stats.averageWealth))
    print("   Active players:", stats.activePlayers)
    print("   Wealth distribution:")
    print("     Poor (0-100):", stats.wealthDistribution.poor)
    print("     Middle (101-1000):", stats.wealthDistribution.middle)
    print("     Rich (1001-5000):", stats.wealthDistribution.rich)
    print("     Wealthy (5000+):", stats.wealthDistribution.wealthy)
end

return EconomyManager
