--[[
    Remote Events Setup
    Client-Server Communication Events
    
    This script creates all the necessary RemoteEvents and RemoteFunctions
    for the garden game communication system.
--]]

-- Create RemoteEvents folder if it doesn't exist
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEventsFolder then
    remoteEventsFolder = Instance.new("Folder")
    remoteEventsFolder.Name = "RemoteEvents"
    remoteEventsFolder.Parent = ReplicatedStorage
end

-- ==========================================
-- PLANT SYSTEM EVENTS
-- ==========================================

-- Plant Seed Event
local plantSeedEvent = Instance.new("RemoteEvent")
plantSeedEvent.Name = "PlantSeed"
plantSeedEvent.Parent = remoteEventsFolder

-- Harvest Plant Event
local harvestPlantEvent = Instance.new("RemoteEvent")
harvestPlantEvent.Name = "HarvestPlant"
harvestPlantEvent.Parent = remoteEventsFolder

-- Get Plant Status Function
local getPlantStatusFunction = Instance.new("RemoteFunction")
getPlantStatusFunction.Name = "GetPlantStatus"
getPlantStatusFunction.Parent = remoteEventsFolder

-- ==========================================
-- SHOP SYSTEM EVENTS
-- ==========================================

-- Open Shop Event
local openShopEvent = Instance.new("RemoteEvent")
openShopEvent.Name = "OpenShop"
openShopEvent.Parent = remoteEventsFolder

-- Purchase Item Function
local purchaseItemFunction = Instance.new("RemoteFunction")
purchaseItemFunction.Name = "PurchaseItem"
purchaseItemFunction.Parent = remoteEventsFolder

-- Sell Item Function
local sellItemFunction = Instance.new("RemoteFunction")
sellItemFunction.Name = "SellItem"
sellItemFunction.Parent = remoteEventsFolder

-- ==========================================
-- PLAYER DATA EVENTS
-- ==========================================

-- Update Player Data Event
local updatePlayerDataEvent = Instance.new("RemoteEvent")
updatePlayerDataEvent.Name = "UpdatePlayerData"
updatePlayerDataEvent.Parent = remoteEventsFolder

-- Get Player Data Function
local getPlayerDataFunction = Instance.new("RemoteFunction")
getPlayerDataFunction.Name = "GetPlayerData"
getPlayerDataFunction.Parent = remoteEventsFolder

-- ==========================================
-- VIP SYSTEM EVENTS
-- ==========================================

-- Check VIP Status Function
local checkVIPStatusFunction = Instance.new("RemoteFunction")
checkVIPStatusFunction.Name = "CheckVIPStatus"
checkVIPStatusFunction.Parent = remoteEventsFolder

-- Claim Daily Bonus Event
local claimDailyBonusEvent = Instance.new("RemoteEvent")
claimDailyBonusEvent.Name = "ClaimDailyBonus"
claimDailyBonusEvent.Parent = remoteEventsFolder

-- ==========================================
-- UI SYSTEM EVENTS
-- ==========================================

-- Show Notification Event
local showNotificationEvent = Instance.new("RemoteEvent")
showNotificationEvent.Name = "ShowNotification"
showNotificationEvent.Parent = remoteEventsFolder

-- Update UI Event
local updateUIEvent = Instance.new("RemoteEvent")
updateUIEvent.Name = "UpdateUI"
updateUIEvent.Parent = remoteEventsFolder

-- Toggle UI Event
local toggleUIEvent = Instance.new("RemoteEvent")
toggleUIEvent.Name = "ToggleUI"
toggleUIEvent.Parent = remoteEventsFolder

-- ==========================================
-- QUEST SYSTEM EVENTS
-- ==========================================

-- Get Quests Function
local getQuestsFunction = Instance.new("RemoteFunction")
getQuestsFunction.Name = "GetQuests"
getQuestsFunction.Parent = remoteEventsFolder

-- Complete Quest Event
local completeQuestEvent = Instance.new("RemoteEvent")
completeQuestEvent.Name = "CompleteQuest"
completeQuestEvent.Parent = remoteEventsFolder

-- ==========================================
-- LEADERBOARD EVENTS
-- ==========================================

-- Get Leaderboard Function
local getLeaderboardFunction = Instance.new("RemoteFunction")
getLeaderboardFunction.Name = "GetLeaderboard"
getLeaderboardFunction.Parent = remoteEventsFolder

print("✅ RemoteEvents: All communication events created successfully")
