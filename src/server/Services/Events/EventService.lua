--[[
	EventService: random server events that keep things fresh.

	  TitanClash  - free-for-all battle in the arena (BattleService)
	  WildRush    - lots of wild titans appear, rare ones 3x more likely
	  MeteorFeast - food falls on the fields
	  BloodMoon   - 2x growth, faster stealing

	Add a new event: write a function in EVENTS below. It runs, and when it
	returns the event is over. The next one is picked after a delay.
	Admins can start any event from the admin panel.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Log = require(Shared.Lib.Log)
local Net = require(Shared.Net)

local log = Log.new("EventService")

local EventService = {
	Priority = 60,
	Running = nil :: string?,
}

local Food, Base, Battle, Wild

local EVENTS = {}

function EVENTS.TitanClash()
	Battle:RunClash()
end

function EVENTS.WildRush()
	local duration = GameConfig.Events.WildRushDuration
	Net.Announce(
		"🌟 WILD RUSH",
		"Wild titans are everywhere and rare ones are 3x more common! Go tame them!",
		Color3.fromRGB(120, 255, 150)
	)
	Workspace:SetAttribute("EventEndsAt", Workspace:GetServerTimeNow() + duration)
	Wild:Rush(duration)
end

function EVENTS.MeteorFeast()
	Net.Announce("☄️ METEOR FEAST", "Food is falling on the fields! Run!", Color3.fromRGB(255, 150, 50))
	task.wait(3)
	Food:MeteorShower(GameConfig.Events.MeteorFoodCount)
	task.wait(GameConfig.Events.MeteorFoodCount * 0.15 + 3)
end

function EVENTS.BloodMoon()
	local duration = GameConfig.Events.BloodMoonDuration
	Net.Announce(
		"🩸 BLOOD MOON",
		"Titans grow " .. GameConfig.Events.BloodMoonGrowthMult .. "x faster... but stealing is faster too!",
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
	for _, plot in Base.Plots do
		plot.StealPrompt.HoldDuration = GameConfig.Steal.HoldTime / 2
	end

	task.wait(duration)

	Workspace:SetAttribute("GrowthMult", nil)
	TweenService:Create(tint, info, { TintColor = Color3.new(1, 1, 1) }):Play()
	TweenService:Create(Lighting, info, { ClockTime = oldClock }):Play()
	for _, plot in Base.Plots do
		plot.StealPrompt.HoldDuration = GameConfig.Steal.HoldTime
	end
	Net.Announce("🌅 The Blood Moon is over", "", Color3.fromRGB(255, 200, 150))
	task.wait(3)
	tint:Destroy()
end

-- The Titan Clash comes up more often: it's the main event.
local ROTATION = { "TitanClash", "WildRush", "TitanClash", "MeteorFeast", "TitanClash", "BloodMoon" }

function EventService:Init(registry)
	Food = registry.FoodService
	Base = registry.BaseService
	Battle = registry.BattleService
	Wild = registry.WildService
end

function EventService:Start()
	task.spawn(function()
		task.wait(GameConfig.Events.FirstDelay)
		local index = math.random(1, #ROTATION)
		while true do
			self:Run(ROTATION[index])
			index = index % #ROTATION + 1
			task.wait(GameConfig.Events.Interval)
		end
	end)
end

function EventService:Names(): { string }
	local names = {}
	for name in EVENTS do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

function EventService:Run(name: string): boolean
	local event = EVENTS[name]
	if not event then
		log:Warn("unknown event", name)
		return false
	end
	if self.Running then
		return false
	end
	self.Running = name
	Workspace:SetAttribute("ActiveEvent", name)
	local ok, err = pcall(event)
	if not ok then
		log:Error("event", name, "failed:", err)
	end
	Workspace:SetAttribute("ActiveEvent", nil)
	Workspace:SetAttribute("EventEndsAt", nil)
	self.Running = nil
	return true
end

return EventService
