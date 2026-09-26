--[[
	EventService: random server events that keep things fresh.

	Add a new event: write a function in EVENTS below. It runs, and when it
	returns the event is over. Then the next one is picked after a delay.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)

local EventService = {}

local Food, World

local EVENTS = {}

function EVENTS.MeteorFeast()
	Net.Announce("☄️ METEOR FEAST", "Food is falling from the sky! Run to the middle!", Color3.fromRGB(255, 150, 50))
	task.wait(3)
	Food:MeteorShower(GameConfig.Events.MeteorFoodCount)
	task.wait(GameConfig.Events.MeteorFoodCount * 0.15 + 3)
end

function EVENTS.BloodMoon()
	local duration = GameConfig.Events.BloodMoonDuration
	Net.Announce(
		"🩸 BLOOD MOON",
		"Kaiju grow " .. GameConfig.Events.BloodMoonGrowthMult .. "x faster... but stealing is faster too!",
		Color3.fromRGB(255, 50, 50)
	)
	Workspace:SetAttribute("GrowthMult", GameConfig.Events.BloodMoonGrowthMult)
	Workspace:SetAttribute("EventEndsAt", Workspace:GetServerTimeNow() + duration)

	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "BloodMoonTint"
	tint.TintColor = Color3.new(1, 1, 1)
	tint.Parent = Lighting
	local info = TweenInfo.new(3)
	local oldClock = Lighting.ClockTime
	TweenService:Create(tint, info, { TintColor = Color3.fromRGB(255, 150, 150) }):Play()
	TweenService:Create(Lighting, info, { ClockTime = 0 }):Play()
	for _, plot in World.Plots do
		plot.StealPrompt.HoldDuration = GameConfig.Steal.HoldTime / 2
	end

	task.wait(duration)

	Workspace:SetAttribute("GrowthMult", nil)
	TweenService:Create(tint, info, { TintColor = Color3.new(1, 1, 1) }):Play()
	TweenService:Create(Lighting, info, { ClockTime = oldClock }):Play()
	for _, plot in World.Plots do
		plot.StealPrompt.HoldDuration = GameConfig.Steal.HoldTime
	end
	Net.Announce("🌅 The Blood Moon is over", "", Color3.fromRGB(255, 200, 150))
	task.wait(3)
	tint:Destroy()
end

function EventService:Init(services)
	Food = services.FoodService
	World = services.WorldService
end

function EventService:Start()
	task.spawn(function()
		task.wait(GameConfig.Events.FirstDelay)
		while true do
			self:RunRandom()
			task.wait(GameConfig.Events.Interval)
		end
	end)
end

function EventService:Run(name: string)
	local event = EVENTS[name]
	if not event then
		warn("[EventService] Unknown event", name)
		return
	end
	Workspace:SetAttribute("ActiveEvent", name)
	local ok, err = pcall(event)
	if not ok then
		warn("[EventService] Event", name, "failed:", err)
	end
	Workspace:SetAttribute("ActiveEvent", nil)
	Workspace:SetAttribute("EventEndsAt", nil)
end

function EventService:RunRandom()
	local names = {}
	for name in EVENTS do
		table.insert(names, name)
	end
	self:Run(names[math.random(1, #names)])
end

return EventService
