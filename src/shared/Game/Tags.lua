--!strict
--[[
	Tags: CollectionService tag names that make up the MAP CONTRACT.
	The map generator creates these; a hand-built map just needs to tag its
	parts the same way (see docs/MAP_GUIDE.md).
]]

return {
	Plot = "Plot", -- anchor part per base. Attribute PlotIndex (number). Front (-Z) faces the arena.
	FoodSpawn = "FoodSpawn", -- where food grows.
	WildSpawn = "WildSpawn", -- where wild titans appear and roam around.
	Arena = "Arena", -- arena center part (on the floor). Attribute Radius (fighting area).
	Portal = "Portal", -- touch to teleport. Attribute To = "Arena" (to the stands) | "Island" (back home).
	ArenaSpawn = "ArenaSpawn", -- fighter start points (at least 2, around the arena edge).
	Stands = "Stands", -- where spectators get moved during a match.
	HubSpawn = "HubSpawn", -- where players appear before being sent to their base.
	MeteorZone = "MeteorZone", -- where Meteor Feast food lands. Optional Radius.
	Leaderboard = "Leaderboard", -- board part. Attribute Board = "Trophies" | "Biggest" | "Rebirths".

	-- Runtime tags
	AnimatedMutation = "AnimatedMutation",
	BaseTitan = "BaseTitan",
	FoodPickup = "FoodPickup",
	WildTitan = "WildTitan",
	Mover = "Mover", -- models the client moves smoothly (wild titans, followers)
}
