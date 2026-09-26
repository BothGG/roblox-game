--[[
	Window: the pop-up menu. Each page is a module in UI/Pages that returns

	  { Name = "Eggs", Title = "🥚 Egg Shop", Build = function(page, ctx) ... end,
	    Update = function(state) ... end,   -- optional, called on every snapshot
	    Opened = function() ... end }       -- optional, called when shown

	  Window.Open("Eggs") / Window.Close() / Window.Toggle("Eggs")
]]

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Window = {
	Pages = {} :: { [string]: any },
	Current = nil :: string?,
	State = nil :: any,
}

local frame: Frame
local titleLabel: TextLabel
local containers: { [string]: ScrollingFrame } = {}

function Window.Start()
	local gui = Theme.ScreenGui("Menu", 10)
	frame = Theme.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(660, 480),
		BackgroundColor3 = Theme.Background,
		Visible = false,
		Parent = gui,
	}, { Theme.Corner(18), Theme.Stroke(Theme.Gold, 3) })
	Theme.AutoScale(frame)
	titleLabel = Theme.Label({
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -90, 0, 44),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	local close = Theme.Button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(48, 44),
		Text = "X",
		BackgroundColor3 = Theme.Red,
		Parent = frame,
	})
	close.Activated:Connect(Window.Close)
end

function Window.AddPage(page, ctx)
	local container = Theme.New("ScrollingFrame", {
		Name = page.Name,
		Position = UDim2.fromOffset(12, 64),
		Size = UDim2.new(1, -24, 1, -76),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Visible = false,
		Parent = frame,
	}, {
		Theme.New("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	containers[page.Name] = container
	Window.Pages[page.Name] = page
	page.Build(container, ctx)
end

function Window.Open(name: string)
	local page = Window.Pages[name]
	if not page then
		return
	end
	for pageName, container in containers do
		container.Visible = pageName == name
	end
	titleLabel.Text = page.Title
	Window.Current = name
	frame.Visible = true
	frame.Position = UDim2.fromScale(0.5, 0.56)
	TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.5) })
		:Play()
	if page.Opened then
		page.Opened()
	end
	if Window.State and page.Update then
		page.Update(Window.State)
	end
end

function Window.Close()
	frame.Visible = false
	Window.Current = nil
end

function Window.Toggle(name: string)
	if Window.Current == name then
		Window.Close()
	else
		Window.Open(name)
	end
end

function Window.Update(state)
	Window.State = state
	for _, page in Window.Pages do
		if page.Update then
			local ok, err = pcall(page.Update, state)
			if not ok then
				warn("[Window] page update failed:", page.Name, err)
			end
		end
	end
end

return Window
