--[[
	PromptController: shows each ProximityPrompt only to the right players.

	Prompt attributes (set by the server):
	  OnlyUserId    = only this player sees it (feed/sell your own kaiju)
	  HideForUserId = everyone except this player (steal from others)
	  UnlockBiome   = hidden once this player has unlocked that biome
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ClientState = require(script.Parent.Parent.State.ClientState)

local player = Players.LocalPlayer

local PromptController = {
	Priority = 20,
}

local tracked: { ProximityPrompt } = {}

local function evaluate(prompt: ProximityPrompt)
	local only = prompt:GetAttribute("OnlyUserId")
	local hide = prompt:GetAttribute("HideForUserId")
	local biome = prompt:GetAttribute("UnlockBiome")
	local visible = true
	if only ~= nil and only ~= player.UserId then
		visible = false
	end
	if hide ~= nil and hide == player.UserId then
		visible = false
	end
	if type(biome) == "string" and ClientState.IsUnlocked(biome) then
		visible = false
	end
	prompt.Enabled = visible
end

local function track(instance: Instance)
	if not instance:IsA("ProximityPrompt") then
		return
	end
	table.insert(tracked, instance)
	evaluate(instance)
	instance.AttributeChanged:Connect(function()
		evaluate(instance)
	end)
	instance.Destroying:Connect(function()
		local index = table.find(tracked, instance)
		if index then
			table.remove(tracked, index)
		end
	end)
end

function PromptController:Start()
	for _, d in Workspace:GetDescendants() do
		track(d)
	end
	Workspace.DescendantAdded:Connect(track)
	-- Unlocking a biome changes which gate prompts show.
	ClientState.Changed:Connect(function(snapshot, previous)
		if previous and snapshot.Unlocks == previous.Unlocks then
			return
		end
		for _, prompt in tracked do
			if prompt:GetAttribute("UnlockBiome") then
				evaluate(prompt)
			end
		end
	end)
end

return PromptController
