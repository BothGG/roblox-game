--[[
	Signal: a simple event you can Connect to and Fire.

	  local changed = Signal.new()
	  local connection = changed:Connect(function(value) print(value) end)
	  changed:Fire(5)
	  connection:Disconnect()
]]

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	DisconnectAll: (self: Signal<T...>) -> (),
}

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({ _handlers = {} :: { any } }, Signal)
	return (self :: any) :: Signal<T...>
end

function Signal:Connect(handler)
	local handlers = self._handlers
	local connection = { Connected = true }
	local entry = { Handler = handler, Connection = connection }
	function connection.Disconnect(conn)
		if not conn.Connected then
			return
		end
		conn.Connected = false
		local index = table.find(handlers, entry)
		if index then
			table.remove(handlers, index)
		end
	end
	table.insert(handlers, entry)
	return connection
end

function Signal:Once(handler)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		handler(...)
	end)
	return connection
end

function Signal:Fire(...)
	-- Copy so handlers can disconnect while firing.
	for _, entry in table.clone(self._handlers) do
		if entry.Connection.Connected then
			task.spawn(entry.Handler, ...)
		end
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:DisconnectAll()
	for _, entry in self._handlers do
		entry.Connection.Connected = false
	end
	table.clear(self._handlers)
end

return Signal
