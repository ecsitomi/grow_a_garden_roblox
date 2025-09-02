--[[
    MiniGameManager.lua
    Server-Side Mini-Games and Garden Activities System
    
    Priority: 33 (Advanced Features phase)
    Dependencies: DataStoreService, ReplicatedStorage, TweenService
    Used by: NotificationManager, EconomyManager, VIPManager
    
    Features:
    - Garden-themed mini-games
    - Daily challenges and puzzles
    - Skill-based farming activities
    - Multiplayer mini-game competitions
    - Seasonal mini-game events
    - Reward systems and leaderboards
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

-- Load required modules
local ConfigModule = require(ReplicatedStorage.Modules.ConfigModule)

local MiniGameManager = {}
MiniGameManager.__index = MiniGameManager

-- ==========================================
-- INITIALIZATION & SETUP
-- ==========================================

-- Data stores
MiniGameManager.GameStore = DataStoreService:GetDataStore("MiniGameData_v1")
MiniGameManager.LeaderboardStore = DataStoreService:GetDataStore("MiniGameLeaderboards_v1")

-- Mini-game state tracking
MiniGameManager.ActiveGames = {} -- [gameId] = gameData
MiniGameManager.PlayerScores = {} -- [userId] = {gameScores, achievements}
MiniGameManager.DailyChallenges = {} -- Daily rotating challenges
MiniGameManager.Leaderboards = {} -- [gameType] = leaderboard

-- Mini-game types
MiniGameManager.GameTypes = {
    PLANT_PUZZLE = {
        name = "Plant Puzzle",
        description = "Match plants to solve puzzles",
        category = "puzzle",
        difficulty = "easy",
        duration = 180, -- 3 minutes
        maxPlayers = 1,
        rewards = {
            bronze = {coins = 100, xp = 200},
            silver = {coins = 250, xp = 500},
            gold = {coins = 500, xp = 1000}
        },
        vipMultiplier = 1.5
    },
    
    WATER_RHYTHM = {
        name = "Watering Rhythm",
        description = "Water plants to the beat",
        category = "rhythm",
        difficulty = "medium",
        duration = 120, -- 2 minutes
        maxPlayers = 1,
        rewards = {
            bronze = {coins = 150, xp = 300},
            silver = {coins = 375, xp = 750},
            gold = {coins = 750, xp = 1500}
        },
        vipMultiplier = 1.5
    },
    
    HARVEST_RUSH = {
        name = "Harvest Rush",
        description = "Harvest as many crops as possible",
        category = "speed",
        difficulty = "easy",
        duration = 60, -- 1 minute
        maxPlayers = 1,
        rewards = {
            bronze = {coins = 80, xp = 160},
            silver = {coins = 200, xp = 400},
            gold = {coins = 400, xp = 800}
        },
        vipMultiplier = 1.5
    },
    
    SEED_SORTING = {
        name = "Seed Sorting Challenge",
        description = "Sort seeds by type and color",
        category = "sorting",
        difficulty = "medium",
        duration = 240, -- 4 minutes
        maxPlayers = 1,
        rewards = {
            bronze = {coins = 120, xp = 240},
            silver = {coins = 300, xp = 600},
            gold = {coins = 600, xp = 1200}
        },
        vipMultiplier = 1.5
    },
    
    PEST_DEFENSE = {
        name = "Garden Defense",
        description = "Defend your garden from pest invasion",
        category = "strategy",
        difficulty = "hard",
        duration = 300, -- 5 minutes
        maxPlayers = 1,
        rewards = {
            bronze = {coins = 200, xp = 400},
            silver = {coins = 500, xp = 1000},
            gold = {coins = 1000, xp = 2000}
        },
        vipMultiplier = 1.5
    },
    
    FLOWER_MEMORY = {
        name = "Flower Memory Game",
        description = "Remember the flower pattern sequence",
        category = "memory",
        difficulty = "medium",
        duration = 180, -- 3 minutes
        maxPlayers = 1,
        rewards = {
            bronze = {coins = 110, xp = 220},
            silver = {coins = 275, xp = 550},
            gold = {coins = 550, xp = 1100}
        },
        vipMultiplier = 1.5
    },
    
    MULTIPLAYER_RACE = {
        name = "Garden Race",
        description = "Race to complete gardening tasks",
        category = "multiplayer",
        difficulty = "medium",
        duration = 180, -- 3 minutes
        maxPlayers = 4,
        rewards = {
            winner = {coins = 1000, xp = 2000},
            second = {coins = 600, xp = 1200},
            third = {coins = 400, xp = 800},
            participant = {coins = 200, xp = 400}
        },
        vipMultiplier = 1.3
    },
    
    COOPERATIVE_GARDEN = {
        name = "Cooperative Gardening",
        description = "Work together to build a garden",
        category = "cooperative",
        difficulty = "easy",
        duration = 300, -- 5 minutes
        maxPlayers = 6,
        rewards = {
            success = {coins = 800, xp = 1600},
            partial = {coins = 400, xp = 800},
            participation = {coins = 200, xp = 400}
        },
        vipMultiplier = 1.3
    }
}

-- Daily challenge types
MiniGameManager.DailyChallengeTypes = {
    HIGH_SCORE = {
        name = "High Score Challenge",
        description = "Achieve the highest score in any mini-game",
        requirement = "score",
        threshold = 10000,
        rewards = {coins = 2000, xp = 4000, title = "Daily Champion"}
    },
    
    SPEED_RUN = {
        name = "Speed Run Challenge",
        description = "Complete 5 mini-games in under 10 minutes",
        requirement = "speed",
        threshold = 600, -- 10 minutes
        rewards = {coins = 1500, xp = 3000, item = "speed_boost"}
    },
    
    PERFECT_GAMES = {
        name = "Perfect Games Challenge",
        description = "Achieve gold rank in 3 different mini-games",
        requirement = "perfection",
        threshold = 3,
        rewards = {coins = 2500, xp = 5000, title = "Perfectionist"}
    },
    
    ENDURANCE = {
        name = "Endurance Challenge",
        description = "Play mini-games for 30 minutes total",
        requirement = "time",
        threshold = 1800, -- 30 minutes
        rewards = {coins = 1800, xp = 3600, item = "endurance_trophy"}
    }
}

-- Achievement types
MiniGameManager.AchievementTypes = {
    FIRST_WIN = {
        name = "First Victory",
        description = "Win your first mini-game",
        requirement = {wins = 1},
        rewards = {coins = 500, xp = 1000}
    },
    
    MINI_GAME_MASTER = {
        name = "Mini-Game Master",
        description = "Win 100 mini-games",
        requirement = {wins = 100},
        rewards = {coins = 10000, xp = 20000, title = "Game Master"}
    },
    
    PERFECT_SCORE = {
        name = "Perfect Score",
        description = "Achieve a perfect score in any mini-game",
        requirement = {perfect_scores = 1},
        rewards = {coins = 1000, xp = 2000}
    },
    
    SPEED_DEMON = {
        name = "Speed Demon",
        description = "Complete 10 speed category games with gold rank",
        requirement = {speed_golds = 10},
        rewards = {coins = 5000, xp = 10000, title = "Speed Demon"}
    },
    
    PUZZLE_SOLVER = {
        name = "Puzzle Solver",
        description = "Complete 50 puzzle category games",
        requirement = {puzzle_games = 50},
        rewards = {coins = 3000, xp = 6000, title = "Puzzle Master"}
    },
    
    MULTIPLAYER_CHAMPION = {
        name = "Multiplayer Champion",
        description = "Win 25 multiplayer games",
        requirement = {multiplayer_wins = 25},
        rewards = {coins = 8000, xp = 16000, title = "Champion"}
    }
}

-- Game difficulty settings
MiniGameManager.DifficultySettings = {
    easy = {
        scoreMultiplier = 1.0,
        timeBonus = 1.0,
        mistakePenalty = 0.9
    },
    medium = {
        scoreMultiplier = 1.2,
        timeBonus = 1.1,
        mistakePenalty = 0.8
    },
    hard = {
        scoreMultiplier = 1.5,
        timeBonus = 1.2,
        mistakePenalty = 0.7
    }
}

-- ==========================================
-- INITIALIZATION
-- ==========================================

function MiniGameManager:Initialize()
    print("🎮 MiniGameManager: Initializing mini-game system...")
    
    -- Set up remote events
    self:SetupRemoteEvents()
    
    -- Set up player connections
    self:SetupPlayerConnections()
    
    -- Load mini-game data
    self:LoadMiniGameData()
    
    -- Initialize daily challenges
    self:InitializeDailyChallenges()
    
    -- Start game updates
    self:StartGameUpdates()
    
    print("✅ MiniGameManager: Mini-game system initialized")
end

function MiniGameManager:SetupRemoteEvents()
    local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remoteEvents then
        remoteEvents = Instance.new("Folder")
        remoteEvents.Name = "RemoteEvents"
        remoteEvents.Parent = ReplicatedStorage
    end
    
    -- Start mini-game
    local startGameFunction = Instance.new("RemoteFunction")
    startGameFunction.Name = "StartMiniGame"
    startGameFunction.Parent = remoteEvents
    startGameFunction.OnServerInvoke = function(player, gameType)
        return self:StartMiniGame(player, gameType)
    end
    
    -- End mini-game
    local endGameFunction = Instance.new("RemoteFunction")
    endGameFunction.Name = "EndMiniGame"
    endGameFunction.Parent = remoteEvents
    endGameFunction.OnServerInvoke = function(player, gameId, score, completed)
        return self:EndMiniGame(player, gameId, score, completed)
    end
    
    -- Join multiplayer game
    local joinMultiplayerFunction = Instance.new("RemoteFunction")
    joinMultiplayerFunction.Name = "JoinMultiplayerGame"
    joinMultiplayerFunction.Parent = remoteEvents
    joinMultiplayerFunction.OnServerInvoke = function(player, gameType)
        return self:JoinMultiplayerGame(player, gameType)
    end
    
    -- Get leaderboards
    local getLeaderboardFunction = Instance.new("RemoteFunction")
    getLeaderboardFunction.Name = "GetMiniGameLeaderboard"
    getLeaderboardFunction.Parent = remoteEvents
    getLeaderboardFunction.OnServerInvoke = function(player, gameType)
        return self:GetLeaderboard(gameType)
    end
    
    -- Get player stats
    local getStatsFunction = Instance.new("RemoteFunction")
    getStatsFunction.Name = "GetMiniGameStats"
    getStatsFunction.Parent = remoteEvents
    getStatsFunction.OnServerInvoke = function(player)
        return self:GetPlayerStats(player)
    end
    
    -- Get daily challenges
    local getDailyChallengesFunction = Instance.new("RemoteFunction")
    getDailyChallengesFunction.Name = "GetDailyChallenges"
    getDailyChallengesFunction.Parent = remoteEvents
    getDailyChallengesFunction.OnServerInvoke = function(player)
        return self:GetDailyChallenges(player)
    end
    
    -- Mini-game action events
    local gameActionEvent = Instance.new("RemoteEvent")
    gameActionEvent.Name = "MiniGameAction"
    gameActionEvent.Parent = remoteEvents
    gameActionEvent.OnServerEvent:Connect(function(player, gameId, action, data)
        self:HandleGameAction(player, gameId, action, data)
    end)
end

function MiniGameManager:SetupPlayerConnections()
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

function MiniGameManager:LoadMiniGameData()
    -- Load leaderboards
    for gameType, _ in pairs(self.GameTypes) do
        local success, leaderboardData = pcall(function()
            return self.LeaderboardStore:GetAsync("leaderboard_" .. gameType)
        end)
        
        if success and leaderboardData then
            self.Leaderboards[gameType] = leaderboardData
        else
            self.Leaderboards[gameType] = {
                players = {},
                lastUpdated = tick()
            }
        end
    end
end

function MiniGameManager:InitializeDailyChallenges()
    -- Create daily challenges
    local today = os.date("%Y-%m-%d")
    
    if not self.DailyChallenges[today] then
        self.DailyChallenges[today] = {}
        
        -- Select random challenges for today
        local challengeTypes = {}
        for challengeType, _ in pairs(self.DailyChallengeTypes) do
            table.insert(challengeTypes, challengeType)
        end
        
        -- Pick 3 random challenges
        for i = 1, 3 do
            local randomIndex = math.random(#challengeTypes)
            local challengeType = challengeTypes[randomIndex]
            table.remove(challengeTypes, randomIndex)
            
            local challengeTemplate = self.DailyChallengeTypes[challengeType]
            self.DailyChallenges[today][challengeType] = {
                type = challengeType,
                name = challengeTemplate.name,
                description = challengeTemplate.description,
                requirement = challengeTemplate.requirement,
                threshold = challengeTemplate.threshold,
                rewards = challengeTemplate.rewards,
                completedBy = {}
            }
        end
    end
end

function MiniGameManager:StartGameUpdates()
    spawn(function()
        while true do
            self:UpdateActiveGames()
            self:CheckDailyChallenges()
            self:SaveLeaderboards()
            wait(30) -- Update every 30 seconds
        end
    end)
end

-- ==========================================
-- PLAYER MANAGEMENT
-- ==========================================

function MiniGameManager:OnPlayerJoined(player)
    -- Initialize player score data
    self.PlayerScores[player.UserId] = {
        gameScores = {},
        achievements = {},
        stats = {
            totalGames = 0,
            totalWins = 0,
            totalScore = 0,
            bestScores = {},
            streaks = {current = 0, best = 0},
            timePlayedTotal = 0
        },
        dailyProgress = {}
    }
    
    -- Load player mini-game data
    spawn(function()
        self:LoadPlayerGameData(player)
    end)
    
    print("🎮 MiniGameManager: Player", player.Name, "initialized")
end

function MiniGameManager:OnPlayerLeaving(player)
    -- End any active games
    for gameId, game in pairs(self.ActiveGames) do
        if game.players[player.UserId] then
            self:RemovePlayerFromGame(gameId, player.UserId)
        end
    end
    
    -- Save player mini-game data
    spawn(function()
        self:SavePlayerGameData(player)
    end)
    
    -- Clean up
    self.PlayerScores[player.UserId] = nil
    
    print("🎮 MiniGameManager: Player", player.Name, "data saved")
end

function MiniGameManager:LoadPlayerGameData(player)
    local success, gameData = pcall(function()
        return self.GameStore:GetAsync("player_" .. player.UserId)
    end)
    
    if success and gameData then
        self.PlayerScores[player.UserId] = gameData
        print("🎮 MiniGameManager: Loaded game data for", player.Name)
    else
        print("🎮 MiniGameManager: New game data for", player.Name)
    end
end

function MiniGameManager:SavePlayerGameData(player)
    local gameData = self.PlayerScores[player.UserId]
    if not gameData then return end
    
    local success, error = pcall(function()
        self.GameStore:SetAsync("player_" .. player.UserId, gameData)
    end)
    
    if not success then
        warn("❌ MiniGameManager: Failed to save game data for", player.Name, ":", error)
    end
end

-- ==========================================
-- MINI-GAME CORE
-- ==========================================

function MiniGameManager:StartMiniGame(player, gameType)
    local gameTemplate = self.GameTypes[gameType]
    if not gameTemplate then
        return {success = false, message = "Invalid game type"}
    end
    
    -- Check if player is already in a game
    for gameId, game in pairs(self.ActiveGames) do
        if game.players[player.UserId] then
            return {success = false, message = "Already in a game"}
        end
    end
    
    -- Create game instance
    local gameId = HttpService:GenerateGUID()
    local game = {
        id = gameId,
        type = gameType,
        template = gameTemplate,
        startTime = tick(),
        endTime = tick() + gameTemplate.duration,
        status = "active",
        players = {
            [player.UserId] = {
                userId = player.UserId,
                playerName = player.Name,
                score = 0,
                completed = false,
                joinTime = tick()
            }
        },
        maxPlayers = gameTemplate.maxPlayers,
        gameData = self:InitializeGameData(gameType)
    }
    
    self.ActiveGames[gameId] = game
    
    -- Update player stats
    local playerStats = self.PlayerScores[player.UserId].stats
    playerStats.totalGames = playerStats.totalGames + 1
    
    return {
        success = true, 
        message = "Game started successfully", 
        gameId = gameId,
        gameData = game.gameData
    }
end

function MiniGameManager:EndMiniGame(player, gameId, score, completed)
    local game = self.ActiveGames[gameId]
    if not game then
        return {success = false, message = "Game not found"}
    end
    
    local playerData = game.players[player.UserId]
    if not playerData then
        return {success = false, message = "Player not in this game"}
    end
    
    -- Update player game data
    playerData.score = score or 0
    playerData.completed = completed or false
    playerData.endTime = tick()
    
    -- Calculate time played
    local timePlayed = tick() - playerData.joinTime
    
    -- Update player stats
    local playerStats = self.PlayerScores[player.UserId].stats
    playerStats.totalScore = playerStats.totalScore + playerData.score
    playerStats.timePlayedTotal = playerStats.timePlayedTotal + timePlayed
    
    -- Update best score
    if not playerStats.bestScores[game.type] or playerData.score > playerStats.bestScores[game.type] then
        playerStats.bestScores[game.type] = playerData.score
    end
    
    -- Calculate rewards
    local rewards = self:CalculateRewards(game, playerData)
    
    -- Give rewards
    if rewards then
        self:GiveGameRewards(player, rewards)
    end
    
    -- Update leaderboard
    self:UpdateLeaderboard(game.type, player, playerData.score)
    
    -- Check achievements
    self:CheckAchievements(player, game, playerData)
    
    -- Check daily challenges
    self:UpdateDailyChallengeProgress(player, game, playerData)
    
    -- Remove game if all players finished or it's single player
    if game.maxPlayers == 1 or self:AllPlayersFinished(game) then
        self.ActiveGames[gameId] = nil
    end
    
    return {
        success = true, 
        message = "Game ended successfully", 
        score = playerData.score,
        rewards = rewards
    }
end

function MiniGameManager:JoinMultiplayerGame(player, gameType)
    local gameTemplate = self.GameTypes[gameType]
    if not gameTemplate then
        return {success = false, message = "Invalid game type"}
    end
    
    if gameTemplate.maxPlayers <= 1 then
        return {success = false, message = "Not a multiplayer game"}
    end
    
    -- Check if player is already in a game
    for gameId, game in pairs(self.ActiveGames) do
        if game.players[player.UserId] then
            return {success = false, message = "Already in a game"}
        end
    end
    
    -- Find existing game to join
    local joinableGame = nil
    for gameId, game in pairs(self.ActiveGames) do
        if game.type == gameType and 
           game.status == "waiting" and 
           #game.players < game.maxPlayers then
            joinableGame = game
            break
        end
    end
    
    -- Create new game if none found
    if not joinableGame then
        local gameId = HttpService:GenerateGUID()
        joinableGame = {
            id = gameId,
            type = gameType,
            template = gameTemplate,
            startTime = nil, -- Will be set when game starts
            endTime = nil,
            status = "waiting",
            players = {},
            maxPlayers = gameTemplate.maxPlayers,
            gameData = self:InitializeGameData(gameType)
        }
        self.ActiveGames[gameId] = joinableGame
    end
    
    -- Add player to game
    joinableGame.players[player.UserId] = {
        userId = player.UserId,
        playerName = player.Name,
        score = 0,
        completed = false,
        joinTime = tick()
    }
    
    -- Start game if enough players
    if #joinableGame.players >= 2 then -- Minimum 2 for multiplayer
        self:StartMultiplayerGame(joinableGame)
    end
    
    return {
        success = true, 
        message = "Joined multiplayer game", 
        gameId = joinableGame.id,
        playersCount = #joinableGame.players,
        maxPlayers = joinableGame.maxPlayers
    }
end

function MiniGameManager:StartMultiplayerGame(game)
    game.status = "active"
    game.startTime = tick()
    game.endTime = tick() + game.template.duration
    
    -- Notify all players
    for userId, playerData in pairs(game.players) do
        local player = Players:GetPlayerByUserId(userId)
        if player then
            local notificationManager = _G.NotificationManager
            if notificationManager then
                notificationManager:ShowToast(
                    "Game Starting! 🎮",
                    game.template.name .. " is about to begin!",
                    "🚀",
                    "game_start"
                )
            end
        end
    end
end

function MiniGameManager:InitializeGameData(gameType)
    -- Initialize game-specific data based on type
    if gameType == "PLANT_PUZZLE" then
        return {
            puzzleGrid = self:GeneratePuzzleGrid(),
            targetPattern = self:GenerateTargetPattern(),
            movesLeft = 20
        }
    elseif gameType == "WATER_RHYTHM" then
        return {
            beatPattern = self:GenerateBeatPattern(),
            currentBeat = 1,
            accuracy = 100
        }
    elseif gameType == "HARVEST_RUSH" then
        return {
            cropsToHarvest = self:GenerateHarvestField(),
            timeMultiplier = 1.0
        }
    elseif gameType == "SEED_SORTING" then
        return {
            seedsToSort = self:GenerateRandomSeeds(),
            categories = {"color", "type", "size"},
            sortedCorrectly = 0
        }
    elseif gameType == "PEST_DEFENSE" then
        return {
            gardenHealth = 100,
            waveNumber = 1,
            pestsDefeated = 0,
            defenseItems = {"pesticide", "trap", "repellent"}
        }
    elseif gameType == "FLOWER_MEMORY" then
        return {
            sequence = self:GenerateMemorySequence(),
            currentStep = 1,
            playerSequence = {}
        }
    else
        return {}
    end
end

-- ==========================================
-- GAME ACTION HANDLING
-- ==========================================

function MiniGameManager:HandleGameAction(player, gameId, action, data)
    local game = self.ActiveGames[gameId]
    if not game or not game.players[player.UserId] then
        return
    end
    
    if game.status ~= "active" then
        return
    end
    
    -- Handle action based on game type
    if game.type == "PLANT_PUZZLE" then
        self:HandlePuzzleAction(game, player.UserId, action, data)
    elseif game.type == "WATER_RHYTHM" then
        self:HandleRhythmAction(game, player.UserId, action, data)
    elseif game.type == "HARVEST_RUSH" then
        self:HandleHarvestAction(game, player.UserId, action, data)
    elseif game.type == "SEED_SORTING" then
        self:HandleSortingAction(game, player.UserId, action, data)
    elseif game.type == "PEST_DEFENSE" then
        self:HandleDefenseAction(game, player.UserId, action, data)
    elseif game.type == "FLOWER_MEMORY" then
        self:HandleMemoryAction(game, player.UserId, action, data)
    end
end

function MiniGameManager:HandlePuzzleAction(game, userId, action, data)
    if action == "move_piece" then
        local gameData = game.gameData
        local fromPos = data.from
        local toPos = data.to
        
        -- Validate move
        if self:IsValidPuzzleMove(gameData.puzzleGrid, fromPos, toPos) then
            -- Swap pieces
            self:SwapPuzzlePieces(gameData.puzzleGrid, fromPos, toPos)
            gameData.movesLeft = gameData.movesLeft - 1
            
            -- Check if puzzle is solved
            if self:IsPuzzleSolved(gameData.puzzleGrid, gameData.targetPattern) then
                game.players[userId].score = self:CalculatePuzzleScore(gameData)
                game.players[userId].completed = true
            end
        end
    end
end

function MiniGameManager:HandleRhythmAction(game, userId, action, data)
    if action == "beat_hit" then
        local gameData = game.gameData
        local timing = data.timing
        local expectedTime = data.expectedTime
        
        -- Calculate accuracy
        local timeDiff = math.abs(timing - expectedTime)
        local maxDiff = 100 -- milliseconds
        local accuracy = math.max(0, (maxDiff - timeDiff) / maxDiff)
        
        -- Update score
        local points = math.floor(accuracy * 100)
        game.players[userId].score = game.players[userId].score + points
        
        -- Update game data
        gameData.currentBeat = gameData.currentBeat + 1
        gameData.accuracy = (gameData.accuracy + accuracy * 100) / 2 -- Running average
    end
end

function MiniGameManager:HandleHarvestAction(game, userId, action, data)
    if action == "harvest_crop" then
        local cropType = data.cropType
        local position = data.position
        
        -- Validate harvest
        if self:IsValidHarvest(game.gameData.cropsToHarvest, position, cropType) then
            -- Remove crop and add score
            self:RemoveHarvestedCrop(game.gameData.cropsToHarvest, position)
            local points = self:GetCropPoints(cropType) * game.gameData.timeMultiplier
            game.players[userId].score = game.players[userId].score + points
        end
    end
end

function MiniGameManager:HandleSortingAction(game, userId, action, data)
    if action == "sort_seed" then
        local seedId = data.seedId
        local category = data.category
        
        -- Check if sorting is correct
        if self:IsSeedSortedCorrectly(game.gameData.seedsToSort, seedId, category) then
            game.gameData.sortedCorrectly = game.gameData.sortedCorrectly + 1
            game.players[userId].score = game.players[userId].score + 50
        else
            game.players[userId].score = math.max(0, game.players[userId].score - 10)
        end
    end
end

function MiniGameManager:HandleDefenseAction(game, userId, action, data)
    if action == "use_defense" then
        local defenseType = data.defenseType
        local target = data.target
        
        -- Apply defense
        if self:UseDefenseItem(game.gameData, defenseType, target) then
            game.gameData.pestsDefeated = game.gameData.pestsDefeated + 1
            game.players[userId].score = game.players[userId].score + 25
        end
    end
end

function MiniGameManager:HandleMemoryAction(game, userId, action, data)
    if action == "sequence_input" then
        local input = data.input
        local gameData = game.gameData
        
        table.insert(gameData.playerSequence, input)
        
        -- Check if input matches sequence so far
        local currentStep = #gameData.playerSequence
        if gameData.sequence[currentStep] == input then
            -- Correct input
            if currentStep == #gameData.sequence then
                -- Sequence completed
                game.players[userId].score = game.players[userId].score + (#gameData.sequence * 10)
                game.players[userId].completed = true
            end
        else
            -- Wrong input - end game
            game.players[userId].completed = true
        end
    end
end

-- ==========================================
-- REWARD CALCULATION
-- ==========================================

function MiniGameManager:CalculateRewards(game, playerData)
    local gameTemplate = game.template
    local rewards = nil
    
    if not playerData.completed then
        return nil -- No rewards for incomplete games
    end
    
    -- Determine rank based on score
    local rank = self:DetermineRank(game, playerData)
    
    if gameTemplate.rewards[rank] then
        rewards = {}
        for rewardType, amount in pairs(gameTemplate.rewards[rank]) do
            rewards[rewardType] = amount
        end
        
        -- Apply VIP multiplier
        local player = Players:GetPlayerByUserId(playerData.userId)
        if player and self:IsPlayerVIP(player) then
            if rewards.coins then
                rewards.coins = math.floor(rewards.coins * gameTemplate.vipMultiplier)
            end
            if rewards.xp then
                rewards.xp = math.floor(rewards.xp * gameTemplate.vipMultiplier)
            end
        end
        
        -- Apply difficulty multiplier
        local difficulty = gameTemplate.difficulty
        local difficultySettings = self.DifficultySettings[difficulty]
        if difficultySettings and rewards.coins then
            rewards.coins = math.floor(rewards.coins * difficultySettings.scoreMultiplier)
        end
    end
    
    return rewards
end

function MiniGameManager:DetermineRank(game, playerData)
    local score = playerData.score
    local gameTemplate = game.template
    
    -- Different ranking logic for multiplayer games
    if game.maxPlayers > 1 then
        local scores = {}
        for userId, data in pairs(game.players) do
            if data.completed then
                table.insert(scores, {userId = userId, score = data.score})
            end
        end
        
        table.sort(scores, function(a, b) return a.score > b.score end)
        
        for i, scoreData in ipairs(scores) do
            if scoreData.userId == playerData.userId then
                if i == 1 then return "winner"
                elseif i == 2 then return "second"
                elseif i == 3 then return "third"
                else return "participant"
                end
            end
        end
        
        return "participant"
    else
        -- Single player ranking
        local maxScore = self:GetMaxPossibleScore(game.type)
        local scorePercentage = score / maxScore
        
        if scorePercentage >= 0.9 then
            return "gold"
        elseif scorePercentage >= 0.7 then
            return "silver"
        elseif scorePercentage >= 0.5 then
            return "bronze"
        else
            return nil -- No reward
        end
    end
end

function MiniGameManager:GetMaxPossibleScore(gameType)
    -- Return theoretical maximum score for each game type
    local maxScores = {
        PLANT_PUZZLE = 2000,
        WATER_RHYTHM = 12000, -- 120 beats * 100 points
        HARVEST_RUSH = 3000,
        SEED_SORTING = 5000,
        PEST_DEFENSE = 2500,
        FLOWER_MEMORY = 1000,
        MULTIPLAYER_RACE = 5000,
        COOPERATIVE_GARDEN = 4000
    }
    
    return maxScores[gameType] or 1000
end

function MiniGameManager:GiveGameRewards(player, rewards)
    local economyManager = _G.EconomyManager
    local inventoryManager = _G.InventoryManager
    
    if rewards.coins and economyManager then
        economyManager:AddCurrency(player, rewards.coins)
    end
    
    if rewards.xp and economyManager then
        economyManager:AddExperience(player, rewards.xp)
    end
    
    if rewards.item and inventoryManager then
        inventoryManager:AddItem(player, rewards.item, 1)
    end
    
    if rewards.title then
        local achievementManager = _G.AchievementManager
        if achievementManager then
            achievementManager:UnlockTitle(player, rewards.title)
        end
    end
end

-- ==========================================
-- LEADERBOARDS
-- ==========================================

function MiniGameManager:UpdateLeaderboard(gameType, player, score)
    local leaderboard = self.Leaderboards[gameType]
    if not leaderboard then
        leaderboard = {players = {}, lastUpdated = tick()}
        self.Leaderboards[gameType] = leaderboard
    end
    
    -- Find existing entry or create new one
    local playerEntry = nil
    for i, entry in ipairs(leaderboard.players) do
        if entry.userId == player.UserId then
            playerEntry = entry
            break
        end
    end
    
    if not playerEntry then
        playerEntry = {
            userId = player.UserId,
            playerName = player.Name,
            bestScore = 0,
            totalGames = 0,
            lastPlayed = tick()
        }
        table.insert(leaderboard.players, playerEntry)
    end
    
    -- Update entry
    if score > playerEntry.bestScore then
        playerEntry.bestScore = score
    end
    playerEntry.totalGames = playerEntry.totalGames + 1
    playerEntry.lastPlayed = tick()
    
    -- Sort leaderboard
    table.sort(leaderboard.players, function(a, b)
        return a.bestScore > b.bestScore
    end)
    
    -- Keep only top 100
    if #leaderboard.players > 100 then
        for i = 101, #leaderboard.players do
            leaderboard.players[i] = nil
        end
    end
    
    leaderboard.lastUpdated = tick()
end

function MiniGameManager:GetLeaderboard(gameType)
    return self.Leaderboards[gameType] or {players = {}, lastUpdated = 0}
end

function MiniGameManager:SaveLeaderboards()
    for gameType, leaderboard in pairs(self.Leaderboards) do
        local success, error = pcall(function()
            self.LeaderboardStore:SetAsync("leaderboard_" .. gameType, leaderboard)
        end)
        
        if not success then
            warn("❌ MiniGameManager: Failed to save leaderboard for", gameType, ":", error)
        end
    end
end

-- ==========================================
-- ACHIEVEMENTS & CHALLENGES
-- ==========================================

function MiniGameManager:CheckAchievements(player, game, playerData)
    local playerStats = self.PlayerScores[player.UserId].stats
    local achievements = self.PlayerScores[player.UserId].achievements
    
    -- Check each achievement type
    for achievementId, achievement in pairs(self.AchievementTypes) do
        if not achievements[achievementId] then -- Not yet unlocked
            local unlocked = false
            
            -- Check requirements
            for requirementType, threshold in pairs(achievement.requirement) do
                if requirementType == "wins" and playerData.completed then
                    playerStats.totalWins = playerStats.totalWins + 1
                    if playerStats.totalWins >= threshold then
                        unlocked = true
                    end
                elseif requirementType == "perfect_scores" and playerData.score == self:GetMaxPossibleScore(game.type) then
                    playerStats.perfectScores = (playerStats.perfectScores or 0) + 1
                    if playerStats.perfectScores >= threshold then
                        unlocked = true
                    end
                elseif requirementType == "speed_golds" and game.template.category == "speed" then
                    local rank = self:DetermineRank(game, playerData)
                    if rank == "gold" then
                        playerStats.speedGolds = (playerStats.speedGolds or 0) + 1
                        if playerStats.speedGolds >= threshold then
                            unlocked = true
                        end
                    end
                elseif requirementType == "puzzle_games" and game.template.category == "puzzle" then
                    playerStats.puzzleGames = (playerStats.puzzleGames or 0) + 1
                    if playerStats.puzzleGames >= threshold then
                        unlocked = true
                    end
                elseif requirementType == "multiplayer_wins" and game.maxPlayers > 1 then
                    local rank = self:DetermineRank(game, playerData)
                    if rank == "winner" then
                        playerStats.multiplayerWins = (playerStats.multiplayerWins or 0) + 1
                        if playerStats.multiplayerWins >= threshold then
                            unlocked = true
                        end
                    end
                end
            end
            
            if unlocked then
                achievements[achievementId] = {
                    unlockedTime = tick(),
                    gameId = game.id
                }
                
                -- Give rewards
                self:GiveGameRewards(player, achievement.rewards)
                
                -- Notify player
                local notificationManager = _G.NotificationManager
                if notificationManager then
                    notificationManager:ShowToast(
                        "Achievement Unlocked! 🏆",
                        achievement.name,
                        "🎯",
                        "achievement"
                    )
                end
            end
        end
    end
end

function MiniGameManager:GetDailyChallenges(player)
    local today = os.date("%Y-%m-%d")
    return self.DailyChallenges[today] or {}
end

function MiniGameManager:UpdateDailyChallengeProgress(player, game, playerData)
    local today = os.date("%Y-%m-%d")
    local todaysChallenges = self.DailyChallenges[today]
    if not todaysChallenges then return end
    
    local playerProgress = self.PlayerScores[player.UserId].dailyProgress
    if not playerProgress[today] then
        playerProgress[today] = {}
    end
    
    for challengeType, challenge in pairs(todaysChallenges) do
        if not challenge.completedBy[player.UserId] then
            local progress = playerProgress[today][challengeType] or 0
            
            if challenge.requirement == "score" and playerData.score >= challenge.threshold then
                self:CompleteDailyChallenge(player, challengeType, challenge)
            elseif challenge.requirement == "perfection" then
                local rank = self:DetermineRank(game, playerData)
                if rank == "gold" then
                    progress = progress + 1
                    playerProgress[today][challengeType] = progress
                    if progress >= challenge.threshold then
                        self:CompleteDailyChallenge(player, challengeType, challenge)
                    end
                end
            end
        end
    end
end

function MiniGameManager:CompleteDailyChallenge(player, challengeType, challenge)
    challenge.completedBy[player.UserId] = tick()
    
    -- Give rewards
    self:GiveGameRewards(player, challenge.rewards)
    
    -- Notify player
    local notificationManager = _G.NotificationManager
    if notificationManager then
        notificationManager:ShowToast(
            "Daily Challenge Complete! 🌟",
            challenge.name,
            "📅",
            "daily_challenge"
        )
    end
end

function MiniGameManager:CheckDailyChallenges()
    local today = os.date("%Y-%m-%d")
    
    -- Create new challenges if day changed
    if not self.DailyChallenges[today] then
        self:InitializeDailyChallenges()
    end
    
    -- Clean up old challenges (keep last 7 days)
    local cutoffDate = os.date("%Y-%m-%d", os.time() - (7 * 24 * 3600))
    for date, _ in pairs(self.DailyChallenges) do
        if date < cutoffDate then
            self.DailyChallenges[date] = nil
        end
    end
end

-- ==========================================
-- GAME UPDATES
-- ==========================================

function MiniGameManager:UpdateActiveGames()
    for gameId, game in pairs(self.ActiveGames) do
        if game.status == "active" and tick() >= game.endTime then
            -- Auto-end expired games
            self:EndExpiredGame(gameId)
        end
    end
end

function MiniGameManager:EndExpiredGame(gameId)
    local game = self.ActiveGames[gameId]
    if not game then return end
    
    game.status = "expired"
    
    -- End game for all players
    for userId, playerData in pairs(game.players) do
        if not playerData.completed then
            playerData.completed = true
            playerData.endTime = tick()
            
            -- Give partial rewards if any progress made
            if playerData.score > 0 then
                local partialRewards = self:CalculatePartialRewards(game, playerData)
                if partialRewards then
                    local player = Players:GetPlayerByUserId(userId)
                    if player then
                        self:GiveGameRewards(player, partialRewards)
                    end
                end
            end
        end
    end
    
    -- Remove game
    self.ActiveGames[gameId] = nil
end

function MiniGameManager:CalculatePartialRewards(game, playerData)
    -- Give reduced rewards for partial completion
    local gameTemplate = game.template
    if gameTemplate.rewards.bronze then
        local partialRewards = {}
        for rewardType, amount in pairs(gameTemplate.rewards.bronze) do
            partialRewards[rewardType] = math.floor(amount * 0.5) -- 50% of bronze rewards
        end
        return partialRewards
    end
    return nil
end

-- ==========================================
-- HELPER FUNCTIONS
-- ==========================================

function MiniGameManager:AllPlayersFinished(game)
    for userId, playerData in pairs(game.players) do
        if not playerData.completed then
            return false
        end
    end
    return true
end

function MiniGameManager:RemovePlayerFromGame(gameId, userId)
    local game = self.ActiveGames[gameId]
    if game and game.players[userId] then
        game.players[userId] = nil
        
        -- Remove game if empty
        if next(game.players) == nil then
            self.ActiveGames[gameId] = nil
        end
    end
end

function MiniGameManager:IsPlayerVIP(player)
    local vipManager = _G.VIPManager
    if vipManager then
        return vipManager:IsPlayerVIP(player)
    end
    return false
end

function MiniGameManager:GetPlayerStats(player)
    local playerData = self.PlayerScores[player.UserId]
    if not playerData then return {} end
    
    return {
        stats = playerData.stats,
        achievements = playerData.achievements,
        bestScores = playerData.stats.bestScores
    }
end

-- ==========================================
-- GAME-SPECIFIC HELPER FUNCTIONS
-- ==========================================

function MiniGameManager:GeneratePuzzleGrid()
    -- Generate a random puzzle grid
    local grid = {}
    for i = 1, 4 do
        grid[i] = {}
        for j = 1, 4 do
            grid[i][j] = math.random(1, 6) -- 6 different plant types
        end
    end
    return grid
end

function MiniGameManager:GenerateTargetPattern()
    -- Generate target pattern for puzzle
    return {
        {1, 2, 3, 4},
        {2, 3, 4, 1},
        {3, 4, 1, 2},
        {4, 1, 2, 3}
    }
end

function MiniGameManager:GenerateBeatPattern()
    -- Generate rhythm pattern
    local pattern = {}
    for i = 1, 30 do -- 30 beats
        table.insert(pattern, {
            time = i * 1000, -- milliseconds
            type = math.random(1, 4) -- 4 different beat types
        })
    end
    return pattern
end

function MiniGameManager:GenerateHarvestField()
    -- Generate field of crops to harvest
    local field = {}
    for i = 1, 50 do
        table.insert(field, {
            position = {x = math.random(1, 10), y = math.random(1, 10)},
            type = math.random(1, 5), -- 5 crop types
            points = math.random(10, 50)
        })
    end
    return field
end

function MiniGameManager:GenerateRandomSeeds()
    -- Generate random seeds for sorting
    local seeds = {}
    for i = 1, 20 do
        table.insert(seeds, {
            id = i,
            color = math.random(1, 5),
            type = math.random(1, 4),
            size = math.random(1, 3)
        })
    end
    return seeds
end

function MiniGameManager:GenerateMemorySequence()
    -- Generate memory sequence
    local sequence = {}
    for i = 1, 8 do
        table.insert(sequence, math.random(1, 6)) -- 6 different flowers
    end
    return sequence
end

-- Placeholder validation functions
function MiniGameManager:IsValidPuzzleMove(grid, from, to)
    return true -- Simplified validation
end

function MiniGameManager:SwapPuzzlePieces(grid, from, to)
    local temp = grid[from.x][from.y]
    grid[from.x][from.y] = grid[to.x][to.y]
    grid[to.x][to.y] = temp
end

function MiniGameManager:IsPuzzleSolved(grid, target)
    -- Check if grid matches target pattern
    for i = 1, 4 do
        for j = 1, 4 do
            if grid[i][j] ~= target[i][j] then
                return false
            end
        end
    end
    return true
end

function MiniGameManager:CalculatePuzzleScore(gameData)
    return gameData.movesLeft * 100 -- Score based on moves remaining
end

function MiniGameManager:IsValidHarvest(field, position, cropType)
    for _, crop in ipairs(field) do
        if crop.position.x == position.x and 
           crop.position.y == position.y and 
           crop.type == cropType then
            return true
        end
    end
    return false
end

function MiniGameManager:RemoveHarvestedCrop(field, position)
    for i, crop in ipairs(field) do
        if crop.position.x == position.x and crop.position.y == position.y then
            table.remove(field, i)
            break
        end
    end
end

function MiniGameManager:GetCropPoints(cropType)
    local points = {10, 20, 30, 40, 50}
    return points[cropType] or 10
end

function MiniGameManager:IsSeedSortedCorrectly(seeds, seedId, category)
    -- Simplified validation
    return math.random() > 0.3 -- 70% chance of correct sort
end

function MiniGameManager:UseDefenseItem(gameData, defenseType, target)
    -- Simplified defense logic
    return math.random() > 0.2 -- 80% success rate
end

-- ==========================================
-- CLEANUP
-- ==========================================

function MiniGameManager:Cleanup()
    -- End all active games
    for gameId, game in pairs(self.ActiveGames) do
        self:EndExpiredGame(gameId)
    end
    
    -- Save all player data
    for userId, _ in pairs(self.PlayerScores) do
        local player = Players:GetPlayerByUserId(userId)
        if player then
            self:SavePlayerGameData(player)
        end
    end
    
    -- Save leaderboards
    self:SaveLeaderboards()
    
    print("🎮 MiniGameManager: Mini-game system cleaned up")
end

return MiniGameManager
