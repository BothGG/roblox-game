--[[
	UIController: starts every UI module and connects them to state and
	server messages.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared").Net)
local ClientState = require(script.Parent.Parent.State.ClientState)

local UI = script.Parent.Parent:WaitForChild("UI")
local Toasts = require(UI.Toasts)
local Hud = require(UI.Hud)
local Shop = require(UI.Shop)
local HatchReveal = require(UI.HatchReveal)

local UIController = {
	Priority = 10,
}

function UIController:Start()
	Toasts.Start()
	Shop.Start()
	Hud.Start(Shop)
	HatchReveal.Start()

	ClientState.Changed:Connect(function(snapshot)
		Hud.Update(snapshot)
		Shop.Update(snapshot)
	end)
	ClientState.BiomeChanged:Connect(function(biomeId)
		Hud.SetBiome(biomeId)
	end)

	Net.Listen("Notify", function(message)
		Toasts.Notify(message.Text, message.Color)
	end)
	Net.Listen("Announce", function(message)
		Toasts.Banner(message.Title, message.Text, message.Color)
	end)
	Net.Listen("Hatched", function(info)
		HatchReveal.Show(info)
	end)
end

return UIController
