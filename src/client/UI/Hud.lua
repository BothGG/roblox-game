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
	WildRush = "🌟 Wild Rush",
	BloodMoon = "🩸 Blood Moon",
	TitanClash = "⚔️ Titan Clash",
}

-- icon, label, page, color, side. "Left" = wide buttons, "Right" = square icon buttons
-- (the layout big simulator games use: Shop/Index on the left, icons on the right).
local MENU = {
	{ "🛒", "Shop", "Store", Color3.fromRGB(80, 210, 70), "Left" },
	{ "📖", "Index", "Index", Color3.fromRGB(50, 190, 240), "Left" },
	{ "📜", "Quests", "Quests", Color3.fromRGB(255, 170, 40), "Left" },
	{ "📅", "Daily", "Daily", Color3.fromRGB(190, 110, 255), "Left" },
	{ "🥚", "Eggs", "Eggs", Color3.fromRGB(235, 60, 60), "Right" },
	{ "🐾", "Titans", "Titans", Color3.fromRGB(255, 140, 40), "Right" },
	{ "💞", "Breed", "Breed", Color3.fromRGB(255, 110, 170), "Right" },
	{ "🍖", "Food", "Food", Color3.fromRGB(110, 200, 70), "Right" },
	{ "⚔️", "Battle", "Battle", Color3.fromRGB(200, 50, 70), "Right" },
	{ "🌟", "Rebirth", "Rebirth", Color3.fromRGB(170, 110, 255), "Right" },
	{ "⚙️", "Settings", "Settings", Color3.fromRGB(120, 120, 140), "Right" },
	{ "🛠️", "Admin", "Admin", Color3.fromRGB(70, 80, 120), "Right" },
}

-- Money bottom-left (big green outlined text, like the reference), event
-- timer and status lines top-center.
local function buildTop(gui: ScreenGui)
	local money = Theme.New("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(300, 110),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Theme.AutoScale(money)
	refs.Trophies = Theme.BigLabel({
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 0),
		Text = "🏆 0",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 205, 90),
		Parent = money,
	})
	refs.Cash = Theme.BigLabel({
		Size = UDim2.new(1, 0, 0, 50),
		Position = UDim2.fromOffset(0, 30),
		Text = "💵 $0",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(120, 255, 90),
		Parent = money,
	})
	refs.Income = Theme.BigLabel({
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(4, 82),
		Text = "+$0/s",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(200, 255, 190),
		Parent = money,
	})

	local lines = Theme.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(460, 100),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Theme.New(
			"UIListLayout",
			{ HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }
		),
	})
	Theme.AutoScale(lines)
	local function line(name: string, order: number, color: Color3, height: number)
		refs[name] = Theme.BigLabel({
			Size = UDim2.fromOffset(460, height),
			Text = "",
			TextColor3 = color,
			LayoutOrder = order,
			Parent = lines,
		})
	end
	line("Event", 1, Color3.new(1, 1, 1), 30)
	line("King", 2, Theme.Gold, 24)
	line("Boosts", 3, Theme.Green, 24)
end

local function menuButton(parent: Instance, info, order: number, wide: boolean): TextButton
	local button = Theme.Button({
		Text = "",
		BackgroundColor3 = info[4],
		LayoutOrder = order,
		Size = if wide then UDim2.fromOffset(150, 48) else UDim2.fromOffset(64, 64),
		Parent = parent,
	})
	if wide then
		Theme.Label({ Size = UDim2.new(0, 38, 1, 0), Text = info[1], Parent = button })
		Theme.BigLabel({
			Position = UDim2.fromOffset(38, 0),
			Size = UDim2.new(1, -40, 1, 0),
			Text = info[2],
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = button,
		})
	else
		Theme.Label({ Size = UDim2.fromScale(1, 0.62), Text = info[1], Parent = button })
		Theme.BigLabel({
			Position = UDim2.fromScale(0, 0.6),
			Size = UDim2.fromScale(1, 0.38),
			Text = info[2],
			Parent = button,
		})
	end
	Theme.New("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 6, 0, -6),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = Color3.fromRGB(255, 50, 50),
		Visible = false,
		Parent = button,
	}, {
		Theme.Corner(10),
		Theme.Stroke(Color3.new(1, 1, 1), 2),
		Theme.Label({ Size = UDim2.fromScale(1, 1), Text = "!" }),
	})
	button.Activated:Connect(function()
		window.Toggle(info[3])
	end)
	menuButtons[info[3]] = button
	if info[3] == "Admin" then
		button.Visible = false
	end
	return button
end

local function buildMenu(gui: ScreenGui)
	local function column(anchorX: number, x: UDim, width: number, fill: Enum.FillDirection?)
		local frame = Theme.New("Frame", {
			AnchorPoint = Vector2.new(anchorX, 0.5),
			Position = UDim2.new(x.Scale, x.Offset, 0.45, 0),
			Size = UDim2.fromOffset(width, 470),
			BackgroundTransparency = 1,
			Parent = gui,
		}, {
			Theme.New("UIListLayout", {
				FillDirection = fill or Enum.FillDirection.Vertical,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = if anchorX == 0
					then Enum.HorizontalAlignment.Left
					else Enum.HorizontalAlignment.Right,
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		Theme.AutoScale(frame)
		return frame
	end
	local left = column(0, UDim.new(0, 12), 160)
	-- Right side: a 2-wide grid of square icon buttons
	local right = Theme.New("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.4, 0),
		Size = UDim2.fromOffset(138, 290),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Theme.New("UIGridLayout", {
			CellSize = UDim2.fromOffset(64, 64),
			CellPadding = UDim2.fromOffset(10, 10),
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	Theme.AutoScale(right)
	for i, info in MENU do
		menuButton(if info[5] == "Left" then left else right, info, i, info[5] == "Left")
	end

	local corner = Theme.New("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -140),
		Size = UDim2.fromOffset(130, 124),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Theme.New("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	Theme.AutoScale(corner)
	refs.Corner = corner
	local home = Theme.Button({
		Size = UDim2.fromOffset(130, 54),
		Text = "🏠 Home",
		BackgroundColor3 = Color3.fromRGB(110, 110, 130),
		LayoutOrder = 1,
		Parent = corner,
	})
	home.Activated:Connect(function()
		Net.Send("TeleportHome")
	end)
	refs.LockButton = Theme.Button({
		Size = UDim2.fromOffset(130, 54),
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
		BackgroundTransparency = 1,
		Parent = bottom,
	}, {
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
		-- Hotbar slot (like the Roblox backpack bar): dark glass square with a number
		local button = Theme.Button({
			Size = UDim2.fromOffset(74, 74),
			Text = "",
			BackgroundColor3 = Color3.fromRGB(40, 44, 40),
			BackgroundTransparency = 0.25,
			LayoutOrder = i,
			Parent = bar,
		})
		Theme.Label({
			Position = UDim2.fromOffset(3, 1),
			Size = UDim2.fromOffset(16, 16),
			Text = tostring(i),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = button,
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
		button.BackgroundTransparency = if count > 0 then 0.25 else 0.55
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
		refs.Event.Text = string.upper(name)
			.. (if endsAt and endsAt > now then "  " .. Format.Time(endsAt - now) else "")
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
	refs.Cash.Text = "💵 " .. Format.Money(snapshot.Cash)
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
