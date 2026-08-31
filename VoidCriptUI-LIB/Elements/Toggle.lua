--[[
	VoidCriptUI · Elements/Toggle.lua

		Section:CreateToggle({
			Name = "Fly",
			Flag = "Fly_Toggle",
			CurrentValue = false,
			Style = "Checkbox",        -- Checkbox | Switch
			Icon = "bolt",             -- optional icon instead of/next to text
			Tooltip = "Enables flight",
			Risky = false,             -- shows a ⚠ marker and asks for confirmation
			Keybind = "F",             -- inline keybind that flips the toggle (#6)
			KeybindMode = "Toggle",
			Color = Color3...,         -- inline colour picker on the same row (#7)
			Callback = function(value) end,
		})

	Registers itself in `Void.Elements.Toggle`.
]]

return function(Void)
	local Util, Theme, Scale, Common = Void.Util, Void.Theme, Void.Scale, Void.Common

	Void.Elements.Toggle = function(ctx, cfg)
		cfg = cfg or {}
		local control = Void.Control.new("Toggle", cfg, ctx)
		local maid = control:GetMaid()
		local state = cfg.CurrentValue or cfg.Default or false

		local row = Common.Row(ctx.Parent, Scale:Metric("Row"), true)
		Common.RowHighlight(row, maid)

		local style = (cfg.Style == "Switch") and "Switch" or "Checkbox"
		local widget
		local textLeft, textRight = 0, 0

		if style == "Switch" then
			widget = Common.Switch(row)
			textRight = Scale.u(38)
		else
			widget = Common.Checkbox(row, { Glyph = cfg.CheckGlyph })
			textLeft = Scale.u(Scale.M.Checkbox + 8)
		end

		-- optional leading icon
		if cfg.Icon then
			local kind, value = Void.Icons:Resolve(cfg.Icon)
			if kind == "image" then
				local img = Util.New("ImageLabel", {
					Image = value,
					ImageColor3 = Theme.C.TextDim,
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, textLeft, 0.5, 0),
					Size = UDim2.fromOffset(Scale.u(13), Scale.u(13)),
					Parent = row,
				})
				Theme:Paint(img, { ImageColor3 = "TextDim" })
				control._icon = img
			else
				local glyph = Util.New("TextLabel", {
					Font = Theme:Font("Font"),
					Text = value,
					TextColor3 = Theme.C.TextDim,
					TextSize = Scale.f(12),
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, textLeft, 0.5, 0),
					Size = UDim2.fromOffset(Scale.u(14), Scale.u(14)),
					Parent = row,
				})
				Theme:Paint(glyph, { TextColor3 = "TextDim" })
				control._icon = glyph
			end
			textLeft = textLeft + Scale.u(18)
		end

		if control.Risky then
			Common.RiskyMarker(row, textLeft)
			textLeft = textLeft + Scale.u(15)
		end

		local label = Common.Label(row, cfg.Name or "Toggle", {
			Token = "TextDim",
			Position = UDim2.fromOffset(textLeft, 0),
			Size2 = UDim2.new(1, -textLeft - textRight, 1, 0),
		})

		-- ── inline extras: keybind (#6) and colour picker (#7) ───────────
		local inlineRight = textRight
		local inlineKeybind, inlineColor

		if cfg.Color ~= nil then
			inlineColor = Void.Elements.ColorPicker({
				Window = ctx.Window, Tab = ctx.Tab, Section = ctx.Section,
				Parent = row, Maid = maid, Inline = true,
			}, {
				Name = (cfg.Name or "Toggle") .. " colour",
				Flag = cfg.ColorFlag,
				Color = cfg.Color,
				Alpha = cfg.Alpha,
				Inline = true,
				InlineOffset = inlineRight,
				Callback = cfg.ColorCallback,
				Searchable = false,
			})
			inlineRight = inlineRight + Scale.u(38)
			label.Size = UDim2.new(1, -textLeft - inlineRight, 1, 0)
		end

		if cfg.Keybind ~= nil then
			inlineKeybind = Void.Elements.Keybind({
				Window = ctx.Window, Tab = ctx.Tab, Section = ctx.Section,
				Parent = row, Maid = maid, Inline = true,
			}, {
				Name = cfg.Name or "Toggle",
				Flag = cfg.KeybindFlag,
				CurrentKeybind = cfg.Keybind,
				Mode = cfg.KeybindMode or "Toggle",
				Inline = true,
				InlineOffset = inlineRight,
				Searchable = false,
				Callback = function() end,
			})
			inlineRight = inlineRight + Scale.u(52)
			label.Size = UDim2.new(1, -textLeft - inlineRight, 1, 0)
		end

		-- ── state application ───────────────────────────────────────────
		local function apply(value, fire, instant)
			state = value and true or false
			widget.Set(state, instant)
			Util.Tween(label, { TextColor3 = state and Theme.C.Text or Theme.C.TextDim }, instant and 0 or Util.Motion.Normal)
			if control._icon then
				local prop = control._icon:IsA("ImageLabel") and "ImageColor3" or "TextColor3"
				Util.Tween(control._icon, { [prop] = state and Theme.C.Accent or Theme.C.TextDim }, instant and 0 or Util.Motion.Normal)
			end
			if fire then control:_emit(state) end
		end

		control._get = function() return state end
		control._raw = function() return state end
		control._set = function(value, fire) apply(value, fire, false) end

		local function flip()
			if not control:IsEnabled() then return end
			if control.Risky and not state then
				-- only confirm when turning a risky feature ON
				control:_confirmedClick(function() apply(true, true) end)
				return
			end
			widget.Flash()
			apply(not state, true)
		end

		maid:Give(row.MouseButton1Click:Connect(flip))

		-- inline keybind flips the toggle
		if inlineKeybind then
			inlineKeybind._bind.OnPress = function(bind)
				if bind.Mode == "Hold" then return end
				flip()
			end
			inlineKeybind._bind.OnState = function(bindState)
				if inlineKeybind._bind.Mode == "Hold" then
					apply(bindState, true)
				end
			end
			inlineKeybind._bind.Name = cfg.Name or "Toggle"
			inlineKeybind._bind.Control = control
		end

		control:_finalise(row, row)
		control.InlineKeybind = inlineKeybind
		control.InlineColorPicker = inlineColor

		-- initial paint without firing the callback, then fire once if ON
		apply(state, false, true)
		if state and cfg.Callback and cfg.FireOnStart ~= false then
			Void.Log:GuardAsync(("Toggle '%s' initial"):format(tostring(cfg.Name)), cfg.Callback, true, control)
		end

		return control
	end
end
