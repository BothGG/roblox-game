--[[
	BaseAnimController: makes titans in bases feel alive (client only, no network).
	- gentle breathing bob + looking around
	- a bounce when fed (Fx primitive P.Bounce sets "ClientBounce")
	- "+$" money popping off YOUR titans every few seconds
	- moving shine on rarity badges (RarityTag "Shine" gradients)
	Only animates titans near the camera.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Fx = require(Shared.Fx)
local RarityTag = require(Shared.Fx.RarityTag)
local Format = require(Shared.Lib.Format)

local player = Players.LocalPlayer

local BaseAnimController = {
	Priority = 30,
}

local MAX_DISTANCE = 200
local BOUNCE_TIME = 0.35
local INCOME_EVERY = 3 -- seconds between money popups per titan
local INCOME_DISTANCE = 120

local nextIncome: { [Model]: number } = {}

local function incomePopups(model: Model, home: CFrame, t: number, camera: Camera)
	if model:GetAttribute("OwnerUserId") ~= player.UserId then
		return
	end
	local income = model:GetAttribute("Income")
	if type(income) ~= "number" or income <= 0 then
		return
	end
	local due = nextIncome[model]
	if not due then
		-- Stagger titans so the popups ripple instead of all firing at once.
		nextIncome[model] = t + math.random() * INCOME_EVERY
		return
	end
	if t < due then
		return
	end
	nextIncome[model] = t + INCOME_EVERY
	if (home.Position - camera.CFrame.Position).Magnitude > INCOME_DISTANCE then
		return
	end
	local top = home.Position + Vector3.new(0, model:GetExtentsSize().Y + 1, 0)
	Fx.Play("Income", { Position = top, Text = "+" .. Format.Money(income * INCOME_EVERY) })
end

function BaseAnimController:Start()
	local elapsed = 0
	RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed < 1 / 30 then
			return
		end
		elapsed = 0
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local t = os.clock()
		for _, model in CollectionService:GetTagged("BaseTitan") do
			if not model:IsA("Model") then
				continue
			end
			local home = model:GetAttribute("Home")
			if typeof(home) ~= "CFrame" then
				continue
			end
			incomePopups(model, home, t, camera)
			if (home.Position - camera.CFrame.Position).Magnitude > MAX_DISTANCE then
				continue
			end
			local scale = model:GetScale()
			local seed = (tonumber(model.Name) or 0) * 1.7
			local bob = (math.sin(t * 2 + seed) + 1) * 0.08 * scale
			local yaw = math.sin(t * 0.6 + seed) * 0.25
			local bounceAt = model:GetAttribute("ClientBounce")
			if type(bounceAt) == "number" and t - bounceAt < BOUNCE_TIME then
				bob += math.sin(math.pi * (t - bounceAt) / BOUNCE_TIME) * 1.2 * scale
			end
			model:PivotTo(home * CFrame.new(0, bob, 0) * CFrame.Angles(0, yaw, 0))
		end
		-- Shine sweeping across rarity badges.
		local shine = ((t * 0.6) % 2) - 1
		for _, gradient in CollectionService:GetTagged(RarityTag.ShineTag) do
			if gradient:IsA("UIGradient") then
				gradient.Offset = Vector2.new(shine, 0)
			end
		end
	end)
	CollectionService:GetInstanceRemovedSignal("BaseTitan"):Connect(function(model)
		nextIncome[model] = nil
	end)
end

return BaseAnimController
