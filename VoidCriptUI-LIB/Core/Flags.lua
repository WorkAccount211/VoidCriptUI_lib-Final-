--[[
	VoidCriptUI · Core/Flags.lua
	The flag registry — the developer-facing state layer.

	Any element created with `Flag = "Name"` registers itself here, so its value
	is reachable from anywhere:

		VoidLib.Flags["Fly_Toggle"]              -- raw value (Weave-style)
		VoidLib:GetFlag("Fly_Toggle")            -- value via API
		VoidLib:SetFlag("Fly_Toggle", true)      -- drives the UI too
		VoidLib:OnFlagChanged("Fly_Toggle", fn)  -- subscribe

	`VoidLib.Flags` is a proxy table: indexing it returns the *value*, not the
	control object, and reading an unknown flag logs a warning instead of
	silently returning nil (flag validation). Controls themselves live in
	`Flags.Controls`.
]]

return function(Void)
	local Flags = {
		Controls = {},   -- flag -> control object
		Values = {},     -- flag -> last known value (fast read path)
		Pending = {},    -- flag -> value waiting for a lazily-built element
		Listeners = {},  -- flag -> { fn, ... }
		Strict = false,  -- when true, unknown flag reads raise an error
		_anyListeners = {},
	}

	-- ── public proxy ────────────────────────────────────────────────────
	-- Reading  : Library.Flags.Foo         → value
	-- Writing  : Library.Flags.Foo = true  → drives the control
	Flags.Proxy = setmetatable({}, {
		__index = function(_, key)
			local control = Flags.Controls[key]
			if control then
				return control:Get()
			end
			if Flags.Values[key] ~= nil then
				return Flags.Values[key]
			end
			local msg = ("flag '%s' does not exist (created a typo? register it with Flag = \"%s\")"):format(tostring(key), tostring(key))
			if Flags.Strict then
				error("[VoidCript] " .. msg, 2)
			end
			Void.Log:Warn(msg)
			return nil
		end,
		__newindex = function(_, key, value)
			Flags:Set(key, value)
		end,
		__len = function()
			local n = 0
			for _ in pairs(Flags.Controls) do n = n + 1 end
			return n
		end,
		__iter = function()
			-- generalised iteration yields flag/value pairs
			local keys, i = {}, 0
			for k in pairs(Flags.Controls) do keys[#keys + 1] = k end
			return function()
				i = i + 1
				local key = keys[i]
				if key == nil then return nil end
				return key, Flags.Controls[key]:Get()
			end
		end,
	})

	function Flags:Register(flag, control)
		if flag == nil then return control end
		if type(flag) ~= "string" or flag == "" then
			Void.Log:Warn("Flag must be a non-empty string, got %s", tostring(flag))
			return control
		end
		if self.Controls[flag] then
			Void.Log:Warn("flag '%s' is already registered — the newer element overwrites the older one", flag)
		end
		self.Controls[flag] = control

		-- Deferred restore: the config loader parks values for flags whose
		-- element does not exist yet (lazy tabs). If one is waiting for us,
		-- apply it now instead of overwriting it with the element's default.
		local pending = self.Pending[flag]
		if pending ~= nil then
			self.Pending[flag] = nil
			local ok, err = pcall(function() control:Set(pending, false) end)
			if ok then
				Void.Log:Debug("flag '%s' restored from a pending config value", flag)
			else
				Void.Log:Warn("could not restore pending value for flag '%s': %s", flag, tostring(err))
			end
		end

		self.Values[flag] = control.Get and control:Get() or nil
		Void.Log:Debug("registered flag '%s' (%s)", flag, tostring(control._kind))
		return control
	end

	function Flags:Unregister(flag)
		if not flag then return end
		self.Controls[flag] = nil
		self.Values[flag] = nil
		self.Pending[flag] = nil
		self.Listeners[flag] = nil
	end

	function Flags:Exists(flag)
		return self.Controls[flag] ~= nil
	end

	function Flags:Get(flag, default)
		local control = self.Controls[flag]
		if control then
			local value = control:Get()
			if value == nil then return default end
			return value
		end
		if self.Pending[flag] ~= nil then return self.Pending[flag] end
		if self.Values[flag] ~= nil then return self.Values[flag] end
		Void.Log:Warn("GetFlag('%s'): unknown flag", tostring(flag))
		return default
	end

	function Flags:Set(flag, value, silent)
		local control = self.Controls[flag]
		if not control then
			-- No element yet. This is normal during a config load with lazy
			-- tabs, so park the value and apply it when the element registers.
			self.Pending[flag] = value
			self.Values[flag] = value
			Void.Log:Debug("SetFlag('%s'): no element yet — value parked for later", tostring(flag))
			self:Fire(flag, value)
			return false
		end
		control:Set(value, not silent)
		return true
	end

	-- Park a value without firing listeners (used by the config loader).
	function Flags:SetPending(flag, value)
		if flag == nil then return end
		local control = self.Controls[flag]
		if control then
			control:Set(value, true)
			return true
		end
		self.Pending[flag] = value
		self.Values[flag] = value
		return false
	end

	function Flags:PendingCount()
		local n = 0
		for _ in pairs(self.Pending) do n = n + 1 end
		return n
	end

	function Flags:GetControl(flag)
		return self.Controls[flag]
	end

	-- Called by controls whenever their value changes.
	function Flags:Fire(flag, value)
		if flag == nil then return end
		self.Values[flag] = value

		local list = self.Listeners[flag]
		if list then
			for i = #list, 1, -1 do
				local fn = list[i]
				Void.Log:GuardAsync(("flag listener '%s'"):format(flag), fn, value, flag)
			end
		end
		for i = #self._anyListeners, 1, -1 do
			Void.Log:GuardAsync("flag listener (*)", self._anyListeners[i], flag, value)
		end
	end

	-- Subscribe to a single flag, or to every flag with flag == "*".
	function Flags:OnChanged(flag, fn)
		if type(flag) == "function" then
			fn, flag = flag, "*"
		end
		if type(fn) ~= "function" then
			Void.Log:Warn("OnFlagChanged needs a function")
			return function() end
		end
		if flag == "*" then
			table.insert(self._anyListeners, fn)
			return function()
				for i = #self._anyListeners, 1, -1 do
					if self._anyListeners[i] == fn then table.remove(self._anyListeners, i) end
				end
			end
		end
		if not self.Controls[flag] then
			Void.Log:Debug("OnFlagChanged('%s') registered before the element exists — that is fine", tostring(flag))
		end
		self.Listeners[flag] = self.Listeners[flag] or {}
		table.insert(self.Listeners[flag], fn)
		return function()
			local list = self.Listeners[flag]
			if not list then return end
			for i = #list, 1, -1 do
				if list[i] == fn then table.remove(list, i) end
			end
		end
	end

	-- Snapshot of every flag as plain values (used by config save + debug dump).
	-- Pending values are included so saving before the user opened every tab
	-- does not silently drop settings that were restored earlier.
	function Flags:Snapshot()
		local out = {}
		for flag, value in pairs(self.Pending) do
			out[flag] = value
		end
		for flag, control in pairs(self.Controls) do
			local ok, value = pcall(function()
				return control.GetRaw and control:GetRaw() or control:Get()
			end)
			if ok then out[flag] = value end
		end
		return out
	end

	function Flags:List()
		local out = {}
		for flag in pairs(self.Controls) do out[#out + 1] = flag end
		table.sort(out)
		return out
	end

	function Flags:Count()
		local n = 0
		for _ in pairs(self.Controls) do n = n + 1 end
		return n
	end

	function Flags:Clear()
		table.clear(self.Controls)
		table.clear(self.Values)
		table.clear(self.Pending)
		table.clear(self.Listeners)
		table.clear(self._anyListeners)
	end

	Void.Flags = Flags
	return Flags
end
