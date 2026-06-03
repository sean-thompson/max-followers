--!strict

local DataStoreService = game:GetService('DataStoreService')
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')

local PersistenceService = {}

-- Configuration
local BASE_TOKENS = 50 -- Base tokens available (safety margin from 60)
local TOKENS_PER_PLAYER = 8 -- Additional tokens per player in the game
local TOKEN_REGENERATION_RATE = 1 -- Tokens per second
local MINIMUM_WAIT_BETWEEN_WRITES = 0.1 -- Wait even when tokens available
local WRITE_DEBOUNCE_DELAY = 2 -- Seconds a key must be idle before being written
local QUEUE_WARNING_THRESHOLD = 100 -- Warn if queue gets too large

-- Types
type WriteRequest = {
	modelName: string,
	ownerId: string,
	modelId: string?,
	data: { [string]: any },
	timestamp: number,
}

-- State
local dataStore: DataStore = nil
local writeQueue: { WriteRequest } = {}
local currentMaxTokens = BASE_TOKENS
local currentTokens = BASE_TOKENS
local lastTokenRegenTime = 0
local isProcessing = false

-- Helper function to serialize model data
local function serializeModelData(modelInstance: any): { [string]: any }
	local serialized = {}

	for key, value in pairs(modelInstance) do
		-- Skip functions, RemoteEvent references, and internal metadata (fields starting with _)
		local valueType = type(value)
		if valueType ~= "function" and valueType ~= "userdata" and key ~= "remoteEvent" and not key:match("^_") then
			serialized[key] = value
		end
	end

	return serialized
end

-- Update max tokens based on current player count
local function updateMaxTokens()
	local playerCount = #Players:GetPlayers()
	local newMax = BASE_TOKENS + (TOKENS_PER_PLAYER * playerCount)

	currentMaxTokens = newMax

	-- If current tokens exceed new max, cap them
	if currentTokens > currentMaxTokens then
		currentTokens = currentMaxTokens
	end

	print(
		string.format(
			"[PersistenceService] Max tokens updated: %d (base: %d + %d players × %d)",
			currentMaxTokens,
			BASE_TOKENS,
			playerCount,
			TOKENS_PER_PLAYER
		)
	)
end

-- Regenerate tokens based on elapsed time
local function regenerateTokens()
	local currentTime = os.clock()
	local elapsedTime = currentTime - lastTokenRegenTime

	if elapsedTime >= 1 then
		local tokensToAdd = math.floor(elapsedTime / TOKEN_REGENERATION_RATE)
		currentTokens = math.min(currentMaxTokens, currentTokens + tokensToAdd)
		lastTokenRegenTime = currentTime
	end
end

-- Process a single write from the queue
local function processWrite(request: WriteRequest): boolean
	-- Build DataStore key with optional modelId
	local key = if request.modelId
		then request.modelName .. "_" .. request.ownerId .. "_" .. request.modelId
		else request.modelName .. "_" .. request.ownerId

	-- Attempt to write to DataStore
	local success, err = pcall(function()
		dataStore:SetAsync(key, request.data)
	end)

	if success then
		print(
			string.format(
				"[PersistenceService] ✓ Successfully wrote %s for owner %s%s",
				request.modelName,
				request.ownerId,
				request.modelId and (" (entity: " .. request.modelId .. ")") or ""
			)
		)
		return true
	else
		warn(string.format(
			"[PersistenceService] ✗ Failed to write %s for owner %s%s: %s",
			request.modelName,
			request.ownerId,
			request.modelId and (" (entity: " .. request.modelId .. ")") or "",
			tostring(err)
		))
		return false
	end
end

-- Background loop to process the write queue
local function startQueueProcessor()
	if isProcessing then
		return
	end

	isProcessing = true

	task.spawn(function()
		while true do
			regenerateTokens()

			-- Check if we have work to do
			if #writeQueue > 0 then
				-- Warn if queue is getting large
				if #writeQueue > QUEUE_WARNING_THRESHOLD then
					local modelCounts: { [string]: number } = {}
					for _, req in ipairs(writeQueue) do
						modelCounts[req.modelName] = (modelCounts[req.modelName] or 0) + 1
					end

					local parts: { string } = {}
					for modelName, count in pairs(modelCounts) do
						table.insert(parts, string.format("%s×%d", modelName, count))
					end
					table.sort(parts)

					warn(
						string.format(
							"[PersistenceService] Queue is large (%d items). Consider optimizing write frequency. Breakdown: %s",
							#writeQueue,
							table.concat(parts, ", ")
						)
					)
				end

				-- Find the first request that has been idle long enough (debounce)
				local readyIndex: number? = nil
				local nowMs = DateTime.now().UnixTimestampMillis
				for i, req in ipairs(writeQueue) do
					if (nowMs - req.timestamp) >= (WRITE_DEBOUNCE_DELAY * 1000) then
						readyIndex = i
						break
					end
				end

				-- Check if we have a ready request and tokens available
				if readyIndex and currentTokens > 0 then
					local request = table.remove(writeQueue, readyIndex)

					-- Consume a token
					currentTokens = currentTokens - 1

					-- Process the write
					processWrite(request)

					-- Wait a bit even when we have tokens
					task.wait(MINIMUM_WAIT_BETWEEN_WRITES)
				else
					-- No ready requests or no tokens available
					task.wait(currentTokens > 0 and 0.5 or 1)
				end
			else
				-- No work to do, wait a bit before checking again
				task.wait(0.5)
			end
		end
	end)
end

-- Initialize the PersistenceService
function PersistenceService.init()
	-- Only initialize in non-Studio environments or in Studio if testing
	if RunService:IsStudio() then
		warn("[PersistenceService] Running in Studio - DataStore operations may be limited")
	end

	-- Get or create the DataStore
	local success, result = pcall(function()
		return DataStoreService:GetDataStore("PlayerData")
	end)

	if success then
		dataStore = result
		print("[PersistenceService] Initialized successfully")
	else
		warn("[PersistenceService] Failed to initialize DataStore: " .. tostring(result))
		warn("[PersistenceService] Make sure Studio Access to API Services is enabled")
		-- Create a dummy dataStore to prevent errors
		dataStore = {
			SetAsync = function()
				warn("[PersistenceService] Dummy SetAsync called - DataStore not available")
			end,
			GetAsync = function()
				warn("[PersistenceService] Dummy GetAsync called - DataStore not available")
				return nil -- Simulate new player with no saved data
			end,
			RemoveAsync = function()
				warn("[PersistenceService] Dummy RemoveAsync called - DataStore not available")
			end,
		} :: any
	end

	-- Initialize token regeneration timer
	lastTokenRegenTime = os.clock()

	-- Set up player tracking for dynamic max tokens
	updateMaxTokens() -- Initial calculation

	Players.PlayerAdded:Connect(function(player)
		updateMaxTokens()
	end)

	Players.PlayerRemoving:Connect(function(player)
		updateMaxTokens()
	end)

	-- Handle server shutdown to flush all pending writes
	game:BindToClose(function()
		-- Skip in Studio to avoid blocking offline testing
		if RunService:IsStudio() then
			print("[PersistenceService] BindToClose skipped in Studio")
			return
		end

		print("[PersistenceService] Server shutting down - flushing all pending writes")
		PersistenceService:flushAllWrites()
	end)

	-- Start the background processor
	startQueueProcessor()
end

-- Load a model's data from DataStore
-- Returns (success: boolean, data: any?)
-- - New player/entity: (true, nil) - Success, no data found
-- - Existing player/entity: (true, data) - Success with loaded data
-- - Load failed: (false, nil) - Failure, should kick player
function PersistenceService:loadModel(modelName: string, ownerId: string, modelId: string?): (boolean, { [string]: any }?)
	local key = if modelId
		then modelName .. "_" .. ownerId .. "_" .. modelId
		else modelName .. "_" .. ownerId

	local success, result = pcall(function()
		return dataStore:GetAsync(key)
	end)

	if success then
		if result then
			print(
				string.format(
					"[PersistenceService] ✓ Loaded %s for owner %s%s",
					modelName,
					ownerId,
					modelId and (" (entity: " .. modelId .. ")") or ""
				)
			)
			return true, result
		else
			-- No data found (new player/entity)
			print(
				string.format(
					"[PersistenceService] No saved data for %s (owner: %s%s) - using defaults",
					modelName,
					ownerId,
					modelId and (", entity: " .. modelId) or ""
				)
			)
			return true, nil
		end
	else
		-- Load failed
		warn(
			string.format(
				"[PersistenceService] ✗ Failed to load %s for owner %s%s: %s",
				modelName,
				ownerId,
				modelId and (" (entity: " .. modelId .. ")") or "",
				tostring(result)
			)
		)
		return false, nil
	end
end

-- Delete a model's data from DataStore
-- Cancels any pending writes for the same key first to prevent resurrection
function PersistenceService:deleteModel(modelName: string, ownerId: string, modelId: string?)
	local key = modelName .. "_" .. ownerId
	if modelId then
		key = key .. "_" .. modelId
	end

	-- Cancel any pending writes for this key to prevent them overwriting the delete
	local i = 1
	local cancelledCount = 0
	while i <= #writeQueue do
		local request = writeQueue[i]
		local requestKey = request.modelName .. "_" .. request.ownerId
		if request.modelId then
			requestKey = requestKey .. "_" .. request.modelId
		end
		if requestKey == key then
			table.remove(writeQueue, i)
			cancelledCount += 1
		else
			i += 1
		end
	end

	if cancelledCount > 0 then
		print(string.format("[PersistenceService] Cancelled %d pending write(s) for %s before delete", cancelledCount, key))
	end

	local success, err = pcall(function()
		dataStore:RemoveAsync(key)
	end)

	if success then
		print(string.format("[PersistenceService] ✓ Deleted %s", key))
	else
		warn(string.format("[PersistenceService] ✗ Failed to delete %s: %s", key, tostring(err)))
	end
end

-- Queue a write request
function PersistenceService:queueWrite(modelName: string, ownerId: string, modelInstance: any, modelId: string?)
	-- Serialize the model data
	local serializedData = serializeModelData(modelInstance)

	-- Build key for dedup lookup
	local key = modelName .. "_" .. ownerId
	if modelId then
		key = key .. "_" .. modelId
	end

	-- Coalesce: if a pending write for this key already exists, update it in-place
	for _, existing in ipairs(writeQueue) do
		local existingKey = existing.modelName .. "_" .. existing.ownerId
		if existing.modelId then
			existingKey = existingKey .. "_" .. existing.modelId
		end
		if existingKey == key then
			existing.data = serializedData
			existing.timestamp = DateTime.now().UnixTimestampMillis
			return
		end
	end

	-- No existing entry — append a new request
	local request: WriteRequest = {
		modelName = modelName,
		ownerId = ownerId,
		modelId = modelId,
		data = serializedData,
		timestamp = DateTime.now().UnixTimestampMillis,
	}

	table.insert(writeQueue, request)

	print(
		string.format(
			"[PersistenceService] Queued write for %s (owner: %s%s) - Queue size: %d, Tokens: %d",
			modelName,
			ownerId,
			modelId and (", entity: " .. modelId) or "",
			#writeQueue,
			currentTokens
		)
	)
end

-- Flush all pending writes for a specific player
-- Used when a player is leaving to ensure their data is saved
function PersistenceService:flushPlayerWrites(ownerId: string)
	print(string.format("[PersistenceService] Flushing writes for owner %s", ownerId))

	local flushedCount = 0
	local i = 1

	-- Process all queued writes for this player
	while i <= #writeQueue do
		local request = writeQueue[i]

		if request.ownerId == ownerId then
			-- Remove from queue
			table.remove(writeQueue, i)

			-- Process immediately (skip token limiting for critical saves)
			processWrite(request)
			flushedCount = flushedCount + 1

			-- Don't increment i since we removed an element
		else
			i = i + 1
		end
	end

	print(string.format("[PersistenceService] Flushed %d write(s) for owner %s", flushedCount, ownerId))
end

-- Flush all pending writes
-- Used during server shutdown to ensure no data is lost
function PersistenceService:flushAllWrites()
	local queueSize = #writeQueue
	print(string.format("[PersistenceService] Flushing all writes (%d items in queue)", queueSize))

	local startTime = os.clock()
	local successCount = 0
	local failCount = 0

	-- Process all queued writes
	while #writeQueue > 0 do
		local request = table.remove(writeQueue, 1)

		-- Process immediately (skip token limiting for critical saves)
		local success = processWrite(request)

		if success then
			successCount = successCount + 1
		else
			failCount = failCount + 1
		end

		-- Check if we're running out of time (BindToClose has 30 second limit)
		local elapsedTime = os.clock() - startTime
		if elapsedTime > 28 then
			warn(string.format("[PersistenceService] Approaching BindToClose timeout! %d items remaining", #writeQueue))
			break
		end
	end

	local totalTime = os.clock() - startTime
	print(
		string.format(
			"[PersistenceService] Flush complete: %d succeeded, %d failed, %.2fs elapsed",
			successCount,
			failCount,
			totalTime
		)
	)
end

-- Get queue stats (useful for debugging)
function PersistenceService:getStats(): { queueSize: number, availableTokens: number, maxTokens: number }
	regenerateTokens()
	return {
		queueSize = #writeQueue,
		availableTokens = currentTokens,
		maxTokens = currentMaxTokens,
	}
end

return PersistenceService
