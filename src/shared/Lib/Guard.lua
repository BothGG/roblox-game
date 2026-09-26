--!strict
--[[
	Guard: checks values that come from clients (never trust the client!).

	Type specs:
	  "string" "number" "integer" "boolean" "any"
	  add "?" to allow nil:  "string?"
	Numbers must be finite (no NaN / infinity tricks).
]]

local Guard = {}

local MAX_STRING = 200

local function isFinite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

function Guard.Check(value: any, spec: string): boolean
	local optional = string.sub(spec, -1) == "?"
	local base = if optional then string.sub(spec, 1, -2) else spec
	if value == nil then
		return optional or base == "any"
	end
	if base == "any" then
		return true
	elseif base == "string" then
		return type(value) == "string" and #value <= MAX_STRING
	elseif base == "number" then
		return type(value) == "number" and isFinite(value)
	elseif base == "integer" then
		return type(value) == "number" and isFinite(value) and value == math.floor(value)
	elseif base == "boolean" then
		return type(value) == "boolean"
	end
	return false
end

-- Checks a list of arguments against a list of specs.
function Guard.CheckArgs(args: { any }, specs: { string }, count: number): (boolean, string?)
	if count > #specs then
		return false, "too many arguments"
	end
	for i, spec in specs do
		if not Guard.Check(args[i], spec) then
			return false, string.format("argument %d should be %s, got %s", i, spec, typeof(args[i]))
		end
	end
	return true, nil
end

-- True if `key` is a real entry of a config table (not a helper like "Order").
function Guard.IsConfigKey(config: { [any]: any }, key: any): boolean
	return type(key) == "string" and type(config[key]) == "table" and config[key].Id == key
end

return Guard
