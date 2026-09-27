--[[
	FusionService: fuse 3 titans of the same species and size tier into one
	titan of the next size tier (x1 -> x3 -> x10 ... -> x100,000).

	The new titan keeps the best of the three: highest level, best stat
	bonus, and a mutation if any of them had one. Costs cash
	(Breeding.FuseCost: rarer and bigger = more).
	Remote "Fuse" uidA uidB uidC (from the 💞 Breed page, Fuse tab).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Breeding = require(Shared.Game.Breeding)
local CreatureMath = require(Shared.Game.CreatureMath)
local Format = require(Shared.Lib.Format)
local Log = require(Shared.Lib.Log)
local Net = require(Shared.Net)

local log = Log.new("FusionService")

local RED = Color3.fromRGB(255, 90, 90)

local FusionService = {
	Priority = 34,
}

local Data, Creature, Breed, Ride, Follower, Fx

function FusionService:Init(registry)
	Data = registry.DataService
	Creature = registry.CreatureService
	Breed = registry.BreedingService
	Ride = registry.RideService
	Follower = registry.FollowerService
	Fx = registry.FxService
end

function FusionService:Start()
	Net.On("Fuse", function(player, a, b, c)
		self:Fuse(player, { a, b, c })
	end)
end

function FusionService:Fuse(player: Player, uids: { string })
	local data = Data:Get(player)
	if not data then
		return
	end
	if uids[1] == uids[2] or uids[1] == uids[3] or uids[2] == uids[3] then
		Net.Notify(player, "🔮 Pick 3 different titans", RED)
		return
	end
	local parts = {}
	for _, uid in uids do
		local creature = data.Creatures[uid]
		if not creature then
			return
		end
		if Breed:IsBreeding(player, uid) then
			Net.Notify(player, "🔮 A titan you picked is breeding!", RED)
			return
		end
		table.insert(parts, { Id = creature.Id, Size = creature.Size, Mutation = creature.Mutation })
	end
	local newSize, reason = Breeding.FuseResult(parts)
	if not newSize then
		Net.Notify(player, "🔮 " .. (reason or "Can't fuse"), RED)
		return
	end
	local species = parts[1].Id
	local cost = Breeding.FuseCost(species, parts[1].Size or 1)
	if data.Cash < cost then
		Net.Notify(player, "🔮 Fusing costs " .. Format.Money(cost) .. "!", RED)
		return
	end

	-- The best of the three
	local level, bonus, mutation = 1, 0, nil
	for _, uid in uids do
		local creature = data.Creatures[uid]
		level = math.max(level, creature.Level)
		bonus = math.max(bonus, creature.Bonus or 0)
		mutation = mutation or creature.Mutation
	end
	local wasActive = table.find(uids, data.Active or "") ~= nil
	local where = Creature:GetModel(player, uids[1])
	local at = where and where:GetPivot().Position

	-- Take them out of the world first (riding / following)
	local ride = Ride:Get(player)
	if ride and table.find(uids, ride.Uid) then
		Ride:Dismount(player)
	end
	for _, uid in uids do
		Follower:Release(player, uid, true)
	end

	data.Cash -= cost
	for _, uid in uids do
		Creature:Remove(player, uid)
	end
	local newUid = Creature:Add(player, species, mutation, newSize)
	if not newUid then
		-- Can't happen (we just freed 3 pens), but never lose the cash.
		data.Cash += cost
		log:Warn("fusion failed to add for", player.Name)
		return
	end
	Creature:SetLevel(player, newUid, level)
	data.Creatures[newUid].Bonus = bonus
	if wasActive then
		data.Active = newUid
	end
	Creature:RefreshAllTags(player)

	local def = Creatures[species]
	local color = if mutation then Mutations[mutation].Color else Rarities[def.Rarity].Color
	local model = Creature:GetModel(player, newUid)
	if model then
		at = model:GetPivot().Position
	end
	if at then
		Fx:PlayAll("Mutation", { Position = at, Color = color })
		Fx:PlayAll("LevelUp", { Position = at + Vector3.new(0, 4, 0), Level = level, Owner = player.UserId })
	end
	local name = CreatureMath.DisplayName({ Id = species, Level = level, Xp = 0, Mutation = mutation, Size = newSize })
	Net.Fire(player, "Hatched", { CreatureId = species, Mutation = mutation, Source = "Fuse", Size = newSize })
	if Breeding.ShouldAnnounce(newSize) then
		Net.Announce("🔮 MEGA FUSION!", player.DisplayName .. " fused a " .. name .. "!", color)
	end
	log:Info(player.Name, "fused", name)
	Data:Changed(player)
end

return FusionService
