--[[
	VoidCriptUI · Core/InterfaceSettings.lua
	Persistence for library-level preferences.

	Flags cover everything a *script author* declares. This module covers the
	settings the *user* changes in the built-in Interface tab, which have no
	flag of their own because they belong to the library rather than to any
	script: animations, tooltips, the custom cursor, input locking, notification
	placement, watermark/keylist visibility, slider style and log level.

	Each entry is a get/set pair, so adding a new preference is one table entry
	and it is immediately saved, restored and validated.
]]

return function(Void)
	local InterfaceSettings = {}

	-- name -> { Get = fn, Set = fn(value), Default = value }
	InterfaceSettings.Entries = {
		Animations = {
			Get = function() return Void.Util.AnimationsEnabled end,
			Set = function(value) Void.Util.AnimationsEnabled = value and true or false end,
			Default = true,
		},
		Tooltips = {
			Get = function() return Void.Tooltip.Enabled end,
			Set = function(value) Void.Tooltip:SetEnabled(value) end,
			Default = true,
		},
		TooltipDelay = {
			Get = function() return Void.Tooltip.HoverDelay end,
			Set = function(value) Void.Tooltip:SetDelay(value) end,
			Default = 0.5,
		},
		Cursor = {
			Get = function() return Void.Cursor.Enabled end,
			Set = function(value) Void.Cursor:SetEnabled(value) end,
			Default = false,
		},
		CursorStyle = {
			Get = function() return Void.Cursor.Style end,
			Set = function(value) Void.Cursor:SetStyle(value) end,
			Default = "Arrow",
		},
		InputLock = {
			Get = function() return Void.Cursor.LockInput end,
			Set = function(value) Void.Cursor:SetInputLock(value) end,
			Default = false,
		},
		NotifyPosition = {
			Get = function() return Void.Notify.Position end,
			Set = function(value) Void.Notify:SetPosition(value) end,
			Default = "TopRight",
		},
		NotifyMax = {
			Get = function() return Void.Notify.Max end,
			Set = function(value) Void.Notify.Max = math.clamp(math.floor(tonumber(value) or 6), 1, 12) end,
			Default = 6,
		},
		SliderStyle = {
			Get = function() return Void.SliderStyle end,
			Set = function(value)
				if Void.Library and Void.Library.SetSliderStyle then
					Void.Library:SetSliderStyle(value)
				end
			end,
			Default = "Slider",
		},
		LogLevel = {
			Get = function() return Void.Log:GetLevel() end,
			Set = function(value) Void.Log:SetLevel(value) end,
			Default = "Warning",
		},
		LogMirror = {
			Get = function() return Void.Log.MirrorToNotify end,
			Set = function(value) Void.Log.MirrorToNotify = value and true or false end,
			Default = false,
		},
		Profiler = {
			Get = function() return Void.Profiler.Enabled end,
			Set = function(value) Void.Profiler.Enabled = value and true or false end,
			Default = true,
		},

		-- Overlay visibility. These only restore an overlay that the script
		-- already created; they never spawn one the author did not ask for.
		WatermarkVisible = {
			Get = function()
				local instance = Void.Watermark:Get()
				return instance and instance:IsVisible() or false
			end,
			Set = function(value)
				local instance = Void.Watermark:Get()
				if not instance then return end
				if value then instance:Show() else instance:Hide() end
			end,
			Default = false,
		},
		WatermarkPosition = {
			Get = function()
				local instance = Void.Watermark:Get()
				return instance and instance._position or "TopRight"
			end,
			Set = function(value)
				local instance = Void.Watermark:Get()
				if instance then instance:SetPosition(value) end
			end,
			Default = "TopRight",
		},
		WatermarkModules = {
			Get = function()
				local instance = Void.Watermark:Get()
				return instance and table.clone(instance._order) or nil
			end,
			Set = function(value)
				local instance = Void.Watermark:Get()
				if instance and type(value) == "table" and #value > 0 then
					instance:Configure({ Modules = value })
				end
			end,
			Default = nil,
		},
		KeylistVisible = {
			Get = function()
				local instance = Void.Keylist:Get()
				return instance and instance._visible or false
			end,
			Set = function(value)
				local instance = Void.Keylist:Get()
				if not instance then return end
				if value then instance:Show() else instance:Hide() end
			end,
			Default = false,
		},
		KeylistPosition = {
			Get = function()
				local instance = Void.Keylist:Get()
				return instance and instance._position or "LeftCenter"
			end,
			Set = function(value)
				local instance = Void.Keylist:Get()
				if instance then instance:Configure({ Position = value }) end
			end,
			Default = "LeftCenter",
		},
		KeylistColumns = {
			Get = function()
				local instance = Void.Keylist:Get()
				return instance and table.clone(instance._columns) or nil
			end,
			Set = function(value)
				local instance = Void.Keylist:Get()
				if instance and type(value) == "table" and #value > 0 then
					instance:Configure({ Columns = value })
				end
			end,
			Default = nil,
		},
	}

	-- Register your own preference (plugins, or a script that wants one of its
	-- own settings persisted without a visible element).
	function InterfaceSettings:Register(name, getter, setter, default)
		if type(name) ~= "string" or type(getter) ~= "function" or type(setter) ~= "function" then
			Void.Log:Warn("InterfaceSettings:Register(name, get, set, default?) got bad arguments")
			return false
		end
		self.Entries[name] = { Get = getter, Set = setter, Default = default }
		return true
	end

	function InterfaceSettings:Snapshot()
		local out = {}
		for name, entry in pairs(self.Entries) do
			local ok, value = pcall(entry.Get)
			if ok and value ~= nil then
				out[name] = value
			end
		end
		return out
	end

	function InterfaceSettings:Restore(data)
		if type(data) ~= "table" then return 0 end
		local applied = 0
		for name, value in pairs(data) do
			local entry = self.Entries[name]
			if entry then
				local ok, err = pcall(entry.Set, value)
				if ok then
					applied = applied + 1
				else
					Void.Log:Debug("interface setting '%s' rejected value: %s", name, tostring(err))
				end
			else
				Void.Log:Debug("unknown interface setting '%s' in config", tostring(name))
			end
		end
		Void.Log:Debug("restored %d interface settings", applied)
		return applied
	end

	function InterfaceSettings:Reset()
		for name, entry in pairs(self.Entries) do
			if entry.Default ~= nil then
				pcall(entry.Set, entry.Default)
			end
		end
		Void.Log:Info("interface settings reset to defaults")
	end

	function InterfaceSettings:List()
		local out = {}
		for name in pairs(self.Entries) do out[#out + 1] = name end
		table.sort(out)
		return out
	end

	Void.InterfaceSettings = InterfaceSettings
	return InterfaceSettings
end
