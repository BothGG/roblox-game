--[[
	BiomeService: unlocking biomes and keeping players out of locked ones.

	- Gates at biome entrances have an "Unlock" prompt (and the UI can call
	  the UnlockBiome remote).
	- Every second, anyone standing in a biome they haven't unlocked is sent
	  back outside its gate. (The gate wall is only solid for locked players;
	  see client BiomeController.)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Biomes = require(Shared.Config.Biomes)
local GameConfig = require(Shared.Config.GameConfig)
local Rules = require(Shared.Game.Rules)
local Format = require(Shared.Lib.Format)
local Net = require(Shared.Net)

local BiomeService = {
	Priority = 15,
}

local Data, Map, Fx

local RED = Color3.fromRGB(255, 90, 90)

function BiomeService:Init(registry)
	Data = registry.DataService
	Map = registry.MapService
	Fx = registry.FxService
end

local function priceText(biome): string
	local parts = {}
	if biome.Unlock.Cash > 0 then
		table.insert(parts, Format.Money(biome.Unlock.Cash))
	end
	if biome.Unlock.Rebirths > 0 then
		table.insert(parts, "Rebirth " .. biome.Unlock.Rebirths)
	end
	return if #parts > 0 then table.concat(parts, " + ") else "Free"
end
BiomeService.PriceText = priceText

function BiomeService:Start()
	for biomeId, gate in Map.Gates do
		local biome = Biomes[biomeId]
		if not biome then
			continue
		end
		gate.Part:SetAttribute("PriceText", priceText(biome))

		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local gui = Instance.new("SurfaceGui")
			gui.Name = "LockSign"
			gui.Face = face
			gui.PixelsPerStud = 20
			gui.LightInfluence = 0
			gui.Parent = gate.Part
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 0.5)
			label.Position = UDim2.fromScale(0, 0.25)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.FredokaOne
			label.TextScaled = true
			label.TextColor3 = Color3.new(1, 1, 1)
			label.Text = string.format("🔒 %s %s\n%s", biome.Icon, biome.Name, priceText(biome))
			label.Parent = gui
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 3
			stroke.Parent = label
		end

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "UnlockPrompt"
		prompt.ActionText = "Unlock (" .. priceText(biome) .. ")"
		prompt.ObjectText = biome.Icon .. " " .. biome.Name
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("UnlockBiome", biomeId)
		prompt.Parent = gate.Part
		prompt.Triggered:Connect(function(player)
			self:TryUnlock(player, biomeId)
		end)
	end

	Net.On("UnlockBiome", function(player, biomeId)
		self:TryUnlock(player, biomeId)
	end)

	task.spawn(function()
		while true do
			task.wait(GameConfig.BiomeCheckInterval)
			self:_enforce()
		end
	end)
end

function BiomeService:TryUnlock(player: Player, biomeId: string)
	local data = Data:Get(player)
	if not data then
		return
	end
	local ok, reason = Rules.CanUnlockBiome(data, biomeId)
	if not ok then
		if reason ~= "Already unlocked" then
			Net.Notify(player, "🔒 " .. (reason or "Can't unlock"), RED)
		end
		return
	end
	local biome = Biomes[biomeId]
	data.Cash -= biome.Unlock.Cash
	data.Unlocks[biomeId] = true
	local gate = Map.Gates[biomeId]
	Fx:PlayFor(player, "Unlock", {
		Position = gate and gate.Part.Position or nil,
		Color = biome.Color,
		Name = biome.Name,
	})
	Net.NotifyAll(string.format("%s %s unlocked the %s!", biome.Icon, player.DisplayName, biome.Name), biome.Color)
	Data:Changed(player)
end

function BiomeService:_enforce()
	for _, player in Players:GetPlayers() do
		local data = Data:Get(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if data and root then
			local biomeId = Map:GetBiomeAt(root.Position)
			if biomeId and not data.Unlocks[biomeId] then
				local gate = Map.Gates[biomeId]
				character:PivotTo(if gate then gate.Outside else Map.HubSpawn)
				if Net.Throttle(player, "LockedBiome", 3) then
					local biome = Biomes[biomeId]
					Net.Notify(
						player,
						string.format("🔒 Unlock %s %s first! (%s)", biome.Icon, biome.Name, priceText(biome)),
						RED
					)
				end
			end
		end
	end
end

return BiomeService
