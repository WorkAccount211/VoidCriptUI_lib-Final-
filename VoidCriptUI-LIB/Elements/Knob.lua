--[[
	VoidCriptUI · Elements/Knob.lua
	Circular dial as an alternative to the slider.

		Section:CreateKnob({
			Name = "FOV",
			Flag = "fov",
			Range = { 30, 120 },
			Increment = 1,
			CurrentValue = 90,
			Sweep = 270,          -- degrees of travel (default 270)
			Callback = function(v) end,
		})

	The arc is drawn with 24 small radial ticks instead of an image, so it is
	crisp at any resolution, themable, and costs nothing to animate (we only
	recolour the ticks that are inside the current value).

	Interaction: vertical drag (up = increase) plus scroll wheel. Angular
	dragging feels bad on touch screens, so vertical drag is the primary
	gesture — the same choice every good audio plugin makes.

	Users can switch every slider in the UI to knobs from the built-in
	Interface tab (`Library:SetSliderStyle("Knob")`).
]]

return function(Void)
	local Util, Theme, Scale, Common = Void.Util, Void.Theme, Void.Scale, Void.Common
	local UserInputService = game:GetService("UserInputService")

	local TICKS = 24

	Void.Elements.Knob = function(ctx, cfg)
		cfg = cfg or {}
		local control = Void.Control.new("Knob", cfg, ctx)
		local maid = control:GetMaid()

		local min = (cfg.Range and cfg.Range[1]) or cfg.Min or 0
		local max = (cfg.Range and cfg.Range[2]) or cfg.Max or 100
		local increment = cfg.Increment or 1
		local suffix = cfg.Suffix or ""
		local sweep = math.clamp(cfg.Sweep or 270, 90, 340)
		local value = math.clamp(tonumber(cfg.CurrentValue or cfg.Default or min) or min, min, max)

		local size = Scale.u(cfg.Size or Scale.M.Knob)
		local holder = Common.Stack(ctx.Parent, size + Scale.u(26))

		local label = Common.Label(holder, cfg.Name or "Knob", {
			Token = "TextDim",
			Align = Enum.TextXAlignment.Center,
			Size2 = UDim2.new(1, 0, 0, Scale.u(14)),
		})

		local dial = Util.New("Frame", {
			Name = "Dial",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, Scale.u(16)),
			Size = UDim2.fromOffset(size, size),
			Parent = holder,
		})

		-- hit surface (a button so we get MouseEnter/Click for free)
		local hit = Util.New("TextButton", {
			Name = "Hit",
			BackgroundTransparency = 1,
			Text = "",
			Size = UDim2.fromScale(1, 1),
			ZIndex = 6,
			Parent = dial,
		})

		-- centre puck
		local puck = Util.New("Frame", {
			Name = "Puck",
			BackgroundColor3 = Theme.C.Element,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.62, 0.62),
			ZIndex = 3,
			Parent = dial,
		})
		Theme:Paint(puck, { BackgroundColor3 = "Element" })
		Util.Corner(puck, 999)
		local puckStroke = Util.Stroke(puck, Theme.C.OutlineSoft)
		Theme:Paint(puckStroke, { Color = "OutlineSoft" })

		-- inner glass sheen
		Util.New("Frame", {
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0.93,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 4,
			Parent = puck,
		}, {
			Util.New("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Util.New("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.35),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})

		local readout = Util.New("TextLabel", {
			Name = "Readout",
			BackgroundTransparency = 1,
			Font = Theme:Font("FontBold"),
			Text = tostring(value) .. suffix,
			TextColor3 = Theme.C.Text,
			TextSize = Scale.f(math.max(10, size * 0.24)),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 5,
			Parent = puck,
		})
		Theme:Paint(readout, { TextColor3 = "Text" })

		-- pointer needle
		local needle = Util.New("Frame", {
			Name = "Needle",
			BackgroundColor3 = Theme.C.Accent,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(2, math.floor(size * 0.26)),
			ZIndex = 5,
			Parent = puck,
		})
		Theme:Paint(needle, { BackgroundColor3 = "Accent" })
		Util.Corner(needle, 1)
		local needleRotator = Util.New("Frame", {
			Name = "Rotator",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 5,
			Parent = puck,
		})
		needle.Parent = needleRotator

		-- radial ticks
		local ticks = {}
		local startAngle = -sweep / 2
		for i = 1, TICKS do
			local alpha = (i - 1) / (TICKS - 1)
			local angle = math.rad(startAngle + alpha * sweep)
			local radius = size * 0.44
			local tick = Util.New("Frame", {
				Name = "Tick" .. i,
				BackgroundColor3 = Theme.C.OutlineStrong,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, math.floor(math.sin(angle) * radius), 0.5, math.floor(-math.cos(angle) * radius)),
				Size = UDim2.fromOffset(2, math.max(3, math.floor(size * 0.1))),
				Rotation = math.deg(angle),
				ZIndex = 2,
				Parent = dial,
			})
			Util.Corner(tick, 1)
			ticks[i] = tick
		end

		local function render(instant)
			local alpha = (value - min) / (max - min)
			local lit = math.floor(alpha * TICKS + 0.5)
			for i, tick in ipairs(ticks) do
				local on = i <= lit
				local target = on and Theme.C.Accent or Theme.C.OutlineStrong
				if instant then
					tick.BackgroundColor3 = target
				elseif tick.BackgroundColor3 ~= target then
					Util.Tween(tick, { BackgroundColor3 = target }, Util.Motion.Fast)
				end
			end
			local rotation = startAngle + alpha * sweep
			if instant then
				needleRotator.Rotation = rotation
			else
				Util.Tween(needleRotator, { Rotation = rotation }, Util.Motion.Fast)
			end
			readout.Text = tostring(value) .. suffix
		end

		local emit = Util.Throttle(function() control:_emit(value) end, cfg.Throttle or 0.03)

		local function apply(raw, fire, instant, immediate)
			local rounded = math.clamp(Util.Round(math.clamp(tonumber(raw) or min, min, max), increment), min, max)
			if rounded == value and not instant then
				if fire and immediate then control:_emit(value) end
				return
			end
			value = rounded
			render(instant)
			if fire then
				if immediate then control:_emit(value) else emit() end
			end
		end

		control._get = function() return value end
		control._raw = function() return value end
		control._set = function(v, fire) apply(v, fire, false, true) end

		-- ── vertical drag ───────────────────────────────────────────────
		local dragging, dragStart, startValue = false, nil, value
		local sensitivity = cfg.Sensitivity or 160 -- pixels for the full range

		maid:Give(hit.InputBegan:Connect(function(input)
			local t = input.UserInputType
			if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
			if not control:IsEnabled() then return end
			dragging = true
			dragStart = input.Position
			startValue = value
			Util.Tween(puck, { Size = UDim2.fromScale(0.66, 0.66) }, Util.Motion.Fast)
			Util.Tween(puckStroke, { Color = Theme.C.Accent }, Util.Motion.Fast)
		end))

		maid:Give(UserInputService.InputChanged:Connect(function(input)
			if not dragging then return end
			local t = input.UserInputType
			if t ~= Enum.UserInputType.MouseMovement and t ~= Enum.UserInputType.Touch then return end
			local delta = dragStart.Y - input.Position.Y
			local span = max - min
			apply(startValue + (delta / sensitivity) * span, true, true)
		end))

		maid:Give(UserInputService.InputEnded:Connect(function(input)
			local t = input.UserInputType
			if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
			if not dragging then return end
			dragging = false
			Util.Tween(puck, { Size = UDim2.fromScale(0.62, 0.62) }, Util.Motion.Normal, Enum.EasingStyle.Back)
			Util.Tween(puckStroke, { Color = Theme.C.OutlineSoft }, Util.Motion.Fast)
			control:_emit(value)
		end))

		-- scroll wheel: one increment per notch
		maid:Give(hit.InputChanged:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
			if not control:IsEnabled() then return end
			apply(value + input.Position.Z * increment, true, false, true)
		end))

		maid:Give(hit.MouseEnter:Connect(function()
			Util.Tween(puckStroke, { Color = Theme.C.OutlineStrong }, Util.Motion.Fast)
			Util.Tween(label, { TextColor3 = Theme.C.Text }, Util.Motion.Fast)
		end))
		maid:Give(hit.MouseLeave:Connect(function()
			if not dragging then
				Util.Tween(puckStroke, { Color = Theme.C.OutlineSoft }, Util.Motion.Fast)
				Util.Tween(label, { TextColor3 = Theme.C.TextDim }, Util.Motion.Fast)
			end
		end))

		-- double click resets to the default
		local lastClick = 0
		maid:Give(hit.MouseButton1Click:Connect(function()
			local now = os.clock()
			if now - lastClick < 0.3 then
				apply(cfg.CurrentValue or cfg.Default or min, true, false, true)
			end
			lastClick = now
		end))

		control._setName = function(name) label.Text = name end
		control:_finalise(holder, holder)
		render(true)

		function control:SetRange(newMin, newMax)
			min, max = newMin, newMax
			apply(value, false, true)
			return self
		end

		return control
	end
end
