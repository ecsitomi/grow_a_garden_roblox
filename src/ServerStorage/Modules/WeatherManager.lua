--[[
    WeatherManager.lua
    Server-Side Dynamic Weather System
    
    Priority: 27 (Advanced Features phase)
    Dependencies: TweenService, Lighting, SoundService
    Used by: PlantManager, QuestManager, VIPEffectsManager
    
    Features:
    - Dynamic weather patterns (rain, sun, drought, storm)
    - Seasonal changes and cycles
    - Weather effects on plant growth
    - VIP weather prediction and control
    - Visual and audio weather effects
    - Weather-based quests and events
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

-- Load required modules
local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)

local WeatherManager = {}
WeatherManager.__index = WeatherManager

-- ==========================================
-- INITIALIZATION & SETUP
-- ==========================================

-- Weather state
WeatherManager.CurrentWeather = "sunny"
WeatherManager.WeatherDuration = 0
WeatherManager.WeatherStartTime = 0
WeatherManager.NextWeatherTime = 0

-- Weather patterns
WeatherManager.WeatherTypes = {
    SUNNY = "sunny",
    CLOUDY = "cloudy", 
    RAINY = "rainy",
    STORMY = "stormy",
    DROUGHT = "drought",
    FOGGY = "foggy",
    WINDY = "windy"
}

-- Seasonal system
WeatherManager.CurrentSeason = "spring"
WeatherManager.SeasonStartTime = 0
WeatherManager.SeasonDuration = 3600 -- 1 hour per season

WeatherManager.Seasons = {
    SPRING = "spring",
    SUMMER = "summer", 
    AUTUMN = "autumn",
    WINTER = "winter"
}

-- Weather effects configuration
WeatherManager.WeatherEffects = {
    sunny = {
        duration = {min = 300, max = 600}, -- 5-10 minutes
        probability = 0.35,
        plantGrowthMultiplier = 1.0,
        lighting = {
            brightness = 2.0,
            ambientColor = Color3.fromRGB(135, 206, 235),
            colorShift_Top = Color3.fromRGB(255, 248, 220),
            fogEnd = 2000,
            fogStart = 0
        },
        particles = nil,
        sounds = {"birds_chirping", "gentle_breeze"}
    },
    
    cloudy = {
        duration = {min = 240, max = 480}, -- 4-8 minutes
        probability = 0.25,
        plantGrowthMultiplier = 0.9,
        lighting = {
            brightness = 1.2,
            ambientColor = Color3.fromRGB(128, 128, 128),
            colorShift_Top = Color3.fromRGB(200, 200, 200),
            fogEnd = 1500,
            fogStart = 0
        },
        particles = nil,
        sounds = {"wind_medium"}
    },
    
    rainy = {
        duration = {min = 180, max = 360}, -- 3-6 minutes
        probability = 0.2,
        plantGrowthMultiplier = 1.5, -- Rain boosts growth
        lighting = {
            brightness = 0.8,
            ambientColor = Color3.fromRGB(64, 64, 96),
            colorShift_Top = Color3.fromRGB(128, 128, 160),
            fogEnd = 800,
            fogStart = 100
        },
        particles = "rain",
        sounds = {"rain_light", "thunder_distant"}
    },
    
    stormy = {
        duration = {min = 120, max = 240}, -- 2-4 minutes
        probability = 0.08,
        plantGrowthMultiplier = 1.2,
        lighting = {
            brightness = 0.5,
            ambientColor = Color3.fromRGB(32, 32, 64),
            colorShift_Top = Color3.fromRGB(64, 64, 128),
            fogEnd = 400,
            fogStart = 50
        },
        particles = "storm",
        sounds = {"rain_heavy", "thunder_close", "wind_strong"},
        lightningEnabled = true
    },
    
    drought = {
        duration = {min = 600, max = 900}, -- 10-15 minutes
        probability = 0.05,
        plantGrowthMultiplier = 0.5, -- Drought slows growth
        lighting = {
            brightness = 2.5,
            ambientColor = Color3.fromRGB(255, 228, 181),
            colorShift_Top = Color3.fromRGB(255, 165, 0),
            fogEnd = 3000,
            fogStart = 0
        },
        particles = "dust",
        sounds = {"wind_dry", "heat_shimmer"}
    },
    
    foggy = {
        duration = {min = 300, max = 500}, -- 5-8 minutes
        probability = 0.05,
        plantGrowthMultiplier = 0.8,
        lighting = {
            brightness = 0.6,
            ambientColor = Color3.fromRGB(192, 192, 192),
            colorShift_Top = Color3.fromRGB(224, 224, 224),
            fogEnd = 200,
            fogStart = 0
        },
        particles = "fog",
        sounds = {"fog_ambience"}
    },
    
    windy = {
        duration = {min = 240, max = 480}, -- 4-8 minutes
        probability = 0.02,
        plantGrowthMultiplier = 1.1,
        lighting = {
            brightness = 1.5,
            ambientColor = Color3.fromRGB(173, 216, 230),
            colorShift_Top = Color3.fromRGB(135, 206, 235),
            fogEnd = 2500,
            fogStart = 0
        },
        particles = "wind",
        sounds = {"wind_strong", "leaves_rustling"}
    }
}

-- Seasonal weather patterns
WeatherManager.SeasonalWeather = {
    spring = {
        commonWeather = {"sunny", "rainy", "cloudy"},
        rareWeather = {"stormy"},
        bonusGrowthMultiplier = 1.2,
        specialEvents = {"flower_bloom"}
    },
    
    summer = {
        commonWeather = {"sunny", "drought", "cloudy"},
        rareWeather = {"stormy", "windy"},
        bonusGrowthMultiplier = 1.0,
        specialEvents = {"heat_wave"}
    },
    
    autumn = {
        commonWeather = {"cloudy", "windy", "rainy"},
        rareWeather = {"foggy"},
        bonusGrowthMultiplier = 0.9,
        specialEvents = {"harvest_festival"}
    },
    
    winter = {
        commonWeather = {"cloudy", "foggy"},
        rareWeather = {"stormy"},
        bonusGrowthMultiplier = 0.7,
        specialEvents = {"frost"}
    }
}

-- Weather effects objects
WeatherManager.ActiveParticles = {}
WeatherManager.ActiveSounds = {}
WeatherManager.ActiveTweens = {}

-- VIP weather features
WeatherManager.VIPWeatherPredictions = {}
WeatherManager.VIPWeatherRequests = {}

-- ==========================================
-- INITIALIZATION
-- ==========================================

function WeatherManager:Initialize()
    print("🌦️ WeatherManager: Initializing weather system...")
    
    -- Initialize weather state
    self:InitializeWeatherState()
    
    -- Set up remote events
    self:SetupRemoteEvents()
    
    -- Set up seasonal system
    self:InitializeSeasonalSystem()
    
    -- Start weather management loop
    self:StartWeatherLoop()
    
    -- Set up VIP features
    self:SetupVIPWeatherFeatures()
    
    -- Initialize first weather
    self:StartWeatherPattern("sunny")
    
    print("✅ WeatherManager: Weather system initialized")
end

function WeatherManager:InitializeWeatherState()
    local currentTime = tick()
    
    self.WeatherStartTime = currentTime
    self.NextWeatherTime = currentTime + math.random(300, 600) -- 5-10 minutes until first change
    self.SeasonStartTime = currentTime
    
    -- Determine starting season based on real world time
    local month = tonumber(os.date("%m"))
    if month >= 3 and month <= 5 then
        self.CurrentSeason = self.Seasons.SPRING
    elseif month >= 6 and month <= 8 then
        self.CurrentSeason = self.Seasons.SUMMER
    elseif month >= 9 and month <= 11 then
        self.CurrentSeason = self.Seasons.AUTUMN
    else
        self.CurrentSeason = self.Seasons.WINTER
    end
end

function WeatherManager:SetupRemoteEvents()
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then
        remoteEvents = Instance.new("Folder")
        remoteEvents.Name = "RemoteEvents"
        remoteEvents.Parent = ReplicatedStorage
    end
    
    -- Weather state sync
    local weatherStateEvent = Instance.new("RemoteEvent")
    weatherStateEvent.Name = "WeatherStateUpdate"
    weatherStateEvent.Parent = remoteEvents
    
    -- VIP weather prediction
    local weatherPredictionFunction = Instance.new("RemoteFunction")
    weatherPredictionFunction.Name = "GetWeatherPrediction"
    weatherPredictionFunction.Parent = remoteEvents
    weatherPredictionFunction.OnServerInvoke = function(player)
        return self:GetVIPWeatherPrediction(player)
    end
    
    -- VIP weather request
    local weatherRequestFunction = Instance.new("RemoteFunction")
    weatherRequestFunction.Name = "RequestWeatherChange"
    weatherRequestFunction.Parent = remoteEvents
    weatherRequestFunction.OnServerInvoke = function(player, weatherType)
        return self:ProcessVIPWeatherRequest(player, weatherType)
    end
end

function WeatherManager:InitializeSeasonalSystem()
    -- Calculate season progression
    local currentTime = tick()
    local seasonProgress = (currentTime - self.SeasonStartTime) / self.SeasonDuration
    
    if seasonProgress >= 1.0 then
        self:AdvanceSeason()
    end
end

function WeatherManager:SetupVIPWeatherFeatures()
    -- Initialize VIP weather predictions for all VIP players
    for _, player in pairs(Players:GetPlayers()) do
        if self:IsPlayerVIP(player) then
            self:GenerateVIPWeatherPrediction(player)
        end
    end
end

function WeatherManager:StartWeatherLoop()
    spawn(function()
        while true do
            local currentTime = tick()
            
            -- Check for weather changes
            if currentTime >= self.NextWeatherTime then
                self:ChangeWeather()
            end
            
            -- Check for seasonal changes
            if currentTime >= self.SeasonStartTime + self.SeasonDuration then
                self:AdvanceSeason()
            end
            
            -- Update weather effects
            self:UpdateWeatherEffects()
            
            -- Update VIP predictions
            self:UpdateVIPPredictions()
            
            wait(30) -- Update every 30 seconds
        end
    end)
end

-- ==========================================
-- WEATHER MANAGEMENT
-- ==========================================

function WeatherManager:ChangeWeather()
    local newWeather = self:SelectNextWeather()
    self:StartWeatherPattern(newWeather)
end

function WeatherManager:SelectNextWeather()
    local seasonData = self.SeasonalWeather[self.CurrentSeason]
    local weatherOptions = {}
    
    -- Build weighted weather options based on season
    for _, weather in ipairs(seasonData.commonWeather) do
        local weight = self.WeatherEffects[weather].probability * 100
        for i = 1, weight do
            table.insert(weatherOptions, weather)
        end
    end
    
    -- Add rare weather with lower probability
    for _, weather in ipairs(seasonData.rareWeather) do
        local weight = self.WeatherEffects[weather].probability * 50 -- Reduced for rare
        for i = 1, weight do
            table.insert(weatherOptions, weather)
        end
    end
    
    -- Avoid repeating the same weather immediately
    if #weatherOptions > 1 then
        for i = #weatherOptions, 1, -1 do
            if weatherOptions[i] == self.CurrentWeather then
                table.remove(weatherOptions, i)
            end
        end
    end
    
    -- Select random weather
    if #weatherOptions > 0 then
        return weatherOptions[math.random(1, #weatherOptions)]
    else
        return self.WeatherTypes.SUNNY -- Fallback
    end
end

function WeatherManager:StartWeatherPattern(weatherType)
    if not self.WeatherEffects[weatherType] then
        warn("❌ WeatherManager: Unknown weather type:", weatherType)
        return
    end
    
    -- Clean up previous weather
    self:CleanupCurrentWeather()
    
    local weatherData = self.WeatherEffects[weatherType]
    local currentTime = tick()
    
    -- Set new weather state
    self.CurrentWeather = weatherType
    self.WeatherStartTime = currentTime
    self.WeatherDuration = math.random(weatherData.duration.min, weatherData.duration.max)
    self.NextWeatherTime = currentTime + self.WeatherDuration
    
    -- Apply weather effects
    self:ApplyLightingEffects(weatherData.lighting)
    self:StartParticleEffects(weatherData.particles)
    self:StartSoundEffects(weatherData.sounds)
    
    -- Special weather effects
    if weatherData.lightningEnabled then
        self:StartLightningEffects()
    end
    
    -- Notify systems about weather change
    self:NotifyWeatherChange(weatherType, weatherData.plantGrowthMultiplier)
    
    -- Send to clients
    self:BroadcastWeatherUpdate()
    
    -- Update VIP predictions
    self:UpdateVIPPredictions()
    
    print("🌦️ WeatherManager: Weather changed to", weatherType, "for", self.WeatherDuration, "seconds")
end

function WeatherManager:ApplyLightingEffects(lightingData)
    local tweenInfo = TweenInfo.new(
        30, -- 30 second transition
        Enum.EasingStyle.Sine,
        Enum.EasingDirection.InOut
    )
    
    -- Tween lighting properties
    local lightingTween = TweenService:Create(Lighting, tweenInfo, {
        Brightness = lightingData.brightness,
        Ambient = lightingData.ambientColor,
        ColorShift_Top = lightingData.colorShift_Top,
        FogEnd = lightingData.fogEnd,
        FogStart = lightingData.fogStart
    })
    
    lightingTween:Play()
    table.insert(self.ActiveTweens, lightingTween)
end

function WeatherManager:StartParticleEffects(particleType)
    if not particleType then return end
    
    spawn(function()
        if particleType == "rain" then
            self:CreateRainEffect()
        elseif particleType == "storm" then
            self:CreateStormEffect()
        elseif particleType == "dust" then
            self:CreateDustEffect()
        elseif particleType == "fog" then
            self:CreateFogEffect()
        elseif particleType == "wind" then
            self:CreateWindEffect()
        end
    end)
end

function WeatherManager:CreateRainEffect()
    -- Create rain particles across the map
    local spawnLocation = workspace:FindFirstChild("SpawnLocation")
    if not spawnLocation then return end
    
    for i = 1, 10 do
        local rainEmitter = Instance.new("ParticleEmitter")
        rainEmitter.Parent = spawnLocation
        
        -- Rain particle properties
        rainEmitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
        rainEmitter.Color = ColorSequence.new(Color3.fromRGB(173, 216, 230))
        rainEmitter.Size = NumberSequence.new(0.1, 0.3)
        rainEmitter.Transparency = NumberSequence.new(0.3, 0.8)
        rainEmitter.Lifetime = NumberRange.new(2, 4)
        rainEmitter.Rate = 50
        rainEmitter.SpreadAngle = Vector2.new(5, 5)
        rainEmitter.Speed = NumberRange.new(10, 15)
        rainEmitter.Acceleration = Vector3.new(0, -20, 0)
        
        table.insert(self.ActiveParticles, rainEmitter)
    end
end

function WeatherManager:CreateStormEffect()
    -- Create more intense rain with wind
    self:CreateRainEffect()
    
    local spawnLocation = workspace:FindFirstChild("SpawnLocation")
    if not spawnLocation then return end
    
    -- Add wind particles
    local windEmitter = Instance.new("ParticleEmitter")
    windEmitter.Parent = spawnLocation
    
    windEmitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
    windEmitter.Color = ColorSequence.new(Color3.fromRGB(200, 200, 200))
    windEmitter.Size = NumberSequence.new(1, 3)
    windEmitter.Transparency = NumberSequence.new(0.7, 1)
    windEmitter.Lifetime = NumberRange.new(3, 6)
    windEmitter.Rate = 30
    windEmitter.SpreadAngle = Vector2.new(45, 45)
    windEmitter.Speed = NumberRange.new(5, 10)
    windEmitter.Acceleration = Vector3.new(15, -5, 0)
    
    table.insert(self.ActiveParticles, windEmitter)
end

function WeatherManager:CreateDustEffect()
    local spawnLocation = workspace:FindFirstChild("SpawnLocation")
    if not spawnLocation then return end
    
    local dustEmitter = Instance.new("ParticleEmitter")
    dustEmitter.Parent = spawnLocation
    
    dustEmitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
    dustEmitter.Color = ColorSequence.new(Color3.fromRGB(222, 184, 135))
    dustEmitter.Size = NumberSequence.new(0.5, 2)
    dustEmitter.Transparency = NumberSequence.new(0.5, 1)
    dustEmitter.Lifetime = NumberRange.new(4, 8)
    dustEmitter.Rate = 20
    dustEmitter.SpreadAngle = Vector2.new(30, 30)
    dustEmitter.Speed = NumberRange.new(2, 5)
    dustEmitter.Acceleration = Vector3.new(3, 1, 0)
    
    table.insert(self.ActiveParticles, dustEmitter)
end

function WeatherManager:CreateFogEffect()
    local spawnLocation = workspace:FindFirstChild("SpawnLocation")
    if not spawnLocation then return end
    
    local fogEmitter = Instance.new("ParticleEmitter")
    fogEmitter.Parent = spawnLocation
    
    fogEmitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
    fogEmitter.Color = ColorSequence.new(Color3.fromRGB(245, 245, 245))
    fogEmitter.Size = NumberSequence.new(3, 8)
    fogEmitter.Transparency = NumberSequence.new(0.8, 1)
    fogEmitter.Lifetime = NumberRange.new(10, 20)
    fogEmitter.Rate = 10
    fogEmitter.SpreadAngle = Vector2.new(180, 180)
    fogEmitter.Speed = NumberRange.new(0.5, 1)
    fogEmitter.Acceleration = Vector3.new(0, 0.5, 0)
    
    table.insert(self.ActiveParticles, fogEmitter)
end

function WeatherManager:CreateWindEffect()
    local spawnLocation = workspace:FindFirstChild("SpawnLocation")
    if not spawnLocation then return end
    
    -- Create swirling wind particles
    for i = 1, 5 do
        local windEmitter = Instance.new("ParticleEmitter")
        windEmitter.Parent = spawnLocation
        
        windEmitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
        windEmitter.Color = ColorSequence.new(Color3.fromRGB(240, 248, 255))
        windEmitter.Size = NumberSequence.new(1, 4)
        windEmitter.Transparency = NumberSequence.new(0.9, 1)
        windEmitter.Lifetime = NumberRange.new(5, 10)
        windEmitter.Rate = 15
        windEmitter.SpreadAngle = Vector2.new(90, 90)
        windEmitter.Speed = NumberRange.new(8, 12)
        windEmitter.Acceleration = Vector3.new(math.random(-5, 5), 2, math.random(-5, 5))
        
        table.insert(self.ActiveParticles, windEmitter)
    end
end

function WeatherManager:StartSoundEffects(soundList)
    if not soundList then return end
    
    for _, soundName in ipairs(soundList) do
        local sound = self:CreateWeatherSound(soundName)
        if sound then
            sound:Play()
            table.insert(self.ActiveSounds, sound)
        end
    end
end

function WeatherManager:CreateWeatherSound(soundName)
    local soundId = self:GetSoundId(soundName)
    if not soundId then return nil end
    
    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Volume = 0.3
    sound.Looped = true
    sound.Parent = workspace
    
    return sound
end

function WeatherManager:GetSoundId(soundName)
    -- Placeholder sound IDs - replace with actual Roblox sound IDs
    local soundIds = {
        birds_chirping = "rbxassetid://131961136",
        gentle_breeze = "rbxassetid://131961136", 
        wind_medium = "rbxassetid://131961136",
        rain_light = "rbxassetid://131961136",
        thunder_distant = "rbxassetid://131961136",
        rain_heavy = "rbxassetid://131961136",
        thunder_close = "rbxassetid://131961136",
        wind_strong = "rbxassetid://131961136",
        wind_dry = "rbxassetid://131961136",
        heat_shimmer = "rbxassetid://131961136",
        fog_ambience = "rbxassetid://131961136",
        leaves_rustling = "rbxassetid://131961136"
    }
    
    return soundIds[soundName]
end

function WeatherManager:StartLightningEffects()
    spawn(function()
        while self.CurrentWeather == self.WeatherTypes.STORMY do
            wait(math.random(10, 30)) -- Lightning every 10-30 seconds
            
            if self.CurrentWeather == self.WeatherTypes.STORMY then
                self:CreateLightningFlash()
            end
        end
    end)
end

function WeatherManager:CreateLightningFlash()
    -- Brief lightning flash effect
    local originalBrightness = Lighting.Brightness
    
    Lighting.Brightness = 5
    wait(0.1)
    Lighting.Brightness = originalBrightness
    
    -- Play thunder sound
    spawn(function()
        wait(math.random(1, 3)) -- Thunder delay
        local thunder = self:CreateWeatherSound("thunder_close")
        if thunder then
            thunder.Looped = false
            thunder:Play()
            Debris:AddItem(thunder, 5)
        end
    end)
end

function WeatherManager:CleanupCurrentWeather()
    -- Stop all active particle effects
    for _, particle in ipairs(self.ActiveParticles) do
        if particle and particle.Parent then
            particle.Enabled = false
            Debris:AddItem(particle, 5)
        end
    end
    self.ActiveParticles = {}
    
    -- Stop all active sounds
    for _, sound in ipairs(self.ActiveSounds) do
        if sound and sound.Parent then
            sound:Stop()
            sound:Destroy()
        end
    end
    self.ActiveSounds = {}
    
    -- Stop all active tweens
    for _, tween in ipairs(self.ActiveTweens) do
        if tween then
            tween:Cancel()
        end
    end
    self.ActiveTweens = {}
end

-- ==========================================
-- SEASONAL SYSTEM
-- ==========================================

function WeatherManager:AdvanceSeason()
    local seasons = {self.Seasons.SPRING, self.Seasons.SUMMER, self.Seasons.AUTUMN, self.Seasons.WINTER}
    local currentIndex = 1
    
    -- Find current season index
    for i, season in ipairs(seasons) do
        if season == self.CurrentSeason then
            currentIndex = i
            break
        end
    end
    
    -- Advance to next season
    currentIndex = currentIndex + 1
    if currentIndex > #seasons then
        currentIndex = 1
    end
    
    self.CurrentSeason = seasons[currentIndex]
    self.SeasonStartTime = tick()
    
    -- Trigger seasonal events
    self:TriggerSeasonalEvent()
    
    -- Notify all systems
    self:NotifySeasonChange()
    
    print("🌦️ WeatherManager: Season changed to", self.CurrentSeason)
end

function WeatherManager:TriggerSeasonalEvent()
    local seasonData = self.SeasonalWeather[self.CurrentSeason]
    
    if seasonData.specialEvents then
        for _, event in ipairs(seasonData.specialEvents) do
            self:HandleSeasonalEvent(event)
        end
    end
end

function WeatherManager:HandleSeasonalEvent(eventType)
    if eventType == "flower_bloom" then
        -- Spring flower bloom event
        self:BroadcastSpecialEvent("flower_bloom", "Spring Flower Bloom! 🌸 All plants grow 50% faster for the next hour!")
        
    elseif eventType == "heat_wave" then
        -- Summer heat wave
        self:BroadcastSpecialEvent("heat_wave", "Heat Wave! ☀️ Drought weather is more likely for the next day.")
        
    elseif eventType == "harvest_festival" then
        -- Autumn harvest festival
        self:BroadcastSpecialEvent("harvest_festival", "Harvest Festival! 🍂 Double harvest rewards for the next hour!")
        
    elseif eventType == "frost" then
        -- Winter frost
        self:BroadcastSpecialEvent("frost", "Frost Warning! ❄️ Plant growth slowed, but rare winter plants may appear!")
    end
end

-- ==========================================
-- VIP WEATHER FEATURES
-- ==========================================

function WeatherManager:GenerateVIPWeatherPrediction(player)
    if not self:IsPlayerVIP(player) then return end
    
    local prediction = {}
    local currentTime = tick()
    
    -- Predict next 3 weather changes
    for i = 1, 3 do
        local futureTime = currentTime + (self.WeatherDuration * i)
        local predictedWeather = self:SelectNextWeather()
        
        table.insert(prediction, {
            time = futureTime,
            weather = predictedWeather,
            duration = math.random(
                self.WeatherEffects[predictedWeather].duration.min,
                self.WeatherEffects[predictedWeather].duration.max
            )
        })
    end
    
    self.VIPWeatherPredictions[player.UserId] = prediction
end

function WeatherManager:GetVIPWeatherPrediction(player)
    if not self:IsPlayerVIP(player) then
        return nil
    end
    
    local prediction = self.VIPWeatherPredictions[player.UserId]
    if not prediction then
        self:GenerateVIPWeatherPrediction(player)
        prediction = self.VIPWeatherPredictions[player.UserId]
    end
    
    return {
        currentWeather = self.CurrentWeather,
        currentSeason = self.CurrentSeason,
        timeRemaining = self.NextWeatherTime - tick(),
        prediction = prediction
    }
end

function WeatherManager:ProcessVIPWeatherRequest(player, weatherType)
    if not self:IsPlayerVIP(player) then
        return {success = false, message = "VIP membership required"}
    end
    
    -- Check if weather type is valid
    if not self.WeatherEffects[weatherType] then
        return {success = false, message = "Invalid weather type"}
    end
    
    -- Check cooldown (VIP can request weather change once per hour)
    local lastRequest = self.VIPWeatherRequests[player.UserId]
    if lastRequest and (tick() - lastRequest) < 3600 then
        local remaining = 3600 - (tick() - lastRequest)
        return {success = false, message = "Cooldown remaining: " .. math.floor(remaining / 60) .. " minutes"}
    end
    
    -- Process weather change request
    self.VIPWeatherRequests[player.UserId] = tick()
    self:StartWeatherPattern(weatherType)
    
    -- Notify all players
    local notificationManager = _G.NotificationManager
    if notificationManager then
        for _, p in pairs(Players:GetPlayers()) do
            notificationManager:ShowToast(
                "VIP Weather Control! 👑",
                player.Name .. " changed the weather to " .. weatherType,
                "🌦️",
                "vip"
            )
        end
    end
    
    return {success = true, message = "Weather changed to " .. weatherType}
end

function WeatherManager:UpdateVIPPredictions()
    -- Update predictions for all VIP players
    for _, player in pairs(Players:GetPlayers()) do
        if self:IsPlayerVIP(player) then
            self:GenerateVIPWeatherPrediction(player)
        end
    end
end

-- ==========================================
-- SYSTEM INTEGRATION
-- ==========================================

function WeatherManager:NotifyWeatherChange(weatherType, growthMultiplier)
    -- Notify PlantManager about growth effects
    local plantManager = _G.PlantManager
    if plantManager then
        plantManager:ApplyWeatherEffect(weatherType, growthMultiplier)
    end
    
    -- Notify QuestManager for weather-based quests
    local questManager = _G.QuestManager
    if questManager then
        for _, player in pairs(Players:GetPlayers()) do
            questManager:UpdateQuestProgress(player, "weather_change", {
                weatherType = weatherType,
                season = self.CurrentSeason
            })
        end
    end
    
    -- Notify achievement system
    local achievementManager = _G.AchievementManager
    if achievementManager then
        for _, player in pairs(Players:GetPlayers()) do
            achievementManager:CheckWeatherAchievements(player, weatherType)
        end
    end
end

function WeatherManager:NotifySeasonChange()
    -- Notify all relevant systems about season change
    local plantManager = _G.PlantManager
    if plantManager then
        local seasonData = self.SeasonalWeather[self.CurrentSeason]
        plantManager:ApplySeasonalEffect(self.CurrentSeason, seasonData.bonusGrowthMultiplier)
    end
    
    -- Notify players about season change
    local notificationManager = _G.NotificationManager
    if notificationManager then
        for _, player in pairs(Players:GetPlayers()) do
            notificationManager:ShowToast(
                "Season Changed! 🗓️",
                "Welcome to " .. self.CurrentSeason .. "!",
                self:GetSeasonIcon(self.CurrentSeason),
                "season"
            )
        end
    end
end

function WeatherManager:GetSeasonIcon(season)
    local icons = {
        spring = "🌸",
        summer = "☀️", 
        autumn = "🍂",
        winter = "❄️"
    }
    return icons[season] or "🗓️"
end

function WeatherManager:BroadcastWeatherUpdate()
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if remoteEvents then
        local weatherEvent = remoteEvents:FindFirstChild("WeatherStateUpdate")
        if weatherEvent then
            local weatherData = {
                currentWeather = self.CurrentWeather,
                currentSeason = self.CurrentSeason,
                timeRemaining = self.NextWeatherTime - tick(),
                weatherStartTime = self.WeatherStartTime
            }
            
            weatherEvent:FireAllClients(weatherData)
        end
    end
end

function WeatherManager:BroadcastSpecialEvent(eventType, message)
    local notificationManager = _G.NotificationManager
    if notificationManager then
        for _, player in pairs(Players:GetPlayers()) do
            notificationManager:ShowToast(
                "Special Event! ✨",
                message,
                "🎉",
                "special"
            )
        end
    end
    
    -- Track analytics
    local analyticsManager = _G.AnalyticsManager
    if analyticsManager then
        for _, player in pairs(Players:GetPlayers()) do
            analyticsManager:TrackEvent(player, {
                category = "weather",
                action = "special_event",
                label = eventType
            })
        end
    end
end

function WeatherManager:UpdateWeatherEffects()
    -- Update any ongoing weather effects
    local currentTime = tick()
    
    -- Update particle emission rates based on weather intensity
    for _, particle in ipairs(self.ActiveParticles) do
        if particle and particle.Parent then
            local intensity = self:GetWeatherIntensity()
            particle.Rate = particle.Rate * intensity
        end
    end
end

function WeatherManager:GetWeatherIntensity()
    -- Calculate weather intensity based on time remaining
    local timeElapsed = tick() - self.WeatherStartTime
    local progress = timeElapsed / self.WeatherDuration
    
    -- Weather intensity varies over time (starts low, peaks in middle, ends low)
    if progress < 0.3 then
        return 0.5 + (progress / 0.3) * 0.5 -- 0.5 to 1.0
    elseif progress < 0.7 then
        return 1.0 -- Peak intensity
    else
        return 1.0 - ((progress - 0.7) / 0.3) * 0.5 -- 1.0 to 0.5
    end
end

-- ==========================================
-- HELPER FUNCTIONS
-- ==========================================

function WeatherManager:IsPlayerVIP(player)
    local vipManager = _G.VIPManager
    if vipManager then
        return vipManager:IsPlayerVIP(player)
    end
    return false
end

function WeatherManager:GetCurrentWeatherMultiplier()
    local weatherData = self.WeatherEffects[self.CurrentWeather]
    local seasonData = self.SeasonalWeather[self.CurrentSeason]
    
    return weatherData.plantGrowthMultiplier * seasonData.bonusGrowthMultiplier
end

function WeatherManager:GetWeatherDescription(weatherType)
    local descriptions = {
        sunny = "Clear skies and bright sunshine",
        cloudy = "Overcast with gray clouds",
        rainy = "Light to moderate rainfall",
        stormy = "Heavy rain with thunder and lightning",
        drought = "Hot and dry with no precipitation",
        foggy = "Dense fog reducing visibility",
        windy = "Strong winds with clear skies"
    }
    
    return descriptions[weatherType] or "Unknown weather pattern"
end

-- ==========================================
-- PUBLIC API
-- ==========================================

function WeatherManager:GetCurrentWeather()
    return {
        type = self.CurrentWeather,
        season = self.CurrentSeason,
        timeRemaining = self.NextWeatherTime - tick(),
        growthMultiplier = self:GetCurrentWeatherMultiplier()
    }
end

function WeatherManager:GetWeatherForecast(days)
    -- Generate weather forecast for specified number of days
    local forecast = {}
    days = days or 3
    
    for i = 1, days do
        local weather = self:SelectNextWeather()
        table.insert(forecast, {
            day = i,
            weather = weather,
            description = self:GetWeatherDescription(weather)
        })
    end
    
    return forecast
end

function WeatherManager:ForceWeatherChange(weatherType)
    -- Admin function to force weather change
    if self.WeatherEffects[weatherType] then
        self:StartWeatherPattern(weatherType)
        return true
    end
    return false
end

function WeatherManager:GetWeatherStats()
    return {
        currentWeather = self.CurrentWeather,
        currentSeason = self.CurrentSeason,
        weatherStartTime = self.WeatherStartTime,
        seasonStartTime = self.SeasonStartTime,
        activeParticles = #self.ActiveParticles,
        activeSounds = #self.ActiveSounds
    }
end

-- ==========================================
-- CLEANUP
-- ==========================================

function WeatherManager:Cleanup()
    -- Clean up all weather effects
    self:CleanupCurrentWeather()
    
    -- Reset lighting to default
    Lighting.Brightness = 2
    Lighting.Ambient = Color3.fromRGB(135, 206, 235)
    Lighting.ColorShift_Top = Color3.fromRGB(255, 248, 220)
    Lighting.FogEnd = 2000
    Lighting.FogStart = 0
    
    print("🌦️ WeatherManager: Weather system cleaned up")
end

return WeatherManager
