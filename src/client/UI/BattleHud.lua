--[[
	BattleHud: shown during arena matches.
	- Top: every fighter's name + HP bar, and the timer
	- Center: 3-2-1-FIGHT countdown
	- Bottom right (fighters only): Attack and Special buttons with cooldowns
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Lib.Format)
local Fx = require(Shared.Fx)
local Theme = require(script.Parent.Theme)

local BattleHud = {}

local gui: ScreenGui
local board: Frame
local timer: TextLabel
local countdown: TextLabel
local controls: Frame
local attackButton: TextButton
local specialButton: TextButton
local attackShade: Frame
local specialShade: Frame
local state: any = nil
local lastCountdown = ""
local cooldowns = { Attack = { Until = 0, Length = 1 }, Special = { Until = 0, Length = 1 } }

function BattleHud.Start(onAction: (string) -> ())
	gui = Theme.ScreenGui("BattleHud", 15)
	gui.Enabled = false

	local top = Theme.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 180),
		Size = UDim2.fromOffset(460, 40),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.2,
		Parent = gui,
	}, {
		Theme.Corner(12),
		Theme.New("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
		}),
		Theme.New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	Theme.AutoScale(top)
	timer = Theme.Label({
		Size = UDim2.new(1, 0, 0, 26),
		Text = "",
		TextColor3 = Theme.Gold,
		LayoutOrder = 0,
		Parent = top,
	})
	board = Theme.New("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = top,
	}, { Theme.New("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })

	countdown = Theme.Label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(500, 140),
		Text = "",
		TextColor3 = Theme.Gold,
		Parent = gui,
	})

	controls = Theme.New("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -30),
		Size = UDim2.fromOffset(260, 130),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Theme.AutoScale(controls)
	local function actionButton(text: string, color: Color3, position: UDim2, size: number): (TextButton, Frame)
		local button = Theme.Button({
			AnchorPoint = Vector2.new(1, 1),
			Position = position,
			Size = UDim2.fromOffset(size, size),
			Text = text,
			BackgroundColor3 = color,
			Parent = controls,
		})
		button:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
		local shade = Theme.New("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.45,
			ZIndex = 5,
			Parent = button,
		}, { Theme.Corner(60) })
		return button, shade
	end
	attackButton, attackShade = actionButton("👊\nAttack", Theme.Red, UDim2.fromScale(1, 1), 120)
	specialButton, specialShade = actionButton("✨\nSpecial", Theme.Purple, UDim2.new(1, -130, 1, 0), 100)
	attackButton.Activated:Connect(function()
		onAction("Attack")
	end)
	specialButton.Activated:Connect(function()
		onAction("Special")
	end)

	RunService.RenderStepped:Connect(function()
		if not gui.Enabled then
			return
		end
		local now = os.clock()
		for name, shade in { Attack = attackShade, Special = specialShade } do
			local cd = cooldowns[name]
			local left = math.max(0, cd.Until - now)
			shade.Size = UDim2.fromScale(1, left / cd.Length)
		end
		if state then
			local serverNow = Workspace:GetServerTimeNow()
			local left = math.max(0, (state.EndsAt or 0) - serverNow)
			if state.Phase == "Countdown" then
				local text = tostring(math.ceil(left))
				countdown.Text = text
				if text ~= lastCountdown then
					lastCountdown = text
					Fx.Primitives.Pop(countdown, 0.5)
					Fx.Primitives.Sound("Countdown", nil, 0.6, 0.8)
				end
				timer.Text = "Get ready..."
			elseif state.Phase == "Fight" then
				if lastCountdown ~= "FIGHT" then
					lastCountdown = "FIGHT"
					countdown.Text = "FIGHT!"
					Fx.Primitives.Pop(countdown, 0.6)
					Fx.Primitives.Sound("Countdown", nil, 0.8, 1.4)
					task.delay(0.8, function()
						if countdown.Text == "FIGHT!" then
							countdown.Text = ""
						end
					end)
				end
				timer.Text = (state.Mode or "Battle") .. "  ⏱️ " .. Format.Time(left)
			else
				timer.Text = "Results"
			end
		end
	end)
end

function BattleHud.SetCooldown(action: string, seconds: number)
	cooldowns[action] = { Until = os.clock() + seconds, Length = seconds }
end

function BattleHud.CooldownLeft(action: string): number
	return math.max(0, cooldowns[action].Until - os.clock())
end

function BattleHud.SetSpecialName(name: string)
	specialButton.Text = "✨\n" .. name
end

function BattleHud.Update(battleState, isFighter: boolean)
	state = battleState
	local active = battleState and battleState.Phase ~= "None"
	gui.Enabled = active == true
	controls.Visible = isFighter
	if not active then
		countdown.Text = ""
		lastCountdown = ""
		return
	end
	for _, child in board:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for i, f in battleState.Fighters do
		local row = Theme.New(
			"Frame",
			{ Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = i, Parent = board }
		)
		local winner = battleState.Winner == f.Id
		Theme.Label({
			Size = UDim2.new(0.45, 0, 1, 0),
			Text = (if winner then "🏆 " elseif not f.Alive then "💀 " else "") .. f.Name,
			TextColor3 = if f.Alive then Theme.Text else Theme.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		local bar, fill =
			Theme.ProgressBar(row, { Position = UDim2.new(0.47, 0, 0.15, 0), Size = UDim2.new(0.53, 0, 0.7, 0) })
		local ratio = math.clamp(f.HP / math.max(1, f.MaxHP), 0, 1)
		fill.Size = UDim2.fromScale(ratio, 1)
		fill.BackgroundColor3 = Color3.fromRGB(255, 80, 80):Lerp(Color3.fromRGB(90, 220, 110), ratio)
		Theme.Label({
			Size = UDim2.fromScale(1, 1),
			Text = Format.Number(f.HP) .. " / " .. Format.Number(f.MaxHP),
			ZIndex = 3,
			Parent = bar,
		})
	end
end

return BattleHud
