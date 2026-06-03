--!strict

--[[
	useDrag

	Makes an element draggable with momentum and spring-back.
	Returns event callbacks to bind to the draggable element and a
	position offset binding.

	Usage:
		local dragBind, dragOffset = useDrag({
			springBack = true,
			config = { force = 300, dampening = 25 },
		})

		e("Frame", {
			Position = dragOffset:map(function(offset)
				return UDim2.new(0.5, offset.X, 0.5, offset.Y)
			end),
			[React.Event.InputBegan] = dragBind.onInputBegan,
		})
]]

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local SpringSolver = require(script.Parent:WaitForChild("SpringSolver"))

type SpringConfig = SpringSolver.SpringConfig
type SpringState = SpringSolver.SpringState

export type UseDragConfig = {
	springBack: boolean?,
	config: {
		force: number?,
		dampening: number?,
		mass: number?,
	}?,
}

export type DragBind = {
	onInputBegan: (rbx: any, input: InputObject) -> (),
}

local function useDrag(dragConfig: UseDragConfig?): (DragBind, any)
	local springBack = if dragConfig and dragConfig.springBack ~= nil then dragConfig.springBack else true
	local resolvedConfig: SpringConfig = {
		force = if dragConfig and dragConfig.config and dragConfig.config.force then dragConfig.config.force else 300,
		dampening = if dragConfig and dragConfig.config and dragConfig.config.dampening then dragConfig.config.dampening else 25,
		mass = if dragConfig and dragConfig.config and dragConfig.config.mass then dragConfig.config.mass else 1,
	}

	-- Offset binding: stable across re-renders via ref
	local bindingRef = React.useRef(nil :: any?)
	local setOffsetRef = React.useRef(nil :: any?)
	if bindingRef.current == nil then
		local binding, updater = React.createBinding(Vector2.new(0, 0))
		bindingRef.current = binding
		setOffsetRef.current = updater
	end
	local offsetBinding = bindingRef.current
	local setOffset = setOffsetRef.current :: (Vector2) -> ()

	-- Refs for drag state
	local stateRef = React.useRef({
		isDragging = false,
		dragStartPos = Vector2.new(0, 0),     -- screen position when drag began
		dragStartOffset = Vector2.new(0, 0),  -- offset when drag began
		currentOffset = Vector2.new(0, 0),    -- current offset
		-- Velocity tracking: circular buffer of last 3 samples
		samples = {} :: { { pos: Vector2, time: number } },
	})

	local springRef = React.useRef(nil :: SpringState?)
	local connectionRef = React.useRef(nil :: RBXScriptConnection?)
	local moveConnRef = React.useRef(nil :: RBXScriptConnection?)
	local endConnRef = React.useRef(nil :: RBXScriptConnection?)
	local isAnimating, setIsAnimating = React.useState(false)

	-- Calculate release velocity from position samples
	local function calculateVelocity(): Vector2
		local samples = stateRef.current.samples
		if #samples < 2 then
			return Vector2.new(0, 0)
		end

		local first = samples[1]
		local last = samples[#samples]
		local dt = last.time - first.time

		if dt < 0.001 then
			return Vector2.new(0, 0)
		end

		local delta = last.pos - first.pos
		return delta / dt
	end

	-- Clean up global input listeners
	local function cleanupInputListeners()
		if moveConnRef.current then
			moveConnRef.current:Disconnect()
			moveConnRef.current = nil
		end
		if endConnRef.current then
			endConnRef.current:Disconnect()
			endConnRef.current = nil
		end
	end

	-- Handle input began on the draggable element
	local onInputBegan = React.useCallback(function(_rbx: any, input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local state = stateRef.current
		state.isDragging = true
		state.dragStartPos = Vector2.new(input.Position.X, input.Position.Y)
		state.dragStartOffset = state.currentOffset
		state.samples = { { pos = state.dragStartPos, time = tick() } }

		-- Stop any ongoing spring animation
		if connectionRef.current then
			connectionRef.current:Disconnect()
			connectionRef.current = nil
		end
		setIsAnimating(false)

		-- Listen globally for move and end
		cleanupInputListeners()

		moveConnRef.current = UserInputService.InputChanged:Connect(function(changedInput: InputObject)
			if not state.isDragging then
				return
			end

			if changedInput.UserInputType ~= Enum.UserInputType.MouseMovement
				and changedInput.UserInputType ~= Enum.UserInputType.Touch then
				return
			end

			local currentPos = Vector2.new(changedInput.Position.X, changedInput.Position.Y)
			local delta = currentPos - state.dragStartPos
			local newOffset = state.dragStartOffset + delta

			state.currentOffset = newOffset
			setOffset(newOffset)

			-- Track velocity samples (keep last 3)
			local samples = state.samples
			table.insert(samples, { pos = currentPos, time = tick() })
			if #samples > 3 then
				table.remove(samples, 1)
			end
		end)

		endConnRef.current = UserInputService.InputEnded:Connect(function(endedInput: InputObject)
			if endedInput.UserInputType ~= Enum.UserInputType.MouseButton1
				and endedInput.UserInputType ~= Enum.UserInputType.Touch then
				return
			end

			state.isDragging = false
			cleanupInputListeners()

			if springBack then
				-- Calculate release velocity and start spring-back
				local velocity = calculateVelocity()

				springRef.current = {
					position = { state.currentOffset.X, state.currentOffset.Y },
					velocity = { velocity.X, velocity.Y },
					target = { 0, 0 },
					settled = false,
				}
				setIsAnimating(true)
			end
		end)
	end, {})

	-- Spring-back animation loop
	React.useEffect(function()
		if not isAnimating then
			return
		end

		local connection = RunService.RenderStepped:Connect(function(dt: number)
			local spring = springRef.current :: SpringState

			if spring.settled then
				setIsAnimating(false)
				return
			end

			local newState = SpringSolver.step(spring, resolvedConfig, dt)
			springRef.current = newState

			local newOffset = Vector2.new(newState.position[1], newState.position[2])
			stateRef.current.currentOffset = newOffset
			setOffset(newOffset)

			if newState.settled then
				stateRef.current.currentOffset = Vector2.new(0, 0)
				setOffset(Vector2.new(0, 0))
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

	-- Cleanup on unmount
	React.useEffect(function()
		return function()
			cleanupInputListeners()
			if connectionRef.current then
				connectionRef.current:Disconnect()
			end
		end
	end, {})

	local dragBind: DragBind = {
		onInputBegan = onInputBegan,
	}

	return dragBind, offsetBinding
end

return useDrag
