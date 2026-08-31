--[[
	VoidCriptUI · Elements/Keybind.lua
	Full keybind picker with modifiers, mouse buttons and modes
	(roadmap #5, #42).

		Section:CreateKeybind({
			Name = "Aim assist",
			Flag = "aim_key",
			CurrentKeybind = "MB2",       -- "Ctrl+F" | "MB2" | Enum.KeyCode.F
			Mode = "Hold",                -- Always | Toggle | Hold
			ModeSelectable = true,        -- click the mode chip to cycle it
			Category = "Combat",          -- shown in the keylist
			ShowInKeylist = true,
			Callback = function(state) end,   -- Toggle/Hold: boolean; Always: nil
		})

	Press the chip, then hit any key or mouse button. Hold Ctrl/Shift/Alt while
	pressing to record a combo. Escape cancels, Backspace clears the bind.
]]

return function(Void)
	local Util, Theme, Scale, Common = Void.Util, Void.Theme, Void.Scale, Void.Common

	local MODES = { "Always", "Toggle", "Hold" }

	Void.Elements.Keybind = function(ctx, cfg)
		cfg = cfg or {}
		local control = Void.Control.new("Keybind", cfg, ctx)
		local maid = control:GetMaid()

		local descriptor = Void.Keybinds.Descriptor(cfg.CurrentKeybind or cfg.Default or cfg.Key)
		local mode = cfg.Mode or (cfg.HoldToInteract and "Hold") or "Always"
		if not table.find(MODES, mode) then
			Void.Log:Warn("keybind '%s': unknown mode '%s', using Always", tostring(cfg.Name), tostring(mode))
			mode = "Always"
		end

		local inline = cfg.Inline == true
		local row, label

		if inline then
			row = ctx.Parent
		else
			row = Common.Row(ctx.Parent, Scale:Metric("Row"), false)
			Common.RowHighlight(row, maid)
			label = Common.Label(row, cfg.Name or "Keybind", {
				Token = "TextDim",
				Size2 = UDim2.new(1, -Scale.u(110), 1, 0),
			})
		end

		local rightOffset = inline and (cfg.InlineOffset or 0) or 0

		-- mode chip (Always / Toggle / Hold)
		local modeChip
		if not inline and cfg.ModeSelectable ~= false then
			modeChip = Util.New("TextButton", {
				Name = "Mode",
				BackgroundColor3 = Theme.C.Element,
				Font = Theme:Font("Font"),
				Text = mode:lower(),
				TextColor3 = Theme.C.TextDim,
				TextSize = Scale.f(10),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -Scale.u(56) - rightOffset, 0.5, 0),
				Size = UDim2.fromOffset(Scale.u(46), Scale.u(16)),
				Parent = row,
			})
			Theme:Paint(modeChip, { BackgroundColor3 = "Element", TextColor3 = "TextDim" })
			Util.Corner(modeChip, Theme.Style.RadiusSmall)
			Util.Stroke(modeChip, Theme.C.OutlineSoft)
			Void.Tooltip:Attach(modeChip, "Click to change the trigger mode: **always** fires on press, **toggle** flips a state, **hold** stays on while held", maid)
		end

		local keyChip = Util.New("TextButton", {
			Name = "Key",
			BackgroundColor3 = Theme.C.Element,
			Font = Theme:Font("FontMedium"),
			Text = Void.Keybinds.Label(descriptor),
			TextColor3 = Theme.C.Accent,
			TextSize = Scale.f(11),
			AutomaticSize = Enum.AutomaticSize.X,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -rightOffset, 0.5, 0),
			Size = UDim2.fromOffset(Scale.u(44), Scale.touch(18)),
			Parent = row,
		}, {
			Util.New("UIPadding", { PaddingLeft = UDim.new(0, Scale.u(9)), PaddingRight = UDim.new(0, Scale.u(9)) }),
			Util.New("UISizeConstraint", { MinSize = Vector2.new(Scale.u(44), 0) }),
		})
		Theme:Paint(keyChip, { BackgroundColor3 = "Element", TextColor3 = "Accent" })
		Util.Corner(keyChip, Theme.Style.RadiusSmall)
		local chipStroke = Util.Stroke(keyChip, Theme.C.OutlineSoft)
		Theme:Paint(chipStroke, { Color = "OutlineSoft" })

		-- ── the bind entry in the central manager ───────────────────────
		local bind = Void.Keybinds:Register({
			Name = cfg.Name or "Keybind",
			Descriptor = descriptor,
			Mode = mode,
			Control = control,
			Category = cfg.Category,
			ShowInKeylist = cfg.ShowInKeylist ~= false,
			OnPress = function(entry)
				if entry.Mode == "Always" then
					control:_emit(true)
				end
			end,
			OnState = function(state)
				control:_emit(state)
			end,
		})
		control._bind = bind
		maid:Give(function() Void.Keybinds:Remove(bind) end)

		local function refreshChip()
			keyChip.Text = Void.Keybinds.Label(bind.Descriptor)
			if modeChip then modeChip.Text = bind.Mode:lower() end
		end

		-- ── capture ─────────────────────────────────────────────────────
		local listening = false

		local function beginCapture()
			if not control:IsEnabled() then return end
			listening = true
			keyChip.Text = "press…"
			Util.Tween(chipStroke, { Color = Theme.C.Accent }, Util.Motion.Fast)
			Util.Tween(keyChip, { BackgroundColor3 = Theme.C.ElementActive }, Util.Motion.Fast)

			Void.Keybinds:BeginCapture(function(newDescriptor, action)
				listening = false
				Util.Tween(chipStroke, { Color = Theme.C.OutlineSoft }, Util.Motion.Fast)
				Util.Tween(keyChip, { BackgroundColor3 = Theme.C.Element }, Util.Motion.Fast)

				if action == "cancel" then
					refreshChip()
					return
				end
				if action == "clear" then
					bind.Descriptor = nil
					descriptor = nil
					refreshChip()
					control:_emit(nil)
					return
				end
				bind.Descriptor = newDescriptor
				descriptor = newDescriptor
				refreshChip()
				Void.Log:Debug("keybind '%s' set to %s", tostring(cfg.Name), Void.Keybinds.Label(newDescriptor))
				if control.Flag then Void.Flags:Fire(control.Flag, newDescriptor) end
				if ctx.Window and ctx.Window._requestAutoSave then ctx.Window._requestAutoSave() end
			end)
		end

		maid:Give(keyChip.MouseButton1Click:Connect(beginCapture))
		maid:Give(keyChip.MouseEnter:Connect(function()
			if listening then return end
			Util.Tween(keyChip, { BackgroundColor3 = Theme.C.ElementHover }, Util.Motion.Fast)
			Util.Tween(chipStroke, { Color = Theme.C.OutlineStrong }, Util.Motion.Fast)
		end))
		maid:Give(keyChip.MouseLeave:Connect(function()
			if listening then return end
			Util.Tween(keyChip, { BackgroundColor3 = Theme.C.Element }, Util.Motion.Fast)
			Util.Tween(chipStroke, { Color = Theme.C.OutlineSoft }, Util.Motion.Fast)
		end))

		if modeChip then
			maid:Give(modeChip.MouseButton1Click:Connect(function()
				if not control:IsEnabled() then return end
				local index = table.find(MODES, bind.Mode) or 1
				bind.Mode = MODES[(index % #MODES) + 1]
				bind.State = false
				refreshChip()
				Void.Keybinds:_notify()
				if ctx.Window and ctx.Window._requestAutoSave then ctx.Window._requestAutoSave() end
			end))
			maid:Give(modeChip.MouseEnter:Connect(function()
				Util.Tween(modeChip, { BackgroundColor3 = Theme.C.ElementHover, TextColor3 = Theme.C.Text }, Util.Motion.Fast)
			end))
			maid:Give(modeChip.MouseLeave:Connect(function()
				Util.Tween(modeChip, { BackgroundColor3 = Theme.C.Element, TextColor3 = Theme.C.TextDim }, Util.Motion.Fast)
			end))
		end

		-- ── control API ─────────────────────────────────────────────────
		control._get = function() return bind.Descriptor end
		control._raw = function() return bind.Descriptor end
		control._set = function(value, fire)
			bind.Descriptor = Void.Keybinds.Descriptor(value)
			descriptor = bind.Descriptor
			refreshChip()
			Void.Keybinds:_notify()
			if fire then control:_emit(bind.Descriptor) end
		end

		function control:GetLabel()
			return Void.Keybinds.Label(bind.Descriptor)
		end
		function control:SetMode(newMode)
			if table.find(MODES, newMode) then
				bind.Mode = newMode
				refreshChip()
				Void.Keybinds:_notify()
			end
			return self
		end
		function control:GetMode() return bind.Mode end
		function control:GetState() return bind.State end
		function control:IsHeld() return bind.State == true end

		control._setName = function(name)
			bind.Name = name
			if label then label.Text = name end
		end

		control:_finalise(inline and keyChip or row, keyChip)
		return control
	end

	Void.Elements.Bind = Void.Elements.Keybind
end
