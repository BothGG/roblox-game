--[[
	TutorialController: shows the current tutorial step at the top of the
	screen and points an arrow (a glowing beam) at the target.
	Steps come from Config/Tutorial.lua; progress comes from the server.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tutorial = require(Shared.Config.Tutorial)
local Tags = require(Shared.Game.Tags)
local ClientState = require(script.Parent.Parent.State.ClientState)

local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI.Theme)
local Hud = require(UI.Hud)

local player = Players.LocalPlayer

local TutorialController = {
	Priority = 40,
}

local bar: Frame
local label: TextLabel
local beam: Beam
local fromAttachment: Attachment
local toAttachment: Attachment
local toPart: Part
local step: any = nil

local function nearest(tag: string, filter: ((Instance) -> boolean)?): Vector3?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local best, bestDist = nil, math.huge
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsA("Model") and inst.PrimaryPart and (not filter or filter(inst)) then
			local d = (inst.PrimaryPart.Position - root.Position).Magnitude
			if d < bestDist then
				best, bestDist = inst.PrimaryPart.Position, d
			end
		end
	end
	return best
end

local function targetPosition(): Vector3?
	if not step then
		return nil
	end
	if step.Target == "MyTitan" then
		return nearest(Tags.BaseTitan, function(model)
			return model:GetAttribute("OwnerUserId") == player.UserId
		end)
	elseif step.Target == "Food" then
		return nearest(Tags.FoodPickup)
	elseif step.Target == "Wild" then
		return nearest(Tags.WildTitan)
	elseif step.Target == "Arena" then
		local arena = CollectionService:GetTagged(Tags.Arena)[1]
		return if arena and arena:IsA("BasePart") then arena.Position else Vector3.new(0, 2, 0)
	end
	return nil
end

function TutorialController:Start()
	local gui = Theme.ScreenGui("Tutorial", 6)
	bar = Theme.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 176),
		Size = UDim2.fromOffset(560, 46),
		BackgroundColor3 = Color3.fromRGB(40, 60, 40),
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = gui,
	}, { Theme.Corner(12), Theme.Stroke(Theme.Green, 3) })
	Theme.AutoScale(bar)
	label =
		Theme.Label({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 1, -8), Text = "", Parent = bar })

	toPart = Instance.new("Part")
	toPart.Name = "TutorialTarget"
	toPart.Anchored = true
	toPart.CanCollide = false
	toPart.CanQuery = false
	toPart.CanTouch = false
	toPart.Transparency = 1
	toPart.Size = Vector3.one
	toPart.Parent = Workspace
	toAttachment = Instance.new("Attachment")
	toAttachment.Parent = toPart
	fromAttachment = Instance.new("Attachment")
	beam = Instance.new("Beam")
	beam.Attachment1 = toAttachment
	beam.Color = ColorSequence.new(Color3.fromRGB(120, 255, 140))
	beam.LightEmission = 1
	beam.Width0 = 1.2
	beam.Width1 = 1.2
	beam.FaceCamera = true
	beam.Segments = 20
	beam.CurveSize0 = 8
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureSpeed = 2
	beam.Enabled = false
	beam.Parent = toPart

	local function refreshVisible()
		bar.Visible = step ~= nil and not player:GetAttribute("InBattle")
	end
	player:GetAttributeChangedSignal("InBattle"):Connect(refreshVisible)

	ClientState.Changed:Connect(function(state)
		local index = state.Tutorial
		step = if index and index > 0 then Tutorial.Steps[index] else nil
		refreshVisible()
		if step then
			local progress = if step.Count > 1
				then string.format(" (%d/%d)", state.TutorialProgress, step.Count)
				else ""
			label.Text = string.format("🎓 %d/%d: %s%s", index, #Tutorial.Steps, step.Text, progress)
		end
		local menuTarget = step and string.match(step.Target, "^Menu:(.+)$")
		Hud.Highlight(menuTarget)
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.2 then
			return
		end
		elapsed = 0
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local target = targetPosition()
		if root and target and not player:GetAttribute("InBattle") then
			if fromAttachment.Parent ~= root then
				fromAttachment.Parent = root
				beam.Attachment0 = fromAttachment
			end
			toPart.Position = target + Vector3.new(0, 3, 0)
			beam.Enabled = true
		else
			beam.Enabled = false
		end
	end)
end

return TutorialController
