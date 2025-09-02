--[[
    SocialFeaturesManager.lua
    Server-Side Social Features System
    
    Priority: 22 (VIP & Monetization phase)
    Dependencies: Players, DataStoreService, MessagingService
    Used by: UI, leaderboards, achievements, garden sharing
    
    Features:
    - Friend system integration
    - Garden visiting and sharing
    - Gift system between players
    - Social achievements
    - VIP exclusive social features
    - Community events
--]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

-- Load required modules
local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)

local SocialFeaturesManager = {}
SocialFeaturesManager.__index = SocialFeaturesManager

-- ==========================================
-- DATASTORE SETUP
-- ==========================================

SocialFeaturesManager.SocialDataStore = DataStoreService:GetDataStore("SocialFeatures_v1")
SocialFeaturesManager.GiftDataStore = DataStoreService:GetDataStore("Gifts_v1")
SocialFeaturesManager.VisitDataStore = DataStoreService:GetDataStore("GardenVisits_v1")

-- ==========================================
-- SOCIAL FEATURES CONFIGURATION
-- ==========================================

SocialFeaturesManager.Features = {
    friendVisits = {
        enabled = true,
        maxVisitsPerDay = 10,
        visitReward = 25,
        hostReward = 50,
        vipMultiplier = 2
    },
    
    gifts = {
        enabled = true,
        maxGiftsPerDay = 5,
        maxGiftValue = 1000,
        vipMaxGifts = 10,
        vipMaxValue = 5000,
        cooldownHours = 2
    },
    
    gardenSharing = {
        enabled = true,
        maxScreenshots = 3,
        vipMaxScreenshots = 10,
        shareReward = 100
    },
    
    communityEvents = {
        enabled = true,
        vipEarlyAccess = true,
        vipBonusRewards = true
    },
    
    socialAchievements = {
        enabled = true,
        friendVisitMilestones = {5, 10, 25, 50, 100},
        giftMilestones = {5, 15, 30, 75, 150},
        popularityMilestones = {10, 50, 100, 250, 500}
    }
}

-- Gift types and configurations
SocialFeaturesManager.GiftTypes = {
    coins = {
        id = "coins",
        name = "Coins",
        icon = "💰",
        maxAmount = 1000,
        vipMaxAmount = 5000,
        description = "Send coins to help your friends!"
    },
    
    seeds = {
        id = "seeds",
        name = "Seeds",
        icon = "🌱",
        maxAmount = 10,
        vipMaxAmount = 25,
        description = "Share seeds with your friends!"
    },
    
    fertilizer = {
        id = "fertilizer",
        name = "Fertilizer",
        icon = "🧪",
        maxAmount = 5,
        vipMaxAmount = 15,
        description = "Boost your friend's garden growth!"
    },
    
    decorations = {
        id = "decorations",
        name = "Decorations",
        icon = "🎨",
        maxAmount = 3,
        vipMaxAmount = 8,
        description = "Beautiful decorations for gardens!"
    },
    
    vip_exclusive = {
        id = "vip_exclusive",
        name = "VIP Gift Box",
        icon = "👑",
        maxAmount = 1,
        vipMaxAmount = 3,
        description = "Exclusive VIP gift containing rare items!",
        vipOnly = true
    }
}

-- ==========================================
-- STATE MANAGEMENT
-- ==========================================

SocialFeaturesManager.PlayerSocialData = {}        -- [userId] = social data
SocialFeaturesManager.ActiveVisits = {}            -- [hostUserId] = {visitors}
SocialFeaturesManager.PendingGifts = {}           -- [recipientUserId] = {gifts}
SocialFeaturesManager.CommunityEvents = {}         -- Active community events
SocialFeaturesManager.SocialStats = {}            -- Global social statistics

-- ==========================================
-- INITIALIZATION
-- ==========================================

function SocialFeaturesManager:Initialize()
    print("👥 SocialFeaturesManager: Initializing social features system...")
    
    -- Set up remote events
    self:SetupRemoteEvents()
    
    -- Set up player tracking
    self:SetupPlayerTracking()
    
    -- Set up messaging service
    self:SetupMessagingService()
    
    -- Load community events
    self:LoadCommunityEvents()
    
    -- Start periodic updates
    self:StartPeriodicUpdates()
    
    print("✅ SocialFeaturesManager: Social features system initialized")
end

function SocialFeaturesManager:SetupRemoteEvents()
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then
        remoteEvents = Instance.new("Folder")
        remoteEvents.Name = "RemoteEvents"
        remoteEvents.Parent = ReplicatedStorage
    end
    
    -- Visit friend's garden
    local visitGardenFunction = Instance.new("RemoteFunction")
    visitGardenFunction.Name = "VisitFriendGarden"
    visitGardenFunction.Parent = remoteEvents
    visitGardenFunction.OnServerInvoke = function(player, friendUserId)
        return self:VisitFriendGarden(player, friendUserId)
    end
    
    -- Send gift to friend
    local sendGiftFunction = Instance.new("RemoteFunction")
    sendGiftFunction.Name = "SendGiftToFriend"
    sendGiftFunction.Parent = remoteEvents
    sendGiftFunction.OnServerInvoke = function(player, friendUserId, giftType, amount, message)
        return self:SendGiftToFriend(player, friendUserId, giftType, amount, message)
    end
    
    -- Get pending gifts
    local getPendingGiftsFunction = Instance.new("RemoteFunction")
    getPendingGiftsFunction.Name = "GetPendingGifts"
    getPendingGiftsFunction.Parent = remoteEvents
    getPendingGiftsFunction.OnServerInvoke = function(player)
        return self:GetPendingGifts(player)
    end
    
    -- Claim gift
    local claimGiftFunction = Instance.new("RemoteFunction")
    claimGiftFunction.Name = "ClaimGift"
    claimGiftFunction.Parent = remoteEvents
    claimGiftFunction.OnServerInvoke = function(player, giftId)
        return self:ClaimGift(player, giftId)
    end
    
    -- Get social stats
    local getSocialStatsFunction = Instance.new("RemoteFunction")
    getSocialStatsFunction.Name = "GetPlayerSocialStats"
    getSocialStatsFunction.Parent = remoteEvents
    getSocialStatsFunction.OnServerInvoke = function(player)
        return self:GetPlayerSocialStats(player)
    end
    
    -- Share garden screenshot
    local shareGardenFunction = Instance.new("RemoteFunction")
    shareGardenFunction.Name = "ShareGarden"
    shareGardenFunction.Parent = remoteEvents
    shareGardenFunction.OnServerInvoke = function(player, screenshotData)
        return self:ShareGarden(player, screenshotData)
    end
    
    -- Get friend list for social features
    local getFriendsFunction = Instance.new("RemoteFunction")
    getFriendsFunction.Name = "GetFriendsForSocial"
    getFriendsFunction.Parent = remoteEvents
    getFriendsFunction.OnServerInvoke = function(player)
        return self:GetFriendsForSocial(player)
    end
    
    -- Events for real-time updates
    local socialUpdateEvent = Instance.new("RemoteEvent")
    socialUpdateEvent.Name = "SocialUpdate"
    socialUpdateEvent.Parent = remoteEvents
    self.SocialUpdateEvent = socialUpdateEvent
    
    local giftReceivedEvent = Instance.new("RemoteEvent")
    giftReceivedEvent.Name = "GiftReceived"
    giftReceivedEvent.Parent = remoteEvents
    self.GiftReceivedEvent = giftReceivedEvent
end

function SocialFeaturesManager:SetupPlayerTracking()
    -- Track player joining
    Players.PlayerAdded:Connect(function(player)
        self:OnPlayerJoined(player)
    end)
    
    -- Track player leaving
    Players.PlayerRemoving:Connect(function(player)
        self:OnPlayerLeaving(player)
    end)
    
    -- Initialize existing players
    for _, player in pairs(Players:GetPlayers()) do
        self:OnPlayerJoined(player)
    end
end

function SocialFeaturesManager:SetupMessagingService()
    -- Listen for cross-server social updates
    MessagingService:SubscribeAsync("SocialUpdate", function(message)
        self:HandleCrossServerSocialUpdate(message.Data)
    end)
    
    MessagingService:SubscribeAsync("GiftSent", function(message)
        self:HandleCrossServerGift(message.Data)
    end)
end

function SocialFeaturesManager:LoadCommunityEvents()
    local success, eventData = pcall(function()
        return self.SocialDataStore:GetAsync("community_events")
    end)
    
    if success and eventData then
        self.CommunityEvents = eventData
        print("👥 SocialFeaturesManager: Loaded", #self.CommunityEvents, "community events")
    else
        self.CommunityEvents = {}
    end
end

function SocialFeaturesManager:StartPeriodicUpdates()
    -- Clean up expired data
    spawn(function()
        while true do
            wait(3600) -- Every hour
            self:CleanupExpiredData()
        end
    end)
    
    -- Update social statistics
    spawn(function()
        while true do
            wait(300) -- Every 5 minutes
            self:UpdateSocialStatistics()
        end
    end)
end

-- ==========================================
-- PLAYER DATA MANAGEMENT
-- ==========================================

function SocialFeaturesManager:OnPlayerJoined(player)
    local userId = player.UserId
    
    -- Initialize social data
    self.PlayerSocialData[userId] = {
        friendVisits = {
            today = 0,
            total = 0,
            lastVisitDate = "",
            visitedFriends = {}
        },
        
        gifts = {
            sentToday = 0,
            receivedToday = 0,
            totalSent = 0,
            totalReceived = 0,
            lastGiftDate = "",
            giftCooldowns = {}
        },
        
        garden = {
            totalVisitors = 0,
            popularityRating = 0,
            screenshots = 0,
            lastSharedDate = ""
        },
        
        achievements = {
            socialMilestones = {},
            friendshipLevel = 1
        },
        
        vipStatus = false,
        lastActiveDate = os.date("%Y-%m-%d")
    }
    
    -- Load existing social data
    self:LoadPlayerSocialData(player)
    
    -- Check for pending gifts
    self:LoadPendingGifts(player)
    
    -- Update VIP status
    self:UpdatePlayerVIPStatus(player)
    
    print("👥 SocialFeaturesManager: Initialized social data for", player.Name)
end

function SocialFeaturesManager:OnPlayerLeaving(player)
    -- Save social data
    self:SavePlayerSocialData(player)
    
    -- Clean up memory
    local userId = player.UserId
    self.PlayerSocialData[userId] = nil
    
    -- Remove from active visits
    for hostUserId, visitors in pairs(self.ActiveVisits) do
        for i, visitorUserId in ipairs(visitors) do
            if visitorUserId == userId then
                table.remove(visitors, i)
                break
            end
        end
    end
end

function SocialFeaturesManager:LoadPlayerSocialData(player)
    local userId = player.UserId
    
    local success, socialData = pcall(function()
        return self.SocialDataStore:GetAsync("social_" .. userId)
    end)
    
    if success and socialData then
        -- Merge with defaults
        for key, value in pairs(socialData) do
            if self.PlayerSocialData[userId][key] then
                self.PlayerSocialData[userId][key] = value
            end
        end
        
        print("👥 SocialFeaturesManager: Loaded social data for", player.Name)
    end
end

function SocialFeaturesManager:SavePlayerSocialData(player)
    local userId = player.UserId
    local socialData = self.PlayerSocialData[userId]
    
    if not socialData then return end
    
    local success, errorMessage = pcall(function()
        self.SocialDataStore:SetAsync("social_" .. userId, socialData)
    end)
    
    if not success then
        warn("⚠️ SocialFeaturesManager: Failed to save social data for", player.Name, "-", errorMessage)
    end
end

function SocialFeaturesManager:LoadPendingGifts(player)
    local userId = player.UserId
    
    local success, giftData = pcall(function()
        return self.GiftDataStore:GetAsync("pending_" .. userId)
    end)
    
    if success and giftData then
        self.PendingGifts[userId] = giftData
        
        -- Notify player of pending gifts
        if #giftData > 0 then
            self:NotifyPlayerOfPendingGifts(player, #giftData)
        end
    else
        self.PendingGifts[userId] = {}
    end
end

function SocialFeaturesManager:UpdatePlayerVIPStatus(player)
    local userId = player.UserId
    local vipManager = _G.VIPManager
    
    if vipManager and self.PlayerSocialData[userId] then
        self.PlayerSocialData[userId].vipStatus = vipManager:IsPlayerVIP(player)
    end
end

-- ==========================================
-- FRIEND VISITING SYSTEM
-- ==========================================

function SocialFeaturesManager:VisitFriendGarden(player, friendUserId)
    local userId = player.UserId
    local socialData = self.PlayerSocialData[userId]
    
    if not socialData then
        return {success = false, error = "Social data not loaded"}
    end
    
    -- Check if already visited this friend today
    local today = os.date("%Y-%m-%d")
    if socialData.friendVisits.lastVisitDate == today then
        if socialData.friendVisits.visitedFriends[friendUserId] then
            return {success = false, error = "Already visited this friend today"}
        end
        
        -- Check daily visit limit
        local maxVisits = self.Features.friendVisits.maxVisitsPerDay
        if socialData.vipStatus then
            maxVisits = maxVisits * self.Features.friendVisits.vipMultiplier
        end
        
        if socialData.friendVisits.today >= maxVisits then
            return {success = false, error = "Daily visit limit reached"}
        end
    else
        -- Reset daily counters
        socialData.friendVisits.today = 0
        socialData.friendVisits.lastVisitDate = today
        socialData.friendVisits.visitedFriends = {}
    end
    
    -- Check if friend is online (for real-time visit)
    local friendPlayer = Players:GetPlayerByUserId(friendUserId)
    local isOnline = friendPlayer ~= nil
    
    -- Record the visit
    socialData.friendVisits.today = socialData.friendVisits.today + 1
    socialData.friendVisits.total = socialData.friendVisits.total + 1
    socialData.friendVisits.visitedFriends[friendUserId] = true
    
    -- Calculate rewards
    local visitReward = self.Features.friendVisits.visitReward
    if socialData.vipStatus then
        visitReward = visitReward * self.Features.friendVisits.vipMultiplier
    end
    
    -- Give visitor reward
    local economyManager = _G.EconomyManager
    if economyManager then
        economyManager:AddCoins(player, visitReward, "friend_visit")
    end
    
    -- Track visit for friend (if online)
    if isOnline then
        self:RecordFriendVisit(friendPlayer, userId)
        
        -- Add to active visits
        if not self.ActiveVisits[friendUserId] then
            self.ActiveVisits[friendUserId] = {}
        end
        table.insert(self.ActiveVisits[friendUserId], userId)
    else
        -- Send cross-server message for offline visit tracking
        self:SendCrossServerVisitMessage(friendUserId, userId)
    end
    
    -- Check for achievements
    self:CheckSocialAchievements(player, "friend_visits")
    
    -- Update statistics
    self:UpdatePlayerSocialStats(player)
    
    print("👥 SocialFeaturesManager:", player.Name, "visited friend", friendUserId)
    
    return {
        success = true,
        reward = visitReward,
        visitsToday = socialData.friendVisits.today,
        visitsTotal = socialData.friendVisits.total,
        isOnline = isOnline
    }
end

function SocialFeaturesManager:RecordFriendVisit(hostPlayer, visitorUserId)
    local hostUserId = hostPlayer.UserId
    local hostSocialData = self.PlayerSocialData[hostUserId]
    
    if not hostSocialData then return end
    
    -- Update host's visitor count
    hostSocialData.garden.totalVisitors = hostSocialData.garden.totalVisitors + 1
    
    -- Give host reward
    local hostReward = self.Features.friendVisits.hostReward
    if hostSocialData.vipStatus then
        hostReward = hostReward * self.Features.friendVisits.vipMultiplier
    end
    
    local economyManager = _G.EconomyManager
    if economyManager then
        economyManager:AddCoins(hostPlayer, hostReward, "garden_visit_host")
    end
    
    -- Notify host
    local notificationManager = _G.NotificationManager
    if notificationManager then
        -- Get visitor name
        local visitorPlayer = Players:GetPlayerByUserId(visitorUserId)
        local visitorName = visitorPlayer and visitorPlayer.Name or "Friend"
        
        notificationManager:ShowToast(
            "Friend Visit! 👥",
            visitorName .. " visited your garden! (+" .. hostReward .. " coins)",
            "🏠",
            "social"
        )
    end
    
    print("👥 SocialFeaturesManager: Recorded visit to", hostPlayer.Name, "'s garden")
end

function SocialFeaturesManager:SendCrossServerVisitMessage(friendUserId, visitorUserId)
    local messageData = {
        type = "friend_visit",
        friendUserId = friendUserId,
        visitorUserId = visitorUserId,
        timestamp = tick()
    }
    
    local success, errorMessage = pcall(function()
        MessagingService:PublishAsync("SocialUpdate", messageData)
    end)
    
    if not success then
        warn("⚠️ SocialFeaturesManager: Failed to send cross-server visit message -", errorMessage)
    end
end

-- ==========================================
-- GIFT SYSTEM
-- ==========================================

function SocialFeaturesManager:SendGiftToFriend(player, friendUserId, giftType, amount, message)
    local userId = player.UserId
    local socialData = self.PlayerSocialData[userId]
    
    if not socialData then
        return {success = false, error = "Social data not loaded"}
    end
    
    -- Validate gift type
    local giftConfig = self.GiftTypes[giftType]
    if not giftConfig then
        return {success = false, error = "Invalid gift type"}
    end
    
    -- Check VIP requirements for exclusive gifts
    if giftConfig.vipOnly and not socialData.vipStatus then
        return {success = false, error = "VIP only gift"}
    end
    
    -- Check daily gift limits
    local today = os.date("%Y-%m-%d")
    if socialData.gifts.lastGiftDate ~= today then
        socialData.gifts.sentToday = 0
        socialData.gifts.lastGiftDate = today
    end
    
    local maxGifts = socialData.vipStatus and self.Features.gifts.vipMaxGifts or self.Features.gifts.maxGiftsPerDay
    if socialData.gifts.sentToday >= maxGifts then
        return {success = false, error = "Daily gift limit reached"}
    end
    
    -- Check gift cooldown for this friend
    local cooldownKey = friendUserId .. "_" .. giftType
    local lastGiftTime = socialData.gifts.giftCooldowns[cooldownKey] or 0
    local cooldownHours = self.Features.gifts.cooldownHours
    
    if tick() - lastGiftTime < (cooldownHours * 3600) then
        local remainingTime = math.ceil((cooldownHours * 3600 - (tick() - lastGiftTime)) / 60)
        return {success = false, error = "Gift cooldown active", remainingMinutes = remainingTime}
    end
    
    -- Validate amount
    local maxAmount = socialData.vipStatus and giftConfig.vipMaxAmount or giftConfig.maxAmount
    if amount > maxAmount or amount <= 0 then
        return {success = false, error = "Invalid gift amount"}
    end
    
    -- Check if player has enough resources to send
    if not self:CanPlayerSendGift(player, giftType, amount) then
        return {success = false, error = "Insufficient resources"}
    end
    
    -- Create gift data
    local giftData = {
        id = HttpService:GenerateGUID(false),
        senderUserId = userId,
        senderName = player.Name,
        recipientUserId = friendUserId,
        giftType = giftType,
        amount = amount,
        message = message or "",
        timestamp = tick(),
        claimed = false
    }
    
    -- Deduct resources from sender
    self:DeductGiftResources(player, giftType, amount)
    
    -- Update sender's stats
    socialData.gifts.sentToday = socialData.gifts.sentToday + 1
    socialData.gifts.totalSent = socialData.gifts.totalSent + 1
    socialData.gifts.giftCooldowns[cooldownKey] = tick()
    
    -- Store gift for recipient
    self:StorePendingGift(friendUserId, giftData)
    
    -- Send cross-server notification
    self:SendCrossServerGiftMessage(giftData)
    
    -- Check for achievements
    self:CheckSocialAchievements(player, "gifts_sent")
    
    print("👥 SocialFeaturesManager:", player.Name, "sent gift to", friendUserId)
    
    return {
        success = true,
        giftId = giftData.id,
        giftsToday = socialData.gifts.sentToday,
        giftsTotal = socialData.gifts.totalSent
    }
end

function SocialFeaturesManager:CanPlayerSendGift(player, giftType, amount)
    if giftType == "coins" then
        local economyManager = _G.EconomyManager
        return economyManager and economyManager:GetPlayerCoins(player) >= amount
        
    elseif giftType == "seeds" then
        local inventoryManager = _G.InventoryManager
        return inventoryManager and inventoryManager:GetItemCount(player, "seeds") >= amount
        
    elseif giftType == "fertilizer" then
        local inventoryManager = _G.InventoryManager
        return inventoryManager and inventoryManager:GetItemCount(player, "fertilizer") >= amount
        
    elseif giftType == "decorations" then
        local inventoryManager = _G.InventoryManager
        return inventoryManager and inventoryManager:GetItemCount(player, "decorations") >= amount
        
    elseif giftType == "vip_exclusive" then
        -- VIP gift boxes are generated, not taken from inventory
        return true
    end
    
    return false
end

function SocialFeaturesManager:DeductGiftResources(player, giftType, amount)
    if giftType == "coins" then
        local economyManager = _G.EconomyManager
        if economyManager then
            economyManager:RemoveCoins(player, amount, "gift_sent")
        end
        
    elseif giftType == "seeds" then
        local inventoryManager = _G.InventoryManager
        if inventoryManager then
            inventoryManager:RemoveItem(player, "seeds", amount)
        end
        
    elseif giftType == "fertilizer" then
        local inventoryManager = _G.InventoryManager
        if inventoryManager then
            inventoryManager:RemoveItem(player, "fertilizer", amount)
        end
        
    elseif giftType == "decorations" then
        local inventoryManager = _G.InventoryManager
        if inventoryManager then
            inventoryManager:RemoveItem(player, "decorations", amount)
        end
    end
end

function SocialFeaturesManager:StorePendingGift(recipientUserId, giftData)
    if not self.PendingGifts[recipientUserId] then
        self.PendingGifts[recipientUserId] = {}
    end
    
    table.insert(self.PendingGifts[recipientUserId], giftData)
    
    -- Save to DataStore
    local success, errorMessage = pcall(function()
        self.GiftDataStore:SetAsync("pending_" .. recipientUserId, self.PendingGifts[recipientUserId])
    end)
    
    if not success then
        warn("⚠️ SocialFeaturesManager: Failed to save pending gift -", errorMessage)
    end
end

function SocialFeaturesManager:SendCrossServerGiftMessage(giftData)
    local messageData = {
        type = "gift_sent",
        giftData = giftData
    }
    
    local success, errorMessage = pcall(function()
        MessagingService:PublishAsync("GiftSent", messageData)
    end)
    
    if not success then
        warn("⚠️ SocialFeaturesManager: Failed to send cross-server gift message -", errorMessage)
    end
end

function SocialFeaturesManager:GetPendingGifts(player)
    local userId = player.UserId
    return self.PendingGifts[userId] or {}
end

function SocialFeaturesManager:ClaimGift(player, giftId)
    local userId = player.UserId
    local pendingGifts = self.PendingGifts[userId]
    
    if not pendingGifts then
        return {success = false, error = "No pending gifts"}
    end
    
    -- Find the gift
    local giftIndex = nil
    local gift = nil
    
    for i, pendingGift in ipairs(pendingGifts) do
        if pendingGift.id == giftId then
            giftIndex = i
            gift = pendingGift
            break
        end
    end
    
    if not gift then
        return {success = false, error = "Gift not found"}
    end
    
    if gift.claimed then
        return {success = false, error = "Gift already claimed"}
    end
    
    -- Give gift to player
    self:GiveGiftToPlayer(player, gift)
    
    -- Mark as claimed and remove from pending
    table.remove(pendingGifts, giftIndex)
    
    -- Update recipient stats
    local socialData = self.PlayerSocialData[userId]
    if socialData then
        socialData.gifts.receivedToday = socialData.gifts.receivedToday + 1
        socialData.gifts.totalReceived = socialData.gifts.totalReceived + 1
    end
    
    -- Save updated pending gifts
    local success, errorMessage = pcall(function()
        self.GiftDataStore:SetAsync("pending_" .. userId, pendingGifts)
    end)
    
    if not success then
        warn("⚠️ SocialFeaturesManager: Failed to save updated pending gifts -", errorMessage)
    end
    
    -- Check for achievements
    self:CheckSocialAchievements(player, "gifts_received")
    
    print("👥 SocialFeaturesManager:", player.Name, "claimed gift", giftId)
    
    return {
        success = true,
        gift = gift,
        totalReceived = socialData and socialData.gifts.totalReceived or 1
    }
end

function SocialFeaturesManager:GiveGiftToPlayer(player, gift)
    local giftType = gift.giftType
    local amount = gift.amount
    
    if giftType == "coins" then
        local economyManager = _G.EconomyManager
        if economyManager then
            economyManager:AddCoins(player, amount, "gift_received")
        end
        
    elseif giftType == "seeds" then
        local inventoryManager = _G.InventoryManager
        if inventoryManager then
            inventoryManager:AddItem(player, "seeds", amount)
        end
        
    elseif giftType == "fertilizer" then
        local inventoryManager = _G.InventoryManager
        if inventoryManager then
            inventoryManager:AddItem(player, "fertilizer", amount)
        end
        
    elseif giftType == "decorations" then
        local inventoryManager = _G.InventoryManager
        if inventoryManager then
            inventoryManager:AddItem(player, "decorations", amount)
        end
        
    elseif giftType == "vip_exclusive" then
        -- Give VIP exclusive items
        self:GiveVIPGiftBox(player, amount)
    end
    
    -- Show notification
    local notificationManager = _G.NotificationManager
    if notificationManager then
        local giftConfig = self.GiftTypes[giftType]
        notificationManager:ShowToast(
            "Gift Received! 🎁",
            "From " .. gift.senderName .. ": " .. amount .. " " .. giftConfig.name,
            giftConfig.icon,
            "social"
        )
    end
end

function SocialFeaturesManager:GiveVIPGiftBox(player, amount)
    local inventoryManager = _G.InventoryManager
    if inventoryManager then
        -- Give random VIP exclusive items
        for i = 1, amount do
            local randomItems = {
                {type = "coins", amount = math.random(1000, 5000)},
                {type = "rare_seeds", amount = math.random(1, 3)},
                {type = "premium_fertilizer", amount = math.random(1, 2)},
                {type = "exclusive_decoration", amount = 1}
            }
            
            local randomItem = randomItems[math.random(1, #randomItems)]
            inventoryManager:AddItem(player, randomItem.type, randomItem.amount)
        end
    end
end

-- ==========================================
-- FRIEND SYSTEM INTEGRATION
-- ==========================================

function SocialFeaturesManager:GetFriendsForSocial(player)
    local friends = {}
    
    -- Get Roblox friends list
    local success, friendsList = pcall(function()
        return player:GetFriendsOnline(50)  -- Get up to 50 online friends
    end)
    
    if success and friendsList then
        for _, friend in ipairs(friendsList) do
            table.insert(friends, {
                userId = friend.Id,
                username = friend.Username,
                displayName = friend.DisplayName,
                isOnline = friend.IsOnline,
                lastLocation = friend.LastLocation
            })
        end
    end
    
    return friends
end

-- ==========================================
-- GARDEN SHARING SYSTEM
-- ==========================================

function SocialFeaturesManager:ShareGarden(player, screenshotData)
    local userId = player.UserId
    local socialData = self.PlayerSocialData[userId]
    
    if not socialData then
        return {success = false, error = "Social data not loaded"}
    end
    
    -- Check daily screenshot limits
    local today = os.date("%Y-%m-%d")
    if socialData.garden.lastSharedDate ~= today then
        socialData.garden.screenshots = 0
        socialData.garden.lastSharedDate = today
    end
    
    local maxScreenshots = socialData.vipStatus and self.Features.gardenSharing.vipMaxScreenshots or self.Features.gardenSharing.maxScreenshots
    if socialData.garden.screenshots >= maxScreenshots then
        return {success = false, error = "Daily screenshot limit reached"}
    end
    
    -- Update stats
    socialData.garden.screenshots = socialData.garden.screenshots + 1
    socialData.garden.popularityRating = socialData.garden.popularityRating + 1
    
    -- Give share reward
    local shareReward = self.Features.gardenSharing.shareReward
    if socialData.vipStatus then
        shareReward = shareReward * 2
    end
    
    local economyManager = _G.EconomyManager
    if economyManager then
        economyManager:AddCoins(player, shareReward, "garden_share")
    end
    
    print("👥 SocialFeaturesManager:", player.Name, "shared garden screenshot")
    
    return {
        success = true,
        reward = shareReward,
        sharesToday = socialData.garden.screenshots,
        popularityRating = socialData.garden.popularityRating
    }
end

-- ==========================================
-- SOCIAL ACHIEVEMENTS
-- ==========================================

function SocialFeaturesManager:CheckSocialAchievements(player, achievementType)
    local userId = player.UserId
    local socialData = self.PlayerSocialData[userId]
    
    if not socialData then return end
    
    local achievementSystem = _G.AchievementSystem
    if not achievementSystem then return end
    
    if achievementType == "friend_visits" then
        local total = socialData.friendVisits.total
        for _, milestone in ipairs(self.Features.socialAchievements.friendVisitMilestones) do
            if total >= milestone and not socialData.achievements.socialMilestones["visits_" .. milestone] then
                socialData.achievements.socialMilestones["visits_" .. milestone] = true
                achievementSystem:UnlockAchievement(player, "friend_visits_" .. milestone)
            end
        end
        
    elseif achievementType == "gifts_sent" then
        local total = socialData.gifts.totalSent
        for _, milestone in ipairs(self.Features.socialAchievements.giftMilestones) do
            if total >= milestone and not socialData.achievements.socialMilestones["gifts_" .. milestone] then
                socialData.achievements.socialMilestones["gifts_" .. milestone] = true
                achievementSystem:UnlockAchievement(player, "gifts_sent_" .. milestone)
            end
        end
        
    elseif achievementType == "popularity" then
        local total = socialData.garden.totalVisitors
        for _, milestone in ipairs(self.Features.socialAchievements.popularityMilestones) do
            if total >= milestone and not socialData.achievements.socialMilestones["popularity_" .. milestone] then
                socialData.achievements.socialMilestones["popularity_" .. milestone] = true
                achievementSystem:UnlockAchievement(player, "garden_popularity_" .. milestone)
            end
        end
    end
end

-- ==========================================
-- STATISTICS & ANALYTICS
-- ==========================================

function SocialFeaturesManager:GetPlayerSocialStats(player)
    local userId = player.UserId
    local socialData = self.PlayerSocialData[userId]
    
    if not socialData then
        return {
            friendVisits = {today = 0, total = 0},
            gifts = {sentToday = 0, receivedToday = 0, totalSent = 0, totalReceived = 0},
            garden = {totalVisitors = 0, popularityRating = 0},
            friendshipLevel = 1
        }
    end
    
    return {
        friendVisits = socialData.friendVisits,
        gifts = socialData.gifts,
        garden = socialData.garden,
        friendshipLevel = socialData.achievements.friendshipLevel,
        vipStatus = socialData.vipStatus
    }
end

function SocialFeaturesManager:UpdatePlayerSocialStats(player)
    local userId = player.UserId
    local socialData = self.PlayerSocialData[userId]
    
    if not socialData then return end
    
    -- Calculate friendship level based on total social activity
    local totalActivity = socialData.friendVisits.total + socialData.gifts.totalSent + socialData.gifts.totalReceived + socialData.garden.totalVisitors
    local friendshipLevel = math.floor(totalActivity / 50) + 1
    
    socialData.achievements.friendshipLevel = math.min(friendshipLevel, 10) -- Max level 10
end

function SocialFeaturesManager:UpdateSocialStatistics()
    -- Update global social statistics
    local totalPlayers = 0
    local totalVisits = 0
    local totalGifts = 0
    local vipPlayers = 0
    
    for userId, socialData in pairs(self.PlayerSocialData) do
        totalPlayers = totalPlayers + 1
        totalVisits = totalVisits + socialData.friendVisits.total
        totalGifts = totalGifts + socialData.gifts.totalSent
        
        if socialData.vipStatus then
            vipPlayers = vipPlayers + 1
        end
    end
    
    self.SocialStats = {
        totalPlayers = totalPlayers,
        totalVisits = totalVisits,
        totalGifts = totalGifts,
        vipPlayers = vipPlayers,
        lastUpdate = tick()
    }
end

-- ==========================================
-- CROSS-SERVER HANDLING
-- ==========================================

function SocialFeaturesManager:HandleCrossServerSocialUpdate(data)
    if data.type == "friend_visit" then
        local friendPlayer = Players:GetPlayerByUserId(data.friendUserId)
        if friendPlayer then
            self:RecordFriendVisit(friendPlayer, data.visitorUserId)
        end
    end
end

function SocialFeaturesManager:HandleCrossServerGift(data)
    if data.type == "gift_sent" then
        local recipientPlayer = Players:GetPlayerByUserId(data.giftData.recipientUserId)
        if recipientPlayer then
            self:NotifyPlayerOfPendingGifts(recipientPlayer, 1)
        end
    end
end

function SocialFeaturesManager:NotifyPlayerOfPendingGifts(player, giftCount)
    if self.GiftReceivedEvent then
        self.GiftReceivedEvent:FireClient(player, giftCount)
    end
    
    local notificationManager = _G.NotificationManager
    if notificationManager then
        notificationManager:ShowToast(
            "New Gift! 🎁",
            "You have " .. giftCount .. " pending gift" .. (giftCount > 1 and "s" or ""),
            "🎁",
            "social"
        )
    end
end

-- ==========================================
-- CLEANUP & MAINTENANCE
-- ==========================================

function SocialFeaturesManager:CleanupExpiredData()
    local currentTime = tick()
    local oneDayAgo = currentTime - (24 * 3600)
    
    -- Clean up old pending gifts (older than 30 days)
    local thirtyDaysAgo = currentTime - (30 * 24 * 3600)
    
    for userId, gifts in pairs(self.PendingGifts) do
        local validGifts = {}
        for _, gift in ipairs(gifts) do
            if gift.timestamp > thirtyDaysAgo then
                table.insert(validGifts, gift)
            end
        end
        self.PendingGifts[userId] = validGifts
    end
    
    print("👥 SocialFeaturesManager: Cleaned up expired data")
end

-- ==========================================
-- PUBLIC API
-- ==========================================

function SocialFeaturesManager:GetGlobalSocialStats()
    return self.SocialStats
end

function SocialFeaturesManager:IsFeatureEnabled(featureName)
    return self.Features[featureName] and self.Features[featureName].enabled
end

function SocialFeaturesManager:GetGiftTypes()
    return self.GiftTypes
end

-- ==========================================
-- CLEANUP
-- ==========================================

function SocialFeaturesManager:Cleanup()
    -- Save all player data
    for _, player in pairs(Players:GetPlayers()) do
        self:SavePlayerSocialData(player)
    end
    
    print("👥 SocialFeaturesManager: Cleaned up and saved all data")
end

-- ==========================================
-- GLOBAL REGISTRATION
-- ==========================================

_G.SocialFeaturesManager = SocialFeaturesManager

return SocialFeaturesManager
