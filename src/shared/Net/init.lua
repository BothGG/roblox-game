--[[
	Net: typed, validated networking built from Net/Remotes.lua.

	Server:
	  Net.On("BuyEgg", function(player, eggId) ... end)  -- args already type-checked + rate limited
	  Net.Fire(player, "Notify", data)
	  Net.FireAll("Fx", name, params)
	  Net.Notify(player, text, color) / Net.NotifyAll / Net.Announce
	  Net.Throttle(player, key, seconds) -> boolean

	Client:
	  Net.Send("BuyEgg", "BasicEgg")
	  Net.Listen("State", function(snapshot) ... end)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(script.Remotes)
local Guard = require(script.Parent.Lib.Guard)
local Log = require(script.Parent.Lib.Log)

local log = Log.new("Net")
local IS_SERVER = RunService:IsServer()

local Net = {}
Net.Remotes = Remotes

local folder: Folder
if IS_SERVER then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for name, spec in Remotes do
		local remote = Instance.new(if spec.Unreliable then "UnreliableRemoteEvent" else "RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local function remote(name: string): any
	assert(Remotes[name], "Unknown remote: " .. name)
	return folder:WaitForChild(name)
end

--------------------------------------------------------------------------
-- Rate limiting (server)
--------------------------------------------------------------------------

local lastCalls: { [Player]: { [string]: number } } = {}

function Net.Throttle(player: Player, key: string, cooldown: number): boolean
	local calls = lastCalls[player]
	if not calls then
		calls = {}
		lastCalls[player] = calls
	end
	local now = os.clock()
	local last = calls[key]
	if last and now - last < cooldown then
		return false
	end
	calls[key] = now
	return true
end

--------------------------------------------------------------------------
-- Server API
--------------------------------------------------------------------------

function Net.On(name: string, handler: (Player, ...any) -> ())
	assert(IS_SERVER, "Net.On is server-only")
	local spec = Remotes[name]
	assert(spec and spec.Direction == "ToServer", name .. " is not a ToServer remote")
	remote(name).OnServerEvent:Connect(function(player: Player, ...)
		local args = table.pack(...)
		local ok, reason = Guard.CheckArgs(args, spec.Args or {}, args.n)
		if not ok then
			log:Warn(player.Name, "sent bad", name, reason)
			return
		end
		if spec.RateLimit and not Net.Throttle(player, "remote:" .. name, spec.RateLimit) then
			return
		end
		handler(player, table.unpack(args, 1, args.n))
	end)
end

function Net.Fire(player: Player, name: string, ...)
	remote(name):FireClient(player, ...)
end

function Net.FireAll(name: string, ...)
	remote(name):FireAllClients(...)
end

function Net.Notify(player: Player, text: string, color: Color3?)
	Net.Fire(player, "Notify", { Text = text, Color = color })
end

function Net.NotifyAll(text: string, color: Color3?)
	Net.FireAll("Notify", { Text = text, Color = color })
end

function Net.Announce(title: string, text: string, color: Color3?)
	Net.FireAll("Announce", { Title = title, Text = text, Color = color })
end

--------------------------------------------------------------------------
-- Client API
--------------------------------------------------------------------------

function Net.Send(name: string, ...)
	assert(not IS_SERVER, "Net.Send is client-only")
	remote(name):FireServer(...)
end

function Net.Listen(name: string, handler: (...any) -> ())
	assert(not IS_SERVER, "Net.Listen is client-only")
	return remote(name).OnClientEvent:Connect(handler)
end

if IS_SERVER then
	Players.PlayerRemoving:Connect(function(player)
		lastCalls[player] = nil
	end)
end

return Net
