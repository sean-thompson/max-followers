--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = require(ReplicatedStorage.Network)

local AbstractController = {}
AbstractController.__index = AbstractController

export type AbstractController = typeof(setmetatable({} :: {
	intentEvent: any,
	_controllerName: string,
}, AbstractController))

-- Lazy-loaded AnalyticsService (avoids circular deps, gracefully degrades if missing)
local AnalyticsService: any = nil
local analyticsLoaded = false

local function getAnalyticsService()
	if not analyticsLoaded then
		analyticsLoaded = true
		local success, result = pcall(function()
			return require(script.Parent.Parent.services.framework.AnalyticsService)
		end)
		if success then
			AnalyticsService = result
		end
	end
	return AnalyticsService
end

function AbstractController.new(controllerName: string): AbstractController
	local self = setmetatable({}, AbstractController)

	-- Auto-register with Network using Bolt ReliableEvent
	local eventName = controllerName:gsub("Controller$", "")
	self.intentEvent = Network.registerIntent(eventName)
	self._controllerName = controllerName

	print(controllerName .. " initialized with Bolt")

	return self
end

function AbstractController:dispatchAction(actionsTable: { [string]: (...any) -> () }, action: string, player: Player, ...: any)
	local actionFunc = actionsTable[action]
	if not actionFunc then
		warn("Invalid action received from " .. player.Name .. ": " .. tostring(action))
		return
	end

	actionFunc(...)

	-- Auto-instrument: track this controller action in analytics
	local analytics = getAnalyticsService()
	if analytics and analytics.isEnabled then
		analytics:trackControllerAction(player, self._controllerName, action)
	end
end

return AbstractController
