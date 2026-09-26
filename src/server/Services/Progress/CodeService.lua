--[[
	CodeService: redeem codes from Config/Codes.lua (one use per player).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Progress = require(Shared.Game.Progress)
local Net = require(Shared.Net)

local CodeService = {
	Priority = 74,
}

local Data, Reward

function CodeService:Init(registry)
	Data = registry.DataService
	Reward = registry.RewardService
end

function CodeService:Start()
	Net.On("RedeemCode", function(player, code)
		self:Redeem(player, code)
	end)
end

function CodeService:Redeem(player: Player, code: string)
	local data = Data:Get(player)
	if not data then
		return
	end
	local ok, reason, def = Progress.CanRedeem(data.Codes, code, os.time())
	if not ok then
		Net.Notify(player, "🎟️ " .. (reason or "That code didn't work"), Color3.fromRGB(255, 120, 120))
		return
	end
	local key = Progress.NormalizeCode(code)
	data.Codes[key] = true
	Reward:Grant(player, def.Reward, "🎟️ Code " .. key .. " redeemed!", "Code")
end

return CodeService
