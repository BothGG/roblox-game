local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Progress = require(Shared.Game.Progress)
local Format = require(Shared.Lib.Format)
local Theme = require(script.Parent.Parent.Theme)

local Page = { Name = "Quests", Title = "📜 Daily Quests" }

local rows = {}
local timer: TextLabel

function Page.Build(page: ScrollingFrame, ctx)
	local header = Theme.Row(page, 0, 34)
	header.BackgroundTransparency = 1
	timer = Theme.Label({ Size = UDim2.fromScale(1, 1), Text = "", TextColor3 = Theme.Muted, Parent = header })
	for i = 1, 3 do
		local r = Theme.Row(page, i, 96)
		local text = Theme.Label({
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.new(1, -170, 0, 28),
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		local bar, fill =
			Theme.ProgressBar(r, { Position = UDim2.fromOffset(14, 42), Size = UDim2.new(1, -170, 0, 16) })
		local count = Theme.Label({ Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 3, Parent = bar })
		local reward = Theme.Label({
			Position = UDim2.fromOffset(14, 64),
			Size = UDim2.new(1, -170, 0, 22),
			Text = "",
			TextColor3 = Theme.Gold,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		local claim = Theme.Button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(130, 54),
			Text = "Claim",
			Parent = r,
		})
		claim.Activated:Connect(function()
			ctx.Net.Send("ClaimQuest", i)
		end)
		rows[i] = { Row = r, Text = text, Fill = fill, Count = count, Reward = reward, Claim = claim }
	end
end

function Page.Update(state)
	local now = state.ServerTime or math.floor(Workspace:GetServerTimeNow())
	timer.Text = "New quests in " .. Format.Time(Progress.SecondsUntilNextDay(now))
	local income = state.Income or 0
	for i, row in rows do
		local quest = state.Quests.List[i]
		row.Row.Visible = quest ~= nil
		if quest then
			local def = Progress.QuestDefs[quest.Id]
			row.Text.Text = Progress.QuestText(quest)
			row.Fill.Size = UDim2.fromScale(math.clamp(quest.Progress / quest.Goal, 0, 1), 1)
			row.Count.Text = Format.Number(quest.Progress) .. " / " .. Format.Number(quest.Goal)
			row.Reward.Text = if def then "Reward: " .. Progress.DescribeReward(def.Reward, income) else ""
			local done = quest.Progress >= quest.Goal
			row.Claim.Text = if quest.Claimed then "Claimed ✓" elseif done then "Claim!" else "In progress"
			row.Claim.BackgroundColor3 = if done and not quest.Claimed then Theme.Green else Color3.fromRGB(90, 90, 100)
		end
	end
end

return Page
