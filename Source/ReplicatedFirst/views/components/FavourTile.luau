--!strict

--[[
	FavourTile

	A single favour card in the Favours grid.
	The tile background IS the rarity colour (derived from FavoursConfig chance
	values). A cream body with UICorner is overlaid below so the coloured
	stripe follows the parent's corner radius naturally.

	Props:
		favourType: string
		count: number
		layoutOrder: number?
		groupTransparency: any? -- React binding for stagger fade-in
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local FavoursConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("FavoursConfig"))

local e = React.createElement

export type Props = {
	favourType: string,
	count: number,
	layoutOrder: number?,
	groupTransparency: any?,
}

-- Rarity colour tiers based on chance value from FavoursConfig
local RARITY_TIERS = {
	{ threshold = 0.5,  color = Color3.fromRGB(184, 190, 200) }, -- common (grey)
	{ threshold = 0.2,  color = Color3.fromRGB(111, 214, 199) }, -- uncommon (teal)
	{ threshold = 0.05, color = Color3.fromRGB(91, 164, 232) },  -- rare (blue)
	{ threshold = 0,    color = Color3.fromRGB(233, 180, 76) },   -- legendary (gold)
}

local function getRarityColor(favourType: string): Color3
	local chance = FavoursConfig.favours[favourType]
	if not chance then
		return RARITY_TIERS[1].color
	end

	for _, tier in RARITY_TIERS do
		if chance >= tier.threshold then
			return tier.color
		end
	end

	return RARITY_TIERS[#RARITY_TIERS].color
end

local COLOR_TILE_BG = Color3.fromRGB(245, 241, 232)
local COLOR_TILE_TEXT = Color3.fromRGB(44, 38, 32)
local COLOR_BADGE_BG = Color3.fromRGB(11, 13, 16)
local COLOR_BADGE_TEXT = Color3.fromRGB(246, 213, 138)
local COLOR_ART_BG = Color3.fromRGB(220, 214, 200)

local RARITY_BAR_HEIGHT = 4
local CORNER_RADIUS = 10

local function FavourTile(props: Props)
	local rarityColor = getRarityColor(props.favourType)
	local initials = string.upper(string.sub(props.favourType, 1, 2))

	-- CanvasGroup enables GroupTransparency for stagger fade-in
	return e("CanvasGroup", {
		Size = UDim2.new(0, 118, 0, 128),
		BackgroundColor3 = rarityColor,
		GroupTransparency = props.groupTransparency or 0,
		LayoutOrder = props.layoutOrder or 0,
		ClipsDescendants = true,
	}, {
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, CORNER_RADIUS),
		}),
		Stroke = e("UIStroke", {
			Color = Color3.new(0, 0, 0),
			Transparency = 0.92,
			Thickness = 1,
		}),

		-- Cream body overlaid below the rarity stripe
		Body = e("Frame", {
			Position = UDim2.new(0, 0, 0, RARITY_BAR_HEIGHT),
			Size = UDim2.new(1, 0, 1, -RARITY_BAR_HEIGHT),
			BackgroundColor3 = COLOR_TILE_BG,
			BorderSizePixel = 0,
		}, {
			BodyCorner = e("UICorner", {
				CornerRadius = UDim.new(0, CORNER_RADIUS),
			}),
		}),

		-- Count badge (top-right, fixed circle)
		CountBadge = e("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 10),
			Size = UDim2.new(0, 24, 0, 24),
			BackgroundColor3 = COLOR_BADGE_BG,
			ZIndex = 3,
		}, {
			BadgeCorner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
			Stroke = e("UIStroke", {
				Color = Color3.fromRGB(233, 180, 76),
				Transparency = 0.6,
				Thickness = 1,
			}),
			Label = e("TextLabel", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = tostring(props.count),
				TextColor3 = COLOR_BADGE_TEXT,
				TextSize = 11,
				Font = Enum.Font.GothamBold,
			}),
		}),

		-- Art placeholder (initials)
		Art = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 34),
			Size = UDim2.new(0, 56, 0, 56),
			BackgroundColor3 = COLOR_ART_BG,
			ZIndex = 2,
		}, {
			ArtCorner = e("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
			Initials = e("TextLabel", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = initials,
				TextColor3 = COLOR_TILE_TEXT,
				TextTransparency = 0.3,
				TextSize = 22,
				Font = Enum.Font.GothamBold,
			}),
		}),

		-- Name label at bottom
		NameLabel = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -20, 0, 28),
			BackgroundTransparency = 1,
			Text = props.favourType,
			TextColor3 = COLOR_TILE_TEXT,
			TextSize = 11,
			Font = Enum.Font.GothamMedium,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 2,
		}),
	})
end

return FavourTile
