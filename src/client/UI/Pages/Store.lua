local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosts = require(Shared.Config.Boosts)
local Store = require(Shared.Config.Store)
local Format = require(Shared.Lib.Format)
local Theme = require(script.Parent.Parent.Theme)

local Page = { Name = "Store", Title = "💎 Store" }

local passButtons = {}
local boostLabel: TextLabel

local function section(page: ScrollingFrame, order: number, text: string)
	local r = Theme.Row(page, order, 30)
	r.BackgroundTransparency = 1
	Theme.Label({
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.Gold,
		Parent = r,
	})
end

local function itemRow(
	page: ScrollingFrame,
	order: number,
	icon: string,
	name: string,
	description: string,
	price: string,
	available: boolean
)
	local r = Theme.Row(page, order, 70)
	Theme.Label({ Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(50, 50), Text = icon, Parent = r })
	Theme.Label({
		Position = UDim2.fromOffset(70, 6),
		Size = UDim2.new(1, -230, 0, 30),
		Text = name,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = r,
	})
	Theme.Label({
		Position = UDim2.fromOffset(70, 38),
		Size = UDim2.new(1, -230, 0, 24),
		Text = description,
		TextColor3 = Theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = r,
	})
	return Theme.Button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(140, 50),
		Text = if available then price else "Coming soon",
		BackgroundColor3 = if available then Theme.Green else Color3.fromRGB(90, 90, 100),
		Parent = r,
	})
end

function Page.Build(page: ScrollingFrame, _ctx)
	local player = Players.LocalPlayer
	local top = Theme.Row(page, 0, 40)
	top.BackgroundTransparency = 1
	boostLabel = Theme.Label({
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextColor3 = Theme.Green,
		TextWrapped = true,
		Parent = top,
	})

	section(page, 1, "Game passes (forever)")
	for i, key in Store.PassOrder do
		local pass = Store.Passes[key]
		local button = itemRow(page, 1 + i, pass.Icon, pass.Name, pass.Description, pass.PriceLabel, pass.Id ~= 0)
		button.Activated:Connect(function()
			if pass.Id ~= 0 then
				MarketplaceService:PromptGamePassPurchase(player, pass.Id)
			end
		end)
		passButtons[key] = { Button = button, Available = pass.Id ~= 0, Price = pass.PriceLabel }
	end
	section(page, 20, "Items")
	for i, key in Store.ProductOrder do
		local product = Store.Products[key]
		local button = itemRow(page, 20 + i, product.Icon, product.Name, "", product.PriceLabel, product.Id ~= 0)
		button.Activated:Connect(function()
			if product.Id ~= 0 then
				MarketplaceService:PromptProductPurchase(player, product.Id)
			end
		end)
	end
end

function Page.Update(state)
	for key, entry in passButtons do
		if state.Passes[key] then
			entry.Button.Text = "Owned ✓"
			entry.Button.BackgroundColor3 = Color3.fromRGB(70, 110, 80)
		end
	end
	local now = Workspace:GetServerTimeNow()
	local active = {}
	for _, id in Boosts.Order do
		local expiresAt = state.Boosts[id]
		if expiresAt and expiresAt > now then
			table.insert(active, Boosts[id].Icon .. " " .. Boosts[id].Name .. " " .. Format.Time(expiresAt - now))
		end
	end
	boostLabel.Text = if #active > 0 then "Active boosts: " .. table.concat(active, "   ") else "No active boosts"
end

return Page
