--!strict

--[[
	FollowersView

	Pattern: A (Pure client-side — no server communication)
	Purpose: Simulates NPC "followers" worshipping the ChickenGod, entirely
	on the client. Positions are not synchronized between players — each
	client runs its own boids sim, which makes reactions to the local
	player instant (no replication round-trip).

	Boids behaviour (per Heartbeat, 60hz):
	- Ring formation: stay between MIN_RADIUS and MAX_RADIUS of the ChickenGod
	- Separation: push away from other followers that get too close
	- Player avoidance: push away from characters, so players shove them around
	- Reverence: when standing still, turn to face the ChickenGod

	Expected setup:
	- Model tagged "ChickenGod" in Workspace (see ChickenGodView)
	- Rig at ReplicatedStorage.Assets.Rigs.Robert (welded, with an Animator)

	Limitations (fine for a flat worship area):
	- No world collision — followers walk through obstacles, ground-snap only
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MathUtils = require(game.ReplicatedFirst.LightweightNpcsClient.Utils.MathUtils)

local CHICKEN_GOD_TAG = "ChickenGod"
local RIG_NAME = "Robert"
local FOLLOWER_COUNT = 500

-- Ring around the ChickenGod
local MIN_RADIUS = 30
local MAX_RADIUS = 45
local RING_FALLOFF = 4 -- studs outside the band before urgency reaches full speed

-- Separation
local FOLLOWER_SEPARATION = 5
local FOLLOWER_SEPARATION_WEIGHT = 1
local PLAYER_SEPARATION = 6
local PLAYER_SEPARATION_WEIGHT = 1.5

-- Movement
local WALK_SPEED = 8
local WALK_ACCEL = 6
local TURN_FRACTION = 0.92 -- per-second smoothing fraction for facing

-- Hysteresis so animation doesn't thrash between idle/walk at the threshold
local START_MOVING_THRESHOLD = 0.15
local STOP_MOVING_THRESHOLD = 0.05

-- Stock R15 animations (same ids the LightweightNpcs DefaultAnims uses)
local IDLE_ANIM_ID = "http://www.roblox.com/asset/?id=507766388"
local WALK_ANIM_ID = "http://www.roblox.com/asset/?id=507777826"
local WALK_ANIM_TUNED_SPEED = 8 -- studs/sec the walk animation is authored for

type Follower = {
	model: Model,
	position: Vector3, -- flat ground position (Y maintained separately)
	velocity: Vector3,
	yaw: number,
	hipHeight: number,
	moving: boolean,
	idleTrack: AnimationTrack?,
	walkTrack: AnimationTrack?,
}

local followers: { Follower } = {}

local followersFolder = Instance.new("Folder")
followersFolder.Name = "Followers"
followersFolder.Parent = Workspace

local groundCastParams = RaycastParams.new()
groundCastParams.FilterType = Enum.RaycastFilterType.Exclude
groundCastParams.FilterDescendantsInstances = { followersFolder }
groundCastParams.RespectCanCollide = true

local function loadTrack(animator: Animator, animationId: string): AnimationTrack
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	return animator:LoadAnimation(animation)
end

local function spawnFollower(rig: Model, position: Vector3): Follower
	local model = rig:Clone()

	-- Same treatment as the LightweightNpcs client module: anchor the root,
	-- leave the rest of the rig exactly as authored (these rigs are built
	-- for batching — modifying their parts breaks them)
	if model.PrimaryPart then
		model.PrimaryPart.Anchored = true
	end

	local extents = model:GetExtentsSize()
	model:PivotTo(CFrame.new(position))
	model.Parent = followersFolder

	local follower: Follower = {
		model = model,
		position = position,
		velocity = Vector3.zero,
		yaw = 0,
		hipHeight = extents.Y / 2,
		moving = false,
		idleTrack = nil,
		walkTrack = nil,
	}

	local animator = model:FindFirstChild("Animator", true)
	if animator and animator:IsA("Animator") then
		follower.idleTrack = loadTrack(animator, IDLE_ANIM_ID)
		follower.walkTrack = loadTrack(animator, WALK_ANIM_ID)
		if follower.idleTrack then
			follower.idleTrack:Play()
		end
	else
		warn(`FollowersView: no Animator found in rig '{model.Name}' — followers will slide`)
	end

	return follower
end

local function computeSteer(follower: Follower, flatGod: Vector3): (Vector3, Vector3)
	local flatPosition = MathUtils:FlatVec(follower.position)
	local steer = Vector3.zero

	-- Ring formation: seek the band between MIN_RADIUS and MAX_RADIUS
	local toGod = flatGod - flatPosition
	local distance = toGod.Magnitude
	if distance > 0.001 then
		local toGodDir = toGod.Unit
		if distance > MAX_RADIUS then
			steer += toGodDir * math.min((distance - MAX_RADIUS) / RING_FALLOFF, 1)
		elseif distance < MIN_RADIUS then
			steer -= toGodDir * math.min((MIN_RADIUS - distance) / RING_FALLOFF, 1)
		end
	end

	-- Separation from other followers
	for _, other in followers do
		if other ~= follower then
			local away = flatPosition - MathUtils:FlatVec(other.position)
			local awayDistance = away.Magnitude
			if awayDistance > 0.001 and awayDistance < FOLLOWER_SEPARATION then
				steer += away.Unit * (1 - awayDistance / FOLLOWER_SEPARATION) * FOLLOWER_SEPARATION_WEIGHT
			end
		end
	end

	-- Pushed around by players (local player reacts instantly — that's the point)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local rootPart = character and character.PrimaryPart
		if rootPart then
			local away = flatPosition - MathUtils:FlatVec(rootPart.Position)
			local awayDistance = away.Magnitude
			if awayDistance > 0.001 and awayDistance < PLAYER_SEPARATION then
				steer += away.Unit * (1 - awayDistance / PLAYER_SEPARATION) * PLAYER_SEPARATION_WEIGHT
			end
		end
	end

	return steer, toGod
end

local function yawTowards(direction: Vector3): number
	return math.atan2(-direction.X, -direction.Z)
end

local function updateFollower(follower: Follower, flatGod: Vector3, dt: number)
	local steer, toGod = computeSteer(follower, flatGod)

	-- Hysteresis on the move/idle decision
	local urgency = steer.Magnitude
	local threshold = follower.moving and STOP_MOVING_THRESHOLD or START_MOVING_THRESHOLD
	local wantsToMove = urgency > threshold

	if wantsToMove and urgency > 1 then
		steer = steer.Unit
	end

	-- Accelerate toward the steer direction (magnitude scales speed)
	local wishDir = wantsToMove and steer or Vector3.zero
	follower.velocity = MathUtils:GroundAccelerate(wishDir, WALK_SPEED, WALK_ACCEL, follower.velocity, dt)
	follower.position += follower.velocity * dt

	-- Snap to ground
	local rayOrigin = Vector3.new(follower.position.X, follower.position.Y + 10, follower.position.Z)
	local hit = Workspace:Raycast(rayOrigin, Vector3.new(0, -50, 0), groundCastParams)
	if hit then
		follower.position = Vector3.new(follower.position.X, hit.Position.Y + follower.hipHeight, follower.position.Z)
	end

	-- Facing: direction of travel while moving, the ChickenGod while still
	local speed = MathUtils:FlatVec(follower.velocity).Magnitude
	local targetYaw = follower.yaw
	if speed > 0.5 then
		targetYaw = yawTowards(follower.velocity)
	elseif toGod.Magnitude > 0.001 then
		targetYaw = yawTowards(toGod)
	end
	follower.yaw = MathUtils:AngleLerp(follower.yaw, targetYaw, 1 - math.pow(1 - TURN_FRACTION, dt))

	follower.model:PivotTo(CFrame.new(follower.position) * CFrame.Angles(0, follower.yaw, 0))

	-- Animation state
	if speed > 0.5 then
		if not follower.moving then
			follower.moving = true
			if follower.idleTrack then
				follower.idleTrack:Stop()
			end
			if follower.walkTrack then
				follower.walkTrack:Play()
			end
		end
		if follower.walkTrack then
			follower.walkTrack:AdjustSpeed(speed / WALK_ANIM_TUNED_SPEED)
		end
	elseif follower.moving then
		follower.moving = false
		if follower.walkTrack then
			follower.walkTrack:Stop()
		end
		if follower.idleTrack then
			follower.idleTrack:Play()
		end
	end
end

local function start()
	local god = CollectionService:GetTagged(CHICKEN_GOD_TAG)[1]
	while god == nil do
		god = CollectionService:GetInstanceAddedSignal(CHICKEN_GOD_TAG):Wait()
	end

	local rig = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Rigs"):WaitForChild(RIG_NAME) :: Model

	-- The rig model can arrive before its descendants finish replicating, and
	-- there's no "fully replicated" signal — wait until it has a PrimaryPart,
	-- an Animator, and the descendant count has been stable for a few frames
	local stableFrames = 0
	local lastCount = -1
	while stableFrames < 10 do
		task.wait()
		local count = #rig:GetDescendants()
		if count == lastCount and count > 0 and rig.PrimaryPart and rig:FindFirstChild("Animator", true) then
			stableFrames += 1
		else
			stableFrames = 0
			lastCount = count
		end
	end

	local godPosition = (god :: Model):GetPivot().Position
	-- Scatter spawns well inside and outside the ring band so the crowd
	-- visibly converges on the ChickenGod at startup
	local minSpawnRadius = MIN_RADIUS * 0.25
	local maxSpawnRadius = MAX_RADIUS * 2.5
	for _ = 1, FOLLOWER_COUNT do
		local angle = math.random() * math.pi * 2
		local radius = minSpawnRadius + math.random() * (maxSpawnRadius - minSpawnRadius)
		local position = godPosition
			+ Vector3.new(math.sin(angle) * radius, 0, math.cos(angle) * radius)
		table.insert(followers, spawnFollower(rig, position))
	end

	RunService.Heartbeat:Connect(function(dt: number)
		local flatGod = MathUtils:FlatVec((god :: Model):GetPivot().Position)
		for _, follower in followers do
			updateFollower(follower, flatGod, dt)
		end
	end)

	print(`FollowersView: {FOLLOWER_COUNT} followers gathered around the ChickenGod`)
end

task.spawn(start)
