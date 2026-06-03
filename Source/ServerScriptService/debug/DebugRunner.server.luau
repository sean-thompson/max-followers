--!strict

--[[
	DebugRunner

	Sets up DebugTools authorization and delegates action discovery to
	DebugActionBuilder, which auto-generates actions from `debugActions`
	descriptor tables on each model class. No manual registration needed
	when new models are added.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DebugTools = require(ReplicatedStorage.Packages.DebugTools)
local DebugActionBuilder = require(script.Parent.DebugActionBuilder)

local TEST_GROUP_ID = 13711091
local MIN_RANK = 200

DebugTools.Authorization:SetAuthorizationCallback(function(player: Player)
	if game.CreatorType == Enum.CreatorType.Group then
		return player:GetRankInGroupAsync(TEST_GROUP_ID) >= MIN_RANK
	end

	-- Non-group game: allow Studio sessions or the game creator only
	return RunService:IsStudio() or player.UserId == game.CreatorId
end)

local modelsFolder = script.Parent.Parent.models
DebugActionBuilder.buildAll(modelsFolder)

print("[DebugRunner] Debug actions registered")
