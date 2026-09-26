--[[
	Log: tagged logging with levels.

	  local log = Log.new("FoodService")
	  log:Debug("spawned", foodId)   -- only shown when Log.Level = "Debug"
	  log:Info("started")
	  log:Warn("storage full for", player.Name)
]]

local LEVELS = { Debug = 1, Info = 2, Warn = 3, Error = 4 }

local Log = {}
Log.__index = Log

-- Change to "Debug" while developing to see everything.
Log.Level = "Info"

export type Logger = {
	Tag: string,
	Debug: (self: Logger, ...any) -> (),
	Info: (self: Logger, ...any) -> (),
	Warn: (self: Logger, ...any) -> (),
	Error: (self: Logger, ...any) -> (),
}

function Log.new(tag: string): Logger
	return (setmetatable({ Tag = tag }, Log) :: any) :: Logger
end

local function enabled(level: string): boolean
	return LEVELS[level] >= (LEVELS[Log.Level] or 2)
end

function Log:Debug(...)
	if enabled("Debug") then
		print("[" .. self.Tag .. "]", ...)
	end
end

function Log:Info(...)
	if enabled("Info") then
		print("[" .. self.Tag .. "]", ...)
	end
end

function Log:Warn(...)
	if enabled("Warn") then
		warn("[" .. self.Tag .. "]", ...)
	end
end

-- Errors are reported but never thrown, so one broken system can't crash the rest.
function Log:Error(...)
	warn("[" .. self.Tag .. "] ERROR:", ...)
end

return Log
