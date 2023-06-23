# Advanced Signal
Advanced Signal lets you choose whether you prefer performance or ease of use

### About
Signal is not yieldable by default, so yielding inside one of its bindings will result in yielding rest of them. By default, the binding order is not preserved thus connection that were made first will be fired last. Behavior of these two things can be changed by providing additional arguments to Signal.new() or by changing globally DEFAULT_SETTINGS.

### API Usage
```lua
local Signal = require(path.to.advancedsignal.module)

-- Creates new signal class with optional settings
local signal = Signal.new(yieldable?, keepOrder?)

-- Binds callback to the signal, returns connection
local handle = signal:Bind(function(params)
	print(params)
end)

-- Binds callback to the signal, will unbind automatically, returns connection
signal:Once(function(params)
	print(params)
end)

-- Fires signal with given arguments
signal:Fire(args)

-- Unbinds a connection from the signal
handle:Unbind() or signal:Unbind(handle)

-- Unbinds all connections from the signal
signal:UnbindAll()

-- Yields current thread until signal is fired
signal:Wait()
```

### Credits
Part of this code was written by @stravant