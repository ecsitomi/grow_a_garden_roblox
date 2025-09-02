--[[
    GuildManager.lua
    Server-Side Social Guilds and Cooperative Gameplay System
    
    Priority: 31 (Advanced Features phase)
    Dependencies: DataStoreService, MessagingService, ReplicatedStorage
    Used by: NotificationManager, VIPManager, EconomyManager
    
    Features:
    - Guild creation and management
    - Member roles and permissions
    - Guild activities and challenges
    - Cooperative farming projects
    - Guild chat and communication
    - Guild benefits and rewards
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

-- Load required modules
local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)

local GuildManager = {}
GuildManager.__index = GuildManager

-- ==========================================
-- INITIALIZATION & SETUP
-- ==========================================

-- Data stores
GuildManager.GuildStore = DataStoreService:GetDataStore("GuildData_v1")
GuildManager.MemberStore = DataStoreService:GetDataStore("GuildMembers_v1")

-- Guild state tracking
GuildManager.Guilds = {} -- [guildId] = guildData
GuildManager.PlayerGuilds = {} -- [userId] = guildId
GuildManager.GuildInvites = {} -- [playerId] = {invites}

-- Guild settings
GuildManager.GuildSettings = {
    maxNameLength = 30,
    maxDescriptionLength = 200,
    maxMembers = 50,
    vipMaxMembers = 100,
    creationCost = 10000, -- coins
    vipCreationCost = 5000, -- discounted for VIP
    maxGuildsPerPlayer = 1,
    inviteExpiration = 7 * 24 * 3600 -- 7 days
}

-- Guild member roles
GuildManager.GuildRoles = {
    LEADER = {
        name = "Leader",
        level = 4,
        permissions = {
            "invite_members", "kick_members", "promote_members", "demote_members",
            "edit_guild", "disband_guild", "manage_projects", "set_permissions",
            "access_treasury", "start_activities"
        }
    },
    OFFICER = {
        name = "Officer",
        level = 3,
        permissions = {
            "invite_members", "kick_members", "promote_members", "manage_projects",
            "start_activities"
        }
    },
    VETERAN = {
        name = "Veteran",
        level = 2,
        permissions = {
            "invite_members", "contribute_projects", "participate_activities"
        }
    },
    MEMBER = {
        name = "Member",
        level = 1,
        permissions = {
            "contribute_projects", "participate_activities"
        }
    }
}

-- Guild activity types
GuildManager.ActivityTypes = {
    COOPERATIVE_FARM = {
        name = "Cooperative Farm",
        description = "Work together to grow massive crops",
        duration = 24 * 3600, -- 24 hours
        minMembers = 3,
        maxParticipants = 20,
        rewards = {
            coins = 5000,
            xp = 10000,
            guildXP = 500,
            items = {"rare_seeds", "guild_trophy"}
        }
    },
    
    HARVEST_COMPETITION = {
        name = "Harvest Competition",
        description = "Compete with other guilds in harvesting",
        duration = 3 * 3600, -- 3 hours
        minMembers = 5,
        maxParticipants = 50,
        competitive = true,
        rewards = {
            winner = {coins = 20000, xp = 40000, guildXP = 2000},
            participant = {coins = 5000, xp = 10000, guildXP = 200}
        }
    },
    
    BEAUTY_CONTEST = {
        name = "Guild Beauty Contest",
        description = "Create the most beautiful guild garden",
        duration = 7 * 24 * 3600, -- 7 days
        minMembers = 2,
        maxParticipants = 30,
        rewards = {
            coins = 15000,
            xp = 30000,
            guildXP = 1500,
            items = {"beauty_crown", "guild_statue"}
        }
    },
    
    RESOURCE_DRIVE = {
        name = "Resource Collection Drive",
        description = "Collect resources for guild projects",
        duration = 12 * 3600, -- 12 hours
        minMembers = 4,
        maxParticipants = 40,
        rewards = {
            coins = 8000,
            xp = 16000,
            guildXP = 800,
            items = {"resource_chest"}
        }
    }
}

-- Guild project types
GuildManager.ProjectTypes = {
    GUILD_GARDEN = {
        name = "Guild Community Garden",
        description = "Build a massive shared garden space",
        cost = {coins = 100000, materials = 500},
        duration = 7 * 24 * 3600, -- 7 days
        maxContributors = 30,
        rewards = {
            guildXP = 5000,
            perks = {"shared_garden_access", "bonus_growth_rate"},
            items = {"guild_garden_key"}
        }
    },
    
    GUILD_HALL = {
        name = "Guild Hall",
        description = "Construct a meeting place for guild members",
        cost = {coins = 200000, materials = 1000},
        duration = 10 * 24 * 3600, -- 10 days
        maxContributors = 50,
        rewards = {
            guildXP = 10000,
            perks = {"guild_hall_access", "member_bonus", "storage_access"},
            items = {"guild_hall_deed"}
        }
    },
    
    RESEARCH_LAB = {
        name = "Agricultural Research Lab",
        description = "Research new farming techniques and seeds",
        cost = {coins = 300000, materials = 1500},
        duration = 14 * 24 * 3600, -- 14 days
        maxContributors = 40,
        rewards = {
            guildXP = 15000,
            perks = {"research_access", "advanced_seeds", "growth_bonus"},
            items = {"research_notes", "experimental_seeds"}
        }
    },
    
    GUILD_MARKETPLACE = {
        name = "Guild Marketplace",
        description = "Create a trading hub for guild members",
        cost = {coins = 150000, materials = 750},
        duration = 5 * 24 * 3600, -- 5 days
        maxContributors = 25,
        rewards = {
            guildXP = 7500,
            perks = {"marketplace_access", "trading_bonus", "discount_privileges"},
            items = {"trader_license"}
        }
    }
}

-- Guild perks and benefits
GuildManager.GuildPerks = {
    shared_garden_access = {
        name = "Shared Garden Access",
        description = "Access to guild's community garden",
        effects = {growth_bonus = 1.1, shared_resources = true}
    },
    
    member_bonus = {
        name = "Guild Member Bonus",
        description = "Bonus rewards for guild activities",
        effects = {activity_bonus = 1.2, xp_bonus = 1.1}
    },
    
    research_access = {
        name = "Research Lab Access",
        description = "Access to advanced farming research",
        effects = {rare_seed_chance = 1.3, mutation_chance = 1.2}
    },
    
    trading_bonus = {
        name = "Trading Bonus",
        description = "Better prices in guild marketplace",
        effects = {sell_bonus = 1.15, buy_discount = 0.9}
    }
}

-- ==========================================
-- INITIALIZATION
-- ==========================================

function GuildManager:Initialize()
    print("🏰 GuildManager: Initializing guild system...")
    
    -- Set up remote events
    self:SetupRemoteEvents()
    
    -- Set up player connections
    self:SetupPlayerConnections()
    
    -- Load existing guilds
    self:LoadGuilds()
    
    -- Set up messaging service for cross-server communication
    self:SetupMessagingService()
    
    -- Start guild activity updates
    self:StartGuildUpdates()
    
    print("✅ GuildManager: Guild system initialized")
end

function GuildManager:SetupRemoteEvents()
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then
        remoteEvents = Instance.new("Folder")
        remoteEvents.Name = "RemoteEvents"
        remoteEvents.Parent = ReplicatedStorage
    end
    
    -- Create guild
    local createGuildFunction = Instance.new("RemoteFunction")
    createGuildFunction.Name = "CreateGuild"
    createGuildFunction.Parent = remoteEvents
    createGuildFunction.OnServerInvoke = function(player, guildName, description)
        return self:CreateGuild(player, guildName, description)
    end
    
    -- Join guild
    local joinGuildFunction = Instance.new("RemoteFunction")
    joinGuildFunction.Name = "JoinGuild"
    joinGuildFunction.Parent = remoteEvents
    joinGuildFunction.OnServerInvoke = function(player, guildId)
        return self:JoinGuild(player, guildId)
    end
    
    -- Leave guild
    local leaveGuildFunction = Instance.new("RemoteFunction")
    leaveGuildFunction.Name = "LeaveGuild"
    leaveGuildFunction.Parent = remoteEvents
    leaveGuildFunction.OnServerInvoke = function(player)
        return self:LeaveGuild(player)
    end
    
    -- Invite player
    local invitePlayerFunction = Instance.new("RemoteFunction")
    invitePlayerFunction.Name = "InvitePlayer"
    invitePlayerFunction.Parent = remoteEvents
    invitePlayerFunction.OnServerInvoke = function(player, targetPlayerName)
        return self:InvitePlayer(player, targetPlayerName)
    end
    
    -- Get guild info
    local getGuildInfoFunction = Instance.new("RemoteFunction")
    getGuildInfoFunction.Name = "GetGuildInfo"
    getGuildInfoFunction.Parent = remoteEvents
    getGuildInfoFunction.OnServerInvoke = function(player)
        return self:GetPlayerGuildInfo(player)
    end
    
    -- Start guild activity
    local startActivityFunction = Instance.new("RemoteFunction")
    startActivityFunction.Name = "StartGuildActivity"
    startActivityFunction.Parent = remoteEvents
    startActivityFunction.OnServerInvoke = function(player, activityType)
        return self:StartGuildActivity(player, activityType)
    end
    
    -- Contribute to project
    local contributeProjectFunction = Instance.new("RemoteFunction")
    contributeProjectFunction.Name = "ContributeToProject"
    contributeProjectFunction.Parent = remoteEvents
    contributeProjectFunction.OnServerInvoke = function(player, projectId, contributionType, amount)
        return self:ContributeToProject(player, projectId, contributionType, amount)
    end
    
    -- Guild chat
    local guildChatEvent = Instance.new("RemoteEvent")
    guildChatEvent.Name = "GuildChatMessage"
    guildChatEvent.Parent = remoteEvents
    guildChatEvent.OnServerEvent:Connect(function(player, message)
        self:BroadcastGuildMessage(player, message)
    end)
end

function GuildManager:SetupPlayerConnections()
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

function GuildManager:LoadGuilds()
    -- Load all guild data from DataStore
    local success, guildsData = pcall(function()
        return self.GuildStore:GetAsync("all_guilds") or {}
    end)
    
    if success and guildsData then
        for guildId, guildData in pairs(guildsData) do
            self.Guilds[guildId] = guildData
            
            -- Map players to guilds
            for userId, memberData in pairs(guildData.members) do
                self.PlayerGuilds[userId] = guildId
            end
        end
        
        print("🏰 GuildManager: Loaded", #self.Guilds, "guilds")
    end
end

function GuildManager:SetupMessagingService()
    -- Subscribe to guild messages for cross-server communication
    MessagingService:SubscribeAsync("GuildUpdates", function(message)
        self:HandleGuildMessage(message.Data)
    end)
end

function GuildManager:StartGuildUpdates()
    spawn(function()
        while true do
            self:UpdateGuildActivities()
            self:UpdateGuildProjects()
            self:CleanupExpiredInvites()
            wait(60) -- Update every minute
        end
    end)
end

-- ==========================================
-- PLAYER MANAGEMENT
-- ==========================================

function GuildManager:OnPlayerJoined(player)
    -- Load player's guild membership
    local guildId = self.PlayerGuilds[player.UserId]
    if guildId then
        local guild = self.Guilds[guildId]
        if guild then
            -- Update player's online status
            guild.members[player.UserId].lastSeen = tick()
            guild.members[player.UserId].online = true
            
            -- Notify guild members
            self:NotifyGuildMembers(guildId, {
                type = "member_online",
                playerName = player.Name,
                userId = player.UserId
            })
        end
    end
    
    print("🏰 GuildManager: Player", player.Name, "joined with guild:", guildId or "none")
end

function GuildManager:OnPlayerLeaving(player)
    -- Update player's offline status
    local guildId = self.PlayerGuilds[player.UserId]
    if guildId then
        local guild = self.Guilds[guildId]
        if guild and guild.members[player.UserId] then
            guild.members[player.UserId].lastSeen = tick()
            guild.members[player.UserId].online = false
            
            -- Notify guild members
            self:NotifyGuildMembers(guildId, {
                type = "member_offline",
                playerName = player.Name,
                userId = player.UserId
            })
        end
    end
    
    -- Save guild data
    self:SaveGuildData()
    
    print("🏰 GuildManager: Player", player.Name, "left, guild data saved")
end

-- ==========================================
-- GUILD CREATION & MANAGEMENT
-- ==========================================

function GuildManager:CreateGuild(player, guildName, description)
    -- Check if player is already in a guild
    if self.PlayerGuilds[player.UserId] then
        return {success = false, message = "You are already in a guild"}
    end
    
    -- Validate guild name
    if not guildName or #guildName < 3 or #guildName > self.GuildSettings.maxNameLength then
        return {success = false, message = "Invalid guild name length"}
    end
    
    -- Check if guild name is taken
    for _, guild in pairs(self.Guilds) do
        if guild.name:lower() == guildName:lower() then
            return {success = false, message = "Guild name already taken"}
        end
    end
    
    -- Check creation cost
    local isVIP = self:IsPlayerVIP(player)
    local creationCost = isVIP and self.GuildSettings.vipCreationCost or self.GuildSettings.creationCost
    
    local economyManager = _G.EconomyManager
    if not economyManager or not economyManager:HasCurrency(player, creationCost) then
        return {success = false, message = "Not enough coins to create guild"}
    end
    
    -- Create guild
    local guildId = HttpService:GenerateGUID()
    local guild = {
        id = guildId,
        name = guildName,
        description = description or "",
        leaderId = player.UserId,
        leaderName = player.Name,
        createdTime = tick(),
        level = 1,
        xp = 0,
        xpRequired = 1000,
        maxMembers = isVIP and self.GuildSettings.vipMaxMembers or self.GuildSettings.maxMembers,
        members = {
            [player.UserId] = {
                userId = player.UserId,
                playerName = player.Name,
                role = "LEADER",
                joinTime = tick(),
                lastSeen = tick(),
                online = true,
                contribution = 0
            }
        },
        activities = {},
        projects = {},
        perks = {},
        treasury = {
            coins = 0,
            materials = 0
        },
        stats = {
            totalActivities = 0,
            totalProjects = 0,
            totalMembers = 1,
            guildAge = 0
        }
    }
    
    -- Deduct creation cost
    economyManager:RemoveCurrency(player, creationCost)
    
    -- Store guild
    self.Guilds[guildId] = guild
    self.PlayerGuilds[player.UserId] = guildId
    
    -- Save data
    self:SaveGuildData()
    
    -- Notify player
    local notificationManager = _G.NotificationManager
    if notificationManager then
        notificationManager:ShowToast(
            "Guild Created! 🏰",
            "Welcome to " .. guildName .. "!",
            "👑",
            "guild"
        )
    end
    
    print("🏰 GuildManager: Player", player.Name, "created guild:", guildName)
    
    return {success = true, message = "Guild created successfully", guildId = guildId}
end

function GuildManager:JoinGuild(player, guildId)
    local guild = self.Guilds[guildId]
    if not guild then
        return {success = false, message = "Guild not found"}
    end
    
    -- Check if player is already in a guild
    if self.PlayerGuilds[player.UserId] then
        return {success = false, message = "You are already in a guild"}
    end
    
    -- Check if guild is full
    if #guild.members >= guild.maxMembers then
        return {success = false, message = "Guild is full"}
    end
    
    -- Check if player has an invite
    local hasInvite = false
    if self.GuildInvites[player.UserId] then
        for _, invite in ipairs(self.GuildInvites[player.UserId]) do
            if invite.guildId == guildId and tick() < invite.expiration then
                hasInvite = true
                break
            end
        end
    end
    
    if not hasInvite then
        return {success = false, message = "You need an invitation to join this guild"}
    end
    
    -- Add player to guild
    guild.members[player.UserId] = {
        userId = player.UserId,
        playerName = player.Name,
        role = "MEMBER",
        joinTime = tick(),
        lastSeen = tick(),
        online = true,
        contribution = 0
    }
    
    -- Update player's guild membership
    self.PlayerGuilds[player.UserId] = guildId
    
    -- Update guild stats
    guild.stats.totalMembers = guild.stats.totalMembers + 1
    
    -- Remove used invite
    if self.GuildInvites[player.UserId] then
        for i, invite in ipairs(self.GuildInvites[player.UserId]) do
            if invite.guildId == guildId then
                table.remove(self.GuildInvites[player.UserId], i)
                break
            end
        end
    end
    
    -- Notify guild members
    self:NotifyGuildMembers(guildId, {
        type = "member_joined",
        playerName = player.Name,
        userId = player.UserId
    })
    
    -- Save data
    self:SaveGuildData()
    
    return {success = true, message = "Successfully joined " .. guild.name}
end

function GuildManager:LeaveGuild(player)
    local guildId = self.PlayerGuilds[player.UserId]
    if not guildId then
        return {success = false, message = "You are not in a guild"}
    end
    
    local guild = self.Guilds[guildId]
    if not guild then
        return {success = false, message = "Guild not found"}
    end
    
    -- Check if player is the leader
    if guild.leaderId == player.UserId then
        -- Transfer leadership or disband guild
        local newLeader = self:FindNewLeader(guild)
        if newLeader then
            guild.leaderId = newLeader.userId
            guild.leaderName = newLeader.playerName
            guild.members[newLeader.userId].role = "LEADER"
            
            -- Notify new leader
            local newLeaderPlayer = Players:GetPlayerByUserId(newLeader.userId)
            if newLeaderPlayer then
                local notificationManager = _G.NotificationManager
                if notificationManager then
                    notificationManager:ShowToast(
                        "Leadership Transferred! 👑",
                        "You are now the leader of " .. guild.name,
                        "⭐",
                        "guild"
                    )
                end
            end
        else
            -- Disband guild if no other members
            return self:DisbandGuild(guildId)
        end
    end
    
    -- Remove player from guild
    guild.members[player.UserId] = nil
    self.PlayerGuilds[player.UserId] = nil
    
    -- Update guild stats
    guild.stats.totalMembers = guild.stats.totalMembers - 1
    
    -- Notify remaining guild members
    self:NotifyGuildMembers(guildId, {
        type = "member_left",
        playerName = player.Name,
        userId = player.UserId
    })
    
    -- Save data
    self:SaveGuildData()
    
    return {success = true, message = "Successfully left the guild"}
end

function GuildManager:InvitePlayer(player, targetPlayerName)
    local guildId = self.PlayerGuilds[player.UserId]
    if not guildId then
        return {success = false, message = "You are not in a guild"}
    end
    
    local guild = self.Guilds[guildId]
    if not guild then
        return {success = false, message = "Guild not found"}
    end
    
    -- Check permissions
    if not self:HasPermission(player.UserId, guild, "invite_members") then
        return {success = false, message = "You don't have permission to invite members"}
    end
    
    -- Find target player
    local targetPlayer = nil
    for _, p in pairs(Players:GetPlayers()) do
        if p.Name:lower() == targetPlayerName:lower() then
            targetPlayer = p
            break
        end
    end
    
    if not targetPlayer then
        return {success = false, message = "Player not found online"}
    end
    
    -- Check if target is already in a guild
    if self.PlayerGuilds[targetPlayer.UserId] then
        return {success = false, message = "Player is already in a guild"}
    end
    
    -- Check if guild is full
    if #guild.members >= guild.maxMembers then
        return {success = false, message = "Guild is full"}
    end
    
    -- Create invite
    if not self.GuildInvites[targetPlayer.UserId] then
        self.GuildInvites[targetPlayer.UserId] = {}
    end
    
    -- Check for existing invite
    for _, invite in ipairs(self.GuildInvites[targetPlayer.UserId]) do
        if invite.guildId == guildId then
            return {success = false, message = "Player already has an invite from your guild"}
        end
    end
    
    table.insert(self.GuildInvites[targetPlayer.UserId], {
        guildId = guildId,
        guildName = guild.name,
        inviterName = player.Name,
        expiration = tick() + self.GuildSettings.inviteExpiration
    })
    
    -- Notify target player
    local notificationManager = _G.NotificationManager
    if notificationManager then
        notificationManager:ShowToast(
            "Guild Invitation! 📨",
            player.Name .. " invited you to join " .. guild.name,
            "🏰",
            "guild_invite"
        )
    end
    
    return {success = true, message = "Invitation sent successfully"}
end

-- ==========================================
-- GUILD ACTIVITIES
-- ==========================================

function GuildManager:StartGuildActivity(player, activityType)
    local guildId = self.PlayerGuilds[player.UserId]
    if not guildId then
        return {success = false, message = "You are not in a guild"}
    end
    
    local guild = self.Guilds[guildId]
    if not guild then
        return {success = false, message = "Guild not found"}
    end
    
    -- Check permissions
    if not self:HasPermission(player.UserId, guild, "start_activities") then
        return {success = false, message = "You don't have permission to start activities"}
    end
    
    local activityTemplate = self.ActivityTypes[activityType]
    if not activityTemplate then
        return {success = false, message = "Invalid activity type"}
    end
    
    -- Check minimum members
    local onlineMembers = self:GetOnlineMembers(guild)
    if #onlineMembers < activityTemplate.minMembers then
        return {success = false, message = "Not enough online members"}
    end
    
    -- Create activity
    local activityId = HttpService:GenerateGUID()
    local activity = {
        id = activityId,
        type = activityType,
        name = activityTemplate.name,
        description = activityTemplate.description,
        startTime = tick(),
        endTime = tick() + activityTemplate.duration,
        participants = {},
        progress = 0,
        target = 100, -- Default target
        rewards = activityTemplate.rewards,
        status = "active"
    }
    
    -- Add starting member as participant
    activity.participants[player.UserId] = {
        userId = player.UserId,
        playerName = player.Name,
        contribution = 0,
        joinTime = tick()
    }
    
    guild.activities[activityId] = activity
    guild.stats.totalActivities = guild.stats.totalActivities + 1
    
    -- Notify guild members
    self:NotifyGuildMembers(guildId, {
        type = "activity_started",
        activityName = activity.name,
        startedBy = player.Name,
        activityId = activityId
    })
    
    return {success = true, message = "Activity started successfully", activityId = activityId}
end

function GuildManager:JoinGuildActivity(player, activityId)
    local guildId = self.PlayerGuilds[player.UserId]
    if not guildId then
        return {success = false, message = "You are not in a guild"}
    end
    
    local guild = self.Guilds[guildId]
    if not guild then
        return {success = false, message = "Guild not found"}
    end
    
    local activity = guild.activities[activityId]
    if not activity then
        return {success = false, message = "Activity not found"}
    end
    
    if activity.status ~= "active" then
        return {success = false, message = "Activity is not active"}
    end
    
    -- Check if already participating
    if activity.participants[player.UserId] then
        return {success = false, message = "Already participating in this activity"}
    end
    
    -- Check participant limit
    local activityTemplate = self.ActivityTypes[activity.type]
    if #activity.participants >= activityTemplate.maxParticipants then
        return {success = false, message = "Activity is full"}
    end
    
    -- Add participant
    activity.participants[player.UserId] = {
        userId = player.UserId,
        playerName = player.Name,
        contribution = 0,
        joinTime = tick()
    }
    
    return {success = true, message = "Joined activity successfully"}
end

function GuildManager:ContributeToActivity(player, activityId, contribution)
    local guildId = self.PlayerGuilds[player.UserId]
    if not guildId then return end
    
    local guild = self.Guilds[guildId]
    if not guild then return end
    
    local activity = guild.activities[activityId]
    if not activity or activity.status ~= "active" then return end
    
    local participant = activity.participants[player.UserId]
    if not participant then return end
    
    -- Update contribution
    participant.contribution = participant.contribution + contribution
    activity.progress = activity.progress + contribution
    
    -- Check if activity is completed
    if activity.progress >= activity.target then
        self:CompleteGuildActivity(guildId, activityId)
    end
end

function GuildManager:CompleteGuildActivity(guildId, activityId)
    local guild = self.Guilds[guildId]
    local activity = guild.activities[activityId]
    
    activity.status = "completed"
    activity.completionTime = tick()
    
    -- Distribute rewards
    for userId, participant in pairs(activity.participants) do
        local player = Players:GetPlayerByUserId(userId)
        if player then
            self:GiveActivityRewards(player, activity.rewards)
        end
    end
    
    -- Add guild XP
    if activity.rewards.guildXP then
        self:AddGuildXP(guildId, activity.rewards.guildXP)
    end
    
    -- Notify guild members
    self:NotifyGuildMembers(guildId, {
        type = "activity_completed",
        activityName = activity.name,
        participants = #activity.participants
    })
end

-- ==========================================
-- GUILD PROJECTS
-- ==========================================

function GuildManager:StartGuildProject(player, projectType)
    local guildId = self.PlayerGuilds[player.UserId]
    if not guildId then
        return {success = false, message = "You are not in a guild"}
    end
    
    local guild = self.Guilds[guildId]
    if not guild then
        return {success = false, message = "Guild not found"}
    end
    
    -- Check permissions
    if not self:HasPermission(player.UserId, guild, "manage_projects") then
        return {success = false, message = "You don't have permission to start projects"}
    end
    
    local projectTemplate = self.ProjectTypes[projectType]
    if not projectTemplate then
        return {success = false, message = "Invalid project type"}
    end
    
    -- Check if guild already has this project
    for _, project in pairs(guild.projects) do
        if project.type == projectType and project.status ~= "failed" then
            return {success = false, message = "Guild already has this project"}
        end
    end
    
    -- Create project
    local projectId = HttpService:GenerateGUID()
    local project = {
        id = projectId,
        type = projectType,
        name = projectTemplate.name,
        description = projectTemplate.description,
        startTime = tick(),
        endTime = tick() + projectTemplate.duration,
        cost = projectTemplate.cost,
        progress = {coins = 0, materials = 0},
        contributors = {},
        status = "active",
        rewards = projectTemplate.rewards
    }
    
    guild.projects[projectId] = project
    guild.stats.totalProjects = guild.stats.totalProjects + 1
    
    -- Notify guild members
    self:NotifyGuildMembers(guildId, {
        type = "project_started",
        projectName = project.name,
        startedBy = player.Name,
        projectId = projectId
    })
    
    return {success = true, message = "Project started successfully", projectId = projectId}
end

function GuildManager:ContributeToProject(player, projectId, contributionType, amount)
    local guildId = self.PlayerGuilds[player.UserId]
    if not guildId then
        return {success = false, message = "You are not in a guild"}
    end
    
    local guild = self.Guilds[guildId]
    if not guild then
        return {success = false, message = "Guild not found"}
    end
    
    local project = guild.projects[projectId]
    if not project then
        return {success = false, message = "Project not found"}
    end
    
    if project.status ~= "active" then
        return {success = false, message = "Project is not active"}
    end
    
    -- Check if player has required resources
    local economyManager = _G.EconomyManager
    local inventoryManager = _G.InventoryManager
    
    if contributionType == "coins" then
        if not economyManager or not economyManager:HasCurrency(player, amount) then
            return {success = false, message = "Not enough coins"}
        end
        economyManager:RemoveCurrency(player, amount)
    elseif contributionType == "materials" then
        if not inventoryManager or not inventoryManager:HasItem(player, "materials", amount) then
            return {success = false, message = "Not enough materials"}
        end
        inventoryManager:RemoveItem(player, "materials", amount)
    else
        return {success = false, message = "Invalid contribution type"}
    end
    
    -- Add contribution
    project.progress[contributionType] = project.progress[contributionType] + amount
    
    -- Track contributor
    if not project.contributors[player.UserId] then
        project.contributors[player.UserId] = {
            userId = player.UserId,
            playerName = player.Name,
            totalContribution = 0,
            contributions = {}
        }
    end
    
    local contributor = project.contributors[player.UserId]
    contributor.totalContribution = contributor.totalContribution + amount
    
    if not contributor.contributions[contributionType] then
        contributor.contributions[contributionType] = 0
    end
    contributor.contributions[contributionType] = contributor.contributions[contributionType] + amount
    
    -- Check if project is completed
    local completed = true
    for resourceType, required in pairs(project.cost) do
        if project.progress[resourceType] < required then
            completed = false
            break
        end
    end
    
    if completed then
        self:CompleteGuildProject(guildId, projectId)
    end
    
    return {success = true, message = "Contribution successful"}
end

function GuildManager:CompleteGuildProject(guildId, projectId)
    local guild = self.Guilds[guildId]
    local project = guild.projects[projectId]
    
    project.status = "completed"
    project.completionTime = tick()
    
    -- Add guild XP
    if project.rewards.guildXP then
        self:AddGuildXP(guildId, project.rewards.guildXP)
    end
    
    -- Unlock perks
    if project.rewards.perks then
        for _, perkId in ipairs(project.rewards.perks) do
            guild.perks[perkId] = {
                unlocked = true,
                unlockedTime = tick(),
                source = "project_" .. projectId
            }
        end
    end
    
    -- Distribute rewards to contributors
    for userId, contributor in pairs(project.contributors) do
        local player = Players:GetPlayerByUserId(userId)
        if player then
            self:GiveProjectRewards(player, project.rewards)
        end
    end
    
    -- Notify guild members
    self:NotifyGuildMembers(guildId, {
        type = "project_completed",
        projectName = project.name,
        contributors = #project.contributors
    })
end

-- ==========================================
-- GUILD PROGRESSION
-- ==========================================

function GuildManager:AddGuildXP(guildId, amount)
    local guild = self.Guilds[guildId]
    if not guild then return end
    
    guild.xp = guild.xp + amount
    
    -- Check for level up
    while guild.xp >= guild.xpRequired do
        guild.xp = guild.xp - guild.xpRequired
        guild.level = guild.level + 1
        guild.xpRequired = guild.xpRequired * 1.5 -- Increase XP requirement
        
        -- Level up benefits
        self:OnGuildLevelUp(guildId)
    end
end

function GuildManager:OnGuildLevelUp(guildId)
    local guild = self.Guilds[guildId]
    
    -- Increase max members
    guild.maxMembers = guild.maxMembers + 5
    
    -- Notify all guild members
    self:NotifyGuildMembers(guildId, {
        type = "guild_level_up",
        newLevel = guild.level,
        guildName = guild.name
    })
    
    print("🏰 GuildManager: Guild", guild.name, "leveled up to level", guild.level)
end

-- ==========================================
-- UTILITY FUNCTIONS
-- ==========================================

function GuildManager:HasPermission(userId, guild, permission)
    local member = guild.members[userId]
    if not member then return false end
    
    local role = self.GuildRoles[member.role]
    if not role then return false end
    
    for _, perm in ipairs(role.permissions) do
        if perm == permission then
            return true
        end
    end
    
    return false
end

function GuildManager:GetOnlineMembers(guild)
    local onlineMembers = {}
    for userId, member in pairs(guild.members) do
        if member.online then
            table.insert(onlineMembers, member)
        end
    end
    return onlineMembers
end

function GuildManager:FindNewLeader(guild)
    -- Find highest ranking member to become new leader
    local candidates = {}
    for userId, member in pairs(guild.members) do
        if userId ~= guild.leaderId then
            table.insert(candidates, member)
        end
    end
    
    -- Sort by role level and contribution
    table.sort(candidates, function(a, b)
        local roleA = self.GuildRoles[a.role]
        local roleB = self.GuildRoles[b.role]
        if roleA.level ~= roleB.level then
            return roleA.level > roleB.level
        end
        return a.contribution > b.contribution
    end)
    
    return candidates[1]
end

function GuildManager:NotifyGuildMembers(guildId, messageData)
    local guild = self.Guilds[guildId]
    if not guild then return end
    
    for userId, member in pairs(guild.members) do
        local player = Players:GetPlayerByUserId(userId)
        if player then
            -- Send notification to player
            local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
            if remoteEvents then
                local guildNotification = remoteEvents:FindFirstChild("GuildNotification")
                if guildNotification then
                    guildNotification:FireClient(player, messageData)
                end
            end
        end
    end
end

function GuildManager:BroadcastGuildMessage(player, message)
    local guildId = self.PlayerGuilds[player.UserId]
    if not guildId then return end
    
    local guild = self.Guilds[guildId]
    if not guild then return end
    
    -- Filter message
    local filteredMessage = self:FilterMessage(message)
    
    local messageData = {
        type = "chat_message",
        senderName = player.Name,
        senderId = player.UserId,
        message = filteredMessage,
        timestamp = tick()
    }
    
    self:NotifyGuildMembers(guildId, messageData)
end

function GuildManager:FilterMessage(message)
    -- Basic message filtering
    return message:gsub("%s+", " "):sub(1, 200) -- Limit length and clean whitespace
end

function GuildManager:IsPlayerVIP(player)
    local vipManager = _G.VIPManager
    if vipManager then
        return vipManager:IsPlayerVIP(player)
    end
    return false
end

function GuildManager:GetPlayerGuildInfo(player)
    local guildId = self.PlayerGuilds[player.UserId]
    if not guildId then
        return {inGuild = false}
    end
    
    local guild = self.Guilds[guildId]
    if not guild then
        return {inGuild = false}
    end
    
    return {
        inGuild = true,
        guild = {
            id = guild.id,
            name = guild.name,
            description = guild.description,
            level = guild.level,
            xp = guild.xp,
            xpRequired = guild.xpRequired,
            memberCount = #guild.members,
            maxMembers = guild.maxMembers,
            role = guild.members[player.UserId].role,
            activities = guild.activities,
            projects = guild.projects,
            perks = guild.perks,
            stats = guild.stats
        }
    }
end

function GuildManager:CleanupExpiredInvites()
    for userId, invites in pairs(self.GuildInvites) do
        for i = #invites, 1, -1 do
            if tick() >= invites[i].expiration then
                table.remove(invites, i)
            end
        end
        
        if #invites == 0 then
            self.GuildInvites[userId] = nil
        end
    end
end

function GuildManager:UpdateGuildActivities()
    for guildId, guild in pairs(self.Guilds) do
        for activityId, activity in pairs(guild.activities) do
            if activity.status == "active" and tick() >= activity.endTime then
                activity.status = "expired"
                
                -- Notify guild members
                self:NotifyGuildMembers(guildId, {
                    type = "activity_expired",
                    activityName = activity.name
                })
            end
        end
    end
end

function GuildManager:UpdateGuildProjects()
    for guildId, guild in pairs(self.Guilds) do
        for projectId, project in pairs(guild.projects) do
            if project.status == "active" and tick() >= project.endTime then
                project.status = "failed"
                
                -- Notify guild members
                self:NotifyGuildMembers(guildId, {
                    type = "project_failed",
                    projectName = project.name
                })
            end
        end
    end
end

function GuildManager:GiveActivityRewards(player, rewards)
    local economyManager = _G.EconomyManager
    local inventoryManager = _G.InventoryManager
    
    if rewards.coins and economyManager then
        economyManager:AddCurrency(player, rewards.coins)
    end
    
    if rewards.xp and economyManager then
        economyManager:AddExperience(player, rewards.xp)
    end
    
    if rewards.items and inventoryManager then
        for _, item in ipairs(rewards.items) do
            inventoryManager:AddItem(player, item, 1)
        end
    end
end

function GuildManager:GiveProjectRewards(player, rewards)
    self:GiveActivityRewards(player, rewards) -- Same reward system
end

function GuildManager:SaveGuildData()
    local success, error = pcall(function()
        self.GuildStore:SetAsync("all_guilds", self.Guilds)
    end)
    
    if not success then
        warn("❌ GuildManager: Failed to save guild data:", error)
    end
end

function GuildManager:DisbandGuild(guildId)
    local guild = self.Guilds[guildId]
    if not guild then
        return {success = false, message = "Guild not found"}
    end
    
    -- Remove all members from guild mapping
    for userId, _ in pairs(guild.members) do
        self.PlayerGuilds[userId] = nil
    end
    
    -- Remove guild
    self.Guilds[guildId] = nil
    
    -- Save data
    self:SaveGuildData()
    
    return {success = true, message = "Guild disbanded"}
end

-- ==========================================
-- CLEANUP
-- ==========================================

function GuildManager:Cleanup()
    -- Save all guild data
    self:SaveGuildData()
    
    print("🏰 GuildManager: Guild system cleaned up")
end

return GuildManager
