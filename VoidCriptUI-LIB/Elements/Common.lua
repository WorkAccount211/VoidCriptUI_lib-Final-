--[[
	VoidCriptUI · Elements/Common.lua
	Shared building blocks for elements.

	Every element is a row inside a section. Rather than repeating the same
	label/value/hover/accent-line code fifteen times, elements compose these
	helpers. That keeps each element file short and guarantees a consistent
	look: same paddings, same hover timing, same focus ring, same "risky"
	colouring.
]]

return function(Void)
	local Util, Theme, Scale = Void.Util, Void.Theme, Void.Scale

	local Common = {}

	-- ── row shells ──────────────────────────────────────────────────────
	-- A single-line interactive row (toggle, keybind, colour).
	function Common.Row(parent, height, interactive)
		local class = interactive and "TextButton" or "Frame"
		local row = Util.New(class, {
			Name = "Row",
			BackgroundTransparency = 1,
			Text = interactive and "" or nil,
			Size = UDim2.new(1, 0, 0, height or Scale:Metric("Row")),
			AutomaticSize = Enum.AutomaticSize.None,
			Parent = parent,
		})
		return row
	end

	-- A stacked row: label above, control below (slider, dropdown, input).
	function Common.Stack(parent, height)
		local holder = Util.New("Frame", {
			Name = "Stack",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, height or 0),
			AutomaticSize = height and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
			Parent = parent,
		})
		return holder
	end

	-- ── labels ──────────────────────────────────────────────────────────
	function Common.Label(parent, text, opts)
		opts = opts or {}
		local label = Util.New("TextLabel", {
			Name = opts.Name or "Label",
			Font = Theme:Font(opts.Font or "Font"),
			Text = tostring(text or ""),
			TextColor3 = Theme.C[opts.Token or "TextDim"],
			TextSize = Scale.f(opts.Size or 12),
			TextXAlignment = opts.Align or Enum.TextXAlignment.Left,
			TextTruncate = opts.Truncate ~= false and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None,
			TextWrapped = opts.Wrapped or false,
			RichText = opts.RichText or false,
			Position = opts.Position or UDim2.fromOffset(0, 0),
			Size = opts.Size2 or UDim2.new(1, 0, 1, 0),
			AnchorPoint = opts.Anchor or Vector2.new(0, 0),
			LayoutOrder = opts.LayoutOrder,
			Parent = parent,
		})
		Theme:Paint(label, { TextColor3 = opts.Token or "TextDim" })
		return label
	end

	-- The little accent value chip on the right of a row ("120", "MB2", "on").
	function Common.Chip(parent, text, opts)
		opts = opts or {}
		local chip = Util.New(opts.Interactive and "TextButton" or "TextLabel", {
			Name = opts.Name or "Chip",
			BackgroundColor3 = Theme.C[opts.Background or "Element"],
			BackgroundTransparency = opts.Transparent and 1 or 0,
			Font = Theme:Font("FontMedium"),
			Text = tostring(text or ""),
			TextColor3 = Theme.C[opts.Token or "Accent"],
			TextSize = Scale.f(opts.FontSize or 11),
			AutomaticSize = Enum.AutomaticSize.X,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(0, 0, 0, Scale.u(opts.Height or 18)),
			Parent = parent,
		}, {
			Util.New("UIPadding", {
				PaddingLeft = UDim.new(0, Scale.u(8)),
				PaddingRight = UDim.new(0, Scale.u(8)),
			}),
		})
		Theme:Paint(chip, {
			TextColor3 = opts.Token or "Accent",
			BackgroundColor3 = opts.Background or "Element",
		})
		if not opts.Transparent then
			Util.Corner(chip, Theme.Style.RadiusSmall)
			local stroke = Util.Stroke(chip, Theme.C.OutlineSoft)
			Theme:Paint(stroke, { Color = "OutlineSoft" })
			chip:SetAttribute("HasStroke", true)
			return chip, stroke
		end
		return chip
	end

	-- ── framed control surfaces (dropdown button, textbox, list) ────────
	function Common.Surface(parent, height, opts)
		opts = opts or {}
		local surface = Util.New(opts.Class or "Frame", {
			Name = opts.Name or "Surface",
			BackgroundColor3 = Theme.C[opts.Token or "Element"],
			Text = (opts.Class == "TextButton") and "" or nil,
			Position = opts.Position or UDim2.fromOffset(0, 0),
			Size = opts.Size or UDim2.new(1, 0, 0, height),
			AutomaticSize = opts.AutomaticSize,
			ClipsDescendants = opts.Clip,
			Parent = parent,
		})
		Theme:Paint(surface, { BackgroundColor3 = opts.Token or "Element" })
		Util.Corner(surface, opts.Radius or Theme.Style.RadiusSmall)
		local stroke = Util.Stroke(surface, Theme.C.OutlineSoft)
		Theme:Paint(stroke, { Color = "OutlineSoft" })
		return surface, stroke
	end

	-- ── the accent indicator line for active elements ───────────────────
	-- A 2px accent bar that slides in on the left edge. Used to highlight the
	-- focused input / open dropdown / active row.
	function Common.AccentLine(parent, opts)
		opts = opts or {}
		local line = Util.New("Frame", {
			Name = "AccentLine",
			BackgroundColor3 = Theme.C.Accent,
			BorderSizePixel = 0,
			AnchorPoint = opts.Anchor or Vector2.new(0, 0.5),
			Position = opts.Position or UDim2.new(0, -Scale.u(6), 0.5, 0),
			Size = UDim2.fromOffset(2, 0),
			ZIndex = (parent.ZIndex or 1) + 1,
			Parent = parent,
		})
		Theme:Paint(line, { BackgroundColor3 = "Accent" })
		Util.Corner(line, 1)

		local height = opts.Height
		return {
			Instance = line,
			Show = function()
				local target = height or parent.AbsoluteSize.Y
				Util.Tween(line, { Size = UDim2.fromOffset(2, math.max(target - Scale.u(4), 8)) }, Util.Motion.Normal, Enum.EasingStyle.Quint)
			end,
			Hide = function()
				Util.Tween(line, { Size = UDim2.fromOffset(2, 0) }, Util.Motion.Fast)
			end,
		}
	end

	-- ── numeric text entry shared by slider / range slider / knob ───────
	-- Turns a value chip into an editable box on click (roadmap #4).
	function Common.EditableValue(chip, opts)
		opts = opts or {}
		local box = Util.New("TextBox", {
			Name = "Editor",
			BackgroundColor3 = Theme.C.ElementActive,
			Font = Theme:Font("FontMedium"),
			Text = "",
			TextColor3 = Theme.C.Text,
			TextSize = Scale.f(11),
			TextXAlignment = Enum.TextXAlignment.Center,
			ClearTextOnFocus = true,
			Visible = false,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(Scale.u(opts.Width or 58), Scale.u(18)),
			ZIndex = 5,
			Parent = chip.Parent,
		})
		Theme:Paint(box, { BackgroundColor3 = "ElementActive", TextColor3 = "Text" })
		Util.Corner(box, Theme.Style.RadiusSmall)
		local stroke = Util.Stroke(box, Theme.C.Accent)
		Theme:Paint(stroke, { Color = "Accent" })

		local api = {}

		function api.Open(currentText)
			box.Text = tostring(currentText or "")
			box.Visible = true
			chip.Visible = false
			box:CaptureFocus()
		end

		function api.Close()
			box.Visible = false
			chip.Visible = true
		end

		box.FocusLost:Connect(function(enter)
			api.Close()
			if enter and opts.OnCommit then
				opts.OnCommit(box.Text)
			end
		end)

		api.Box = box
		return api
	end

	-- ── checkbox visual shared by toggle / listbox / multi-dropdown ─────
	function Common.Checkbox(parent, opts)
		opts = opts or {}
		local size = Scale.u(opts.Size or Scale.M.Checkbox)
		local box = Util.New("Frame", {
			Name = "Checkbox",
			BackgroundColor3 = Theme.C.Element,
			AnchorPoint = opts.Anchor or Vector2.new(0, 0.5),
			Position = opts.Position or UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(size, size),
			Parent = parent,
		})
		Theme:Paint(box, { BackgroundColor3 = "Element" })
		Util.Corner(box, math.max(2, math.floor(size / 5)))
		local stroke = Util.Stroke(box, Theme.C.Outline)

		-- the tick: an icon glyph that scales in
		local tick = Util.New("TextLabel", {
			Name = "Tick",
			Font = Theme:Font("FontBold"),
			Text = opts.Glyph or "✔",
			TextColor3 = Theme.C.TextOnAccent,
			TextSize = Scale.f(size * 0.72),
			TextTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Parent = box,
		})
		local tickScale = Util.New("UIScale", { Scale = 0.4, Parent = tick })

		local api = { Instance = box, Stroke = stroke, Tick = tick }

		function api.Set(state, instant)
			local dur = instant and 0 or Util.Motion.Normal
			Util.Tween(box, { BackgroundColor3 = state and Theme.C.Accent or Theme.C.Element }, dur)
			Util.Tween(stroke, { Color = state and Theme.C.Accent or Theme.C.Outline }, dur)
			Util.Tween(tick, { TextTransparency = state and 0 or 1 }, dur)
			if instant then
				tickScale.Scale = state and 1 or 0.4
			else
				Util.Tween(tickScale, { Scale = state and 1 or 0.4 }, dur, Enum.EasingStyle.Back)
			end
		end

		function api.Flash()
			Util.Tween(box, { BackgroundColor3 = Theme.C.AccentSoft }, 0.06)
		end

		return api
	end

	-- ── switch visual (iOS-style pill) used by Toggle Style = "Switch" ──
	function Common.Switch(parent, opts)
		opts = opts or {}
		local width = Scale.u(opts.Width or 30)
		local height = Scale.u(opts.Height or 16)

		local track = Util.New("Frame", {
			Name = "Switch",
			BackgroundColor3 = Theme.C.Element,
			AnchorPoint = opts.Anchor or Vector2.new(1, 0.5),
			Position = opts.Position or UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(width, height),
			Parent = parent,
		})
		Theme:Paint(track, { BackgroundColor3 = "Element" })
		Util.Corner(track, 999)
		local stroke = Util.Stroke(track, Theme.C.Outline)

		local knob = Util.New("Frame", {
			Name = "Knob",
			BackgroundColor3 = Theme.C.TextDim,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 2, 0.5, 0),
			Size = UDim2.fromOffset(height - 4, height - 4),
			Parent = track,
		})
		Util.Corner(knob, 999)

		local api = { Instance = track }
		function api.Set(state, instant)
			local dur = instant and 0 or Util.Motion.Normal
			Util.Tween(track, { BackgroundColor3 = state and Theme.C.Accent or Theme.C.Element }, dur)
			Util.Tween(stroke, { Color = state and Theme.C.Accent or Theme.C.Outline }, dur)
			Util.Tween(knob, {
				BackgroundColor3 = state and Theme.C.TextOnAccent or Theme.C.TextDim,
				Position = state and UDim2.new(1, -(height - 2), 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
			}, dur, Enum.EasingStyle.Back)
			if state then knob.AnchorPoint = Vector2.new(1, 0.5) else knob.AnchorPoint = Vector2.new(0, 0.5) end
		end
		function api.Flash() end
		return api
	end

	-- ── slider track shared by Slider / RangeSlider ─────────────────────
	function Common.Track(parent, opts)
		opts = opts or {}
		local height = Scale.u(opts.Height or Scale.M.Track)
		local track = Util.New("Frame", {
			Name = "Track",
			BackgroundColor3 = Theme.C.Element,
			Position = opts.Position or UDim2.new(0, 0, 1, -height),
			Size = UDim2.new(1, 0, 0, height),
			Parent = parent,
		})
		Theme:Paint(track, { BackgroundColor3 = "Element" })
		Util.Corner(track, math.floor(height / 2))
		local stroke = Util.Stroke(track, Theme.C.OutlineSoft)
		Theme:Paint(stroke, { Color = "OutlineSoft" })

		local fill = Util.New("Frame", {
			Name = "Fill",
			BackgroundColor3 = Theme.C.Accent,
			Size = UDim2.fromScale(0, 1),
			Parent = track,
		})
		Theme:Paint(fill, { BackgroundColor3 = "Accent" })
		Util.Corner(fill, math.floor(height / 2))

		-- accent gradient so the fill has depth (CompKiller look)
		Util.New("UIGradient", {
			Color = ColorSequence.new(Theme.C.AccentDark, Theme.C.Accent),
			Rotation = 0,
			Parent = fill,
		})

		local grip = Util.New("Frame", {
			Name = "Grip",
			BackgroundColor3 = Theme.C.Text,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(Scale.u(opts.GripSize or 9), Scale.u(opts.GripSize or 9)),
			ZIndex = 3,
			Visible = opts.Grip ~= false,
			Parent = track,
		})
		Theme:Paint(grip, { BackgroundColor3 = "Text" })
		Util.Corner(grip, 999)
		local gripStroke = Util.Stroke(grip, Theme.C.Background, 2)

		return {
			Track = track,
			Fill = fill,
			Grip = grip,
			GripStroke = gripStroke,
			Stroke = stroke,
			Height = height,
		}
	end

	-- ── section-level hover highlight (subtle row background) ───────────
	function Common.RowHighlight(row, maid)
		local highlight = Util.New("Frame", {
			Name = "Highlight",
			BackgroundColor3 = Theme.C.ElementHover,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(-Scale.u(6), 0),
			Size = UDim2.new(1, Scale.u(12), 1, 0),
			ZIndex = 0,
			Parent = row,
		})
		Util.Corner(highlight, Theme.Style.RadiusSmall)
		Theme:Paint(highlight, { BackgroundColor3 = "ElementHover" })

		maid:Give(row.MouseEnter:Connect(function()
			Util.Tween(highlight, { BackgroundTransparency = 0.55 }, Util.Motion.Fast)
		end))
		maid:Give(row.MouseLeave:Connect(function()
			Util.Tween(highlight, { BackgroundTransparency = 1 }, Util.Motion.Fast)
		end))
		return highlight
	end

	-- ── "risky" marker: a small warning dot next to the name ────────────
	function Common.RiskyMarker(parent, xOffset)
		local dot = Util.New("TextLabel", {
			Name = "Risky",
			Font = Theme:Font("FontBold"),
			Text = "⚠",
			TextColor3 = Theme.C.Risky,
			TextSize = Scale.f(11),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, xOffset or 0, 0.5, 0),
			Size = UDim2.fromOffset(Scale.u(12), Scale.u(12)),
			Parent = parent,
		})
		Theme:Paint(dot, { TextColor3 = "Risky" })
		return dot
	end

	-- ── popup layer (dropdown lists, colour pickers) ────────────────────
	-- Popups are parented to the window's overlay layer, not the section, so
	-- they are never clipped by the ScrollingFrame and always draw on top.
	function Common.Popup(ctx, anchorInstance, size, opts)
		opts = opts or {}
		local overlay = ctx.Window and ctx.Window._overlay
		if not overlay then
			Void.Log:Warn("popup requested without a window overlay; falling back to inline")
			overlay = anchorInstance.Parent
		end

		local canvas = Util.New("CanvasGroup", {
			Name = "Popup",
			BackgroundTransparency = 1,
			GroupTransparency = 1,
			Size = size,
			Visible = false,
			ZIndex = opts.ZIndex or 50,
			Parent = overlay,
		})

		local card = Util.New("Frame", {
			Name = "Card",
			BackgroundColor3 = Theme.C.Overlay,
			Size = UDim2.fromScale(1, 1),
			AutomaticSize = opts.AutomaticSize,
			Parent = canvas,
		})
		Theme:Paint(card, { BackgroundColor3 = "Overlay" })
		Util.Corner(card, Theme.Style.RadiusSmall + 1)
		local stroke = Util.Stroke(card, Theme.C.OutlineStrong)
		Theme:Paint(stroke, { Color = "OutlineStrong" })
		Util.Shadow(card, Scale.u(34), 0.55)

		local scaler = Util.New("UIScale", { Scale = 0.96, Parent = canvas })

		local api = { Canvas = canvas, Card = card, Open = false }

		function api.Reposition()
			if not anchorInstance.Parent then return end
			local anchorPos = anchorInstance.AbsolutePosition
			local anchorSize = anchorInstance.AbsoluteSize
			local overlayPos = overlay.AbsolutePosition
			local viewport = Util.Viewport()
			local popupHeight = canvas.AbsoluteSize.Y > 0 and canvas.AbsoluteSize.Y or size.Y.Offset

			local x = anchorPos.X - overlayPos.X
			local y = anchorPos.Y - overlayPos.Y + anchorSize.Y + Scale.u(4)

			-- flip above the anchor when there is no room below
			if anchorPos.Y + anchorSize.Y + popupHeight > viewport.Y - Scale.u(10) then
				y = anchorPos.Y - overlayPos.Y - popupHeight - Scale.u(4)
			end

			canvas.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
			if opts.MatchWidth ~= false then
				canvas.Size = UDim2.fromOffset(anchorSize.X, size.Y.Offset)
			end
		end

		function api.Show()
			api.Open = true
			api.Reposition()
			canvas.Visible = true
			scaler.Scale = 0.96
			Util.Tween(canvas, { GroupTransparency = 0 }, Util.Motion.Normal)
			Util.Tween(scaler, { Scale = 1 }, Util.Motion.Normal, Enum.EasingStyle.Back)
			if ctx.Window and ctx.Window._registerPopup then
				ctx.Window:_registerPopup(api)
			end
		end

		function api.Hide()
			if not api.Open then return end
			api.Open = false
			Util.Tween(canvas, { GroupTransparency = 1 }, Util.Motion.Fast)
			Util.Tween(scaler, { Scale = 0.97 }, Util.Motion.Fast)
			task.delay(Util.Motion.Fast + 0.03, function()
				if not api.Open and canvas.Parent then canvas.Visible = false end
			end)
		end

		function api.Toggle()
			if api.Open then api.Hide() else api.Show() end
			return api.Open
		end

		function api.Destroy()
			canvas:Destroy()
		end

		return api
	end

	Void.Common = Common
	return Common
end
