--!strict

--[[
	useSpringNumber

	Animates a single number value using spring physics.
	Returns a rounded integer via useState — re-renders only when the
	displayed digit changes.

	Usage:
		local displayValue = useSpringNumber(props.amount, {
			force = 120,
			dampening = 14,
		})
		Text = formatNumber(displayValue)
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local SpringSolver = require(script.Parent:WaitForChild("SpringSolver"))

type SpringConfig = SpringSolver.SpringConfig
type SpringState = SpringSolver.SpringState

export type UseSpringNumberConfig = {
	force: number?,
	dampening: number?,
	mass: number?,
}

local function useSpringNumber(target: number, config: UseSpringNumberConfig?): number
	local resolvedConfig: SpringConfig = {
		force = if config and config.force then config.force else 120,
		dampening = if config and config.dampening then config.dampening else 14,
		mass = if config and config.mass then config.mass else 1,
	}

	local displayValue, setDisplayValue = React.useState(math.floor(target))
	local springRef = React.useRef(nil :: SpringState?)
	local connectionRef = React.useRef(nil :: RBXScriptConnection?)
	local isAnimating, setIsAnimating = React.useState(false)

	-- Initialize spring state
	if springRef.current == nil then
		springRef.current = SpringSolver.create(target, target)
	end

	-- Detect target changes
	React.useEffect(function()
		local currentState = springRef.current :: SpringState
		local newTarget = SpringSolver.decompose(target)

		if math.abs(newTarget[1] - currentState.target[1]) > 0.01 then
			springRef.current = SpringSolver.retarget(currentState, newTarget)
			setIsAnimating(true)
		end
	end)

	-- Animation loop
	React.useEffect(function()
		if not isAnimating then
			return
		end

		local connection = RunService.RenderStepped:Connect(function(dt: number)
			local state = springRef.current :: SpringState

			if state.settled then
				setIsAnimating(false)
				return
			end

			local newState = SpringSolver.step(state, resolvedConfig, dt)
			springRef.current = newState

			local rounded = math.floor(newState.position[1] + 0.5)
			setDisplayValue(function(current: number)
				if current ~= rounded then
					return rounded
				end
				return current
			end)

			if newState.settled then
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

	return displayValue
end

return useSpringNumber
