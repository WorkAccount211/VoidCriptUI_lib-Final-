--[[
	VoidCriptUI · Core/Scale.lua
	Adaptive units + device profiles (roadmap #17, #30).

	Instead of hard-coded pixel sizes every element asks Scale for its metrics.
	Three inputs decide the result:
	  · viewport width  → device class (phone / tablet / desktop / wide)
	  · compact mode    → tighter paddings and rows for small screens
	  · user multiplier → Library:SetScale(1.15) for 1440p / 4K

	`Scale.u(n)` ("adaptive unit") converts a design pixel written against a
	1440-wide reference viewport into the current viewport, clamped so the UI
	never becomes unusable on extremes. Hit-targets go through `Scale.touch(n)`
	which additionally enforces a 44px minimum on touch devices — the platform
	accessibility guideline for finger targets.
]]

return function(Void)
	local UserInputService = game:GetService("UserInputService")
	local GuiService = game:GetService("GuiService")
	local Util = Void.Util

	local REFERENCE_WIDTH = 1440

	local Scale = {
		Multiplier = 1,
		Compact = false,
		Device = "Desktop",
		Touch = false,
		Factor = 1,
		Viewport = Vector2.new(1920, 1080),
		_listeners = {},
	}

	-- Per-device metric tables. Anything an element needs to size itself lives
	-- here, so there is exactly one place to tune the whole layout.
	local PROFILES = {
		Phone = {
			WindowSize = Vector2.new(0.94, 0.86), -- scale of viewport
			WindowMin = Vector2.new(300, 260),
			Rail = 56, RailIcon = 20, RailFont = 8,
			Header = 44, Row = 30, RowGap = 8, SectionGap = 10,
			Pad = 9, FontBody = 13, FontTitle = 15, FontSmall = 11,
			Checkbox = 18, Track = 8, Knob = 46, Columns = 1,
			ScrollBar = 4, MinHit = 44,
		},
		Tablet = {
			WindowSize = Vector2.new(0.82, 0.78),
			WindowMin = Vector2.new(420, 320),
			Rail = 62, RailIcon = 20, RailFont = 9,
			Header = 42, Row = 26, RowGap = 7, SectionGap = 11,
			Pad = 10, FontBody = 13, FontTitle = 15, FontSmall = 11,
			Checkbox = 16, Track = 7, Knob = 44, Columns = 2,
			ScrollBar = 4, MinHit = 40,
		},
		Desktop = {
			WindowSize = Vector2.new(0, 0), -- fixed pixel size below
			WindowFixed = Vector2.new(760, 500),
			WindowMin = Vector2.new(520, 340),
			Rail = 66, RailIcon = 19, RailFont = 9,
			Header = 40, Row = 22, RowGap = 6, SectionGap = 12,
			Pad = 10, FontBody = 12, FontTitle = 15, FontSmall = 11,
			Checkbox = 13, Track = 6, Knob = 40, Columns = 2,
			ScrollBar = 3, MinHit = 20,
		},
		Wide = {
			WindowSize = Vector2.new(0, 0),
			WindowFixed = Vector2.new(880, 560),
			WindowMin = Vector2.new(560, 360),
			Rail = 70, RailIcon = 20, RailFont = 10,
			Header = 42, Row = 24, RowGap = 7, SectionGap = 13,
			Pad = 12, FontBody = 13, FontTitle = 16, FontSmall = 11,
			Checkbox = 14, Track = 6, Knob = 44, Columns = 2,
			ScrollBar = 3, MinHit = 20,
		},
	}

	-- Compact mode shrinks everything that is safe to shrink.
	local COMPACT_DELTA = {
		Row = -4, RowGap = -2, SectionGap = -3, Pad = -3,
		Header = -6, Rail = -8, FontBody = -1, FontTitle = -1,
	}

	local function classify(width, height)
		if Util.IsMobile() or UserInputService.TouchEnabled and width < 900 then
			return width < 720 and "Phone" or "Tablet"
		end
		if width < 700 then return "Phone" end
		if width < 1100 then return "Tablet" end
		if width >= 2200 then return "Wide" end
		return "Desktop"
	end

	function Scale:Recompute()
		local viewport = Util.Viewport()
		self.Viewport = viewport
		self.Touch = UserInputService.TouchEnabled
		self.Device = classify(viewport.X, viewport.Y)

		-- Adaptive factor: viewport-relative, clamped, then user multiplier.
		local raw = viewport.X / REFERENCE_WIDTH
		self.Factor = math.clamp(raw, 0.72, 1.45) * self.Multiplier

		local base = PROFILES[self.Device]
		local metrics = {}
		for k, v in pairs(base) do metrics[k] = v end
		if self.Compact then
			for k, delta in pairs(COMPACT_DELTA) do
				if type(metrics[k]) == "number" then
					metrics[k] = math.max(metrics[k] + delta, 4)
				end
			end
			metrics.Columns = 1
		end
		self.M = metrics
		return metrics
	end

	-- adaptive unit: design pixels → device pixels
	function Scale.u(n)
		return math.max(1, math.floor(n * Scale.Factor + 0.5))
	end

	-- font size: scaled but clamped to a legible range
	function Scale.f(n)
		return math.clamp(math.floor(n * math.clamp(Scale.Factor, 0.9, 1.3) + 0.5), 9, 28)
	end

	-- hit target: never smaller than the platform minimum
	function Scale.touch(n)
		return math.max(Scale.u(n), Scale.M and Scale.M.MinHit or 20)
	end

	function Scale:Metric(name)
		local value = self.M and self.M[name]
		if value == nil then
			Void.Log:Debug("unknown scale metric '%s'", tostring(name))
			return 0
		end
		if type(value) == "number" then return Scale.u(value) end
		return value
	end

	function Scale:Font(name)
		local value = self.M and self.M[name]
		return Scale.f(value or 12)
	end

	function Scale:WindowSize()
		local m = self.M
		local viewport = self.Viewport
		if m.WindowFixed then
			local w = math.min(Scale.u(m.WindowFixed.X), viewport.X - Scale.u(40))
			local h = math.min(Scale.u(m.WindowFixed.Y), viewport.Y - Scale.u(40))
			return UDim2.fromOffset(w, h)
		end
		return UDim2.fromOffset(
			math.floor(viewport.X * m.WindowSize.X),
			math.floor(viewport.Y * m.WindowSize.Y)
		)
	end

	function Scale:MinWindowSize()
		return Vector2.new(Scale.u(self.M.WindowMin.X), Scale.u(self.M.WindowMin.Y))
	end

	function Scale:IsPhone() return self.Device == "Phone" end
	function Scale:IsTablet() return self.Device == "Tablet" end
	function Scale:IsMobileClass() return self.Device == "Phone" or self.Device == "Tablet" end
	function Scale:Columns() return (self.M and self.M.Columns) or 2 end

	function Scale:OnChanged(fn)
		table.insert(self._listeners, fn)
		return function()
			for i = #self._listeners, 1, -1 do
				if self._listeners[i] == fn then table.remove(self._listeners, i) end
			end
		end
	end

	function Scale:_notify()
		for _, fn in ipairs(self._listeners) do
			local ok, err = pcall(fn, self)
			if not ok then Void.Log:Error("scale listener failed: %s", tostring(err)) end
		end
	end

	function Scale:SetMultiplier(value)
		self.Multiplier = math.clamp(tonumber(value) or 1, 0.6, 2)
		self:Recompute()
		self:_notify()
		return self.Multiplier
	end

	function Scale:SetCompact(state)
		self.Compact = state and true or false
		self:Recompute()
		self:_notify()
		return self.Compact
	end

	function Scale:ToggleCompact()
		return self:SetCompact(not self.Compact)
	end

	-- Single viewport listener, debounced: resizing a window fires dozens of
	-- events per second and every one of them would otherwise relayout the UI.
	function Scale:Start(maid)
		self:Recompute()
		if self._started then return end
		self._started = true

		local apply = Util.Debounce(function()
			local before = self.Device
			local beforeFactor = self.Factor
			self:Recompute()
			if before ~= self.Device or math.abs(beforeFactor - self.Factor) > 0.01 then
				Void.Log:Debug("viewport changed → device=%s factor=%.2f", self.Device, self.Factor)
				self:_notify()
			end
		end, 0.15)

		local cam = workspace.CurrentCamera
		if cam then
			maid:Give(cam:GetPropertyChangedSignal("ViewportSize"):Connect(apply))
		end
		maid:Give(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
			local newCam = workspace.CurrentCamera
			if newCam then
				maid:Give(newCam:GetPropertyChangedSignal("ViewportSize"):Connect(apply))
			end
			apply()
		end))
		maid:Give(GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(apply))
		maid:Give(UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(apply))
	end

	Scale:Recompute()
	Void.Scale = Scale
	return Scale
end
