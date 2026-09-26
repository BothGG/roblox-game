--[[
	Net: one place that lists every RemoteEvent.
	The server creates them; the client waits for them.

	Add a new remote: put its name in REMOTES, then use Net.Get("Name").
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTES = {
	-- server -> client
	"DataUpdate", -- full player snapshot for the UI
	"Notify", -- small toast message
	"Announce", -- big banner for everyone
	"Fx", -- play an effect preset
	"Hatched", -- egg reveal
	-- client -> server
	"BuyEgg",
	"BuyFood",
	"SelectFood",
	"LockStorage",
	"Rebirth",
}

local Net = {}

local folder: Folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in REMOTES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Net.Get(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

-- Server-side spam protection. Returns true if the call is allowed.
local lastCalls: { [Player]: { [string]: number } } = {}

function Net.Throttle(player: Player, key: string, cooldown: number): boolean
	local calls = lastCalls[player]
	if not calls then
		calls = {}
		lastCalls[player] = calls
	end
	local now = os.clock()
	if calls[key] and now - calls[key] < cooldown then
		return false
	end
	calls[key] = now
	return true
end

-- Sends a toast to one player.
function Net.Notify(player: Player, text: string, color: Color3?)
	Net.Get("Notify"):FireClient(player, { Text = text, Color = color })
end

function Net.NotifyAll(text: string, color: Color3?)
	Net.Get("Notify"):FireAllClients({ Text = text, Color = color })
end

function Net.Announce(title: string, text: string, color: Color3?)
	Net.Get("Announce"):FireAllClients({ Title = title, Text = text, Color = color })
end

if RunService:IsServer() then
	Players.PlayerRemoving:Connect(function(player)
		lastCalls[player] = nil
	end)
end

return Net
