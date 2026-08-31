--[[
	VoidCriptUI · Elements/Button.lua
	Button, ImageButton and confirmation buttons.

		Section:CreateButton({
			Name = "Rejoin server",
			Icon = "refresh",              -- optional leading icon
			Risky = true,                  -- ⚠ marker + "Are you sure?" dialog
			ConfirmText = "This will disconnect you.",
			DoubleClick = false,           -- inline arm/confirm instead of a dialog
			Callback = function() end,
		})

		Section:CreateImageButton({
			Name = "Discord",
			Image = 1234567,               -- asset id, rbxassetid:// or icon name
			Size = 34,
			Layout = "Icon",               -- Icon | IconText
			Callback = function() end,
		})
]]

return function(Void)
	local Util, Theme, Scale, Common = Void.Util, Void.Theme, Void.Scale, Void.Common

	Void.Elements.Button = function(ctx, cfg)
		cfg = cfg or {}
		local control = Void.Control.new("Button", cfg, ctx)
		local maid = control:GetMaid()

		local height = Scale.touch(cfg.Height or 26)
		local button = Util.New("TextButton", {
			Name = "Button",
			BackgroundColor3 = Theme.C.Element,
			Text = "",
			Size = UDim2.new(1, 0, 0, height),
			Parent = ctx.Parent,
		})
		Theme:Paint(button, { BackgroundColor3 = "Element" })
		Util.Corner(button, Theme.Style.RadiusSmall)
		local stroke = Util.Stroke(button, Theme.C.OutlineSoft)
		Theme:Paint(stroke, { Color = "OutlineSoft" })

		-- risky buttons get a tinted background and a warning glyph
		local isRisky = control.Risky
		if isRisky then
			Theme:Unpaint(stroke)
			stroke.Color = Theme.C.Risky
			stroke.Transparency = 0.55
		end

		local contentHolder = Util.New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Parent = button,
		}, {
			Util.New("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, Scale.u(6)),
			}),
		})

		local iconLabel
		if cfg.Icon or isRisky then
			local kind, value = Void.Icons:Resolve(cfg.Icon or "warning")
			if kind == "image" then
				iconLabel = Util.New("ImageLabel", {
					Image = value,
					ImageColor3 = isRisky and Theme.C.Risky or Theme.C.Accent,
					Size = UDim2.fromOffset(Scale.u(13), Scale.u(13)),
					LayoutOrder = 1,
					Parent = contentHolder,
				})
				Theme:Paint(iconLabel, { ImageColor3 = isRisky and "Risky" or "Accent" })
			else
				iconLabel = Util.New("TextLabel", {
					Font = Theme:Font("FontBold"),
					Text = value,
					TextColor3 = isRisky and Theme.C.Risky or Theme.C.Accent,
					TextSize = Scale.f(12),
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, Scale.u(14)),
					LayoutOrder = 1,
					Parent = contentHolder,
				})
				Theme:Paint(iconLabel, { TextColor3 = isRisky and "Risky" or "Accent" })
			end
		end

		local text = Util.New("TextLabel", {
			Name = "Text",
			BackgroundTransparency = 1,
			Font = Theme:Font("FontMedium"),
			Text = tostring(cfg.Name or cfg.Title or "Button"),
			TextColor3 = Theme.C.Text,
			TextSize = Scale.f(12),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, height),
			LayoutOrder = 2,
			Parent = contentHolder,
		})
		Theme:Paint(text, { TextColor3 = "Text" })

		control:_hoverable(button, button, "Element", "ElementHover", stroke)

		-- click feedback: a quick accent ripple from the press point
		local function ripple()
			local circle = Util.New("Frame", {
				Name = "Ripple",
				BackgroundColor3 = Theme.C.Accent,
				BackgroundTransparency = 0.65,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(0, 0),
				ZIndex = 0,
				Parent = button,
			})
			Util.Corner(circle, 999)
			local target = math.max(button.AbsoluteSize.X, button.AbsoluteSize.Y) * 2
			Util.Tween(circle, { Size = UDim2.fromOffset(target, target), BackgroundTransparency = 1 }, 0.4)
			task.delay(0.45, function() circle:Destroy() end)
		end

		-- inline double-click confirmation (alternative to the modal dialog)
		local armed, armTimer = false, nil
		local originalText = text.Text

		local function disarm()
			armed = false
			text.Text = originalText
			Util.Tween(text, { TextColor3 = Theme.C.Text }, Util.Motion.Fast)
			Util.Tween(stroke, { Color = isRisky and Theme.C.Risky or Theme.C.OutlineSoft }, Util.Motion.Fast)
		end

		local function fire()
			ripple()
			control:_emit(true)
			if cfg.Callback then
				Void.Log:GuardAsync(("Button '%s'"):format(tostring(cfg.Name)), cfg.Callback, control)
			end
		end

		maid:Give(button.MouseButton1Click:Connect(function()
			if not control:IsEnabled() then return end

			if cfg.DoubleClick then
				if not armed then
					armed = true
					text.Text = cfg.ConfirmLabel or "Click again to confirm"
					Util.Tween(text, { TextColor3 = Theme.C.Risky }, Util.Motion.Fast)
					Util.Tween(stroke, { Color = Theme.C.Risky }, Util.Motion.Fast)
					if armTimer then task.cancel(armTimer) end
					armTimer = task.delay(cfg.ConfirmTimeout or 2.5, function()
						armTimer = nil
						if armed then disarm() end
					end)
					return
				end
				if armTimer then task.cancel(armTimer) armTimer = nil end
				disarm()
				fire()
				return
			end

			control:_confirmedClick(fire)
		end))

		control._get = function() return nil end
		control._raw = function() return nil end
		control._set = function() end

		function control:Fire()
			fire()
			return self
		end
		function control:SetText(newText)
			originalText = tostring(newText)
			text.Text = originalText
			return self
		end
		control._setName = control.SetText
		control._setEnabled = function(enabled)
			text.TextTransparency = enabled and 0 or 0.5
			button.BackgroundTransparency = enabled and 0 or 0.5
			button.Active = enabled
		end

		control:_finalise(button, button)
		return control
	end

	-- ════════════════════════════════════════════════════════════════════
	-- IMAGE BUTTON — an icon-first button (roadmap: DX section)
	-- ════════════════════════════════════════════════════════════════════
	Void.Elements.ImageButton = function(ctx, cfg)
		cfg = cfg or {}
		local control = Void.Control.new("ImageButton", cfg, ctx)
		local maid = control:GetMaid()

		local iconOnly = (cfg.Layout or "Icon") == "Icon"
		local size = Scale.touch(cfg.Size or 34)

		local holder = Util.New("Frame", {
			Name = "ImageButtonHolder",
			BackgroundTransparency = 1,
			Size = iconOnly and UDim2.new(1, 0, 0, size) or UDim2.new(1, 0, 0, size),
			Parent = ctx.Parent,
		})

		local button = Util.New("ImageButton", {
			Name = "Button",
			BackgroundColor3 = Theme.C.Element,
			BackgroundTransparency = 0,
			Image = "",
			Size = iconOnly and UDim2.fromOffset(size, size) or UDim2.new(1, 0, 1, 0),
			Parent = holder,
		})
		Theme:Paint(button, { BackgroundColor3 = "Element" })
		Util.Corner(button, cfg.Round and 999 or Theme.Style.RadiusSmall)
		local stroke = Util.Stroke(button, Theme.C.OutlineSoft)
		Theme:Paint(stroke, { Color = "OutlineSoft" })

		local kind, value = Void.Icons:Resolve(cfg.Image or cfg.Icon or "image")
		local visual
		if kind == "image" then
			visual = Util.New("ImageLabel", {
				Name = "Icon",
				Image = value,
				ImageColor3 = cfg.Tint or Color3.new(1, 1, 1),
				ScaleType = Enum.ScaleType.Fit,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = iconOnly and UDim2.fromScale(0.5, 0.5) or UDim2.new(0, Scale.u(18), 0.5, 0),
				Size = UDim2.fromOffset(math.floor(size * 0.58), math.floor(size * 0.58)),
				Parent = button,
			})
		else
			visual = Util.New("TextLabel", {
				Name = "Glyph",
				BackgroundTransparency = 1,
				Font = Theme:Font("FontBold"),
				Text = value,
				TextColor3 = Theme.C.Accent,
				TextSize = Scale.f(math.floor(size * 0.42)),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = iconOnly and UDim2.fromScale(0.5, 0.5) or UDim2.new(0, Scale.u(18), 0.5, 0),
				Size = UDim2.fromOffset(math.floor(size * 0.7), math.floor(size * 0.7)),
				Parent = button,
			})
			Theme:Paint(visual, { TextColor3 = "Accent" })
		end

		local text
		if not iconOnly then
			text = Util.New("TextLabel", {
				BackgroundTransparency = 1,
				Font = Theme:Font("FontMedium"),
				Text = tostring(cfg.Name or "Button"),
				TextColor3 = Theme.C.Text,
				TextSize = Scale.f(12),
				TextXAlignment = Enum.TextXAlignment.Left,
				Position = UDim2.fromOffset(Scale.u(34), 0),
				Size = UDim2.new(1, -Scale.u(42), 1, 0),
				Parent = button,
			})
			Theme:Paint(text, { TextColor3 = "Text" })
		end

		control:_hoverable(button, button, "Element", "ElementHover", stroke)
		maid:Give(button.MouseEnter:Connect(function()
			Util.Tween(visual, { Size = UDim2.fromOffset(math.floor(size * 0.66), math.floor(size * 0.66)) }, Util.Motion.Fast)
		end))
		maid:Give(button.MouseLeave:Connect(function()
			Util.Tween(visual, { Size = UDim2.fromOffset(math.floor(size * 0.58), math.floor(size * 0.58)) }, Util.Motion.Fast)
		end))

		maid:Give(button.MouseButton1Click:Connect(function()
			if not control:IsEnabled() then return end
			control:_confirmedClick(function()
				control:_emit(true)
				if cfg.Callback then
					Void.Log:GuardAsync(("ImageButton '%s'"):format(tostring(cfg.Name)), cfg.Callback, control)
				end
			end)
		end))

		control._get = function() return nil end
		control._set = function() end

		function control:SetImage(image)
			local newKind, newValue = Void.Icons:Resolve(image)
			if newKind == "image" and visual:IsA("ImageLabel") then
				visual.Image = newValue
			elseif newKind == "text" and visual:IsA("TextLabel") then
				visual.Text = newValue
			end
			return self
		end

		control._setName = function(name)
			if text then text.Text = name end
		end

		control:_finalise(holder, button)
		return control
	end
end
