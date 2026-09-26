--[[
	Hud: always-on-screen UI. Cash, income, trophies, boosts, menu buttons,
	food bar, storage/pen info, king badge, event timer and "carrying" banner.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosts = require(Shared.Config.Boosts)
local Foods = require(Shared.Config.Foods)
local GameConfig = require(Shared.Config.GameConfig)
local CreatureMath = require(Shared.Game.CreatureMath)
local Format = require(Shared.Lib.Format)
local Net = require(Shared.Net)
local Fx = require(Shared.Fx)
local Theme = require(script.Parent.Theme)

local player = Players.LocalPlayer

local Hud = {}

local refs: { [string]: any } = {}
local foodButtons: { [string]: TextButton } = {}
local menuButtons: { [string]: TextButton } = {}
local state: any = nil
local lastCash = nil
local window

local EVENT_NAMES = {
	MeteorFeast = "☄️ Meteor Feast",
	BloodMoon = "🩸 Blood Moon",
	TitanClash = "⚔️ Titan Clash",
}

-- icon, label, page (or function), color
local MENU = {
	{ "🥚", "Eggs", "Eggs", Color3.fromRGB(240, 190, 60) },
	{ "🍖", "Food", "Food", Color3.fromRGB(220, 90, 80) },
	{ "🐾", "Titans", "Titans", Color3.fromRGB(90, 170, 110) },
	{ "⚔️", "Battle", "Battle", Color3.fromRGB(200, 60, 70) },
	{ "📜", "Quests", "Quests", Color3.fromRGB(200, 150, 80) },
	{ "📅", "Daily", "Daily", Color3.fromRGB(80, 160, 230) },
	{ "📖", "Index", "Index", Color3.fromRGB(150, 110, 220) },
	{ "💎", "Store", "Store", Color3.fromRGB(60, 200, 200) },
	{ "🌟", "Rebirth", "Rebirth", Color3.fromRGB(170, 110, 255) },
	{ "⚙️", "Settings", "Settings", Color3.fromRGB(120, 120, 140) },
	{ "🛠️", "Admin", "Admin", Color3.fromRGB(70, 80, 120) },
}

local function buildTop(gui: ScreenGui)
	local top = Theme.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(320, 78),
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
		Size = UDim2.new(0.5, -8, 0.32, 0),
		Position = UDim2.new(0, 8, 0.62, 0),
		Text = "+$0/s",
		TextColor3 = Theme.Green,
		Parent = top,
	})
	refs.Trophies = Theme.Label({
		Size = UDim2.new(0.5, -8, 0.32, 0),
		Position = UDim2.new(0.5, 0, 0.62, 0),
		Text = "🏆 0",
		TextColor3 = Color3.fromRGB(255, 200, 120),
		Parent = top,
	})
	local lines = Theme.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 6),
		Size = UDim2.fromOffset(420, 90),
		BackgroundTransparency = 1,
		Parent = top,
	}, {
		Theme.New(
			"UIListLayout",
			{ HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }
		),
	})
	local function line(name: string, order: number, color: Color3)
		refs[name] = Theme.Label({
			Size = UDim2.fromOffset(420, 24),
			Text = "",
			TextColor3 = color,
			LayoutOrder = order,
			Parent = lines,
		})
	end
	line("King", 1, Theme.Gold)
	line("Boosts", 2, Theme.Green)
	line("Event", 3, Color3.fromRGB(255, 140, 120))
end

local function buildMenu(gui: ScreenGui)
	local menu = Theme.New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(150, 440),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Theme.New("UIGridLayout", {
			CellSize = UDim2.fromOffset(70, 70),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	Theme.AutoScale(menu)
	for i, info in MENU do
		local button = Theme.Button({ Text = "", BackgroundColor3 = info[4], LayoutOrder = i, Parent = menu })
		Theme.Label({ Size = UDim2.fromScale(1, 0.62), Text = info[1], Parent = button })
		Theme.Label({
			Position = UDim2.fromScale(0, 0.6),
			Size = UDim2.fromScale(1, 0.38),
			Text = info[2],
			Parent = button,
		})
		Theme.New("Frame", {
			Name = "Badge",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 4, 0, -4),
			Size = UDim2.fromOffset(18, 18),
			BackgroundColor3 = Color3.fromRGB(255, 60, 60),
			Visible = false,
			Parent = button,
		}, { Theme.Corner(9), Theme.Stroke(Color3.new(1, 1, 1), 2) })
		button.Activated:Connect(function()
			window.Toggle(info[3])
		end)
		menuButtons[info[3]] = button
		if info[3] == "Admin" then
			button.Visible = false
		end
	end

	local corner = Theme.New("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -140),
		Size = UDim2.fromOffset(120, 130),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Theme.New("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	Theme.AutoScale(corner)
	refs.Corner = corner
	local home = Theme.Button({
		Size = UDim2.fromOffset(120, 56),
		Text = "🏠 Home",
		BackgroundColor3 = Color3.fromRGB(110, 110, 130),
		LayoutOrder = 1,
		Parent = corner,
	})
	home.Activated:Connect(function()
		Net.Send("TeleportHome")
	end)
	refs.LockButton = Theme.Button({
		Size = UDim2.fromOffset(120, 56),
		Text = "🔒 Lock",
		BackgroundColor3 = Theme.Blue,
		LayoutOrder = 2,
		Parent = corner,
	})
	refs.LockButton.Activated:Connect(function()
		Net.Send("LockStorage")
	end)
end

local function buildFoodBar(gui: ScreenGui)
	local bottom = Theme.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(800, 116),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Theme.AutoScale(bottom)
	refs.FoodBar = bottom
	refs.Info = Theme.Label({ Size = UDim2.new(1, 0, 0, 26), Text = "", Parent = bottom })
	local bar = Theme.New("Frame", {
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 0, 80),
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
			Size = UDim2.fromOffset(80, 66),
			Text = "",
			BackgroundColor3 = Theme.Panel,
			LayoutOrder = i,
			Parent = bar,
		})
		Theme.New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.02),
			Size = UDim2.fromOffset(24, 24),
			BackgroundColor3 = def.Color,
			Parent = button,
		}, { Theme.Corner(12), Theme.Stroke(Color3.new(0, 0, 0), 1.5) })
		Theme.Label({
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
			Net.Send("SelectFood", id)
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

function Hud.Start(windowModule)
	window = windowModule
	local gui = Theme.ScreenGui("Hud", 5)
	buildTop(gui)
	buildMenu(gui)
	buildFoodBar(gui)
	buildCarrying(gui)

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

-- Makes a menu button pulse (used by the tutorial).
function Hud.Highlight(page: string?)
	for name, button in menuButtons do
		local stroke = button:FindFirstChild("Border") :: UIStroke
		if stroke then
			stroke.Color = if name == page then Theme.Gold else Color3.new(0, 0, 0)
			stroke.Thickness = if name == page then 4 else 2
		end
	end
	if page and menuButtons[page] then
		Fx.Primitives.Pop(menuButtons[page], 0.12)
	end
end

function Hud.SetBadge(page: string, visible: boolean)
	local button = menuButtons[page]
	local badge = button and button:FindFirstChild("Badge")
	if badge then
		(badge :: Frame).Visible = visible
	end
end

function Hud.SetBattleMode(fighting: boolean)
	refs.FoodBar.Visible = not fighting
	refs.Corner.Visible = not fighting
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
		refs.Event.Text = if endsAt and endsAt > now then name .. " • " .. Format.Time(endsAt - now) else name
	else
		refs.Event.Text = ""
	end
	if state then
		if (state.LockedUntil or 0) > now then
			refs.LockButton.Text = "🔒 " .. Format.Time(state.LockedUntil - now)
		elseif (state.LockCooldownUntil or 0) > now then
			refs.LockButton.Text = "⏳ " .. Format.Time(state.LockCooldownUntil - now)
		else
			refs.LockButton.Text = "🔒 Lock"
		end
		local active = {}
		for _, id in Boosts.Order do
			local expiresAt = state.Boosts[id]
			if expiresAt and expiresAt > now then
				table.insert(active, Boosts[id].Icon .. " " .. Format.Time(expiresAt - now))
			end
		end
		local friends = state.Friends or 0
		if friends > 0 then
			table.insert(active, "🤝 +" .. math.min(friends * 10, 50) .. "%")
		end
		refs.Boosts.Text = table.concat(active, "   ")
	end
end

function Hud.Update(snapshot)
	state = snapshot
	refs.Cash.Text = "💰 " .. Format.Money(snapshot.Cash)
	refs.Income.Text = "+" .. Format.Money(snapshot.Income or 0) .. "/s"
	refs.Trophies.Text = "🏆 " .. Format.Number(snapshot.Trophies)
	refs.King.Text = if snapshot.IsKing
		then "👑 You own the " .. GameConfig.CreatureName .. " King! +50% income"
		else ""
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
	menuButtons.Admin.Visible = snapshot.IsAdmin == true
	Hud.RefreshFoodBar()
	Hud.RefreshTimers()
end

return Hud
