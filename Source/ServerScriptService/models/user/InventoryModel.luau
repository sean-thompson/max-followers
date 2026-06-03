--!strict

local AbstractModel = require(script.Parent.Parent.AbstractModel)

local InventoryModel = {}
InventoryModel.__index = InventoryModel
setmetatable(InventoryModel, AbstractModel)

export type InventoryModel = typeof(setmetatable({} :: {
	gold: number,
	treasure: number,
	favourIds: {string},
}, InventoryModel)) & AbstractModel.AbstractModel

function InventoryModel.new(ownerId: string): InventoryModel
	local self = AbstractModel.new("InventoryModel", ownerId, "User") :: any
	setmetatable(self, InventoryModel)

	self.gold = 0
	self.treasure = 0
	self.favourIds = {}

	return self :: InventoryModel
end

function InventoryModel.get(ownerId: string): InventoryModel?
	return AbstractModel.getOrWait("InventoryModel", ownerId, function()
		return InventoryModel.new(ownerId)
	end) :: InventoryModel?
end

function InventoryModel.remove(ownerId: string): ()
	AbstractModel.removeInstance("InventoryModel", ownerId)
end

function InventoryModel:addGold(amount: number): ()
	self.gold += amount
	self:syncState()
end

function InventoryModel:spendGold(amount: number): boolean
	if self.gold >= amount then
		self.gold -= amount
		self:syncState()
		return true
	end
	return false
end

function InventoryModel:addTreasure(amount: number): ()
	self.treasure += amount
	self:syncState()
end

function InventoryModel:spendTreasure(amount: number): boolean
	if self.treasure >= amount then
		self.treasure -= amount
		self:syncState()
		return true
	end
	return false
end

function InventoryModel:addFavourId(favourId: string): ()
	table.insert(self.favourIds, favourId)
	self:syncState()
end

function InventoryModel:removeFavourId(favourId: string): ()
	local index = table.find(self.favourIds, favourId)
	if index then
		table.remove(self.favourIds, index)
		self:syncState()
	end
end

-- Debug action descriptors for DebugActionBuilder.
-- Pure data — no imports required. Builder prepends a Player arg for User scope.
-- DebugTools arg types: "Player" | "string" | "number" | "boolean"
InventoryModel.debugActions = {
	{
		name = "Add Gold",
		description = "Add gold to a player's inventory",
		method = "addGold",
		args = {
			{ Type = "number", Name = "Amount", Default = 100 },
		},
	},
	{
		name = "Spend Gold",
		description = "Remove gold from a player's inventory",
		method = "spendGold",
		args = {
			{ Type = "number", Name = "Amount", Default = 100 },
		},
	},
	{
		name = "Add Treasure",
		description = "Add treasure to a player's inventory",
		method = "addTreasure",
		args = {
			{ Type = "number", Name = "Amount", Default = 100 },
		},
	},
	{
		name = "Spend Treasure",
		description = "Remove treasure from a player's inventory",
		method = "spendTreasure",
		args = {
			{ Type = "number", Name = "Amount", Default = 100 },
		},
	},
	{
		name = "Add FavourId",
		description = "Add a favour ID to a player's inventory",
		method = "addFavourId",
		args = {
			{ Type = "string", Name = "Favour ID", Default = "" },
		},
	},
	{
		name = "Remove FavourId",
		description = "Remove a favour ID from a player's inventory",
		method = "removeFavourId",
		args = {
			{ Type = "string", Name = "Favour ID", Default = "" },
		},
	},
}

return InventoryModel
