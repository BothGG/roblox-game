--[[
	SettingsService: saves player settings (music / sound effects on or off).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared").Net)

local ALLOWED = { Music = true, Sfx = true }

local SettingsService = {
	Priority = 78,
}

local Data

function SettingsService:Init(registry)
	Data = registry.DataService
end

function SettingsService:Start()
	Net.On("SetSetting", function(player, name, value)
		local data = Data:Get(player)
		if data and ALLOWED[name] then
			data.Settings[name] = value
			Data:Changed(player)
		end
	end)
end

return SettingsService
