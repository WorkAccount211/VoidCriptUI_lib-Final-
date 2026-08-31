--[[
	VoidCriptUI · Core/Logger.lua
	Configurable console logger (F9 developer console).

	Levels: 0 Off · 1 Error · 2 Warning · 3 Info · 4 Debug
	Default is Warning: only warnings and errors reach the console, exactly
	as requested. Raise it while developing:

		VoidLib:SetLogLevel("Debug")

	Errors/warnings go through error()/warn() so Roblox colours them red and
	orange in the F9 console; info/debug use print. Every line is prefixed and
	timestamped so multi-script sessions stay readable. The last 200 entries
	are kept in a ring buffer and exposed through Library:GetLogs() for the
	in-UI console viewer.
]]

return function(Void)
	local Log = {
		Levels = { Off = 0, Error = 1, Warning = 2, Warn = 2, Info = 3, Debug = 4 },
		Level = 2,
		Prefix = "VoidCript",
		History = {},
		HistoryLimit = 200,
		MirrorToNotify = false, -- when true, errors also pop a notification
	}

	local LEVEL_NAME = { [1] = "ERROR", [2] = "WARN", [3] = "INFO", [4] = "DEBUG" }

	local function stamp()
		local t = os.date("*t")
		return string.format("%02d:%02d:%02d", t.hour, t.min, t.sec)
	end

	function Log:SetLevel(level)
		if type(level) == "string" then
			local resolved = self.Levels[level] or self.Levels[level:sub(1, 1):upper() .. level:sub(2):lower()]
			if resolved == nil then
				self:Warn(("unknown log level '%s' (use Off/Error/Warning/Info/Debug)"):format(level))
				return
			end
			self.Level = resolved
		elseif type(level) == "number" then
			self.Level = math.clamp(math.floor(level), 0, 4)
		end
		return self.Level
	end

	function Log:GetLevel()
		for name, value in pairs(self.Levels) do
			if value == self.Level and name ~= "Warn" then return name end
		end
		return "Off"
	end

	function Log:_push(levelNum, message)
		local entry = {
			Level = LEVEL_NAME[levelNum] or "?",
			LevelNum = levelNum,
			Message = message,
			Time = stamp(),
			Clock = os.clock(),
		}
		local h = self.History
		h[#h + 1] = entry
		if #h > self.HistoryLimit then
			table.remove(h, 1)
		end
		return entry
	end

	function Log:_emit(levelNum, message, ...)
		if select("#", ...) > 0 then
			local ok, formatted = pcall(string.format, message, ...)
			message = ok and formatted or (tostring(message) .. " " .. table.concat({ ... }, " "))
		end
		message = tostring(message)
		local entry = self:_push(levelNum, message)
		if levelNum > self.Level then return entry end

		local line = ("[%s][%s][%s] %s"):format(self.Prefix, entry.Level, entry.Time, message)
		if levelNum == 1 then
			-- task.spawn(error) keeps the red traceback in F9 without
			-- unwinding the calling thread.
			task.spawn(function() error(line, 0) end)
			if self.MirrorToNotify and Void.Notify then
				pcall(function()
					Void.Notify:Push({ Title = "VoidCript error", Content = message, Type = "error", Duration = 8 })
				end)
			end
		elseif levelNum == 2 then
			warn(line)
		else
			print(line)
		end
		return entry
	end

	function Log:Error(msg, ...) return self:_emit(1, msg, ...) end
	function Log:Warn(msg, ...) return self:_emit(2, msg, ...) end
	Log.Warning = Log.Warn
	function Log:Info(msg, ...) return self:_emit(3, msg, ...) end
	function Log:Debug(msg, ...) return self:_emit(4, msg, ...) end

	-- Guarded call used everywhere a user callback is invoked. Any error is
	-- logged with context instead of killing the UI thread (roadmap #38).
	function Log:Guard(context, fn, ...)
		if type(fn) ~= "function" then return false end
		local args = table.pack(...)
		local ok, err = pcall(function()
			return fn(table.unpack(args, 1, args.n))
		end)
		if not ok then
			self:Error("callback '%s' errored: %s", tostring(context), tostring(err))
			if Void.Notify then
				pcall(function()
					Void.Notify:Push({
						Title = "Callback error",
						Content = ("%s: %s"):format(tostring(context), tostring(err)),
						Type = "error",
						Duration = 8,
					})
				end)
			end
		end
		return ok, err
	end

	-- Same as Guard but on its own thread: for callbacks that may yield.
	function Log:GuardAsync(context, fn, ...)
		if type(fn) ~= "function" then return end
		local args = table.pack(...)
		task.spawn(function()
			self:Guard(context, fn, table.unpack(args, 1, args.n))
		end)
	end

	function Log:Clear()
		table.clear(self.History)
	end

	function Log:Dump(minLevel)
		minLevel = minLevel or 4
		local out = {}
		for _, e in ipairs(self.History) do
			if e.LevelNum <= minLevel then
				out[#out + 1] = ("[%s][%s] %s"):format(e.Level, e.Time, e.Message)
			end
		end
		return table.concat(out, "\n")
	end

	Void.Log = Log
	return Log
end
