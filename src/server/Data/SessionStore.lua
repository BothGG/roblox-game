--[[
	SessionStore: DataStore wrapper with SESSION LOCKING.

	Why: if a player hops servers quickly, two servers could load the same
	save at once and overwrite each other (lost progress or duplicated
	items). The lock makes sure only one server owns a save at a time.

	Stored format: { Data = <player data>, Lock = { JobId, Time } }

	  local store = SessionStore.new("MyStore")
	  local data, status = store:Load(key)        -- status: "ok" | "failed"
	  local ok, lostLock = store:Save(key, data)
	  store:Save(key, data, true)                  -- final save + release lock
]]

local DataStoreService = game:GetService("DataStoreService")

local Log = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Lib.Log)

local log = Log.new("SessionStore")

local LOCK_EXPIRE = 30 * 60 -- a lock not refreshed for 30 min is from a crashed server
local LOCKED_RETRIES = 6 -- wait for the other server this many times...
local LOCKED_RETRY_DELAY = 5 -- ...this many seconds apart, then take the lock
local ERROR_RETRIES = 3

local SessionStore = {}
SessionStore.__index = SessionStore

function SessionStore.new(name: string)
	local self = setmetatable({}, SessionStore)
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(name)
	end)
	if ok then
		self._store = result
	else
		log:Warn("DataStore unavailable, saving disabled:", result)
	end
	self._jobId = game.JobId
	return self
end

function SessionStore:IsAvailable(): boolean
	return self._store ~= nil
end

local function isLockedByOther(lock, jobId: string): boolean
	return lock ~= nil and lock.JobId ~= jobId and os.time() - (lock.Time or 0) < LOCK_EXPIRE
end

-- Returns (data, "ok") or (nil, "failed").
function SessionStore:Load(key: string, isStillWanted: () -> boolean)
	if not self._store then
		return nil, "failed"
	end
	local lockedAttempts = 0
	local errorAttempts = 0
	while isStillWanted() do
		local loaded, data, locked = false, nil, false
		local forceTake = lockedAttempts >= LOCKED_RETRIES
		local ok, err = pcall(self._store.UpdateAsync, self._store, key, function(stored)
			stored = if type(stored) == "table" then stored else {}
			-- Saves from before session locking stored the data directly.
			if stored.Data == nil and stored.Version ~= nil then
				stored = { Data = stored }
			end
			if isLockedByOther(stored.Lock, self._jobId) and not forceTake then
				locked = true
				return nil -- cancel the write
			end
			stored.Lock = { JobId = self._jobId, Time = os.time() }
			data = stored.Data
			loaded = true
			return stored
		end)
		if ok and loaded then
			if forceTake then
				log:Warn("took session lock for", key, "from an unresponsive server")
			end
			return data, "ok"
		elseif ok and locked then
			lockedAttempts += 1
			log:Info(key, "is open on another server, waiting...", lockedAttempts)
			task.wait(LOCKED_RETRY_DELAY)
		else
			errorAttempts += 1
			log:Warn("load error for", key, err)
			if errorAttempts >= ERROR_RETRIES then
				return nil, "failed"
			end
			task.wait(errorAttempts * 2)
		end
	end
	return nil, "failed"
end

-- Returns (saved, lostLock). lostLock = another server took this save.
function SessionStore:Save(key: string, data: any, release: boolean?): (boolean, boolean)
	if not self._store then
		return false, false
	end
	for attempt = 1, ERROR_RETRIES do
		local lost = false
		local ok, err = pcall(self._store.UpdateAsync, self._store, key, function(stored)
			stored = if type(stored) == "table" then stored else {}
			if stored.Lock and stored.Lock.JobId ~= self._jobId then
				lost = true
				return nil
			end
			stored.Data = data
			stored.Lock = if release then nil else { JobId = self._jobId, Time = os.time() }
			return stored
		end)
		if ok then
			return not lost, lost
		end
		log:Warn("save error for", key, "attempt", attempt, err)
		task.wait(attempt)
	end
	return false, false
end

return SessionStore
