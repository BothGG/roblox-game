--[[
	DataService: loads, saves and replicates player data.

	  DataService:Get(player)          -> PlayerData (or nil if not loaded)
	  DataService:Changed(player)      -> call after changing data; the UI updates
	  DataService:AddSnapshotHook(fn)  -> add computed fields to the UI snapshot
	  DataService.Loaded / .Releasing  -> Signals(player, data)

	Saves use SessionStore (session locking) and Schema (versions + migrations).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local CreatureMath = require(Shared.Game.CreatureMath)
local Signal = require(Shared.Lib.Signal)
local Log = require(Shared.Lib.Log)
local Net = require(Shared.Net)
local Types = require(Shared.Types)

local DataFolder = ServerScriptService:WaitForChild("Server"):WaitForChild("Data")
local Schema = require(DataFolder.Schema)
local SessionStore = require(DataFolder.SessionStore)

type PlayerData = Types.PlayerData

local log = Log.new("DataService")

type Profile = {
	Data: PlayerData,
	Key: string,
	CanSave: boolean,
	JoinedAt: number,
}

local DataService = {
	Priority = 1,
	Profiles = {} :: { [Player]: Profile },
	Loaded = Signal.new(),
	Releasing = Signal.new(),
	_pending = {} :: { [Player]: boolean },
	_hooks = {} :: { (Player, any) -> () },
	_store = nil :: any,
}

DataService.DeepCopy = Schema.DeepCopy

function DataService:Init()
	self._store = SessionStore.new(GameConfig.Data.StoreName)
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
				self:Save(player, true)
				remaining -= 1
			end)
		end
		local started = os.clock()
		while remaining > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
end

function DataService:Load(player: Player): PlayerData?
	local key = "Player_" .. player.UserId
	local stored, status = self._store:Load(key, function()
		return player.Parent ~= nil
	end)
	if not player.Parent then
		-- Left while loading: give the lock back.
		if status == "ok" then
			self._store:Save(key, stored, true)
		end
		return nil
	end
	local data = Schema.Prepare(stored)
	local canSave = status == "ok"
	self.Profiles[player] = { Data = data, Key = key, CanSave = canSave, JoinedAt = os.time() }
	if not canSave then
		log:Warn("saving disabled for", player.Name)
		task.delay(4, function()
			if player.Parent then
				Net.Notify(
					player,
					"⚠️ Saving is off right now. Your progress won't be saved.",
					Color3.fromRGB(255, 170, 60)
				)
			end
		end)
	end
	self.Loaded:Fire(player, data)
	return data
end

function DataService:Get(player: Player): PlayerData?
	local profile = self.Profiles[player]
	return profile and profile.Data
end

function DataService:IsLoaded(player: Player): boolean
	return self.Profiles[player] ~= nil
end

function DataService:Save(player: Player, release: boolean?)
	local profile = self.Profiles[player]
	if not profile or not profile.CanSave then
		return
	end
	local data = profile.Data
	data.Stats.PlayTime += os.time() - profile.JoinedAt
	profile.JoinedAt = os.time()
	data.LastOnline = os.time()
	local ok, lostLock = self._store:Save(profile.Key, data, release)
	if lostLock then
		-- Another server loaded this player (e.g. they joined somewhere else).
		-- Stop saving here so we never overwrite the newer data.
		profile.CanSave = false
		log:Warn("lost session lock for", player.Name)
		if player.Parent then
			player:Kick("Your data was opened on another server. Please rejoin.")
		end
	elseif not ok then
		log:Warn("save failed for", player.Name)
	end
end

function DataService:Release(player: Player)
	if not self.Profiles[player] then
		return
	end
	self.Releasing:Fire(player, self.Profiles[player].Data)
	self:Save(player, true)
	self.Profiles[player] = nil
	self._pending[player] = nil
end

function DataService:AddSnapshotHook(hook: (Player, any) -> ())
	table.insert(self._hooks, hook)
end

function DataService:BuildSnapshot(player: Player): Types.Snapshot
	local data = self:Get(player) :: PlayerData
	local snapshot: any = {
		Cash = data.Cash,
		Rebirths = data.Rebirths,
		Creatures = data.Creatures,
		Food = data.Food,
		Unlocks = data.Unlocks,
		IndexCount = CreatureMath.Count(data.Index),
		Slots = CreatureMath.MaxSlots(data.Rebirths),
		StorageCap = CreatureMath.StorageCap(data.Rebirths),
		RebirthCost = CreatureMath.RebirthCost(data.Rebirths),
		SelectedFood = player:GetAttribute("SelectedFood"),
	}
	for _, hook in self._hooks do
		local ok, err = pcall(hook, player, snapshot)
		if not ok then
			log:Error("snapshot hook failed:", err)
		end
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
			Net.Fire(player, "State", self:BuildSnapshot(player))
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	DataService._pending[player] = nil
end)

return DataService
