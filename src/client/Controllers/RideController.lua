--[[
	RideController: the local player's side of riding titans and followers.

	Keys while riding:
	  Shift = sprint (runners)      V = fly / land (flyers)
	  Space = jump (flying: up)     Ctrl = down while flying
	  Click = attack   Q = special  X = get off
	Phones use the big buttons on the ride panel (RideHud).

	Flying is done here with a LinearVelocity on your character (your
	client moves your character); the server only allows it while you
	have stamina (RideMode attribute = "Fly").
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)

local UI = script.Parent.Parent:WaitForChild("UI")
local RideHud = require(UI.RideHud)
local Hud = require(UI.Hud)

local player = Players.LocalPlayer

local RideController = {
	Priority = 22,
}

local savedZoom: { Min: number, Max: number }? = nil
local flight: LinearVelocity? = nil
local flightAttachment: Attachment? = nil

local function riding(): boolean
	return player:GetAttribute("Riding") ~= nil
end

local function send(action: string, on: boolean?)
	if not riding() then
		return
	end
	if action == "Attack" then
		if RideHud.CooldownLeft("Attack") > 0 then
			return
		end
		RideHud.StartCooldown("Attack", GameConfig.Battle.AttackCooldown)
	elseif action == "Special" then
		if RideHud.CooldownLeft("Special") > 0 then
			return
		end
		RideHud.StartCooldown("Special", player:GetAttribute("RideSpecialCd") or 6)
	elseif action == "Fly" and on then
		on = player:GetAttribute("RideMode") ~= "Fly" -- the button toggles
	end
	Net.Send("RideAction", action, on)
end

local function setCamera(on: boolean)
	if on then
		local scale = player:GetAttribute("RideScale") or 1
		if not savedZoom then
			savedZoom = { Min = player.CameraMinZoomDistance, Max = player.CameraMaxZoomDistance }
		end
		player.CameraMaxZoomDistance = math.max(90, scale * 40)
		player.CameraMinZoomDistance = math.max(12, scale * 8)
	elseif savedZoom then
		player.CameraMinZoomDistance = savedZoom.Min
		player.CameraMaxZoomDistance = savedZoom.Max
		savedZoom = nil
	end
end

local function stopFlying()
	if flight then
		flight:Destroy()
		flight = nil
	end
	if flightAttachment then
		flightAttachment:Destroy()
		flightAttachment = nil
	end
end

local function updateFlight()
	local flying = riding() and player:GetAttribute("RideMode") == "Fly"
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not flying or not root or not humanoid then
		stopFlying()
		return
	end
	if not flight then
		local attachment = Instance.new("Attachment")
		attachment.Name = "FlyAttachment"
		attachment.Parent = root
		local velocity = Instance.new("LinearVelocity")
		velocity.Attachment0 = attachment
		velocity.MaxForce = math.huge
		velocity.RelativeTo = Enum.ActuatorRelativeTo.World
		velocity.Parent = root
		flight, flightAttachment = velocity, attachment
	end
	local speed = player:GetAttribute("RideFlySpeed") or 30
	local up = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		up = speed * 0.7
	elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.C) then
		up = -speed * 0.7
	end
	local velocity = flight :: LinearVelocity
	velocity.VectorVelocity = humanoid.MoveDirection * speed + Vector3.new(0, up, 0)
end

function RideController:Start()
	RideHud.Start(send, function(command)
		Net.Send("FollowerCommand", command)
	end)

	local function onRidingChanged()
		local on = riding()
		RideHud.SetRiding(on)
		Hud.SetBattleMode(on)
		setCamera(on)
		if not on then
			stopFlying()
		end
	end
	player:GetAttributeChangedSignal("Riding"):Connect(onRidingChanged)
	player:GetAttributeChangedSignal("Followers"):Connect(function()
		RideHud.SetFollowers(player:GetAttribute("Followers") or 0)
	end)
	onRidingChanged()

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not riding() then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			send("Attack")
		elseif input.KeyCode == Enum.KeyCode.Q then
			send("Special")
		elseif input.KeyCode == Enum.KeyCode.X then
			send("Dismount")
		elseif input.KeyCode == Enum.KeyCode.LeftShift then
			send("Sprint", true)
		elseif input.KeyCode == Enum.KeyCode.V then
			send("Fly", true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if riding() and input.KeyCode == Enum.KeyCode.LeftShift then
			send("Sprint", false)
		end
	end)

	RunService.RenderStepped:Connect(function()
		if riding() then
			RideHud.Refresh()
		end
		updateFlight()
	end)
end

return RideController
