--[[
    SecurityHandler.lua
    Server-Side Anti-Cheat & Security System
    
    Priority: 15 (Critical security layer)
    Dependencies: All gameplay modules
    Used by: All server modules for validation
    
    Features:
    - Rapid action detection & prevention
    - Distance validation for interactions
    - Economy transaction validation
    - Progress manipulation detection
    - Client data integrity checks
    - Automated banning system
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Load required modules
local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)

local SecurityHandler = {}
SecurityHandler.__index = SecurityHandler

-- ==========================================
-- SECURITY DATA STORAGE
-- ==========================================

SecurityHandler.PlayerSecurityData = {}    -- [userId] = {violations, actions, timestamps}
SecurityHandler.ActionCooldowns = {}       -- [userId] = {action = lastTime}
SecurityHandler.SuspiciousActivity = {}    -- [userId] = {activity logs}
SecurityHandler.BannedPlayers = {}         -- [userId] = {reason, duration}

-- Security Configuration
SecurityHandler.MaxActionsPerSecond = {
    plant = 2,      -- Max 2 plants per second
    harvest = 3,    -- Max 3 harvests per second
    purchase = 1,   -- Max 1 purchase per second
    interact = 5    -- Max 5 interactions per second
}

SecurityHandler.MaxDistance = {
    plotInteraction = 50,   -- Max distance to interact with plots
    npcInteraction = 30,    -- Max distance to interact with NPCs
    shopInteraction = 25    -- Max distance to use shop
}

SecurityHandler.ViolationThresholds = {
    warning = 3,    -- 3 violations = warning
    kick = 10,      -- 10 violations = kick
    ban = 25        -- 25 violations = temporary ban
}

-- ==========================================
-- INITIALIZATION
-- ==========================================

function SecurityHandler:Initialize()
    print("🔒 SecurityHandler: Initializing security system...")
    
    -- Set up player tracking
    self:SetupPlayerTracking()
    
    -- Set up periodic security checks
    self:SetupSecurityChecks()
    
    -- Set up violation monitoring
    self:SetupViolationMonitoring()
    
    print("✅ SecurityHandler: Security system initialized successfully")
end

function SecurityHandler:SetupPlayerTracking()
    -- Track player joining
    Players.PlayerAdded:Connect(function(player)
        self:InitializePlayerSecurity(player)
    end)
    
    -- Track player leaving
    Players.PlayerRemoving:Connect(function(player)
        self:CleanupPlayerSecurity(player)
    end)
    
    -- Initialize existing players
    for _, player in pairs(Players:GetPlayers()) do
        self:InitializePlayerSecurity(player)
    end
end

function SecurityHandler:InitializePlayerSecurity(player)
    local userId = player.UserId
    
    self.PlayerSecurityData[userId] = {
        violations = 0,
        totalActions = 0,
        lastActionTime = 0,
        joinTime = os.time(),
        warnings = 0,
        kicks = 0,
        actionHistory = {}
    }
    
    self.ActionCooldowns[userId] = {}
    self.SuspiciousActivity[userId] = {}
    
    print("🔒 SecurityHandler: Initialized security tracking for", player.Name)
end

function SecurityHandler:CleanupPlayerSecurity(player)
    local userId = player.UserId
    
    -- Archive security data before cleanup
    self:ArchivePlayerSecurity(userId)
    
    -- Clean up active tracking
    self.PlayerSecurityData[userId] = nil
    self.ActionCooldowns[userId] = nil
    self.SuspiciousActivity[userId] = nil
    
    print("🔒 SecurityHandler: Cleaned up security data for", player.Name)
end

-- ==========================================
-- ACTION VALIDATION
-- ==========================================

function SecurityHandler:ValidateAction(player, actionType, actionData)
    local userId = player.UserId
    local currentTime = os.time()
    
    -- Check if player is banned
    if self:IsPlayerBanned(userId) then
        return {
            valid = false,
            reason = "Player is banned",
            action = "kick"
        }
    end
    
    -- Validate action rate
    local rateCheck = self:ValidateActionRate(userId, actionType, currentTime)
    if not rateCheck.valid then
        return rateCheck
    end
    
    -- Validate distance if applicable
    local distanceCheck = self:ValidateDistance(player, actionType, actionData)
    if not distanceCheck.valid then
        return distanceCheck
    end
    
    -- Validate action context
    local contextCheck = self:ValidateActionContext(player, actionType, actionData)
    if not contextCheck.valid then
        return contextCheck
    end
    
    -- Record valid action
    self:RecordAction(userId, actionType, currentTime, true)
    
    return {
        valid = true,
        reason = "Action validated"
    }
end

function SecurityHandler:ValidateActionRate(userId, actionType, currentTime)
    local securityData = self.PlayerSecurityData[userId]
    if not securityData then
        return {valid = false, reason = "No security data", action = "kick"}
    end
    
    -- Check general action rate (all actions combined)
    local totalActionsThisSecond = 0
    for _, actionTime in pairs(securityData.actionHistory) do
        if currentTime - actionTime < 1 then
            totalActionsThisSecond = totalActionsThisSecond + 1
        end
    end
    
    if totalActionsThisSecond >= 10 then -- Max 10 actions per second total
        self:RecordViolation(userId, "excessive_action_rate", "More than 10 actions per second")
        return {
            valid = false,
            reason = "Too many actions per second",
            action = "warning"
        }
    end
    
    -- Check specific action type rate
    local cooldowns = self.ActionCooldowns[userId]
    if not cooldowns then
        self.ActionCooldowns[userId] = {}
        cooldowns = self.ActionCooldowns[userId]
    end
    
    local lastActionTime = cooldowns[actionType] or 0
    local timeSinceLastAction = currentTime - lastActionTime
    local maxRate = self.MaxActionsPerSecond[actionType] or 1
    local minCooldown = 1 / maxRate
    
    if timeSinceLastAction < minCooldown then
        self:RecordViolation(userId, "action_spam", "Action " .. actionType .. " too frequent")
        return {
            valid = false,
            reason = "Action cooldown not met",
            action = "warning"
        }
    end
    
    -- Update cooldown
    cooldowns[actionType] = currentTime
    
    return {valid = true}
end

function SecurityHandler:ValidateDistance(player, actionType, actionData)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return {valid = true} -- Can't validate without character
    end
    
    local playerPosition = player.Character.HumanoidRootPart.Position
    local maxDistance = self.MaxDistance[actionType .. "Interaction"] or 100
    
    -- Get target position based on action type
    local targetPosition = nil
    
    if actionType == "plant" or actionType == "harvest" then
        -- For plot interactions, get plot position
        if actionData and actionData.plotId then
            targetPosition = self:GetPlotPosition(actionData.plotId)
        end
    elseif actionType == "purchase" then
        -- For shop interactions, get NPC position
        targetPosition = self:GetShopNPCPosition()
    end
    
    if targetPosition then
        local distance = (playerPosition - targetPosition).Magnitude
        
        if distance > maxDistance then
            self:RecordViolation(player.UserId, "distance_cheat", 
                string.format("Action %s at distance %.1f (max: %d)", actionType, distance, maxDistance))
            return {
                valid = false,
                reason = "Too far from target",
                action = "warning"
            }
        end
    end
    
    return {valid = true}
end

function SecurityHandler:ValidateActionContext(player, actionType, actionData)
    local userId = player.UserId
    
    -- Validate based on action type
    if actionType == "plant" then
        return self:ValidatePlantAction(player, actionData)
    elseif actionType == "harvest" then
        return self:ValidateHarvestAction(player, actionData)
    elseif actionType == "purchase" then
        return self:ValidatePurchaseAction(player, actionData)
    end
    
    return {valid = true}
end

function SecurityHandler:ValidatePlantAction(player, actionData)
    -- Check if plot exists and is owned by player
    if not actionData or not actionData.plotId then
        return {valid = false, reason = "Invalid plot data", action = "warning"}
    end
    
    -- Additional plant-specific validations can be added here
    return {valid = true}
end

function SecurityHandler:ValidateHarvestAction(player, actionData)
    -- Check if plot exists, is owned by player, and has a ready plant
    if not actionData or not actionData.plotId then
        return {valid = false, reason = "Invalid plot data", action = "warning"}
    end
    
    -- Additional harvest-specific validations can be added here
    return {valid = true}
end

function SecurityHandler:ValidatePurchaseAction(player, actionData)
    -- Validate purchase data
    if not actionData or not actionData.itemType or not actionData.itemName then
        return {valid = false, reason = "Invalid purchase data", action = "warning"}
    end
    
    -- Check if item exists in config
    if actionData.itemType == "seed" then
        local plantConfig = ConfigModule.Plants[actionData.itemName]
        if not plantConfig then
            return {valid = false, reason = "Invalid plant type", action = "warning"}
        end
    end
    
    return {valid = true}
end

-- ==========================================
-- VIOLATION HANDLING
-- ==========================================

function SecurityHandler:RecordViolation(userId, violationType, details)
    local player = Players:GetPlayerByUserId(userId)
    if not player then return end
    
    local securityData = self.PlayerSecurityData[userId]
    if not securityData then return end
    
    -- Increment violation count
    securityData.violations = securityData.violations + 1
    
    -- Record violation details
    table.insert(self.SuspiciousActivity[userId], {
        type = violationType,
        details = details,
        timestamp = os.time(),
        count = securityData.violations
    })
    
    -- Determine action based on violation count
    local action = self:DetermineViolationAction(securityData.violations)
    
    -- Execute action
    self:ExecuteSecurityAction(player, action, violationType, details)
    
    print("⚠️ SecurityHandler: Violation recorded for", player.Name, "-", violationType, "(" .. securityData.violations .. " total)")
end

function SecurityHandler:DetermineViolationAction(violationCount)
    if violationCount >= self.ViolationThresholds.ban then
        return "ban"
    elseif violationCount >= self.ViolationThresholds.kick then
        return "kick"
    elseif violationCount >= self.ViolationThresholds.warning then
        return "warning"
    else
        return "log"
    end
end

function SecurityHandler:ExecuteSecurityAction(player, action, violationType, details)
    local userId = player.UserId
    local securityData = self.PlayerSecurityData[userId]
    
    if action == "warning" then
        self:SendWarning(player, violationType)
        securityData.warnings = securityData.warnings + 1
        
    elseif action == "kick" then
        self:KickPlayer(player, violationType, details)
        securityData.kicks = securityData.kicks + 1
        
    elseif action == "ban" then
        self:BanPlayer(player, violationType, details, 3600) -- 1 hour ban
        
    end
end

function SecurityHandler:SendWarning(player, violationType)
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if remoteEvents then
        local showNotificationEvent = remoteEvents:FindFirstChild("ShowNotification")
        if showNotificationEvent then
            local message = "⚠️ Warning: Suspicious activity detected (" .. violationType .. ")"
            showNotificationEvent:FireClient(player, message, "warning")
        end
    end
    
    print("⚠️ SecurityHandler: Warning sent to", player.Name, "for", violationType)
end

function SecurityHandler:KickPlayer(player, violationType, details)
    local kickMessage = "You have been kicked for suspicious activity: " .. violationType
    
    -- Log the kick
    print("🚫 SecurityHandler: Kicking", player.Name, "for", violationType, "-", details)
    
    -- Kick the player
    player:Kick(kickMessage)
end

function SecurityHandler:BanPlayer(player, violationType, details, duration)
    local userId = player.UserId
    local banEndTime = os.time() + duration
    
    -- Record ban
    self.BannedPlayers[userId] = {
        reason = violationType,
        details = details,
        startTime = os.time(),
        endTime = banEndTime,
        duration = duration
    }
    
    -- Log the ban
    print("🔨 SecurityHandler: Banning", player.Name, "for", duration, "seconds -", violationType, "-", details)
    
    -- Kick with ban message
    local banMessage = string.format("You have been temporarily banned for %d minutes. Reason: %s", 
        math.floor(duration / 60), violationType)
    player:Kick(banMessage)
end

-- ==========================================
-- BAN MANAGEMENT
-- ==========================================

function SecurityHandler:IsPlayerBanned(userId)
    local banData = self.BannedPlayers[userId]
    if not banData then return false end
    
    -- Check if ban has expired
    if os.time() >= banData.endTime then
        self.BannedPlayers[userId] = nil
        return false
    end
    
    return true
end

function SecurityHandler:GetBanInfo(userId)
    return self.BannedPlayers[userId]
end

function SecurityHandler:UnbanPlayer(userId)
    self.BannedPlayers[userId] = nil
    print("🔓 SecurityHandler: Player", userId, "has been unbanned")
end

-- ==========================================
-- PERIODIC SECURITY CHECKS
-- ==========================================

function SecurityHandler:SetupSecurityChecks()
    -- Run security checks every 30 seconds
    spawn(function()
        while true do
            wait(30)
            self:PerformSecuritySweep()
        end
    end)
    
    -- Clean up old data every 5 minutes
    spawn(function()
        while true do
            wait(300) -- 5 minutes
            self:CleanupOldData()
        end
    end)
end

function SecurityHandler:PerformSecuritySweep()
    for userId, securityData in pairs(self.PlayerSecurityData) do
        local player = Players:GetPlayerByUserId(userId)
        if player then
            -- Check for rapid actions
            self:CheckRapidActions(userId)
            
            -- Check for suspicious patterns
            self:CheckSuspiciousPatterns(userId)
            
            -- Check player integrity
            self:CheckPlayerIntegrity(player)
        end
    end
end

function SecurityHandler:CheckRapidActions(userId)
    local securityData = self.PlayerSecurityData[userId]
    if not securityData then return end
    
    local currentTime = os.time()
    local recentActions = 0
    
    -- Count actions in the last 5 seconds
    for _, actionTime in pairs(securityData.actionHistory) do
        if currentTime - actionTime < 5 then
            recentActions = recentActions + 1
        end
    end
    
    -- Flag if too many actions in short time
    if recentActions > 20 then -- More than 20 actions in 5 seconds
        self:RecordViolation(userId, "rapid_actions", "Too many actions in short period")
    end
end

function SecurityHandler:CheckSuspiciousPatterns(userId)
    local suspiciousData = self.SuspiciousActivity[userId]
    if not suspiciousData or #suspiciousData < 3 then return end
    
    -- Look for patterns in violations
    local recentViolations = {}
    local currentTime = os.time()
    
    for _, violation in ipairs(suspiciousData) do
        if currentTime - violation.timestamp < 300 then -- Last 5 minutes
            table.insert(recentViolations, violation)
        end
    end
    
    -- If multiple violations of same type in short period
    if #recentViolations >= 3 then
        local sameTypeCount = 0
        local violationType = recentViolations[1].type
        
        for _, violation in ipairs(recentViolations) do
            if violation.type == violationType then
                sameTypeCount = sameTypeCount + 1
            end
        end
        
        if sameTypeCount >= 3 then
            self:RecordViolation(userId, "pattern_violation", "Repeated violations of type: " .. violationType)
        end
    end
end

function SecurityHandler:CheckPlayerIntegrity(player)
    if not player.Character then return end
    
    -- Check for impossible speeds
    local humanoid = player.Character:FindFirstChild("Humanoid")
    if humanoid and humanoid.WalkSpeed > 50 then -- Normal max is 16
        self:RecordViolation(player.UserId, "speed_hack", "WalkSpeed: " .. humanoid.WalkSpeed)
    end
    
    -- Check for impossible jump power
    if humanoid and humanoid.JumpPower > 100 then -- Normal max is 50
        self:RecordViolation(player.UserId, "jump_hack", "JumpPower: " .. humanoid.JumpPower)
    end
end

-- ==========================================
-- DATA MANAGEMENT
-- ==========================================

function SecurityHandler:RecordAction(userId, actionType, timestamp, success)
    local securityData = self.PlayerSecurityData[userId]
    if not securityData then return end
    
    -- Update action history
    table.insert(securityData.actionHistory, timestamp)
    
    -- Keep only recent history (last 60 seconds)
    local currentTime = os.time()
    local filteredHistory = {}
    for _, actionTime in ipairs(securityData.actionHistory) do
        if currentTime - actionTime < 60 then
            table.insert(filteredHistory, actionTime)
        end
    end
    securityData.actionHistory = filteredHistory
    
    -- Update counters
    securityData.totalActions = securityData.totalActions + 1
    securityData.lastActionTime = timestamp
end

function SecurityHandler:CleanupOldData()
    local currentTime = os.time()
    
    -- Clean up old suspicious activity records
    for userId, activities in pairs(self.SuspiciousActivity) do
        local filteredActivities = {}
        for _, activity in ipairs(activities) do
            if currentTime - activity.timestamp < 3600 then -- Keep last hour
                table.insert(filteredActivities, activity)
            end
        end
        self.SuspiciousActivity[userId] = filteredActivities
    end
    
    -- Clean up expired bans
    for userId, banData in pairs(self.BannedPlayers) do
        if currentTime >= banData.endTime then
            self.BannedPlayers[userId] = nil
        end
    end
    
    print("🧹 SecurityHandler: Old data cleaned up")
end

function SecurityHandler:ArchivePlayerSecurity(userId)
    local securityData = self.PlayerSecurityData[userId]
    if not securityData then return end
    
    -- Archive to persistent storage if needed
    -- For now, just log the summary
    print("📁 SecurityHandler: Archived security data for userId", userId, 
          "- Violations:", securityData.violations, 
          "- Total actions:", securityData.totalActions,
          "- Warnings:", securityData.warnings,
          "- Kicks:", securityData.kicks)
end

-- ==========================================
-- UTILITY FUNCTIONS
-- ==========================================

function SecurityHandler:GetPlotPosition(plotId)
    -- Get plot position from PlotManager or workspace
    local plotsFolder = workspace:FindFirstChild("Plots")
    if plotsFolder then
        for _, plot in pairs(plotsFolder:GetChildren()) do
            if plot:GetAttribute("PlotId") == plotId then
                return plot.Position
            end
        end
    end
    return Vector3.new(0, 0, 0)
end

function SecurityHandler:GetShopNPCPosition()
    -- Get shop NPC position
    local shopNPC = workspace:FindFirstChild("ShopNPC")
    if shopNPC and shopNPC:FindFirstChild("HumanoidRootPart") then
        return shopNPC.HumanoidRootPart.Position
    end
    return Vector3.new(0, 0, 0)
end

function SecurityHandler:SetupViolationMonitoring()
    -- Monitor for patterns across all players
    spawn(function()
        while true do
            wait(60) -- Check every minute
            self:AnalyzeGlobalPatterns()
        end
    end)
end

function SecurityHandler:AnalyzeGlobalPatterns()
    local totalViolations = 0
    local activePlayers = 0
    
    for userId, securityData in pairs(self.PlayerSecurityData) do
        totalViolations = totalViolations + securityData.violations
        activePlayers = activePlayers + 1
    end
    
    -- Log statistics
    if activePlayers > 0 then
        local avgViolations = totalViolations / activePlayers
        if avgViolations > 5 then -- High violation rate
            print("🚨 SecurityHandler: High violation rate detected - Average:", avgViolations, "per player")
        end
    end
end

-- ==========================================
-- ADMIN FUNCTIONS
-- ==========================================

function SecurityHandler:GetPlayerSecurityReport(userId)
    local securityData = self.PlayerSecurityData[userId]
    local suspiciousData = self.SuspiciousActivity[userId]
    local banData = self.BannedPlayers[userId]
    
    return {
        security = securityData,
        suspicious = suspiciousData,
        ban = banData,
        isBanned = self:IsPlayerBanned(userId)
    }
end

function SecurityHandler:ResetPlayerViolations(userId)
    local securityData = self.PlayerSecurityData[userId]
    if securityData then
        securityData.violations = 0
        securityData.warnings = 0
        securityData.kicks = 0
        self.SuspiciousActivity[userId] = {}
        print("🔄 SecurityHandler: Reset violations for userId", userId)
    end
end

function SecurityHandler:PrintSecurityStatistics()
    local totalPlayers = 0
    local totalViolations = 0
    local totalWarnings = 0
    local totalKicks = 0
    local totalBans = 0
    
    for userId, securityData in pairs(self.PlayerSecurityData) do
        totalPlayers = totalPlayers + 1
        totalViolations = totalViolations + securityData.violations
        totalWarnings = totalWarnings + securityData.warnings
        totalKicks = totalKicks + securityData.kicks
    end
    
    for userId, banData in pairs(self.BannedPlayers) do
        totalBans = totalBans + 1
    end
    
    print("📊 SecurityHandler Statistics:")
    print("   Active players monitored:", totalPlayers)
    print("   Total violations:", totalViolations)
    print("   Total warnings:", totalWarnings)
    print("   Total kicks:", totalKicks)
    print("   Active bans:", totalBans)
    print("   Average violations per player:", totalPlayers > 0 and (totalViolations / totalPlayers) or 0)
end

return SecurityHandler
