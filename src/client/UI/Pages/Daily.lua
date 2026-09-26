local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DailyRewards = require(Shared.Config.DailyRewards)
local Progress = require(Shared.Game.Progress)
local Theme = require(script.Parent.Parent.Theme)

local Page = { Name = "Daily", Title = "📅 Daily Rewards" }

local tiles = {}
local claim: TextButton
local status: TextLabel

function Page.Build(page: ScrollingFrame, ctx)
	local grid = Theme.Row(page, 1, 250)
	grid.BackgroundTransparency = 1
	Theme.New("UIGridLayout", {
		CellSize = UDim2.fromOffset(145, 115),
		CellPadding = UDim2.fromOffset(8, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	for i, day in DailyRewards do
		local tile = Theme.New(
			"Frame",
			{ BackgroundColor3 = Theme.Panel, LayoutOrder = i, Parent = grid },
			{ Theme.Corner(12) }
		)
		local stroke = Theme.Stroke(Color3.new(0, 0, 0), 2)
		stroke.Parent = tile
		Theme.Label({
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.new(1, -12, 0, 26),
			Text = "Day " .. i,
			TextColor3 = Theme.Gold,
			Parent = tile,
		})
		Theme.Label({
			Position = UDim2.fromOffset(6, 36),
			Size = UDim2.new(1, -12, 1, -42),
			Text = Progress.DescribeReward(day.Reward, 0),
			TextWrapped = true,
			Parent = tile,
		})
		tiles[i] = { Tile = tile, Stroke = stroke }
	end
	local bottom = Theme.Row(page, 2, 80)
	bottom.BackgroundTransparency = 1
	status = Theme.Label({ Size = UDim2.new(1, 0, 0, 26), Text = "", TextColor3 = Theme.Muted, Parent = bottom })
	claim = Theme.Button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 30),
		Size = UDim2.fromOffset(240, 50),
		Text = "Claim",
		BackgroundColor3 = Theme.Green,
		Parent = bottom,
	})
	claim.Activated:Connect(function()
		ctx.Net.Send("ClaimDaily")
	end)
end

function Page.CanClaim(state): (boolean, number)
	return Progress.DailyStatus(state.Daily, Progress.Day(state.ServerTime or os.time()))
end

function Page.Update(state)
	local canClaim, index = Page.CanClaim(state)
	for i, tile in tiles do
		local claimedAlready = i < index or (not canClaim and i == index)
		tile.Tile.BackgroundColor3 = if claimedAlready then Color3.fromRGB(45, 80, 55) else Theme.Panel
		tile.Stroke.Color = if i == index then Theme.Gold else Color3.new(0, 0, 0)
		tile.Stroke.Thickness = if i == index then 4 else 2
	end
	claim.Text = if canClaim then "Claim Day " .. index .. "!" else "Come back tomorrow"
	claim.BackgroundColor3 = if canClaim then Theme.Green else Color3.fromRGB(90, 90, 100)
	status.Text = "Streak: " .. state.Daily.Streak .. " day(s). Miss a day and it starts over!"
end

return Page
