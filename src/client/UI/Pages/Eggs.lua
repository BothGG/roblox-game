local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Eggs = require(Shared.Config.Eggs)
local Rarities = require(Shared.Config.Rarities)
local Format = require(Shared.Lib.Format)
local Theme = require(script.Parent.Parent.Theme)

local Page = { Name = "Eggs", Title = "🥚 Egg Shop" }

local buttons: { { Button: TextButton, Price: number } } = {}

function Page.Build(page: ScrollingFrame, ctx)
	for i, eggId in Eggs.Order do
		local egg = Eggs[eggId]
		local r = Theme.Row(page, i, 120)
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
			table.insert(
				lines,
				string.format(
					'<font color="#%s">%s</font> %s',
					Rarities[def.Rarity].Color:ToHex(),
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
			ctx.Net.Send("BuyEgg", eggId)
		end)
		table.insert(buttons, { Button = buy, Price = egg.Price })
	end
	local hint = Theme.Row(page, 99, 40)
	hint.BackgroundTransparency = 1
	Theme.Label({
		Size = UDim2.fromScale(1, 1),
		Text = "🍀 Luck boosts make rare titans more likely!",
		TextColor3 = Theme.Muted,
		Parent = hint,
	})
end

function Page.Update(state)
	for _, entry in buttons do
		entry.Button.BackgroundColor3 = if state.Cash >= entry.Price then Theme.Green else Color3.fromRGB(90, 90, 100)
	end
end

return Page
