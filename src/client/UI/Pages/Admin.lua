--[[ Admin page: test commands (only shown to admins / in Studio). ]]

local Theme = require(script.Parent.Parent.Theme)

local Page = { Name = "Admin", Title = "🛠️ Admin" }

local QUICK = {
	"cash 1000000",
	"food StarFood 5",
	"food FirePepper 10",
	"level 25",
	"give Hydra Golden",
	"give Drake",
	"trophies 100",
	"boost Luck 30",
	"wild Hydra",
	"wild Phoenix Golden",
	"event TitanClash",
	"event WildRush",
	"event MeteorFeast",
	"event BloodMoon",
	"practice",
	"daily",
	"quests",
	"tutorial",
}

function Page.Build(page: ScrollingFrame, ctx)
	local top = Theme.Row(page, 1, 70)
	local box = Theme.New("TextBox", {
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.new(1, -160, 0, 46),
		BackgroundColor3 = Color3.fromRGB(25, 25, 35),
		TextColor3 = Theme.Text,
		PlaceholderText = "command (e.g. cash 5000)",
		PlaceholderColor3 = Theme.Muted,
		Font = Theme.Font,
		TextScaled = true,
		Text = "",
		ClearTextOnFocus = false,
		Parent = top,
	}, { Theme.Corner(10) })
	local run = Theme.Button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(130, 46),
		Text = "Run",
		BackgroundColor3 = Theme.Blue,
		Parent = top,
	})
	run.Activated:Connect(function()
		if box.Text ~= "" then
			ctx.Net.Send("AdminCommand", box.Text)
		end
	end)
	local grid = Theme.Row(page, 2, 330)
	grid.BackgroundTransparency = 1
	Theme.New("UIGridLayout", {
		CellSize = UDim2.fromOffset(196, 44),
		CellPadding = UDim2.fromOffset(6, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = grid,
	})
	for _, command in QUICK do
		local button = Theme.Button({ Text = command, BackgroundColor3 = Color3.fromRGB(70, 80, 120), Parent = grid })
		button.Activated:Connect(function()
			ctx.Net.Send("AdminCommand", command)
		end)
	end
end

return Page
