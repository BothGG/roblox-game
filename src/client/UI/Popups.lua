--[[
	Popups: cards in the middle of the screen.
	  Popups.Reward(title, text)             -- queued "you got X" cards
	  Popups.DuelRequest(info, onAnswer)     -- Accept / Decline with a timer
	  Popups.ClashInvite(endsAt, onJoin)     -- JOIN button with a timer
	  Popups.Offline(amount, seconds)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Lib.Format)
local Fx = require(Shared.Fx)
local Theme = require(script.Parent.Theme)

local Popups = {}

local gui: ScreenGui
local rewardQueue = {}
local showingReward = false

function Popups.Start()
	gui = Theme.ScreenGui("Popups", 25)
end

local function card(width: number, height: number, color: Color3, position: UDim2?): Frame
	local frame = Theme.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position or UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = Theme.Background,
		Parent = gui,
	}, { Theme.Corner(18), Theme.Stroke(color, 4) })
	Theme.AutoScale(frame)
	Fx.Primitives.Pop(frame, 0.2)
	return frame
end

local function closeCard(frame: Frame)
	local t = TweenService:Create(frame, TweenInfo.new(0.2), { Position = frame.Position + UDim2.fromScale(0, 0.05) })
	t:Play()
	t.Completed:Wait()
	frame:Destroy()
end

local function showNextReward()
	if showingReward or #rewardQueue == 0 then
		return
	end
	showingReward = true
	local info = table.remove(rewardQueue, 1)
	local frame = card(420, 190, Theme.Gold)
	Theme.Label({
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.new(1, -24, 0, 44),
		Text = info.Title,
		TextColor3 = Theme.Gold,
		Parent = frame,
	})
	Theme.Label({
		Position = UDim2.fromOffset(12, 62),
		Size = UDim2.new(1, -24, 0, 56),
		Text = info.Text,
		TextWrapped = true,
		Parent = frame,
	})
	local ok = Theme.Button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(160, 48),
		Text = "Nice!",
		BackgroundColor3 = Theme.Green,
		Parent = frame,
	})
	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		closeCard(frame)
		showingReward = false
		showNextReward()
	end
	ok.Activated:Connect(finish)
	task.delay(4, finish)
end

function Popups.Reward(title: string, text: string)
	table.insert(rewardQueue, { Title = title, Text = text })
	showNextReward()
end

function Popups.DuelRequest(info, onAnswer: (boolean) -> ())
	local frame = card(440, 230, Theme.Red, UDim2.fromScale(0.5, 0.35))
	Theme.Label({
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.new(1, -24, 0, 40),
		Text = "⚔️ DUEL CHALLENGE!",
		TextColor3 = Theme.Red,
		Parent = frame,
	})
	Theme.Label({
		Position = UDim2.fromOffset(12, 56),
		Size = UDim2.new(1, -24, 0, 60),
		Text = string.format(
			"%s (🏆 %d) wants to fight with\n%s Lv.%d",
			info.FromName,
			info.Trophies or 0,
			info.Titan,
			info.Level
		),
		TextWrapped = true,
		Parent = frame,
	})
	local timer = Theme.Label({
		Position = UDim2.fromOffset(12, 120),
		Size = UDim2.new(1, -24, 0, 26),
		Text = "",
		TextColor3 = Theme.Muted,
		Parent = frame,
	})
	local answered = false
	local function answer(accept: boolean)
		if answered then
			return
		end
		answered = true
		onAnswer(accept)
		closeCard(frame)
	end
	local accept = Theme.Button({
		Position = UDim2.new(0, 20, 1, -66),
		Size = UDim2.new(0.5, -30, 0, 52),
		Text = "✅ Accept",
		BackgroundColor3 = Theme.Green,
		Parent = frame,
	})
	local decline = Theme.Button({
		Position = UDim2.new(0.5, 10, 1, -66),
		Size = UDim2.new(0.5, -30, 0, 52),
		Text = "❌ Decline",
		BackgroundColor3 = Theme.Red,
		Parent = frame,
	})
	accept.Activated:Connect(function()
		answer(true)
	end)
	decline.Activated:Connect(function()
		answer(false)
	end)
	Fx.Primitives.Sound("Alarm", nil, 0.5)
	task.spawn(function()
		local timeout = info.Timeout or 15
		for left = timeout, 1, -1 do
			if answered then
				return
			end
			timer.Text = "Answer in " .. left .. "s"
			task.wait(1)
		end
		if not answered then
			answered = true
			closeCard(frame)
		end
	end)
end

function Popups.ClashInvite(endsAt: number, onJoin: () -> ())
	local frame = card(420, 200, Theme.Gold, UDim2.fromScale(0.5, 0.3))
	Theme.Label({
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.new(1, -24, 0, 44),
		Text = "⚔️ TITAN CLASH!",
		TextColor3 = Theme.Gold,
		Parent = frame,
	})
	Theme.Label({
		Position = UDim2.fromOffset(12, 56),
		Size = UDim2.new(1, -24, 0, 30),
		Text = "Everyone vs everyone. Winner takes 🏆 and a Star Food!",
		TextWrapped = true,
		Parent = frame,
	})
	local joined = false
	local closed = false
	local join = Theme.Button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(220, 56),
		Text = "JOIN",
		BackgroundColor3 = Theme.Red,
		Parent = frame,
	})
	join.Activated:Connect(function()
		if not joined then
			joined = true
			join.Text = "Joined ✓"
			join.BackgroundColor3 = Theme.Green
			onJoin()
		end
	end)
	task.spawn(function()
		while not closed do
			local left = endsAt - Workspace:GetServerTimeNow()
			if left <= 0 then
				closed = true
				closeCard(frame)
				return
			end
			if not joined then
				join.Text = "JOIN (" .. math.ceil(left) .. "s)"
			end
			task.wait(0.25)
		end
	end)
end

function Popups.Offline(amount: number, seconds: number)
	Popups.Reward(
		"💤 Welcome back!",
		string.format("Your titans earned %s while you were away (%s).", Format.Money(amount), Format.Time(seconds))
	)
end

return Popups
