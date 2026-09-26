--[[
	Fx: the client-side effect player.

	  Fx.Play("LevelUp", { Position = pos, Level = 12 })

	Presets (named effects) live in Fx/Presets.lua.
	Building blocks (burst, ring, shake, ...) live in Fx/Primitives.lua.
	Persistent auras on kaiju live in Fx/Auras.lua (used by the server).

	From the server, don't call this directly. Use FxService:
	  FxService:PlayAll("LevelUp", params)
	  FxService:PlayFor(player, "StealAlert", params)
]]

local RunService = game:GetService("RunService")

local Fx = {}

local Presets
local Primitives

local function load()
	if not Presets then
		Primitives = require(script.Primitives)
		Presets = require(script.Presets)
		Fx.Primitives = Primitives
	end
end

function Fx.Play(name: string, params: { [string]: any }?)
	if RunService:IsServer() then
		warn("[Fx] Fx.Play is client-only. Use FxService on the server.")
		return
	end
	load()
	local preset = Presets[name]
	if not preset then
		warn("[Fx] Unknown effect preset:", name)
		return
	end
	task.spawn(function()
		local ok, err = pcall(preset, params or {}, Primitives)
		if not ok then
			warn("[Fx] Preset", name, "failed:", err)
		end
	end)
end

-- Add or override a preset at runtime (e.g. from a new feature module).
function Fx.Register(name: string, preset: (params: any, P: any) -> ())
	load()
	Presets[name] = preset
end

if RunService:IsClient() then
	load()
end

return Fx
