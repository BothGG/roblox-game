--!strict
--[[
	Every message between client and server, in one list.

	ToServer remotes: Args = the type of each argument (see Lib/Guard.lua).
	  Bad types are rejected automatically before your handler runs.
	  RateLimit = minimum seconds between calls per player.
	ToClient remotes: Unreliable = true for cosmetic stuff (effects) that is
	  fine to drop under heavy load.
]]

export type RemoteSpec = {
	Direction: "ToServer" | "ToClient",
	Args: { string }?,
	RateLimit: number?,
	Unreliable: boolean?,
}

local Remotes: { [string]: RemoteSpec } = {
	-- Server -> client
	State = { Direction = "ToClient" }, -- player state snapshot for UI
	Notify = { Direction = "ToClient" }, -- small toast
	Announce = { Direction = "ToClient" }, -- big banner
	Fx = { Direction = "ToClient", Unreliable = true }, -- effect preset
	Hatched = { Direction = "ToClient" }, -- egg / catch reveal

	-- Client -> server
	BuyEgg = { Direction = "ToServer", Args = { "string" }, RateLimit = 0.4 },
	BuyFood = { Direction = "ToServer", Args = { "string", "integer" }, RateLimit = 0.2 },
	SelectFood = { Direction = "ToServer", Args = { "string" }, RateLimit = 0.1 },
	LockStorage = { Direction = "ToServer", Args = {}, RateLimit = 1 },
	Rebirth = { Direction = "ToServer", Args = {}, RateLimit = 2 },
	UnlockBiome = { Direction = "ToServer", Args = { "string" }, RateLimit = 0.5 },
	TeleportHome = { Direction = "ToServer", Args = {}, RateLimit = 3 },
}

return Remotes
