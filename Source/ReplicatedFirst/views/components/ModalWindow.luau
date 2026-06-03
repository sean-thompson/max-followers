--!strict

--[[
	ModalWindow

	Shared modal window chrome with scrim overlay, header, body, and footer.
	Body content is passed via the bodyContent prop.

	Props:
		title: string
		subtitle: string
		gold: number
		treasure: number
		onClose: () -> ()
		windowWidth: number  (max width in pixels)
		windowHeight: number (max height in pixels)
		footerText: string?  (optional footer left text)
		bodyContent: any?    (React element to render in the body)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local useDrag = require(script.Parent.Parent:WaitForChild("hooks"):WaitForChild("useDrag"))

local e = React.createElement

export type Props = {
	title: string,
	subtitle: string,
	gold: number,
	treasure: number,
	onClose: () -> (),
	windowWidth: number,
	windowHeight: number,
	footerText: string?,
	bodyContent: any?, -- React element to render inside the body
	scrimTransparency: any?, -- React binding for animated scrim
	windowTransparency: any?, -- React binding for animated window fade
	windowYOffset: any?, -- React binding for vertical slide animation
}

-- Colours
local COLOR_WINDOW_BG = Color3.fromRGB(30, 33, 38)
local COLOR_STROKE = Color3.new(1, 1, 1)
local COLOR_TEXT = Color3.fromRGB(243, 241, 236)
local COLOR_TEXT_DIM = Color3.fromRGB(243, 241, 236)
local COLOR_TEXT_MUTE = Color3.fromRGB(243, 241, 236)
local COLOR_GOLD = Color3.fromRGB(233, 180, 76)
local COLOR_TREASURE = Color3.fromRGB(111, 214, 199)
local COLOR_SCRIM = Color3.new(0, 0, 0)
local COLOR_FOOTER_BG = Color3.new(0, 0, 0)
local COLOR_SIGIL_BG = Color3.fromRGB(47, 39, 22)

local function formatNumber(n: number): string
	local formatted = tostring(math.floor(n))
	local k: number
	repeat
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
	until k == 0
	return formatted
end

-- Currency mini display for the header
local function CurrencyMini(props: { color: Color3, amount: number, label: string, layoutOrder: number })
	return e("Frame", {
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
	}, {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		Dot = e("Frame", {
			Size = UDim2.new(0, 8, 0, 8),
			BackgroundColor3 = props.color,
			LayoutOrder = 1,
		}, {
			Corner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
		}),
		Amount = e("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Text = formatNumber(props.amount),
			TextColor3 = COLOR_TEXT,
			TextSize = 13,
			Font = Enum.Font.GothamBold,
			LayoutOrder = 2,
		}),
		Label = e("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Text = props.label,
			TextColor3 = COLOR_TEXT_MUTE,
			TextTransparency = 0.38,
			TextSize = 12,
			Font = Enum.Font.GothamMedium,
			LayoutOrder = 3,
		}),
	})
end

local function ModalWindow(props: Props)
	local dragBind, dragOffset = useDrag({
		springBack = true,
		config = { force = 300, dampening = 25 },
	})

	-- Combine drag offset with optional slide animation offset
	local windowPosition
	if props.windowYOffset then
		windowPosition = React.joinBindings({ drag = dragOffset, slide = props.windowYOffset }):map(function(values: any)
			return UDim2.new(0.5, values.drag.X, 0.5, values.drag.Y + values.slide)
		end)
	else
		windowPosition = dragOffset:map(function(offset: Vector2)
			return UDim2.new(0.5, offset.X, 0.5, offset.Y)
		end)
	end

	return e("Frame", {
		Name = "ModalContainer",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 10,
	}, {
		-- Scrim overlay (non-interactive — close via X button only)
		Scrim = e("Frame", {
			Name = "Scrim",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = COLOR_SCRIM,
			BackgroundTransparency = props.scrimTransparency or 0.65,
			ZIndex = 1,
		}),

		-- Window frame (CanvasGroup enables GroupTransparency for fade animation)
		Window = e("CanvasGroup", {
			Name = "Window",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = windowPosition,
			Size = UDim2.new(0, props.windowWidth, 0, props.windowHeight),
			BackgroundTransparency = 1,
			GroupTransparency = props.windowTransparency or 0,
			ClipsDescendants = true,
			ZIndex = 2,
		}, {
			-- Inner frame holds the background + stroke so GroupTransparency fades both
			Inner = e("Frame", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundColor3 = COLOR_WINDOW_BG,
			}, {
				InnerCorner = e("UICorner", {
					CornerRadius = UDim.new(0, 14),
				}),
				Stroke = e("UIStroke", {
					Color = COLOR_STROKE,
					Transparency = 0.86,
					Thickness = 1,
				}),
			}),

			-- Header (draggable)
			Header = e("Frame", {
				Name = "Header",
				Size = UDim2.new(1, 0, 0, 56),
				BackgroundTransparency = 1,
			}, {
				-- Drag handle: invisible overlay that captures drag input
				DragHandle = e("Frame", {
					Size = UDim2.new(1, -46, 1, 0), -- leave space for close button
					BackgroundTransparency = 1,
					Active = true,
					ZIndex = 10,
					[React.Event.InputBegan] = dragBind.onInputBegan,
				}),
				Border = e("Frame", {
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, 0, 1, 0),
					Size = UDim2.new(1, 0, 0, 1),
					BackgroundColor3 = COLOR_STROKE,
					BackgroundTransparency = 0.92,
					BorderSizePixel = 0,
				}),

				-- Left group (sigil + title)
				LeftGroup = e("Frame", {
					Position = UDim2.new(0, 18, 0, 0),
					Size = UDim2.new(0.5, -18, 1, 0),
					BackgroundTransparency = 1,
				}, {
					Layout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 12),
					}),

					-- Sigil icon
					Sigil = e("Frame", {
						Size = UDim2.new(0, 30, 0, 30),
						BackgroundColor3 = COLOR_SIGIL_BG,
						LayoutOrder = 1,
					}, {
						Corner = e("UICorner", {
							CornerRadius = UDim.new(0, 8),
						}),
						Stroke = e("UIStroke", {
							Color = COLOR_GOLD,
							Transparency = 0.7,
							Thickness = 1,
						}),
						Icon = e("TextLabel", {
							Size = UDim2.new(1, 0, 1, 0),
							BackgroundTransparency = 1,
							Text = if props.title == "Favours" then "\u{2B50}" else "\u{1F56F}",
							TextSize = 14,
						}),
					}),

					-- Title block
					TitleBlock = e("Frame", {
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						LayoutOrder = 2,
					}, {
						TitleLayout = e("UIListLayout", {
							FillDirection = Enum.FillDirection.Vertical,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, 2),
						}),
						Title = e("TextLabel", {
							AutomaticSize = Enum.AutomaticSize.XY,
							BackgroundTransparency = 1,
							Text = props.title,
							TextColor3 = COLOR_TEXT,
							TextSize = 14,
							Font = Enum.Font.GothamBold,
							LayoutOrder = 1,
						}),
						Subtitle = e("TextLabel", {
							AutomaticSize = Enum.AutomaticSize.XY,
							BackgroundTransparency = 1,
							Text = props.subtitle,
							TextColor3 = COLOR_TEXT_MUTE,
							TextTransparency = 0.38,
							TextSize = 10,
							Font = Enum.Font.GothamBold,
							LayoutOrder = 2,
						}),
					}),
				}),

				-- Right group (currency + close button)
				RightGroup = e("Frame", {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -18, 0, 0),
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.new(0, 0, 1, 0),
					BackgroundTransparency = 1,
				}, {
					Layout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 12),
					}),

					-- Currency displays
					Gold = e(CurrencyMini, {
						color = COLOR_GOLD,
						amount = props.gold,
						label = "gold",
						layoutOrder = 1,
					}),
					Treasure = e(CurrencyMini, {
						color = COLOR_TREASURE,
						amount = props.treasure,
						label = "treasure",
						layoutOrder = 2,
					}),

					-- Close button
					CloseButton = e("TextButton", {
						Size = UDim2.new(0, 28, 0, 28),
						BackgroundColor3 = Color3.new(1, 1, 1),
						BackgroundTransparency = 0.94,
						Text = "X",
						TextColor3 = COLOR_TEXT_DIM,
						TextTransparency = 0.38,
						TextSize = 14,
						Font = Enum.Font.GothamBold,
						AutoButtonColor = false,
						LayoutOrder = 3,
						[React.Event.Activated] = props.onClose,
					}, {
						Corner = e("UICorner", {
							CornerRadius = UDim.new(0, 6),
						}),
						Stroke = e("UIStroke", {
							Color = COLOR_STROKE,
							Transparency = 0.92,
							Thickness = 1,
						}),
					}),
				}),
			}),

			-- Body (scrollable, hosts body content)
			Body = e("ScrollingFrame", {
				Name = "Body",
				Position = UDim2.new(0, 0, 0, 56),
				Size = UDim2.new(1, 0, 1, -108), -- 56 header + 52 footer
				BackgroundTransparency = 1,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Color3.new(1, 1, 1),
				ScrollBarImageTransparency = 0.7,
				CanvasSize = UDim2.new(0, 0, 0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BorderSizePixel = 0,
			}, {
				Padding = e("UIPadding", {
					PaddingLeft = UDim.new(0, 14),
					PaddingRight = UDim.new(0, 14),
					PaddingTop = UDim.new(0, 14),
					PaddingBottom = UDim.new(0, 14),
				}),
				Content = props.bodyContent,
			}),

			-- Footer
			Footer = e("Frame", {
				Name = "Footer",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 0, 1, 0),
				Size = UDim2.new(1, 0, 0, 52),
				BackgroundColor3 = COLOR_FOOTER_BG,
				BackgroundTransparency = 0.8,
			}, {
				Border = e("Frame", {
					Size = UDim2.new(1, 0, 0, 1),
					BackgroundColor3 = COLOR_STROKE,
					BackgroundTransparency = 0.92,
					BorderSizePixel = 0,
				}),
				Padding = e("UIPadding", {
					PaddingLeft = UDim.new(0, 18),
					PaddingRight = UDim.new(0, 18),
				}),
				FooterText = e("TextLabel", {
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					Text = props.footerText or "",
					TextColor3 = COLOR_TEXT_MUTE,
					TextTransparency = 0.62,
					TextSize = 12,
					Font = Enum.Font.GothamMedium,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
			}),
		}),
	})
end

return ModalWindow
