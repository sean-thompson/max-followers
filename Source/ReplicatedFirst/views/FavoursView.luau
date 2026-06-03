--!strict

--[[
	FavoursView

	Body content for the Favours modal window.
	Aggregates favour data by type and renders a grid of FavourTile cards
	with staggered entrance animation.

	Props:
		favoursData: { [string]: Network.FavoursState }
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local Network = require(ReplicatedStorage:WaitForChild("Network"))
local FavourTile = require(script.Parent:WaitForChild("components"):WaitForChild("FavourTile"))
local useTransition = require(script.Parent:WaitForChild("hooks"):WaitForChild("useTransition"))

local e = React.createElement

local COLOR_TEXT_MUTE = Color3.fromRGB(243, 241, 236)

export type Props = {
	favoursData: { [string]: Network.FavoursState },
}

-- Aggregate counts by favour type from the favours dictionary
local function getCountsByType(favours: { [string]: Network.FavoursState }): { [string]: number }
	local counts: { [string]: number } = {}
	for _, favour in pairs(favours) do
		local favourType = favour.favourType
		if favourType and favourType ~= "" then
			counts[favourType] = (counts[favourType] or 0) + 1
		end
	end
	return counts
end

-- Stable sort order for favour types (fallback to alphabetical)
local TYPE_ORDER: { [string]: number } = {
	Blessing = 1,
	Fortune = 2,
	Miracle = 3,
}

local function FavoursView(props: Props)
	local counts = getCountsByType(props.favoursData)

	-- Build sorted item list for transitions
	local sortedItems = React.useMemo(function()
		local items = {}
		for favourType, count in counts do
			table.insert(items, { favourType = favourType, count = count })
		end
		table.sort(items, function(a, b)
			local orderA = TYPE_ORDER[a.favourType] or 99
			local orderB = TYPE_ORDER[b.favourType] or 99
			if orderA ~= orderB then
				return orderA < orderB
			end
			return a.favourType < b.favourType
		end)
		return items
	end, { props.favoursData })

	local transitions = useTransition(sortedItems, {
		from = { GroupTransparency = 1 },
		enter = { GroupTransparency = 0 },
		leave = { GroupTransparency = 1 },
		trail = 40,
		keys = function(item: any)
			return item.favourType
		end,
		config = { force = 220, dampening = 22, mass = 1 },
	})

	-- Check if there are any favours
	if #sortedItems == 0 then
		return e("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
			Icon = e("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				Text = "\u{2B50}",
				TextSize = 32,
				LayoutOrder = 1,
			}),
			Message = e("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				Text = "No favours yet",
				TextColor3 = COLOR_TEXT_MUTE,
				TextTransparency = 0.38,
				TextSize = 14,
				Font = Enum.Font.GothamMedium,
				LayoutOrder = 2,
			}),
			Hint = e("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				Text = "Donate at the shrine to earn blessings",
				TextColor3 = COLOR_TEXT_MUTE,
				TextTransparency = 0.62,
				TextSize = 12,
				Font = Enum.Font.GothamMedium,
				LayoutOrder = 3,
			}),
		})
	end

	-- Build tile elements from transitions
	local tiles: { [string]: any } = {}
	for i, transition in transitions do
		local item = transition.item
		tiles[transition.key] = e(FavourTile, {
			favourType = item.favourType,
			count = item.count,
			layoutOrder = TYPE_ORDER[item.favourType] or 99,
			groupTransparency = transition.springProps.GroupTransparency,
		})
	end

	tiles["_Layout"] = e("UIGridLayout", {
		CellSize = UDim2.new(0, 118, 0, 128),
		CellPadding = UDim2.new(0, 10, 0, 10),
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	return e("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, tiles)
end

return FavoursView
