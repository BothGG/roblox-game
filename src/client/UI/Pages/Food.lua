local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Foods = require(Shared.Config.Foods)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Format = require(Shared.Lib.Format)
local Theme = require(script.Parent.Parent.Theme)

local Page = { Name = "Food", Title = "🍖 Food Shop" }

local buttons: { { Button: TextButton, Price: number } } = {}

function Page.Build(page: ScrollingFrame, ctx)
	local order = 0
	for _, foodId in Foods.Order do
		local def = Foods[foodId]
		if not def.Price then
			continue
		end
		order += 1
		local r = Theme.Row(page, order, 80)
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
				ctx.Net.Send("BuyFood", foodId, amount)
			end)
			table.insert(buttons, { Button = buy, Price = def.Price * amount })
		end
	end
	local hint = Theme.Row(page, order + 1, 60)
	hint.BackgroundTransparency = 1
	Theme.Label({
		Size = UDim2.fromScale(1, 1),
		Text = "Rare food only grows in the fields around the arena... or you can steal it 😈",
		TextWrapped = true,
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
