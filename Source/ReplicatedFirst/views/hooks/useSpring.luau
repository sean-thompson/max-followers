--!strict

--[[
	useSpring

	Animates a dictionary of properties toward target values using spring physics.
	Returns React bindings that update Instance properties directly — zero re-renders
	during animation.

	Usage:
		local springProps = useSpring({
			Position = UDim2.new(0.5, 0, 0.5, 0),
			BackgroundTransparency = 0,
		}, {
			force = 200,
			dampening = 20,
			mass = 1,
		})

		e("Frame", {
			Position = springProps.Position,
			BackgroundTransparency = springProps.BackgroundTransparency,
		})
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local SpringSolver = require(script.Parent:WaitForChild("SpringSolver"))

type SpringConfig = SpringSolver.SpringConfig
type SpringState = SpringSolver.SpringState

export type UseSpringConfig = {
	force: number?,
	dampening: number?,
	mass: number?,
	immediate: boolean?,
}

local function useSpring(targets: { [string]: any }, config: UseSpringConfig?): { [string]: any }
	local resolvedConfig: SpringConfig = {
		force = if config and config.force then config.force else SpringSolver.DEFAULT_CONFIG.force,
		dampening = if config and config.dampening then config.dampening else SpringSolver.DEFAULT_CONFIG.dampening,
		mass = if config and config.mass then config.mass else SpringSolver.DEFAULT_CONFIG.mass,
	}
	local immediate = config and config.immediate or false

	-- Refs for mutable state that persists across renders
	local springStatesRef = React.useRef(nil :: { [string]: SpringState }?)
	local bindingsRef = React.useRef(nil :: { [string]: any }?)
	local updatersRef = React.useRef(nil :: { [string]: (any) -> () }?)
	local connectionRef = React.useRef(nil :: RBXScriptConnection?)
	local templatesRef = React.useRef(nil :: { [string]: any }?)

	-- Animating state controls the RenderStepped connection
	local isAnimating, setIsAnimating = React.useState(false)

	-- Initialize bindings and spring states on first render
	if bindingsRef.current == nil then
		local bindings: { [string]: any } = {}
		local updaters: { [string]: (any) -> () } = {}
		local springStates: { [string]: SpringState } = {}
		local templates: { [string]: any } = {}

		for propName, targetValue in targets do
			local binding, updater = React.createBinding(targetValue)
			bindings[propName] = binding
			updaters[propName] = updater
			templates[propName] = targetValue
			springStates[propName] = SpringSolver.create(targetValue, targetValue)
		end

		bindingsRef.current = bindings
		updatersRef.current = updaters
		springStatesRef.current = springStates
		templatesRef.current = templates
	end

	-- Detect target changes and retarget springs
	React.useEffect(function()
		local springStates = springStatesRef.current :: { [string]: SpringState }
		local templates = templatesRef.current :: { [string]: any }
		local updaters = updatersRef.current :: { [string]: (any) -> () }
		local needsAnimation = false

		for propName, targetValue in targets do
			local newTarget = SpringSolver.decompose(targetValue)
			local currentState = springStates[propName]
			templates[propName] = targetValue

			if currentState then
				-- Check if target actually changed
				local changed = false
				for i, v in newTarget do
					if math.abs(v - currentState.target[i]) > 0.0001 then
						changed = true
						break
					end
				end

				if changed then
					if immediate then
						-- Snap immediately
						springStates[propName] = SpringSolver.create(targetValue, targetValue)
						updaters[propName](targetValue)
					else
						-- Retarget with current velocity preserved
						springStates[propName] = SpringSolver.retarget(currentState, newTarget)
						needsAnimation = true
					end
				end
			end
		end

		if needsAnimation then
			setIsAnimating(true)
		end
	end)

	-- Run the animation loop when active
	React.useEffect(function()
		if not isAnimating then
			return
		end

		local connection = RunService.RenderStepped:Connect(function(dt: number)
			local springStates = springStatesRef.current :: { [string]: SpringState }
			local updaters = updatersRef.current :: { [string]: (any) -> () }
			local templates = templatesRef.current :: { [string]: any }
			local allSettled = true

			for propName, state in springStates do
				if not state.settled then
					local newState = SpringSolver.step(state, resolvedConfig, dt)
					springStates[propName] = newState

					local value = SpringSolver.recompose(newState.position, templates[propName])
					updaters[propName](value)

					if not newState.settled then
						allSettled = false
					end
				end
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

	return bindingsRef.current :: { [string]: any }
end

return useSpring
