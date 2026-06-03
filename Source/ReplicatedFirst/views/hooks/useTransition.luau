--!strict

--[[
	useTransition

	Manages enter/leave animations for items. Items animate from `from` → `enter`
	on mount, and from current → `leave` on unmount (with delayed removal).

	Supports staggered animations via the `trail` parameter.

	Usage (boolean — single item show/hide):
		local transitions = useTransition(isVisible, {
			from = { BackgroundTransparency = 1 },
			enter = { BackgroundTransparency = 0 },
			leave = { BackgroundTransparency = 1 },
			config = { force = 200, dampening = 22 },
		})

	Usage (list — multiple items with stagger):
		local transitions = useTransition(items, {
			from = { BackgroundTransparency = 1 },
			enter = { BackgroundTransparency = 0 },
			leave = { BackgroundTransparency = 1 },
			trail = 80,
			keys = function(item) return item.id end,
			config = { force = 220, dampening = 22 },
		})

	Returns array of:
		{ item: any, key: string, springProps: { [string]: Binding }, phase: string }
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local SpringSolver = require(script.Parent:WaitForChild("SpringSolver"))

type SpringConfig = SpringSolver.SpringConfig
type SpringState = SpringSolver.SpringState

export type TransitionConfig = {
	from: { [string]: any },
	enter: { [string]: any },
	leave: { [string]: any },
	trail: number?,
	keys: ((any) -> string)?,
	config: {
		force: number?,
		dampening: number?,
		mass: number?,
	}?,
	leaveConfig: {
		force: number?,
		dampening: number?,
		mass: number?,
	}?,
}

export type TransitionItem = {
	item: any,
	key: string,
	springProps: { [string]: any },
	phase: string,
}

type InternalItem = {
	item: any,
	key: string,
	phase: string, -- "entering" | "entered" | "leaving"
	springs: { [string]: SpringState },
	bindings: { [string]: any },
	updaters: { [string]: (any) -> () },
	templates: { [string]: any },
	trailDelay: number, -- seconds remaining before animation starts
}

local function useTransition(input: any, transitionConfig: TransitionConfig): { TransitionItem }
	local resolvedConfig: SpringConfig = {
		force = if transitionConfig.config and transitionConfig.config.force then transitionConfig.config.force else 200,
		dampening = if transitionConfig.config and transitionConfig.config.dampening then transitionConfig.config.dampening else 22,
		mass = if transitionConfig.config and transitionConfig.config.mass then transitionConfig.config.mass else 1,
	}
	local resolvedLeaveConfig: SpringConfig = {
		force = if transitionConfig.leaveConfig and transitionConfig.leaveConfig.force then transitionConfig.leaveConfig.force else resolvedConfig.force,
		dampening = if transitionConfig.leaveConfig and transitionConfig.leaveConfig.dampening then transitionConfig.leaveConfig.dampening else resolvedConfig.dampening,
		mass = if transitionConfig.leaveConfig and transitionConfig.leaveConfig.mass then transitionConfig.leaveConfig.mass else resolvedConfig.mass,
	}
	local trail = (transitionConfig.trail or 0) / 1000 -- convert ms to seconds

	-- Normalize input to a keyed item list
	local function normalizeInput(): { { item: any, key: string } }
		if typeof(input) == "boolean" then
			if input then
				return { { item = true, key = "item" } }
			else
				return {}
			end
		elseif typeof(input) == "table" then
			local result = {}
			local keyFn = transitionConfig.keys or function(item: any)
				return tostring(item)
			end
			for i, item in input do
				table.insert(result, { item = item, key = keyFn(item) })
			end
			return result
		else
			return {}
		end
	end

	local internalsRef = React.useRef(nil :: { [string]: InternalItem }?)
	local connectionRef = React.useRef(nil :: RBXScriptConnection?)
	local renderList, setRenderList = React.useState({} :: { TransitionItem })
	local isAnimating, setIsAnimating = React.useState(false)

	-- Initialize internals
	if internalsRef.current == nil then
		internalsRef.current = {}
	end

	-- Diff items and manage enter/leave phases
	React.useEffect(function()
		local internals = internalsRef.current :: { [string]: InternalItem }
		local currentItems = normalizeInput()
		local currentKeys: { [string]: boolean } = {}
		local needsAnimation = false
		local enterIndex = 0

		-- Mark current items
		for _, entry in currentItems do
			currentKeys[entry.key] = true
		end

		-- Handle entering items
		for _, entry in currentItems do
			if not internals[entry.key] then
				-- New item — create bindings at "from" values
				local bindings: { [string]: any } = {}
				local updaters: { [string]: (any) -> () } = {}
				local springs: { [string]: SpringState } = {}
				local templates: { [string]: any } = {}

				for propName, fromValue in transitionConfig.from do
					local enterValue = transitionConfig.enter[propName]
					local binding, updater = React.createBinding(fromValue)
					bindings[propName] = binding
					updaters[propName] = updater
					templates[propName] = fromValue
					springs[propName] = SpringSolver.create(
						fromValue,
						if enterValue ~= nil then enterValue else fromValue
					)
				end

				internals[entry.key] = {
					item = entry.item,
					key = entry.key,
					phase = "entering",
					springs = springs,
					bindings = bindings,
					updaters = updaters,
					templates = templates,
					trailDelay = trail * enterIndex,
				}
				enterIndex += 1
				needsAnimation = true
			elseif internals[entry.key].phase == "leaving" then
				-- Item returned — retarget back to enter values
				local internal = internals[entry.key]
				internal.phase = "entering"
				internal.item = entry.item
				for propName, enterValue in transitionConfig.enter do
					if internal.springs[propName] then
						internal.springs[propName] = SpringSolver.retarget(
							internal.springs[propName],
							SpringSolver.decompose(enterValue)
						)
					end
				end
				internal.trailDelay = 0
				needsAnimation = true
			else
				-- Update item reference
				internals[entry.key].item = entry.item
			end
		end

		-- Handle leaving items
		for key, internal in internals do
			if not currentKeys[key] and internal.phase ~= "leaving" then
				internal.phase = "leaving"
				internal.trailDelay = 0
				for propName, leaveValue in transitionConfig.leave do
					if internal.springs[propName] then
						internal.springs[propName] = SpringSolver.retarget(
							internal.springs[propName],
							SpringSolver.decompose(leaveValue)
						)
					end
				end
				needsAnimation = true
			end
		end

		-- Build render list
		local newRenderList: { TransitionItem } = {}
		-- Add items in input order first (entering/entered)
		for _, entry in currentItems do
			local internal = internals[entry.key]
			if internal then
				table.insert(newRenderList, {
					item = internal.item,
					key = internal.key,
					springProps = internal.bindings,
					phase = internal.phase,
				})
			end
		end
		-- Add leaving items at the end
		for _, internal in internals do
			if internal.phase == "leaving" then
				table.insert(newRenderList, {
					item = internal.item,
					key = internal.key,
					springProps = internal.bindings,
					phase = internal.phase,
				})
			end
		end

		setRenderList(newRenderList)
		if needsAnimation then
			setIsAnimating(true)
		end
	end)

	-- Animation loop
	React.useEffect(function()
		if not isAnimating then
			return
		end

		local connection = RunService.RenderStepped:Connect(function(dt: number)
			local internals = internalsRef.current :: { [string]: InternalItem }
			local allSettled = true
			local removedKeys: { string } = {}

			for key, internal in internals do
				-- Handle trail delay
				if internal.trailDelay > 0 then
					internal.trailDelay -= dt
					allSettled = false
					continue
				end

				local activeConfig = if internal.phase == "leaving" then resolvedLeaveConfig else resolvedConfig
				local itemSettled = true
				for propName, state in internal.springs do
					if not state.settled then
						local newState = SpringSolver.step(state, activeConfig, dt)
						internal.springs[propName] = newState
						local value = SpringSolver.recompose(newState.position, internal.templates[propName])
						internal.updaters[propName](value)
						if not newState.settled then
							itemSettled = false
						end
					end
				end

				if itemSettled then
					if internal.phase == "entering" then
						internal.phase = "entered"
					elseif internal.phase == "leaving" then
						table.insert(removedKeys, key)
					end
				else
					allSettled = false
				end
			end

			-- Remove completed leaving items
			if #removedKeys > 0 then
				for _, key in removedKeys do
					internals[key] = nil
				end

				-- Rebuild render list
				local newRenderList: { TransitionItem } = {}
				for _, internal in internals do
					table.insert(newRenderList, {
						item = internal.item,
						key = internal.key,
						springProps = internal.bindings,
						phase = internal.phase,
					})
				end
				setRenderList(newRenderList)
			end

			if allSettled then
				setIsAnimating(false)
			end
		end)

		connectionRef.current = connection

		return function()
			if connectionRef.current then
				connectionRef.current:Disconnect()
				connectionRef.current = nil
			end
		end
	end, { isAnimating })

	return renderList
end

return useTransition
