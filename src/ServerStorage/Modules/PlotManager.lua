--[[
    PlotManager.lua
    Plot Grid Management & Player Assignment
    
    Priority: 6 (Core infrastructure module)
    Dependencies: ConfigModule, VIPManager
    Used by: PlantingHandler, PlayerJoinHandler, PlantManager
    
    Features:
    - Automatic plot grid generation (8 plots, 4x2 layout)
    - Spawn-relative positioning system
    - Player plot assignment (Free: 5 plots, VIP: 6 plots)
    - Plot boundaries and collision detection
    - Plot availability tracking
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)

local PlotManager = {}
PlotManager.__index = PlotManager

-- ==========================================
-- PLOT DATA STORAGE
-- ==========================================

PlotManager.PlotGrid = {}            -- [plotId] = {position, boundaries, isOccupied}
PlotManager.PlayerPlots = {}         -- [userId] = {assignedPlots = {1,2,3}, maxPlots = 5}
PlotManager.PlotBoundaries = {}      -- [plotId] = boundaryParts
PlotManager.SpawnPosition = nil      -- Reference spawn position

-- ==========================================
-- INITIALIZATION
-- ==========================================

function PlotManager:Initialize()
    print("🏠 PlotManager: Initializing plot system...")
    
    -- Find spawn position for relative positioning
    self:FindSpawnPosition()
    
    -- Generate plot grid
    self:GeneratePlotGrid()
    
    -- Create plot boundaries
    self:CreatePlotBoundaries()
    
    -- Set up player events
    self:SetupPlayerEvents()
    
    print("✅ PlotManager: Plot system initialized successfully")
    print("📊 PlotManager: Generated", ConfigModule.Plots.TOTAL_PLOTS, "plots in", ConfigModule.Plots.ROWS .. "x" .. ConfigModule.Plots.COLS, "grid")
end

function PlotManager:FindSpawnPosition()
    local spawnLocation = Workspace:FindFirstChild("SpawnLocation")
    
    if spawnLocation then
        self.SpawnPosition = spawnLocation.Position
        print("📍 PlotManager: Found spawn at position:", self.SpawnPosition)
    else
        -- Default to origin if no SpawnLocation found
        self.SpawnPosition = Vector3.new(0, 0, 0)
        warn("⚠️ PlotManager: No SpawnLocation found, using origin (0,0,0)")
    end
end

-- ==========================================
-- PLOT GRID GENERATION
-- ==========================================

function PlotManager:GeneratePlotGrid()
    local config = ConfigModule.Plots
    local gridOffset = config.GRID_OFFSET
    
    print("🏗️ PlotManager: Generating plot grid...")
    
    local plotId = 1
    
    -- Generate 4x2 grid (4 plots per row, 2 rows)
    for row = 1, config.ROWS do
        for col = 1, config.COLS do
            local plotPosition = self:CalculatePlotPosition(row, col)
            
            self.PlotGrid[plotId] = {
                id = plotId,
                position = plotPosition,
                row = row,
                col = col,
                isOccupied = false,
                assignedPlayer = nil,
                centerPosition = plotPosition + Vector3.new(config.PLOT_SIZE/2, 0, config.PLOT_SIZE/2)
            }
            
            print("🏠 PlotManager: Generated plot", plotId, "at position", plotPosition)
            plotId = plotId + 1
        end
    end
    
    print("✅ PlotManager: Plot grid generation completed")
end

function PlotManager:CalculatePlotPosition(row, col)
    local config = ConfigModule.Plots
    local gridOffset = config.GRID_OFFSET
    
    -- Calculate X position (columns)
    local xOffset = gridOffset.START_X + ((col - 1) * (config.PLOT_SIZE + config.PLOT_SPACING))
    
    -- Calculate Z position (rows)
    local zOffset = gridOffset.START_Z + ((row - 1) * gridOffset.ROW_SPACING)
    
    -- Return position relative to spawn
    return self.SpawnPosition + Vector3.new(xOffset, 0, zOffset)
end

-- ==========================================
-- PLOT BOUNDARIES
-- ==========================================

function PlotManager:CreatePlotBoundaries()
    print("🚧 PlotManager: Creating plot boundaries...")
    
    -- Create plots folder
    local plotsFolder = Workspace:FindFirstChild("Plots")
    if not plotsFolder then
        plotsFolder = Instance.new("Folder")
        plotsFolder.Name = "Plots"
        plotsFolder.Parent = Workspace
    end
    
    for plotId, plotData in pairs(self.PlotGrid) do
        self:CreateSinglePlotBoundary(plotId, plotData, plotsFolder)
    end
    
    print("✅ PlotManager: Plot boundaries created successfully")
end

function PlotManager:CreateSinglePlotBoundary(plotId, plotData, parent)
    local config = ConfigModule.Plots
    
    -- Create invisible boundary part for click detection
    local boundary = Instance.new("Part")
    boundary.Name = "PlotBoundary_" .. plotId
    boundary.Size = Vector3.new(config.PLOT_SIZE, 0.5, config.PLOT_SIZE)
    boundary.Position = plotData.centerPosition
    boundary.Anchored = true
    boundary.CanCollide = false
    boundary.Transparency = 0.8 -- Semi-transparent
    boundary.Color = Color3.fromRGB(34, 139, 34) -- Green
    boundary.Material = Enum.Material.Grass
    boundary.Parent = parent
    
    -- Add ClickDetector for plot interaction
    local clickDetector = Instance.new("ClickDetector")
    clickDetector.MaxActivationDistance = 20
    clickDetector.Parent = boundary
    
    -- Add plot number label
    local plotGui = Instance.new("SurfaceGui")
    plotGui.Name = "PlotLabel"
    plotGui.Face = Enum.NormalId.Top
    plotGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    plotGui.PixelsPerStud = 10
    plotGui.Parent = boundary
    
    local plotLabel = Instance.new("TextLabel")
    plotLabel.Name = "PlotNumber"
    plotLabel.Size = UDim2.new(1, 0, 1, 0)
    plotLabel.BackgroundTransparency = 1
    plotLabel.Text = "Plot " .. plotId
    plotLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    plotLabel.TextScaled = true
    plotLabel.Font = Enum.Font.GothamBold
    plotLabel.TextStrokeTransparency = 0
    plotLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    plotLabel.Parent = plotGui
    
    -- Store boundary reference
    self.PlotBoundaries[plotId] = boundary
    
    print("🏠 PlotManager: Created boundary for plot", plotId)
end

-- ==========================================
-- PLAYER PLOT ASSIGNMENT
-- ==========================================

function PlotManager:SetupPlayerEvents()
    Players.PlayerAdded:Connect(function(player)
        self:OnPlayerJoined(player)
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        self:OnPlayerLeaving(player)
    end)
end

function PlotManager:OnPlayerJoined(player)
    -- Assign plots to new player
    local assignedPlots = self:AssignPlotsToPlayer(player)
    
    if assignedPlots then
        print("🏠 PlotManager:", player.Name, "assigned plots:", table.concat(assignedPlots, ", "))
    else
        warn("❌ PlotManager: Failed to assign plots to", player.Name)
    end
end

function PlotManager:OnPlayerLeaving(player)
    -- Free up player's plots
    self:FreePlotsByPlayer(player)
    
    local userId = player.UserId
    self.PlayerPlots[userId] = nil
    
    print("🏠 PlotManager:", player.Name, "freed their plots")
end

function PlotManager:AssignPlotsToPlayer(player)
    local userId = player.UserId
    
    -- Check if player already has plots assigned (returning player)
    if self.PlayerPlots[userId] then
        print("🔄 PlotManager:", player.Name, "already has plots assigned")
        return self.PlayerPlots[userId].assignedPlots
    end
    
    -- Determine how many plots player should get
    local maxPlots = self:GetMaxPlotsForPlayer(player)
    
    -- Find available plots
    local availablePlots = self:FindAvailablePlots(maxPlots)
    
    if #availablePlots < maxPlots then
        warn("⚠️ PlotManager: Not enough available plots for", player.Name, "(Needed:", maxPlots, "Available:", #availablePlots, ")")
    end
    
    -- Assign plots to player
    self.PlayerPlots[userId] = {
        assignedPlots = availablePlots,
        maxPlots = maxPlots
    }
    
    -- Mark plots as occupied
    for _, plotId in ipairs(availablePlots) do
        if self.PlotGrid[plotId] then
            self.PlotGrid[plotId].isOccupied = true
            self.PlotGrid[plotId].assignedPlayer = userId
            
            -- Update plot visual to show ownership
            self:UpdatePlotOwnership(plotId, player.Name)
        end
    end
    
    return availablePlots
end

function PlotManager:GetMaxPlotsForPlayer(player)
    -- Check VIP status
    local VIPManager = self:GetVIPManager()
    if VIPManager and VIPManager:IsPlayerVIP(player) then
        return ConfigModule.Plots.DEFAULT_PLOTS_VIP
    else
        return ConfigModule.Plots.DEFAULT_PLOTS_FREE
    end
end

function PlotManager:FindAvailablePlots(count)
    local availablePlots = {}
    
    -- Find unoccupied plots
    for plotId, plotData in pairs(self.PlotGrid) do
        if not plotData.isOccupied and #availablePlots < count then
            table.insert(availablePlots, plotId)
        end
    end
    
    return availablePlots
end

function PlotManager:FreePlotsByPlayer(player)
    local userId = player.UserId
    local playerPlotData = self.PlayerPlots[userId]
    
    if not playerPlotData then
        return
    end
    
    -- Free each assigned plot
    for _, plotId in ipairs(playerPlotData.assignedPlots) do
        if self.PlotGrid[plotId] then
            self.PlotGrid[plotId].isOccupied = false
            self.PlotGrid[plotId].assignedPlayer = nil
            
            -- Update plot visual to show availability
            self:UpdatePlotOwnership(plotId, nil)
        end
    end
end

-- ==========================================
-- PLOT OWNERSHIP MANAGEMENT
-- ==========================================

function PlotManager:UpdatePlotOwnership(plotId, playerName)
    local boundary = self.PlotBoundaries[plotId]
    if not boundary then return end
    
    if playerName then
        -- Assign plot to player
        boundary.Color = Color3.fromRGB(34, 139, 34) -- Green (occupied)
        
        -- Update label
        local plotGui = boundary:FindFirstChild("PlotLabel")
        if plotGui then
            local plotLabel = plotGui:FindFirstChild("PlotNumber")
            if plotLabel then
                plotLabel.Text = "Plot " .. plotId .. "\n" .. playerName
                plotLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            end
        end
    else
        -- Free plot
        boundary.Color = Color3.fromRGB(100, 100, 100) -- Gray (available)
        
        -- Update label
        local plotGui = boundary:FindFirstChild("PlotLabel")
        if plotGui then
            local plotLabel = plotGui:FindFirstChild("PlotNumber")
            if plotLabel then
                plotLabel.Text = "Plot " .. plotId .. "\nAvailable"
                plotLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
        end
    end
end

function PlotManager:IsPlotOwnedByPlayer(plotId, player)
    local userId = player.UserId
    local playerPlotData = self.PlayerPlots[userId]
    
    if not playerPlotData then
        return false
    end
    
    return table.find(playerPlotData.assignedPlots, plotId) ~= nil
end

function PlotManager:GetPlayerPlots(player)
    local userId = player.UserId
    local playerPlotData = self.PlayerPlots[userId]
    
    if playerPlotData then
        return playerPlotData.assignedPlots
    else
        return {}
    end
end

-- ==========================================
-- PLOT INTERACTION VALIDATION
-- ==========================================

function PlotManager:ValidatePlotInteraction(player, plotId)
    -- Check if plot exists
    if not self.PlotGrid[plotId] then
        warn("❌ PlotManager: Plot", plotId, "does not exist")
        return false, "Plot does not exist"
    end
    
    -- Check if player owns the plot
    if not self:IsPlotOwnedByPlayer(plotId, player) then
        warn("❌ PlotManager:", player.Name, "does not own plot", plotId)
        return false, "You do not own this plot"
    end
    
    -- Check walking distance (anti-cheat)
    if not self:ValidatePlayerDistance(player, plotId) then
        warn("🚫 PlotManager:", player.Name, "too far from plot", plotId)
        return false, "Too far from plot"
    end
    
    return true, "Valid interaction"
end

function PlotManager:ValidatePlayerDistance(player, plotId)
    if not player.Character or not player.Character.PrimaryPart then
        return false
    end
    
    local plotData = self.PlotGrid[plotId]
    if not plotData then
        return false
    end
    
    local playerPosition = player.Character.PrimaryPart.Position
    local plotPosition = plotData.centerPosition
    local distance = (playerPosition - plotPosition).Magnitude
    
    -- Check if player is within reasonable interaction distance
    local maxDistance = ConfigModule.Security.MAX_INTERACTION_DISTANCE
    return distance <= maxDistance
end

-- ==========================================
-- PLOT INFORMATION
-- ==========================================

function PlotManager:GetPlotPosition(plotId)
    local plotData = self.PlotGrid[plotId]
    return plotData and plotData.centerPosition or nil
end

function PlotManager:GetPlotData(plotId)
    return self.PlotGrid[plotId]
end

function PlotManager:GetNearestPlot(position)
    local nearestPlot = nil
    local nearestDistance = math.huge
    
    for plotId, plotData in pairs(self.PlotGrid) do
        local distance = (position - plotData.centerPosition).Magnitude
        if distance < nearestDistance then
            nearestDistance = distance
            nearestPlot = plotId
        end
    end
    
    return nearestPlot, nearestDistance
end

function PlotManager:GetPlotsInRadius(position, radius)
    local nearbyPlots = {}
    
    for plotId, plotData in pairs(self.PlotGrid) do
        local distance = (position - plotData.centerPosition).Magnitude
        if distance <= radius then
            table.insert(nearbyPlots, {
                plotId = plotId,
                distance = distance,
                plotData = plotData
            })
        end
    end
    
    -- Sort by distance
    table.sort(nearbyPlots, function(a, b)
        return a.distance < b.distance
    end)
    
    return nearbyPlots
end

-- ==========================================
-- VIP PLOT EXPANSION
-- ==========================================

function PlotManager:ExpandPlayerPlots(player)
    local userId = player.UserId
    local playerPlotData = self.PlayerPlots[userId]
    
    if not playerPlotData then
        warn("❌ PlotManager: Player", player.Name, "has no plot data")
        return false
    end
    
    local currentPlots = #playerPlotData.assignedPlots
    local maxPlots = self:GetMaxPlotsForPlayer(player)
    
    if currentPlots >= maxPlots then
        print("⚠️ PlotManager:", player.Name, "already has maximum plots")
        return false
    end
    
    -- Find additional plots
    local additionalPlotsNeeded = maxPlots - currentPlots
    local availablePlots = self:FindAvailablePlots(additionalPlotsNeeded)
    
    if #availablePlots < additionalPlotsNeeded then
        warn("⚠️ PlotManager: Not enough available plots for expansion")
        return false
    end
    
    -- Assign additional plots
    for _, plotId in ipairs(availablePlots) do
        table.insert(playerPlotData.assignedPlots, plotId)
        
        if self.PlotGrid[plotId] then
            self.PlotGrid[plotId].isOccupied = true
            self.PlotGrid[plotId].assignedPlayer = userId
            self:UpdatePlotOwnership(plotId, player.Name)
        end
    end
    
    -- Update max plots
    playerPlotData.maxPlots = maxPlots
    
    print("🏠 PlotManager: Expanded", player.Name, "plots from", currentPlots, "to", maxPlots)
    return true
end

-- ==========================================
-- UTILITY FUNCTIONS
-- ==========================================

function PlotManager:GetVIPManager()
    -- Safely get VIPManager to avoid circular dependency
    local success, VIPManager = pcall(function()
        return require(game.ServerStorage.Modules.VIPManager)
    end)
    return success and VIPManager or nil
end

function PlotManager:GetPlotStats()
    local totalPlots = ConfigModule.Plots.TOTAL_PLOTS
    local occupiedPlots = 0
    local availablePlots = 0
    
    for plotId, plotData in pairs(self.PlotGrid) do
        if plotData.isOccupied then
            occupiedPlots = occupiedPlots + 1
        else
            availablePlots = availablePlots + 1
        end
    end
    
    return {
        totalPlots = totalPlots,
        occupiedPlots = occupiedPlots,
        availablePlots = availablePlots,
        occupancyRate = (occupiedPlots / totalPlots) * 100
    }
end

function PlotManager:PrintPlotDebugInfo()
    local stats = self:GetPlotStats()
    
    print("🐛 PlotManager Debug Info:")
    print("   Total plots:", stats.totalPlots)
    print("   Occupied plots:", stats.occupiedPlots)
    print("   Available plots:", stats.availablePlots)
    print("   Occupancy rate:", string.format("%.1f%%", stats.occupancyRate))
    print("   Grid size:", ConfigModule.Plots.ROWS .. "x" .. ConfigModule.Plots.COLS)
    print("   Plot size:", ConfigModule.Plots.PLOT_SIZE .. "x" .. ConfigModule.Plots.PLOT_SIZE)
    print("   Spawn position:", self.SpawnPosition)
end

return PlotManager
