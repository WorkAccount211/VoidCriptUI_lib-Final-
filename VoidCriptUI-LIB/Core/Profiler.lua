--[[
	VoidCriptUI · Core/Profiler.lua
	Detailed performance profiling.

	Two jobs:
	  1. Live frame/ping metrics for the watermark and the built-in
	     "Performance" panel (FPS avg/1% low, memory, ping, instance count).
	  2. Named spans (`Profiler:Begin("BuildTab") ... Profiler:End()`) that the
	     library itself uses around construction so you can see exactly what a
	     window costs. Read them with Library:GetProfile().

	The sampler is a single Heartbeat connection with an accumulator — never a
	per-element RenderStepped loop.
]]

return function(Void)
	local RunService = game:GetService("RunService")
	local Stats = game:FindService("Stats") or game:GetService("Stats")

	local Profiler = {
		Enabled = true,
		FPS = 60,
		FrameTimeMs = 16.6,
		Low1 = 60,
		Memory = 0,
		Ping = 0,
		InstanceCount = 0,
		Spans = {},
		_stack = {},
		_frames = 0,
		_accum = 0,
		_window = {},
		_windowMax = 120,
		_slowSpanMs = 8, -- spans slower than this get a Debug log line
	}

	function Profiler:Begin(name)
		if not self.Enabled then return end
		table.insert(self._stack, { Name = name, Start = os.clock() })
	end

	function Profiler:End()
		if not self.Enabled then return 0 end
		local frame = table.remove(self._stack)
		if not frame then return 0 end
		local ms = (os.clock() - frame.Start) * 1000
		local span = self.Spans[frame.Name]
		if span then
			span.Calls = span.Calls + 1
			span.TotalMs = span.TotalMs + ms
			span.LastMs = ms
			if ms > span.MaxMs then span.MaxMs = ms end
		else
			self.Spans[frame.Name] = { Calls = 1, TotalMs = ms, LastMs = ms, MaxMs = ms }
		end
		if ms > self._slowSpanMs and Void.Log then
			Void.Log:Debug("slow span '%s' took %.2fms", frame.Name, ms)
		end
		return ms
	end

	-- Convenience wrapper: Profiler:Measure("name", fn, ...)
	function Profiler:Measure(name, fn, ...)
		self:Begin(name)
		local results = table.pack(pcall(fn, ...))
		self:End()
		if not results[1] and Void.Log then
			Void.Log:Error("profiled call '%s' failed: %s", name, tostring(results[2]))
		end
		return table.unpack(results, 2, results.n)
	end

	function Profiler:Report()
		local rows = {}
		for name, span in pairs(self.Spans) do
			rows[#rows + 1] = {
				Name = name,
				Calls = span.Calls,
				TotalMs = span.TotalMs,
				AvgMs = span.TotalMs / span.Calls,
				MaxMs = span.MaxMs,
				LastMs = span.LastMs,
			}
		end
		table.sort(rows, function(a, b) return a.TotalMs > b.TotalMs end)
		return rows
	end

	function Profiler:ReportString()
		local out = { "name                          calls    total     avg     max" }
		for _, r in ipairs(self:Report()) do
			out[#out + 1] = string.format("%-28s %6d %8.2f %7.2f %7.2f", r.Name, r.Calls, r.TotalMs, r.AvgMs, r.MaxMs)
		end
		return table.concat(out, "\n")
	end

	function Profiler:Reset()
		table.clear(self.Spans)
		table.clear(self._stack)
	end

	function Profiler:GetPing()
		local ok, value = pcall(function()
			local item = Stats.Network.ServerStatsItem["Data Ping"]
			return item:GetValue()
		end)
		return ok and math.floor(value + 0.5) or 0
	end

	function Profiler:Start(maid)
		if self._connection then return end
		local pingClock, instanceClock = 0, 0
		self._connection = RunService.Heartbeat:Connect(function(dt)
			self._frames = self._frames + 1
			self._accum = self._accum + dt

			local w = self._window
			w[#w + 1] = dt
			if #w > self._windowMax then table.remove(w, 1) end

			if self._accum >= 0.5 then
				self.FPS = math.floor(self._frames / self._accum + 0.5)
				self.FrameTimeMs = (self._accum / self._frames) * 1000
				self._frames, self._accum = 0, 0

				-- 1% low: worst frame in the sample window
				local worst = 0
				for i = 1, #w do
					if w[i] > worst then worst = w[i] end
				end
				self.Low1 = worst > 0 and math.floor(1 / worst + 0.5) or self.FPS

				pingClock = pingClock + 1
				if pingClock >= 2 then -- every ~1s
					pingClock = 0
					self.Ping = self:GetPing()
					local okMem, mem = pcall(function()
						return Stats:GetTotalMemoryUsageMb()
					end)
					self.Memory = okMem and math.floor(mem) or 0
				end

				instanceClock = instanceClock + 1
				if instanceClock >= 20 then -- every ~10s, this one is expensive
					instanceClock = 0
					local okCount, count = pcall(function()
						return Stats.InstanceCount or 0
					end)
					self.InstanceCount = okCount and count or 0
				end
			end
		end)
		if maid then maid:Give(self._connection) end
		return self._connection
	end

	function Profiler:Stop()
		if self._connection then
			self._connection:Disconnect()
			self._connection = nil
		end
	end

	Void.Profiler = Profiler
	return Profiler
end
