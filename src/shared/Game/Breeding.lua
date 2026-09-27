--!strict
--[[
	Breeding: eggs, breeding, hatching, carrying and fusion math (pure, tested).

	Size tiers come from Config/Sizes.lua. Eggs always have a tier's size
	(x1, x3, x10 ... x100,000). Bigger eggs hatch slower and are carried
	slower, so a Mythical egg is a slow, risky run home.
]]

local Config = script.Parent.Parent.Config
local Creatures = require(Config.Creatures)
local GameConfig = require(Config.GameConfig)
local Sizes = require(Config.Sizes)
local CreatureMath = require(script.Parent.CreatureMath)

local BREED = GameConfig.Breeding

local Breeding = {}

export type Parent = { Id: string, Mutation: string?, Size: number?, Bonus: number?, BreedReadyAt: number? }
export type EggData = {
	Uid: string,
	Species: string,
	Mutation: string?,
	Size: number,
	Bonus: number,
	Source: string, -- "Breed" | "Nest" | "Stolen"
	Slot: number?, -- incubator index, nil = waiting in egg storage
	StartedAt: number?,
	HatchAt: number?,
}
export type Rolls = {
	Mutation: number, -- 0..1
	PickParent: number, -- 0..1
	Bonus: number, -- 0..1
	Size: number, -- 0..1
	Jump: number, -- 0..1
	PoolMutation: string?, -- a random mutation from the hatch pool (server picks it)
}

-- Size tiers --------------------------------------------------------------

function Breeding.TierIndex(size: number?): number
	local n = CreatureMath.ClampSize(size)
	local index = 1
	for i, tier in Sizes.Tiers do
		if n >= tier.Min then
			index = i
		end
	end
	return index
end

function Breeding.TierSize(index: number): number
	local i = math.clamp(index, 1, #Sizes.Tiers)
	return Sizes.Tiers[i].Min
end

local function tierByName(name: string): number
	for i, tier in Sizes.Tiers do
		if tier.Id == name then
			return i
		end
	end
	return #Sizes.Tiers + 1
end

function Breeding.ShouldAnnounce(size: number): boolean
	return Breeding.TierIndex(size) >= tierByName(BREED.AnnounceTier)
end

function Breeding.HasBeam(size: number): boolean
	return Breeding.TierIndex(size) >= tierByName(BREED.BeamTier)
end

-- Breeding ----------------------------------------------------------------

function Breeding.Time(species: string): number
	return BREED.Time[Creatures[species].Rarity] or 120
end

function Breeding.CanBreed(a: Parent?, b: Parent?, now: number): (boolean, string?)
	if not a or not b then
		return false, "Pick two titans"
	end
	if a == b then
		return false, "Pick two different titans"
	end
	if a.Id ~= b.Id then
		return false, "Both parents must be the same species"
	end
	if (a.BreedReadyAt or 0) > now or (b.BreedReadyAt or 0) > now then
		return false, "A parent is still resting"
	end
	return true, nil
end

-- The egg two parents make. Rolls are random 0..1 numbers (passed in so
-- tests are repeatable).
function Breeding.MakeEgg(
	a: Parent,
	b: Parent,
	rolls: Rolls
): { Species: string, Mutation: string?, Size: number, Bonus: number }
	-- Mutation
	local mutation: string? = nil
	if a.Mutation and b.Mutation then
		if rolls.Mutation < BREED.BothMutatedChance then
			mutation = if rolls.PickParent < 0.5 then a.Mutation else b.Mutation
		end
	elseif a.Mutation or b.Mutation then
		if rolls.Mutation < BREED.OneMutatedChance then
			mutation = a.Mutation or b.Mutation
		end
	elseif rolls.Mutation < BREED.MutationChance then
		mutation = rolls.PoolMutation
	end
	-- Stat bonus: parents' average + a small random change
	local average = ((a.Bonus or 0) + (b.Bonus or 0)) / 2
	local lo, hi = BREED.BonusRange[1], BREED.BonusRange[2]
	local bonus = math.clamp(average + lo + (hi - lo) * rolls.Bonus, 0, BREED.MaxBonus)
	-- Size: a tier between the parents' tiers, rarely one tier higher
	local ta, tb = Breeding.TierIndex(a.Size), Breeding.TierIndex(b.Size)
	local low, high = math.min(ta, tb), math.max(ta, tb)
	local index = low + math.floor(rolls.Size * (high - low + 1))
	index = math.min(index, high)
	if rolls.Jump < BREED.TierJumpChance then
		index += 1
	end
	return {
		Species = a.Id,
		Mutation = mutation,
		Size = Breeding.TierSize(index),
		Bonus = math.floor(bonus * 1000 + 0.5) / 1000,
	}
end

function Breeding.Cooldown(species: string): number
	return Breeding.Time(species) * BREED.CooldownMult
end

-- Hatching ----------------------------------------------------------------

function Breeding.HatchTime(species: string, size: number, speedLevel: number?): number
	local base = BREED.HatchTime[Creatures[species].Rarity] or 60
	local tierMult = 1 + (Breeding.TierIndex(size) - 1) * BREED.HatchPerTier
	return math.ceil(base * tierMult / (1 + (speedLevel or 0) * BREED.IncubatorSpeedPerLevel))
end

-- 0..1 progress of an egg in an incubator.
function Breeding.HatchProgress(egg: EggData, now: number): number
	if not egg.StartedAt or not egg.HatchAt then
		return 0
	end
	local total = egg.HatchAt - egg.StartedAt
	if total <= 0 then
		return 1
	end
	return math.clamp((now - egg.StartedAt) / total, 0, 1)
end

function Breeding.IncubatorCount(level: number): number
	return 1 + level
end

-- Carrying ----------------------------------------------------------------

function Breeding.CarrySpeed(size: number): number
	local penalty = (Breeding.TierIndex(size) - 1) * BREED.CarryPenaltyPerTier
	return math.max(BREED.MinCarrySpeed, BREED.CarrySpeed * (1 - penalty))
end

-- Fusion ------------------------------------------------------------------

-- 3 titans of the same species AND the same size tier fuse into one of the
-- next tier. Returns the new size, or nil and a reason.
function Breeding.FuseResult(parts: { Parent }): (number?, string?)
	if #parts ~= 3 then
		return nil, "Pick 3 titans"
	end
	local species = parts[1].Id
	local tier = Breeding.TierIndex(parts[1].Size)
	for _, p in parts do
		if p.Id ~= species then
			return nil, "All 3 must be the same species"
		end
		if Breeding.TierIndex(p.Size) ~= tier then
			return nil, "All 3 must be the same size tier"
		end
	end
	if tier >= #Sizes.Tiers then
		return nil, "Already the biggest size"
	end
	return Breeding.TierSize(tier + 1), nil
end

return Breeding
