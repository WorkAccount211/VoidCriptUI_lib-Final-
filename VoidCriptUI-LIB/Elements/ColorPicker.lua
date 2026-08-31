--[[
	VoidCriptUI · Elements/ColorPicker.lua
	Colour picker with HEX entry, alpha, rainbow mode and palette presets
	(roadmap #8, #9).

		Section:CreateColorPicker({
			Name = "ESP colour",
			Flag = "esp_color",
			Color = Color3.fromRGB(199, 62, 110),
			Alpha = 1,                 -- omit to hide the alpha bar
			Rainbow = false,           -- auto-cycling hue
			RainbowSpeed = 0.35,       -- hue turns per second
			Palette = { "#ff0000", "#00ff88" },   -- extra preset swatches
			Callback = function(color, alpha) end,
		})

	The picker panel lives on the window overlay so it is never clipped. A
	single shared Heartbeat drives every rainbow picker in the UI (one
	connection total, not one per element).
]]

return function(Void)
	local RunService = game:GetService("RunService")
	local Util, Theme, Scale, Common = Void.Util, Void.Theme, Void.Scale, Void.Common

	-- ── shared rainbow driver ───────────────────────────────────────────
	local rainbow = { Subscribers = {}, Connection = nil, Hue = 0 }

	local function ensureRainbowDriver()
		if rainbow.Connection then return end
		rainbow.Connection = RunService.Heartbeat:Connect(function(dt)
			if next(rainbow.Subscribers) == nil then return end
			rainbow.Hue = (rainbow.Hue + dt * 0.2) % 1
			for control, speed in pairs(rainbow.Subscribers) do
				if control._destroyed then
					rainbow.Subscribers[control] = nil
				else
					control._rainbowTick((rainbow.Hue * (speed / 0.2)) % 1)
				end
			end
		end)
		Void.RootMaid:Give(rainbow.Connection)
	end

	local DEFAULT_PALETTE = {
		"#FFFFFF", "#C73E6E", "#E04848", "#F0C440", "#50C878",
		"#3898DB", "#9660FF", "#00E5C0", "#FF7BAC", "#111114",
	}

	Void.Elements.ColorPicker = function(ctx, cfg)
		cfg = cfg or {}
		local control = Void.Control.new("ColorPicker", cfg, ctx)
		local maid = control:GetMaid()

		local color = typeof(cfg.Color) == "Color3" and cfg.Color
			or (type(cfg.Color) == "string" and Util.FromHex(cfg.Color))
			or Theme.C.Accent
		local hasAlpha = cfg.Alpha ~= nil
		local alpha = tonumber(cfg.Alpha) or 1
		local rainbowOn = cfg.Rainbow or false
		local rainbowSpeed = cfg.RainbowSpeed or 0.35
		local h, s, v = color:ToHSV()

		local inline = cfg.Inline == true
		local row, label

		if inline then
			row = ctx.Parent
		else
			row = Common.Row(ctx.Parent, Scale:Metric("Row"), false)
			Common.RowHighlight(row, maid)
			label = Common.Label(row, cfg.Name or "Colour", {
				Token = "TextDim",
				Size2 = UDim2.new(1, -Scale.u(46), 1, 0),
			})
		end

		local rightOffset = inline and (cfg.InlineOffset or 0) or 0

		-- swatch button
		local swatch = Util.New("TextButton", {
			Name = "Swatch",
			BackgroundColor3 = color,
			Text = "",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -rightOffset, 0.5, 0),
			Size = UDim2.fromOffset(Scale.touch(30), Scale.u(15)),
			Parent = row,
		})
		Util.Corner(swatch, Theme.Style.RadiusSmall - 1)
		local swatchStroke = Util.Stroke(swatch, Theme.C.Outline)
		Theme:Paint(swatchStroke, { Color = "Outline" })

		-- checkerboard behind the swatch so alpha is visible
		if hasAlpha then
			Util.New("ImageLabel", {
				Name = "Checker",
				Image = "rbxassetid://14204231522",
				ScaleType = Enum.ScaleType.Tile,
				TileSize = UDim2.fromOffset(6, 6),
				ImageTransparency = 0.6,
				Size = UDim2.fromScale(1, 1),
				ZIndex = -1,
				Parent = swatch,
			})
		end

		-- ── popup panel ─────────────────────────────────────────────────
		local panelWidth = Scale.u(212)
		local panelHeight = Scale.u(hasAlpha and 214 or 194)
		local popup = Common.Popup(ctx, swatch, UDim2.fromOffset(panelWidth, panelHeight), { MatchWidth = false })
		popup.Canvas.Size = UDim2.fromOffset(panelWidth, panelHeight)
		maid:Give(function() popup.Destroy() end)

		local panel = Util.New("Frame", {
			Name = "Panel",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Parent = popup.Card,
		}, {
			Util.New("UIPadding", {
				PaddingLeft = UDim.new(0, Scale.u(9)), PaddingRight = UDim.new(0, Scale.u(9)),
				PaddingTop = UDim.new(0, Scale.u(9)), PaddingBottom = UDim.new(0, Scale.u(9)),
			}),
		})

		-- saturation/value field
		local svBox = Util.New("TextButton", {
			Name = "SV",
			BackgroundColor3 = Color3.fromHSV(h, 1, 1),
			Text = "",
			Size = UDim2.new(1, 0, 0, Scale.u(96)),
			Parent = panel,
		})
		Util.Corner(svBox, Theme.Style.RadiusSmall)
		Util.New("UIGradient", {
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1)),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = svBox,
		})
		local svDark = Util.New("Frame", {
			Name = "Dark",
			BackgroundColor3 = Color3.new(0, 0, 0),
			Size = UDim2.fromScale(1, 1),
			Parent = svBox,
		}, {
			Util.New("UICorner", { CornerRadius = UDim.new(0, Theme.Style.RadiusSmall) }),
			Util.New("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(1, 0),
				}),
			}),
		})

		local svCursor = Util.New("Frame", {
			Name = "Cursor",
			BackgroundColor3 = Color3.new(1, 1, 1),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(s, 1 - v),
			Size = UDim2.fromOffset(Scale.u(8), Scale.u(8)),
			ZIndex = 4,
			Parent = svBox,
		})
		Util.Corner(svCursor, 999)
		Util.Stroke(svCursor, Color3.new(0, 0, 0), 1)

		-- hue bar
		local hueBar = Util.New("TextButton", {
			Name = "Hue",
			BackgroundColor3 = Color3.new(1, 1, 1),
			Text = "",
			Position = UDim2.fromOffset(0, Scale.u(102)),
			Size = UDim2.new(1, 0, 0, Scale.u(11)),
			Parent = panel,
		})
		Util.Corner(hueBar, 999)
		Util.New("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
				ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
				ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
				ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
				ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
				ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
			}),
			Parent = hueBar,
		})
		local hueCursor = Util.New("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(h, 0.5),
			Size = UDim2.fromOffset(Scale.u(4), Scale.u(15)),
			ZIndex = 4,
			Parent = hueBar,
		})
		Util.Corner(hueCursor, 2)
		Util.Stroke(hueCursor, Color3.new(0, 0, 0), 1)

		-- alpha bar
		local alphaBar, alphaCursor, alphaGradient
		local nextY = Scale.u(119)
		if hasAlpha then
			alphaBar = Util.New("TextButton", {
				Name = "Alpha",
				BackgroundColor3 = Color3.new(1, 1, 1),
				Text = "",
				Position = UDim2.fromOffset(0, nextY),
				Size = UDim2.new(1, 0, 0, Scale.u(11)),
				Parent = panel,
			})
			Util.Corner(alphaBar, 999)
			alphaGradient = Util.New("UIGradient", {
				Color = ColorSequence.new(Color3.new(0, 0, 0), color),
				Parent = alphaBar,
			})
			alphaCursor = Util.New("Frame", {
				BackgroundColor3 = Color3.new(1, 1, 1),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(alpha, 0.5),
				Size = UDim2.fromOffset(Scale.u(4), Scale.u(15)),
				ZIndex = 4,
				Parent = alphaBar,
			})
			Util.Corner(alphaCursor, 2)
			Util.Stroke(alphaCursor, Color3.new(0, 0, 0), 1)
			nextY = nextY + Scale.u(17)
		end

		-- HEX row: preview + editable hex + copy
		local hexRow = Util.New("Frame", {
			Name = "HexRow",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, nextY),
			Size = UDim2.new(1, 0, 0, Scale.touch(22)),
			Parent = panel,
		})
		nextY = nextY + Scale.u(28)

		local preview = Util.New("Frame", {
			Name = "Preview",
			BackgroundColor3 = color,
			Size = UDim2.fromOffset(Scale.u(22), Scale.u(22)),
			Parent = hexRow,
		})
		Util.Corner(preview, Theme.Style.RadiusSmall - 1)
		Util.Stroke(preview, Theme.C.Outline)

		local hexBox = Util.New("TextBox", {
			Name = "Hex",
			BackgroundColor3 = Theme.C.Element,
			Font = Theme:Font("FontMono"),
			Text = Util.ToHex(color),
			PlaceholderText = "#RRGGBB",
			PlaceholderColor3 = Theme.C.TextDark,
			TextColor3 = Theme.C.Text,
			TextSize = Scale.f(11),
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(Scale.u(26), 0),
			Size = UDim2.new(1, -Scale.u(26) - Scale.u(46), 1, 0),
			Parent = hexRow,
		})
		Theme:Paint(hexBox, { BackgroundColor3 = "Element", TextColor3 = "Text", PlaceholderColor3 = "TextDark" })
		Util.Corner(hexBox, Theme.Style.RadiusSmall)
		local hexStroke = Util.Stroke(hexBox, Theme.C.OutlineSoft)

		local copyBtn = Util.New("TextButton", {
			Name = "Copy",
			BackgroundColor3 = Theme.C.Element,
			Font = Theme:Font("Font"),
			Text = "copy",
			TextColor3 = Theme.C.TextDim,
			TextSize = Scale.f(10),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.fromOffset(Scale.u(42), Scale.u(22)),
			Parent = hexRow,
		})
		Theme:Paint(copyBtn, { BackgroundColor3 = "Element", TextColor3 = "TextDim" })
		Util.Corner(copyBtn, Theme.Style.RadiusSmall)
		Util.Stroke(copyBtn, Theme.C.OutlineSoft)

		-- palette swatches
		local paletteRow = Util.New("Frame", {
			Name = "Palette",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, nextY),
			Size = UDim2.new(1, 0, 0, Scale.u(16)),
			Parent = panel,
		}, {
			Util.New("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Scale.u(4)),
			}),
		})
		nextY = nextY + Scale.u(22)

		-- rainbow toggle row
		local rainbowRow = Util.New("TextButton", {
			Name = "RainbowRow",
			BackgroundTransparency = 1,
			Text = "",
			Position = UDim2.fromOffset(0, nextY),
			Size = UDim2.new(1, 0, 0, Scale.u(18)),
			Parent = panel,
		})
		local rainbowCheck = Common.Checkbox(rainbowRow, { Size = 12 })
		local rainbowLabel = Common.Label(rainbowRow, "rainbow", {
			Token = "TextDim",
			Position = UDim2.fromOffset(Scale.u(19), 0),
			Size2 = UDim2.new(1, -Scale.u(19), 1, 0),
		})

		popup.Canvas.Size = UDim2.fromOffset(panelWidth, nextY + Scale.u(28))

		-- ── rendering ───────────────────────────────────────────────────
		local function render(silent)
			color = Color3.fromHSV(h, s, v)
			swatch.BackgroundColor3 = color
			swatch.BackgroundTransparency = hasAlpha and (1 - alpha) * 0.75 or 0
			preview.BackgroundColor3 = color
			svBox.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
			svCursor.Position = UDim2.fromScale(s, 1 - v)
			svCursor.BackgroundColor3 = v > 0.55 and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
			hueCursor.Position = UDim2.fromScale(h, 0.5)
			if alphaGradient then
				alphaGradient.Color = ColorSequence.new(Color3.new(0, 0, 0), Color3.fromHSV(h, 1, 1))
				alphaCursor.Position = UDim2.fromScale(alpha, 0.5)
			end
			if not hexBox:IsFocused() then
				hexBox.Text = Util.ToHex(color)
			end
			if not silent then
				control:_emit({ Color = color, Alpha = alpha, Rainbow = rainbowOn })
			end
		end

		local emit = Util.Throttle(function() render(false) end, 0.03)
		local function renderThrottled()
			render(true)
			emit()
		end

		-- ── interaction ─────────────────────────────────────────────────
		Util.BindDrag(svBox, maid, function(x, y)
			if rainbowOn then return end
			s, v = x, 1 - y
			renderThrottled()
		end, function() render(false) end, "XY")

		Util.BindDrag(hueBar, maid, function(x)
			if rainbowOn then return end
			h = x
			renderThrottled()
		end, function() render(false) end)

		if alphaBar then
			Util.BindDrag(alphaBar, maid, function(x)
				alpha = x
				renderThrottled()
			end, function() render(false) end)
		end

		-- hex entry
		maid:Give(hexBox.Focused:Connect(function()
			Util.Tween(hexStroke, { Color = Theme.C.Accent }, Util.Motion.Fast)
		end))
		maid:Give(hexBox.FocusLost:Connect(function()
			Util.Tween(hexStroke, { Color = Theme.C.OutlineSoft }, Util.Motion.Fast)
			local parsed = Util.FromHex(hexBox.Text)
			if not parsed then
				hexBox.Text = Util.ToHex(color)
				Void.Notify:Push({ Title = "Invalid hex", Content = "Use the `#RRGGBB` format", Type = "warning", Duration = 4 })
				return
			end
			h, s, v = parsed:ToHSV()
			render(false)
		end))

		maid:Give(copyBtn.MouseButton1Click:Connect(function()
			local hex = Util.ToHex(color)
			local ok = type(setclipboard) == "function" and pcall(setclipboard, hex)
			Void.Notify:Push({
				Title = ok and "Copied" or "Hex code",
				Content = ("`%s`"):format(hex),
				Type = "info", Duration = 3,
			})
		end))

		-- palette
		local paletteColors = {}
		for _, hex in ipairs(DEFAULT_PALETTE) do paletteColors[#paletteColors + 1] = hex end
		for _, hex in ipairs(cfg.Palette or {}) do paletteColors[#paletteColors + 1] = hex end

		for index, hex in ipairs(paletteColors) do
			local swatchColor = Util.FromHex(hex) or Color3.new(1, 1, 1)
			local btn = Util.New("TextButton", {
				Name = "P" .. index,
				BackgroundColor3 = swatchColor,
				Text = "",
				Size = UDim2.fromOffset(Scale.u(15), Scale.u(15)),
				LayoutOrder = index,
				Parent = paletteRow,
			})
			Util.Corner(btn, Theme.Style.RadiusSmall - 1)
			local ps = Util.Stroke(btn, Theme.C.OutlineSoft)
			btn.MouseEnter:Connect(function()
				Util.Tween(btn, { Size = UDim2.fromOffset(Scale.u(17), Scale.u(17)) }, Util.Motion.Fast)
				Util.Tween(ps, { Color = Theme.C.Accent }, Util.Motion.Fast)
			end)
			btn.MouseLeave:Connect(function()
				Util.Tween(btn, { Size = UDim2.fromOffset(Scale.u(15), Scale.u(15)) }, Util.Motion.Fast)
				Util.Tween(ps, { Color = Theme.C.OutlineSoft }, Util.Motion.Fast)
			end)
			btn.MouseButton1Click:Connect(function()
				h, s, v = swatchColor:ToHSV()
				render(false)
			end)
		end

		-- rainbow mode
		control._rainbowTick = function(hue)
			h = hue
			s = math.max(s, 0.7)
			v = math.max(v, 0.85)
			render(true)
			control._emitRainbow = control._emitRainbow or Util.Throttle(function()
				control:_emit({ Color = color, Alpha = alpha, Rainbow = true })
			end, 0.1)
			control._emitRainbow()
		end

		local function setRainbow(state, fire)
			rainbowOn = state and true or false
			rainbowCheck.Set(rainbowOn)
			rainbowLabel.TextColor3 = rainbowOn and Theme.C.Text or Theme.C.TextDim
			svBox.Active = not rainbowOn
			hueBar.Active = not rainbowOn
			Util.Tween(svBox, { BackgroundTransparency = rainbowOn and 0.5 or 0 }, Util.Motion.Fast)
			if rainbowOn then
				rainbow.Subscribers[control] = rainbowSpeed
				ensureRainbowDriver()
			else
				rainbow.Subscribers[control] = nil
			end
			if fire then render(false) end
		end

		maid:Give(rainbowRow.MouseButton1Click:Connect(function()
			setRainbow(not rainbowOn, true)
		end))
		maid:Give(function() rainbow.Subscribers[control] = nil end)

		-- open / close
		maid:Give(swatch.MouseButton1Click:Connect(function()
			if not control:IsEnabled() then return end
			popup.Toggle()
			Util.Tween(swatchStroke, { Color = popup.Open and Theme.C.Accent or Theme.C.Outline }, Util.Motion.Fast)
		end))
		popup.OnClose = function()
			Util.Tween(swatchStroke, { Color = Theme.C.Outline }, Util.Motion.Fast)
		end
		maid:Give(swatch.MouseEnter:Connect(function()
			Util.Tween(swatch, { Size = UDim2.fromOffset(Scale.touch(33), Scale.u(16)) }, Util.Motion.Fast)
		end))
		maid:Give(swatch.MouseLeave:Connect(function()
			Util.Tween(swatch, { Size = UDim2.fromOffset(Scale.touch(30), Scale.u(15)) }, Util.Motion.Fast)
		end))

		-- ── control API ─────────────────────────────────────────────────
		control._get = function() return color, alpha end
		control._raw = function() return { Color = color, Alpha = alpha, Rainbow = rainbowOn } end
		control._set = function(value, fire)
			if typeof(value) == "Color3" then
				h, s, v = value:ToHSV()
			elseif type(value) == "string" then
				local parsed = Util.FromHex(value)
				if parsed then h, s, v = parsed:ToHSV() end
			elseif type(value) == "table" then
				if typeof(value.Color) == "Color3" then h, s, v = value.Color:ToHSV() end
				if value.Alpha then alpha = value.Alpha end
				if value.Rainbow ~= nil then setRainbow(value.Rainbow, false) end
			end
			render(not fire)
		end

		function control:GetColor() return color end
		function control:GetAlpha() return alpha end
		function control:GetHex() return Util.ToHex(color) end
		function control:SetRainbow(state) setRainbow(state, true) return self end
		function control:IsRainbow() return rainbowOn end

		control._setName = function(name) if label then label.Text = name end end
		control:_finalise(inline and swatch or row, swatch)

		setRainbow(rainbowOn, false)
		render(true)
		return control
	end
end
