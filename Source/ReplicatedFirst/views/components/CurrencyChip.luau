--!strict

--[[
	CurrencyChip

	Displays a currency icon circle + formatted number inside a pill-shaped frame.
	Used in the StatusBar and ModalWindow header.

	Props:
		currencyType: "gold" | "treasure"
		amount: number
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local useSpringNumber = require(script.Parent.Parent:WaitForChild("hooks"):WaitForChild("useSpringNumber"))

local e = React.createElement

export type Props = {
	currencyType: string,
	amount: number,
	layoutOrder: number?,
}

local CURRENCY_CONFIG = {
	gold = {
		iconColor = Color3.fromRGB(233, 180, 76),
		iconText = "\u{1F4B0}",
	},
	treasure = {
		iconColor = Color3.fromRGB(111, 214, 199),
		iconText = "\u{1F48E}",
	},
}

local function formatNumber(n: number): string
	local formatted = tostring(math.floor(n))
	local k: number
	repeat
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
	until k == 0
	return formatted
end

local function CurrencyChip(props: Props)
	local config = CURRENCY_CONFIG[props.currencyType] or CURRENCY_CONFIG.gold
	local displayAmount = useSpringNumber(props.amount, { force = 120, dampening = 24 })

	return e("Frame", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 34),
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder or 0,
	}, {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
		Padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 14),
		}),

		Icon = e("Frame", {
			Size = UDim2.new(0, 24, 0, 24),
			BackgroundColor3 = config.iconColor,
			LayoutOrder = 1,
		}, {
			Corner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
			Label = e("TextLabel", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = config.iconText,
				TextColor3 = Color3.fromRGB(0, 0, 0),
				TextSize = 14,
			}),
		}),

		Value = e("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = formatNumber(displayAmount),
			TextColor3 = Color3.fromRGB(243, 241, 236),
			TextSize = 15,
			Font = Enum.Font.GothamBold,
			LayoutOrder = 2,
		}),
	})
end

return CurrencyChip
