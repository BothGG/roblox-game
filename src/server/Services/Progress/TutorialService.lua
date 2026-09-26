--[[
	TutorialService: walks new players through the game (Config/Tutorial.lua).
	Steps complete from GameEvents. The client shows the hint + an arrow.
	data.Tutorial = current step (1..n), 0 = finished or skipped.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tutorial = require(Shared.Config.Tutorial)
local Net = require(Shared.Net)

local GameEvents = require(ServerScriptService:WaitForChild("Server").Modules.GameEvents)

local TutorialService = {
	Priority = 79,
}

local Data, Reward

function TutorialService:Init(registry)
	Data = registry.DataService
	Reward = registry.RewardService
end

function TutorialService:Start()
	GameEvents.Listen(function(player, name, payload)
		self:_onEvent(player, name, payload)
	end)
	Net.On("SkipTutorial", function(player)
		local data = Data:Get(player)
		if data and data.Tutorial ~= 0 then
			data.Tutorial = 0
			data.TutorialProgress = 0
			Net.Notify(player, "Tutorial skipped. Have fun! ⚔️")
			Data:Changed(player)
		end
	end)
end

function TutorialService:_onEvent(player: Player, name: string, payload: { [string]: any })
	local data = Data:Get(player)
	if not data or data.Tutorial == 0 then
		return
	end
	local step = Tutorial.Steps[data.Tutorial]
	if not step then
		data.Tutorial = 0
		return
	end
	if step.Event ~= name then
		return
	end
	if step.MinLevel and (type(payload.Level) ~= "number" or payload.Level < step.MinLevel) then
		return
	end
	data.TutorialProgress += 1
	if data.TutorialProgress >= step.Count then
		data.TutorialProgress = 0
		data.Tutorial = if data.Tutorial >= #Tutorial.Steps then 0 else data.Tutorial + 1
		local title = if data.Tutorial == 0 then "🎓 Tutorial complete!" else "✅ Step done!"
		Reward:Grant(player, { Cash = Tutorial.RewardCash }, title, "Tutorial")
	end
	Data:Changed(player)
end

return TutorialService
