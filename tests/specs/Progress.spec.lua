return function(t)
	local Progress = t.require(t.Shared.Game.Progress)
	local Rng = t.require(t.Shared.Lib.Rng)
	local QuestConfig = t.require(t.Shared.Config.Quests)
	local GameConfig = t.require(t.Shared.Config.GameConfig)

	t.test("Rng is deterministic and in range", function()
		local a, b = Rng.new(42), Rng.new(42)
		for _ = 1, 200 do
			local x = a:NextInteger(1, 6)
			t.expect(x).toBe(b:NextInteger(1, 6))
			t.expect(x >= 1 and x <= 6).toBe(true)
			local n = a:NextNumber()
			b:NextNumber()
			t.expect(n >= 0 and n <= 1).toBe(true)
		end
	end)

	t.test("daily streak: claim, same day, next day, missed day, wrap after 7", function()
		local daily = { Streak = 0, LastDay = -1 }
		t.expect(Progress.ClaimDaily(daily, 100)).toBe(1)
		t.expect(Progress.ClaimDaily(daily, 100)).toBe(nil) -- already claimed today
		t.expect(Progress.ClaimDaily(daily, 101)).toBe(2)
		t.expect(Progress.ClaimDaily(daily, 103)).toBe(1) -- missed a day -> reset
		for day = 104, 109 do
			Progress.ClaimDaily(daily, day)
		end
		t.expect(daily.Streak).toBe(7)
		t.expect(Progress.ClaimDaily(daily, 110)).toBe(1) -- starts over after day 7
	end)

	t.test("quests are the same all day for a player and different per player", function()
		local a1 = Progress.GenerateQuests(500, 111, 0)
		local a2 = Progress.GenerateQuests(500, 111, 0)
		t.expect(#a1).toBe(QuestConfig.PerDay)
		for i = 1, #a1 do
			t.expect(a1[i].Id).toBe(a2[i].Id)
			t.expect(a1[i].Goal).toBe(a2[i].Goal)
		end
		local seen = {}
		for _, q in a1 do
			t.expect(seen[q.Id]).toBe(nil) -- no duplicates
			seen[q.Id] = true
		end
	end)

	t.test("quests reset on a new day and count events", function()
		local state = { Day = -1, List = {} }
		t.expect(Progress.EnsureQuests(state, 10, 1, 0)).toBe(true)
		t.expect(Progress.EnsureQuests(state, 10, 1, 0)).toBe(false)
		state.List = {
			{ Id = "Feed", Goal = 2, Progress = 0, Claimed = false },
			{ Id = "Pick", Goal = 10, Progress = 0, Claimed = false },
		}
		t.expect(#Progress.QuestEvent(state, "Fed", {})).toBe(0)
		local done = Progress.QuestEvent(state, "Fed", {})
		t.expect(#done).toBe(1)
		t.expect(state.List[1].Progress).toBe(2)
		Progress.QuestEvent(state, "Fed", {}) -- can't go past the goal
		t.expect(state.List[1].Progress).toBe(2)
		Progress.QuestEvent(state, "FoodPicked", { Amount = 4 }) -- Field = Amount
		t.expect(state.List[2].Progress).toBe(4)
		t.expect(Progress.QuestText(state.List[1])).toBe("Feed your titans 2 times")
	end)

	t.test("offline earnings: minimum time, rate and cap", function()
		t.expect(Progress.OfflineEarnings(10, 30, 0.25)).toBe(0)
		t.expect(Progress.OfflineEarnings(10, 1000, 0.25)).toBe(2500)
		local capped = Progress.OfflineEarnings(10, 1e9, 0.25)
		t.expect(capped).toBe(math.floor(10 * GameConfig.Offline.MaxSeconds * 0.25))
		t.expect(Progress.OfflineEarnings(0, 1000, 0.25)).toBe(0)
	end)

	t.test("index total and milestones", function()
		t.expect(Progress.IndexTotal()).toBe(13 * 6)
		local index = { Rex = true, Gloop = true, Kong = true }
		local claimable = Progress.ClaimableMilestones(index, {})
		t.expect(#claimable).toBe(1)
		t.expect(#Progress.ClaimableMilestones(index, { ["1"] = true })).toBe(0)
	end)

	t.test("codes: case-insensitive, one use, unknown", function()
		local used = {}
		local ok, _, def = Progress.CanRedeem(used, " release ", 0)
		t.expect(ok).toBe(true)
		t.expect(def ~= nil).toBe(true)
		used[Progress.NormalizeCode(" release ")] = true
		local ok2, reason = Progress.CanRedeem(used, "RELEASE", 0)
		t.expect(ok2).toBe(false)
		t.expect(reason).toBe("You already used this code")
		t.expect((Progress.CanRedeem(used, "NOPE", 0))).toBe(false)
	end)

	t.test("boosts stack time and expire", function()
		local active = {}
		Progress.AddBoost(active, "Luck", 10, 1000)
		Progress.AddBoost(active, "Luck", 10, 1000)
		t.expect(active.Luck).toBe(1000 + 1200)
		t.expect(Progress.BoostMult(active, "Luck", 1500)).toBe(2)
		t.expect(Progress.BoostMult(active, "Luck", 3000)).toBe(1)
		t.expect(Progress.BoostMult(active, "Income", 1500)).toBe(1)
		Progress.CleanBoosts(active, 3000)
		t.expect(active.Luck).toBe(nil)
	end)

	t.test("rewards: cash seconds scale with income and describe nicely", function()
		t.expect(Progress.RewardCash({ Cash = 100, CashSeconds = 10 }, 50)).toBe(600)
		t.expect(Progress.RewardCash({ CashSeconds = 10 }, 0)).toBe(50) -- income floor of 5/s
		local text = Progress.DescribeReward(
			{ Cash = 1500, Food = { Meat = 2 }, Boost = { Id = "Luck", Minutes = 5 }, Trophies = 3 },
			0
		)
		t.expect(text).toBe("💰 $1.5K  🍖 2 Meat  🍀 2x Luck 5m  🏆 3")
	end)
end
