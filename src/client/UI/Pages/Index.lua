local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local IndexConfig = require(Shared.Config.Index)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Progress = require(Shared.Game.Progress)
local Theme = require(script.Parent.Parent.Theme)

local Page = { Name = "Index", Title = "📖 Titan Index" }

local header: TextLabel
local milestoneRows = {}
local tiles = {}

local MUTATION_ORDER = { "Lava", "Crystal", "Shadow", "Golden", "Rainbow" }

function Page.Build(page: ScrollingFrame, ctx)
	local top = Theme.Row(page, 0, 34)
	top.BackgroundTransparency = 1
	header = Theme.Label({ Size = UDim2.fromScale(1, 1), Text = "", Parent = top })

	for i, milestone in IndexConfig.Milestones do
		local r = Theme.Row(page, i, 52)
		local label = Theme.Label({
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -160, 1, -12),
			Text = string.format("Collect %d  →  %s", milestone.Count, Progress.DescribeReward(milestone.Reward, 0)),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		local claim = Theme.Button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(130, 40),
			Text = "",
			Parent = r,
		})
		claim.Activated:Connect(function()
			ctx.Net.Send("ClaimIndex", i)
		end)
		milestoneRows[i] = { Label = label, Claim = claim, Count = milestone.Count }
	end

	local grid = Theme.New("Frame", {
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 100,
		Parent = page,
	}, {
		Theme.New("UIGridLayout", {
			CellSize = UDim2.fromOffset(145, 74),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local ids = {}
	for id in Creatures do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		local ra, rb = Rarities[Creatures[a].Rarity].Order, Rarities[Creatures[b].Rarity].Order
		if ra ~= rb then
			return ra < rb
		end
		return a < b
	end)
	for i, id in ids do
		local tile = Theme.New(
			"Frame",
			{ BackgroundColor3 = Theme.Panel, LayoutOrder = i, Parent = grid },
			{ Theme.Corner(10) }
		)
		local name = Theme.Label({
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.new(1, -8, 0, 30),
			Text = "???",
			Parent = tile,
		})
		local dots = {}
		for m, mutationId in MUTATION_ORDER do
			dots[mutationId] = Theme.New("Frame", {
				Position = UDim2.new(0, 12 + (m - 1) * 26, 0, 42),
				Size = UDim2.fromOffset(20, 20),
				BackgroundColor3 = Color3.fromRGB(30, 30, 40),
				Parent = tile,
			}, { Theme.Corner(10) })
		end
		tiles[id] = { Name = name, Dots = dots }
	end
end

function Page.Update(state)
	header.Text = string.format("Collected %d / %d", state.IndexCount, Progress.IndexTotal())
	local claimable = Progress.ClaimableMilestones(state.Index, state.IndexClaimed)
	for i, row in milestoneRows do
		if state.IndexClaimed[tostring(i)] then
			row.Claim.Text = "Claimed ✓"
			row.Claim.BackgroundColor3 = Color3.fromRGB(70, 110, 80)
		elseif table.find(claimable, i) then
			row.Claim.Text = "Claim!"
			row.Claim.BackgroundColor3 = Theme.Green
		else
			row.Claim.Text = state.IndexCount .. "/" .. row.Count
			row.Claim.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
		end
	end
	for id, tile in tiles do
		local def = Creatures[id]
		local owned = state.Index[id] == true
		tile.Name.Text = if owned then def.Name else "???"
		tile.Name.TextColor3 = if owned then Rarities[def.Rarity].Color else Theme.Muted
		for mutationId, dot in tile.Dots do
			dot.BackgroundColor3 = if state.Index[id .. ":" .. mutationId]
				then Mutations[mutationId].Color
				else Color3.fromRGB(30, 30, 40)
		end
	end
end

return Page
