--[[
	VoidCriptUI · Elements/Slider.lua

		Section:CreateSlider({
			Name = "Walk speed",
			Flag = "walkspeed",
			Range = { 16, 200 },
			Increment = 1,
			CurrentValue = 16,
			Suffix = " studs",
			Editable = true,        -- click the value to type it (roadmap #4)
			CallbackOnRelease = false, -- fire only when the grip is released (#37)
			Throttle = 0.03,        -- min seconds between callbacks while dragging
			Callback = function(value) end,
		})

	Performance notes:
	  · dragging uses the shared InputChanged pass from Util.BindDrag; there is
	    no while-loop and no per-frame connection
	  · the fill is resized directly (cheap) while the *callback* goes through a
	    throttle, so heavy user code cannot stall the drag
	  · `CallbackOnRelease` defers the callback entirely to mouse-up for very
	    expensive operations
]]

return function(Void)
	local Util, Theme, Scale, Common = Void.Util, Void.Theme, Void.Scale, Void.Common

	Void.Elements.Slider = function(ctx, cfg)
		cfg = cfg or {}
		local control = Void.Control.new("Slider", cfg, ctx)
		local maid = control:GetMaid()

		local min = (cfg.Range and cfg.Range[1]) or cfg.Min or 0
		local max = (cfg.Range and cfg.Range[2]) or cfg.Max or 100
		if max <= min then
			Void.Log:Warn("Slider '%s' has an invalid range (%s..%s); using 0..100", tostring(cfg.Name), tostring(min), tostring(max))
			min, max = 0, 100
		end
		local increment = cfg.Increment or cfg.Step or 1
		local suffix = cfg.Suffix or ""
		local prefix = cfg.Prefix or ""
		local value = math.clamp(tonumber(cfg.CurrentValue or cfg.Default or min) or min, min, max)

		local rowHeight = Scale:Metric("Row") + Scale.u(14)
		local holder = Common.Stack(ctx.Parent, rowHeight)

		local labelWidth = 0.62
		local label = Common.Label(holder, cfg.Name or "Slider", {
			Token = "TextDim",
			Size2 = UDim2.new(labelWidth, 0, 0, Scale.u(14)),
		})

		local chip, chipStroke = Common.Chip(holder, prefix .. tostring(value) .. suffix, {
			Interactive = cfg.Editable ~= false,
			Height = 16,
			Transparent = true,
			Token = "Accent",
		})
		chip.Position = UDim2.new(1, 0, 0, Scale.u(7))
		chip.Size = UDim2.new(0, 0, 0, Scale.u(14))

		local track = Common.Track(holder, { Position = UDim2.new(0, 0, 0, Scale.u(20)) })

		local function ratio(v)
			return (v - min) / (max - min)
		end

		local function render(v, instant)
			local alpha = ratio(v)
			local dur = instant and 0 or Util.Motion.Fast
			if instant then
				track.Fill.Size = UDim2.fromScale(alpha, 1)
				track.Grip.Position = UDim2.fromScale(alpha, 0.5)
			else
				Util.Tween(track.Fill, { Size = UDim2.fromScale(alpha, 1) }, dur)
				Util.Tween(track.Grip, { Position = UDim2.fromScale(alpha, 0.5) }, dur)
			end
			chip.Text = prefix .. tostring(v) .. suffix
		end

		-- Throttled emit so heavy callbacks cannot stall the drag.
		local emit = Util.Throttle(function(v)
			control:_emit(v)
		end, cfg.Throttle or 0.03)

		local function apply(raw, fire, instant, immediate)
			local clamped = math.clamp(tonumber(raw) or min, min, max)
			local rounded = Util.Round(clamped, increment)
			rounded = math.clamp(rounded, min, max)
			if rounded == value and not instant then
				if fire and immediate then control:_emit(value) end
				return value
			end
			value = rounded
			render(value, instant)
			if fire then
				if immediate then
					control:_emit(value)
				else
					emit(value)
				end
			end
			return value
		end

		control._get = function() return value end
		control._raw = function() return value end
		control._set = function(v, fire) apply(v, fire, false, true) end

		-- ── dragging ────────────────────────────────────────────────────
		local dragging = false
		local deferCallback = cfg.CallbackOnRelease == true

		local isDragging = Util.BindDrag(track.Track, maid, function(alpha)
			if not control:IsEnabled() then return end
			dragging = true
			Util.Tween(track.Grip, { Size = UDim2.fromOffset(Scale.u(11), Scale.u(11)) }, Util.Motion.Fast)
			apply(min + alpha * (max - min), not deferCallback, true)
		end, function()
			dragging = false
			Util.Tween(track.Grip, { Size = UDim2.fromOffset(Scale.u(9), Scale.u(9)) }, Util.Motion.Fast)
			if deferCallback then
				control:_emit(value)
			else
				control:_emit(value) -- final exact value after the throttle
			end
		end)
		control._isDragging = isDragging

		-- hover feedback on the track
		maid:Give(track.Track.MouseEnter:Connect(function()
			Util.Tween(track.Stroke, { Color = Theme.C.OutlineStrong }, Util.Motion.Fast)
		end))
		maid:Give(track.Track.MouseLeave:Connect(function()
			if not dragging then
				Util.Tween(track.Stroke, { Color = Theme.C.OutlineSoft }, Util.Motion.Fast)
			end
		end))

		-- ── keyboard entry (roadmap #4) ─────────────────────────────────
		if cfg.Editable ~= false then
			local editor
			editor = Common.EditableValue(chip, {
				Width = 62,
				OnCommit = function(text)
					local parsed = tonumber((text:gsub("[^%-%d%.]", "")))
					if parsed == nil then
						Void.Log:Warn("slider '%s': '%s' is not a number", tostring(cfg.Name), tostring(text))
						Void.Notify:Push({ Title = "Invalid value", Content = ("`%s` is not a number"):format(tostring(text)), Type = "warning", Duration = 4 })
						return
					end
					if parsed < min or parsed > max then
						Void.Notify:Push({
							Title = "Out of range",
							Content = ("Value clamped to **%s … %s**"):format(tostring(min), tostring(max)),
							Type = "warning", Duration = 4,
						})
					end
					apply(parsed, true, false, true)
				end,
			})
			editor.Box.Position = UDim2.new(1, 0, 0, Scale.u(7))
			editor.Box.AnchorPoint = Vector2.new(1, 0)
			maid:Give(chip.MouseButton1Click:Connect(function()
				if not control:IsEnabled() then return end
				editor.Open(tostring(value))
			end))
			maid:Give(chip.MouseEnter:Connect(function()
				Util.Tween(chip, { TextColor3 = Theme.C.AccentSoft }, Util.Motion.Fast)
			end))
			maid:Give(chip.MouseLeave:Connect(function()
				Util.Tween(chip, { TextColor3 = Theme.C.Accent }, Util.Motion.Fast)
			end))
			control._editor = editor
		end

		control._setName = function(name) label.Text = name end
		control._setEnabled = function(enabled)
			label.TextTransparency = enabled and 0 or 0.5
			chip.TextTransparency = enabled and 0 or 0.5
			track.Track.BackgroundTransparency = enabled and 0 or 0.4
		end

		control:_finalise(holder, holder)
		render(value, true)

		-- public extras
		function control:SetRange(newMin, newMax)
			min, max = newMin, newMax
			apply(value, false, true)
			return self
		end
		function control:GetRange()
			return min, max
		end

		if cfg.FireOnStart and cfg.Callback then
			Void.Log:GuardAsync(("Slider '%s' initial"):format(tostring(cfg.Name)), cfg.Callback, value, control)
		end

		return control
	end

	-- ════════════════════════════════════════════════════════════════════
	-- RANGE SLIDER (roadmap #3) — two grips, returns { Min = n, Max = n }
	-- ════════════════════════════════════════════════════════════════════
	Void.Elements.RangeSlider = function(ctx, cfg)
		cfg = cfg or {}
		local control = Void.Control.new("RangeSlider", cfg, ctx)
		local maid = control:GetMaid()

		local min = (cfg.Range and cfg.Range[1]) or 0
		local max = (cfg.Range and cfg.Range[2]) or 100
		local increment = cfg.Increment or 1
		local suffix = cfg.Suffix or ""
		local low = math.clamp(tonumber(cfg.CurrentMin or cfg.MinValue or min) or min, min, max)
		local high = math.clamp(tonumber(cfg.CurrentMax or cfg.MaxValue or max) or max, min, max)
		if low > high then low, high = high, low end

		local holder = Common.Stack(ctx.Parent, Scale:Metric("Row") + Scale.u(14))

		local label = Common.Label(holder, cfg.Name or "Range", {
			Token = "TextDim",
			Size2 = UDim2.new(0.55, 0, 0, Scale.u(14)),
		})

		local chip = Common.Chip(holder, "", { Transparent = true, Token = "Accent" })
		chip.Position = UDim2.new(1, 0, 0, Scale.u(7))
		chip.Size = UDim2.new(0, 0, 0, Scale.u(14))

		local track = Common.Track(holder, { Position = UDim2.new(0, 0, 0, Scale.u(20)), Grip = false })
		track.Fill.Size = UDim2.fromScale(0, 1)

		-- second grip
		local function makeGrip(name)
			local grip = Util.New("Frame", {
				Name = name,
				BackgroundColor3 = Theme.C.Text,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.fromOffset(Scale.u(10), Scale.u(10)),
				ZIndex = 4,
				Parent = track.Track,
			})
			Theme:Paint(grip, { BackgroundColor3 = "Text" })
			Util.Corner(grip, 999)
			Util.Stroke(grip, Theme.C.Background, 2)
			return grip
		end
		local gripLow = makeGrip("GripLow")
		local gripHigh = makeGrip("GripHigh")

		local function render(instant)
			local a = (low - min) / (max - min)
			local b = (high - min) / (max - min)
			local dur = instant and 0 or Util.Motion.Fast
			if instant then
				track.Fill.Position = UDim2.fromScale(a, 0)
				track.Fill.Size = UDim2.fromScale(b - a, 1)
				gripLow.Position = UDim2.fromScale(a, 0.5)
				gripHigh.Position = UDim2.fromScale(b, 0.5)
			else
				Util.Tween(track.Fill, { Position = UDim2.fromScale(a, 0), Size = UDim2.fromScale(b - a, 1) }, dur)
				Util.Tween(gripLow, { Position = UDim2.fromScale(a, 0.5) }, dur)
				Util.Tween(gripHigh, { Position = UDim2.fromScale(b, 0.5) }, dur)
			end
			chip.Text = ("%s%s – %s%s"):format(tostring(low), suffix, tostring(high), suffix)
		end

		local emit = Util.Throttle(function()
			control:_emit({ Min = low, Max = high })
		end, cfg.Throttle or 0.04)

		local function apply(newLow, newHigh, fire, instant, immediate)
			low = math.clamp(Util.Round(newLow, increment), min, max)
			high = math.clamp(Util.Round(newHigh, increment), min, max)
			if low > high then low, high = high, low end
			render(instant)
			if fire then
				if immediate then control:_emit({ Min = low, Max = high }) else emit() end
			end
		end

		control._get = function() return { Min = low, Max = high } end
		control._raw = function() return { Min = low, Max = high } end
		control._set = function(v, fire)
			if type(v) == "table" then
				apply(v.Min or v[1] or low, v.Max or v[2] or high, fire, false, true)
			end
		end

		-- Whichever grip is closer to the click follows the pointer.
		local active = nil
		Util.BindDrag(track.Track, maid, function(alpha)
			if not control:IsEnabled() then return end
			local target = min + alpha * (max - min)
			if active == nil then
				local distLow = math.abs(target - low)
				local distHigh = math.abs(target - high)
				active = distLow <= distHigh and "low" or "high"
			end
			if active == "low" then
				apply(target, high, true, true)
			else
				apply(low, target, true, true)
			end
		end, function()
			active = nil
			control:_emit({ Min = low, Max = high })
		end)

		control._setName = function(name) label.Text = name end
		control:_finalise(holder, holder)
		render(true)
		return control
	end
end
