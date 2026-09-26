--[[
	Loader: finds every module whose name ends with a suffix ("Service" on
	the server, "Controller" on the client), then runs them in order:

	  1. module:Init(registry)   for all modules (no yielding!)
	  2. module:Start()          for all modules

	Order = module.Priority (lower first, default 100), then name.
	registry[Name] gives access to every other module.
]]

local Log = require(script.Parent.Log)

local log = Log.new("Loader")

local Loader = {}

export type Module = {
	Name: string?,
	Priority: number?,
	Init: ((self: any, registry: { [string]: any }) -> ())?,
	Start: ((self: any) -> ())?,
	[any]: any,
}

function Loader.Collect(folder: Instance, suffix: string): { [string]: Module }
	local modules = {}
	for _, descendant in folder:GetDescendants() do
		if descendant:IsA("ModuleScript") and string.sub(descendant.Name, -#suffix) == suffix then
			local ok, result = pcall(require, descendant)
			if not ok then
				log:Error("failed to load", descendant:GetFullName(), result)
			elseif type(result) ~= "table" then
				log:Error(descendant:GetFullName(), "must return a table")
			else
				result.Name = result.Name or descendant.Name
				if modules[result.Name] then
					log:Error("duplicate module name", result.Name)
				end
				modules[result.Name] = result
			end
		end
	end
	return modules
end

function Loader.Order(modules: { [string]: Module }): { Module }
	local list = {}
	for _, module in modules do
		table.insert(list, module)
	end
	table.sort(list, function(a, b)
		local pa, pb = a.Priority or 100, b.Priority or 100
		if pa ~= pb then
			return pa < pb
		end
		return (a.Name :: string) < (b.Name :: string)
	end)
	return list
end

-- Calls `method` on every module that has it, in order. Errors are logged, not thrown.
function Loader.Each(ordered: { Module }, method: string, ...)
	for _, module in ordered do
		local fn = module[method]
		if type(fn) == "function" then
			local ok, err = pcall(fn, module, ...)
			if not ok then
				log:Error(module.Name, method, "failed:", err)
			end
		end
	end
end

function Loader.Boot(folder: Instance, suffix: string): ({ [string]: Module }, { Module })
	local modules = Loader.Collect(folder, suffix)
	local ordered = Loader.Order(modules)
	Loader.Each(ordered, "Init", modules)
	Loader.Each(ordered, "Start")
	log:Info(string.format("started %d %ss", #ordered, suffix))
	return modules, ordered
end

return Loader
