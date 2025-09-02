--[[
    VIPEffectsManager.lua
    Client-Side VIP Visual Effects System
    
    Priority: 18 (VIP & Monetization phase)
    Dependencies: VIPManager, TweenService, Lighting
    Used by: VIP status changes, plot interactions, UI elements
    
    Features:
    - Golden glow effects for VIP players
    - Particle effects for VIP plots
    - Enhanced UI highlighting
    - VIP-exclusive visual feedback
    - Dynamic lighting effects
    - Plot enhancement visuals
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

-- Load required modules
local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)

local VIPEffectsManager = {}
VIPEffectsManager.__index = VIPEffectsManager

-- ==========================================
-- EFFECT REFERENCES & STATE
-- ==========================================

VIPEffectsManager.Player = Players.LocalPlayer
VIPEffectsManager.Character = nil
VIPEffectsManager.IsVIP = false

-- Effect objects
VIPEffectsManager.PlayerGlowEffect = nil
VIPEffectsManager.PlotEffects = {}          -- [plotId] = {glow, particles, etc}
VIPEffectsManager.UIEffects = {}            -- UI glow effects
VIPEffectsManager.ActiveTweens = {}         -- Active animation tweens

-- Effect configurations
VIPEffectsManager.GlowColors = {
    primary = Color3.fromRGB(255, 215, 0),      -- Gold
    secondary = Color3.fromRGB(255, 255, 100),   -- Light yellow
    accent = Color3.fromRGB(255, 165, 0)         -- Orange-gold
}

VIPEffectsManager.EffectSettings = {
    playerGlowIntensity = 2,
    plotGlowIntensity = 1.5,
    pulseSpeed = 2,
    particleRate = 10,
    maxEffectDistance = 100
}

-- ==========================================
-- INITIALIZATION
-- ==========================================

function VIPEffectsManager:Initialize()
    print("✨ VIPEffectsManager: Initializing VIP effects system...")
    
    -- Set up character tracking
    self:SetupCharacterTracking()
    
    -- Set up VIP status monitoring
    self:SetupVIPStatusMonitoring()
    
    -- Set up remote event listeners
    self:SetupRemoteEvents()
    
    -- Set up update loop
    self:SetupUpdateLoop()
    
    print("✅ VIPEffectsManager: VIP effects system initialized")
end

function VIPEffectsManager:SetupCharacterTracking()
    -- Track character spawning
    self.Player.CharacterAdded:Connect(function(character)
        self:OnCharacterAdded(character)
    end)
    
    -- Track character removal
    self.Player.CharacterRemoving:Connect(function(character)
        self:OnCharacterRemoving(character)
    end)
    
    -- Initialize current character if it exists
    if self.Player.Character then
        self:OnCharacterAdded(self.Player.Character)
    end
end

function VIPEffectsManager:SetupVIPStatusMonitoring()
    -- Check VIP status regularly
    spawn(function()
        while true do
            wait(5) -- Check every 5 seconds
            self:UpdateVIPStatus()
        end
    end)
end

function VIPEffectsManager:SetupRemoteEvents()
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then
        warn("❌ VIPEffectsManager: RemoteEvents folder not found")
        return
    end
    
    -- Listen for VIP status updates
    local vipStatusUpdateEvent = remoteEvents:FindFirstChild("VIPStatusUpdate")
    if vipStatusUpdateEvent then
        vipStatusUpdateEvent.OnClientEvent:Connect(function(isVIP)
            self:OnVIPStatusChanged(isVIP)
        end)
    end
    
    -- Listen for plot interaction effects
    local plotInteractionEvent = remoteEvents:FindFirstChild("TriggerPlotEffect")
    if plotInteractionEvent then
        plotInteractionEvent.OnClientEvent:Connect(function(plotId, effectType)
            self:TriggerPlotEffect(plotId, effectType)
        end)
    end
    
    -- Listen for celebration effects
    local celebrationEvent = remoteEvents:FindFirstChild("PlayCelebrationEffect")
    if celebrationEvent then
        celebrationEvent.OnClientEvent:Connect(function(effectType, data)
            self:PlayCelebrationEffect(effectType, data)
        end)
    end
end

function VIPEffectsManager:SetupUpdateLoop()
    -- Update effects regularly
    self.UpdateConnection = RunService.Heartbeat:Connect(function()
        self:UpdateEffects()
    end)
end

-- ==========================================
-- CHARACTER EFFECTS
-- ==========================================

function VIPEffectsManager:OnCharacterAdded(character)
    self.Character = character
    
    -- Wait for character to fully load
    character:WaitForChild("HumanoidRootPart")
    wait(1)
    
    -- Apply VIP effects if player is VIP
    if self.IsVIP then
        self:ApplyPlayerVIPEffects()
    end
end

function VIPEffectsManager:OnCharacterRemoving(character)
    -- Clean up character effects
    self:RemovePlayerVIPEffects()
    self.Character = nil
end

function VIPEffectsManager:ApplyPlayerVIPEffects()
    if not self.Character or not self.Character:FindFirstChild("HumanoidRootPart") then
        return
    end
    
    -- Remove existing effects first
    self:RemovePlayerVIPEffects()
    
    -- Create golden glow effect
    self:CreatePlayerGlowEffect()
    
    -- Create particle effects
    self:CreatePlayerParticleEffects()
    
    -- Apply special animations
    self:ApplyVIPAnimations()
    
    print("✨ VIPEffectsManager: Applied VIP effects to player character")
end

function VIPEffectsManager:CreatePlayerGlowEffect()
    local humanoidRootPart = self.Character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    -- Create point light for glow
    self.PlayerGlowEffect = Instance.new("PointLight")
    self.PlayerGlowEffect.Name = "VIPGlow"
    self.PlayerGlowEffect.Color = self.GlowColors.primary
    self.PlayerGlowEffect.Brightness = self.EffectSettings.playerGlowIntensity
    self.PlayerGlowEffect.Range = 20
    self.PlayerGlowEffect.Parent = humanoidRootPart
    
    -- Create pulsing animation
    self:CreatePulsingGlow(self.PlayerGlowEffect)
    
    -- Add selection box for extra glow
    local selectionBox = Instance.new("SelectionBox")
    selectionBox.Name = "VIPSelectionGlow"
    selectionBox.Adornee = humanoidRootPart
    selectionBox.Color3 = self.GlowColors.primary
    selectionBox.LineThickness = 0.3
    selectionBox.Transparency = 0.7
    selectionBox.Parent = humanoidRootPart
    
    -- Animate selection box
    self:CreatePulsingEffect(selectionBox, "Transparency", 0.3, 0.8, 1.5)
end

function VIPEffectsManager:CreatePlayerParticleEffects()
    local humanoidRootPart = self.Character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    -- Create attachment for particles
    local attachment = Instance.new("Attachment")
    attachment.Name = "VIPParticleAttachment"
    attachment.Parent = humanoidRootPart
    
    -- Create golden sparkle particles
    local sparkleParticles = Instance.new("ParticleEmitter")
    sparkleParticles.Name = "VIPSparkles"
    sparkleParticles.Parent = attachment
    
    -- Configure sparkle properties
    sparkleParticles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    sparkleParticles.Color = ColorSequence.new(self.GlowColors.primary)
    sparkleParticles.Lifetime = NumberRange.new(0.5, 1.5)
    sparkleParticles.Rate = self.EffectSettings.particleRate
    sparkleParticles.SpreadAngle = Vector2.new(360, 360)
    sparkleParticles.Speed = NumberRange.new(2, 5)
    sparkleParticles.Acceleration = Vector3.new(0, 5, 0)
    
    -- Size and transparency
    sparkleParticles.Size = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.5, 1),
        NumberSequenceKeypoint.new(1, 0)
    }
    
    sparkleParticles.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.5, 0.3),
        NumberSequenceKeypoint.new(1, 1)
    }
end

function VIPEffectsManager:ApplyVIPAnimations()
    local humanoid = self.Character:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    -- Slight speed boost for VIP (visual only)
    humanoid.WalkSpeed = 16 -- Keep normal speed for fairness
    
    -- Add confident walking animation (if available)
    -- This would require custom animation IDs
end

function VIPEffectsManager:RemovePlayerVIPEffects()
    if self.Character then
        -- Remove glow effects
        local humanoidRootPart = self.Character:FindFirstChild("HumanoidRootPart")
        if humanoidRootPart then
            local glow = humanoidRootPart:FindFirstChild("VIPGlow")
            if glow then glow:Destroy() end
            
            local selectionGlow = humanoidRootPart:FindFirstChild("VIPSelectionGlow")
            if selectionGlow then selectionGlow:Destroy() end
            
            local particleAttachment = humanoidRootPart:FindFirstChild("VIPParticleAttachment")
            if particleAttachment then particleAttachment:Destroy() end
        end
    end
    
    self.PlayerGlowEffect = nil
end

-- ==========================================
-- PLOT EFFECTS
-- ==========================================

function VIPEffectsManager:ApplyPlotVIPEffects(plotId)
    if not self.IsVIP then return end
    
    local plotPart = self:FindPlotPart(plotId)
    if not plotPart then return end
    
    -- Remove existing effects
    self:RemovePlotEffects(plotId)
    
    -- Create plot effects container
    self.PlotEffects[plotId] = {}
    
    -- Create golden border effect
    self:CreatePlotBorderEffect(plotId, plotPart)
    
    -- Create subtle particle effects
    self:CreatePlotParticleEffects(plotId, plotPart)
    
    -- Create growth enhancement visual
    self:CreateGrowthEnhancementEffect(plotId, plotPart)
    
    print("✨ VIPEffectsManager: Applied VIP effects to plot", plotId)
end

function VIPEffectsManager:CreatePlotBorderEffect(plotId, plotPart)
    -- Create selection box for border
    local borderEffect = Instance.new("SelectionBox")
    borderEffect.Name = "VIPPlotBorder"
    borderEffect.Adornee = plotPart
    borderEffect.Color3 = self.GlowColors.secondary
    borderEffect.LineThickness = 0.15
    borderEffect.Transparency = 0.6
    borderEffect.Parent = plotPart
    
    -- Add to effects tracking
    self.PlotEffects[plotId].border = borderEffect
    
    -- Create subtle pulsing
    self:CreatePulsingEffect(borderEffect, "Transparency", 0.4, 0.8, 3)
end

function VIPEffectsManager:CreatePlotParticleEffects(plotId, plotPart)
    -- Create attachment at plot center
    local attachment = Instance.new("Attachment")
    attachment.Name = "VIPPlotParticles"
    attachment.Position = Vector3.new(0, plotPart.Size.Y/2 + 0.5, 0)
    attachment.Parent = plotPart
    
    -- Create gentle golden particles
    local particles = Instance.new("ParticleEmitter")
    particles.Name = "VIPPlotSparkles"
    particles.Parent = attachment
    
    -- Configure gentle sparkles
    particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    particles.Color = ColorSequence.new(self.GlowColors.accent)
    particles.Lifetime = NumberRange.new(1, 3)
    particles.Rate = 3 -- Subtle rate
    particles.SpreadAngle = Vector2.new(45, 45)
    particles.Speed = NumberRange.new(1, 2)
    particles.Acceleration = Vector3.new(0, 2, 0)
    
    particles.Size = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(0.5, 0.5),
        NumberSequenceKeypoint.new(1, 0)
    }
    
    particles.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 1)
    }
    
    -- Add to effects tracking
    self.PlotEffects[plotId].particles = attachment
end

function VIPEffectsManager:CreateGrowthEnhancementEffect(plotId, plotPart)
    -- Create point light for growth enhancement glow
    local growthLight = Instance.new("PointLight")
    growthLight.Name = "VIPGrowthBoost"
    growthLight.Color = Color3.fromRGB(100, 255, 100) -- Green for growth
    growthLight.Brightness = 0.5
    growthLight.Range = 8
    growthLight.Parent = plotPart
    
    -- Add to effects tracking
    self.PlotEffects[plotId].growthLight = growthLight
    
    -- Create pulsing growth effect
    self:CreatePulsingGlow(growthLight, 2.5)
end

function VIPEffectsManager:RemovePlotEffects(plotId)
    local effects = self.PlotEffects[plotId]
    if not effects then return end
    
    -- Clean up all effects
    for effectName, effectObject in pairs(effects) do
        if effectObject and effectObject.Parent then
            effectObject:Destroy()
        end
    end
    
    self.PlotEffects[plotId] = nil
end

function VIPEffectsManager:TriggerPlotEffect(plotId, effectType)
    if not self.IsVIP then return end
    
    local plotPart = self:FindPlotPart(plotId)
    if not plotPart then return end
    
    if effectType == "plant" then
        self:PlayPlantingEffect(plotPart)
    elseif effectType == "harvest" then
        self:PlayHarvestEffect(plotPart)
    elseif effectType == "growth" then
        self:PlayGrowthStageEffect(plotPart)
    end
end

function VIPEffectsManager:PlayPlantingEffect(plotPart)
    -- Create burst of golden particles
    local attachment = Instance.new("Attachment")
    attachment.Position = Vector3.new(0, plotPart.Size.Y/2, 0)
    attachment.Parent = plotPart
    
    local burstEffect = Instance.new("ParticleEmitter")
    burstEffect.Parent = attachment
    burstEffect.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    burstEffect.Color = ColorSequence.new(self.GlowColors.primary)
    burstEffect.Lifetime = NumberRange.new(0.5, 1)
    burstEffect.Rate = 50
    burstEffect.SpreadAngle = Vector2.new(360, 360)
    burstEffect.Speed = NumberRange.new(5, 10)
    
    -- Burst for short duration
    burstEffect.Enabled = true
    wait(0.2)
    burstEffect.Enabled = false
    
    -- Clean up after particles die
    wait(1.5)
    attachment:Destroy()
end

function VIPEffectsManager:PlayHarvestEffect(plotPart)
    -- Create coin shower effect
    local attachment = Instance.new("Attachment")
    attachment.Position = Vector3.new(0, plotPart.Size.Y/2 + 2, 0)
    attachment.Parent = plotPart
    
    local coinEffect = Instance.new("ParticleEmitter")
    coinEffect.Parent = attachment
    coinEffect.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    coinEffect.Color = ColorSequence.new(Color3.fromRGB(255, 215, 0))
    coinEffect.Lifetime = NumberRange.new(1, 2)
    coinEffect.Rate = 30
    coinEffect.SpreadAngle = Vector2.new(180, 180)
    coinEffect.Speed = NumberRange.new(3, 8)
    coinEffect.Acceleration = Vector3.new(0, -20, 0)
    
    -- Coin shower for short duration
    coinEffect.Enabled = true
    wait(0.5)
    coinEffect.Enabled = false
    
    -- Clean up
    wait(2.5)
    attachment:Destroy()
end

function VIPEffectsManager:PlayGrowthStageEffect(plotPart)
    -- Create green growth sparkles
    local attachment = Instance.new("Attachment")
    attachment.Position = Vector3.new(0, plotPart.Size.Y/2 + 1, 0)
    attachment.Parent = plotPart
    
    local growthEffect = Instance.new("ParticleEmitter")
    growthEffect.Parent = attachment
    growthEffect.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    growthEffect.Color = ColorSequence.new(Color3.fromRGB(100, 255, 100))
    growthEffect.Lifetime = NumberRange.new(0.8, 1.5)
    growthEffect.Rate = 20
    growthEffect.SpreadAngle = Vector2.new(45, 45)
    growthEffect.Speed = NumberRange.new(2, 4)
    growthEffect.Acceleration = Vector3.new(0, 5, 0)
    
    -- Growth effect duration
    growthEffect.Enabled = true
    wait(0.3)
    growthEffect.Enabled = false
    
    -- Clean up
    wait(2)
    attachment:Destroy()
end

-- ==========================================
-- UI EFFECTS
-- ==========================================

function VIPEffectsManager:ApplyUIVIPEffects(uiElement, effectType)
    if not self.IsVIP or not uiElement then return end
    
    if effectType == "glow" then
        self:AddUIGlowEffect(uiElement)
    elseif effectType == "border" then
        self:AddUIBorderEffect(uiElement)
    elseif effectType == "sparkle" then
        self:AddUISparkleEffect(uiElement)
    end
end

function VIPEffectsManager:AddUIGlowEffect(uiElement)
    -- Create UI stroke for glow
    local glowStroke = Instance.new("UIStroke")
    glowStroke.Name = "VIPGlow"
    glowStroke.Color = self.GlowColors.primary
    glowStroke.Thickness = 2
    glowStroke.Transparency = 0.3
    glowStroke.Parent = uiElement
    
    -- Store for tracking
    table.insert(self.UIEffects, glowStroke)
    
    -- Add pulsing animation
    self:CreatePulsingEffect(glowStroke, "Transparency", 0.2, 0.6, 2)
    
    return glowStroke
end

function VIPEffectsManager:AddUIBorderEffect(uiElement)
    -- Create golden border
    local borderStroke = Instance.new("UIStroke")
    borderStroke.Name = "VIPBorder"
    borderStroke.Color = self.GlowColors.secondary
    borderStroke.Thickness = 1
    borderStroke.Transparency = 0.1
    borderStroke.Parent = uiElement
    
    table.insert(self.UIEffects, borderStroke)
    return borderStroke
end

function VIPEffectsManager:RemoveUIVIPEffects(uiElement)
    if not uiElement then return end
    
    local vipGlow = uiElement:FindFirstChild("VIPGlow")
    if vipGlow then vipGlow:Destroy() end
    
    local vipBorder = uiElement:FindFirstChild("VIPBorder")
    if vipBorder then vipBorder:Destroy() end
end

-- ==========================================
-- CELEBRATION EFFECTS
-- ==========================================

function VIPEffectsManager:PlayCelebrationEffect(effectType, data)
    if not self.IsVIP then return end
    
    if effectType == "daily_bonus" then
        self:PlayDailyBonusCelebration(data)
    elseif effectType == "level_up" then
        self:PlayLevelUpCelebration(data)
    elseif effectType == "vip_purchase" then
        self:PlayVIPPurchaseCelebration()
    end
end

function VIPEffectsManager:PlayDailyBonusCelebration(data)
    -- Create screen-wide golden sparkles
    local celebrationGui = Instance.new("ScreenGui")
    celebrationGui.Name = "VIPCelebration"
    celebrationGui.Parent = self.Player:WaitForChild("PlayerGui")
    
    -- Create multiple sparkle emitters across screen
    for i = 1, 5 do
        local sparkleFrame = Instance.new("Frame")
        sparkleFrame.Size = UDim2.new(0, 1, 0, 1)
        sparkleFrame.Position = UDim2.new(math.random(0, 100)/100, 0, math.random(0, 100)/100, 0)
        sparkleFrame.BackgroundTransparency = 1
        sparkleFrame.Parent = celebrationGui
        
        -- Animate sparkles
        self:CreateUISparkleAnimation(sparkleFrame)
    end
    
    -- Clean up after celebration
    wait(3)
    celebrationGui:Destroy()
end

function VIPEffectsManager:PlayVIPPurchaseCelebration()
    -- Special celebration for new VIP
    if self.Character and self.Character:FindFirstChild("HumanoidRootPart") then
        local humanoidRootPart = self.Character.HumanoidRootPart
        
        -- Create massive golden explosion
        local attachment = Instance.new("Attachment")
        attachment.Parent = humanoidRootPart
        
        local explosionEffect = Instance.new("ParticleEmitter")
        explosionEffect.Parent = attachment
        explosionEffect.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        explosionEffect.Color = ColorSequence.new(self.GlowColors.primary)
        explosionEffect.Lifetime = NumberRange.new(2, 4)
        explosionEffect.Rate = 200
        explosionEffect.SpreadAngle = Vector2.new(360, 360)
        explosionEffect.Speed = NumberRange.new(10, 25)
        explosionEffect.Acceleration = Vector3.new(0, -10, 0)
        
        explosionEffect.Size = NumberSequence.new{
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.3, 2),
            NumberSequenceKeypoint.new(1, 0)
        }
        
        explosionEffect.Enabled = true
        wait(1)
        explosionEffect.Enabled = false
        
        wait(5)
        attachment:Destroy()
    end
end

-- ==========================================
-- ANIMATION UTILITIES
-- ==========================================

function VIPEffectsManager:CreatePulsingGlow(lightObject, speed)
    speed = speed or self.EffectSettings.pulseSpeed
    
    local pulseTween = TweenService:Create(
        lightObject,
        TweenInfo.new(speed/2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {Brightness = lightObject.Brightness * 1.5}
    )
    
    pulseTween:Play()
    table.insert(self.ActiveTweens, pulseTween)
    
    return pulseTween
end

function VIPEffectsManager:CreatePulsingEffect(object, property, minValue, maxValue, speed)
    speed = speed or 2
    
    local pulseTween = TweenService:Create(
        object,
        TweenInfo.new(speed/2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {[property] = maxValue}
    )
    
    pulseTween:Play()
    table.insert(self.ActiveTweens, pulseTween)
    
    return pulseTween
end

function VIPEffectsManager:CreateUISparkleAnimation(frame)
    -- Create sparkle text
    local sparkle = Instance.new("TextLabel")
    sparkle.Size = UDim2.new(0, 20, 0, 20)
    sparkle.BackgroundTransparency = 1
    sparkle.Text = "✨"
    sparkle.TextScaled = true
    sparkle.TextColor3 = self.GlowColors.primary
    sparkle.Parent = frame
    
    -- Animate movement and fading
    local moveTween = TweenService:Create(sparkle, TweenInfo.new(2, Enum.EasingStyle.Quad), {
        Position = UDim2.new(0, math.random(-50, 50), 0, -100),
        TextTransparency = 1
    })
    
    moveTween:Play()
    moveTween.Completed:Connect(function()
        sparkle:Destroy()
    end)
end

-- ==========================================
-- STATUS MANAGEMENT
-- ==========================================

function VIPEffectsManager:UpdateVIPStatus()
    -- Check VIP status from server
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if remoteEvents then
        local getVIPStatusFunction = remoteEvents:FindFirstChild("GetVIPStatus")
        if getVIPStatusFunction then
            local isVIP = getVIPStatusFunction:InvokeServer()
            
            if isVIP ~= self.IsVIP then
                self:OnVIPStatusChanged(isVIP)
            end
        end
    end
end

function VIPEffectsManager:OnVIPStatusChanged(isVIP)
    local wasVIP = self.IsVIP
    self.IsVIP = isVIP
    
    if isVIP and not wasVIP then
        -- Became VIP
        self:ApplyPlayerVIPEffects()
        self:ApplyAllPlotVIPEffects()
        self:PlayVIPPurchaseCelebration()
        print("✨ VIPEffectsManager: Player became VIP - applying effects")
        
    elseif not isVIP and wasVIP then
        -- Lost VIP status
        self:RemoveAllVIPEffects()
        print("✨ VIPEffectsManager: Player lost VIP status - removing effects")
    end
end

function VIPEffectsManager:ApplyAllPlotVIPEffects()
    -- Apply VIP effects to all player plots
    for plotId = 1, 8 do -- Assuming 8 plots max
        self:ApplyPlotVIPEffects(plotId)
    end
end

function VIPEffectsManager:RemoveAllVIPEffects()
    -- Remove player effects
    self:RemovePlayerVIPEffects()
    
    -- Remove all plot effects
    for plotId, effects in pairs(self.PlotEffects) do
        self:RemovePlotEffects(plotId)
    end
    
    -- Remove UI effects
    for _, uiEffect in ipairs(self.UIEffects) do
        if uiEffect and uiEffect.Parent then
            uiEffect:Destroy()
        end
    end
    self.UIEffects = {}
    
    -- Stop all tweens
    for _, tween in ipairs(self.ActiveTweens) do
        if tween then
            tween:Cancel()
        end
    end
    self.ActiveTweens = {}
end

-- ==========================================
-- UTILITY FUNCTIONS
-- ==========================================

function VIPEffectsManager:FindPlotPart(plotId)
    local plotsFolder = workspace:FindFirstChild("Plots")
    if plotsFolder then
        for _, plot in pairs(plotsFolder:GetChildren()) do
            if plot:GetAttribute("PlotId") == plotId then
                return plot
            end
        end
    end
    return nil
end

function VIPEffectsManager:UpdateEffects()
    -- Update effect intensities based on distance and performance
    if not self.Character then return end
    
    local humanoidRootPart = self.Character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    local playerPosition = humanoidRootPart.Position
    
    -- Update plot effects based on distance
    for plotId, effects in pairs(self.PlotEffects) do
        local plotPart = self:FindPlotPart(plotId)
        if plotPart then
            local distance = (playerPosition - plotPart.Position).Magnitude
            
            -- Reduce effects if too far away
            if distance > self.EffectSettings.maxEffectDistance then
                self:SetPlotEffectsEnabled(plotId, false)
            else
                self:SetPlotEffectsEnabled(plotId, true)
            end
        end
    end
end

function VIPEffectsManager:SetPlotEffectsEnabled(plotId, enabled)
    local effects = self.PlotEffects[plotId]
    if not effects then return end
    
    -- Enable/disable particles
    if effects.particles then
        local particleEmitter = effects.particles:FindFirstChild("VIPPlotSparkles")
        if particleEmitter then
            particleEmitter.Enabled = enabled
        end
    end
    
    -- Adjust light brightness
    if effects.growthLight then
        effects.growthLight.Enabled = enabled
    end
end

-- ==========================================
-- PUBLIC API
-- ==========================================

function VIPEffectsManager:IsPlayerVIP()
    return self.IsVIP
end

function VIPEffectsManager:ForceRefreshEffects()
    if self.IsVIP then
        self:RemoveAllVIPEffects()
        wait(0.1)
        self:ApplyPlayerVIPEffects()
        self:ApplyAllPlotVIPEffects()
    end
end

function VIPEffectsManager:GetEffectIntensity()
    return self.EffectSettings.playerGlowIntensity
end

function VIPEffectsManager:SetEffectIntensity(intensity)
    self.EffectSettings.playerGlowIntensity = intensity
    self.EffectSettings.plotGlowIntensity = intensity * 0.75
    
    -- Update existing effects
    if self.PlayerGlowEffect then
        self.PlayerGlowEffect.Brightness = intensity
    end
end

-- ==========================================
-- CLEANUP
-- ==========================================

function VIPEffectsManager:Cleanup()
    -- Stop update loop
    if self.UpdateConnection then
        self.UpdateConnection:Disconnect()
    end
    
    -- Remove all effects
    self:RemoveAllVIPEffects()
    
    print("✨ VIPEffectsManager: Cleaned up all effects")
end

return VIPEffectsManager
