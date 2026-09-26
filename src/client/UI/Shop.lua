--[[
	Shop: the pop-up window with Eggs, Food and Rebirth pages.
	Shop.Open("Eggs" | "Food" | "Rebirth"), Shop.Close()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Eggs = require(Shared.Config.Eggs)
local Foods = require(Shared.Config.Foods)
local GameConfig = require(Shared.Config.GameConfig)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local CreatureMath = require(Shared.CreatureMath)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)
local Theme = require(script.Parent.Theme)

local Shop = {}

local window: Frame
local titleLabel: TextLabel
local pages: { [string]: ScrollingFrame } = {}
local priceButtons: { { Button: TextButton, Price: () -> number } } = {}
local rebirthRefs: { [string]: any } = {}
local state: any = nil

local TITLES = {
	Eggs = "🥚 Egg Shop",
	Food = "🍖 Food Shop",
	Rebirth = "🌟 Rebirth",
}

local function page(name: string): ScrollingFrame
	local scroll = Theme.New("ScrollingFrame", {
		Name = name,
		Position = UDim2.fromOffset(12, 64),
		Size = UDim2.new(1, -24, 1, -76),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Visible = false,
		Parent = window,
	}, {
		Theme.New("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	pages[name] = scroll
	return scroll
end

local function row(parent: Instance, order: number, height: number): Frame
	return Theme.New("Frame", {
		Size = UDim2.new(1, -8, 0, height),
		BackgroundColor3 = Theme.Panel,
		LayoutOrder = order,
		Parent = parent,
	}, { Theme.Corner(12) })
end

local function buildEggs()
	local p = page("Eggs")
	for i, eggId in Eggs.Order do
		local egg = Eggs[eggId]
		local r = row(p, i, 120)
		Theme.New("Frame", {
			Position = UDim2.fromOffset(12, 18),
			Size = UDim2.fromOffset(64, 84),
			BackgroundColor3 = egg.Color,
			Parent = r,
		}, { Theme.Corner(32), Theme.Stroke(Color3.new(0, 0, 0), 2) })
		Theme.Label({
			Position = UDim2.fromOffset(90, 8),
			Size = UDim2.new(1, -230, 0, 30),
			Text = egg.Name,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		local total = 0
		for _, odd in egg.Odds do
			total += odd.Weight
		end
		local lines = {}
		for _, odd in egg.Odds do
			local def = Creatures[odd.Creature]
			local color = Rarities[def.Rarity].Color
			table.insert(
				lines,
				string.format(
					'<font color="#%s">%s</font> %s',
					color:ToHex(),
					def.Name,
					Format.Percent(odd.Weight / total)
				)
			)
		end
		Theme.Label({
			Position = UDim2.fromOffset(90, 42),
			Size = UDim2.new(1, -230, 0, 66),
			Text = table.concat(lines, "  •  "),
			RichText = true,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = r,
		})
		local buy = Theme.Button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(120, 56),
			Text = Format.Money(egg.Price),
			BackgroundColor3 = Theme.Green,
			Parent = r,
		})
		buy.Activated:Connect(function()
			Net.Get("BuyEgg"):FireServer(eggId)
		end)
		table.insert(priceButtons, {
			Button = buy,
			Price = function()
				return egg.Price
			end,
		})
	end
end

local function buildFood()
	local p = page("Food")
	local order = 0
	for _, foodId in Foods.Order do
		local def = Foods[foodId]
		if not def.Price then
			continue
		end
		order += 1
		local r = row(p, order, 80)
		Theme.New("Frame", {
			Position = UDim2.fromOffset(14, 18),
			Size = UDim2.fromOffset(44, 44),
			BackgroundColor3 = def.Color,
			Parent = r,
		}, { Theme.Corner(22), Theme.Stroke(Color3.new(0, 0, 0), 2) })
		Theme.Label({
			Position = UDim2.fromOffset(70, 8),
			Size = UDim2.new(1, -300, 0, 30),
			Text = def.Name,
			TextColor3 = Rarities[def.Rarity].Color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		local detail = "+" .. def.Growth .. " XP"
		if def.Mutation then
			detail ..= "  •  " .. Format.Percent(def.Mutation.Chance) .. " " .. Mutations[def.Mutation.Id].Name .. " mutation"
		end
		Theme.Label({
			Position = UDim2.fromOffset(70, 42),
			Size = UDim2.new(1, -300, 0, 26),
			Text = detail,
			TextColor3 = Theme.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		for i, amount in { 1, 5 } do
			local buy = Theme.Button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12 - (2 - i) * 112, 0.5, 0),
				Size = UDim2.fromOffset(104, 52),
				Text = "x" .. amount .. " " .. Format.Money(def.Price * amount),
				BackgroundColor3 = Theme.Green,
				Parent = r,
			})
			buy.Activated:Connect(function()
				Net.Get("BuyFood"):FireServer(foodId, amount)
			end)
			table.insert(priceButtons, {
				Button = buy,
				Price = function()
					return def.Price * amount
				end,
			})
		end
	end
	local hint = row(p, order + 1, 60)
	hint.BackgroundTransparency = 1
	Theme.Label({
		Size = UDim2.fromScale(1, 1),
		Text = "Rare foods like Shadow Shroom and Star Food can't be bought. Find them... or steal them!",
		TextWrapped = true,
		TextColor3 = Theme.Muted,
		Parent = hint,
	})
end

local function buildRebirth()
	local p = page("Rebirth")
	local r = row(p, 1, 300)
	r.BackgroundTransparency = 1
	rebirthRefs.Current = Theme.Label({
		Size = UDim2.new(1, 0, 0, 34),
		Text = "Rebirth 0",
		TextColor3 = Theme.Purple,
		Parent = r,
	})
	Theme.Label({
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 0, 100),
		Text = string.format(
			"You get forever:\n+%d%% income  •  +%d %s slot  •  +%d food storage",
			math.round(GameConfig.RebirthIncomeBonus * 100),
			GameConfig.SlotsPerRebirth,
			GameConfig.CreatureName,
			GameConfig.StorageCapPerRebirth
		),
		TextWrapped = true,
		TextColor3 = Theme.Green,
		Parent = r,
	})
	Theme.Label({
		Position = UDim2.fromOffset(0, 150),
		Size = UDim2.new(1, 0, 0, 50),
		Text = "⚠️ You lose your " .. GameConfig.CreatureNamePlural .. ", cash and food.\nYour collection (Index) is kept.",
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(255, 170, 120),
		Parent = r,
	})
	local button = Theme.Button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 214),
		Size = UDim2.fromOffset(260, 64),
		Text = "Rebirth",
		BackgroundColor3 = Theme.Purple,
		Parent = r,
	})
	button.Activated:Connect(function()
		Net.Get("Rebirth"):FireServer()
		Shop.Close()
	end)
	rebirthRefs.Button = button
end

function Shop.Start()
	local gui = Theme.ScreenGui("Shop", 10)
	window = Theme.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(620, 460),
		BackgroundColor3 = Theme.Background,
		Visible = false,
		Parent = gui,
	}, { Theme.Corner(18), Theme.Stroke(Theme.Gold, 3) })
	Theme.AutoScale(window)
	titleLabel = Theme.Label({
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -90, 0, 44),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})
	local close = Theme.Button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(48, 44),
		Text = "X",
		BackgroundColor3 = Theme.Red,
		Parent = window,
	})
	close.Activated:Connect(Shop.Close)

	buildEggs()
	buildFood()
	buildRebirth()
end

function Shop.Open(name: string)
	if window.Visible and pages[name] and pages[name].Visible then
		Shop.Close()
		return
	end
	for pageName, p in pages do
		p.Visible = pageName == name
	end
	titleLabel.Text = TITLES[name] or name
	window.Visible = true
	window.Position = UDim2.fromScale(0.5, 0.56)
	TweenService:Create(window, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
end

function Shop.Close()
	window.Visible = false
end

function Shop.Update(snapshot)
	state = snapshot
	for _, entry in priceButtons do
		local affordable = state.Cash >= entry.Price()
		entry.Button.BackgroundColor3 = if affordable then Theme.Green else Color3.fromRGB(90, 90, 100)
	end
	rebirthRefs.Current.Text = "Rebirth " .. state.Rebirths .. " → " .. (state.Rebirths + 1)
	local cost = CreatureMath.RebirthCost(state.Rebirths)
	rebirthRefs.Button.Text = "Rebirth for " .. Format.Money(cost)
	rebirthRefs.Button.BackgroundColor3 = if state.Cash >= cost then Theme.Purple else Color3.fromRGB(90, 90, 100)
end

return Shop
