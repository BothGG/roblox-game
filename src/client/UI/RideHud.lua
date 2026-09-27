--[[
	RideHud: shown while you ride a titan (HP, stamina, special cooldown and
	big buttons that also work as the phone controls), plus the follower
	command bar when titans follow you.

	RideHud.Start(onAction, onFollowerCommand)
	RideHud.SetRiding(riding)            RideHud.Refresh()
	RideHud.SetFollowers(count)          RideHud.StartCooldown(name, seconds)
]]

local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)

local player = Players.LocalPlayer

local RideHud = {}

local panel: Frame
local followerBar: Frame
local refs: { [string]: any } = {}
local cooldowns: { [string]: { Until: number, Length: number } } = {}

local function barRow(parent: Instance, y: number, color: Color3, label: string): (Frame, TextLabel)
	local back = Theme.New("Frame", {
		Position = UDim2.fromOffset(10, y),
		Size = UDim2.new(1, -20, 0, 18),
		BackgroundColor3 = Color3.fromRGB(25, 25, 35),
		Parent = parent,
	}, { Theme.Corner(9) })
	local fill = Theme.New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		Parent = back,
	}, { Theme.Corner(9) })
	local text = Theme.Label({
		Size = UDim2.fromScale(1, 1),
		Text = label,
		ZIndex = 3,
		Parent = back,
	})
	return fill, text
end

local function actionButton(
	parent: Instance,
	name: string,
	text: string,
	color: Color3,
	order: number,
	onPress,
	onRelease
)
	local button = Theme.Button({
		Size = UDim2.fromOffset(78, 58),
		Text = text,
		BackgroundColor3 = color,
		LayoutOrder = order,
		Parent = parent,
	})
	local shade = Theme.New("Frame", {
		Name = "Cooldown",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		ZIndex = 4,
		Parent = button,
	}, { Theme.Corner(10) })
	button.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			onPress(name)
		end
	end)
	button.InputEnded:Connect(function(input)
		if
			onRelease
			and (
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			onRelease(name)
		end
	end)
	refs[name] = { Button = button, Shade = shade }
	return button
end

function RideHud.Start(onAction: (string, boolean?) -> (), onFollowerCommand: (string) -> ())
	local gui = Theme.ScreenGui("RideHud", 6)

	panel = Theme.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(440, 150),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.2,
		Visible = false,
		Parent = gui,
	}, { Theme.Corner(16), Theme.Stroke(Theme.Gold, 3) })
	Theme.AutoScale(panel)
	refs.Name = Theme.BigLabel({
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -20, 0, 26),
		Text = "",
		TextColor3 = Theme.Gold,
		Parent = panel,
	})
	refs.HpFill, refs.HpText = barRow(panel, 32, Color3.fromRGB(90, 220, 110), "")
	refs.StaminaFill, refs.StaminaText = barRow(panel, 54, Color3.fromRGB(80, 170, 255), "")
	local buttons = Theme.New("Frame", {
		Position = UDim2.fromOffset(10, 80),
		Size = UDim2.new(1, -20, 0, 62),
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		Theme.New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local function press(name: string)
		if name == "Sprint" or name == "Fly" then
			onAction(name, true)
		else
			onAction(name)
		end
	end
	local function release(name: string)
		if name == "Sprint" then
			onAction(name, false)
		end
	end
	actionButton(buttons, "Attack", "👊\nAttack", Color3.fromRGB(220, 70, 70), 1, press)
	actionButton(buttons, "Special", "✨\nSpecial", Color3.fromRGB(160, 90, 230), 2, press)
	actionButton(buttons, "Sprint", "💨\nSprint", Color3.fromRGB(70, 150, 240), 3, press, release)
	actionButton(buttons, "Fly", "🪽\nFly", Color3.fromRGB(80, 200, 220), 4, press)
	actionButton(buttons, "Dismount", "⬇️\nGet off", Color3.fromRGB(120, 120, 140), 5, press)

	followerBar = Theme.New("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -275),
		Size = UDim2.fromOffset(140, 190),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	}, {
		Theme.New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	Theme.AutoScale(followerBar)
	refs.FollowerTitle = Theme.BigLabel({
		Size = UDim2.fromOffset(140, 24),
		Text = "🐾 Followers",
		TextColor3 = Color3.fromRGB(180, 255, 180),
		LayoutOrder = 0,
		Parent = followerBar,
	})
	for i, info in
		{
			{ "FollowAll", "🐾 Follow", Color3.fromRGB(80, 190, 90) },
			{ "Stay", "✋ Stay", Color3.fromRGB(230, 170, 60) },
			{ "Attack", "⚔️ Attack", Color3.fromRGB(220, 70, 70) },
			{ "Guard", "🏠 Guard base", Color3.fromRGB(110, 110, 140) },
		}
	do
		local button = Theme.Button({
			Size = UDim2.fromOffset(140, 34),
			Text = info[2],
			BackgroundColor3 = info[3],
			LayoutOrder = i,
			Parent = followerBar,
		})
		button.Activated:Connect(function()
			onFollowerCommand(info[1])
		end)
	end
end

function RideHud.SetRiding(riding: boolean)
	panel.Visible = riding
	if riding then
		RideHud.Refresh()
	end
end

function RideHud.SetFollowers(count: number)
	followerBar.Visible = count > 0
	refs.FollowerTitle.Text = "🐾 Followers (" .. count .. ")"
end

function RideHud.StartCooldown(name: string, seconds: number)
	cooldowns[name] = { Until = os.clock() + seconds, Length = seconds }
end

function RideHud.CooldownLeft(name: string): number
	local cd = cooldowns[name]
	return if cd then math.max(0, cd.Until - os.clock()) else 0
end

-- Called every frame while riding (cheap: a few property sets).
function RideHud.Refresh()
	if not panel.Visible then
		return
	end
	local hp = player:GetAttribute("RideHp") or 0
	local hpMax = math.max(1, player:GetAttribute("RideHpMax") or 1)
	local stamina = player:GetAttribute("RideStamina") or 0
	local staminaMax = math.max(1, player:GetAttribute("RideStaminaMax") or 1)
	local mode = player:GetAttribute("RideMode") or "Walk"
	refs.Name.Text = "🐎 " .. tostring(player:GetAttribute("RideName") or "")
	refs.HpFill.Size = UDim2.fromScale(math.clamp(hp / hpMax, 0, 1), 1)
	refs.HpText.Text = string.format("❤️ %d / %d", hp, hpMax)
	refs.StaminaFill.Size = UDim2.fromScale(math.clamp(stamina / staminaMax, 0, 1), 1)
	refs.StaminaText.Text = string.format("⚡ Stamina %d%s", math.floor(stamina / staminaMax * 100), "%")
	refs.Sprint.Button.Visible = player:GetAttribute("RideCanSprint") == true
	refs.Fly.Button.Visible = player:GetAttribute("RideCanFly") == true
	refs.Fly.Button.Text = if mode == "Fly" then "🪽\nLand" else "🪽\nFly"
	refs.Special.Button.Text = "✨\n" .. tostring(player:GetAttribute("RideSpecial") or "Special")
	for name, entry in refs do
		if type(entry) == "table" and entry.Shade then
			local cd = cooldowns[name]
			local left = if cd then math.max(0, cd.Until - os.clock()) / cd.Length else 0
			entry.Shade.Size = UDim2.fromScale(1, left)
		end
	end
end

return RideHud
