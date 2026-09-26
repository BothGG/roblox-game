--[[
	Client entry point. Starts every controller and UI module.
	Each module has Start(); UI modules get snapshots via Update(snapshot).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local Controllers = script.Parent:WaitForChild("Controllers")
local UI = script.Parent:WaitForChild("UI")

local FxController = require(Controllers.FxController)
local PromptController = require(Controllers.PromptController)
local Toasts = require(UI.Toasts)
local Hud = require(UI.Hud)
local Shop = require(UI.Shop)
local HatchReveal = require(UI.HatchReveal)

FxController.Start()
PromptController.Start()
Toasts.Start()
Shop.Start()
Hud.Start(Shop)
HatchReveal.Start()

Net.Get("DataUpdate").OnClientEvent:Connect(function(snapshot)
	Hud.Update(snapshot)
	Shop.Update(snapshot)
end)

Net.Get("Notify").OnClientEvent:Connect(function(message)
	Toasts.Notify(message.Text, message.Color)
end)

Net.Get("Announce").OnClientEvent:Connect(function(message)
	Toasts.Banner(message.Title, message.Text, message.Color)
end)

Net.Get("Hatched").OnClientEvent:Connect(function(info)
	HatchReveal.Show(info)
end)
