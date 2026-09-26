--[[
	BattleController: the local player's side of arena fights.
	- Shows the BattleHud while a match is on
	- Inputs: Click / F = Attack, Q = Special (plus the on-screen buttons)
	- Zooms the camera out to fit your (possibly giant) titan
	The server decides every hit; this only sends button presses.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Battle = require(Shared.Game.Battle)
local Net = require(Shared.Net)

local UI = script.Parent.Parent:WaitForChild("UI")
local BattleHud = require(UI.BattleHud)
local Hud = require(UI.Hud)

local player = Players.LocalPlayer

local BattleController = {
	Priority = 20,
}

local current: any = nil
local me: any = nil
local savedZoom: { Min: number, Max: number }? = nil

local function isFighting(): boolean
	return me ~= nil and me.Alive and current ~= nil and current.Phase == "Fight"
end

local function act(action: string)
	if not isFighting() then
		return
	end
	if BattleHud.CooldownLeft(action) > 0 then
		return
	end
	local length = if action == "Attack"
		then GameConfig.Battle.AttackCooldown
		else Battle.SpecialFor(me.TitanId).Cooldown
	BattleHud.SetCooldown(action, length)
	Net.Send("BattleAction", action)
end

local function setCamera(fighterHeight: number?)
	if fighterHeight then
		if not savedZoom then
			savedZoom = { Min = player.CameraMinZoomDistance, Max = player.CameraMaxZoomDistance }
		end
		player.CameraMaxZoomDistance = math.max(80, fighterHeight * 5)
		player.CameraMinZoomDistance = math.max(10, fighterHeight * 1.6)
	elseif savedZoom then
		player.CameraMinZoomDistance = savedZoom.Min
		player.CameraMaxZoomDistance = savedZoom.Max
		savedZoom = nil
	end
end

function BattleController:Start()
	BattleHud.Start(act)

	Net.Listen("BattleState", function(state)
		current = state
		me = nil
		if state.Phase ~= "None" then
			for _, f in state.Fighters do
				if f.Id == player.UserId then
					me = f
				end
			end
		end
		BattleHud.Update(state, me ~= nil and me.Alive)
		if me then
			BattleHud.SetSpecialName(Battle.SpecialFor(me.TitanId).Name)
		end
		Hud.SetBattleMode(me ~= nil)
		setCamera(if me then me.Height else nil)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.F then
			act("Attack")
		elseif input.KeyCode == Enum.KeyCode.Q then
			act("Special")
		end
	end)
end

return BattleController
