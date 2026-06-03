--!strict

--[[
	DebugActionBuilder

	Scans model scope folders and auto-generates DebugTools Actions from
	`debugActions` descriptor tables declared on each model class.

	Supported scopes:
	  user         — closure injects Player; calls modelClass.get(userId)
	  server       — no Player injection; calls modelClass.get("SERVER")
	  userEntities — closure injects Player + modelId; calls modelClass.get(userId, modelId)

	ServerEntity scope is skipped — candles and other world objects have no
	meaningful player-targeted debug actions.

	Models declare `debugActions` as pure data at the bottom of their file.
	Only method args are listed; scope-specific args are prepended by this builder.

	DebugTools arg types: "Player" | "string" | "number" | "boolean"
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DebugTools = require(ReplicatedStorage.Packages.DebugTools)

type DebugArgType = "Player" | "string" | "number" | "boolean"

type DebugArgDescriptor = {
	Type: DebugArgType,
	Name: string,
	Default: any?,
}

type DebugActionDescriptor = {
	name: string,
	description: string?,
	method: string,
	modelIdLabel: string?,  -- UserEntity only: label for the injected modelId arg (default: "Model ID")
	args: { DebugArgDescriptor }?,
}

-- Registers a DebugTools action for a User-scoped model.
-- Prepends a Player arg; closure calls modelClass.get(userId):method(...methodArgs).
local function buildUserAction(modelClass: any, descriptor: DebugActionDescriptor): ()
	local methodArgs = descriptor.args or {}
	local actionArgs: { any } = { { Type = "Player", Name = "Player" } }

	for _, arg in methodArgs do
		table.insert(actionArgs, arg)
	end

	DebugTools.Action.new(
		descriptor.name,
		descriptor.description,
		function(player: Player, ...)
			local instance = modelClass.get(tostring(player.UserId))
			instance[descriptor.method](instance, ...)
		end,
		actionArgs
	)
end

-- Registers a DebugTools action for a Server-scoped model.
-- No Player injection; closure calls modelClass.get("SERVER"):method(...args).
local function buildServerAction(modelClass: any, descriptor: DebugActionDescriptor): ()
	local methodArgs = descriptor.args or {}

	DebugTools.Action.new(
		descriptor.name,
		descriptor.description,
		function(...)
			local instance = modelClass.get("SERVER")
			instance[descriptor.method](instance, ...)
		end,
		methodArgs
	)
end

-- Registers a DebugTools action for a UserEntity-scoped model.
-- Prepends Player + modelId args; closure calls modelClass.get(userId, modelId):method(...methodArgs).
local function buildUserEntityAction(modelClass: any, descriptor: DebugActionDescriptor): ()
	local methodArgs = descriptor.args or {}
	local actionArgs: { any } = {
		{ Type = "Player", Name = "Player" },
		{ Type = "string", Name = descriptor.modelIdLabel or "Model ID", Default = "" },
	}

	for _, arg in methodArgs do
		table.insert(actionArgs, arg)
	end

	DebugTools.Action.new(
		descriptor.name,
		descriptor.description,
		function(player: Player, modelId: string, ...)
			local ownerId = tostring(player.UserId)
			local instance = modelClass.get(ownerId, modelId)
			instance[descriptor.method](instance, ...)
		end,
		actionArgs
	)
end

type ScopeBuilder = (modelClass: any, descriptor: DebugActionDescriptor) -> ()

local SCOPE_BUILDERS: { [string]: ScopeBuilder } = {
	user = buildUserAction,
	server = buildServerAction,
	userEntities = buildUserEntityAction,
	-- serverEntities: skipped — no player-targeted actions applicable
}

local DebugActionBuilder = {}

-- Scans all supported model scope folders and registers DebugTools actions
-- for each model class that declares a `debugActions` descriptor table.
function DebugActionBuilder.buildAll(modelsFolder: Instance): ()
	local count = 0

	for scopeName, builder in SCOPE_BUILDERS do
		local scopeFolder = modelsFolder:FindFirstChild(scopeName)
		if not scopeFolder then
			continue
		end

		for _, moduleScript in scopeFolder:GetChildren() do
			if not moduleScript:IsA("ModuleScript") then
				continue
			end
			if moduleScript.Name:find("^Abstract") then
				continue
			end

			local modelClass = require(moduleScript) :: any
			local debugActions = modelClass.debugActions

			if not debugActions then
				continue
			end

			for _, descriptor in debugActions do
				builder(modelClass, descriptor)
				count += 1
			end
		end
	end

	print(string.format("[DebugActionBuilder] Registered %d actions from model descriptors", count))
end

return DebugActionBuilder
