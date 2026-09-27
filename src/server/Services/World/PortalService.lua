--[[
	PortalService: portal pads that teleport players (tag "Portal").

	  To = "Arena"  -> up to the floating arena's stands (to watch / get ready)
	  To = "Island" -> back to your own base

	Fighters in a match are not teleported (BattleService keeps them inside).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tags = require(Shared.Game.Tags)
local Net = require(Shared.Net)

local PortalService = {
	Priority = 50,
}

local Map, Base, Battle, Fx

local COOLDOWN = 2

function PortalService:Init(registry)
	Map = registry.MapService
	Base = registry.BaseService
	Battle = registry.BattleService
	Fx = registry.FxService
end

function PortalService:Start()
	for _, pad in CollectionService:GetTagged(Tags.Portal) do
		if pad:IsA("BasePart") then
			pad.CanTouch = true
			pad.Touched:Connect(function(hit)
				local character = hit.Parent
				local player = character and Players:GetPlayerFromCharacter(character)
				if player then
					self:Use(player, pad:GetAttribute("To"))
				end
			end)
		end
	end
end

function PortalService:Use(player: Player, to: string?)
	if Battle:IsFighting(player) or not Net.Throttle(player, "Portal", COOLDOWN) then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not root then
		return
	end
	local from = root.Position
	if to == "Arena" and #Map.Stands > 0 then
		character:PivotTo(Map.Stands[math.random(1, #Map.Stands)] + Vector3.new(0, 3, 0))
		Net.Notify(player, "⚔️ Welcome to the Titan Arena! Challenge someone or open ⚔️ Battle.")
	elseif to == "Island" then
		Base:TeleportHome(player)
	else
		return
	end
	Fx:PlayAll("Spawn", { Position = from, Color = Color3.fromRGB(120, 200, 255) })
end

return PortalService
