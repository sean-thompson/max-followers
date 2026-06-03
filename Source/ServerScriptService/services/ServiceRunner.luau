--!strict
--[[
	ServiceRunner
	Orchestrates service initialization:
	1. Framework services (explicit order)
	2. Game services (auto-discovered)
]]

local frameworkFolder = script.Parent:WaitForChild("framework")
local gameFolder = script.Parent:WaitForChild("game")

local ServiceRunner = {}

local PersistenceService = nil
local SlashCommandService = nil
local AnalyticsService = nil

-- Phase 1: Must run before any model is used
function ServiceRunner.initPersistence()
	PersistenceService = require(frameworkFolder.PersistenceService)
	PersistenceService.init()
end

-- Phase 1.5: Analytics (before controllers so auto-instrumentation hooks are ready)
function ServiceRunner.initAnalytics()
	AnalyticsService = require(frameworkFolder.AnalyticsService)
	AnalyticsService.init()
end

function ServiceRunner.getAnalyticsService()
	return AnalyticsService
end

-- Phase 2: After models discovered (idempotent — safe to call from multiple scripts)
function ServiceRunner.initSlashCommands()
	if SlashCommandService then return end
	SlashCommandService = require(frameworkFolder.SlashCommandService)
	SlashCommandService:init()
end

function ServiceRunner.registerModels(modelInfos)
	ServiceRunner.initSlashCommands()
	SlashCommandService:registerModels(modelInfos)
end

function ServiceRunner.registerControllers(controllerInfos)
	ServiceRunner.initSlashCommands()
	SlashCommandService:registerControllers(controllerInfos)
end

-- Phase 3: Auto-discover game services after models ready
function ServiceRunner.initGameServices()
	if not gameFolder then
		return
	end

	for _, moduleScript in gameFolder:GetChildren() do
		if moduleScript:IsA("ModuleScript") then
			local service = require(moduleScript)
			if service.init then
				service.init()
				print("[ServiceRunner] Initialized: " .. moduleScript.Name)
			end
		end
	end
end

function ServiceRunner.getPersistenceService()
	return PersistenceService
end

return ServiceRunner
