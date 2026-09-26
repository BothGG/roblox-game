--!strict
--[[
	Tags: CollectionService tag names that make up the MAP CONTRACT.
	The map generator creates these; a hand-built map just needs to tag its
	parts the same way (see docs/MAP_GUIDE.md).
]]

return {
	ZooPlot = "ZooPlot", -- anchor part per zoo. Attribute PlotIndex (number). Front (-Z) faces the plaza.
	BiomeZone = "BiomeZone", -- invisible part covering a biome. Attribute Biome, optional Radius (round zone).
	FoodSpawn = "FoodSpawn", -- where food appears. Attribute Biome.
	WildSpawn = "WildSpawn", -- where wild kaiju appear. Attribute Biome.
	BiomeGate = "BiomeGate", -- barrier at a biome entrance. Attribute Biome.
	HubSpawn = "HubSpawn", -- where players appear if they have no zoo.
	MeteorZone = "MeteorZone", -- where Meteor Feast food lands. Optional Radius.

	-- Runtime tags
	AnimatedMutation = "AnimatedMutation",
	WildCreature = "WildCreature",
}
