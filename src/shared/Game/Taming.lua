--!strict
--[[
	Taming: ARK-style knock-out taming math (pure, unit tested).

	1. Hit a wild titan with a club / tranq darts -> Torpor goes up.
	   Torpor slowly drains while it's awake.
	2. Torpor full -> it falls asleep for GameConfig.Tame.SleepTime seconds.
	3. Feed the sleeping titan -> the taming bar fills. Favorite food counts
	   double. Every player has their own bar: whoever fills theirs first
	   gets the titan (so others can "steal" your tame by feeding faster).
	4. Hitting it while asleep lowers taming effectiveness, which lowers
	   the bonus levels it gets when tamed.
]]

local Config = script.Parent.Parent.Config
local Creatures = require(Config.Creatures)
local GameConfig = require(Config.GameConfig)
local Rarities = require(Config.Rarities)
local CreatureMath = require(script.Parent.CreatureMath)

local TAME = GameConfig.Tame

local Taming = {}

type Creature = { Id: string, Level: number?, Size: number? }

local function rarityOf(id: string)
	return Rarities[Creatures[id].Rarity]
end

-- Bigger titans need more torpor (x1 = base, x1,000 = 2.8x, x100,000 = 4x).
function Taming.MaxTorpor(creature: Creature): number
	local size = CreatureMath.ClampSize(creature.Size)
	return math.floor(rarityOf(creature.Id).Torpor * (1 + math.log10(size) * 0.6))
end

-- Adds torpor. Returns the new value and true if it just fell asleep.
function Taming.AddTorpor(current: number, amount: number, max: number): (number, boolean)
	local new = math.clamp(current + math.max(0, amount), 0, max)
	return new, current < max and new >= max
end

-- Torpor drain while awake.
function Taming.Drain(current: number, max: number, dt: number): number
	return math.max(0, current - max * TAME.TorporDrain * dt)
end

-- Food points needed to tame a sleeping titan.
function Taming.FoodNeeded(creature: Creature): number
	local size = CreatureMath.ClampSize(creature.Size)
	return math.ceil(rarityOf(creature.Id).TameFood * TAME.FoodPerRarity * (1 + math.log10(size) * 0.5))
end

-- How many points one food is worth for this titan.
function Taming.FoodPoints(creatureId: string, foodId: string): number
	local def = Creatures[creatureId]
	if def and def.Diet and table.find(def.Diet, foodId) then
		return TAME.FavoritePoints
	end
	return 1
end

function Taming.Effectiveness(hitsWhileAsleep: number): number
	return math.max(TAME.MinEffectiveness, 1 - hitsWhileAsleep * TAME.DamageLoss)
end

-- Level the titan gets when tamed.
function Taming.TamedLevel(effectiveness: number): number
	return 1 + math.floor(effectiveness * TAME.MaxBonusLevels + 0.0001)
end

-- Per-player taming bars on one sleeping titan.
export type Progress = { Points: { [number]: number } }

function Taming.NewProgress(): Progress
	return { Points = {} }
end

-- Adds food points for a player. Returns true if that player finished taming.
function Taming.Feed(progress: Progress, userId: number, points: number, needed: number): boolean
	local total = (progress.Points[userId] or 0) + points
	progress.Points[userId] = total
	return total >= needed
end

-- The player closest to finishing (for the shared taming bar), and their points.
function Taming.Leader(progress: Progress): (number?, number)
	local bestId, best = nil, 0
	for userId, points in progress.Points do
		if points > best or (points == best and bestId ~= nil and userId < bestId) then
			bestId, best = userId, points
		end
	end
	return bestId, best
end

return Taming
