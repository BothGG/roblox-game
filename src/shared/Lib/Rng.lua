--!strict
--[[
	Rng: a small deterministic random generator (same seed = same numbers,
	on every server and in tests). Used for daily quests so a player sees the
	same quests all day on any server.

	  local rng = Rng.new(12345)
	  rng:NextNumber()        -- 0..1
	  rng:NextInteger(1, 6)   -- 1..6
]]

local MOD = 2147483647 -- 2^31 - 1 (Park-Miller)
local MULT = 48271

export type Rng = {
	NextNumber: (self: Rng) -> number,
	NextInteger: (self: Rng, min: number, max: number) -> number,
}

local Rng = {}
Rng.__index = Rng

function Rng.new(seed: number): Rng
	local state = math.floor(math.abs(seed)) % (MOD - 1) + 1
	return (setmetatable({ _state = state }, Rng) :: any) :: Rng
end

function Rng.NextNumber(self: any): number
	self._state = (self._state * MULT) % MOD
	return (self._state - 1) / (MOD - 1)
end

function Rng.NextInteger(self: any, min: number, max: number): number
	local span = max - min
	return min + math.min(span, math.floor(Rng.NextNumber(self) * (span + 1)))
end

return Rng
