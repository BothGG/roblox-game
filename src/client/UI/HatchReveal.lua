--[[
	HatchReveal: the egg-opening / catch reveal.
	Egg: shakes (more for rarer titan) -> flash -> card with the result.
	Tame (info.Source == "Tame"): straight to the card, titled "TAMED!".
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Eggs = require(Shared.Config.Eggs)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local CreatureMath = require(Shared.Game.CreatureMath)
local Fx = require(Shared.Fx)
local Theme = require(script.Parent.Theme)

local HatchReveal = {}

local gui: ScreenGui
local queue = {}
local playing = false

function HatchReveal.Start()
	gui = Theme.ScreenGui("HatchReveal", 30)
	gui.IgnoreGuiInset = true
end

local function play(info)
	local def = Creatures[info.CreatureId]
	local rarity = Rarities[def.Rarity]
	local egg = Eggs[info.EggId]
	local mutation = info.Mutation and Mutations[info.Mutation]
	local color = if mutation then mutation.Color else rarity.Color

	local dim = Theme.New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	TweenService:Create(dim, TweenInfo.new(0.3), { BackgroundTransparency = 0.45 }):Play()

	local holder = Theme.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 420),
		BackgroundTransparency = 1,
		Parent = dim,
	})
	Theme.AutoScale(holder)

	local isCatch = info.Source == "Tame"
	local eggFrame = Theme.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(150, 190),
		BackgroundColor3 = egg and egg.Color or Color3.new(1, 1, 1),
		Parent = holder,
	}, { Theme.Corner(75), Theme.Stroke(Color3.new(0, 0, 0), 4) })

	-- Shake: more shakes for rarer results builds suspense.
	local shakes = if isCatch then 0 else 2 + rarity.Order
	for i = 1, shakes do
		local speed = math.max(0.05, 0.16 - i * 0.012)
		local angle = if i % 2 == 0 then 15 else -15
		local t = TweenService:Create(eggFrame, TweenInfo.new(speed), { Rotation = angle })
		t:Play()
		t.Completed:Wait()
	end
	eggFrame:Destroy()

	Fx.Play("HatchReveal", { Color = color, RarityOrder = rarity.Order + (if mutation then 2 else 0) })

	local card = Theme.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 260),
		BackgroundColor3 = Theme.Background,
		Parent = holder,
	}, { Theme.Corner(20), Theme.Stroke(color, 5) })
	Theme.Label({
		Position = UDim2.fromOffset(10, 16),
		Size = UDim2.new(1, -20, 0, 34),
		Text = (if isCatch then "🎯 TAMED!  " else "") .. string.upper(def.Rarity),
		TextColor3 = rarity.Color,
		Parent = card,
	})
	local nameLabel = Theme.Label({
		Position = UDim2.fromOffset(10, 58),
		Size = UDim2.new(1, -20, 0, 70),
		Text = CreatureMath.DisplayName({ Id = info.CreatureId, Level = 1, Xp = 0, Mutation = info.Mutation }),
		TextColor3 = color,
		Parent = card,
	})
	Theme.Label({
		Position = UDim2.fromOffset(10, 136),
		Size = UDim2.new(1, -20, 0, 30),
		Text = def.Description,
		TextColor3 = Theme.Muted,
		Parent = card,
	})
	Theme.Label({
		Position = UDim2.fromOffset(10, 176),
		Size = UDim2.new(1, -20, 0, 28),
		Text = CreatureMath.DescribeTraits(info.CreatureId),
		TextColor3 = Theme.Green,
		Parent = card,
	})
	if mutation then
		Theme.Label({
			Position = UDim2.fromOffset(10, 212),
			Size = UDim2.new(1, -20, 0, 30),
			Text = "🧬 " .. mutation.Name .. " mutation! x" .. mutation.IncomeMult .. " income",
			TextColor3 = mutation.Color,
			Parent = card,
		})
	end
	Fx.Primitives.Pop(card, 0.4)
	Fx.Primitives.Pop(nameLabel, 0.3)

	task.wait(2.6)
	TweenService:Create(dim, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(card, TweenInfo.new(0.3), { Position = UDim2.fromScale(0.5, 1.5) }):Play()
	task.wait(0.3)
	dim:Destroy()
end

function HatchReveal.Show(info)
	table.insert(queue, info)
	if playing then
		return
	end
	playing = true
	task.spawn(function()
		while #queue > 0 do
			local ok, err = pcall(play, table.remove(queue, 1))
			if not ok then
				warn("[HatchReveal]", err)
			end
		end
		playing = false
	end)
end

return HatchReveal
