-- Fake Roblox environment for tests. __ENTRIES is prepended by tests/run.py.

---------------------------------------------------------------------------
-- Instances
---------------------------------------------------------------------------
local Node = {}
local nodeMethods = {}

local function newNode(name: string, className: string, parent)
	local node = setmetatable({ Name = name, ClassName = className, Parent = parent, _children = {} }, Node)
	if parent then
		table.insert(rawget(parent, "_children"), node)
	end
	return node
end

Node.__index = function(self, key)
	if nodeMethods[key] then
		return nodeMethods[key]
	end
	for _, child in rawget(self, "_children") do
		if child.Name == key then
			return child
		end
	end
	return nil
end

function nodeMethods:FindFirstChild(name)
	for _, child in rawget(self, "_children") do
		if child.Name == name then
			return child
		end
	end
	return nil
end
function nodeMethods:WaitForChild(name)
	local child = self:FindFirstChild(name)
	assert(child, "WaitForChild: " .. self:GetFullName() .. " has no child " .. tostring(name))
	return child
end
function nodeMethods:GetChildren()
	return table.clone(rawget(self, "_children"))
end
function nodeMethods:GetDescendants()
	local out = {}
	local function walk(node)
		for _, child in rawget(node, "_children") do
			table.insert(out, child)
			walk(child)
		end
	end
	walk(self)
	return out
end
function nodeMethods:IsA(className)
	return self.ClassName == className
end
function nodeMethods:GetFullName()
	local parts = {}
	local node = self
	while node and node.Parent do
		table.insert(parts, 1, node.Name)
		node = node.Parent
	end
	return table.concat(parts, ".")
end

---------------------------------------------------------------------------
-- Datatypes used by configs
---------------------------------------------------------------------------
local Color3Meta = {}
Color3Meta.__index = {
	ToHex = function(self)
		return string.format("%02X%02X%02X", self.R * 255, self.G * 255, self.B * 255)
	end,
	Lerp = function(self, other, a)
		return Color3.new(
			self.R + (other.R - self.R) * a,
			self.G + (other.G - self.G) * a,
			self.B + (other.B - self.B) * a
		)
	end,
}
Color3 = {
	new = function(r, g, b)
		return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3Meta)
	end,
}
Color3.fromRGB = function(r, g, b)
	return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end
Color3.fromHSV = function()
	return Color3.new(1, 1, 1)
end

local function enumProxy(path)
	return setmetatable({}, {
		__index = function(_, key)
			return enumProxy(path .. "." .. key)
		end,
		__tostring = function()
			return path
		end,
	})
end
Enum = enumProxy("Enum")

Vector3 = {
	new = function(x, y, z)
		return { X = x or 0, Y = y or 0, Z = z or 0 }
	end,
}
Vector3.zero = Vector3.new()
Vector3.one = Vector3.new(1, 1, 1)

-- Quiet logging during tests (set TEST_VERBOSE = true to see it)
TEST_VERBOSE = false
local rawPrint = print
print = function(...)
	if TEST_VERBOSE then
		rawPrint(...)
	end
end
warn = function(...)
	if TEST_VERBOSE then
		rawPrint("WARN", ...)
	end
end

---------------------------------------------------------------------------
-- task
---------------------------------------------------------------------------
task = {
	spawn = function(fn, ...)
		if type(fn) == "function" then
			fn(...)
		end
	end,
	defer = function(fn, ...)
		fn(...)
	end,
	delay = function() end,
	wait = function()
		return 0
	end,
	cancel = function() end,
}

---------------------------------------------------------------------------
-- Services
---------------------------------------------------------------------------
local game = newNode("Game", "DataModel", nil)
game.JobId = "test-job"
local services = {}

local fakeSignal = {
	Connect = function()
		return { Disconnect = function() end }
	end,
}

-- In-memory DataStore (tests can inspect/modify __DATASTORE)
__DATASTORE = {}
local function newDataStore(name)
	__DATASTORE[name] = __DATASTORE[name] or {}
	local data = __DATASTORE[name]
	return {
		UpdateAsync = function(_, key, transform)
			local result = transform(data[key])
			if result ~= nil then
				data[key] = result
			end
			return result
		end,
		GetAsync = function(_, key)
			return data[key]
		end,
	}
end

local function service(name)
	if services[name] then
		return services[name]
	end
	local s
	if name == "RunService" then
		s = {
			IsServer = function()
				return true
			end,
			IsClient = function()
				return false
			end,
			IsStudio = function()
				return true
			end,
			Heartbeat = fakeSignal,
		}
	elseif name == "Players" then
		s = {
			PlayerAdded = fakeSignal,
			PlayerRemoving = fakeSignal,
			GetPlayers = function()
				return {}
			end,
		}
	elseif name == "DataStoreService" then
		s = {
			GetDataStore = function(_, storeName)
				return newDataStore(storeName)
			end,
		}
	else
		s = game:FindFirstChild(name) or newNode(name, name, game)
	end
	services[name] = s
	return s
end
nodeMethods.GetService = function(_, name)
	return service(name)
end

---------------------------------------------------------------------------
-- Build the tree from __ENTRIES
---------------------------------------------------------------------------
for _, entry in __ENTRIES do
	local node = game
	for i, part in entry.Path do
		local child = node:FindFirstChild(part)
		if not child then
			if i == 1 then
				child = service(part)
			else
				child = newNode(part, if i == #entry.Path then entry.Class else "Folder", node)
			end
		end
		if i == #entry.Path then
			rawset(child, "ClassName", entry.Class)
			rawset(child, "_source", entry.Source)
		end
		node = child
	end
end

---------------------------------------------------------------------------
-- require
---------------------------------------------------------------------------
local cache = {}
local loading = {}
local baseEnv = getfenv(1)

local function fakeRequire(node)
	if type(node) ~= "table" or rawget(node, "_source") == nil then
		error("require: not a module: " .. tostring(node and node.Name))
	end
	if cache[node] ~= nil then
		return cache[node]
	end
	assert(not loading[node], "circular require: " .. node:GetFullName())
	loading[node] = true
	local fn, err = loadstring(rawget(node, "_source"), "=" .. node:GetFullName())
	assert(fn, err)
	local env = setmetatable({ script = node, require = fakeRequire, game = game }, { __index = baseEnv })
	setfenv(fn, env)
	local result = fn()
	loading[node] = nil
	cache[node] = result
	return result
end

---------------------------------------------------------------------------
-- Test API
---------------------------------------------------------------------------
local passed, failed, failures = 0, 0, {}
local currentSuite = ""

local function fmt(v)
	if type(v) == "string" then
		return string.format("%q", v)
	end
	return tostring(v)
end

local function deepEqual(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function expect(actual)
	return {
		toBe = function(expected)
			if actual ~= expected then
				error(string.format("expected %s to be %s", fmt(actual), fmt(expected)), 2)
			end
		end,
		toEqual = function(expected)
			if not deepEqual(actual, expected) then
				error("tables are not equal", 2)
			end
		end,
		toBeTruthy = function()
			if not actual then
				error(string.format("expected %s to be truthy", fmt(actual)), 2)
			end
		end,
		toBeFalsy = function()
			if actual then
				error(string.format("expected %s to be falsy", fmt(actual)), 2)
			end
		end,
		toBeCloseTo = function(expected, epsilon)
			if math.abs(actual - expected) > (epsilon or 1e-6) then
				error(string.format("expected %s to be close to %s", fmt(actual), fmt(expected)), 2)
			end
		end,
		toBeGreaterThan = function(expected)
			if not (actual > expected) then
				error(string.format("expected %s > %s", fmt(actual), fmt(expected)), 2)
			end
		end,
	}
end

local api = {
	game = game,
	require = fakeRequire,
	expect = expect,
	Shared = game.ReplicatedStorage.Shared,
	Server = game.ServerScriptService.Server,
	test = function(name, fn)
		local ok, err = pcall(fn)
		if ok then
			passed += 1
		else
			failed += 1
			table.insert(failures, currentSuite .. " > " .. name .. "\n    " .. tostring(err))
		end
	end,
}

for _, spec in game.ServerScriptService.Specs:GetChildren() do
	currentSuite = spec.Name
	local ok, err = pcall(function()
		fakeRequire(spec)(api)
	end)
	if not ok then
		failed += 1
		table.insert(failures, spec.Name .. " (failed to load)\n    " .. tostring(err))
	end
end

for _, failure in failures do
	rawPrint("FAIL  " .. failure)
end
rawPrint(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	error("tests failed", 0)
end
