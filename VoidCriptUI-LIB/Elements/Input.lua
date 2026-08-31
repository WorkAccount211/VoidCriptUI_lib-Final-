--[[
	VoidCriptUI · Elements/Input.lua
	Text input with validation (roadmap #34).

		Section:CreateInput({
			Name = "Webhook URL",
			Flag = "webhook",
			PlaceholderText = "https://…",
			CurrentValue = "",
			Numeric = false,          -- digits only
			MaxLength = 200,
			Pattern = "^https://",    -- Lua pattern the value must match
			Validate = function(text)  -- or a custom validator
				return #text > 3, "Too short"
			end,
			ClearOnFocus = false,
			FireOnEnterOnly = false,  -- default: fire on focus lost too
			Multiline = false,
			Callback = function(text) end,
		})

	Invalid values paint the outline red, show the reason under the box, and are
	NOT committed — the callback only receives values that passed validation.
]]

return function(Void)
	local Util, Theme, Scale, Common = Void.Util, Void.Theme, Void.Scale, Void.Common

	Void.Elements.Input = function(ctx, cfg)
		cfg = cfg or {}
		local control = Void.Control.new("Input", cfg, ctx)
		local maid = control:GetMaid()

		local value = tostring(cfg.CurrentValue or cfg.Default or "")

		local holder = Common.Stack(ctx.Parent, nil)
		holder.AutomaticSize = Enum.AutomaticSize.Y

		local label = Common.Label(holder, cfg.Name or "Input", {
			Token = "TextDim",
			Size2 = UDim2.new(1, 0, 0, Scale.u(14)),
		})

		local boxHeight = cfg.Multiline and Scale.touch(52) or Scale.touch(24)
		local box = Util.New("TextBox", {
			Name = "Box",
			BackgroundColor3 = Theme.C.Element,
			Font = Theme:Font("Font"),
			PlaceholderText = tostring(cfg.PlaceholderText or cfg.Placeholder or ""),
			PlaceholderColor3 = Theme.C.TextDark,
			Text = value,
			TextColor3 = Theme.C.Text,
			TextSize = Scale.f(12),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = cfg.Multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
			MultiLine = cfg.Multiline or false,
			TextWrapped = cfg.Multiline or false,
			ClearTextOnFocus = cfg.ClearOnFocus or false,
			Position = UDim2.fromOffset(0, Scale.u(17)),
			Size = UDim2.new(1, 0, 0, boxHeight),
			Parent = holder,
		}, {
			Util.New("UIPadding", {
				PaddingLeft = UDim.new(0, Scale.u(9)), PaddingRight = UDim.new(0, Scale.u(9)),
				PaddingTop = UDim.new(0, cfg.Multiline and Scale.u(6) or 0),
			}),
		})
		Theme:Paint(box, { BackgroundColor3 = "Element", TextColor3 = "Text", PlaceholderColor3 = "TextDark" })
		Util.Corner(box, Theme.Style.RadiusSmall)
		local stroke = Util.Stroke(box, Theme.C.OutlineSoft)
		Theme:Paint(stroke, { Color = "OutlineSoft" })

		holder.Size = UDim2.new(1, 0, 0, Scale.u(17) + boxHeight)

		-- accent line on the left while focused
		local accentLine = Common.AccentLine(box, { Height = boxHeight - Scale.u(6) })

		-- validation message
		local errorLabel = Common.Label(holder, "", {
			Token = "Danger",
			Size = 11,
			Position = UDim2.fromOffset(0, Scale.u(17) + boxHeight + Scale.u(2)),
			Size2 = UDim2.new(1, 0, 0, Scale.u(13)),
		})
		errorLabel.Visible = false

		-- character counter for MaxLength
		local counter
		if cfg.MaxLength then
			counter = Common.Label(holder, "", {
				Token = "TextDark",
				Size = 10,
				Align = Enum.TextXAlignment.Right,
				Size2 = UDim2.new(1, 0, 0, Scale.u(14)),
			})
		end

		-- ── validation ──────────────────────────────────────────────────
		local function validate(text)
			if cfg.MaxLength and #text > cfg.MaxLength then
				return false, ("Max %d characters"):format(cfg.MaxLength)
			end
			if cfg.MinLength and #text < cfg.MinLength then
				return false, ("At least %d characters"):format(cfg.MinLength)
			end
			if cfg.Numeric then
				local number = tonumber(text)
				if text ~= "" and number == nil then
					return false, "Numbers only"
				end
				if number and cfg.Min and number < cfg.Min then
					return false, ("Minimum is %s"):format(tostring(cfg.Min))
				end
				if number and cfg.Max and number > cfg.Max then
					return false, ("Maximum is %s"):format(tostring(cfg.Max))
				end
			end
			if cfg.Pattern and text ~= "" and not text:match(cfg.Pattern) then
				return false, cfg.PatternMessage or "Wrong format"
			end
			if type(cfg.Validate) == "function" then
				local ok, result, message = pcall(cfg.Validate, text)
				if not ok then
					Void.Log:Error("input '%s' validator errored: %s", tostring(cfg.Name), tostring(result))
					return true
				end
				if not result then
					return false, message or "Invalid value"
				end
			end
			return true
		end

		local function showError(message)
			errorLabel.Text = message or ""
			errorLabel.Visible = message ~= nil
			holder.Size = UDim2.new(1, 0, 0, Scale.u(17) + boxHeight + (message and Scale.u(15) or 0))
			Util.Tween(stroke, { Color = message and Theme.C.Danger or Theme.C.OutlineSoft }, Util.Motion.Fast)
		end

		local function updateCounter()
			if not counter then return end
			counter.Text = ("%d/%d"):format(#box.Text, cfg.MaxLength)
			counter.TextColor3 = #box.Text > cfg.MaxLength and Theme.C.Danger or Theme.C.TextDark
		end

		-- ── live filtering for numeric inputs ───────────────────────────
		if cfg.Numeric then
			maid:Give(box:GetPropertyChangedSignal("Text"):Connect(function()
				local filtered = box.Text:gsub("[^%-%d%.]", "")
				if filtered ~= box.Text then box.Text = filtered end
				updateCounter()
			end))
		elseif counter then
			maid:Give(box:GetPropertyChangedSignal("Text"):Connect(updateCounter))
		end

		-- ── focus visuals ───────────────────────────────────────────────
		maid:Give(box.Focused:Connect(function()
			control:_focusRing(stroke, true)
			accentLine.Show()
		end))

		local function commit(enterPressed)
			local text = box.Text
			local ok, message = validate(text)
			if not ok then
				showError(message)
				Void.Log:Debug("input '%s' rejected: %s", tostring(cfg.Name), tostring(message))
				return false
			end
			showError(nil)
			value = text
			control:_emit(cfg.Numeric and (tonumber(text) or 0) or text)
			if cfg.RemoveTextAfterFocusLost or cfg.ClearAfterCommit then
				box.Text = ""
			end
			return true
		end

		maid:Give(box.FocusLost:Connect(function(enterPressed)
			control:_focusRing(stroke, false)
			accentLine.Hide()
			if cfg.FireOnEnterOnly and not enterPressed then
				box.Text = value
				showError(nil)
				return
			end
			commit(enterPressed)
		end))

		control._get = function()
			return cfg.Numeric and (tonumber(value) or 0) or value
		end
		control._raw = function() return value end
		control._set = function(newValue, fire)
			value = tostring(newValue == nil and "" or newValue)
			box.Text = value
			showError(nil)
			updateCounter()
			if fire then control:_emit(control._get()) end
		end

		control._setName = function(name) label.Text = name end
		control._setEnabled = function(enabled)
			box.TextEditable = enabled
			box.TextTransparency = enabled and 0 or 0.5
			label.TextTransparency = enabled and 0 or 0.5
		end

		function control:Validate()
			return validate(box.Text)
		end

		function control:Focus()
			pcall(function() box:CaptureFocus() end)
			return self
		end

		control:_finalise(holder, box)
		updateCounter()
		return control
	end

	Void.Elements.Textbox = Void.Elements.Input
end
