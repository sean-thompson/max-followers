--!strict

--[[
	AnimatedModal

	Wrapper component that animates modal open/close using useTransition.
	Stays mounted across the modal's lifecycle to manage the exit animation.

	Props:
		isOpen: boolean
		modalType: string? -- "favours" | "candles" (used to build the correct modal)
		gold: number
		treasure: number
		favoursData: any
		favourCount: number
		onClose: () -> ()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local viewsFolder = script.Parent.Parent
local useTransition = require(viewsFolder:WaitForChild("hooks"):WaitForChild("useTransition"))
local ModalWindow = require(script.Parent:WaitForChild("ModalWindow"))
local FavoursView = require(viewsFolder:WaitForChild("FavoursView"))
local CandlesView = require(viewsFolder:WaitForChild("CandlesView"))

local e = React.createElement

export type Props = {
	isOpen: boolean,
	modalType: string?,
	gold: number,
	treasure: number,
	favoursData: any,
	favourCount: number,
	onClose: () -> (),
}

local MODAL_CONFIGS: { [string]: { title: string, subtitle: string, width: number, height: number, footerText: string } } = {
	favours = {
		title = "Favours",
		subtitle = "", -- dynamic, set in render
		width = 560,
		height = 460,
		footerText = "Blessings earned at the shrine",
	},
	candles = {
		title = "Candles",
		subtitle = "OFFERINGS",
		width = 520,
		height = 440,
		footerText = "Light a candle at the shrine",
	},
}

local function AnimatedModal(props: Props)
	local transitions = useTransition(props.isOpen, {
		from = {
			BackgroundTransparency = 1, -- scrim starts invisible
			WindowTransparency = 1,     -- window starts invisible
			WindowYOffset = -50,        -- window starts 50px above center
		},
		enter = {
			BackgroundTransparency = 0.35, -- scrim target (1 - 0.65)
			WindowTransparency = 0,        -- window fully visible
			WindowYOffset = 0,             -- slides down to center
		},
		leave = {
			BackgroundTransparency = 1,
			WindowTransparency = 1,
			WindowYOffset = -50,
		},
		config = { force = 200, dampening = 14, mass = 1 },
		leaveConfig = { force = 300, dampening = 30, mass = 1 },
	})

	local elements: { [string]: any } = {}

	for _, transition in transitions do
		local modalType = props.modalType or "favours"
		local modalConfig = MODAL_CONFIGS[modalType] or MODAL_CONFIGS.favours

		local subtitle = modalConfig.subtitle
		if modalType == "favours" then
			subtitle = `{props.favourCount} \u{00B7} BLESSINGS EARNED AT THE SHRINE`
		end

		local bodyContent
		if modalType == "favours" then
			bodyContent = e(FavoursView, {
				favoursData = props.favoursData,
			})
		else
			bodyContent = e(CandlesView)
		end

		elements[transition.key] = e(ModalWindow, {
			title = modalConfig.title,
			subtitle = subtitle,
			gold = props.gold,
			treasure = props.treasure,
			onClose = props.onClose,
			windowWidth = modalConfig.width,
			windowHeight = modalConfig.height,
			footerText = modalConfig.footerText,
			bodyContent = bodyContent,
			scrimTransparency = transition.springProps.BackgroundTransparency,
			windowTransparency = transition.springProps.WindowTransparency,
			windowYOffset = transition.springProps.WindowYOffset,
		})
	end

	return e("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
	}, elements)
end

return AnimatedModal
