--!strict
--[[
	Battle: pure battle math (stats, specials, damage, hit tests, results).
	The server uses it to decide every hit; the client uses it to show stats.
	No Roblox objects here, so it's fully unit-tested.
]]

local Config = script.Parent.Parent.Config
local Creatures = require(Config.Creatures)
local GameConfig = require(Config.GameConfig)
local Mutations = require(Config.Mutations)
local Types = require(script.Parent.Parent.Types)
local CreatureMath = require(script.Parent.CreatureMath)

type CreatureData = Types.CreatureData

local BATTLE = GameConfig.Battle

local Battle = {}

export type Stats = {
	MaxHP: number,
	Attack: number,
	Speed: number,
	Scale: number,
	Range: number,
}

export type Special = {
	Id: string,
	Name: string,
	Mult: number,
	Cooldown: number,
	Shape: "Around" | "Cone" | "Dash",
	RangeMult: number,
	Delay: number,
}

-- Special move per body style.
Battle.Specials = {
	Biped = {
		Id = "Slam",
		Name = "Ground Slam",
		Mult = 1.6,
		Cooldown = 6,
		Shape = "Around",
		RangeMult = 1.5,
		Delay = 0.3,
	},
	Quad = { Id = "Charge", Name = "Charge", Mult = 1.8, Cooldown = 7, Shape = "Dash", RangeMult = 1.2, Delay = 0.35 },
	Blob = { Id = "Bounce", Name = "Bounce", Mult = 1.7, Cooldown = 6, Shape = "Around", RangeMult = 1.4, Delay = 0.6 },
	Winged = {
		Id = "Breath",
		Name = "Fire Breath",
		Mult = 1.4,
		Cooldown = 6,
		Shape = "Cone",
		RangeMult = 2.2,
		Delay = 0.2,
	},
} :: { [string]: Special }

function Battle.Stats(creature: CreatureData): Stats
	local def = Creatures[creature.Id]
	local base = def and def.Stats or { HP = 100, Attack = 10, Speed = 1 }
	local mutation = creature.Mutation and Mutations[creature.Mutation]
	local mult = mutation and mutation.StatMult or 1
	local scale = CreatureMath.VisualScale(creature)
	mult *= 1 + ((creature :: any).Bonus or 0) -- bred titans inherit a stat bonus
	return {
		MaxHP = math.floor(base.HP * (1 + (creature.Level - 1) * 0.12) * mult),
		Attack = math.floor(base.Attack * (1 + (creature.Level - 1) * 0.10) * mult),
		Speed = math.min(BATTLE.MaxSpeed, 16 * base.Speed * (1 + math.min(scale, 8) * 0.04)),
		Scale = scale,
		Range = BATTLE.AttackRange + scale * 1.6,
	}
end

function Battle.SpecialFor(creatureId: string): Special
	local def = Creatures[creatureId]
	return Battle.Specials[def and def.Style or "Biped"] or Battle.Specials.Biped
end

-- Damage for one hit. roll (0..1) adds +-10% variety; pass 0.5 for exact.
function Battle.Damage(attack: number, mult: number, roll: number): number
	return math.max(1, math.floor(attack * mult * (0.9 + roll * 0.2)))
end

export type Point = { X: number, Z: number }

-- Is target inside the attack? Positions are flat (X, Z). look = facing direction.
function Battle.InCone(attacker: Point, look: Point, target: Point, range: number, minDot: number): boolean
	local dx, dz = target.X - attacker.X, target.Z - attacker.Z
	local dist = math.sqrt(dx * dx + dz * dz)
	if dist > range then
		return false
	end
	if dist < 0.001 then
		return true
	end
	local lookLen = math.sqrt(look.X * look.X + look.Z * look.Z)
	if lookLen < 0.001 then
		return true
	end
	local dot = (dx * look.X + dz * look.Z) / (dist * lookLen)
	return dot >= minDot
end

function Battle.InRadius(center: Point, target: Point, radius: number): boolean
	local dx, dz = target.X - center.X, target.Z - center.Z
	return dx * dx + dz * dz <= radius * radius
end

-- Hit test for a basic attack or special. targetSize widens the hit a bit
-- so giant titans are easier to hit.
function Battle.Hits(
	kind: "Attack" | "Special",
	special: Special?,
	attacker: Point,
	look: Point,
	target: Point,
	range: number,
	targetScale: number
): boolean
	local reach = range + targetScale * 1.2
	if kind == "Attack" or not special then
		return Battle.InCone(attacker, look, target, reach, 0.3)
	end
	if special.Shape == "Around" then
		return Battle.InRadius(attacker, target, reach * special.RangeMult)
	elseif special.Shape == "Cone" then
		return Battle.InCone(attacker, look, target, reach * special.RangeMult, 0.55)
	end
	-- Dash: checked after the dash, in front of the new position
	return Battle.InCone(attacker, look, target, reach * special.RangeMult, 0.1)
end

export type Fighter = { UserId: number, HP: number, MaxHP: number }

-- Winner when time runs out (or everyone else is KO): highest HP %.
-- Returns nil on an exact tie.
function Battle.Leader(fighters: { Fighter }): Fighter?
	local best, bestRatio, tie = nil, -1, false
	for _, f in fighters do
		local ratio = if f.MaxHP > 0 then f.HP / f.MaxHP else 0
		if ratio > bestRatio then
			best, bestRatio, tie = f, ratio, false
		elseif ratio == bestRatio then
			tie = true
		end
	end
	if tie then
		return nil
	end
	return best
end

function Battle.Alive(fighters: { Fighter }): { Fighter }
	local alive = {}
	for _, f in fighters do
		if f.HP > 0 then
			table.insert(alive, f)
		end
	end
	return alive
end

-- Food the winner takes from the loser: `share` of each food (rounded down).
-- If that rounds to nothing but the loser has food, take 1 of their most common.
function Battle.FoodShare(food: { [string]: number }, share: number): { [string]: number }
	local taken = {}
	local total = 0
	local mostId, mostCount = nil, 0
	for id, count in food do
		local amount = math.floor(count * share)
		if amount > 0 then
			taken[id] = amount
			total += amount
		end
		if count > mostCount then
			mostId, mostCount = id, count
		end
	end
	if total == 0 and mostId then
		taken[mostId] = 1
	end
	return taken
end

function Battle.TrophiesAfterLoss(trophies: number): number
	return math.max(0, trophies - BATTLE.LoseTrophies)
end

return Battle
