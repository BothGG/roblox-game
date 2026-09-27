--[[ Titans page: your titans, their battle stats, choose your fighter, sell. ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local GameConfig = require(Shared.Config.GameConfig)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Battle = require(Shared.Game.Battle)
local CreatureMath = require(Shared.Game.CreatureMath)
local Format = require(Shared.Lib.Format)
local Theme = require(script.Parent.Parent.Theme)

local Page = { Name = "Titans", Title = "🐾 Your " .. GameConfig.CreatureNamePlural }

local container: ScrollingFrame
local context
local lastSignature = ""
local confirmSell: string? = nil

local function rebuild(state)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local uids = {}
	for uid in state.Creatures do
		table.insert(uids, uid)
	end
	table.sort(uids, function(a, b)
		local ca, cb = state.Creatures[a], state.Creatures[b]
		if ca.Level ~= cb.Level then
			return ca.Level > cb.Level
		end
		return a < b
	end)
	local header = Theme.Row(container, 0, 34)
	header.BackgroundTransparency = 1
	Theme.Label({
		Size = UDim2.fromScale(1, 1),
		Text = string.format("%d / %d pens used  •  ⚔️ = your fighter in battles", #uids, state.Slots),
		TextColor3 = Theme.Muted,
		Parent = header,
	})
	for i, uid in uids do
		local creature = state.Creatures[uid]
		local def = Creatures[creature.Id]
		local stats = Battle.Stats(creature)
		local special = Battle.SpecialFor(creature.Id)
		local active = state.Active == uid
		local color = if creature.Mutation then Mutations[creature.Mutation].Color else Rarities[def.Rarity].Color
		local r = Theme.Row(container, i, 128)
		if active then
			Theme.Stroke(Theme.Gold, 3).Parent = r
		end
		Theme.Label({
			Position = UDim2.fromOffset(14, 6),
			Size = UDim2.new(1, -250, 0, 30),
			Text = (if active then "⚔️ " else "")
				.. CreatureMath.DisplayName(creature)
				.. "  Lv."
				.. creature.Level,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		Theme.Label({
			Position = UDim2.fromOffset(14, 38),
			Size = UDim2.new(1, -250, 0, 22),
			Text = string.format(
				"❤️ %s   ⚔️ %s   👟 %d   ✨ %s",
				Format.Number(stats.MaxHP),
				Format.Number(stats.Attack),
				stats.Speed,
				special.Name
			),
			TextColor3 = Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		Theme.Label({
			Position = UDim2.fromOffset(14, 62),
			Size = UDim2.new(1, -250, 0, 20),
			Text = string.format("%s/s base • %s", Format.Money(CreatureMath.BaseIncome(creature)), def.Rarity),
			TextColor3 = Theme.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		local fight = Theme.Button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -128, 0.5, 0),
			Size = UDim2.fromOffset(110, 50),
			Text = if active then "Fighter ✓" else "⚔️ Fight",
			BackgroundColor3 = if active then Color3.fromRGB(90, 90, 100) else Theme.Gold,
			Parent = r,
		})
		fight.Activated:Connect(function()
			if not active then
				context.Net.Send("Equip", uid)
			end
		end)
		local sellText = if confirmSell == uid
			then "Sure? " .. Format.Money(CreatureMath.SellPrice(creature, state.Rebirths))
			else "Sell"
		local sell = Theme.Button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(106, 50),
			Text = sellText,
			BackgroundColor3 = Theme.Red,
			Parent = r,
		})
		-- Ride / follow buttons (Phase 1)
		local following = state.Following ~= nil and state.Following[uid] == true
		local ride = Theme.Button({
			Position = UDim2.fromOffset(14, 88),
			Size = UDim2.fromOffset(110, 34),
			Text = "🐎 Ride",
			BackgroundColor3 = Color3.fromRGB(70, 150, 240),
			Parent = r,
		})
		ride.Activated:Connect(function()
			context.Net.Send("Ride", uid)
			context.Window.Close()
		end)
		local follow = Theme.Button({
			Position = UDim2.fromOffset(132, 88),
			Size = UDim2.fromOffset(130, 34),
			Text = if following then "🏠 Send home" else "🐾 Follow me",
			BackgroundColor3 = if following then Color3.fromRGB(110, 110, 140) else Color3.fromRGB(80, 190, 90),
			Parent = r,
		})
		follow.Activated:Connect(function()
			context.Net.Send("FollowerCommand", "Follow", uid)
		end)
		sell.Activated:Connect(function()
			if confirmSell == uid then
				confirmSell = nil
				context.Net.Send("SellTitan", uid)
			else
				confirmSell = uid
				lastSignature = ""
				rebuild(state)
			end
		end)
	end
end

function Page.Build(page: ScrollingFrame, ctx)
	container = page
	context = ctx
end

function Page.Update(state)
	local parts = { tostring(state.Active), tostring(state.Slots), tostring(confirmSell) }
	for uid in state.Following or {} do
		table.insert(parts, "f" .. uid)
	end
	for uid, creature in state.Creatures do
		table.insert(parts, uid .. ":" .. creature.Level .. ":" .. tostring(creature.Mutation))
	end
	table.sort(parts)
	local signature = table.concat(parts, "|")
	if signature ~= lastSignature then
		lastSignature = signature
		rebuild(state)
	end
end

function Page.Opened()
	confirmSell = nil
	lastSignature = ""
end

return Page
