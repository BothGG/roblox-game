--[[
	Toasts: small messages at the top, and big banners for server news.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Fx = require(ReplicatedStorage:WaitForChild("Shared").Fx)

local Toasts = {}

local list: Frame
local bannerHolder: Frame
local MAX_TOASTS = 5

function Toasts.Start()
	local gui = Theme.ScreenGui("Toasts", 20)
	list = Theme.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.fromOffset(520, 300),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Theme.New("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})
	Theme.AutoScale(list)
	bannerHolder = Theme.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.18, 0),
		Size = UDim2.fromOffset(640, 110),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Theme.AutoScale(bannerHolder)
end

local order = 0
function Toasts.Notify(text: string, color: Color3?)
	order += 1
	local toasts = {}
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts >= MAX_TOASTS then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		toasts[1]:Destroy()
	end
	local frame = Theme.New("CanvasGroup", {
		Size = UDim2.fromOffset(500, 40),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.15,
		LayoutOrder = order,
		GroupTransparency = 1,
		Parent = list,
	}, {
		Theme.Corner(10),
		Theme.Stroke(color or Theme.Text, 2),
	})
	Theme.Label({
		Size = UDim2.new(1, -20, 1, -8),
		Position = UDim2.fromOffset(10, 4),
		Text = text,
		TextColor3 = color or Theme.Text,
		Parent = frame,
	})
	TweenService:Create(frame, TweenInfo.new(0.2), { GroupTransparency = 0 }):Play()
	task.delay(4, function()
		if frame.Parent then
			local fade = TweenService:Create(frame, TweenInfo.new(0.4), { GroupTransparency = 1 })
			fade:Play()
			fade.Completed:Wait()
			frame:Destroy()
		end
	end)
end

function Toasts.Banner(title: string, text: string?, color: Color3?)
	bannerHolder:ClearAllChildren()
	local banner = Theme.New("CanvasGroup", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, -0.4),
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0.1,
		GroupTransparency = 1,
		Parent = bannerHolder,
	}, {
		Theme.Corner(16),
		Theme.Stroke(color or Theme.Gold, 3),
	})
	local titleLabel = Theme.Label({
		Size = UDim2.new(1, -20, 0.55, 0),
		Position = UDim2.fromOffset(10, 6),
		Text = title,
		TextColor3 = color or Theme.Gold,
		Parent = banner,
	})
	Theme.Label({
		Size = UDim2.new(1, -20, 0.35, 0),
		Position = UDim2.new(0, 10, 0.58, 0),
		Text = text or "",
		TextColor3 = Theme.Text,
		Parent = banner,
	})
	TweenService:Create(banner, TweenInfo.new(0.4, Enum.EasingStyle.Back), {
		Position = UDim2.fromScale(0, 0),
		GroupTransparency = 0,
	}):Play()
	Fx.Primitives.Pop(titleLabel, 0.3)
	Fx.Primitives.Sound("Whoosh", nil, 0.5)
	task.delay(4.5, function()
		if banner.Parent then
			local fade = TweenService:Create(banner, TweenInfo.new(0.4), { GroupTransparency = 1 })
			fade:Play()
			fade.Completed:Wait()
			banner:Destroy()
		end
	end)
end

return Toasts
