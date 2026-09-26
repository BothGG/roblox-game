--[[
	Primitives: small, reusable effect building blocks (client only).
	Presets combine these into named effects.

	World effects:  Burst, Ring, Pillar, Light, FloatText, Sound, Highlight
	Screen effects: Shake, Flash, Vignette, Confetti, Pop
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Textures = require(script.Parent.Textures)
local Sounds = require(script.Parent.Parent.Config.Sounds)

local player = Players.LocalPlayer

local Primitives = {}

local FONT = Enum.Font.FredokaOne

local function tween(
	instance: Instance,
	time: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
)
	local t = TweenService:Create(
		instance,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end
Primitives.Tween = tween

local fxFolder: Folder? = nil
local function getFolder(): Folder
	if not fxFolder or not fxFolder.Parent then
		local folder = Instance.new("Folder")
		folder.Name = "LocalFx"
		folder.Parent = Workspace
		fxFolder = folder
	end
	return fxFolder :: Folder
end

local function holderPart(position: Vector3, size: Vector3?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size or Vector3.one
	p.CFrame = CFrame.new(position)
	p.Parent = getFolder()
	return p
end

local overlayGui: ScreenGui? = nil
local function getOverlay(): ScreenGui
	if not overlayGui or not overlayGui.Parent then
		local gui = Instance.new("ScreenGui")
		gui.Name = "FxOverlay"
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 100
		gui.Parent = player:WaitForChild("PlayerGui")
		overlayGui = gui
	end
	return overlayGui :: ScreenGui
end

local function toSequence(color: Color3 | ColorSequence): ColorSequence
	if typeof(color) == "ColorSequence" then
		return color
	end
	return ColorSequence.new(color :: Color3)
end

-- Distance from the camera, used by presets to skip far-away effects.
function Primitives.Distance(position: Vector3): number
	local camera = Workspace.CurrentCamera
	if not camera then
		return 0
	end
	return (camera.CFrame.Position - position).Magnitude
end

function Primitives.IsMe(userId: number?): boolean
	return userId == player.UserId
end

--------------------------------------------------------------------------
-- World effects
--------------------------------------------------------------------------

export type BurstOptions = {
	Color: (Color3 | ColorSequence)?,
	Count: number?,
	Speed: number?,
	Size: number?,
	Lifetime: number?,
	Gravity: number?,
	Spread: number?,
	Texture: string?,
	LightEmission: number?,
}

-- A one-shot explosion of particles.
function Primitives.Burst(position: Vector3, opts: BurstOptions?)
	local o: BurstOptions = opts or {}
	local lifetime = o.Lifetime or 0.8
	local speed = o.Speed or 20
	local size = o.Size or 0.7
	local holder = holderPart(position)
	local e = Instance.new("ParticleEmitter")
	e.Texture = o.Texture or Textures.Sparkle
	e.Color = toSequence(o.Color or Color3.new(1, 1, 1))
	e.LightEmission = o.LightEmission or 1
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(o.Spread or 180, o.Spread or 180)
	e.Lifetime = NumberRange.new(lifetime * 0.6, lifetime)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.7, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Drag = 3
	e.Acceleration = Vector3.new(0, o.Gravity or -15, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-180, 180)
	e.Rate = 0
	e.Parent = holder
	e:Emit(o.Count or 20)
	Debris:AddItem(holder, lifetime + 1)
end

-- A flat shockwave that expands outward and fades.
function Primitives.Ring(
	position: Vector3,
	opts: { Color: Color3?, Radius: number?, Duration: number?, Thickness: number? }?
)
	local o = opts or {}
	local radius = o.Radius or 12
	local duration = o.Duration or 0.5
	local thickness = o.Thickness or 0.3
	local ring = holderPart(position)
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = o.Color or Color3.new(1, 1, 1)
	ring.Transparency = 0.2
	ring.Size = Vector3.new(thickness, 1, 1)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	tween(ring, duration, { Size = Vector3.new(thickness, radius * 2, radius * 2), Transparency = 1 })
	Debris:AddItem(ring, duration + 0.1)
end

-- A vertical beam of light (great for rare hatches, new king, mutations).
function Primitives.Pillar(
	position: Vector3,
	opts: { Color: Color3?, Height: number?, Width: number?, Duration: number? }?
)
	local o = opts or {}
	local height = o.Height or 60
	local width = o.Width or 6
	local duration = o.Duration or 1.2
	local pillar = holderPart(position + Vector3.new(0, height / 2, 0))
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Material = Enum.Material.Neon
	pillar.Color = o.Color or Color3.new(1, 1, 1)
	pillar.Transparency = 0.3
	pillar.Size = Vector3.new(height, width, width)
	pillar.CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	tween(
		pillar,
		duration,
		{ Size = Vector3.new(height, 0.1, 0.1), Transparency = 1 },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	Debris:AddItem(pillar, duration + 0.1)
end

-- A short flash of light that lights up nearby objects.
function Primitives.Light(
	position: Vector3,
	opts: { Color: Color3?, Brightness: number?, Range: number?, Duration: number? }?
)
	local o = opts or {}
	local holder = holderPart(position)
	local light = Instance.new("PointLight")
	light.Color = o.Color or Color3.new(1, 1, 1)
	light.Brightness = o.Brightness or 5
	light.Range = o.Range or 20
	light.Shadows = false
	light.Parent = holder
	local duration = o.Duration or 0.6
	tween(light, duration, { Brightness = 0 })
	Debris:AddItem(holder, duration + 0.1)
end

-- Text that pops up and floats away ("+XP", "LEVEL 10!", "+$500").
function Primitives.FloatText(
	position: Vector3,
	text: string,
	opts: { Color: Color3?, Size: number?, Duration: number?, Rise: number? }?
)
	local o = opts or {}
	local size = o.Size or 2.5
	local duration = o.Duration or 1.2
	local holder = holderPart(position)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(size * 5, size)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 250
	gui.Parent = holder
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = o.Color or Color3.new(1, 1, 1)
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = label
	tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(gui, duration, { StudsOffset = Vector3.new(0, o.Rise or 5, 0) })
	task.delay(duration * 0.6, function()
		tween(label, duration * 0.4, { TextTransparency = 1 })
		tween(stroke, duration * 0.4, { Transparency = 1 })
	end)
	Debris:AddItem(holder, duration + 0.2)
end

-- Plays a sound. `sound` is a key from Config/Sounds.lua or a raw sound id.
-- With a position it is 3D, otherwise it plays for this player only.
function Primitives.Sound(sound: string, position: Vector3?, volume: number?, pitch: number?)
	local id = Sounds[sound] or sound
	if id == nil or id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	s.PlaybackSpeed = pitch or 1
	if position then
		local holder = holderPart(position)
		s.RollOffMaxDistance = 200
		s.Parent = holder
		s:Play()
		Debris:AddItem(holder, 6)
	else
		SoundService:PlayLocalSound(s)
		s:Destroy()
	end
end

-- Briefly makes a model glow.
function Primitives.Highlight(model: Instance, opts: { Color: Color3?, Duration: number? }?)
	local o = opts or {}
	local duration = o.Duration or 0.6
	local h = Instance.new("Highlight")
	h.FillColor = o.Color or Color3.new(1, 1, 1)
	h.OutlineColor = Color3.new(1, 1, 1)
	h.FillTransparency = 0.2
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = model
	tween(h, duration, { FillTransparency = 1, OutlineTransparency = 1 })
	Debris:AddItem(h, duration + 0.1)
end

--------------------------------------------------------------------------
-- Screen effects
--------------------------------------------------------------------------

local shakeStrength = 0
local shakeEnd = 0
local shakeDuration = 1
local shakeConnection: RBXScriptConnection? = nil

-- Camera shake. Stronger shakes override weaker ones.
function Primitives.Shake(intensity: number, duration: number?)
	local now = os.clock()
	local remaining = math.max(0, shakeEnd - now)
	if intensity < shakeStrength and remaining > 0 then
		return
	end
	shakeStrength = intensity
	shakeDuration = duration or 0.4
	shakeEnd = now + shakeDuration
	if shakeConnection then
		return
	end
	shakeConnection = RunService.RenderStepped:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local left = shakeEnd - os.clock()
		if left <= 0 or not humanoid then
			if humanoid then
				humanoid.CameraOffset = Vector3.zero
			end
			shakeStrength = 0
			if shakeConnection then
				shakeConnection:Disconnect()
				shakeConnection = nil
			end
			return
		end
		local falloff = left / shakeDuration
		local s = shakeStrength * falloff
		humanoid.CameraOffset = Vector3.new((math.random() * 2 - 1) * s, (math.random() * 2 - 1) * s, 0)
	end)
end

-- Full-screen color flash.
function Primitives.Flash(color: Color3?, duration: number?, startTransparency: number?)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = color or Color3.new(1, 1, 1)
	frame.BackgroundTransparency = startTransparency or 0.3
	frame.ZIndex = 50
	frame.Parent = getOverlay()
	local d = duration or 0.4
	tween(frame, d, { BackgroundTransparency = 1 })
	Debris:AddItem(frame, d + 0.1)
end

-- Colored glow around the screen edges (e.g. red when someone steals from you).
function Primitives.Vignette(color: Color3?, duration: number?)
	local group = Instance.new("CanvasGroup")
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundTransparency = 1
	group.GroupTransparency = 1
	group.ZIndex = 40
	group.Parent = getOverlay()
	local edges = {
		{ UDim2.fromScale(1, 0.25), UDim2.fromScale(0, 0), 90 },
		{ UDim2.fromScale(1, 0.25), UDim2.fromScale(0, 0.75), -90 },
		{ UDim2.fromScale(0.2, 1), UDim2.fromScale(0, 0), 0 },
		{ UDim2.fromScale(0.2, 1), UDim2.fromScale(0.8, 0), 180 },
	}
	for _, edge in edges do
		local f = Instance.new("Frame")
		f.Size = edge[1]
		f.Position = edge[2]
		f.BorderSizePixel = 0
		f.BackgroundColor3 = color or Color3.fromRGB(255, 40, 40)
		f.Parent = group
		local g = Instance.new("UIGradient")
		g.Rotation = edge[3]
		g.Transparency = NumberSequence.new(0, 1)
		g.Parent = f
	end
	local d = duration or 1.2
	tween(group, d * 0.2, { GroupTransparency = 0.2 })
	task.delay(d * 0.4, function()
		tween(group, d * 0.6, { GroupTransparency = 1 })
	end)
	Debris:AddItem(group, d + 0.1)
end

-- Confetti falling over the screen (celebrations).
function Primitives.Confetti(count: number?, colors: { Color3 }?)
	local palette = colors
		or {
			Color3.fromRGB(255, 80, 80),
			Color3.fromRGB(255, 210, 60),
			Color3.fromRGB(80, 220, 120),
			Color3.fromRGB(80, 160, 255),
			Color3.fromRGB(200, 100, 255),
		}
	local overlay = getOverlay()
	for _ = 1, count or 60 do
		local f = Instance.new("Frame")
		f.Size = UDim2.fromOffset(math.random(8, 14), math.random(14, 22))
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.new(math.random(), 0, -0.05, 0)
		f.Rotation = math.random(0, 360)
		f.BorderSizePixel = 0
		f.BackgroundColor3 = palette[math.random(1, #palette)]
		f.ZIndex = 45
		f.Parent = overlay
		local duration = 1.5 + math.random() * 1.5
		tween(f, duration, {
			Position = UDim2.new(f.Position.X.Scale + (math.random() - 0.5) * 0.3, 0, 1.1, 0),
			Rotation = f.Rotation + math.random(-540, 540),
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Debris:AddItem(f, duration + 0.1)
	end
end

-- Launches the local player's character (used for knockbacks, since each
-- client controls its own character's physics).
function Primitives.Knockback(velocity: Vector3)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and root then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		root.AssemblyLinearVelocity = velocity
	end
end

-- Makes a zoo kaiju do a little jump (animated by ZooAnimController).
function Primitives.Bounce(model: Instance?)
	if model and model.Parent then
		model:SetAttribute("ClientBounce", os.clock())
	end
end

-- Bouncy "pop" on a UI element (buttons, counters).
function Primitives.Pop(gui: GuiObject, amount: number?)
	local scale = gui:FindFirstChild("PopScale") :: UIScale?
	if not scale then
		local s = Instance.new("UIScale")
		s.Name = "PopScale"
		s.Parent = gui
		scale = s
	end
	local s = scale :: UIScale
	s.Scale = 1 + (amount or 0.2)
	tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

return Primitives
