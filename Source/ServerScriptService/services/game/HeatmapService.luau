--!strict
--[[
	HeatmapService
	Tracks player positions on a 2D grid (X/Z) and sends heatmap data to GA4.

	Two modes (set via AnalyticsConfig.heatmap.trackingMode):
	- "summary" (default): Accumulates per-cell dwell time in memory, flushes periodically.
	  Low event volume, suitable for production.
	- "transitions": Fires a GA4 event each time a player crosses a cell boundary.
	  High granularity but high event volume, best for testing/small games.

	Configure bounds and cell size in AnalyticsConfig.heatmap (created in Studio).
]]

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local HeatmapService = {}

-- Types
type PlayerTrackingState = {
	currentCellX: number,
	currentCellZ: number,
	cellEnteredTime: number,
	lastHeartbeatTime: number,
}

type CellData = {
	playerSeconds: number,
	uniquePlayers: { [string]: boolean },
}

-- State
local config: any = nil
local AnalyticsService: any = nil
local playerStates: { [Player]: PlayerTrackingState } = {}
local cellAccumulator: { [string]: CellData } = {}
local isRunning = false

-- Convert world position to grid cell indices
local function positionToCell(posX: number, posZ: number): (number, number)
	local cellX = math.floor((posX - config.boundsMin[1]) / config.cellSize)
	local cellZ = math.floor((posZ - config.boundsMin[2]) / config.cellSize)
	return cellX, cellZ
end

-- Check if a world position is within the configured bounds
local function isInBounds(posX: number, posZ: number): boolean
	return posX >= config.boundsMin[1] and posX <= config.boundsMax[1]
		and posZ >= config.boundsMin[2] and posZ <= config.boundsMax[2]
end

-- Get a cell key string for the accumulator
local function cellKey(cellX: number, cellZ: number): string
	return cellX .. "_" .. cellZ
end

-- Get the HumanoidRootPart position for a player (nil if unavailable)
local function getPlayerPosition(player: Player): (number?, number?)
	local character = player.Character
	if not character then
		return nil, nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return nil, nil
	end

	local pos = rootPart.Position
	return pos.X, pos.Z
end

-- Summary mode: accumulate dwell time for a cell
local function accumulateCell(key: string, seconds: number, playerId: string)
	if not cellAccumulator[key] then
		cellAccumulator[key] = {
			playerSeconds = 0,
			uniquePlayers = {},
		}
	end

	cellAccumulator[key].playerSeconds += seconds
	cellAccumulator[key].uniquePlayers[playerId] = true
end

-- Summary mode: flush all accumulated cell data to GA4
local function flushSummary()
	-- Pick any online player to attribute events to (cell data is aggregate, user attribution doesn't matter)
	local players = Players:GetPlayers()
	if #players == 0 then
		-- No players online, clear accumulator
		cellAccumulator = {}
		return
	end

	local eventPlayer = players[1]

	for key, data in cellAccumulator do
		-- Parse cell coordinates from key
		local underscorePos = key:find("_")
		if underscorePos then
			local cX = tonumber(key:sub(1, underscorePos - 1))
			local cZ = tonumber(key:sub(underscorePos + 1))

			if cX and cZ then
				-- Count unique players
				local uniqueCount = 0
				for _ in data.uniquePlayers do
					uniqueCount += 1
				end

				AnalyticsService:trackEvent(eventPlayer, "heatmap_summary", {
					cell_x = cX,
					cell_z = cZ,
					player_seconds = math.floor(data.playerSeconds),
					unique_players = uniqueCount,
				})
			end
		end
	end

	cellAccumulator = {}
end

-- Transitions mode: fire a cell event for a player
local function fireTransitionEvent(player: Player, cellX: number, cellZ: number, dwellSeconds: number)
	AnalyticsService:trackEvent(player, "heatmap_cell", {
		cell_x = cellX,
		cell_z = cellZ,
		dwell_seconds = math.floor(dwellSeconds),
	})
end

-- Transitions mode: fire a presence heartbeat for a stationary player
local function firePresenceEvent(player: Player, cellX: number, cellZ: number, dwellSeconds: number)
	AnalyticsService:trackEvent(player, "heatmap_presence", {
		cell_x = cellX,
		cell_z = cellZ,
		dwell_seconds = math.floor(dwellSeconds),
	})
end

-- Process one sample tick for all players
local function sampleTick()
	local now = os.clock()
	local isSummary = config.trackingMode == "summary"

	for _, player in Players:GetPlayers() do
		local posX, posZ = getPlayerPosition(player)
		if posX == nil or posZ == nil then
			continue
		end

		if not isInBounds(posX :: number, posZ :: number) then
			-- Player left bounds — flush previous cell if tracked
			local state = playerStates[player]
			if state then
				if isSummary then
					local key = cellKey(state.currentCellX, state.currentCellZ)
					accumulateCell(key, now - state.cellEnteredTime, tostring(player.UserId))
				else
					local dwell = now - state.cellEnteredTime
					fireTransitionEvent(player, state.currentCellX, state.currentCellZ, dwell)
				end
				playerStates[player] = nil
			end
			continue
		end

		local cellX, cellZ = positionToCell(posX :: number, posZ :: number)
		local state = playerStates[player]

		if not state then
			-- First time seeing this player in bounds
			playerStates[player] = {
				currentCellX = cellX,
				currentCellZ = cellZ,
				cellEnteredTime = now,
				lastHeartbeatTime = now,
			}
			continue
		end

		if isSummary then
			-- Accumulate time in current cell
			local key = cellKey(cellX, cellZ)
			accumulateCell(key, config.sampleIntervalSeconds, tostring(player.UserId))

			-- Update state if cell changed
			state.currentCellX = cellX
			state.currentCellZ = cellZ
			state.cellEnteredTime = now
		else
			-- Transitions mode
			if cellX ~= state.currentCellX or cellZ ~= state.currentCellZ then
				-- Cell changed — fire event for previous cell
				local dwell = now - state.cellEnteredTime
				fireTransitionEvent(player, state.currentCellX, state.currentCellZ, dwell)

				state.currentCellX = cellX
				state.currentCellZ = cellZ
				state.cellEnteredTime = now
				state.lastHeartbeatTime = now
			elseif now - state.lastHeartbeatTime >= config.heartbeatIntervalSeconds then
				-- Stationary heartbeat
				local dwell = now - state.lastHeartbeatTime
				firePresenceEvent(player, cellX, cellZ, dwell)
				state.lastHeartbeatTime = now
			end
		end
	end
end

-- Start the sample loop
local function startSampleLoop()
	if isRunning then
		return
	end
	isRunning = true

	task.spawn(function()
		local lastFlushTime = os.clock()

		while true do
			task.wait(config.sampleIntervalSeconds)
			sampleTick()

			-- Summary mode: periodic flush
			if config.trackingMode == "summary" then
				if os.clock() - lastFlushTime >= config.flushIntervalSeconds then
					flushSummary()
					lastFlushTime = os.clock()
				end
			end
		end
	end)
end

-- Handle player leaving — flush their final dwell time
-- In summary mode, also flush the accumulator while this player is still available
-- as the event source (avoids losing data if they're the last player)
local function onPlayerRemoving(player: Player)
	local state = playerStates[player]
	if not state then
		return
	end

	local now = os.clock()

	if config.trackingMode == "summary" then
		local key = cellKey(state.currentCellX, state.currentCellZ)
		accumulateCell(key, now - state.cellEnteredTime, tostring(player.UserId))

		-- If this is the last player, flush now while we still have someone to attribute events to
		if #Players:GetPlayers() <= 1 then
			flushSummary()
		end
	else
		local dwell = now - state.cellEnteredTime
		fireTransitionEvent(player, state.currentCellX, state.currentCellZ, dwell)
	end

	playerStates[player] = nil
end

-- Handle character spawning — reset tracking state
local function onCharacterAdded(player: Player, character: Model)
	-- Wait briefly for HumanoidRootPart to be available
	local rootPart = character:WaitForChild("HumanoidRootPart", 5)
	if not rootPart then
		return
	end

	local pos = (rootPart :: BasePart).Position
	if not isInBounds(pos.X, pos.Z) then
		playerStates[player] = nil
		return
	end

	local cellX, cellZ = positionToCell(pos.X, pos.Z)
	local now = os.clock()

	playerStates[player] = {
		currentCellX = cellX,
		currentCellZ = cellZ,
		cellEnteredTime = now,
		lastHeartbeatTime = now,
	}
end

-- Initialize the HeatmapService
function HeatmapService.init()
	-- Load config from AnalyticsConfig.heatmap
	local configFolder = ServerScriptService:FindFirstChild("Config")
	if not configFolder then
		return
	end

	local analyticsConfig = configFolder:FindFirstChild("AnalyticsConfig")
	if not analyticsConfig then
		return
	end

	local fullConfig = require(analyticsConfig)
	if not fullConfig.heatmap or not fullConfig.heatmap.enabled then
		print("[HeatmapService] Heatmap tracking disabled or not configured")
		return
	end

	config = fullConfig.heatmap

	-- Get AnalyticsService
	local ServiceRunner = require(script.Parent.Parent.ServiceRunner)
	AnalyticsService = ServiceRunner.getAnalyticsService()

	if not AnalyticsService or not AnalyticsService.isEnabled then
		warn("[HeatmapService] AnalyticsService not available or disabled - heatmap tracking requires analytics")
		return
	end

	-- Set up player lifecycle handlers
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		if player.Character then
			task.spawn(onCharacterAdded, player, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end)

	startSampleLoop()

	local gridWidth = math.ceil((config.boundsMax[1] - config.boundsMin[1]) / config.cellSize)
	local gridDepth = math.ceil((config.boundsMax[2] - config.boundsMin[2]) / config.cellSize)
	print(string.format(
		"[HeatmapService] Initialized (%s mode, %dx%d grid, %d stud cells)",
		config.trackingMode,
		gridWidth,
		gridDepth,
		config.cellSize
	))
end

return HeatmapService
