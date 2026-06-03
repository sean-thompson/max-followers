--!strict

--[[
	FollowersView

	Pattern: A (Pure client-side — no server communication)
	Purpose: Simulates NPC "followers" worshipping the ChickenGod, entirely
	on the client. Positions are not synchronized between players — each
	client runs its own boids sim, which makes reactions to the local
	player instant (no replication round-trip).

	Boids behaviour:
	- Ring formation: stay between MIN_RADIUS and MAX_RADIUS of the ChickenGod
	- Separation: push away from other followers that get too close
	- Player avoidance: push away from characters, so players shove them around
	- Reverence: when standing still, turn to face the ChickenGod

	Performance structure (tag `naive-boids` has the simple 60hz O(n^2) version):
	- Steering "thinks" are staggered: each follower steers/raycasts every
	  THINK_BUCKETS-th frame (~10hz at 60fps); movement integration, turning
	  and rendering stay per-frame so motion is smooth
	- Follower separation queries a spatial hash grid (intrusive linked
	  lists, rebuilt per frame with zero allocation) instead of all pairs
	- PivotTo is skipped for followers that haven't moved or turned

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

-- Steering runs for 1/THINK_BUCKETS of the crowd each frame (~10hz at 60fps)
local THINK_BUCKETS = 6

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
	wishDir: Vector3, -- steering decision, refreshed each think
	yaw: number,
	targetYaw: number,
	hipHeight: number,
	bucket: number, -- which frame group this follower thinks in
	wantsToMove: boolean,
	moving: boolean, -- animation state
	lastRenderedPosition: Vector3,
	lastRenderedYaw: number,
	idleTrack: AnimationTrack?,
	walkTrack: AnimationTrack?,
	nextInCell: Follower?, -- intrusive linked list for the spatial grid
}

local followers: { Follower } = {}

local followersFolder = Instance.new("Folder")
followersFolder.Name = "Followers"
followersFolder.Parent = Workspace

local groundCastParams = RaycastParams.new()
groundCastParams.FilterType = Enum.RaycastFilterType.Exclude
groundCastParams.FilterDescendantsInstances = { followersFolder }
groundCastParams.RespectCanCollide = true

-- ============================================================================
-- Spatial hash grid: rebuilt every frame, queried during thinks
-- ============================================================================

local CELL_SIZE = FOLLOWER_SEPARATION
local grid: { [number]: Follower } = {}

local function cellKey(cellX: number, cellZ: number): number
	-- Unique for any sane world size (|cell| < 65536)
	return cellX * 131072 + cellZ
end

local function rebuildGrid()
	table.clear(grid)
	for _, follower in followers do
		local key = cellKey(
			math.floor(follower.position.X / CELL_SIZE),
			math.floor(follower.position.Z / CELL_SIZE)
		)
		follower.nextInCell = grid[key]
		grid[key] = follower
	end
end

-- ============================================================================
-- Setup
-- ============================================================================

local function loadTrack(animator: Animator, animationId: string): AnimationTrack
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	return animator:LoadAnimation(animation)
end

local function spawnFollower(rig: Model, position: Vector3, bucket: number): Follower
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
		wishDir = Vector3.zero,
		yaw = 0,
		targetYaw = 0,
		hipHeight = extents.Y / 2,
		bucket = bucket,
		wantsToMove = false,
		moving = false,
		lastRenderedPosition = position,
		lastRenderedYaw = 0,
		idleTrack = nil,
		walkTrack = nil,
		nextInCell = nil,
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

-- ============================================================================
-- Think: steering decisions + ground snap, runs at ~10hz per follower
-- ============================================================================

local function computeSteer(follower: Follower, flatGod: Vector3, playerPositions: { Vector3 }): (Vector3, Vector3)
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

	-- Separation from nearby followers (3x3 grid cells around us)
	local baseCellX = math.floor(follower.position.X / CELL_SIZE)
	local baseCellZ = math.floor(follower.position.Z / CELL_SIZE)
	for cellX = baseCellX - 1, baseCellX + 1 do
		for cellZ = baseCellZ - 1, baseCellZ + 1 do
			local other = grid[cellKey(cellX, cellZ)]
			while other do
				if other ~= follower then
					local away = flatPosition - MathUtils:FlatVec(other.position)
					local awayDistance = away.Magnitude
					if awayDistance > 0.001 and awayDistance < FOLLOWER_SEPARATION then
						steer += away.Unit * (1 - awayDistance / FOLLOWER_SEPARATION) * FOLLOWER_SEPARATION_WEIGHT
					end
				end
				other = other.nextInCell
			end
		end
	end

	-- Pushed around by players (local player reacts instantly — that's the point)
	for _, playerPosition in playerPositions do
		local away = flatPosition - playerPosition
		local awayDistance = away.Magnitude
		if awayDistance > 0.001 and awayDistance < PLAYER_SEPARATION then
			steer += away.Unit * (1 - awayDistance / PLAYER_SEPARATION) * PLAYER_SEPARATION_WEIGHT
		end
	end

	return steer, toGod
end

local function updateThink(follower: Follower, flatGod: Vector3, playerPositions: { Vector3 })
	local steer, toGod = computeSteer(follower, flatGod, playerPositions)

	-- Hysteresis on the move/idle decision
	local urgency = steer.Magnitude
	local threshold = follower.wantsToMove and STOP_MOVING_THRESHOLD or START_MOVING_THRESHOLD
	follower.wantsToMove = urgency > threshold

	if follower.wantsToMove then
		follower.wishDir = urgency > 1 and steer.Unit or steer
	else
		follower.wishDir = Vector3.zero
		-- Face the ChickenGod in quiet reverence
		if toGod.Magnitude > 0.001 then
			follower.targetYaw = math.atan2(-toGod.X, -toGod.Z)
		end
	end

	-- Snap to ground
	local rayOrigin = Vector3.new(follower.position.X, follower.position.Y + 10, follower.position.Z)
	local hit = Workspace:Raycast(rayOrigin, Vector3.new(0, -50, 0), groundCastParams)
	if hit then
		follower.position = Vector3.new(follower.position.X, hit.Position.Y + follower.hipHeight, follower.position.Z)
	end

	-- Walk animation speed tracks actual velocity
	if follower.moving and follower.walkTrack then
		follower.walkTrack:AdjustSpeed(MathUtils:FlatVec(follower.velocity).Magnitude / WALK_ANIM_TUNED_SPEED)
	end
end

-- ============================================================================
-- Frame: movement integration, turning, animation transitions, rendering
-- ============================================================================

local function updateFrame(follower: Follower, dt: number)
	follower.velocity = MathUtils:GroundAccelerate(follower.wishDir, WALK_SPEED, WALK_ACCEL, follower.velocity, dt)

	local speed = MathUtils:FlatVec(follower.velocity).Magnitude
	if speed > 0.5 then
		follower.position += follower.velocity * dt
		follower.targetYaw = math.atan2(-follower.velocity.X, -follower.velocity.Z)
	end

	follower.yaw = MathUtils:AngleLerp(follower.yaw, follower.targetYaw, 1 - math.pow(1 - TURN_FRACTION, dt))

	-- Animation transitions (rare; the checks are cheap)
	if speed > 0.5 and not follower.moving then
		follower.moving = true
		if follower.idleTrack then
			follower.idleTrack:Stop()
		end
		if follower.walkTrack then
			follower.walkTrack:Play()
		end
	elseif speed <= 0.5 and follower.moving then
		follower.moving = false
		if follower.walkTrack then
			follower.walkTrack:Stop()
		end
		if follower.idleTrack then
			follower.idleTrack:Play()
		end
	end

	-- Only render followers that actually moved or turned
	local positionDelta = follower.position - follower.lastRenderedPosition
	local yawDelta = follower.yaw - follower.lastRenderedYaw
	if positionDelta.Magnitude > 0.01 or math.abs(yawDelta) > 0.002 then
		follower.model:PivotTo(CFrame.new(follower.position) * CFrame.Angles(0, follower.yaw, 0))
		follower.lastRenderedPosition = follower.position
		follower.lastRenderedYaw = follower.yaw
	end
end

-- ============================================================================
-- Startup
-- ============================================================================

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
	for index = 1, FOLLOWER_COUNT do
		local angle = math.random() * math.pi * 2
		local radius = minSpawnRadius + math.random() * (maxSpawnRadius - minSpawnRadius)
		local position = godPosition
			+ Vector3.new(math.sin(angle) * radius, 0, math.cos(angle) * radius)
		table.insert(followers, spawnFollower(rig, position, index % THINK_BUCKETS))
	end

	-- DEBUG: framerate + boids cost, printed every 2s
	local statFrames = 0
	local statTime = 0
	local statBoidsTime = 0

	local frameIndex = 0
	RunService.Heartbeat:Connect(function(dt: number)
		local boidsStart = os.clock()

		frameIndex += 1
		local thinkBucket = frameIndex % THINK_BUCKETS
		local flatGod = MathUtils:FlatVec((god :: Model):GetPivot().Position)

		local playerPositions: { Vector3 } = {}
		for _, player in Players:GetPlayers() do
			local rootPart = player.Character and player.Character.PrimaryPart
			if rootPart then
				table.insert(playerPositions, MathUtils:FlatVec(rootPart.Position))
			end
		end

		rebuildGrid()

		for _, follower in followers do
			if follower.bucket == thinkBucket then
				updateThink(follower, flatGod, playerPositions)
			end
			updateFrame(follower, dt)
		end

		statBoidsTime += os.clock() - boidsStart
		statTime += dt
		statFrames += 1
		if statTime >= 2 then
			print(string.format(
				"FollowersView STATS: %.0f fps | boids %.1fms/frame (%.0f%% of frame budget)",
				statFrames / statTime,
				(statBoidsTime / statFrames) * 1000,
				(statBoidsTime / statTime) * 100
			))
			statFrames = 0
			statTime = 0
			statBoidsTime = 0
		end
	end)

	print(`FollowersView: {FOLLOWER_COUNT} followers gathered around the ChickenGod`)
end

task.spawn(start)
