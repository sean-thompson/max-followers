--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Initialize PersistenceService before any models are used
local AbstractModel = require(script.Parent.AbstractModel)
local ServiceRunner = require(script.Parent.Parent.services.ServiceRunner)
ServiceRunner.initPersistence()
ServiceRunner.initAnalytics()

-- Auto-discover and require all models (skip Abstract)
local modelsFolder = script.Parent
local models = {}

type ModelClass = {
	new: (ownerId: string) -> any,
	get: (ownerId: string) -> any,
	remove: (ownerId: string) -> (),
	initAllServerEntities: (() -> ())?,
}

type ModelScope = "User" | "Server" | "UserEntity" | "ServerEntity" | "UserSession"

type ModelInfo = {
	class: ModelClass,
	name: string,
	scope: ModelScope,
}

local modelInfos: { ModelInfo } = {}

-- Helper function to discover models in a folder with a specific scope
local function discoverModelsInFolder(folder: Instance, scope: ModelScope)
	for _, moduleScript in folder:GetChildren() do
		if moduleScript:IsA("ModuleScript") and not moduleScript.Name:find("^Abstract") then
			local model = require(moduleScript) :: ModelClass
			table.insert(models, model)
			table.insert(modelInfos, {
				class = model,
				name = moduleScript.Name,
				scope = scope,
			})
			print("ModelRunner: Discovered " .. scope .. "-scoped model - " .. moduleScript.Name)
		end
	end
end

-- Discover User-scoped models
local userFolder = modelsFolder:FindFirstChild("user")
if userFolder then
	discoverModelsInFolder(userFolder, "User")
end

-- Discover Server-scoped models
local serverFolder = modelsFolder:FindFirstChild("server")
if serverFolder then
	discoverModelsInFolder(serverFolder, "Server")
end

-- Discover UserEntity-scoped models
local userEntitiesFolder = modelsFolder:FindFirstChild("userEntities")
if userEntitiesFolder then
	discoverModelsInFolder(userEntitiesFolder, "UserEntity")
end

-- Discover ServerEntity-scoped models
local serverEntitiesFolder = modelsFolder:FindFirstChild("serverEntities")
if serverEntitiesFolder then
	discoverModelsInFolder(serverEntitiesFolder, "ServerEntity")
end

-- Discover UserSession-scoped models
local userSessionFolder = modelsFolder:FindFirstChild("userSession")
if userSessionFolder then
	discoverModelsInFolder(userSessionFolder, "UserSession")
end

-- Register models with SlashCommandService and initialize it
ServiceRunner.initSlashCommands()
ServiceRunner.registerModels(modelInfos)

-- Initialize Server-scoped models once (ephemeral, shared by all players)
print("ModelRunner: Initializing Server-scoped models")
for _, modelInfo in modelInfos do
	if modelInfo.scope == "Server" then
		-- Initialize with ownerId "SERVER" (no persistence)
		local instance = modelInfo.class.get("SERVER")
		print("ModelRunner: Initialized Server-scoped model - " .. modelInfo.name)
	end
end

-- Initialize ServerEntity-scoped models (ephemeral, multiple instances, shared by all players)
print("ModelRunner: Initializing ServerEntity-scoped models")
for _, modelInfo in modelInfos do
	if modelInfo.scope == "ServerEntity" then
		-- ServerEntity models need to implement initAllServerEntities() to define their entity IDs
		if modelInfo.class.initAllServerEntities then
			modelInfo.class.initAllServerEntities()
			print("ModelRunner: Initialized ServerEntity-scoped model - " .. modelInfo.name)
		end
	end
end

-- Initialize game services that depend on models
ServiceRunner.initGameServices()

-- Player initialization logic (extracted so it can handle already-present players too)
local initializedPlayers: { [number]: true } = {}

local function initializePlayer(player: Player)
	if initializedPlayers[player.UserId] then
		return
	end
	initializedPlayers[player.UserId] = true

	local ownerId = tostring(player.UserId)
	print("ModelRunner: Initializing models for player " .. player.Name)

	local PersistenceService = ServiceRunner.getPersistenceService()

	for _, modelInfo in modelInfos do
		-- Only initialize User-scoped models per player
		if modelInfo.scope == "User" then
			-- Load data from DataStore for this model
			local success, loadedData = PersistenceService:loadModel(modelInfo.name, ownerId)

			-- Guard: player may have disconnected during the DataStore yield
			if not player.Parent then
				return
			end

			-- If load failed, kick the player to prevent data loss
			if not success then
				player:Kick("Roblox servers are busy right now. Please rejoin to try again. Your progress is safe!")
				return -- Stop processing this player
			end

			-- Get or create model instance for this player (with defaults).
			-- Use getOrCreate directly — ModelRunner is the data producer and must never yield.
			local instance = AbstractModel.getOrCreate(modelInfo.name, ownerId, function()
				return modelInfo.class.new(ownerId)
			end)

			-- Apply loaded data if it exists (overwrites defaults)
			if loadedData then
				instance:_applyLoadedData(loadedData)
			end

			-- Sync initial state to client (skipPersistence=true since we just loaded)
			-- This ensures Bolt RemoteProperty has correct value when client calls Observe()
			instance:syncState(true)

			-- Signal that this model's data is fully loaded. Any code that called
			-- getOrWait() before this point will now be resumed with real data.
			AbstractModel.markLoaded(modelInfo.name, ownerId)

		-- Initialize UserEntity-scoped models per player
		elseif modelInfo.scope == "UserEntity" then
			-- UserEntity models need custom initialization per model type
			-- They should implement a static loadAllForOwner method
			if modelInfo.class.loadAllForOwner then
				local success = modelInfo.class.loadAllForOwner(ownerId)

				-- Guard: player may have disconnected during the DataStore yield
				if not player.Parent then
					return
				end

				if not success then
					player:Kick("Roblox servers are busy right now. Please rejoin to try again. Your progress is safe!")
					return
				end
			else
				warn("UserEntity model " .. modelInfo.name .. " missing loadAllForOwner method")
			end

		-- Initialize UserSession-scoped models per player (no DataStore load)
		elseif modelInfo.scope == "UserSession" then
			local instance = modelInfo.class.get(ownerId)
			instance:syncState(true)
		end
	end

	-- Track player join for analytics (after all models are initialized)
	local AnalyticsService = ServiceRunner.getAnalyticsService()
	if AnalyticsService and AnalyticsService.isEnabled then
		AnalyticsService:cacheUserProperties(player)
		AnalyticsService:trackPlayerJoin(player)
	end
end

-- Handle player initialization
Players.PlayerAdded:Connect(initializePlayer)

-- Handle players who joined before the handler was connected
for _, player in Players:GetPlayers() do
	task.spawn(initializePlayer, player)
end

-- Handle player cleanup
local playerRemovingConnection = Players.PlayerRemoving:Connect(function(player: Player)
	initializedPlayers[player.UserId] = nil
	local ownerId = tostring(player.UserId)
	print("ModelRunner: Cleaning up models for player " .. player.Name)

	-- Track player leave and flush analytics events before cleanup
	local AnalyticsService = ServiceRunner.getAnalyticsService()
	if AnalyticsService and AnalyticsService.isEnabled then
		AnalyticsService:trackPlayerLeave(player)
		AnalyticsService:flushPlayer(player)
	end

	local PersistenceService = ServiceRunner.getPersistenceService()

	-- Flush all pending writes for this player before cleanup
	PersistenceService:flushPlayerWrites(ownerId)

	-- Remove User, UserSession, and UserEntity scoped models (Server-scoped persist for server lifetime)
	for _, modelInfo in modelInfos do
		if modelInfo.scope == "User" then
			modelInfo.class.remove(ownerId)
		elseif modelInfo.scope == "UserSession" then
			modelInfo.class.remove(ownerId)
		elseif modelInfo.scope == "UserEntity" then
			-- Clean up all user entities for this owner
			if modelInfo.class.removeAllEntitiesForOwner then
				modelInfo.class.removeAllEntitiesForOwner(ownerId)
			end
		end
	end
end)

-- Handle server shutdown as backup to ensure all data is saved
game:BindToClose(function()
	-- Skip in Studio to avoid blocking offline testing
	if RunService:IsStudio() then
		print("[ModelRunner] BindToClose skipped in Studio")
		return
	end

	print("[ModelRunner] Server shutting down - disconnecting PlayerRemoving and flushing all players")

	-- Disconnect PlayerRemoving to prevent duplicate saves during shutdown
	playerRemovingConnection:Disconnect()

	local PersistenceService = ServiceRunner.getPersistenceService()

	-- Flush all remaining player data
	for _, player in Players:GetPlayers() do
		local ownerId = tostring(player.UserId)
		PersistenceService:flushPlayerWrites(ownerId)
	end
end)

print("ModelRunner: Initialized with " .. #models .. " model(s)")
