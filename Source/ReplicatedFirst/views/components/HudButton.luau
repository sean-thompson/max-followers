--!strict

--[[
	HudButton

	A toggle button used inside the StatusBar pill.
	Fully transparent by default, subtle white hover, gold-tinted when active.

	Props:
		label: string
		icon: string (emoji)
		isActive: boolean
		onActivated: () -> ()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local e = React.createElement

export type Props = {
	label: string,
	icon: string,
	isActive: boolean,
	onActivated: () -> (),
	layoutOrder: number?,
}

local COLOR_TEXT = Color3.fromRGB(243, 241, 236)
local COLOR_GOLD_SOFT = Color3.fromRGB(246, 213, 138)
local COLOR_GOLD_BG = Color3.fromRGB(60, 48, 24)
local COLOR_HOVER = Color3.new(1, 1, 1)

local function HudButton(props: Props)
	local isHovered, setIsHovered = React.useState(false)

	local bgTransparency: number
	local bgColor: Color3
	local textColor: Color3

	if props.isActive then
		bgColor = COLOR_GOLD_BG
		bgTransparency = 0
		textColor = COLOR_GOLD_SOFT
	elseif isHovered then
		bgColor = COLOR_HOVER
		bgTransparency = 0.94 -- rgba(255,255,255,0.06)
		textColor = COLOR_TEXT
	else
		bgColor = Color3.new(0, 0, 0)
		bgTransparency = 1
		textColor = COLOR_TEXT
	end

	local onEnter = React.useCallback(function()
		setIsHovered(true)
	end, {})

	local onLeave = React.useCallback(function()
		setIsHovered(false)
	end, {})

	return e("TextButton", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 34),
		BackgroundColor3 = bgColor,
		BackgroundTransparency = bgTransparency,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = props.layoutOrder or 0,
		[React.Event.Activated] = props.onActivated,
		[React.Event.MouseEnter] = onEnter,
		[React.Event.MouseLeave] = onLeave,
	}, {
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, 10),
		}),
		Stroke = if props.isActive then e("UIStroke", {
			Color = Color3.fromRGB(233, 180, 76),
			Transparency = 0.45,
			Thickness = 1,
		}) else nil,
		Padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 14),
		}),
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 7),
		}),

		Icon = e("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Text = props.icon,
			TextSize = 14,
			LayoutOrder = 1,
		}),

		Label = e("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = props.label,
			TextColor3 = textColor,
			TextSize = 14,
			Font = Enum.Font.GothamMedium,
			LayoutOrder = 2,
		}),
	})
end

return HudButton
