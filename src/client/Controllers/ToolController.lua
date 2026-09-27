--[[
	ToolController: sends UseTool(id, aim) when you use a taming tool
	(Wooden Club / Tranq Blowgun). The server decides what was hit.
	On phones, tapping aims where you tap; on PC, where the mouse points.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared").Net)

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local ToolController = {
	Priority = 40,
}

local hooked: { [Tool]: boolean } = {}

local function hook(tool: Instance)
	if not tool:IsA("Tool") or hooked[tool] then
		return
	end
	local id = tool:GetAttribute("TitanTool")
	if type(id) ~= "string" then
		return
	end
	hooked[tool] = true
	tool.Activated:Connect(function()
		local aim = mouse.Hit.Position
		Net.Send("UseTool", id, aim.X, aim.Y, aim.Z)
	end)
	tool.Destroying:Connect(function()
		hooked[tool] = nil
	end)
end

local function watch(container: Instance)
	for _, child in container:GetChildren() do
		hook(child)
	end
	container.ChildAdded:Connect(hook)
end

function ToolController:Start()
	local function onCharacter(character: Model)
		watch(character)
	end
	if player.Character then
		onCharacter(player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
	watch(player:WaitForChild("Backpack"))
	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			watch(child)
		end
	end)
end

return ToolController
