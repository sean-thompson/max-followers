--!strict

--[[
	HudApp

	Entry point for the react-luau HUD. Mounts a single ScreenGui into PlayerGui
	containing the StatusBar (always visible) and animated modal windows (Favours, Candles).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))
local ReactRoblox = require(Packages:WaitForChild("ReactRoblox"))

local Network = require(ReplicatedStorage:WaitForChild("Network"))

local viewsFolder = script.Parent
local useBoltState = require(viewsFolder:WaitForChild("hooks"):WaitForChild("useBoltState"))
local StatusBarView = require(viewsFolder:WaitForChild("StatusBarView"))
local AnimatedModal = require(viewsFolder:WaitForChild("components"):WaitForChild("AnimatedModal"))

local e = React.createElement

local INVENTORY_DEFAULT: Network.InventoryState = {
	ownerId = "",
	gold = 0,
	treasure = 0,
	favourIds = {},
}

local FAVOURS_DEFAULT: { [string]: Network.FavoursState } = {}

local function HudApp()
	local activeModal, setActiveModal = React.useState(nil :: string?)

	local inventory = useBoltState(Network.State.Inventory, INVENTORY_DEFAULT)
	local favoursDict = useBoltState(Network.State.Favours, FAVOURS_DEFAULT)

	local toggleModal = React.useCallback(function(modalName: string)
		setActiveModal(function(current: string?)
			if current == modalName then
				return nil
			end
			return modalName
		end)
	end, {})

	local closeModal = React.useCallback(function()
		setActiveModal(nil)
	end, {})

	-- Count total favours for subtitle
	local favourCount = 0
	for _ in favoursDict do
		favourCount += 1
	end

	return e("ScreenGui", {
		Name = "HudApp",
		DisplayOrder = 100,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, {
		StatusBar = e(StatusBarView, {
			gold = inventory.gold,
			treasure = inventory.treasure,
			activeModal = activeModal,
			onToggleModal = toggleModal,
		}),
		Modal = e(AnimatedModal, {
			isOpen = activeModal ~= nil,
			modalType = activeModal,
			gold = inventory.gold,
			treasure = inventory.treasure,
			favoursData = favoursDict,
			favourCount = favourCount,
			onClose = closeModal,
		}),
	})
end

-- Mount into PlayerGui
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local root = ReactRoblox.createRoot(playerGui)
root:render(e(HudApp))
