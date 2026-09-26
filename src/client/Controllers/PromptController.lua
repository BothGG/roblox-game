--[[
	PromptController: shows each ProximityPrompt only to the right players.

	Server sets attributes on a prompt:
	  OnlyUserId    = only this player sees it (feed/sell your own kaiju)
	  HideForUserId = everyone except this player (steal from others)
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local PromptController = {}

local function evaluate(prompt: ProximityPrompt)
	local only = prompt:GetAttribute("OnlyUserId")
	local hide = prompt:GetAttribute("HideForUserId")
	local visible = true
	if only ~= nil and only ~= player.UserId then
		visible = false
	end
	if hide ~= nil and hide == player.UserId then
		visible = false
	end
	prompt.Enabled = visible
end

local function track(instance: Instance)
	if instance:IsA("ProximityPrompt") then
		evaluate(instance)
		instance.AttributeChanged:Connect(function()
			evaluate(instance)
		end)
	end
end

function PromptController.Start()
	for _, d in Workspace:GetDescendants() do
		track(d)
	end
	Workspace.DescendantAdded:Connect(track)
end

return PromptController
