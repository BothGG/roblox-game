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
	Hatched = { Direction = "ToClient" }, -- egg reveal
	Rewarded = { Direction = "ToClient" }, -- reward popup { Title, Text }
	OfflineEarnings = { Direction = "ToClient" }, -- { Amount, Seconds }
	DuelRequest = { Direction = "ToClient" }, -- { FromUserId, FromName, Titan, Level }
	BattleState = { Direction = "ToClient" }, -- match info for the battle HUD
	ClashInvite = { Direction = "ToClient" }, -- { EndsAt }

	-- Client -> server: economy
	BuyEgg = { Direction = "ToServer", Args = { "string" }, RateLimit = 0.4 },
	BuyFood = { Direction = "ToServer", Args = { "string", "integer" }, RateLimit = 0.2 },
	SelectFood = { Direction = "ToServer", Args = { "string" }, RateLimit = 0.1 },
	LockStorage = { Direction = "ToServer", Args = {}, RateLimit = 1 },
	BuyUpgrade = { Direction = "ToServer", Args = { "string" }, RateLimit = 4 }, -- base upgrade id
	Rebirth = { Direction = "ToServer", Args = {}, RateLimit = 2 },
	TeleportHome = { Direction = "ToServer", Args = {}, RateLimit = 3 },
	Equip = { Direction = "ToServer", Args = { "string" }, RateLimit = 0.5 },
	SellTitan = { Direction = "ToServer", Args = { "string" }, RateLimit = 0.5 },

	-- Client -> server: Phase 1 (tools, riding, followers)
	UseTool = { Direction = "ToServer", Args = { "string", "number", "number", "number" }, RateLimit = 0.15 },
	Ride = { Direction = "ToServer", Args = { "string" }, RateLimit = 0.5 }, -- titan uid
	RideAction = { Direction = "ToServer", Args = { "string", "boolean?" }, RateLimit = 0.05 },
	FollowerCommand = { Direction = "ToServer", Args = { "string", "string?" }, RateLimit = 0.3 },

	-- Client -> server: battles
	Challenge = { Direction = "ToServer", Args = { "integer" }, RateLimit = 1 },
	DuelRespond = { Direction = "ToServer", Args = { "integer", "boolean" }, RateLimit = 0.3 },
	JoinClash = { Direction = "ToServer", Args = {}, RateLimit = 1 },
	Practice = { Direction = "ToServer", Args = {}, RateLimit = 2 },
	Spectate = { Direction = "ToServer", Args = {}, RateLimit = 2 },
	BattleAction = { Direction = "ToServer", Args = { "string" }, RateLimit = 0.15 },

	-- Client -> server: progress
	ClaimDaily = { Direction = "ToServer", Args = {}, RateLimit = 1 },
	ClaimQuest = { Direction = "ToServer", Args = { "integer" }, RateLimit = 0.5 },
	ClaimIndex = { Direction = "ToServer", Args = { "integer" }, RateLimit = 0.5 },
	RedeemCode = { Direction = "ToServer", Args = { "string" }, RateLimit = 2 },
	SetSetting = { Direction = "ToServer", Args = { "string", "boolean" }, RateLimit = 0.3 },
	SkipTutorial = { Direction = "ToServer", Args = {}, RateLimit = 1 },
	AdminCommand = { Direction = "ToServer", Args = { "string" }, RateLimit = 0.3 },
}

return Remotes
