--[[
	DataService: loads, saves and replicates player data.

	  DataService:Get(player)      -> the player's data table (or nil)
	  DataService:Changed(player)  -> call after changing data; the UI updates
	  DataService:AddSnapshotHook(fn) -> add extra fields to the UI snapshot

	To add a new saved value: add it to newData() below. Old saves get the
	default automatically.
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local CreatureMath = require(Shared.CreatureMath)
local Net = require(Shared.Net)

local DataService = {
	Profiles = {} :: { [Player]: { Data: any, CanSave: boolean, Key: string } },
	_pending = {} :: { [Player]: boolean },
	_hooks = {} :: { (Player, any) -> () },
}

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end
DataService.DeepCopy = deepCopy

local function newData()
	return {
		Version = 1,
		Cash = GameConfig.StartingCash,
		Rebirths = 0,
		NextUid = 1,
		Creatures = {}, -- [uid] = { Id, Level, Xp, Mutation }
		Food = deepCopy(GameConfig.StartingFood),
		Index = {}, -- ["Rex"] = true, ["Rex:Lava"] = true (collection book)
		Stats = {
			StarterGiven = false,
			Hatched = 0,
			Steals = 0,
			Stolen = 0,
			FoodEaten = 0,
		},
	}
end

-- Fills in missing keys from the template (for old saves).
-- Only top-level keys and Stats are filled, so empty Food/Creatures stay empty.
local function reconcile(data)
	local template = newData()
	for key, value in template do
		if data[key] == nil then
			data[key] = value
		end
	end
	for key, value in template.Stats do
		if data.Stats[key] == nil then
			data.Stats[key] = value
		end
	end
end

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.Data.StoreName)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore unavailable, saving disabled:", result)
	end
end

function DataService:Init(services)
	self.Services = services
end

function DataService:Start()
	task.spawn(function()
		while true do
			task.wait(GameConfig.Data.AutosaveInterval)
			for player in self.Profiles do
				task.spawn(self.Save, self, player)
			end
		end
	end)

	game:BindToClose(function()
		local remaining = 0
		for player in self.Profiles do
			remaining += 1
			task.spawn(function()
				self:Save(player)
				remaining -= 1
			end)
		end
		local started = os.clock()
		while remaining > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
end

function DataService:Load(player: Player)
	local key = "Player_" .. player.UserId
	local data = nil
	local loaded = false
	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(store.GetAsync, store, key)
			if ok then
				data = result
				loaded = true
				break
			end
			warn("[DataService] Load failed for", player.Name, "attempt", attempt, result)
			task.wait(attempt)
		end
	end
	if not player.Parent then
		return nil
	end
	if type(data) ~= "table" then
		data = newData()
	end
	reconcile(data)
	-- Never save over real data that failed to load.
	self.Profiles[player] = { Data = data, CanSave = loaded, Key = key }
	if not loaded then
		task.delay(4, function()
			if player.Parent then
				Net.Notify(player, "⚠️ Saving is off right now. Your progress won't be saved.", Color3.fromRGB(255, 170, 60))
			end
		end)
	end
	return data
end

function DataService:Get(player: Player)
	local profile = self.Profiles[player]
	return profile and profile.Data
end

function DataService:Save(player: Player)
	local profile = self.Profiles[player]
	if not profile or not profile.CanSave or not store then
		return false
	end
	for attempt = 1, 3 do
		local ok, err = pcall(store.UpdateAsync, store, profile.Key, function()
			return profile.Data
		end)
		if ok then
			return true
		end
		warn("[DataService] Save failed for", player.Name, "attempt", attempt, err)
		task.wait(attempt)
	end
	return false
end

function DataService:Release(player: Player)
	self:Save(player)
	self.Profiles[player] = nil
	self._pending[player] = nil
end

function DataService:AddSnapshotHook(hook: (Player, any) -> ())
	table.insert(self._hooks, hook)
end

function DataService:BuildSnapshot(player: Player)
	local data = self:Get(player)
	local snapshot = {
		Cash = data.Cash,
		Rebirths = data.Rebirths,
		Creatures = data.Creatures,
		Food = data.Food,
		IndexCount = CreatureMath.Count(data.Index),
		Slots = CreatureMath.MaxSlots(data.Rebirths),
		StorageCap = CreatureMath.StorageCap(data.Rebirths),
		RebirthCost = CreatureMath.RebirthCost(data.Rebirths),
		SelectedFood = player:GetAttribute("SelectedFood"),
	}
	for _, hook in self._hooks do
		hook(player, snapshot)
	end
	return snapshot
end

-- Batches changes: many calls in one frame send one update.
function DataService:Changed(player: Player)
	if self._pending[player] or not self.Profiles[player] then
		return
	end
	self._pending[player] = true
	task.defer(function()
		self._pending[player] = nil
		if self.Profiles[player] and player.Parent then
			Net.Get("DataUpdate"):FireClient(player, self:BuildSnapshot(player))
		end
	end)
end

return DataService
