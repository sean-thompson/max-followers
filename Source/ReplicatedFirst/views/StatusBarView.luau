--!strict

--[[
	StatusBarView

	V2 centered pill bar at the top of the screen.
	Contains currency chips (gold, treasure) and toggle buttons (Favours, Candles)
	separated by vertical dividers.

	Props:
		gold: number
		treasure: number
		activeModal: string? -- nil | "favours" | "candles"
		onToggleModal: (string) -> ()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local componentsFolder = script.Parent:WaitForChild("components")
local CurrencyChip = require(componentsFolder:WaitForChild("CurrencyChip"))
local HudButton = require(componentsFolder:WaitForChild("HudButton"))

local e = React.createElement

export type Props = {
	gold: number,
	treasure: number,
	activeModal: string?,
	onToggleModal: (string) -> (),
}

local COLOR_PANEL = Color3.fromRGB(18, 20, 24)
local COLOR_DIVIDER = Color3.new(1, 1, 1)

local function Divider(props: { layoutOrder: number })
	return e("Frame", {
		Size = UDim2.new(0, 1, 0, 20),
		BackgroundColor3 = COLOR_DIVIDER,
		BackgroundTransparency = 0.86,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
	})
end

local function StatusBarView(props: Props)
	local onToggleFavours = React.useCallback(function()
		props.onToggleModal("favours")
	end, { props.onToggleModal })

	local onToggleCandles = React.useCallback(function()
		props.onToggleModal("candles")
	end, { props.onToggleModal })

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 44),
		BackgroundColor3 = COLOR_PANEL,
		BackgroundTransparency = 0.22,
	}, {
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, 999),
		}),
		Stroke = e("UIStroke", {
			Color = Color3.new(1, 1, 1),
			Transparency = 0.92,
			Thickness = 1,
		}),
		Padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 5),
			PaddingBottom = UDim.new(0, 5),
		}),
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),

		GoldChip = e(CurrencyChip, {
			currencyType = "gold",
			amount = props.gold,
			layoutOrder = 1,
		}),
		Divider1 = Divider({ layoutOrder = 2 }),
		TreasureChip = e(CurrencyChip, {
			currencyType = "treasure",
			amount = props.treasure,
			layoutOrder = 3,
		}),
		Divider2 = Divider({ layoutOrder = 4 }),
		FavoursButton = e(HudButton, {
			label = "Favours",
			icon = "\u{2B50}",
			isActive = props.activeModal == "favours",
			onActivated = onToggleFavours,
			layoutOrder = 5,
		}),
		CandlesButton = e(HudButton, {
			label = "Candles",
			icon = "\u{1F56F}",
			isActive = props.activeModal == "candles",
			onActivated = onToggleCandles,
			layoutOrder = 6,
		}),
	})
end

return StatusBarView
