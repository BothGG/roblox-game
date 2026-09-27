--!strict
--[[
	Riding: movement stats and stamina for riding your titans (pure, tested).

	Styles move differently:
	  Biped / Quad  runners: sprint with stamina
	  Winged        flyers: hold jump to fly (stamina)
	  Blob          bouncers: huge jumps
	Swimming uses Roblox's normal swimming; Quads and Blobs swim faster.
]]

local Config = script.Parent.Parent.Config
local Creatures = require(Config.Creatures)
local GameConfig = require(Config.GameConfig)
local Battle = require(script.Parent.Battle)

local RIDE = GameConfig.Riding

local Riding = {}

export type Mode = "Walk" | "Sprint" | "Fly"
export type RideStats = {
	WalkSpeed: number,
	SprintSpeed: number,
	JumpPower: number,
	CanSprint: boolean,
	CanFly: boolean,
	FlySpeed: number,
	StaminaMax: number,
	MaxHP: number,
}

function Riding.Stats(creature: { Id: string, Level: number, Mutation: string?, Size: number? }): RideStats
	local def = Creatures[creature.Id]
	local style = def and def.Style or "Biped"
	local battle = Battle.Stats(creature :: any)
	local walk = math.max(16, battle.Speed)
	return {
		WalkSpeed = walk,
		SprintSpeed = walk * RIDE.SprintMult,
		JumpPower = if style == "Blob" then 95 else 55,
		CanSprint = style ~= "Blob",
		CanFly = style == "Winged",
		FlySpeed = walk * 1.4,
		StaminaMax = 100 + creature.Level * 2,
		MaxHP = battle.MaxHP,
	}
end

-- New stamina after dt seconds in a mode. Walking regenerates.
function Riding.UpdateStamina(current: number, max: number, dt: number, mode: Mode): number
	if mode == "Sprint" then
		return math.max(0, current - RIDE.SprintDrain * dt)
	elseif mode == "Fly" then
		return math.max(0, current - RIDE.FlyDrain * dt)
	end
	return math.min(max, current + RIDE.Regen * dt)
end

-- Can you start (or keep) sprinting / flying with this much stamina?
function Riding.CanUse(current: number, mode: Mode, alreadyUsing: boolean?): boolean
	if mode == "Walk" then
		return true
	end
	return if alreadyUsing then current > 0 else current >= RIDE.MinToStart
end

-- Offsets for followers around the owner (behind, left, right).
function Riding.FollowerOffset(index: number, spacing: number): Vector3
	local slots = { { 0, 1 }, { -1, 0.6 }, { 1, 0.6 }, { 0, 2 } }
	local slot = slots[((index - 1) % #slots) + 1]
	return Vector3.new(slot[1] * spacing, 0, slot[2] * spacing)
end

return Riding
