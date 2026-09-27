--[[
	Theme: shared colors, font and small UI helpers.
	Change the look of the whole UI here.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Theme = {
	Font = Enum.Font.FredokaOne,
	Background = Color3.fromRGB(30, 30, 45),
	Panel = Color3.fromRGB(45, 45, 65),
	PanelLight = Color3.fromRGB(65, 65, 90),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(180, 180, 200),
	Green = Color3.fromRGB(80, 200, 110),
	Red = Color3.fromRGB(230, 80, 80),
	Blue = Color3.fromRGB(80, 150, 255),
	Gold = Color3.fromRGB(255, 200, 40),
	Purple = Color3.fromRGB(170, 110, 255),
}

function Theme.New(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	local properties: { [string]: any } = props or {}
	local childList: { Instance } = children or {}
	for key, value in properties do
		if key == "Parent" then
			parent = value
		else
			(inst :: any)[key] = value
		end
	end
	for _, child in childList do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Theme.Corner(radius: number?): UICorner
	return Theme.New("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function Theme.Stroke(color: Color3?, thickness: number?): UIStroke
	return Theme.New("UIStroke", {
		Color = color or Color3.new(0, 0, 0),
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Theme.TextStroke(thickness: number?): UIStroke
	return Theme.New("UIStroke", { Thickness = thickness or 2 })
end

function Theme.Label(props: { [string]: any }): TextLabel
	local label = Theme.New("TextLabel", {
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextColor3 = Theme.Text,
		TextScaled = true,
	}, { Theme.TextStroke(1.5) })
	for key, value in props do
		if key ~= "Parent" then
			(label :: any)[key] = value
		end
	end
	label.Parent = props.Parent
	return label
end

-- Glossy look (like big Roblox simulator games): lighter at the top,
-- darker at the bottom. Works on any colored Frame or button.
function Theme.Gloss(gui: GuiObject)
	Theme.New("UIGradient", {
		Name = "Gloss",
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(235, 235, 235)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 170, 170)),
		}),
		Parent = gui,
	})
end

-- Big bold number text with a thick outline (money, counters).
function Theme.BigLabel(props: { [string]: any }): TextLabel
	local label = Theme.Label(props)
	label.Font = Enum.Font.FredokaOne
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Thickness = 3
		stroke.LineJoinMode = Enum.LineJoinMode.Round
	end
	return label
end

-- A chunky button with hover and press animations.
function Theme.Button(props: { [string]: any }): TextButton
	local color = props.BackgroundColor3 or Theme.Blue
	local button = Theme.New("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = color,
		Font = Theme.Font,
		TextColor3 = Theme.Text,
		TextScaled = true,
	}, {
		Theme.Corner(10),
		Theme.New("UIStroke", {
			Name = "Border",
			Thickness = 3,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Theme.New("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		}),
	})
	for key, value in props do
		if key ~= "Parent" then
			(button :: any)[key] = value
		end
	end
	Theme.TextStroke(2.5).Parent = button
	Theme.Gloss(button)
	local scale = Theme.New("UIScale", { Parent = button })
	local info = TweenInfo.new(0.12)
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, info, { Scale = 1.05 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, info, { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, info, { Scale = 0.92 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, info, { Scale = 1.05 }):Play()
	end)
	button.Parent = props.Parent
	return button
end

-- Scales a GUI cluster with the screen size so it fits phones and PCs.
function Theme.AutoScale(gui: GuiObject, baseHeight: number?)
	local scale = Theme.New("UIScale", { Parent = gui })
	local function update()
		local camera = Workspace.CurrentCamera
		if camera then
			scale.Scale = math.clamp(camera.ViewportSize.Y / (baseHeight or 800), 0.55, 1.25)
		end
	end
	update()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
	return scale
end

-- A panel row for list pages.
function Theme.Row(parent: Instance, order: number, height: number): Frame
	return Theme.New("Frame", {
		Size = UDim2.new(1, -8, 0, height),
		BackgroundColor3 = Theme.Panel,
		LayoutOrder = order,
		Parent = parent,
	}, { Theme.Corner(12) })
end

-- A progress bar. Returns (bar, fill). Set fill.Size = UDim2.fromScale(0..1, 1).
function Theme.ProgressBar(parent: Instance, props: { [string]: any }): (Frame, Frame)
	local bar = Theme.New("Frame", {
		BackgroundColor3 = Color3.fromRGB(25, 25, 35),
		BorderSizePixel = 0,
	}, { Theme.Corner(8) })
	for key, value in props do
		(bar :: any)[key] = value
	end
	local fill = Theme.New("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Green,
		BorderSizePixel = 0,
		Parent = bar,
	}, { Theme.Corner(8) })
	bar.Parent = parent
	return bar, fill
end

function Theme.ScreenGui(name: string, displayOrder: number?): ScreenGui
	return Theme.New("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder or 0,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
end

return Theme
