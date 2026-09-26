--[[
	Hud: always-on-screen UI. Cash, income, menu buttons, food bar,
	storage/pen info, king badge, event timer and "carrying" banner.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Foods = require(Shared.Config.Foods)
local GameConfig = require(Shared.Config.GameConfig)
local CreatureMath = require(Shared.CreatureMath)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)
local Fx = require(Shared.Fx)
local Theme = require(script.Parent.Theme)

local player = Players.LocalPlayer

local Hud = {}

local refs: { [string]: any } = {}
local foodButtons: { [string]: TextButton } = {}
local state: any = nil
local lastCash = nil

local EVENT_NAMES = {
	MeteorFeast = "☄️ Meteor Feast",
	BloodMoon = "🩸 Blood Moon",
}

local function buildTop(gui: ScreenGui)
	local top = Theme.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(300, 78),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.15,
		Parent = gui,
	}, { Theme.Corner(16), Theme.Stroke(Theme.Gold, 3) })
	Theme.AutoScale(top)
	refs.Cash = Theme.Label({
		Size = UDim2.new(1, -16, 0.6, 0),
		Position = UDim2.fromOffset(8, 4),
		Text = "💰 $0",
		TextColor3 = Theme.Gold,
		Parent = top,
	})
	refs.Income = Theme.Label({
		Size = UDim2.new(1, -16, 0.32, 0),
		Position = UDim2.new(0, 8, 0.62, 0),
		Text = "+$0/s",
		TextColor3 = Theme.Green,
		Parent = top,
	})
	refs.King = Theme.Label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 6),
		Size = UDim2.fromOffset(340, 26),
		Text = "👑 You own the " .. GameConfig.CreatureName .. " King! +" .. math.round(GameConfig.KingIncomeBonus * 100) .. "% income",
		TextColor3 = Theme.Gold,
		Visible = false,
		Parent = top,
	})
	refs.Event = Theme.Label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 34),
		Size = UDim2.fromOffset(300, 24),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 140, 120),
		Parent = top,
	})
end

local function buildMenu(gui: ScreenGui, shop)
	local menu = Theme.New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(130, 290),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Theme.New("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	Theme.AutoScale(menu)
	local buttons = {
		{ "🥚 Eggs", Theme.Gold, function()
			shop.Open("Eggs")
		end },
		{ "🍖 Food", Theme.Red, function()
			shop.Open("Food")
		end },
		{ "🌟 Rebirth", Theme.Purple, function()
			shop.Open("Rebirth")
		end },
		{ "🔒 Lock", Theme.Blue, function()
			Net.Get("LockStorage"):FireServer()
		end },
	}
	for i, info in buttons do
		local button = Theme.Button({
			Size = UDim2.fromOffset(130, 60),
			Text = info[1],
			BackgroundColor3 = info[2],
			LayoutOrder = i,
			Parent = menu,
		})
		button.Activated:Connect(info[3])
		if i == 4 then
			refs.LockButton = button
		end
	end
end

local function buildFoodBar(gui: ScreenGui)
	local bottom = Theme.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(620, 120),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Theme.AutoScale(bottom)
	refs.Info = Theme.Label({
		Size = UDim2.new(1, 0, 0, 26),
		Text = "",
		Parent = bottom,
	})
	local bar = Theme.New("Frame", {
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 0, 84),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.2,
		Parent = bottom,
	}, {
		Theme.Corner(14),
		Theme.New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, id in Foods.Order do
		local def = Foods[id]
		local button = Theme.Button({
			Size = UDim2.fromOffset(92, 70),
			Text = "",
			BackgroundColor3 = Theme.Panel,
			LayoutOrder = i,
			Parent = bar,
		})
		Theme.New("Frame", {
			Name = "Dot",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.02),
			Size = UDim2.fromOffset(24, 24),
			BackgroundColor3 = def.Color,
			Parent = button,
		}, { Theme.Corner(12), Theme.Stroke(Color3.new(0, 0, 0), 1.5) })
		Theme.Label({
			Name = "FoodName",
			Position = UDim2.fromScale(0, 0.42),
			Size = UDim2.fromScale(1, 0.28),
			Text = def.Name,
			Parent = button,
		})
		Theme.Label({
			Name = "Count",
			Position = UDim2.fromScale(0, 0.7),
			Size = UDim2.fromScale(1, 0.3),
			Text = "x0",
			TextColor3 = Theme.Gold,
			Parent = button,
		})
		button.Activated:Connect(function()
			Net.Get("SelectFood"):FireServer(id)
			if state then
				state.SelectedFood = id
				Hud.RefreshFoodBar()
			end
			Fx.Primitives.Pop(button, 0.15)
		end)
		foodButtons[id] = button
	end
end

local function buildCarrying(gui: ScreenGui)
	refs.Carrying = Theme.Label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.72),
		Size = UDim2.fromOffset(520, 40),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 120, 120),
		Visible = false,
		Parent = gui,
	})
	Theme.AutoScale(refs.Carrying)
	local function update()
		local foodId = player:GetAttribute("Carrying")
		refs.Carrying.Visible = foodId ~= nil
		if foodId and Foods[foodId] then
			refs.Carrying.Text = "😈 Carrying " .. Foods[foodId].Name .. "! Run to your base!"
			Fx.Primitives.Pop(refs.Carrying, 0.3)
		end
	end
	player:GetAttributeChangedSignal("Carrying"):Connect(update)
	update()
end

function Hud.Start(shop)
	local gui = Theme.ScreenGui("Hud", 5)
	buildTop(gui)
	buildMenu(gui, shop)
	buildFoodBar(gui)
	buildCarrying(gui)

	-- Timers (event countdown, lock cooldown) update every frame-ish.
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.25 then
			return
		end
		elapsed = 0
		Hud.RefreshTimers()
	end)
end

function Hud.RefreshFoodBar()
	if not state then
		return
	end
	for id, button in foodButtons do
		local count = state.Food[id] or 0
		local countLabel = button:FindFirstChild("Count") :: TextLabel
		countLabel.Text = "x" .. count
		button.BackgroundColor3 = if count > 0 then Theme.Panel else Color3.fromRGB(35, 35, 45)
		local stroke = button:FindFirstChild("Border") :: UIStroke
		local selected = state.SelectedFood == id
		stroke.Color = if selected then Theme.Gold else Color3.new(0, 0, 0)
		stroke.Thickness = if selected then 4 else 2
	end
end

function Hud.RefreshTimers()
	local now = Workspace:GetServerTimeNow()
	local event = Workspace:GetAttribute("ActiveEvent")
	if event then
		local endsAt = Workspace:GetAttribute("EventEndsAt")
		local name = EVENT_NAMES[event] or event
		refs.Event.Text = if endsAt then name .. " • " .. Format.Time(endsAt - now) else name
	else
		refs.Event.Text = ""
	end
	if state and refs.LockButton then
		if (state.LockedUntil or 0) > now then
			refs.LockButton.Text = "🔒 " .. Format.Time(state.LockedUntil - now)
		elseif (state.LockCooldownUntil or 0) > now then
			refs.LockButton.Text = "⏳ " .. Format.Time(state.LockCooldownUntil - now)
		else
			refs.LockButton.Text = "🔒 Lock"
		end
	end
end

function Hud.Update(snapshot)
	state = snapshot
	refs.Cash.Text = "💰 " .. Format.Money(snapshot.Cash)
	refs.Income.Text = "+" .. Format.Money(snapshot.Income or 0) .. "/s"
	refs.King.Visible = snapshot.IsKing == true
	if lastCash and snapshot.Cash < lastCash then
		Fx.Primitives.Pop(refs.Cash, 0.12)
	end
	lastCash = snapshot.Cash

	refs.Info.Text = string.format(
		"📦 Food %d/%d   •   🐾 %s %d/%d   •   🌟 Rebirth %d",
		CreatureMath.CountFood(snapshot.Food),
		snapshot.StorageCap,
		GameConfig.CreatureNamePlural,
		CreatureMath.Count(snapshot.Creatures),
		snapshot.Slots,
		snapshot.Rebirths
	)
	Hud.RefreshFoodBar()
	Hud.RefreshTimers()
end

return Hud
