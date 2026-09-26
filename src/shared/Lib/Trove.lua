--[[
	Trove: collects things that need cleaning up (connections, instances,
	functions) and cleans them all at once. Use one per player / per object
	so nothing leaks.

	  local trove = Trove.new()
	  trove:Add(part)                       -- destroyed on Clean
	  trove:Add(signal:Connect(fn))         -- disconnected on Clean
	  trove:Add(function() print("bye") end)
	  trove:Clean()
]]

export type Trove = {
	Add: <T>(self: Trove, item: T) -> T,
	Clean: (self: Trove) -> (),
}

local Trove = {}
Trove.__index = Trove

function Trove.new(): Trove
	return (setmetatable({ _items = {} }, Trove) :: any) :: Trove
end

function Trove:Add(item)
	table.insert(self._items, item)
	return item
end

local function cleanup(item: any)
	local kind = typeof(item)
	if kind == "function" then
		item()
	elseif kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "Instance" then
		item:Destroy()
	elseif kind == "thread" then
		pcall(task.cancel, item)
	elseif kind == "table" then
		if type(item.Destroy) == "function" then
			item:Destroy()
		elseif type(item.Disconnect) == "function" then
			item:Disconnect()
		elseif type(item.Clean) == "function" then
			item:Clean()
		end
	end
end

function Trove:Clean()
	local items = self._items
	self._items = {}
	for i = #items, 1, -1 do
		local ok, err = pcall(cleanup, items[i])
		if not ok then
			warn("[Trove] cleanup failed:", err)
		end
	end
end

return Trove
