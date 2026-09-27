--[[
	UIController: starts every UI module and connects them to state and
	server messages (notifications, rewards, duel requests, clash invites).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Fx = require(Shared.Fx)
local Progress = require(Shared.Game.Progress)
local ClientState = require(script.Parent.Parent.State.ClientState)

local UI = script.Parent.Parent:WaitForChild("UI")
local Toasts = require(UI.Toasts)
local Hud = require(UI.Hud)
local Window = require(UI.Window)
local Popups = require(UI.Popups)
local HatchReveal = require(UI.HatchReveal)

local UIController = {
	Priority = 10,
}

-- Shared with pages (Battle page reads Battle / Clash).
local ctx = {
	Net = Net,
	ClientState = ClientState,
	Window = Window,
	Battle = nil :: any,
	Clash = nil :: any,
}

local PAGES =
	{ "Eggs", "Food", "Titans", "Breed", "Battle", "Quests", "Daily", "Index", "Store", "Rebirth", "Settings", "Admin" }

local function updateBadges(state)
	local canClaimDaily = Progress.DailyStatus(state.Daily, Progress.Day(state.ServerTime or os.time()))
	Hud.SetBadge("Daily", canClaimDaily)
	local questReady = false
	for _, quest in state.Quests.List do
		if quest.Progress >= quest.Goal and not quest.Claimed then
			questReady = true
		end
	end
	Hud.SetBadge("Quests", questReady)
	Hud.SetBadge("Index", #Progress.ClaimableMilestones(state.Index, state.IndexClaimed) > 0)
end

function UIController:Start()
	Toasts.Start()
	Window.Start()
	for _, name in PAGES do
		Window.AddPage(require(UI.Pages[name]), ctx)
	end
	Hud.Start(Window)
	Popups.Start()
	HatchReveal.Start()

	local first = true
	ClientState.Changed:Connect(function(state)
		Fx.Primitives.SoundEnabled = state.Settings.Sfx ~= false
		Hud.Update(state)
		Window.Update(state)
		updateBadges(state)
		if first then
			first = false
			-- Daily reward ready? Show it right away.
			if
				Progress.DailyStatus(state.Daily, Progress.Day(state.ServerTime or os.time()))
				and state.Tutorial == 0
			then
				task.delay(2, Window.Open, "Daily")
			end
		end
	end)

	Net.Listen("Notify", function(message)
		Toasts.Notify(message.Text, message.Color)
	end)
	Net.Listen("Announce", function(message)
		Toasts.Banner(message.Title, message.Text, message.Color)
	end)
	Net.Listen("Hatched", function(info)
		HatchReveal.Show(info)
	end)
	Net.Listen("Rewarded", function(info)
		Popups.Reward(info.Title, info.Text)
	end)
	Net.Listen("OfflineEarnings", function(info)
		Popups.Offline(info.Amount, info.Seconds)
	end)
	Net.Listen("DuelRequest", function(info)
		Popups.DuelRequest(info, function(accept)
			Net.Send("DuelRespond", info.FromUserId, accept)
		end)
	end)
	Net.Listen("ClashInvite", function(info)
		ctx.Clash = info
		Popups.ClashInvite(info.EndsAt, function()
			Net.Send("JoinClash")
		end)
	end)
	Net.Listen("BattleState", function(state)
		ctx.Battle = state
		if state.Phase ~= "None" then
			ctx.Clash = nil
		end
	end)
end

return UIController
