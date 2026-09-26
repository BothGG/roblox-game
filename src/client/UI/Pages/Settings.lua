local Theme = require(script.Parent.Parent.Theme)

local Page = { Name = "Settings", Title = "⚙️ Settings" }

local toggles = {}
local tutorialRow: Frame

local function toggleRow(page: ScrollingFrame, order: number, label: string, setting: string, ctx)
	local r = Theme.Row(page, order, 60)
	Theme.Label({
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -170, 0, 40),
		Text = label,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = r,
	})
	local button = Theme.Button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(120, 44),
		Text = "ON",
		Parent = r,
	})
	button.Activated:Connect(function()
		local state = ctx.ClientState.Current
		if state then
			ctx.Net.Send("SetSetting", setting, not state.Settings[setting])
		end
	end)
	toggles[setting] = button
end

function Page.Build(page: ScrollingFrame, ctx)
	toggleRow(page, 1, "🎵 Music", "Music", ctx)
	toggleRow(page, 2, "🔊 Sound effects", "Sfx", ctx)

	local codes = Theme.Row(page, 3, 70)
	local box = Theme.New("TextBox", {
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.new(1, -170, 0, 46),
		BackgroundColor3 = Color3.fromRGB(25, 25, 35),
		TextColor3 = Theme.Text,
		PlaceholderText = "Enter a code",
		PlaceholderColor3 = Theme.Muted,
		Font = Theme.Font,
		TextScaled = true,
		Text = "",
		ClearTextOnFocus = false,
		Parent = codes,
	}, { Theme.Corner(10) })
	local redeem = Theme.Button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(140, 46),
		Text = "🎟️ Redeem",
		BackgroundColor3 = Theme.Purple,
		Parent = codes,
	})
	redeem.Activated:Connect(function()
		if box.Text ~= "" then
			ctx.Net.Send("RedeemCode", box.Text)
			box.Text = ""
		end
	end)

	tutorialRow = Theme.Row(page, 4, 60)
	Theme.Label({
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -170, 0, 40),
		Text = "🎓 Skip the tutorial",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = tutorialRow,
	})
	local skip = Theme.Button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(120, 44),
		Text = "Skip",
		BackgroundColor3 = Color3.fromRGB(110, 110, 130),
		Parent = tutorialRow,
	})
	skip.Activated:Connect(function()
		ctx.Net.Send("SkipTutorial")
	end)

	local about = Theme.Row(page, 5, 40)
	about.BackgroundTransparency = 1
	Theme.Label({
		Size = UDim2.fromScale(1, 1),
		Text = "Follow us for codes! 🎟️",
		TextColor3 = Theme.Muted,
		Parent = about,
	})
end

function Page.Update(state)
	for setting, button in toggles do
		local on = state.Settings[setting] ~= false
		button.Text = if on then "ON" else "OFF"
		button.BackgroundColor3 = if on then Theme.Green else Color3.fromRGB(90, 90, 100)
	end
	tutorialRow.Visible = state.Tutorial ~= 0
end

return Page
