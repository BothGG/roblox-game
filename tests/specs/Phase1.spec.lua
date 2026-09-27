return function(t)
	local WildBrain = t.require(t.Shared.Game.WildBrain)
	local Taming = t.require(t.Shared.Game.Taming)
	local Riding = t.require(t.Shared.Game.Riding)
	local GameConfig = t.require(t.Shared.Config.GameConfig)
	local WILD = GameConfig.Wild

	local function input(overrides)
		local i = {
			State = "Idle",
			StateSince = 0,
			StateDuration = 3,
			Now = 1,
			Temper = "Passive",
			Asleep = false,
			LastHitAt = nil,
			TargetDistance = math.huge,
			HomeDistance = 0,
			Reach = 10,
			Roll = 0.9,
		}
		for k, v in overrides do
			i[k] = v
		end
		return i
	end

	t.test("wild brain: calm titans cycle between idle, graze and wander", function()
		t.expect(WildBrain.Decide(input({}))).toBe("Idle") -- not finished idling
		t.expect(WildBrain.Decide(input({ Now = 10, Roll = 0.1 }))).toBe("Wander")
		t.expect(WildBrain.Decide(input({ Now = 10, Roll = 0.6 }))).toBe("Graze")
		t.expect(WildBrain.DurationFor("Graze", 1)).toBe(8)
	end)

	t.test("wild brain: passive titans flee when hit, then calm down", function()
		t.expect(WildBrain.Decide(input({ LastHitAt = 0.5 }))).toBe("Flee")
		t.expect(WildBrain.Decide(input({ State = "Flee", LastHitAt = 0, Now = WILD.FleeTime + 1 }))).toBe("Idle")
		-- players nearby don't scare them if they weren't hit
		t.expect(WildBrain.Decide(input({ TargetDistance = 5 }))).toBe("Idle")
	end)

	t.test("wild brain: aggressive titans chase, attack in reach, and give up past the leash", function()
		local base = { Temper = "Aggressive" }
		t.expect(WildBrain.Decide(input(base))).toBe("Idle")
		base.TargetDistance = WILD.AggroRange - 1
		t.expect(WildBrain.Decide(input(base))).toBe("Chase")
		base.TargetDistance = 8
		t.expect(WildBrain.Decide(input(base))).toBe("Attack")
		base.State = "Chase"
		base.TargetDistance = 30
		base.HomeDistance = WILD.LeashRange + 5
		t.expect(WildBrain.Decide(input(base))).toBe("Return")
		t.expect(WildBrain.Decide(input({ State = "Return", HomeDistance = 3 }))).toBe("Idle")
		-- hit from far away: still comes for you
		t.expect(WildBrain.Decide(input({ Temper = "Aggressive", LastHitAt = 0.9, TargetDistance = 100 })))
			.toBe("Chase")
	end)

	t.test("wild brain: asleep beats everything, then it wakes up idle", function()
		t.expect(WildBrain.Decide(input({ Asleep = true, LastHitAt = 0.9, Temper = "Aggressive", TargetDistance = 1 })))
			.toBe("Asleep")
		t.expect(WildBrain.Decide(input({ State = "Asleep" }))).toBe("Idle")
	end)

	t.test("wild size rolls stay inside their bands", function()
		t.expect(WildBrain.RollSize(0.1, 0)).toBe(1)
		t.expect(WildBrain.RollSize(0.1, 1)).toBe(3)
		local big = WildBrain.RollSize(0.999, 0.5)
		t.expect(big >= 100 and big <= 1000).toBe(true)
	end)

	t.test("torpor: fills to max, reports falling asleep once, drains", function()
		local max = Taming.MaxTorpor({ Id = "Rex", Size = 1 })
		t.expect(max).toBe(60)
		local torpor, slept = Taming.AddTorpor(0, 40, max)
		t.expect(slept).toBe(false)
		torpor, slept = Taming.AddTorpor(torpor, 40, max)
		t.expect(torpor).toBe(max)
		t.expect(slept).toBe(true)
		local _, again = Taming.AddTorpor(torpor, 10, max)
		t.expect(again).toBe(false)
		t.expect(Taming.Drain(30, max, 1)).toBeCloseTo(30 - max * GameConfig.Tame.TorporDrain, 1e-9)
		t.expect(Taming.MaxTorpor({ Id = "Rex", Size = 1000 }) > max).toBe(true)
	end)

	t.test("taming: favorite food counts double; first player to fill their bar wins", function()
		local rex = { Id = "Rex", Size = 1 }
		local needed = Taming.FoodNeeded(rex)
		t.expect(needed).toBe(3) -- Common: 1 * 3
		t.expect(Taming.FoodPoints("Rex", "Meat")).toBe(2)
		t.expect(Taming.FoodPoints("Rex", "Fish")).toBe(1)
		local progress = Taming.NewProgress()
		t.expect(Taming.Feed(progress, 1, 2, needed)).toBe(false)
		t.expect(Taming.Feed(progress, 2, 2, needed)).toBe(false)
		local leader, points = Taming.Leader(progress)
		t.expect(leader).toBe(1)
		t.expect(points).toBe(2)
		t.expect(Taming.Feed(progress, 2, 1, needed)).toBe(true) -- player 2 steals the tame
	end)

	t.test("taming effectiveness drops when hit asleep, down to a floor", function()
		t.expect(Taming.Effectiveness(0)).toBe(1)
		t.expect(Taming.TamedLevel(1)).toBe(1 + GameConfig.Tame.MaxBonusLevels)
		t.expect(Taming.Effectiveness(4)).toBeCloseTo(0.8, 1e-9)
		t.expect(Taming.Effectiveness(100)).toBe(GameConfig.Tame.MinEffectiveness)
	end)

	t.test("riding stats by style and stamina", function()
		local rex = Riding.Stats({ Id = "Rex", Level = 1 })
		local drake = Riding.Stats({ Id = "Drake", Level = 1 })
		local gloop = Riding.Stats({ Id = "Gloop", Level = 1 })
		t.expect(rex.CanSprint).toBe(true)
		t.expect(rex.CanFly).toBe(false)
		t.expect(drake.CanFly).toBe(true)
		t.expect(gloop.CanSprint).toBe(false)
		t.expect(gloop.JumpPower > rex.JumpPower).toBe(true)
		t.expect(rex.SprintSpeed > rex.WalkSpeed).toBe(true)
		local s = Riding.UpdateStamina(50, 100, 1, "Sprint")
		t.expect(s).toBe(50 - GameConfig.Riding.SprintDrain)
		t.expect(Riding.UpdateStamina(99, 100, 1, "Walk")).toBe(100)
		t.expect(Riding.UpdateStamina(1, 100, 1, "Fly")).toBe(0)
		t.expect(Riding.CanUse(5, "Sprint")).toBe(false)
		t.expect(Riding.CanUse(5, "Sprint", true)).toBe(true)
		t.expect(Riding.CanUse(0, "Walk")).toBe(true)
		local offset = Riding.FollowerOffset(1, 10)
		t.expect(offset.Z).toBe(10)
	end)
end
