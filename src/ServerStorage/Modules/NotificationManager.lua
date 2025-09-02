--[[
    NotificationManager.lua (Server-Side Wrapper)
    Server-Side Notification System Wrapper
    
    Priority: 21 (VIP & Monetization phase)
    Dependencies: ReplicatedStorage, RemoteEvents
    Used by: All server-side managers
    
    Features:
    - Server-to-client notification forwarding
    - Bulk notification management
    - Event-based notification system
    - VIP notification privileges
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NotificationManager = {}
NotificationManager.__index = NotificationManager

-- ==========================================
-- INITIALIZATION
-- ==========================================

function NotificationManager:Initialize()
    print("📢 NotificationManager (Server): Initializing notification wrapper...")
    
    -- Set up remote events
    self:SetupRemoteEvents()
    
    print("✅ NotificationManager (Server): Notification wrapper initialized")
end

function NotificationManager:SetupRemoteEvents()
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then
        remoteEvents = Instance.new("Folder")
        remoteEvents.Name = "RemoteEvents"
        remoteEvents.Parent = ReplicatedStorage
    end
    
    -- Create ShowToast remote event
    if not remoteEvents:FindFirstChild("ShowToast") then
        local showToastEvent = Instance.new("RemoteEvent")
        showToastEvent.Name = "ShowToast"
        showToastEvent.Parent = remoteEvents
    end
    
    -- Create ShowAchievement remote event  
    if not remoteEvents:FindFirstChild("ShowAchievement") then
        local showAchievementEvent = Instance.new("RemoteEvent")
        showAchievementEvent.Name = "ShowAchievement"
        showAchievementEvent.Parent = remoteEvents
    end
end

-- ==========================================
-- NOTIFICATION FUNCTIONS
-- ==========================================

function NotificationManager:ShowToast(player, data)
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then return end
    
    local showToastEvent = remoteEvents:FindFirstChild("ShowToast")
    if not showToastEvent then return end
    
    -- Send to specific player
    if player and player.Parent then
        showToastEvent:FireClient(player, data)
    end
end

function NotificationManager:ShowToastToAll(data)
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then return end
    
    local showToastEvent = remoteEvents:FindFirstChild("ShowToast")
    if not showToastEvent then return end
    
    -- Send to all players
    showToastEvent:FireAllClients(data)
end

function NotificationManager:ShowAchievement(player, achievementData)
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then return end
    
    local showAchievementEvent = remoteEvents:FindFirstChild("ShowAchievement")
    if not showAchievementEvent then return end
    
    -- Send to specific player
    if player and player.Parent then
        showAchievementEvent:FireClient(player, achievementData)
    end
end

function NotificationManager:ShowVIPNotification(player, data)
    -- Special VIP notification
    local vipData = {
        title = data.title or "VIP Benefit",
        message = data.message,
        type = "vip",
        duration = data.duration or 5,
        sound = data.sound or "vip_notification"
    }
    
    self:ShowToast(player, vipData)
end

function NotificationManager:ShowEconomyAlert(player, data)
    -- Economy-related notification
    local economyData = {
        title = data.title or "Economy Alert",
        message = data.message,
        type = "economy",
        duration = data.duration or 3,
        sound = data.sound or "coin_sound"
    }
    
    self:ShowToast(player, economyData)
end

-- ==========================================
-- UTILITY FUNCTIONS
-- ==========================================

function NotificationManager:IsPlayerValid(player)
    return player and player.Parent and Players:FindFirstChild(player.Name)
end

function NotificationManager:GetPlayerName(player)
    if self:IsPlayerValid(player) then
        return player.Name
    end
    return "Unknown Player"
end

-- ==========================================
-- PUBLIC API
-- ==========================================

function NotificationManager:NotifyPlantGrowth(player, plantType)
    self:ShowToast(player, {
        title = "Plant Ready!",
        message = "Your " .. plantType .. " is ready to harvest!",
        type = "success",
        duration = 4
    })
end

function NotificationManager:NotifyCoinsEarned(player, amount)
    self:ShowEconomyAlert(player, {
        title = "Coins Earned!",
        message = "You earned " .. amount .. " coins!",
        duration = 3
    })
end

function NotificationManager:NotifyLevelUp(player, newLevel)
    self:ShowToast(player, {
        title = "Level Up!",
        message = "Congratulations! You reached level " .. newLevel .. "!",
        type = "achievement",
        duration = 5
    })
end

function NotificationManager:NotifyVIPPurchase(player)
    self:ShowVIPNotification(player, {
        title = "VIP Activated!",
        message = "Welcome to VIP! Enjoy exclusive benefits!",
        duration = 6
    })
end

return NotificationManager
