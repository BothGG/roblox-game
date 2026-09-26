--[[
	BiomeController:
	- works out which biome the local player is in (zones from ReplicatedStorage.MapInfo)
	- fades lighting/atmosphere to that biome's Ambience
	- makes gate walls see-through + walkable once a biome is unlocked
	  (they stay solid for players who haven't unlocked it)
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Biomes = require(Shared.Config.Biomes)
local Tags = require(Shared.Game.Tags)
local Zones = require(Shared.Game.Zones)
local ClientState = require(script.Parent.Parent.State.ClientState)

local player = Players.LocalPlayer

local BiomeController = {
	Priority = 15,
}

local zones: { Zones.Zone } = {}
local tint: ColorCorrectionEffect

local function loadZones()
	local info = ReplicatedStorage:WaitForChild("MapInfo", 30)
	if not info then
		return
	end
	for _, entry in info:GetChildren() do
		table.insert(zones, {
			Biome = entry:GetAttribute("Biome"),
			Center = entry:GetAttribute("Center"),
			Radius = entry:GetAttribute("Radius"),
			CFrame = entry:GetAttribute("CFrame"),
			Size = entry:GetAttribute("Size"),
		})
	end
end

local function applyAmbience(biomeId: string?)
	local ambience = if biomeId and Biomes[biomeId] then Biomes[biomeId].Ambience else Biomes.HubAmbience
	local info = TweenInfo.new(2, Enum.EasingStyle.Sine)
	local atmosphere = Lighting:FindFirstChildWhichIsA("Atmosphere")
	if atmosphere then
		TweenService:Create(atmosphere, info, { Color = ambience.AtmosphereColor, Density = ambience.Density }):Play()
	end
	TweenService:Create(tint, info, { TintColor = ambience.Tint }):Play()
	TweenService:Create(Lighting, info, { Brightness = ambience.Brightness }):Play()
end

local function refreshGate(gate: Instance)
	if not gate:IsA("BasePart") then
		return
	end
	local biome = gate:GetAttribute("Biome")
	local open = type(biome) == "string" and ClientState.IsUnlocked(biome)
	-- Local changes: only affect this player's view and character.
	gate.CanCollide = not open
	gate.Transparency = if open then 1 else 0.2
	for _, gui in gate:GetChildren() do
		if gui:IsA("SurfaceGui") then
			gui.Enabled = not open
		end
	end
end

local function refreshGates()
	for _, gate in CollectionService:GetTagged(Tags.BiomeGate) do
		refreshGate(gate)
	end
end

function BiomeController:Start()
	tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "BiomeTint"
	tint.Parent = Lighting

	task.spawn(loadZones)

	CollectionService:GetInstanceAddedSignal(Tags.BiomeGate):Connect(refreshGate)
	ClientState.Changed:Connect(refreshGates)
	refreshGates()

	ClientState.BiomeChanged:Connect(applyAmbience)
	applyAmbience(nil)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.3 then
			return
		end
		elapsed = 0
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and #zones > 0 then
			ClientState.SetBiome(Zones.Find(zones, root.Position))
		end
	end)
end

return BiomeController
