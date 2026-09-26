--[[ Battle page: challenge players, practice vs a bot, join the Titan Clash, watch. ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Battle = require(Shared.Game.Battle)
local CreatureMath = require(Shared.Game.CreatureMath)
local Format = require(Shared.Lib.Format)
local Theme = require(script.Parent.Parent.Theme)

local Page = { Name = "Battle", Title = "⚔️ Battle Arena" }

local refs: { [string]: any } = {}
local context
local playerRows: Frame
local lastPlayers = ""

local function refreshPlayers()
	local others = {}
	for _, p in Players:GetPlayers() do
		if p ~= Players.LocalPlayer then
			table.insert(others, p)
		end
	end
	table.sort(others, function(a, b)
		return a.DisplayName < b.DisplayName
	end)
	local names = {}
	for _, p in others do
		table.insert(names, p.UserId)
	end
	local signature = table.concat(names, ",")
	if signature == lastPlayers then
		return
	end
	lastPlayers = signature
	for _, child in playerRows:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if #others == 0 then
		Theme.Label({
			Size = UDim2.new(1, 0, 0, 40),
			Text = "No other players here yet. Try Practice or wait for a Titan Clash!",
			TextWrapped = true,
			TextColor3 = Theme.Muted,
			Parent = playerRows,
		})
	end
	for i, p in others do
		local r = Theme.Row(playerRows, i, 56)
		local stats = p:FindFirstChild("leaderstats")
		local trophies = stats and stats:FindFirstChild("Trophies")
		Theme.Label({
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.new(1, -170, 0, 40),
			Text = p.DisplayName .. (if trophies then "  🏆 " .. tostring((trophies :: IntValue).Value) else ""),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		local challenge = Theme.Button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(140, 44),
			Text = "⚔️ Challenge",
			BackgroundColor3 = Theme.Red,
			Parent = r,
		})
		challenge.Activated:Connect(function()
			context.Net.Send("Challenge", p.UserId)
		end)
	end
end

function Page.Build(page: ScrollingFrame, ctx)
	context = ctx
	local top = Theme.Row(page, 1, 110)
	refs.Fighter = Theme.Label({
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 30),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = top,
	})
	refs.FighterStats = Theme.Label({
		Position = UDim2.fromOffset(14, 40),
		Size = UDim2.new(1, -28, 0, 24),
		Text = "",
		TextColor3 = Theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = top,
	})
	refs.Status = Theme.Label({
		Position = UDim2.fromOffset(14, 70),
		Size = UDim2.new(1, -28, 0, 26),
		Text = "",
		TextColor3 = Theme.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = top,
	})

	local actions = Theme.Row(page, 2, 70)
	actions.BackgroundTransparency = 1
	Theme.New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 10),
		Parent = actions,
	})
	local practice = Theme.Button({
		Size = UDim2.fromOffset(190, 56),
		Text = "🥊 Practice vs Bot",
		BackgroundColor3 = Theme.Blue,
		Parent = actions,
	})
	practice.Activated:Connect(function()
		ctx.Net.Send("Practice")
		ctx.Window.Close()
	end)
	refs.Join = Theme.Button({
		Size = UDim2.fromOffset(190, 56),
		Text = "⚔️ Join Clash",
		BackgroundColor3 = Theme.Gold,
		Visible = false,
		Parent = actions,
	})
	refs.Join.Activated:Connect(function()
		ctx.Net.Send("JoinClash")
	end)
	local watch = Theme.Button({
		Size = UDim2.fromOffset(150, 56),
		Text = "👀 Watch",
		BackgroundColor3 = Color3.fromRGB(110, 110, 130),
		Parent = actions,
	})
	watch.Activated:Connect(function()
		ctx.Net.Send("Spectate")
		ctx.Window.Close()
	end)

	local info = Theme.Row(page, 3, 70)
	info.BackgroundTransparency = 1
	Theme.Label({
		Size = UDim2.fromScale(1, 1),
		Text = string.format(
			"Duel: winner gets +%d 🏆, cash and %d%% of the loser's food!\nControls: Click / F = Attack  •  Q = Special move",
			GameConfig.Battle.WinTrophies,
			math.round(GameConfig.Battle.WinFoodShare * 100)
		),
		TextWrapped = true,
		TextColor3 = Theme.Muted,
		Parent = info,
	})

	local header = Theme.Row(page, 4, 30)
	header.BackgroundTransparency = 1
	Theme.Label({
		Size = UDim2.fromScale(1, 1),
		Text = "Challenge a player",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})

	playerRows = Theme.New("Frame", {
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 5,
		Parent = page,
	}, { Theme.New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })

	Players.PlayerAdded:Connect(refreshPlayers)
	Players.PlayerRemoving:Connect(function()
		task.defer(refreshPlayers)
	end)
end

function Page.Opened()
	lastPlayers = ""
	refreshPlayers()
end

function Page.Update(state)
	local uid = state.Active
	local creature = uid and state.Creatures[uid]
	if creature then
		local stats = Battle.Stats(creature)
		refs.Fighter.Text = "Your fighter: ⚔️ " .. CreatureMath.DisplayName(creature) .. " Lv." .. creature.Level
		refs.FighterStats.Text = string.format(
			"❤️ %s HP   ⚔️ %s ATK   ✨ %s   🏆 %d trophies   (%d wins)",
			Format.Number(stats.MaxHP),
			Format.Number(stats.Attack),
			Battle.SpecialFor(creature.Id).Name,
			state.Trophies,
			state.Stats.BattlesWon
		)
	else
		refs.Fighter.Text = "You need a " .. GameConfig.CreatureName .. " to fight!"
		refs.FighterStats.Text = ""
	end
	local battle = context.Battle
	local clash = context.Clash
	local now = Workspace:GetServerTimeNow()
	if clash and clash.EndsAt > now then
		refs.Status.Text = "⚔️ Titan Clash starting in " .. Format.Time(clash.EndsAt - now) .. "!"
		refs.Join.Visible = true
	elseif battle and battle.Phase and battle.Phase ~= "None" then
		refs.Status.Text = "🔴 Arena busy: " .. (battle.Mode or "fight") .. " in progress"
		refs.Join.Visible = false
	else
		refs.Status.Text = "🟢 The arena is free"
		refs.Join.Visible = false
	end
end

return Page
