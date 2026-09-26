--[[
	ClientState: the latest player snapshot from the server, shared by all
	UI and controllers.

	  ClientState.Current        -- latest Snapshot (nil until first update)
	  ClientState.Changed:Connect(function(snapshot, previous) ... end)
	  ClientState.Biome          -- biome the local player is standing in (or nil)
	  ClientState.BiomeChanged:Connect(function(biomeId, previousBiomeId) ... end)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Lib.Signal)
local Types = require(Shared.Types)

local ClientState = {
	Current = nil :: Types.Snapshot?,
	Changed = Signal.new(),
	Biome = nil :: string?,
	BiomeChanged = Signal.new(),
}

function ClientState.Set(snapshot: Types.Snapshot)
	local previous = ClientState.Current
	ClientState.Current = snapshot
	ClientState.Changed:Fire(snapshot, previous)
end

function ClientState.SetBiome(biomeId: string?)
	if biomeId == ClientState.Biome then
		return
	end
	local previous = ClientState.Biome
	ClientState.Biome = biomeId
	ClientState.BiomeChanged:Fire(biomeId, previous)
end

function ClientState.IsUnlocked(biomeId: string): boolean
	local current = ClientState.Current
	return current ~= nil and current.Unlocks[biomeId] == true
end

return ClientState
