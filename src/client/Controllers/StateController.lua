--[[
	StateController: receives player snapshots from the server and stores
	them in ClientState (which fires ClientState.Changed).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared").Net)
local ClientState = require(script.Parent.Parent.State.ClientState)

local StateController = {
	Priority = 1,
}

function StateController:Start()
	Net.Listen("State", function(snapshot)
		ClientState.Set(snapshot)
	end)
end

return StateController
