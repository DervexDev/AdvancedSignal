---------------------------------------------------------------------------------------------------
--       ___    ____ _    _____    _   __________________     _____ ___________   _____    __    --
--      /   |  / __ | |  / /   |  / | / / ____/ ____/ __ \   / ___//  _/ ____/ | / /   |  / /    --
--     / /| | / / / | | / / /| | /  |/ / /   / __/ / / / /   \__ \ / // / __/  |/ / /| | / /     --
--    / ___ |/ /_/ /| |/ / ___ |/ /|  / /___/ /___/ /_/ /   ___/ // // /_/ / /|  / ___ |/ /___   --
--   /_/  |_/_____/ |___/_/  |_/_/ |_/\____/_____/_____/   /____/___/\____/_/ |_/_/  |_/_____/   --
--                                                                                               --
--                                    Made with <3 by Dervex                                     --
--                                                                                               --
-- About:                                                                                        --
--   Advanced Signal lets you choose whether you prefer performance or ease of use.              --
--   Signal is not yieldable by default, so yielding inside one of its bindings will result      --
--   in yielding rest of them. By default, the binding order is not preserved thus connection    --
--   that were made first will be fired last. Behavior of these two things can be changed by     --
--   providing additional arguments to Signal.new() or by changing globally DEFAULT_SETTINGS.    --
--                                                                                               --
-- API usage:                                                                                    --
--   local Signal = require(path.to.this.module)                                                 --
--                                                                                               --
--   local signal = Signal.new()                                                                 --
--                                                                                               --
--   local handle = signal:Bind(function(params)                                                 --
--      print(params)                                                                            --
--   end)                                                                                        --
--                                                                                               --
--   signal:Once(function(params)                                                                --
--      print(params)                                                                            --
--   end)                                                                                        --
--                                                                                               --
--   signal:Fire(args)                                                                           --
--                                                                                               --
--   handle:Unbind() or signal:Unbind(handle)                                                    --
--                                                                                               --
--   signal:UnbindAll()                                                                          --
--                                                                                               --
--   signal:Wait()                                                                               --
--                                                                                               --
-- Credits:                                                                                      --
--   Part of this code was written by stravant                                                   --
---------------------------------------------------------------------------------------------------

-- Change these to override default Advanced Signal settings
local DEFAULT_SETTINGS = {
	yieldable = false,
	keepOrder = false
}

export type Connection = {
	connected: boolean,
	signal: Signal,
	callback: (...any) -> (),
	new: (signal: Signal, callback: (...any) -> ()) -> Connection,
	Unbind: (self: Connection) -> ()
}

export type Signal = {
	yieldable: boolean,
	keepOrder: boolean,
	connections: {[Connection]: boolean},
	new: (yieldable: boolean?, keepOrder: boolean?) -> Signal,
	Bind: (self: Signal, callback: (...any) -> ()) -> Connection,
	Once: (self: Signal, callback: (...any) -> ()) -> (),
	Fire: (self: Signal, ...any) -> (),
	Unbind: (self: Signal, connection: Connection) -> (),
	UnbindAll: (self: Signal) -> (),
	Wait: (self: Signal) -> ...any
}

local freeThread = nil

local function acquireThreadAndRunCallback(callback, ...)
	local acquiredThread = freeThread
	freeThread = nil

	callback(...)

	freeThread = acquiredThread
end

local function runCallback()
	while true do
		acquireThreadAndRunCallback(coroutine.yield())
	end
end

local Connection: Connection = {}
Connection.__index = Connection

-- Creates new connection
function Connection.new(signal, callback)
	local self = setmetatable({
		connected = true,
		signal = signal,
		callback = callback
	}, Connection)

	return self
end

-- Disconnects connection
function Connection:Unbind()
	self.connected = false
	self.signal:Unbind(self)
end

local Signal: Signal = {}
Signal.__index = Signal

-- Creates new signal class with optional settings
function Signal.new(yieldable, keepOrder)
	local self = setmetatable({
		yieldable = if type(yieldable) == 'boolean' then yieldable else DEFAULT_SETTINGS.yieldable,
		keepOrder = if type(yieldable) == 'boolean' then keepOrder else DEFAULT_SETTINGS.keepOrder,
		connections = {}
	}, Signal)

	return self
end

-- Binds callback to the signal, returns connection
function Signal:Bind(callback)
	local connection = Connection.new(self, callback)

	self.connections[connection] = true

	if self.keepOrder then
		local connections = {}

		for i in pairs(self.connections) do
			connections[i] = true
		end

		self.connections = connections
	end

	return connection
end

-- Binds callback to the signal that will unbind automatically after first fire, returns connection
function Signal:Once(callback)
	local connection

	connection = Connection.new(self, function(...)
		if connection.connected then
			connection:Unbind()
		end

		callback(...)
	end)

	self.connections[connection] = true

	return connection
end

-- Fires signal with given arguments
function Signal:Fire(...)
	for connection in pairs(self.connections) do
		if self.yieldable then
			if not freeThread then
				freeThread = coroutine.create(runCallback)
				coroutine.resume(freeThread)
			end

			task.spawn(freeThread, connection.callback, ...)
		else
			connection.callback(...)
		end
	end
end

-- Unbinds a connection from the signal
function Signal:Unbind(connection)
	self.connections[connection] = nil
end

-- Unbinds all connections from the signal
function Signal:UnbindAll()
	self.connections = {}
end

-- Yields current thread until signal is fired
function Signal:Wait()
	local thread = coroutine.running()

	self:Once(function(...)
		task.spawn(thread, ...)
	end)

	return coroutine.yield()
end

return Signal