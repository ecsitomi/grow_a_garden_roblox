--[[
    SocialManager.lua
    Server-Side Social Features and Friend System
    
    Priority: 32 (Advanced Features phase)
    Dependencies: DataStoreService, MessagingService, ReplicatedStorage
    Used by: NotificationManager, VIPManager, GuildManager
    
    Features:
    - Friend system and friend requests
    - Garden visiting and tours
    - Social interactions and gifts
    - Player profiles and achievements showcase
    - Social competitions and challenges
    - Community features and social hubs
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

-- Load required modules
local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)

local SocialManager = {}
SocialManager.__index = SocialManager

-- ==========================================
-- INITIALIZATION & SETUP
-- ==========================================

-- Data stores
SocialManager.FriendStore = DataStoreService:GetDataStore("FriendData_v1")
SocialManager.VisitStore = DataStoreService:GetDataStore("VisitData_v1")
SocialManager.ProfileStore = DataStoreService:GetDataStore("ProfileData_v1")

-- Social state tracking
SocialManager.PlayerFriends = {} -- [userId] = {friends = {}, requests = {}}
SocialManager.PlayerProfiles = {} -- [userId] = profileData
SocialManager.ActiveVisits = {} -- [visitId] = visitData
SocialManager.SocialHubs = {} -- [hubId] = hubData

-- Social settings
SocialManager.SocialSettings = {
    maxFriends = 100,
    vipMaxFriends = 200,
    maxFriendRequests = 20,
    requestExpiration = 7 * 24 * 3600, -- 7 days
    maxVisitorsPerGarden = 10,
    visitDuration = 30 * 60, -- 30 minutes
    dailyGiftLimit = 10,
    vipDailyGiftLimit = 25
}

-- Friend request status
SocialManager.RequestStatus = {
    PENDING = "pending",
    ACCEPTED = "accepted",
    DECLINED = "declined",
    EXPIRED = "expired"
}

-- Visit types
SocialManager.VisitTypes = {
    FRIEND_VISIT = {
        name = "Friend Visit",
        duration = 30 * 60, -- 30 minutes
        permissions = {"view_garden", "water_plants", "admire_decorations"},
        rewards = {visitor = {xp = 100}, host = {xp = 50}}
    },
    
    GARDEN_TOUR = {
        name = "Garden Tour",
        duration = 15 * 60, -- 15 minutes
        permissions = {"view_garden", "admire_decorations"},
        rewards = {visitor = {xp = 50}, host = {xp = 25}}
    },
    
    HELP_VISIT = {
        name = "Help Visit",
        duration = 60 * 60, -- 1 hour
        permissions = {"view_garden", "water_plants", "harvest_crops", "tend_garden"},
        rewards = {visitor = {xp = 200, coins = 500}, host = {xp = 100, coins = 250}}
    },
    
    VIP_EXCLUSIVE = {
        name = "VIP Garden Party",
        duration = 90 * 60, -- 1.5 hours
        permissions = {"view_garden", "water_plants", "admire_decorations", "special_interactions"},
        rewards = {visitor = {xp = 300, coins = 1000}, host = {xp = 150, coins = 500}},
        vipOnly = true
    }
}

-- Gift types
SocialManager.GiftTypes = {
    daily_water = {
        name = "Daily Water",
        description = "Refreshing water for your plants",
        icon = "💧",
        value = {water = 10},
        cost = 0,
        dailyLimit = 5
    },
    
    seed_pack = {
        name = "Seed Pack",
        description = "A small pack of common seeds",
        icon = "🌱",
        value = {seeds = {"carrot", "lettuce", "tomato"}},
        cost = 100,
        dailyLimit = 3
    },
    
    fertilizer = {
        name = "Organic Fertilizer",
        description = "Boost your plant growth",
        icon = "🌿",
        value = {fertilizer = 5},
        cost = 200,
        dailyLimit = 2
    },
    
    rare_seed = {
        name = "Rare Seed",
        description = "A mysterious rare seed",
        icon = "🌟",
        value = {rare_seed = 1},
        cost = 500,
        dailyLimit = 1,
        vipOnly = false
    },
    
    vip_gift_box = {
        name = "VIP Gift Box",
        description = "Exclusive VIP gift with premium items",
        icon = "🎁",
        value = {coins = 1000, diamonds = 10, rare_seeds = 3},
        cost = 1000,
        dailyLimit = 1,
        vipOnly = true
    }
}

-- Social hub types
SocialManager.HubTypes = {
    COMMUNITY_GARDEN = {
        name = "Community Garden",
        description = "A shared space for all players",
        maxCapacity = 50,
        features = {"shared_plots", "community_projects", "social_chat"}
    },
    
    FARMERS_MARKET = {
        name = "Farmers Market",
        description = "Trade and showcase your best crops",
        maxCapacity = 30,
        features = {"trading_posts", "crop_showcase", "price_board"}
    },
    
    SOCIAL_PLAZA = {
        name = "Social Plaza",
        description = "Meet and interact with other gardeners",
        maxCapacity = 40,
        features = {"meeting_areas", "event_board", "friend_finder"}
    }
}

-- Player profile structure
SocialManager.ProfileTemplate = {
    displayName = "",
    title = "",
    level = 1,
    gardenTheme = "classic",
    favoritesCrop = "",
    gardenDescription = "",
    achievements = {},
    stats = {
        totalHarvests = 0,
        plantsGrown = 0,
        friendsHelped = 0,
        gardenVisits = 0
    },
    showcase = {
        featuredPlants = {},
        featuredDecorations = {},
        gardenPhotos = {}
    },
    privacy = {
        allowVisits = true,
        allowFriendRequests = true,
        showAchievements = true,
        showStats = true
    }
}

-- ==========================================
-- INITIALIZATION
-- ==========================================

function SocialManager:Initialize()
    print("👥 SocialManager: Initializing social system...")
    
    -- Set up remote events
    self:SetupRemoteEvents()
    
    -- Set up player connections
    self:SetupPlayerConnections()
    
    -- Load social data
    self:LoadSocialData()
    
    -- Initialize social hubs
    self:InitializeSocialHubs()
    
    -- Start social updates
    self:StartSocialUpdates()
    
    -- Set up cross-server messaging
    self:SetupCrossServerMessaging()
    
    print("✅ SocialManager: Social system initialized")
end

function SocialManager:SetupRemoteEvents()
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then
        remoteEvents = Instance.new("Folder")
        remoteEvents.Name = "RemoteEvents"
        remoteEvents.Parent = ReplicatedStorage
    end
    
    -- Friend system
    local sendFriendRequestFunction = Instance.new("RemoteFunction")
    sendFriendRequestFunction.Name = "SendFriendRequest"
    sendFriendRequestFunction.Parent = remoteEvents
    sendFriendRequestFunction.OnServerInvoke = function(player, targetPlayerName)
        return self:SendFriendRequest(player, targetPlayerName)
    end
    
    local respondFriendRequestFunction = Instance.new("RemoteFunction")
    respondFriendRequestFunction.Name = "RespondFriendRequest"
    respondFriendRequestFunction.Parent = remoteEvents
    respondFriendRequestFunction.OnServerInvoke = function(player, requestId, response)
        return self:RespondFriendRequest(player, requestId, response)
    end
    
    local removeFriendFunction = Instance.new("RemoteFunction")
    removeFriendFunction.Name = "RemoveFriend"
    removeFriendFunction.Parent = remoteEvents
    removeFriendFunction.OnServerInvoke = function(player, friendUserId)
        return self:RemoveFriend(player, friendUserId)
    end
    
    -- Garden visiting
    local visitGardenFunction = Instance.new("RemoteFunction")
    visitGardenFunction.Name = "VisitGarden"
    visitGardenFunction.Parent = remoteEvents
    visitGardenFunction.OnServerInvoke = function(player, targetUserId, visitType)
        return self:VisitGarden(player, targetUserId, visitType)
    end
    
    local endVisitFunction = Instance.new("RemoteFunction")
    endVisitFunction.Name = "EndVisit"
    endVisitFunction.Parent = remoteEvents
    endVisitFunction.OnServerInvoke = function(player)
        return self:EndVisit(player)
    end
    
    -- Gift system
    local sendGiftFunction = Instance.new("RemoteFunction")
    sendGiftFunction.Name = "SendGift"
    sendGiftFunction.Parent = remoteEvents
    sendGiftFunction.OnServerInvoke = function(player, targetUserId, giftType)
        return self:SendGift(player, targetUserId, giftType)
    end
    
    -- Profile management
    local updateProfileFunction = Instance.new("RemoteFunction")
    updateProfileFunction.Name = "UpdateProfile"
    updateProfileFunction.Parent = remoteEvents
    updateProfileFunction.OnServerInvoke = function(player, profileData)
        return self:UpdateProfile(player, profileData)
    end
    
    local getProfileFunction = Instance.new("RemoteFunction")
    getProfileFunction.Name = "GetProfile"
    getProfileFunction.Parent = remoteEvents
    getProfileFunction.OnServerInvoke = function(player, targetUserId)
        return self:GetProfile(player, targetUserId)
    end
    
    -- Social hub
    local joinHubFunction = Instance.new("RemoteFunction")
    joinHubFunction.Name = "JoinSocialHub"
    joinHubFunction.Parent = remoteEvents
    joinHubFunction.OnServerInvoke = function(player, hubType)
        return self:JoinSocialHub(player, hubType)
    end
end

function SocialManager:SetupPlayerConnections()
    -- Player joined
    Players.PlayerAdded:Connect(function(player)
        self:OnPlayerJoined(player)
    end)
    
    -- Player leaving
    Players.PlayerRemoving:Connect(function(player)
        self:OnPlayerLeaving(player)
    end)
    
    -- Handle existing players
    for _, player in pairs(Players:GetPlayers()) do
        self:OnPlayerJoined(player)
    end
end

function SocialManager:LoadSocialData()
    -- This would load global social data
    -- For now, individual player data is loaded when they join
end

function SocialManager:InitializeSocialHubs()
    -- Create social hubs
    for hubType, hubData in pairs(self.HubTypes) do
        local hubId = HttpService:GenerateGUID()
        self.SocialHubs[hubId] = {
            id = hubId,
            type = hubType,
            name = hubData.name,
            description = hubData.description,
            maxCapacity = hubData.maxCapacity,
            features = hubData.features,
            currentPlayers = {},
            created = tick()
        }
    end
    
    print("👥 SocialManager: Created", #self.SocialHubs, "social hubs")
end

function SocialManager:StartSocialUpdates()
    spawn(function()
        while true do
            self:UpdateActiveVisits()
            self:CleanupExpiredRequests()
            self:UpdateSocialHubs()
            wait(60) -- Update every minute
        end
    end)
end

function SocialManager:SetupCrossServerMessaging()
    -- Subscribe to social messages
    MessagingService:SubscribeAsync("SocialUpdates", function(message)
        self:HandleSocialMessage(message.Data)
    end)
end

-- ==========================================
-- PLAYER MANAGEMENT
-- ==========================================

function SocialManager:OnPlayerJoined(player)
    -- Initialize player social data
    self.PlayerFriends[player.UserId] = {
        friends = {},
        sentRequests = {},
        receivedRequests = {},
        dailyGifts = {sent = 0, received = 0, lastReset = tick()}
    }
    
    -- Load player social data
    spawn(function()
        self:LoadPlayerSocialData(player)
        self:LoadPlayerProfile(player)
    end)
    
    -- Notify friends that player is online
    self:NotifyFriendsOnlineStatus(player, true)
    
    print("👥 SocialManager: Player", player.Name, "joined social system")
end

function SocialManager:OnPlayerLeaving(player)
    -- Save player social data
    spawn(function()
        self:SavePlayerSocialData(player)
        self:SavePlayerProfile(player)
    end)
    
    -- End any active visits
    self:EndVisit(player)
    
    -- Notify friends that player is offline
    self:NotifyFriendsOnlineStatus(player, false)
    
    -- Clean up
    self.PlayerFriends[player.UserId] = nil
    self.PlayerProfiles[player.UserId] = nil
    
    print("👥 SocialManager: Player", player.Name, "left social system")
end

function SocialManager:LoadPlayerSocialData(player)
    local success, socialData = pcall(function()
        return self.FriendStore:GetAsync("player_" .. player.UserId)
    end)
    
    if success and socialData then
        self.PlayerFriends[player.UserId] = socialData
        
        -- Reset daily gifts if needed
        local dailyData = socialData.dailyGifts
        if dailyData and tick() - dailyData.lastReset > 24 * 3600 then
            dailyData.sent = 0
            dailyData.received = 0
            dailyData.lastReset = tick()
        end
        
        print("👥 SocialManager: Loaded social data for", player.Name)
    else
        print("👥 SocialManager: New social data for", player.Name)
    end
end

function SocialManager:SavePlayerSocialData(player)
    local socialData = self.PlayerFriends[player.UserId]
    if not socialData then return end
    
    local success, error = pcall(function()
        self.FriendStore:SetAsync("player_" .. player.UserId, socialData)
    end)
    
    if not success then
        warn("❌ SocialManager: Failed to save social data for", player.Name, ":", error)
    end
end

function SocialManager:LoadPlayerProfile(player)
    local success, profileData = pcall(function()
        return self.ProfileStore:GetAsync("profile_" .. player.UserId)
    end)
    
    if success and profileData then
        self.PlayerProfiles[player.UserId] = profileData
    else
        -- Create default profile
        self.PlayerProfiles[player.UserId] = self:CreateDefaultProfile(player)
    end
end

function SocialManager:SavePlayerProfile(player)
    local profileData = self.PlayerProfiles[player.UserId]
    if not profileData then return end
    
    local success, error = pcall(function()
        self.ProfileStore:SetAsync("profile_" .. player.UserId, profileData)
    end)
    
    if not success then
        warn("❌ SocialManager: Failed to save profile for", player.Name, ":", error)
    end
end

function SocialManager:CreateDefaultProfile(player)
    local profile = {}
    for key, value in pairs(self.ProfileTemplate) do
        if type(value) == "table" then
            profile[key] = {}
            for subKey, subValue in pairs(value) do
                profile[key][subKey] = subValue
            end
        else
            profile[key] = value
        end
    end
    
    profile.displayName = player.Name
    profile.level = 1
    
    return profile
end

-- ==========================================
-- FRIEND SYSTEM
-- ==========================================

function SocialManager:SendFriendRequest(player, targetPlayerName)
    local targetPlayer = self:FindPlayerByName(targetPlayerName)
    if not targetPlayer then
        return {success = false, message = "Player not found"}
    end
    
    if targetPlayer.UserId == player.UserId then
        return {success = false, message = "Cannot send friend request to yourself"}
    end
    
    local playerData = self.PlayerFriends[player.UserId]
    local targetData = self.PlayerFriends[targetPlayer.UserId]
    
    if not playerData or not targetData then
        return {success = false, message = "Social data not loaded"}
    end
    
    -- Check if already friends
    if playerData.friends[targetPlayer.UserId] then
        return {success = false, message = "Already friends with this player"}
    end
    
    -- Check friend limits
    local maxFriends = self:IsPlayerVIP(player) and 
        self.SocialSettings.vipMaxFriends or 
        self.SocialSettings.maxFriends
    
    if #playerData.friends >= maxFriends then
        return {success = false, message = "Friend list is full"}
    end
    
    -- Check if request already exists
    for _, request in pairs(playerData.sentRequests) do
        if request.targetUserId == targetPlayer.UserId and request.status == self.RequestStatus.PENDING then
            return {success = false, message = "Friend request already sent"}
        end
    end
    
    -- Check target's privacy settings
    local targetProfile = self.PlayerProfiles[targetPlayer.UserId]
    if targetProfile and not targetProfile.privacy.allowFriendRequests then
        return {success = false, message = "Player is not accepting friend requests"}
    end
    
    -- Create friend request
    local requestId = HttpService:GenerateGUID()
    local friendRequest = {
        id = requestId,
        senderUserId = player.UserId,
        senderName = player.Name,
        targetUserId = targetPlayer.UserId,
        targetName = targetPlayer.Name,
        status = self.RequestStatus.PENDING,
        sentTime = tick(),
        expiration = tick() + self.SocialSettings.requestExpiration
    }
    
    -- Add to sender's sent requests
    playerData.sentRequests[requestId] = friendRequest
    
    -- Add to target's received requests
    targetData.receivedRequests[requestId] = friendRequest
    
    -- Notify target player
    local notificationManager = _G.NotificationManager
    if notificationManager then
        notificationManager:ShowToast(
            "Friend Request! 👋",
            player.Name .. " sent you a friend request",
            "👥",
            "friend_request"
        )
    end
    
    return {success = true, message = "Friend request sent successfully"}
end

function SocialManager:RespondFriendRequest(player, requestId, response)
    local playerData = self.PlayerFriends[player.UserId]
    if not playerData then
        return {success = false, message = "Social data not loaded"}
    end
    
    local request = playerData.receivedRequests[requestId]
    if not request then
        return {success = false, message = "Friend request not found"}
    end
    
    if request.status ~= self.RequestStatus.PENDING then
        return {success = false, message = "Friend request already responded to"}
    end
    
    local senderData = self.PlayerFriends[request.senderUserId]
    if not senderData then
        return {success = false, message = "Sender data not found"}
    end
    
    if response == "accept" then
        -- Add to friends lists
        playerData.friends[request.senderUserId] = {
            userId = request.senderUserId,
            playerName = request.senderName,
            friendSince = tick(),
            lastInteraction = tick()
        }
        
        senderData.friends[player.UserId] = {
            userId = player.UserId,
            playerName = player.Name,
            friendSince = tick(),
            lastInteraction = tick()
        }
        
        request.status = self.RequestStatus.ACCEPTED
        
        -- Notify sender
        local senderPlayer = Players:GetPlayerByUserId(request.senderUserId)
        if senderPlayer then
            local notificationManager = _G.NotificationManager
            if notificationManager then
                notificationManager:ShowToast(
                    "Friend Request Accepted! 🎉",
                    player.Name .. " is now your friend",
                    "👥",
                    "friend_accepted"
                )
            end
        end
        
    elseif response == "decline" then
        request.status = self.RequestStatus.DECLINED
    else
        return {success = false, message = "Invalid response"}
    end
    
    -- Update request in sender's data
    if senderData.sentRequests[requestId] then
        senderData.sentRequests[requestId].status = request.status
    end
    
    return {success = true, message = "Response sent successfully"}
end

function SocialManager:RemoveFriend(player, friendUserId)
    local playerData = self.PlayerFriends[player.UserId]
    if not playerData then
        return {success = false, message = "Social data not loaded"}
    end
    
    if not playerData.friends[friendUserId] then
        return {success = false, message = "Player is not your friend"}
    end
    
    -- Remove from both friends lists
    playerData.friends[friendUserId] = nil
    
    local friendData = self.PlayerFriends[friendUserId]
    if friendData then
        friendData.friends[player.UserId] = nil
    end
    
    -- Notify friend if online
    local friendPlayer = Players:GetPlayerByUserId(friendUserId)
    if friendPlayer then
        local notificationManager = _G.NotificationManager
        if notificationManager then
            notificationManager:ShowToast(
                "Friend Removed",
                player.Name .. " removed you from their friends list",
                "💔",
                "friend_removed"
            )
        end
    end
    
    return {success = true, message = "Friend removed successfully"}
end

-- ==========================================
-- GARDEN VISITING
-- ==========================================

function SocialManager:VisitGarden(player, targetUserId, visitType)
    -- Check if target player exists
    local targetPlayer = Players:GetPlayerByUserId(targetUserId)
    if not targetPlayer then
        return {success = false, message = "Target player not found online"}
    end
    
    -- Check if visit type is valid
    local visitTemplate = self.VisitTypes[visitType]
    if not visitTemplate then
        return {success = false, message = "Invalid visit type"}
    end
    
    -- Check VIP requirements
    if visitTemplate.vipOnly and not self:IsPlayerVIP(player) then
        return {success = false, message = "VIP membership required for this visit type"}
    end
    
    -- Check if player is already visiting
    for _, visit in pairs(self.ActiveVisits) do
        if visit.visitorUserId == player.UserId then
            return {success = false, message = "You are already visiting a garden"}
        end
    end
    
    -- Check target's privacy settings
    local targetProfile = self.PlayerProfiles[targetUserId]
    if targetProfile and not targetProfile.privacy.allowVisits then
        return {success = false, message = "Player is not allowing garden visits"}
    end
    
    -- Check friendship requirement (except for tours)
    if visitType ~= "GARDEN_TOUR" then
        local playerData = self.PlayerFriends[player.UserId]
        if not playerData or not playerData.friends[targetUserId] then
            return {success = false, message = "You need to be friends to visit this garden"}
        end
    end
    
    -- Check garden visitor limit
    local currentVisitors = 0
    for _, visit in pairs(self.ActiveVisits) do
        if visit.hostUserId == targetUserId then
            currentVisitors = currentVisitors + 1
        end
    end
    
    if currentVisitors >= self.SocialSettings.maxVisitorsPerGarden then
        return {success = false, message = "Garden is at visitor capacity"}
    end
    
    -- Create visit
    local visitId = HttpService:GenerateGUID()
    local visit = {
        id = visitId,
        type = visitType,
        visitorUserId = player.UserId,
        visitorName = player.Name,
        hostUserId = targetUserId,
        hostName = targetPlayer.Name,
        startTime = tick(),
        endTime = tick() + visitTemplate.duration,
        permissions = visitTemplate.permissions,
        rewards = visitTemplate.rewards,
        status = "active"
    }
    
    self.ActiveVisits[visitId] = visit
    
    -- Notify host
    local notificationManager = _G.NotificationManager
    if notificationManager then
        notificationManager:ShowToast(
            "Garden Visitor! 🏡",
            player.Name .. " is visiting your garden",
            "👋",
            "garden_visit"
        )
    end
    
    -- Teleport visitor to host's garden (placeholder)
    -- In a real implementation, this would use TeleportService or move player to host's plot
    
    return {success = true, message = "Visit started successfully", visitId = visitId}
end

function SocialManager:EndVisit(player)
    -- Find active visit for player
    local activeVisit = nil
    for visitId, visit in pairs(self.ActiveVisits) do
        if visit.visitorUserId == player.UserId and visit.status == "active" then
            activeVisit = visit
            break
        end
    end
    
    if not activeVisit then
        return {success = false, message = "No active visit found"}
    end
    
    -- End visit
    activeVisit.status = "ended"
    activeVisit.actualEndTime = tick()
    
    -- Calculate visit duration
    local visitDuration = tick() - activeVisit.startTime
    local fullDuration = activeVisit.endTime - activeVisit.startTime
    local completionRatio = math.min(visitDuration / fullDuration, 1)
    
    -- Give rewards based on completion
    if completionRatio > 0.5 then -- Must stay at least half the time
        self:GiveVisitRewards(player, activeVisit.rewards.visitor, completionRatio)
        
        -- Give host rewards if they're online
        local hostPlayer = Players:GetPlayerByUserId(activeVisit.hostUserId)
        if hostPlayer then
            self:GiveVisitRewards(hostPlayer, activeVisit.rewards.host, completionRatio)
        end
    end
    
    -- Update social stats
    self:UpdateSocialStats(player.UserId, "gardenVisits", 1)
    
    -- Remove from active visits
    self.ActiveVisits[activeVisit.id] = nil
    
    return {success = true, message = "Visit ended successfully"}
end

function SocialManager:GiveVisitRewards(player, rewards, completionRatio)
    local economyManager = _G.EconomyManager
    
    if rewards.xp and economyManager then
        local xpReward = math.floor(rewards.xp * completionRatio)
        economyManager:AddExperience(player, xpReward)
    end
    
    if rewards.coins and economyManager then
        local coinReward = math.floor(rewards.coins * completionRatio)
        economyManager:AddCurrency(player, coinReward)
    end
end

-- ==========================================
-- GIFT SYSTEM
-- ==========================================

function SocialManager:SendGift(player, targetUserId, giftType)
    local giftTemplate = self.GiftTypes[giftType]
    if not giftTemplate then
        return {success = false, message = "Invalid gift type"}
    end
    
    -- Check VIP requirement
    if giftTemplate.vipOnly and not self:IsPlayerVIP(player) then
        return {success = false, message = "VIP membership required for this gift"}
    end
    
    -- Check friendship
    local playerData = self.PlayerFriends[player.UserId]
    if not playerData or not playerData.friends[targetUserId] then
        return {success = false, message = "You can only send gifts to friends"}
    end
    
    -- Check daily limits
    local dailyData = playerData.dailyGifts
    local maxGifts = self:IsPlayerVIP(player) and 
        self.SocialSettings.vipDailyGiftLimit or 
        self.SocialSettings.dailyGiftLimit
    
    if dailyData.sent >= maxGifts then
        return {success = false, message = "Daily gift limit reached"}
    end
    
    -- Check gift-specific daily limit
    if giftTemplate.dailyLimit then
        local giftsSentToday = self:CountGiftsSentToday(player, giftType)
        if giftsSentToday >= giftTemplate.dailyLimit then
            return {success = false, message = "Daily limit for this gift type reached"}
        end
    end
    
    -- Check cost
    if giftTemplate.cost > 0 then
        local economyManager = _G.EconomyManager
        if not economyManager or not economyManager:HasCurrency(player, giftTemplate.cost) then
            return {success = false, message = "Not enough coins to send this gift"}
        end
        economyManager:RemoveCurrency(player, giftTemplate.cost)
    end
    
    -- Send gift
    local gift = {
        id = HttpService:GenerateGUID(),
        type = giftType,
        senderUserId = player.UserId,
        senderName = player.Name,
        targetUserId = targetUserId,
        value = giftTemplate.value,
        sentTime = tick(),
        opened = false
    }
    
    -- Add to gift tracking
    self:TrackGiftSent(player, gift)
    self:DeliverGift(targetUserId, gift)
    
    -- Update daily counter
    dailyData.sent = dailyData.sent + 1
    
    -- Notify target
    local targetPlayer = Players:GetPlayerByUserId(targetUserId)
    if targetPlayer then
        local notificationManager = _G.NotificationManager
        if notificationManager then
            notificationManager:ShowToast(
                "Gift Received! 🎁",
                player.Name .. " sent you " .. giftTemplate.name,
                giftTemplate.icon,
                "gift_received"
            )
        end
    end
    
    return {success = true, message = "Gift sent successfully"}
end

function SocialManager:DeliverGift(targetUserId, gift)
    -- Add gift to player's inventory or apply effect immediately
    local targetPlayer = Players:GetPlayerByUserId(targetUserId)
    if targetPlayer then
        local inventoryManager = _G.InventoryManager
        local economyManager = _G.EconomyManager
        
        -- Apply gift value
        for valueType, amount in pairs(gift.value) do
            if valueType == "coins" and economyManager then
                economyManager:AddCurrency(targetPlayer, amount)
            elseif valueType == "water" then
                -- Add water to player's garden
                self:AddWaterToGarden(targetPlayer, amount)
            elseif valueType == "seeds" then
                if inventoryManager then
                    for _, seedType in ipairs(amount) do
                        inventoryManager:AddItem(targetPlayer, seedType, 1)
                    end
                end
            elseif inventoryManager then
                inventoryManager:AddItem(targetPlayer, valueType, amount)
            end
        end
        
        -- Update social stats
        self:UpdateSocialStats(targetUserId, "giftsReceived", 1)
    end
end

function SocialManager:TrackGiftSent(player, gift)
    -- Track gifts for statistics and daily limits
    local playerData = self.PlayerFriends[player.UserId]
    if not playerData.giftHistory then
        playerData.giftHistory = {}
    end
    
    table.insert(playerData.giftHistory, {
        giftId = gift.id,
        type = gift.type,
        targetUserId = gift.targetUserId,
        sentTime = gift.sentTime
    })
    
    -- Keep only recent history (last 30 days)
    local cutoffTime = tick() - (30 * 24 * 3600)
    for i = #playerData.giftHistory, 1, -1 do
        if playerData.giftHistory[i].sentTime < cutoffTime then
            table.remove(playerData.giftHistory, i)
        end
    end
end

function SocialManager:CountGiftsSentToday(player, giftType)
    local playerData = self.PlayerFriends[player.UserId]
    if not playerData.giftHistory then return 0 end
    
    local todayStart = tick() - (24 * 3600)
    local count = 0
    
    for _, giftRecord in ipairs(playerData.giftHistory) do
        if giftRecord.sentTime >= todayStart and giftRecord.type == giftType then
            count = count + 1
        end
    end
    
    return count
end

-- ==========================================
-- PROFILE SYSTEM
-- ==========================================

function SocialManager:UpdateProfile(player, profileData)
    local currentProfile = self.PlayerProfiles[player.UserId]
    if not currentProfile then
        return {success = false, message = "Profile not found"}
    end
    
    -- Validate and update profile fields
    if profileData.displayName then
        if #profileData.displayName <= 30 then
            currentProfile.displayName = profileData.displayName
        end
    end
    
    if profileData.gardenDescription then
        if #profileData.gardenDescription <= 200 then
            currentProfile.gardenDescription = profileData.gardenDescription
        end
    end
    
    if profileData.gardenTheme then
        currentProfile.gardenTheme = profileData.gardenTheme
    end
    
    if profileData.favoritesCrop then
        currentProfile.favoritesCrop = profileData.favoritesCrop
    end
    
    if profileData.privacy then
        for key, value in pairs(profileData.privacy) do
            if currentProfile.privacy[key] ~= nil then
                currentProfile.privacy[key] = value
            end
        end
    end
    
    return {success = true, message = "Profile updated successfully"}
end

function SocialManager:GetProfile(player, targetUserId)
    local targetProfile = self.PlayerProfiles[targetUserId]
    if not targetProfile then
        return {success = false, message = "Profile not found"}
    end
    
    -- Check privacy settings
    local isFriend = false
    local playerData = self.PlayerFriends[player.UserId]
    if playerData and playerData.friends[targetUserId] then
        isFriend = true
    end
    
    local publicProfile = {
        displayName = targetProfile.displayName,
        title = targetProfile.title,
        level = targetProfile.level,
        gardenTheme = targetProfile.gardenTheme,
        favoritesCrop = targetProfile.favoritesCrop
    }
    
    -- Add more info for friends
    if isFriend then
        publicProfile.gardenDescription = targetProfile.gardenDescription
        
        if targetProfile.privacy.showAchievements then
            publicProfile.achievements = targetProfile.achievements
        end
        
        if targetProfile.privacy.showStats then
            publicProfile.stats = targetProfile.stats
        end
        
        publicProfile.showcase = targetProfile.showcase
    end
    
    return {success = true, profile = publicProfile}
end

-- ==========================================
-- SOCIAL HUBS
-- ==========================================

function SocialManager:JoinSocialHub(player, hubType)
    -- Find available hub of requested type
    local selectedHub = nil
    for hubId, hub in pairs(self.SocialHubs) do
        if hub.type == hubType and #hub.currentPlayers < hub.maxCapacity then
            selectedHub = hub
            break
        end
    end
    
    if not selectedHub then
        return {success = false, message = "No available hubs of this type"}
    end
    
    -- Check if player is already in a hub
    for _, hub in pairs(self.SocialHubs) do
        if hub.currentPlayers[player.UserId] then
            return {success = false, message = "You are already in a social hub"}
        end
    end
    
    -- Add player to hub
    selectedHub.currentPlayers[player.UserId] = {
        userId = player.UserId,
        playerName = player.Name,
        joinTime = tick()
    }
    
    -- Teleport player to hub (placeholder)
    -- In real implementation, this would move player to hub area
    
    return {success = true, message = "Joined " .. selectedHub.name, hubId = selectedHub.id}
end

function SocialManager:LeaveSocialHub(player)
    -- Find and remove player from any hub
    for hubId, hub in pairs(self.SocialHubs) do
        if hub.currentPlayers[player.UserId] then
            hub.currentPlayers[player.UserId] = nil
            return {success = true, message = "Left social hub"}
        end
    end
    
    return {success = false, message = "Not in any social hub"}
end

-- ==========================================
-- SOCIAL UPDATES
-- ==========================================

function SocialManager:UpdateActiveVisits()
    for visitId, visit in pairs(self.ActiveVisits) do
        if visit.status == "active" and tick() >= visit.endTime then
            -- Auto-end expired visits
            visit.status = "expired"
            
            local visitor = Players:GetPlayerByUserId(visit.visitorUserId)
            if visitor then
                self:EndVisit(visitor)
            end
        end
    end
end

function SocialManager:CleanupExpiredRequests()
    for userId, playerData in pairs(self.PlayerFriends) do
        -- Clean up sent requests
        for requestId, request in pairs(playerData.sentRequests) do
            if tick() >= request.expiration and request.status == self.RequestStatus.PENDING then
                request.status = self.RequestStatus.EXPIRED
            end
        end
        
        -- Clean up received requests
        for requestId, request in pairs(playerData.receivedRequests) do
            if tick() >= request.expiration and request.status == self.RequestStatus.PENDING then
                request.status = self.RequestStatus.EXPIRED
            end
        end
    end
end

function SocialManager:UpdateSocialHubs()
    -- Remove disconnected players from hubs
    for hubId, hub in pairs(self.SocialHubs) do
        for userId, playerData in pairs(hub.currentPlayers) do
            local player = Players:GetPlayerByUserId(userId)
            if not player then
                hub.currentPlayers[userId] = nil
            end
        end
    end
end

-- ==========================================
-- HELPER FUNCTIONS
-- ==========================================

function SocialManager:FindPlayerByName(playerName)
    for _, player in pairs(Players:GetPlayers()) do
        if player.Name:lower() == playerName:lower() then
            return player
        end
    end
    return nil
end

function SocialManager:IsPlayerVIP(player)
    local vipManager = _G.VIPManager
    if vipManager then
        return vipManager:IsPlayerVIP(player)
    end
    return false
end

function SocialManager:NotifyFriendsOnlineStatus(player, isOnline)
    local playerData = self.PlayerFriends[player.UserId]
    if not playerData then return end
    
    for friendUserId, friendData in pairs(playerData.friends) do
        local friendPlayer = Players:GetPlayerByUserId(friendUserId)
        if friendPlayer then
            local notificationManager = _G.NotificationManager
            if notificationManager then
                local status = isOnline and "came online" or "went offline"
                notificationManager:ShowToast(
                    "Friend Status 👋",
                    player.Name .. " " .. status,
                    isOnline and "🟢" or "🔴",
                    "friend_status"
                )
            end
        end
    end
end

function SocialManager:UpdateSocialStats(userId, statType, amount)
    local profile = self.PlayerProfiles[userId]
    if profile and profile.stats[statType] then
        profile.stats[statType] = profile.stats[statType] + amount
    end
end

function SocialManager:AddWaterToGarden(player, amount)
    -- Add water to player's garden
    local plotManager = _G.PlotManager
    if plotManager then
        plotManager:AddWaterToGarden(player, amount)
    end
end

function SocialManager:HandleSocialMessage(messageData)
    -- Handle cross-server social messages
    if messageData.type == "friend_request" then
        -- Handle friend request from another server
    elseif messageData.type == "friend_online" then
        -- Handle friend coming online on another server
    end
end

-- ==========================================
-- PUBLIC API
-- ==========================================

function SocialManager:GetPlayerFriends(player)
    local playerData = self.PlayerFriends[player.UserId]
    if not playerData then return {} end
    
    local friendsList = {}
    for userId, friendData in pairs(playerData.friends) do
        local friendPlayer = Players:GetPlayerByUserId(userId)
        friendsList[userId] = {
            userId = userId,
            playerName = friendData.playerName,
            friendSince = friendData.friendSince,
            lastInteraction = friendData.lastInteraction,
            online = friendPlayer ~= nil
        }
    end
    
    return friendsList
end

function SocialManager:GetPendingFriendRequests(player)
    local playerData = self.PlayerFriends[player.UserId]
    if not playerData then return {} end
    
    local pendingRequests = {}
    for requestId, request in pairs(playerData.receivedRequests) do
        if request.status == self.RequestStatus.PENDING then
            pendingRequests[requestId] = request
        end
    end
    
    return pendingRequests
end

function SocialManager:CanVisitGarden(player, targetUserId)
    local targetProfile = self.PlayerProfiles[targetUserId]
    if not targetProfile or not targetProfile.privacy.allowVisits then
        return false, "Player is not allowing garden visits"
    end
    
    local playerData = self.PlayerFriends[player.UserId]
    if not playerData or not playerData.friends[targetUserId] then
        return false, "You need to be friends to visit this garden"
    end
    
    return true, "Can visit"
end

-- ==========================================
-- CLEANUP
-- ==========================================

function SocialManager:Cleanup()
    -- Save all player social data
    for userId, _ in pairs(self.PlayerFriends) do
        local player = Players:GetPlayerByUserId(userId)
        if player then
            self:SavePlayerSocialData(player)
            self:SavePlayerProfile(player)
        end
    end
    
    print("👥 SocialManager: Social system cleaned up")
end

return SocialManager
