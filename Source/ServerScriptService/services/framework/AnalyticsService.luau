--!strict
--[[
	AnalyticsService
	Server-side GA4 analytics via the Measurement Protocol.

	Auto-instruments controller actions and player lifecycle events.
	Events are batched in memory and flushed periodically to minimize HTTP requests.

	Setup:
	1. Create a ModuleScript in Studio at ServerScriptService.Config.AnalyticsConfig
	2. Fill in measurementId, apiSecret, hashSalt, and set enabled = true
	3. Enable HttpService in Game Settings

	Custom events:
		local AnalyticsService = require(ServerScriptService.services.framework.AnalyticsService)
		AnalyticsService:trackEvent(player, "purchase_complete", {
			item_name = "Golden Sword",
			item_price = 500,
		})
]]

local HttpService = game:GetService("HttpService")
local LocalizationService = game:GetService("LocalizationService")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local AnalyticsService = {}

-- Types
type GA4Event = {
	name: string,
	params: { [string]: any },
	timestamp_micros: number?,
}

type QueuedEvent = {
	clientId: string,
	event: GA4Event,
}

type UserProperties = {
	locale: { value: string },
	country: { value: string },
	account_age_days: { value: string },
	membership: { value: string },
}

-- State
local config = nil :: any
local eventQueue: { QueuedEvent } = {}
local userPropertiesCache: { [string]: UserProperties } = {}
local playerJoinTimes: { [string]: number } = {}
local numericSessionId: number = 0
local isRunning = false

-- Public flag checked by AbstractController to avoid require overhead
AnalyticsService.isEnabled = false

-- DJB2 hash with salt for one-way UserId hashing
local function djb2Hash(input: string): string
	local hash: number = 5381
	for i = 1, #input do
		hash = ((hash * 33) + string.byte(input, i)) % (2 ^ 32)
	end
	return string.format("%08x", hash)
end

local function hashUserId(userId: number): string
	return djb2Hash(config.hashSalt .. tostring(userId))
end

-- Convert JobId (UUID string) to a numeric session ID for GA4
local function generateNumericSessionId(): number
	local hash: number = 5381
	local jobId = game.JobId
	if jobId == "" then
		-- Studio doesn't have a JobId; use a random number
		return math.random(1, 2^31 - 1)
	end
	for i = 1, #jobId do
		hash = ((hash * 33) + string.byte(jobId, i)) % (2 ^ 32)
	end
	return hash
end

-- Build the GA4 endpoint URL
local function getEndpointUrl(): string
	return string.format(
		"https://www.google-analytics.com/mp/collect?measurement_id=%s&api_secret=%s",
		config.measurementId,
		config.apiSecret
	)
end

-- Send a batch of events to GA4 for a single client
local function sendBatch(clientId: string, events: { GA4Event }, userProperties: UserProperties?): boolean
	local body = HttpService:JSONEncode({
		client_id = clientId,
		user_id = clientId,
		user_properties = userProperties,
		events = events,
	})

	local success, err = pcall(function()
		HttpService:PostAsync(getEndpointUrl(), body, Enum.HttpContentType.ApplicationJson, false)
	end)

	if success then
		if config.debug then
			print(string.format("[AnalyticsService] Sent batch of %d event(s) for client %s", #events, clientId))
		end
	else
		warn(string.format("[AnalyticsService] Failed to send batch: %s", tostring(err)))
	end

	return success
end

-- Flush all queued events, grouped by clientId and chunked into batches
local function flushEvents(filterClientId: string?)
	if #eventQueue == 0 then
		return
	end

	-- Separate events to flush vs events to keep
	local toFlush: { QueuedEvent } = {}
	local toKeep: { QueuedEvent } = {}

	for _, queuedEvent in eventQueue do
		if filterClientId == nil or queuedEvent.clientId == filterClientId then
			table.insert(toFlush, queuedEvent)
		else
			table.insert(toKeep, queuedEvent)
		end
	end

	eventQueue = toKeep

	if #toFlush == 0 then
		return
	end

	-- Group by clientId
	local grouped: { [string]: { GA4Event } } = {}
	for _, queuedEvent in toFlush do
		if not grouped[queuedEvent.clientId] then
			grouped[queuedEvent.clientId] = {}
		end
		table.insert(grouped[queuedEvent.clientId], queuedEvent.event)
	end

	-- Send each group in chunks of maxBatchSize
	for clientId, events in grouped do
		local userProps = userPropertiesCache[clientId]

		for i = 1, #events, config.maxBatchSize do
			local batch: { GA4Event } = {}
			for j = i, math.min(i + config.maxBatchSize - 1, #events) do
				table.insert(batch, events[j])
			end
			local ok = sendBatch(clientId, batch, userProps)
			if not ok then
				for _, event in batch do
					table.insert(eventQueue, { clientId = clientId, event = event })
				end
			end
		end
	end

	if config.debug then
		print(string.format("[AnalyticsService] Flushed %d event(s)", #toFlush))
	end
end

-- Background loop to periodically flush events
local function startFlushLoop()
	if isRunning then
		return
	end
	isRunning = true

	task.spawn(function()
		while true do
			task.wait(config.flushIntervalSeconds)
			flushEvents()
		end
	end)
end

-- Queue an event for a player
local function queueEvent(player: Player, eventName: string, params: { [string]: any }?)
	if not AnalyticsService.isEnabled then
		return
	end

	local clientId = hashUserId(player.UserId)

	local now = DateTime.now()
	local timestampMs = now.UnixTimestampMillis
	local timestampMicros = timestampMs * 1000

	local eventParams: { [string]: any } = params and table.clone(params) or {}
	eventParams.session_id = tostring(numericSessionId)
	eventParams.engagement_time_msec = 1
	eventParams.timestamp = timestampMs
	if config.debug then
		eventParams.debug_mode = true
	end

	local event: GA4Event = {
		name = eventName,
		params = eventParams,
		timestamp_micros = timestampMicros,
	}

	table.insert(eventQueue, {
		clientId = clientId,
		event = event,
	})

	if config.debug then
		print(string.format("[AnalyticsService] Queued event '%s' for player %s (queue size: %d)", eventName, player.Name, #eventQueue))
	end

	-- Auto-flush if this player's events hit the batch limit
	local playerEventCount = 0
	for _, queuedEvent in eventQueue do
		if queuedEvent.clientId == clientId then
			playerEventCount += 1
		end
	end

	if playerEventCount >= config.maxBatchSize then
		flushEvents(clientId)
	end
end

-- Initialize the AnalyticsService
function AnalyticsService.init()
	-- Load config from ServerScriptService.Config
	local configFolder = ServerScriptService:FindFirstChild("Config")
	if not configFolder then
		warn("[AnalyticsService] No Config folder found in ServerScriptService")
		return
	end

	local analyticsConfig = configFolder:FindFirstChild("AnalyticsConfig")
	if not analyticsConfig then
		warn("[AnalyticsService] No AnalyticsConfig found in ServerScriptService.Config - create it in Studio")
		return
	end

	config = require(analyticsConfig)

	if not config.enabled then
		print("[AnalyticsService] Analytics disabled in config")
		return
	end

	if config.measurementId == "" or config.apiSecret == "" then
		warn("[AnalyticsService] Missing measurementId or apiSecret in AnalyticsConfig")
		return
	end

	AnalyticsService.isEnabled = true
	numericSessionId = generateNumericSessionId()

	-- Flush all events on server shutdown
	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		print("[AnalyticsService] Server shutting down - flushing all analytics events")
		AnalyticsService:flushAll()
	end)

	startFlushLoop()
	print("[AnalyticsService] Initialized")
end

-- Cache demographic user properties on player join
function AnalyticsService:cacheUserProperties(player: Player)
	if not AnalyticsService.isEnabled then
		return
	end

	local clientId = hashUserId(player.UserId)

	-- Get country code (async call, may fail)
	local country = "unknown"
	local countrySuccess, countryResult = pcall(function()
		return LocalizationService:GetCountryRegionForPlayerAsync(player)
	end)
	if countrySuccess and countryResult then
		country = countryResult
	end

	userPropertiesCache[clientId] = {
		locale = { value = player.LocaleId },
		country = { value = country },
		account_age_days = { value = tostring(player.AccountAge) },
		membership = { value = tostring(player.MembershipType) },
	}

	playerJoinTimes[clientId] = os.clock()

	if config.debug then
		print(string.format(
			"[AnalyticsService] Cached properties for %s: locale=%s, country=%s, age=%d, membership=%s",
			player.Name,
			player.LocaleId,
			country,
			player.AccountAge,
			tostring(player.MembershipType)
		))
	end
end

-- Track a custom event
function AnalyticsService:trackEvent(player: Player, eventName: string, params: { [string]: any }?)
	queueEvent(player, eventName, params)
end

-- Track a controller action (called automatically by AbstractController)
function AnalyticsService:trackControllerAction(player: Player, controllerName: string, actionName: string)
	queueEvent(player, "controller_action", {
		controller_name = controllerName,
		action_name = actionName,
	})
end

-- Track player join
function AnalyticsService:trackPlayerJoin(player: Player)
	queueEvent(player, "player_join", {})
end

-- Track player leave
function AnalyticsService:trackPlayerLeave(player: Player)
	local clientId = hashUserId(player.UserId)
	local joinTime = playerJoinTimes[clientId]
	local sessionDuration = if joinTime then math.floor(os.clock() - joinTime) else 0

	queueEvent(player, "player_leave", {
		session_duration_seconds = sessionDuration,
	})
end

-- Flush all queued events for a specific player
function AnalyticsService:flushPlayer(player: Player)
	if not AnalyticsService.isEnabled then
		return
	end

	local clientId = hashUserId(player.UserId)
	flushEvents(clientId)

	-- Only clean up cached data if no events remain queued for this client
	-- (failed sends re-queue events and still need the cached properties)
	local hasRemainingEvents = false
	for _, queuedEvent in eventQueue do
		if queuedEvent.clientId == clientId then
			hasRemainingEvents = true
			break
		end
	end

	if not hasRemainingEvents then
		userPropertiesCache[clientId] = nil
		playerJoinTimes[clientId] = nil
	end
end

-- Flush all queued events
function AnalyticsService:flushAll()
	if not AnalyticsService.isEnabled then
		return
	end
	flushEvents()
end

return AnalyticsService
