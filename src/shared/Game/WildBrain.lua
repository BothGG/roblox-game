--!strict
--[[
	WildBrain: what a wild titan does next (pure, unit tested).
	WildService calls Decide() a few times per second and then moves the
	titan for the chosen state.

	States
	  Idle    stand around            Graze  eat grass (stands, head down)
	  Wander  walk near its home      Flee   run away after being hit (Passive)
	  Chase   run at a player         Attack hit the player in range
	  Return  walk back home          Asleep knocked out (torpor full)
]]

local GameConfig = require(script.Parent.Parent.Config.GameConfig)

local WILD = GameConfig.Wild

export type State = "Idle" | "Graze" | "Wander" | "Flee" | "Chase" | "Attack" | "Return" | "Asleep"
export type Temper = "Passive" | "Aggressive"

export type Input = {
	State: State,
	StateSince: number, -- when the current state started
	StateDuration: number, -- how long a timed state (Idle/Graze/Wander) lasts
	Now: number,
	Temper: Temper,
	Asleep: boolean,
	LastHitAt: number?, -- when it was last hit (nil = never)
	TargetDistance: number, -- distance to the nearest player (math.huge = none)
	HomeDistance: number,
	Reach: number, -- attack range for this titan (AttackRange + size)
	Roll: number, -- random 0..1 (passed in so tests are repeatable)
}

local WildBrain = {}

local CALM: { [string]: boolean } = { Idle = true, Graze = true, Wander = true }

-- How long a calm state lasts (seconds), from a 0..1 roll.
function WildBrain.DurationFor(state: State, roll: number): number
	if state == "Idle" then
		return 2 + roll * 3
	elseif state == "Graze" then
		return 4 + roll * 4
	elseif state == "Wander" then
		return 5 + roll * 4
	end
	return 0
end

-- The next calm state, picked by a 0..1 roll.
function WildBrain.NextCalm(roll: number): State
	if roll < 0.45 then
		return "Wander"
	elseif roll < 0.75 then
		return "Graze"
	end
	return "Idle"
end

function WildBrain.Decide(i: Input): State
	if i.Asleep then
		return "Asleep"
	end
	if i.State == "Asleep" then
		return "Idle" -- just woke up
	end
	local recentlyHit = i.LastHitAt ~= nil and i.Now - i.LastHitAt < WILD.FleeTime
	local tooFar = i.HomeDistance > WILD.LeashRange

	if i.Temper == "Passive" then
		if recentlyHit then
			return "Flee"
		end
		if i.State == "Flee" then
			return "Idle"
		end
	else
		local hunting = recentlyHit or i.TargetDistance <= WILD.AggroRange
		if hunting and not tooFar and i.TargetDistance < math.huge then
			return if i.TargetDistance <= i.Reach then "Attack" else "Chase"
		end
		if i.State == "Chase" or i.State == "Attack" then
			return "Return" -- lost the player or went too far
		end
	end

	if i.State == "Return" then
		return if i.HomeDistance < 8 then "Idle" else "Return"
	end
	if tooFar then
		return "Return"
	end
	if not CALM[i.State] or i.Now - i.StateSince >= i.StateDuration then
		return WildBrain.NextCalm(i.Roll)
	end
	return i.State
end

-- Size roll for a new wild titan from a 0..1 roll (GameConfig.Wild.SizeRolls).
function WildBrain.RollSize(roll: number, roll2: number): number
	local acc = 0
	for _, entry in WILD.SizeRolls do
		acc += entry[1]
		if roll <= acc then
			-- log-uniform inside the band so small sizes are more common
			local lo, hi = math.log10(entry[2]), math.log10(entry[3])
			return math.floor(10 ^ (lo + (hi - lo) * roll2) * 10 + 0.5) / 10
		end
	end
	return 1
end

return WildBrain
