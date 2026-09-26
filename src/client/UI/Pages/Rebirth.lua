local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Format = require(Shared.Lib.Format)
local Theme = require(script.Parent.Parent.Theme)

local Page = { Name = "Rebirth", Title = "🌟 Rebirth" }

local refs: { [string]: any } = {}

function Page.Build(page: ScrollingFrame, ctx)
	local r = Theme.Row(page, 1, 320)
	r.BackgroundTransparency = 1
	refs.Current = Theme.Label({ Size = UDim2.new(1, 0, 0, 34), Text = "", TextColor3 = Theme.Purple, Parent = r })
	Theme.Label({
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 0, 100),
		Text = string.format(
			"You get forever:\n+%d%% income  •  +%d pen  •  +%d food storage",
			math.round(GameConfig.RebirthIncomeBonus * 100),
			GameConfig.SlotsPerRebirth,
			GameConfig.StorageCapPerRebirth
		),
		TextWrapped = true,
		TextColor3 = Theme.Green,
		Parent = r,
	})
	Theme.Label({
		Position = UDim2.fromOffset(0, 150),
		Size = UDim2.new(1, 0, 0, 56),
		Text = "⚠️ You lose your "
			.. GameConfig.CreatureNamePlural
			.. ", cash and food.\nTrophies and your Index are kept.",
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(255, 170, 120),
		Parent = r,
	})
	local button = Theme.Button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 220),
		Size = UDim2.fromOffset(280, 64),
		Text = "Rebirth",
		BackgroundColor3 = Theme.Purple,
		Parent = r,
	})
	button.Activated:Connect(function()
		ctx.Net.Send("Rebirth")
		ctx.Window.Close()
	end)
	refs.Button = button
end

function Page.Update(state)
	refs.Current.Text = "Rebirth " .. state.Rebirths .. " → " .. (state.Rebirths + 1)
	refs.Button.Text = "Rebirth for " .. Format.Money(state.RebirthCost)
	refs.Button.BackgroundColor3 = if state.Cash >= state.RebirthCost then Theme.Purple else Color3.fromRGB(90, 90, 100)
end

return Page
