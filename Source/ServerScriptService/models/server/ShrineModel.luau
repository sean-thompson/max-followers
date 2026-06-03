--!strict

local AbstractModel = require(script.Parent.Parent.AbstractModel)

local ShrineModel = {}
ShrineModel.__index = ShrineModel
setmetatable(ShrineModel, AbstractModel)

export type ShrineModel = typeof(setmetatable({} :: {
	treasure: number,
	userId: string,
}, ShrineModel)) & AbstractModel.AbstractModel

function ShrineModel.new(ownerId: string): ShrineModel
	local self = AbstractModel.new("ShrineModel", ownerId, "Server") :: any
	setmetatable(self, ShrineModel)

	self.treasure = 0
	self.userId = ""

	return self :: ShrineModel
end

function ShrineModel.get(ownerId: string): ShrineModel
	return AbstractModel.getOrCreate("ShrineModel", ownerId, function()
		return ShrineModel.new(ownerId)
	end) :: ShrineModel
end

function ShrineModel.remove(ownerId: string): ()
	AbstractModel.removeInstance("ShrineModel", ownerId)
end

function ShrineModel:donate(playerUserId: string, amount: number): ()
	self.treasure += amount
	self.userId = playerUserId
	self:syncState() -- Automatically broadcasts to all (Server scope)
end

function ShrineModel:removeTreasure(amount: number): boolean
	if self.treasure >= amount then
		self.treasure -= amount
		self:syncState() -- Automatically broadcasts to all (Server scope)
		return true
	end
	return false
end

-- Debug action descriptors for DebugActionBuilder.
-- Pure data — no imports required. Server scope: no Player arg is prepended.
-- DebugTools arg types: "Player" | "string" | "number" | "boolean"
ShrineModel.debugActions = {
	{
		name = "Donate",
		description = "Donate treasure to the shrine on behalf of a player",
		method = "donate",
		args = {
			{ Type = "string", Name = "Player User ID", Default = "" },
			{ Type = "number", Name = "Amount", Default = 100 },
		},
	},
	{
		name = "Remove Treasure",
		description = "Remove treasure from the shrine",
		method = "removeTreasure",
		args = {
			{ Type = "number", Name = "Amount", Default = 100 },
		},
	},
}

return ShrineModel
