--[[
	Presets: named effects built from Primitives.

	Each preset is  function(params, P)  where P = Primitives.
	The server plays one with  FxService:PlayAll("Name", params).

	Recipe for effects that feel good (used everywhere below):
	  1. Anticipation: a quick ChargeUp / Glow before the moment.
	  2. Impact: Glow (bright flash) + Shockwave (ring) + Sparks (streaks).
	  3. Aftermath: slower Burst / smoke / Chunks, FloatText, sound.
	  4. Only for YOU: Shake / FovPunch / Flash / Confetti.

	To add a new effect: copy a preset, rename it, and mix primitives.
	Keep far-away effects cheap: check P.Distance(position) first.
]]

local Textures = require(script.Parent.Textures)

local GOLD = Color3.fromRGB(255, 210, 60)
local RED = Color3.fromRGB(255, 60, 60)
local GREEN = Color3.fromRGB(90, 230, 110)
local WHITE = Color3.new(1, 1, 1)
local FAR = 250 -- skip world effects farther than this from the camera

local Presets = {}

-- The standard "boom": flash + ring + streaks. Size ~ 1 for small, 3+ for huge.
local function impact(P, position: Vector3, color: Color3, size: number)
	P.Glow(position, { Color = color, Size = 6 * size, Duration = 0.3 + 0.05 * size })
	P.Shockwave(position, { Color = color, Radius = 7 * size, Duration = 0.4 + 0.05 * size })
	P.Sparks(position, { Color = color, Count = math.floor(10 + 6 * size), Speed = 30 + 10 * size })
end

--------------------------------------------------------------------------
-- Titans at your base
--------------------------------------------------------------------------

-- Titan eats food.
function Presets.Feed(p, P)
	if P.Distance(p.Position) > FAR then
		return
	end
	local color = p.Color or WHITE
	P.Glow(p.Position, { Color = color, Size = 5, Duration = 0.25 })
	P.Burst(p.Position, { Color = color, Count = 14, Speed = 14, Size = 0.7 })
	P.Sparks(p.Position, { Color = color, Count = 8, Speed = 22, Size = 0.4 })
	P.Sound("Pop", p.Position, 0.5, 1 + math.random() * 0.2)
	P.Bounce(p.Model)
	if p.Favorite then
		P.Burst(p.Position, { Color = Color3.fromRGB(255, 90, 140), Count = 10, Speed = 8, Size = 1.1, Gravity = 6 })
	end
	if P.IsMe(p.Owner) then
		local text = if p.Xp then "+" .. tostring(p.Xp) .. " XP" else "+XP"
		if p.Favorite then
			text ..= " ❤️"
		end
		P.FloatText(p.Position, text, { Color = color, Size = 1.8 })
	end
end

-- Titan levels up (and grows).
function Presets.LevelUp(p, P)
	if P.Distance(p.Position) > FAR then
		return
	end
	local ground = p.Ground or p.Position
	local size = p.Size or 0
	P.ChargeUp(p.Position, { Color = GOLD, Size = 12 + size, Duration = 0.25 })
	task.delay(0.22, function()
		impact(P, p.Position, GOLD, 1.5)
		P.Shockwave(ground, { Color = GOLD, Radius = 12 + size * 1.5, Duration = 0.6 })
		P.Ring(ground, { Color = GOLD, Radius = 10 + size, Duration = 0.6 })
		P.Beam(ground, { Color = GOLD, Height = 40 + size * 4, Width = 4 + size * 0.4, Duration = 1 })
		P.Burst(p.Position, { Color = GOLD, Count = 24, Speed = 26, Size = 1, Texture = Textures.Star })
		P.Light(p.Position, { Color = GOLD, Brightness = 6, Range = 25 })
		if p.Model then
			P.Highlight(p.Model, { Color = GOLD, Duration = 0.5 })
		end
		P.Sound("LevelUp", p.Position, 0.7, 1.2)
		if P.IsMe(p.Owner) then
			P.FloatText(
				p.Position + Vector3.new(0, 2, 0),
				"LEVEL " .. tostring(p.Level) .. "!",
				{ Color = GOLD, Size = 3.2 }
			)
			P.Shake(0.15, 0.25)
			P.FovPunch(-4, 0.35)
		end
	end)
end

-- Titan mutates (big moment!).
function Presets.Mutation(p, P)
	local color = p.Color or WHITE
	local ground = p.Ground or p.Position
	if P.Distance(p.Position) <= FAR then
		P.ChargeUp(p.Position, { Color = color, Size = 30, Duration = 0.5 })
		P.Glow(p.Position, { Color = color, Size = 10, Duration = 0.5 })
		task.delay(0.45, function()
			impact(P, p.Position, color, 3)
			P.Beam(ground, { Color = color, Height = 120, Width = 12, Duration = 1.8 })
			P.Shockwave(ground, { Color = color, Radius = 35, Duration = 0.8 })
			P.Ring(ground, { Color = color, Radius = 25, Duration = 0.8 })
			task.delay(0.15, function()
				P.Ring(ground, { Color = WHITE, Radius = 18, Duration = 0.6 })
			end)
			P.Burst(p.Position, { Color = color, Count = 60, Speed = 40, Size = 1.3, Lifetime = 1.2 })
			P.Light(p.Position, { Color = color, Brightness = 10, Range = 40, Duration = 1 })
			if p.Model then
				P.Highlight(p.Model, { Color = color, Duration = 1.2 })
			end
			P.Sound("Fanfare", p.Position, 0.8)
		end)
	end
	if P.IsMe(p.Owner) then
		task.delay(0.45, function()
			P.Flash(color, 0.6, 0.2)
			P.Shake(0.4, 0.5)
			P.FovPunch(-8, 0.5)
			P.FloatText(
				p.Position + Vector3.new(0, 4, 0),
				string.upper(p.Name or "MUTATION") .. "!",
				{ Color = color, Size = 4.5, Duration = 2 }
			)
		end)
	end
end

-- A new titan appears in the pen.
function Presets.Spawn(p, P)
	if P.Distance(p.Position) > FAR then
		return
	end
	local color = p.Color or WHITE
	impact(P, p.Position + Vector3.new(0, 2, 0), color, 1.2)
	P.Ring(p.Position, { Color = color, Radius = 10, Duration = 0.5 })
	P.Burst(p.Position + Vector3.new(0, 2, 0), { Color = color, Count = 25, Speed = 18 })
	if p.Rare then
		P.Beam(p.Position, { Color = color, Height = 70, Width = 8, Duration = 1.6 })
	end
end

-- Money popping off your titans (client plays this locally, see BaseAnimController).
function Presets.Income(p, P)
	P.FloatText(p.Position, p.Text or "+$", { Color = GREEN, Size = p.Size or 1.6, Duration = 1.1, Rise = 4 })
end

-- Sold a titan.
function Presets.Sell(p, P)
	impact(P, p.Position, GOLD, 1.5)
	P.Burst(p.Position, { Color = GOLD, Count = 40, Speed = 25, Size = 0.9 })
	P.Ring(p.Ground or p.Position, { Color = GOLD, Radius = 10 })
	if P.IsMe(p.Owner) then
		P.FloatText(p.Position, "+" .. (p.Text or ""), { Color = GOLD, Size = 2.8 })
		P.Sound("Coin", nil, 0.7)
	end
end

--------------------------------------------------------------------------
-- Finding titans (wild)
--------------------------------------------------------------------------

-- A rare wild titan appeared: a tall beacon everyone on the island can see.
function Presets.WildSpawn(p, P)
	local color = p.Color or WHITE
	local rare = (p.RarityOrder or 1) >= 4
	P.Beam(p.Position, {
		Color = color,
		Height = if rare then 220 else 90,
		Width = if rare then 16 else 8,
		Duration = if rare then 3 else 1.6,
	})
	if P.Distance(p.Position) <= FAR then
		impact(P, p.Position + Vector3.new(0, 3, 0), color, if rare then 3 else 1.5)
		P.Burst(p.Position, {
			Color = Color3.fromRGB(235, 235, 235),
			Count = 14,
			Speed = 10,
			Size = 3,
			Lifetime = 1.2,
			Gravity = 3,
			LightEmission = 0,
			Texture = Textures.Dust,
		})
		P.Sound(if rare then "Fanfare" else "Pop", p.Position, 0.7)
	end
end

-- Knocked out: dizzy stars + a sleepy puff (Phase 1 knock-out taming).
function Presets.KnockOut(p, P)
	if P.Distance(p.Position) > FAR then
		return
	end
	local color = p.Color or WHITE
	P.Glow(p.Position, { Color = Color3.fromRGB(200, 180, 255), Size = 10, Duration = 0.4 })
	P.Burst(p.Position, {
		Color = Color3.fromRGB(255, 240, 120),
		Count = 14,
		Speed = 8,
		Size = 1.2,
		Lifetime = 1.4,
		Gravity = -2,
		Texture = Textures.Star,
	})
	P.Shockwave(p.Position - Vector3.new(0, 2, 0), { Color = color, Radius = 10, Duration = 0.6 })
	P.FloatText(
		p.Position + Vector3.new(0, 2, 0),
		"💫 KNOCKED OUT!",
		{ Color = Color3.fromRGB(200, 170, 255), Size = 3 }
	)
	P.Sound("Pop", p.Position, 0.7, 0.6)
	if P.IsMe(p.Owner) then
		P.FovPunch(-4, 0.35)
	end
end

-- Feeding a sleeping titan while taming: hearts float up.
function Presets.TameFeed(p, P)
	if P.Distance(p.Position) > FAR then
		return
	end
	P.Burst(p.Position, {
		Color = Color3.fromRGB(255, 100, 150),
		Count = if p.Favorite then 10 else 5,
		Speed = 6,
		Size = 1.4,
		Lifetime = 1.3,
		Gravity = -4,
		Texture = Textures.Sparkle,
	})
	if P.IsMe(p.Owner) then
		P.FloatText(p.Position, p.Text or "❤️", { Color = Color3.fromRGB(255, 130, 170), Size = 2 })
	end
end

-- Two titans breeding: hearts float up between them.
function Presets.Love(p, P)
	if P.Distance(p.Position) > FAR then
		return
	end
	P.Burst(p.Position, {
		Color = Color3.fromRGB(255, 110, 160),
		Count = 6,
		Speed = 5,
		Size = 1.6,
		Lifetime = 1.6,
		Gravity = -5,
		Texture = Textures.Sparkle,
	})
	P.FloatText(p.Position, "❤️", { Color = Color3.fromRGB(255, 120, 170), Size = 2.4, Duration = 1.4, Rise = 6 })
end

-- A new egg appears (breeding done / nest found).
function Presets.EggLaid(p, P)
	if P.Distance(p.Position) > FAR then
		return
	end
	local color = p.Color or Color3.fromRGB(255, 220, 120)
	P.Ring(p.Position, { Color = color, Radius = 8 * (p.Scale or 1), Duration = 0.6 })
	P.Burst(p.Position + Vector3.new(0, 2, 0), { Color = color, Count = 20, Speed = 12, Texture = Textures.Sparkle })
	P.FloatText(p.Position + Vector3.new(0, 4, 0), p.Text or "🥚 New egg!", { Color = color, Size = 2.2 })
	P.Sound("Pop", p.Position, 0.7)
end

-- Mounting / dismounting a titan: dust puff at the feet.
function Presets.MountDust(p, P)
	if P.Distance(p.Position) > FAR then
		return
	end
	P.Burst(p.Position, {
		Color = Color3.fromRGB(215, 195, 160),
		Count = 14,
		Speed = 12,
		Size = 3 * (p.Size or 1),
		Lifetime = 0.9,
		Gravity = 2,
		LightEmission = 0,
		Texture = Textures.Dust,
	})
	P.Shockwave(p.Position, { Color = Color3.fromRGB(230, 220, 200), Radius = 6 * (p.Size or 1), Duration = 0.4 })
	P.Sound("Whoosh", p.Position, 0.5, 0.8)
end

-- A tranq dart flying from the shooter to where it landed.
function Presets.Dart(p, P)
	if not p.From or not p.To then
		return
	end
	local direction = p.To - p.From
	for i = 1, 6 do
		task.delay(i * 0.02, function()
			P.Glow(p.From + direction * (i / 6), {
				Color = Color3.fromRGB(120, 255, 140),
				Size = 1.4,
				Duration = 0.15,
			})
		end)
	end
	if p.Hit then
		P.Sparks(p.To, { Color = Color3.fromRGB(160, 255, 170), Count = 8, Speed = 25, Size = 0.4 })
	end
	P.Sound("Whoosh", p.From, 0.4, 1.6)
end

-- Someone started taming a wild titan.
function Presets.TameStart(p, P)
	if P.Distance(p.Position) > FAR then
		return
	end
	local color = p.Color or WHITE
	P.ChargeUp(p.Position, { Color = color, Size = 18, Duration = p.Duration or 1 })
	P.Shockwave(p.Ground or p.Position, { Color = color, Radius = 10, Duration = 0.6 })
end

-- Tamed! The titan flies to its new owner's base.
function Presets.TameSuccess(p, P)
	local color = p.Color or WHITE
	if P.Distance(p.Position) <= FAR then
		impact(P, p.Position, color, 2.5)
		P.Beam(p.Ground or p.Position, { Color = color, Height = 90, Width = 10, Duration = 1.4 })
		P.Burst(p.Position, { Color = color, Count = 50, Speed = 35, Size = 1.2, Texture = Textures.Star })
		P.Burst(p.Position, { Color = GOLD, Count = 20, Speed = 20, Size = 0.8 })
		P.Sound("Fanfare", p.Position, 0.8)
	end
	if P.IsMe(p.Owner) then
		P.Flash(color, 0.5, 0.35)
		P.FovPunch(-6, 0.4)
		P.Shake(0.25, 0.3)
		P.FloatText(p.Position + Vector3.new(0, 4, 0), "TAMED!", { Color = color, Size = 4, Duration = 1.6 })
		if (p.RarityOrder or 1) >= 4 then
			P.Confetti(90)
		end
	end
end

-- Taming failed: the titan runs away in a puff.
function Presets.TameFail(p, P)
	if P.Distance(p.Position) <= FAR then
		P.Burst(p.Position + Vector3.new(0, 2, 0), {
			Color = Color3.fromRGB(230, 230, 230),
			Count = 24,
			Speed = 12,
			Size = 4,
			Lifetime = 1.3,
			Gravity = 4,
			LightEmission = 0,
			Texture = Textures.Dust,
		})
		P.Sound("Whoosh", p.Position, 0.6)
	end
	if P.IsMe(p.Target) then
		P.FloatText(p.Position + Vector3.new(0, 3, 0), "IT GOT AWAY!", { Color = RED, Size = 3, Duration = 1.4 })
	end
end

-- Puff of smoke (wild titan leaving on its own).
function Presets.Poof(p, P)
	if P.Distance(p.Position) > FAR then
		return
	end
	P.Burst(p.Position + Vector3.new(0, 2, 0), {
		Color = Color3.fromRGB(230, 230, 230),
		Count = 20,
		Speed = 10,
		Size = 3,
		Lifetime = 1.2,
		Gravity = 4,
		LightEmission = 0,
		Texture = Textures.Dust,
	})
	P.Sound("Whoosh", p.Position, 0.5)
end

--------------------------------------------------------------------------
-- Food & stealing
--------------------------------------------------------------------------

-- Picked up food.
function Presets.Pickup(p, P)
	local color = p.Color or WHITE
	P.Glow(p.Position, { Color = color, Size = 5, Duration = 0.25 })
	P.Sparks(p.Position, { Color = color, Count = 10, Speed = 25, Size = 0.4, Gravity = -10 })
	P.Burst(p.Position, { Color = color, Count = 10, Speed = 10, Size = 0.6 })
	P.Sound("Pop", p.Position, 0.5, 1.4)
	if p.Text then
		P.FloatText(p.Position, p.Text, { Color = color, Size = 1.7 })
	end
end

-- Someone starts stealing from a food storage.
function Presets.StealStart(p, P)
	if P.Distance(p.Position) > FAR then
		return
	end
	P.Glow(p.Position, { Color = RED, Size = 8, Duration = 0.3 })
	P.Shockwave(p.Position, { Color = RED, Radius = 10, Duration = 0.4 })
	P.Burst(p.Position, { Color = RED, Count = 15, Speed = 15 })
end

-- Shown only to the player being stolen from.
function Presets.StealAlert(_p, P)
	P.Vignette(RED, 1.5)
	P.Sound("Alarm", nil, 0.6)
end

-- Thief made it home with the food.
function Presets.Deposit(p, P)
	local color = p.Color or GOLD
	impact(P, p.Position, color, 1.5)
	P.Burst(p.Position, { Color = color, Count = 25, Speed = 20 })
	if P.IsMe(p.Owner) then
		P.FloatText(p.Position, "STOLEN!", { Color = color, Size = 3 })
		P.Sound("Coin", nil, 0.6)
		P.FovPunch(-3, 0.3)
	end
end

-- A guard titan knocks a thief away.
function Presets.GuardKnock(p, P)
	if P.Distance(p.Position) > FAR then
		return
	end
	impact(P, p.Position, WHITE, 2)
	P.Sound("Impact", p.Position, 0.8)
	if P.IsMe(p.Target) then
		P.Shake(0.6, 0.4)
		P.Flash(WHITE, 0.25, 0.4)
		if p.Velocity then
			P.Knockback(p.Velocity)
		end
	end
end

-- Food taken back from a thief.
function Presets.TakeBack(p, P)
	impact(P, p.Position, GREEN, 1)
	P.Sound("Pop", p.Position, 0.6, 0.9)
end

-- Meteor lands (Meteor Feast event).
function Presets.MeteorImpact(p, P)
	local distance = P.Distance(p.Position)
	if distance > FAR * 1.5 then
		return
	end
	local orange = Color3.fromRGB(255, 140, 40)
	impact(P, p.Position, orange, 2.5)
	P.Chunks(p.Position, { Count = 7, Size = 1.6, Distance = 14 })
	P.Burst(p.Position, { Color = p.Color, Count = 20, Speed = 30, Size = 1 })
	P.Burst(p.Position, {
		Color = Color3.fromRGB(90, 80, 80),
		Count = 10,
		Speed = 10,
		Size = 4,
		Lifetime = 1.6,
		Gravity = 5,
		LightEmission = 0,
		Texture = Textures.Dust,
	})
	P.Light(p.Position, { Color = orange, Brightness = 8, Range = 30 })
	P.Sound("Impact", p.Position, 0.7, 0.8 + math.random() * 0.3)
	if distance < 80 then
		P.Shake(0.3 * (1 - distance / 80), 0.3)
	end
end

-- Red target ring where a meteor will land.
function Presets.MeteorWarning(p, P)
	P.Ring(p.Position, { Color = RED, Radius = 5, Duration = 1.2, Thickness = 0.15 })
	P.Shockwave(p.Position, { Color = RED, Radius = 6, Duration = 1.2 })
end

--------------------------------------------------------------------------
-- Big moments
--------------------------------------------------------------------------

-- A new Titan King is crowned.
function Presets.NewKing(p, P)
	if p.Position and P.Distance(p.Position) <= FAR * 2 then
		P.Beam(p.Position, { Color = GOLD, Height = 200, Width = 18, Duration = 2.5 })
		impact(P, p.Position + Vector3.new(0, 10, 0), GOLD, 4)
		P.Ring(p.Position, { Color = GOLD, Radius = 40, Duration = 1 })
		P.Burst(p.Position + Vector3.new(0, 10, 0), { Color = GOLD, Count = 60, Speed = 40, Size = 1.6 })
	end
	if P.IsMe(p.Owner) then
		P.Confetti(80, { GOLD, WHITE, Color3.fromRGB(255, 170, 0) })
		P.Flash(GOLD, 0.6, 0.3)
		P.FovPunch(-8, 0.6)
	end
end

-- Player rebirths.
function Presets.Rebirth(p, P)
	local purple = Color3.fromRGB(180, 120, 255)
	if p.Position and P.Distance(p.Position) <= FAR then
		P.ChargeUp(p.Position, { Color = purple, Size = 40, Duration = 0.5 })
		task.delay(0.45, function()
			P.Beam(p.Position, { Color = purple, Height = 160, Width = 14, Duration = 2 })
			impact(P, p.Position, purple, 4)
			P.Ring(p.Position, { Color = purple, Radius = 30, Duration = 0.8 })
		end)
	end
	if P.IsMe(p.Owner) then
		task.delay(0.45, function()
			P.Flash(WHITE, 1, 0)
			P.Shake(0.8, 0.8)
			P.Confetti(100)
		end)
	end
end

-- Egg hatch reveal (played by the hatch UI).
function Presets.HatchReveal(p, P)
	P.Flash(p.Color or WHITE, 0.5, 0.1)
	P.Sound("Hatch", nil, 0.8)
	if p.RarityOrder and p.RarityOrder >= 4 then
		P.Confetti(80)
		P.Shake(0.3, 0.4)
		P.FovPunch(-6, 0.5)
	end
end

--------------------------------------------------------------------------
-- Battle
--------------------------------------------------------------------------

-- A titan attacks (basic attack or special). Look = facing direction.
function Presets.TitanAttack(p, P)
	if P.Distance(p.Position) > FAR then
		return
	end
	local look = p.Look or Vector3.new(0, 0, -1)
	local range = p.Range or 10
	local ground = p.Position - Vector3.new(0, 2, 0)
	local color = p.Color or WHITE
	local facing = CFrame.lookAt(p.Position, p.Position + look)
	if p.Kind == "Attack" then
		-- Claw swipe: alternating tilt so combos look different.
		P.Slash(facing, {
			Color = color,
			Radius = range * 0.7,
			Width = 1 + range * 0.15,
			Tilt = if math.random() < 0.5 then 25 else -25,
		})
		P.Sparks(p.Position + look * range * 0.6, { Color = color, Count = 8, Speed = 30, Direction = look })
		P.Sound("Whoosh", p.Position, 0.5, 0.9 + math.random() * 0.3)
	elseif p.Special == "Slam" then
		P.ChargeUp(p.Position, { Color = color, Size = range * 1.5, Duration = 0.3 })
		task.delay(0.3, function()
			impact(P, ground, color, 2 + range * 0.1)
			P.Shockwave(ground, { Color = Color3.fromRGB(200, 170, 120), Radius = range * 1.6, Duration = 0.6 })
			P.Ring(ground, { Color = color, Radius = range * 1.5, Duration = 0.5, Thickness = 0.6 })
			P.Chunks(ground, { Count = 10, Size = 1 + range * 0.1, Distance = range * 1.4 })
			P.Burst(ground, {
				Color = Color3.fromRGB(170, 145, 110),
				Count = 18,
				Speed = 18,
				Size = 4,
				Lifetime = 1.2,
				LightEmission = 0,
				Gravity = 2,
				Texture = Textures.Dust,
			})
			P.Sound("Impact", ground, 0.9, 0.7)
			if P.Distance(ground) < range * 3 then
				P.Shake(0.6, 0.35)
				P.FovPunch(5, 0.3)
			end
		end)
	elseif p.Special == "Charge" then
		P.Glow(p.Position, { Color = color, Size = range, Duration = 0.3 })
		for i = 1, 6 do
			task.delay(i * 0.05, function()
				local at = ground + look * i * range * 0.4
				P.Burst(at, {
					Color = Color3.fromRGB(190, 165, 125),
					Count = 6,
					Speed = 8,
					Size = 3,
					LightEmission = 0,
					Texture = Textures.Dust,
				})
				P.Sparks(at + Vector3.new(0, 2, 0), { Color = color, Count = 5, Speed = 20, Direction = -look })
			end)
		end
		P.Sound("Whoosh", p.Position, 0.8, 0.7)
	elseif p.Special == "Bounce" then
		task.delay(0.6, function()
			impact(P, ground, color, 2 + range * 0.1)
			P.Ring(ground, { Color = color, Radius = range * 1.4, Duration = 0.5, Thickness = 0.6 })
			P.Burst(ground, { Color = color, Count = 30, Speed = 28, Size = 1.6 })
			P.Sound("Impact", ground, 0.8, 1.1)
		end)
	elseif p.Special == "Breath" then
		P.ChargeUp(p.Position + look * 2, { Color = Color3.fromRGB(255, 160, 40), Size = range, Duration = 0.2 })
		for i = 1, 10 do
			task.delay(0.1 + i * 0.04, function()
				local at = p.Position + look * (range * 2.2) * (i / 10)
				P.Burst(at, {
					Color = ColorSequence.new(Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 60, 20)),
					Count = 10,
					Speed = 6 + i,
					Size = 2 + i * 0.4,
					Lifetime = 0.5,
					Gravity = -6,
					Texture = Textures.Fire,
				})
			end)
		end
		P.Sparks(
			p.Position + look * 3,
			{ Color = Color3.fromRGB(255, 180, 60), Count = 20, Speed = 50, Direction = look }
		)
		P.Light(p.Position + look * range, { Color = Color3.fromRGB(255, 140, 40), Brightness = 6, Range = range * 2 })
		P.Sound("Whoosh", p.Position, 0.8, 0.6)
	end
end

-- A titan gets hit.
function Presets.Hit(p, P)
	if P.Distance(p.Position) <= FAR then
		local away = if p.Velocity then Vector3.new(p.Velocity.X, 0, p.Velocity.Z) else nil
		P.Glow(p.Position, { Color = Color3.fromRGB(255, 240, 200), Size = 7, Duration = 0.2 })
		P.Sparks(p.Position, { Color = Color3.fromRGB(255, 230, 160), Count = 14, Speed = 45, Direction = away })
		P.Shockwave(p.Position, { Color = WHITE, Radius = 6, Duration = 0.25, Upright = true })
		P.FloatText(
			p.Position + Vector3.new(0, 2, 0),
			"-" .. tostring(p.Amount or ""),
			{ Color = Color3.fromRGB(255, 80, 80), Size = 3.2, Duration = 0.9 }
		)
		if p.Model then
			P.Highlight(p.Model, { Color = WHITE, Duration = 0.15 })
		end
		P.Sound("Hit", p.Position, 0.7, 0.9 + math.random() * 0.3)
	end
	if P.IsMe(p.Target) then
		P.Shake(0.5, 0.25)
		P.Vignette(Color3.fromRGB(255, 40, 40), 0.5)
		if p.Velocity then
			P.Knockback(p.Velocity)
		end
	end
end

-- A titan is knocked out.
function Presets.KO(p, P)
	if P.Distance(p.Position) <= FAR * 1.5 then
		impact(P, p.Position, RED, 4)
		P.Beam(p.Position, { Color = RED, Height = 80, Width = 10, Duration = 1.2 })
		P.Ring(p.Position, { Color = RED, Radius = 25, Duration = 0.7 })
		P.Burst(p.Position + Vector3.new(0, 4, 0), {
			Color = Color3.fromRGB(220, 220, 220),
			Count = 24,
			Speed = 20,
			Size = 5,
			Lifetime = 1.4,
			Gravity = 4,
			LightEmission = 0,
			Texture = Textures.Dust,
		})
		P.FloatText(p.Position + Vector3.new(0, 10, 0), "K.O.!", { Color = RED, Size = 6, Duration = 1.6 })
		P.Sound("Impact", p.Position, 1, 0.5)
		P.FovPunch(6, 0.5)
	end
	if P.IsMe(p.Target) then
		P.Flash(RED, 0.6, 0.3)
	end
end

-- Match winner.
function Presets.Victory(p, P)
	if p.Position and P.Distance(p.Position) <= FAR * 2 then
		P.Beam(p.Position, { Color = GOLD, Height = 200, Width = 16, Duration = 2.5 })
		impact(P, p.Position + Vector3.new(0, 6, 0), GOLD, 4)
		P.Ring(p.Position, { Color = GOLD, Radius = 40, Duration = 1 })
		P.Burst(p.Position + Vector3.new(0, 10, 0), { Color = GOLD, Count = 60, Speed = 40, Size = 1.6 })
	end
	if P.IsMe(p.Owner) then
		P.Confetti(100, { GOLD, WHITE, Color3.fromRGB(255, 170, 0) })
		P.Sound("Fanfare", nil, 0.9)
	end
end

-- Moves the local player's character (dash / bounce specials).
function Presets.Launch(p, P)
	if p.Velocity then
		P.Knockback(p.Velocity)
	end
end

-- Reward received (small celebration).
function Presets.Reward(_p, P)
	P.Confetti(30)
	P.Sound("Coin", nil, 0.7)
end

-- Storage lock turned on.
function Presets.Lock(p, P)
	local blue = Color3.fromRGB(90, 170, 255)
	impact(P, p.Position, blue, 1.5)
	P.Ring(p.Position, { Color = blue, Radius = 12, Duration = 0.5 })
end

return Presets
