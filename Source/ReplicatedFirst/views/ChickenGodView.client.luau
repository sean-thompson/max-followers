--!strict

--[[
	ChickenGodView

	Pattern: A (Pure client-side feedback — no server communication)
	Purpose: Slowly rotates the Chicken God model around its Y axis.

	Expected Hierarchy:
	Model [Chicken] (Tagged: "ChickenGod")
	+-- Chicken (MeshPart, Anchored)

	Studio Setup:
	1. Select the Chicken Model in Workspace (the Model, not the MeshPart)
	2. Apply CollectionService tag "ChickenGod" (View > Tags, case-sensitive)
	3. Ensure the MeshPart is Anchored
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TAG = "ChickenGod"
local ROTATION_SPEED = math.rad(20) -- degrees per second, converted to radians

local spinningParts: { [BasePart]: boolean } = {}

local function setupChicken(instance: Instance)
	local model = instance :: Model

	-- Rotate the MeshPart around its own centre (model pivots on imported
	-- meshes can sit far from the geometry, which makes PivotTo orbit)
	local meshPart = model:WaitForChild("Chicken") :: MeshPart
	print(`ChickenGodView: Initialized '{model:GetFullName()}'`)

	spinningParts[meshPart] = true
end

RunService.Heartbeat:Connect(function(deltaTime: number)
	for meshPart in spinningParts do
		meshPart.CFrame = meshPart.CFrame * CFrame.Angles(0, ROTATION_SPEED * deltaTime, 0)
	end
end)

for _, instance in ipairs(CollectionService:GetTagged(TAG)) do
	task.spawn(function()
		setupChicken(instance)
	end)
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(function(instance: Instance)
	task.spawn(function()
		setupChicken(instance)
	end)
end)

CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance: Instance)
	local meshPart = instance:FindFirstChild("Chicken")
	if meshPart then
		spinningParts[meshPart :: BasePart] = nil
	end
end)
