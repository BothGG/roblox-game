--[[
	GameEvents: a hub for "something happened to a player" events.
	Gameplay services Fire; progress systems (quests, tutorial, stats) listen.
	This keeps systems independent: the feeding code doesn't need to know
	that quests exist.

	  GameEvents.Fire(player, "Fed", { Food = "Meat" })
	  GameEvents.Listen(function(player, name, payload) ... end)

	Event names (also listed in shared/Game/ConfigValidator.lua):
	  Fed { Food, Favorite }          LevelUp { Level, Titan }
	  FoodPicked { Amount }           Stole { Food }
	  Hatched { Titan, Mutation }     Mutated { Mutation }
	  BattleWon { Mode }              BattlePlayed { Mode }
	  Earned { Amount }               Rebirthed { Rebirths }
	  Equipped { Titan }              Bred { Titan, Mutation, Size }
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage:WaitForChild("Shared").Lib.Log)

local log = Log.new("GameEvents")

local GameEvents = {}

local listeners: { (Player, string, { [string]: any }) -> () } = {}

function GameEvents.Listen(listener: (Player, string, { [string]: any }) -> ())
	table.insert(listeners, listener)
end

function GameEvents.Fire(player: Player, name: string, payload: { [string]: any }?)
	local data = payload or {}
	for _, listener in listeners do
		local ok, err = pcall(listener, player, name, data)
		if not ok then
			log:Error("listener failed for", name, err)
		end
	end
end

return GameEvents
