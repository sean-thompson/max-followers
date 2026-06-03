--[[
	FollowerSpawner

	Spawns lightweight NPC "followers" that worship the ChickenGod.

	Boids behaviour (runs server-side in each follower's onThink):
	- Ring formation: stay between MIN_RADIUS and MAX_RADIUS of the ChickenGod
	- Separation: push away from other followers that get too close
	- Player avoidance: push away from players, so players can shove them around
	- Reverence: when standing still, turn to face the ChickenGod

	Requires a Model tagged "ChickenGod" in Workspace and rigs in
	ReplicatedStorage.Assets.Rigs (see ChickenGodView for the tag setup).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local npcModule = require(game.ServerScriptService.LightweightNpcs.LightweightNpcsServerAPI)
local mathUtils = require(game.ReplicatedFirst.LightweightNpcsClient.Utils.MathUtils)

local CHICKEN_GOD_TAG = "ChickenGod"
local RIG_NAME = "Robert"
local FOLLOWER_COUNT = 16

-- Ring around the ChickenGod
local MIN_RADIUS = 12
local MAX_RADIUS = 18
local RING_FALLOFF = 4 -- studs outside the band before urgency reaches full speed

-- Separation
local FOLLOWER_SEPARATION = 5
local FOLLOWER_SEPARATION_WEIGHT = 1
local PLAYER_SEPARATION = 6
local PLAYER_SEPARATION_WEIGHT = 1.5

-- Hysteresis so animation doesn't thrash between idle/walk at the threshold
local START_MOVING_THRESHOLD = 0.15
local STOP_MOVING_THRESHOLD = 0.05

local followers = {}

local function getChickenGod(): Model
	local god = CollectionService:GetTagged(CHICKEN_GOD_TAG)[1]
	while god == nil do
		god = CollectionService:GetInstanceAddedSignal(CHICKEN_GOD_TAG):Wait()
	end
	return god :: Model
end

local function think(npcRecord, godPosition: Vector3)
	local flatPosition = mathUtils:FlatVec(npcRecord.position)
	local flatGod = mathUtils:FlatVec(godPosition)

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
		if other ~= npcRecord then
			local away = flatPosition - mathUtils:FlatVec(other.position)
			local awayDistance = away.Magnitude
			if awayDistance > 0.001 and awayDistance < FOLLOWER_SEPARATION then
				steer += away.Unit * (1 - awayDistance / FOLLOWER_SEPARATION) * FOLLOWER_SEPARATION_WEIGHT
			end
		end
	end

	-- Pushed around by players
	for _, player in Players:GetPlayers() do
		local rootPart = player.Character and player.Character.PrimaryPart
		if rootPart then
			local away = flatPosition - mathUtils:FlatVec(rootPart.Position)
			local awayDistance = away.Magnitude
			if awayDistance > 0.001 and awayDistance < PLAYER_SEPARATION then
				steer += away.Unit * (1 - awayDistance / PLAYER_SEPARATION) * PLAYER_SEPARATION_WEIGHT
			end
		end
	end

	-- Apply: motionVector magnitude scales speed (GroundAccelerate doesn't normalize)
	local urgency = steer.Magnitude
	local threshold = npcRecord.data.moving and STOP_MOVING_THRESHOLD or START_MOVING_THRESHOLD

	if urgency > threshold then
		npcRecord.data.moving = true
		if urgency > 1 then
			steer = steer.Unit
		end
		npcRecord:Move(steer)
		npcRecord:PlayAnimation("walk", false, 1, 1)
	else
		npcRecord.data.moving = false
		npcRecord:Move(Vector3.zero)
		npcRecord:PlayAnimation("idle", false, 1, 1)

		-- Face the ChickenGod in quiet reverence
		if distance > 0.001 then
			npcRecord.targetAngle = mathUtils:PlayerVecToAngle(toGod)
		end
	end
end

local function spawnFollowers()
	local god = getChickenGod()
	local godPosition = god:GetPivot().Position

	local rig = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Rigs"):WaitForChild(RIG_NAME)

	for index = 1, FOLLOWER_COUNT do
		local config = npcModule:CreateConfig()
		config.walkSpeed = 8 -- matches the walk animation's tuned speed
		config.walkAccel = 6
		config.thinkHzRate = 10
		config.replicationHzRate = 4
		config.canCollide = false -- boids separation handles spacing, not hitboxes

		-- Spawn in a ring at mid-band radius, slightly raised so they settle onto the ground
		local angle = (index / FOLLOWER_COUNT) * math.pi * 2
		local radius = (MIN_RADIUS + MAX_RADIUS) / 2
		local position = godPosition
			+ Vector3.new(math.sin(angle) * radius, 5, math.cos(angle) * radius)

		local npcRecord = npcModule:SpawnNpc(rig, config, position, 0)
		npcRecord.data.moving = false

		npcRecord.onThink:Connect(function(_dt)
			think(npcRecord, god:GetPivot().Position)
		end)

		-- Replication is opt-in per player (nil means invisible) — small scene, always visible
		npcRecord.onCullCheck:Connect(function()
			for _, player in Players:GetPlayers() do
				npcRecord:SetPlayerVisibleFlag(player, true)
			end
		end)

		npcRecord.onFellOffMap:Connect(function()
			warn("FollowerSpawner: follower", npcRecord.npcId, "fell off the map")
		end)

		table.insert(followers, npcRecord)
	end

	print(`FollowerSpawner: {FOLLOWER_COUNT} followers gathered around the ChickenGod`)
end

spawnFollowers()
