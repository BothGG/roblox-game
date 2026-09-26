--[[
	Progress: pure rules for the retention systems. Daily rewards, daily
	quests, offline earnings, Index milestones, codes, boosts and rewards.
	No Roblox objects, so every rule here is unit-tested.
]]

local Config = script.Parent.Parent.Config
local Boosts = require(Config.Boosts)
local Codes = require(Config.Codes)
local Creatures = require(Config.Creatures)
local DailyRewards = require(Config.DailyRewards)
local Foods = require(Config.Foods)
local GameConfig = require(Config.GameConfig)
local IndexConfig = require(Config.Index)
local Mutations = require(Config.Mutations)
local QuestConfig = require(Config.Quests)
local Format = require(script.Parent.Parent.Lib.Format)
local Rng = require(script.Parent.Parent.Lib.Rng)

local Progress = {}

local DAY = 86400

function Progress.Day(now: number): number
	return math.floor(now / DAY)
end

function Progress.SecondsUntilNextDay(now: number): number
	return DAY - (now % DAY)
end

--------------------------------------------------------------------------
-- Rewards
--------------------------------------------------------------------------

export type Reward = {
	Cash: number?,
	CashSeconds: number?, -- seconds of the player's income (scales with progress)
	Food: { [string]: number }?,
	Boost: { Id: string, Minutes: number }?,
	Trophies: number?,
}

-- Total cash for a reward. incomePerSecond has a floor so new players still get something.
function Progress.RewardCash(reward: Reward, incomePerSecond: number): number
	local cash = reward.Cash or 0
	if reward.CashSeconds then
		cash += reward.CashSeconds * math.max(incomePerSecond, 5)
	end
	return math.floor(cash)
end

function Progress.DescribeReward(reward: Reward, incomePerSecond: number?): string
	local parts = {}
	local cash = Progress.RewardCash(reward, incomePerSecond or 0)
	if cash > 0 then
		table.insert(parts, "💰 " .. Format.Money(cash))
	end
	if reward.Food then
		local ids = {}
		for id in reward.Food do
			table.insert(ids, id)
		end
		table.sort(ids)
		for _, id in ids do
			local def = Foods[id]
			table.insert(parts, string.format("🍖 %d %s", reward.Food[id], def and def.Name or id))
		end
	end
	if reward.Boost then
		local def = Boosts[reward.Boost.Id]
		table.insert(
			parts,
			string.format(
				"%s %s %dm",
				def and def.Icon or "⚡",
				def and def.Name or reward.Boost.Id,
				reward.Boost.Minutes
			)
		)
	end
	if reward.Trophies then
		table.insert(parts, "🏆 " .. reward.Trophies)
	end
	return table.concat(parts, "  ")
end

--------------------------------------------------------------------------
-- Boosts
--------------------------------------------------------------------------

-- Multiplier from active boosts of a kind ("Income", "Growth", "Luck").
function Progress.BoostMult(active: { [string]: number }, kind: string, now: number): number
	local mult = 1
	for id, expiresAt in active do
		local def = Boosts[id]
		if def and def.Kind == kind and expiresAt > now then
			mult *= def.Mult
		end
	end
	return mult
end

-- Adds time to a boost (stacks on top of remaining time).
function Progress.AddBoost(active: { [string]: number }, id: string, minutes: number, now: number): number
	local current = active[id] or 0
	local expiresAt = math.max(current, now) + minutes * 60
	active[id] = expiresAt
	return expiresAt
end

function Progress.CleanBoosts(active: { [string]: number }, now: number)
	for id, expiresAt in active do
		if expiresAt <= now then
			active[id] = nil
		end
	end
end

--------------------------------------------------------------------------
-- Daily rewards
--------------------------------------------------------------------------

export type Daily = { Streak: number, LastDay: number }

-- Returns (canClaim, dayIndex 1..7 that would be claimed / was claimed today).
function Progress.DailyStatus(daily: Daily, today: number): (boolean, number)
	if daily.LastDay == today then
		return false, math.max(1, daily.Streak)
	end
	if daily.LastDay == today - 1 then
		return true, daily.Streak % #DailyRewards + 1
	end
	return true, 1
end

-- Claims today's reward. Returns the day index claimed, or nil if already claimed.
function Progress.ClaimDaily(daily: Daily, today: number): number?
	local canClaim, index = Progress.DailyStatus(daily, today)
	if not canClaim then
		return nil
	end
	daily.Streak = index
	daily.LastDay = today
	return index
end

--------------------------------------------------------------------------
-- Daily quests
--------------------------------------------------------------------------

export type Quest = { Id: string, Goal: number, Progress: number, Claimed: boolean }
export type QuestState = { Day: number, List: { Quest } }

local poolById = {}
for _, def in QuestConfig.Pool do
	poolById[def.Id] = def
end
Progress.QuestDefs = poolById

-- Same quests for the same player + day, on any server.
function Progress.GenerateQuests(day: number, userId: number, rebirths: number): { Quest }
	local rng = Rng.new(day * 7919 + userId)
	local pool = table.clone(QuestConfig.Pool)
	local list = {}
	for _ = 1, math.min(QuestConfig.PerDay, #pool) do
		local def = table.remove(pool, rng:NextInteger(1, #pool))
		local goal = rng:NextInteger(def.Goal[1], def.Goal[2])
		if def.ScaleWithRebirth then
			goal *= 1 + rebirths
		end
		table.insert(list, { Id = def.Id, Goal = goal, Progress = 0, Claimed = false })
	end
	return list
end

-- Makes sure the quest list is today's. Returns true if it was reset.
function Progress.EnsureQuests(state: QuestState, today: number, userId: number, rebirths: number): boolean
	if state.Day == today and #state.List > 0 then
		return false
	end
	state.Day = today
	state.List = Progress.GenerateQuests(today, userId, rebirths)
	return true
end

-- Counts an event towards matching quests. Returns the quests that just got completed.
function Progress.QuestEvent(state: QuestState, event: string, payload: { [string]: any }?): { Quest }
	local completed = {}
	for _, quest in state.List do
		local def = poolById[quest.Id]
		if def and def.Event == event and quest.Progress < quest.Goal then
			local amount = 1
			if def.Field and payload and type(payload[def.Field]) == "number" then
				amount = payload[def.Field]
			end
			quest.Progress = math.min(quest.Goal, quest.Progress + amount)
			if quest.Progress >= quest.Goal then
				table.insert(completed, quest)
			end
		end
	end
	return completed
end

function Progress.QuestText(quest: Quest): string
	local def = poolById[quest.Id]
	if not def then
		return quest.Id
	end
	local goal = if string.find(def.Text, "%%s") then Format.Number(quest.Goal) else quest.Goal
	return string.format(def.Text, goal)
end

--------------------------------------------------------------------------
-- Offline earnings
--------------------------------------------------------------------------

function Progress.OfflineEarnings(incomePerSecond: number, secondsAway: number, rate: number): number
	local cfg = GameConfig.Offline
	if secondsAway < cfg.MinSeconds or incomePerSecond <= 0 then
		return 0
	end
	return math.floor(incomePerSecond * math.min(secondsAway, cfg.MaxSeconds) * rate)
end

--------------------------------------------------------------------------
-- Index
--------------------------------------------------------------------------

function Progress.IndexTotal(): number
	local species, mutations = 0, 0
	for _ in Creatures do
		species += 1
	end
	for _, def in Mutations do
		if type(def) == "table" and def.Id then
			mutations += 1
		end
	end
	return species * (1 + mutations)
end

function Progress.IndexCount(index: { [string]: boolean }): number
	local n = 0
	for _ in index do
		n += 1
	end
	return n
end

-- Milestone indices that can be claimed right now.
function Progress.ClaimableMilestones(index: { [string]: boolean }, claimed: { [string]: boolean }): { number }
	local count = Progress.IndexCount(index)
	local list = {}
	for i, milestone in IndexConfig.Milestones do
		if count >= milestone.Count and not claimed[tostring(i)] then
			table.insert(list, i)
		end
	end
	return list
end

--------------------------------------------------------------------------
-- Codes
--------------------------------------------------------------------------

function Progress.NormalizeCode(code: string): string
	return string.upper((string.gsub(code, "%s", "")))
end

-- Returns (ok, reason or nil, code def)
function Progress.CanRedeem(used: { [string]: boolean }, code: string, now: number): (boolean, string?, any)
	local key = Progress.NormalizeCode(code)
	local def = Codes[key]
	if not def then
		return false, "That code doesn't exist", nil
	end
	if used[key] then
		return false, "You already used this code", nil
	end
	if def.Expires and now > def.Expires then
		return false, "This code has expired", nil
	end
	return true, nil, def
end

return Progress
