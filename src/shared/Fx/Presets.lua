--[[
	Presets: named effects built from Primitives.

	Each preset is  function(params, P)  where P = Primitives.
	The server plays one with  FxService:PlayAll("Name", params).

	To add a new effect: copy a preset, rename it, and mix primitives.
	Keep far-away effects cheap: check P.Distance(position) first.
]]

local Textures = require(script.Parent.Textures)

local GOLD = Color3.fromRGB(255, 210, 60)
local RED = Color3.fromRGB(255, 60, 60)
local WHITE = Color3.new(1, 1, 1)
local FAR = 250 -- skip world effects farther than this from the camera

local Presets = {}

-- Titan eats food.
function Presets.Feed(p, P)
	if P.Distance(p.Position) > FAR then
		return
	end
	P.Burst(p.Position, { Color = p.Color, Count = 12, Speed = 12, Size = 0.6 })
	P.Sound("Pop", p.Position, 0.5, 1 + math.random() * 0.2)
	P.Bounce(p.Model)
	if p.Favorite then
		P.Burst(p.Position, { Color = Color3.fromRGB(255, 90, 140), Count = 8, Speed = 8, Size = 1, Gravity = 6 })
	end
	if P.IsMe(p.Owner) then
		local text = if p.Xp then "+" .. tostring(p.Xp) .. " XP" else "+XP"
		if p.Favorite then
			text ..= " ❤️"
		end
		P.FloatText(p.Position, text, { Color = p.Color, Size = 1.6 })
	end
end

-- Titan levels up (and grows).
function Presets.LevelUp(p, P)
	if P.Distance(p.Position) > FAR then
		return
	end
	local ground = p.Ground or p.Position
	P.Ring(ground, { Color = GOLD, Radius = 10 + (p.Size or 0), Duration = 0.6 })
	P.Burst(p.Position, { Color = GOLD, Count = 30, Speed = 30, Size = 0.9 })
	P.Light(p.Position, { Color = GOLD, Brightness = 6, Range = 25 })
	if p.Model then
		P.Highlight(p.Model, { Color = GOLD, Duration = 0.5 })
	end
	P.Sound("LevelUp", p.Position, 0.7, 1.2)
	if P.IsMe(p.Owner) then
		P.FloatText(p.Position + Vector3.new(0, 2, 0), "LEVEL " .. tostring(p.Level) .. "!", { Color = GOLD, Size = 3 })
		P.Shake(0.15, 0.25)
	end
end

-- Titan mutates (big moment!).
function Presets.Mutation(p, P)
	local color = p.Color or WHITE
	if P.Distance(p.Position) <= FAR then
		local ground = p.Ground or p.Position
		P.Pillar(ground, { Color = color, Height = 80, Width = 10, Duration = 1.5 })
		P.Ring(ground, { Color = color, Radius = 25, Duration = 0.8 })
		task.delay(0.15, function()
			P.Ring(ground, { Color = WHITE, Radius = 18, Duration = 0.6 })
		end)
		P.Burst(p.Position, { Color = color, Count = 60, Speed = 40, Size = 1.2, Lifetime = 1.2 })
		P.Light(p.Position, { Color = color, Brightness = 10, Range = 40, Duration = 1 })
		if p.Model then
			P.Highlight(p.Model, { Color = color, Duration = 1.2 })
		end
		P.Sound("Fanfare", p.Position, 0.8)
	end
	if P.IsMe(p.Owner) then
		P.Flash(color, 0.6, 0.2)
		P.Shake(0.4, 0.5)
		P.FloatText(
			p.Position + Vector3.new(0, 4, 0),
			string.upper(p.Name or "MUTATION") .. "!",
			{ Color = color, Size = 4, Duration = 2 }
		)
	end
end

-- A new titan appears in the pen.
function Presets.Spawn(p, P)
	if P.Distance(p.Position) > FAR then
		return
	end
	local color = p.Color or WHITE
	P.Ring(p.Position, { Color = color, Radius = 10, Duration = 0.5 })
	P.Burst(p.Position + Vector3.new(0, 2, 0), { Color = color, Count = 25, Speed = 18 })
	if p.Rare then
		P.Pillar(p.Position, { Color = color, Height = 50, Width = 6 })
	end
end

-- Picked up wild food.
function Presets.Pickup(p, P)
	P.Burst(p.Position, { Color = p.Color, Count = 10, Speed = 10, Size = 0.5 })
	P.Sound("Pop", p.Position, 0.5, 1.4)
	if p.Text then
		P.FloatText(p.Position, p.Text, { Color = p.Color, Size = 1.5 })
	end
end

-- Someone starts stealing from a food storage.
function Presets.StealStart(p, P)
	if P.Distance(p.Position) > FAR then
		return
	end
	P.Burst(p.Position, { Color = RED, Count = 15, Speed = 15 })
	P.Ring(p.Position, { Color = RED, Radius = 8, Duration = 0.4 })
end

-- Shown only to the player being stolen from.
function Presets.StealAlert(_p, P)
	P.Vignette(RED, 1.5)
	P.Sound("Alarm", nil, 0.6)
end

-- Thief made it home with the food.
function Presets.Deposit(p, P)
	P.Burst(p.Position, { Color = p.Color, Count = 25, Speed = 20 })
	P.Ring(p.Position, { Color = p.Color, Radius = 8 })
	if P.IsMe(p.Owner) then
		P.FloatText(p.Position, "STOLEN!", { Color = p.Color, Size = 2.5 })
		P.Sound("Coin", nil, 0.6)
	end
end

-- A guard titan knocks a thief away.
function Presets.GuardKnock(p, P)
	if P.Distance(p.Position) > FAR then
		return
	end
	P.Ring(p.Position, { Color = WHITE, Radius = 14, Duration = 0.4 })
	P.Burst(p.Position, { Color = WHITE, Count = 20, Speed = 35 })
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
	P.Burst(p.Position, { Color = Color3.fromRGB(90, 220, 120), Count = 20, Speed = 20 })
	P.Sound("Pop", p.Position, 0.6, 0.9)
end

-- Sold a titan.
function Presets.Sell(p, P)
	P.Burst(p.Position, { Color = GOLD, Count = 40, Speed = 25, Size = 0.8 })
	P.Ring(p.Ground or p.Position, { Color = GOLD, Radius = 10 })
	if P.IsMe(p.Owner) then
		P.FloatText(p.Position, "+" .. (p.Text or ""), { Color = GOLD, Size = 2.5 })
		P.Sound("Coin", nil, 0.7)
	end
end

-- Meteor lands (Meteor Feast event).
function Presets.MeteorImpact(p, P)
	local distance = P.Distance(p.Position)
	if distance > FAR * 1.5 then
		return
	end
	P.Ring(p.Position, { Color = Color3.fromRGB(255, 140, 40), Radius = 16, Duration = 0.5 })
	P.Burst(p.Position, { Color = p.Color, Count = 25, Speed = 30, Size = 1 })
	P.Burst(p.Position, {
		Color = Color3.fromRGB(80, 80, 80),
		Count = 10,
		Speed = 10,
		Size = 3,
		Lifetime = 1.5,
		Gravity = 5,
		LightEmission = 0,
	})
	P.Light(p.Position, { Color = Color3.fromRGB(255, 150, 50), Brightness = 8, Range = 30 })
	P.Sound("Impact", p.Position, 0.7, 0.8 + math.random() * 0.3)
	if distance < 80 then
		P.Shake(0.3 * (1 - distance / 80), 0.3)
	end
end

-- Meteor streak while falling (attached by the server as a trail).
function Presets.MeteorWarning(p, P)
	P.Ring(p.Position, { Color = RED, Radius = 5, Duration = 1.2, Thickness = 0.15 })
end

-- A new Titan King is crowned.
function Presets.NewKing(p, P)
	if p.Position and P.Distance(p.Position) <= FAR * 2 then
		P.Pillar(p.Position, { Color = GOLD, Height = 150, Width = 14, Duration = 2 })
		P.Ring(p.Position, { Color = GOLD, Radius = 40, Duration = 1 })
		P.Burst(p.Position + Vector3.new(0, 10, 0), { Color = GOLD, Count = 60, Speed = 40, Size = 1.5 })
	end
	if P.IsMe(p.Owner) then
		P.Confetti(80, { GOLD, WHITE, Color3.fromRGB(255, 170, 0) })
		P.Flash(GOLD, 0.6, 0.3)
	end
end

-- Player rebirths.
function Presets.Rebirth(p, P)
	if p.Position and P.Distance(p.Position) <= FAR then
		P.Pillar(p.Position, { Color = Color3.fromRGB(180, 120, 255), Height = 120, Width = 12, Duration = 2 })
		P.Ring(p.Position, { Color = Color3.fromRGB(180, 120, 255), Radius = 30, Duration = 0.8 })
	end
	if P.IsMe(p.Owner) then
		P.Flash(WHITE, 1, 0)
		P.Shake(0.8, 0.8)
		P.Confetti(100)
	end
end

-- Egg hatch reveal (played by the hatch UI).
function Presets.HatchReveal(p, P)
	P.Flash(p.Color or WHITE, 0.5, 0.1)
	P.Sound("Hatch", nil, 0.8)
	if p.RarityOrder and p.RarityOrder >= 4 then
		P.Confetti(80)
		P.Shake(0.3, 0.4)
	end
end

-- Puff of smoke (wild titan leaving).
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
	})
	P.Sound("Whoosh", p.Position, 0.5)
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
	if p.Kind == "Attack" then
		P.Burst(
			p.Position + look * range * 0.6,
			{ Color = color, Count = 14, Speed = 18, Size = 1.2, Lifetime = 0.4, Gravity = 0 }
		)
		P.Sound("Whoosh", p.Position, 0.5, 0.9 + math.random() * 0.3)
	elseif p.Special == "Slam" then
		task.delay(0.3, function()
			P.Ring(ground, { Color = color, Radius = range * 1.5, Duration = 0.5, Thickness = 0.6 })
			P.Burst(ground, {
				Color = Color3.fromRGB(160, 130, 90),
				Count = 30,
				Speed = 30,
				Size = 2.5,
				LightEmission = 0,
				Gravity = -30,
			})
			P.Sound("Impact", ground, 0.9, 0.7)
			if P.Distance(ground) < range * 3 then
				P.Shake(0.6, 0.35)
			end
		end)
	elseif p.Special == "Charge" then
		for i = 1, 5 do
			task.delay(i * 0.05, function()
				P.Burst(
					ground + look * i * 4,
					{ Color = Color3.fromRGB(170, 140, 100), Count = 8, Speed = 8, Size = 2, LightEmission = 0 }
				)
			end)
		end
		P.Sound("Whoosh", p.Position, 0.8, 0.7)
	elseif p.Special == "Bounce" then
		task.delay(0.6, function()
			P.Ring(ground, { Color = color, Radius = range * 1.4, Duration = 0.5, Thickness = 0.6 })
			P.Burst(ground, { Color = color, Count = 30, Speed = 28, Size = 1.6 })
			P.Sound("Impact", ground, 0.8, 1.1)
		end)
	elseif p.Special == "Breath" then
		for i = 1, 8 do
			task.delay(i * 0.04, function()
				local at = p.Position + look * (range * 2.2) * (i / 8)
				P.Burst(at, {
					Color = ColorSequence.new(Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 60, 20)),
					Count = 10,
					Speed = 6 + i,
					Size = 2 + i * 0.3,
					Lifetime = 0.5,
					Gravity = 6,
					Texture = Textures.Fire,
				})
			end)
		end
		P.Light(p.Position + look * range, { Color = Color3.fromRGB(255, 140, 40), Brightness = 6, Range = range * 2 })
		P.Sound("Whoosh", p.Position, 0.8, 0.6)
	end
end

-- A titan gets hit.
function Presets.Hit(p, P)
	if P.Distance(p.Position) <= FAR then
		P.Burst(
			p.Position,
			{ Color = Color3.fromRGB(255, 240, 200), Count = 12, Speed = 25, Size = 1.2, Lifetime = 0.35 }
		)
		P.FloatText(
			p.Position + Vector3.new(0, 2, 0),
			"-" .. tostring(p.Amount or ""),
			{ Color = Color3.fromRGB(255, 90, 90), Size = 3, Duration = 0.9 }
		)
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
		P.Pillar(p.Position, { Color = RED, Height = 60, Width = 10, Duration = 1 })
		P.Ring(p.Position, { Color = RED, Radius = 25, Duration = 0.7 })
		P.Burst(p.Position + Vector3.new(0, 4, 0), {
			Color = Color3.fromRGB(220, 220, 220),
			Count = 30,
			Speed = 20,
			Size = 4,
			Lifetime = 1.4,
			Gravity = 4,
			LightEmission = 0,
		})
		P.FloatText(p.Position + Vector3.new(0, 10, 0), "K.O.!", { Color = RED, Size = 5, Duration = 1.6 })
		P.Sound("Impact", p.Position, 1, 0.5)
	end
	if P.IsMe(p.Target) then
		P.Flash(RED, 0.6, 0.3)
	end
end

-- Match winner.
function Presets.Victory(p, P)
	if p.Position and P.Distance(p.Position) <= FAR * 2 then
		P.Pillar(p.Position, { Color = GOLD, Height = 140, Width = 16, Duration = 2 })
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
	P.Ring(p.Position, { Color = Color3.fromRGB(90, 170, 255), Radius = 12, Duration = 0.5 })
	P.Burst(p.Position, { Color = Color3.fromRGB(90, 170, 255), Count = 15 })
end

return Presets
