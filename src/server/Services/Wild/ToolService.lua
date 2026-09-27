--[[
	ToolService: every player gets the starter taming tools (Config/Tools.lua):
	  Wooden Club   - melee, knocks wild titans out up close
	  Tranq Blowgun - ranged sleepy darts

	The client (ToolController) sends UseTool(id, aimX, aimY, aimZ) when a
	tool is used; everything is checked here (equipped, cooldown, range)
	and hits go to WildService:Hit().
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tools = require(Shared.Config.Tools)
local Log = require(Shared.Lib.Log)
local Net = require(Shared.Net)

local log = Log.new("ToolService")

local ToolService = {
	Priority = 44,
	_cooldowns = {} :: { [Player]: { [string]: number } },
}

local Wild, Fx, Battle

local ORDER = { "Club", "Tranq" }

function ToolService:Init(registry)
	Wild = registry.WildService
	Fx = registry.FxService
	Battle = registry.BattleService
end

local function makeTool(def): Tool
	local tool = Instance.new("Tool")
	tool.Name = def.Name
	tool.ToolTip = def.Tip
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("TitanTool", def.Id)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.CanCollide = false
	handle.Massless = true
	handle.Color = def.Color
	handle.Material = Enum.Material.SmoothPlastic
	if def.Kind == "Melee" then
		handle.Size = Vector3.new(0.8, 4, 0.8)
		tool.GripPos = Vector3.new(0, -1.2, 0)
		local head = Instance.new("Part")
		head.Name = "ClubHead"
		head.Shape = Enum.PartType.Ball
		head.Size = Vector3.new(1.6, 1.6, 1.6)
		head.Color = def.Color:Lerp(Color3.new(0, 0, 0), 0.2)
		head.CanCollide = false
		head.Massless = true
		head.CFrame = handle.CFrame * CFrame.new(0, 1.8, 0)
		head.Parent = tool
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = head
		weld.Parent = head
	else
		handle.Size = Vector3.new(0.35, 0.35, 4)
		tool.GripForward = Vector3.new(0, 0, -1)
		tool.GripPos = Vector3.new(0, 0, 0.8)
	end
	handle.Parent = tool
	return tool
end

function ToolService:Start()
	Net.On("UseTool", function(player, id, x, y, z)
		self:Use(player, id, Vector3.new(x, y, z))
	end)
	Players.PlayerRemoving:Connect(function(player)
		self._cooldowns[player] = nil
	end)
end

function ToolService:OnPlayerReady(player: Player)
	self._cooldowns[player] = {}
	-- StarterGear: copied into the backpack on every respawn
	local gear = player:WaitForChild("StarterGear", 10)
	local backpack = player:FindFirstChildOfClass("Backpack")
	for _, id in ORDER do
		local def = Tools[id]
		if gear and not gear:FindFirstChild(def.Name) then
			makeTool(def).Parent = gear
		end
		if backpack and not backpack:FindFirstChild(def.Name) then
			local character = player.Character
			if not (character and character:FindFirstChild(def.Name)) then
				makeTool(def).Parent = backpack
			end
		end
	end
end

-- The TitanTool the player is holding right now (nil if none).
local function equipped(player: Player, id: string): Tool?
	local character = player.Character
	if not character then
		return nil
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("TitanTool") == id then
			return child
		end
	end
	return nil
end

function ToolService:Use(player: Player, id: string, aim: Vector3)
	local def = Tools[id]
	local tool = def and equipped(player, id)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not def or not tool or not root or player:GetAttribute("Riding") or Battle:IsFighting(player) then
		return
	end
	local cooldowns = self._cooldowns[player]
	local now = os.clock()
	if not cooldowns or now - (cooldowns[id] or 0) < def.Cooldown * 0.9 then
		return
	end
	cooldowns[id] = now

	if def.Kind == "Melee" then
		-- swing animation (the default Animate script plays "toolanim")
		local anim = Instance.new("StringValue")
		anim.Name = "toolanim"
		anim.Value = "Slash"
		anim.Parent = tool
		task.delay(0.3, function()
			anim:Destroy()
		end)
		local look = root.CFrame.LookVector
		local wild = Wild:FindNear(root.Position, look, def.Range, 0.25)
		Fx:PlayAll("TitanAttack", {
			Kind = "Attack",
			Position = root.Position + look * 2,
			Look = look,
			Range = 5,
			Color = Color3.fromRGB(255, 230, 160),
		})
		if wild then
			Wild:Hit(wild, player, def.Damage, def.Torpor)
		end
	else
		local origin = if head then head.Position else root.Position + Vector3.new(0, 1.5, 0)
		local direction = aim - origin
		if direction.Magnitude < 1 then
			direction = root.CFrame.LookVector
		end
		local wild = Wild:FindRay(origin, direction, def.Range)
		local hitPoint = if wild
			then Wild:Center(wild)
			else origin + direction.Unit * math.min(def.Range, direction.Magnitude)
		Fx:PlayAll("Dart", { From = origin, To = hitPoint, Hit = wild ~= nil })
		if wild then
			Wild:Hit(wild, player, def.Damage, def.Torpor)
		end
	end
	log:Debug(player.Name, "used", id)
end

return ToolService
