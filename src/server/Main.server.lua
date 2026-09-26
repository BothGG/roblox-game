--[[
	Server entry point. Loads every service, then handles players.

	Service pattern (see docs/ARCHITECTURE.md):
	  Service:Init(services)  -- grab other services, no yielding
	  Service:Start()         -- start loops / connect remotes
	  Service:OnPlayerReady(player) / :OnPlayerRemoving(player)  -- optional
]]

local Players = game:GetService("Players")

local ServicesFolder = script.Parent:WaitForChild("Services")

-- Order matters: services start in this order.
local ORDER = {
	"DataService",
	"FxService",
	"WorldService",
	"FoodService",
	"CreatureService",
	"KingService",
	"StealService",
	"EggService",
	"RebirthService",
	"EventService",
}

local services = {}
for _, name in ORDER do
	services[name] = require(ServicesFolder:WaitForChild(name))
end
for _, name in ORDER do
	local service = services[name]
	if service.Init then
		service:Init(services)
	end
end
for _, name in ORDER do
	local service = services[name]
	if service.Start then
		service:Start()
	end
end

local function onPlayerAdded(player: Player)
	local data = services.DataService:Load(player)
	if not data or not player.Parent then
		return
	end
	local plot = services.WorldService:Assign(player)
	if not plot then
		player:Kick("This server is full. Please join another one!")
		return
	end
	for _, name in ORDER do
		local service = services[name]
		if service.OnPlayerReady then
			service:OnPlayerReady(player)
		end
	end
	services.DataService:Changed(player)
end

local function onPlayerRemoving(player: Player)
	if not services.DataService:Get(player) then
		return
	end
	-- Reverse order, DataService last so it saves the final state.
	for i = #ORDER, 1, -1 do
		local service = services[ORDER[i]]
		if service.OnPlayerRemoving and service ~= services.DataService then
			service:OnPlayerRemoving(player)
		end
	end
	services.WorldService:Release(player)
	services.DataService:Release(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
