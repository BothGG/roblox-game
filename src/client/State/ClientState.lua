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
}

function ClientState.Set(snapshot: Types.Snapshot)
	local previous = ClientState.Current
	ClientState.Current = snapshot
	ClientState.Changed:Fire(snapshot, previous)
end

return ClientState
