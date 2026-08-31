--[[
	VoidCriptUI · Core/Signal.lua
	Lightweight custom signal (no RBXScriptSignal / BindableEvent overhead).

	Why custom: BindableEvent round-trips through the task scheduler and
	serialises arguments. For UI events we fire thousands of times per session
	a plain table of callbacks is measurably cheaper and lets us fire either
	synchronously (default, for visual updates) or deferred (for user code).
]]

return function(Void)
	local Signal = {}
	Signal.__index = Signal

	local Connection = {}
	Connection.__index = Connection

	function Connection:Disconnect()
		if self._dead then return end
		self._dead = true
		local list = self._signal._handlers
		for i = #list, 1, -1 do
			if list[i] == self then
				table.remove(list, i)
				break
			end
		end
	end
	Connection.Destroy = Connection.Disconnect
	Connection.disconnect = Connection.Disconnect

	function Signal.new(name)
		return setmetatable({
			_name = name or "Signal",
			_handlers = {},
		}, Signal)
	end

	function Signal:Connect(fn)
		assert(type(fn) == "function", "[VoidCript] Signal:Connect expects a function")
		local conn = setmetatable({ _signal = self, _fn = fn }, Connection)
		table.insert(self._handlers, conn)
		return conn
	end

	function Signal:Once(fn)
		local conn
		conn = self:Connect(function(...)
			conn:Disconnect()
			fn(...)
		end)
		return conn
	end

	-- Synchronous fire. Handlers are pcall-guarded so one broken listener
	-- cannot break the UI (roadmap #38).
	function Signal:Fire(...)
		local handlers = self._handlers
		if #handlers == 0 then return end
		-- iterate over a snapshot: handlers may disconnect during the loop
		local snapshot = table.move(handlers, 1, #handlers, 1, table.create and table.create(#handlers) or {})
		for i = 1, #snapshot do
			local conn = snapshot[i]
			if not conn._dead then
				local ok, err = pcall(conn._fn, ...)
				if not ok and Void.Log then
					Void.Log:Error(("signal '%s' handler failed: %s"):format(self._name, tostring(err)))
				end
			end
		end
	end

	-- Deferred fire: used for user callbacks so heavy user code never stalls
	-- the frame in which the input happened.
	function Signal:FireDeferred(...)
		local args = table.pack(...)
		task.spawn(function()
			self:Fire(table.unpack(args, 1, args.n))
		end)
	end

	function Signal:Wait()
		local thread = coroutine.running()
		local conn
		conn = self:Connect(function(...)
			conn:Disconnect()
			task.spawn(thread, ...)
		end)
		return coroutine.yield()
	end

	function Signal:DisconnectAll()
		for i = #self._handlers, 1, -1 do
			self._handlers[i]._dead = true
			self._handlers[i] = nil
		end
	end
	Signal.Destroy = Signal.DisconnectAll

	function Signal:CountConnections()
		return #self._handlers
	end

	Void.Signal = Signal
	return Signal
end
