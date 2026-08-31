--[[
	VoidCriptUI · Elements/Display.lua
	Non-interactive and semi-interactive display elements:

		Section:CreateLabel({ Name = "Status: idle", Icon = "info" })
		Section:CreateParagraph({ Title = "Notes", Content = "**bold** `code`" })
		Section:CreateDivider("optional caption")
		Section:CreateProgressBar({ Name = "Download", Value = 0.4 })
		Section:CreateImage({ Image = 1234567, Height = 120, Caption = "preview" })
		Section:CreateCollapsible({ Name = "Advanced", Open = false })  -- returns a sub-section

	Paragraph and Label both run their text through the RichText parser, so
	**bold**, *italic*, `code`, ```blocks```, ~~strike~~, ||spoiler||,
	[coloured](Accent), # headings, > quotes and - bullets all work.
]]

return function(Void)
	local Util, Theme, Scale, Common = Void.Util, Void.Theme, Void.Scale, Void.Common

	-- ── LABEL ───────────────────────────────────────────────────────────
	Void.Elements.Label = function(ctx, cfg)
		if type(cfg) == "string" then cfg = { Name = cfg } end
		cfg = cfg or {}
		local control = Void.Control.new("Label", cfg, ctx)

		local row = Util.New("Frame", {
			Name = "Label",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = ctx.Parent,
		})

		local offset = 0
		if cfg.Icon then
			local kind, value = Void.Icons:Resolve(cfg.Icon)
			if kind == "image" then
				local img = Util.New("ImageLabel", {
					Image = value,
					ImageColor3 = Theme.C[cfg.Color or "TextDim"],
					AnchorPoint = Vector2.new(0, 0),
					Position = UDim2.fromOffset(0, Scale.u(2)),
					Size = UDim2.fromOffset(Scale.u(13), Scale.u(13)),
					Parent = row,
				})
				Theme:Paint(img, { ImageColor3 = cfg.Color or "TextDim" })
			else
				local glyph = Util.New("TextLabel", {
					BackgroundTransparency = 1,
					Font = Theme:Font("Font"),
					Text = value,
					TextColor3 = Theme.C[cfg.Color or "Accent"],
					TextSize = Scale.f(12),
					TextXAlignment = Enum.TextXAlignment.Left,
					Size = UDim2.fromOffset(Scale.u(14), Scale.u(16)),
					Parent = row,
				})
				Theme:Paint(glyph, { TextColor3 = cfg.Color or "Accent" })
			end
			offset = Scale.u(18)
		end

		local label = Util.New("TextLabel", {
			Name = "Text",
			BackgroundTransparency = 1,
			Font = Theme:Font(cfg.Bold and "FontBold" or "Font"),
			Text = Void.RichText.Parse(cfg.Name or cfg.Text or ""),
			RichText = true,
			TextColor3 = Theme.C[cfg.Color or "TextDim"],
			TextSize = Scale.f(cfg.Size or 12),
			TextWrapped = cfg.Wrapped ~= false,
			TextXAlignment = cfg.Align or Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(offset, 0),
			Size = UDim2.new(1, -offset, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = row,
		})
		Theme:Paint(label, { TextColor3 = cfg.Color or "TextDim" })

		control._get = function() return label.Text end
		control._set = function(value)
			label.Text = Void.RichText.Parse(value)
		end
		control._setName = control._set
		function control:SetText(text)
			label.Text = Void.RichText.Parse(text)
			return self
		end
		function control:SetColor(token)
			label.TextColor3 = typeof(token) == "Color3" and token or Theme.C[token]
			return self
		end

		control:_finalise(row, row)
		return control
	end

	-- ── PARAGRAPH ───────────────────────────────────────────────────────
	Void.Elements.Paragraph = function(ctx, cfg)
		cfg = cfg or {}
		local control = Void.Control.new("Paragraph", cfg, ctx)

		local card = Util.New("Frame", {
			Name = "Paragraph",
			BackgroundColor3 = Theme.C.Element,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = ctx.Parent,
		}, {
			Util.New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, Scale.u(4)) }),
			Util.New("UIPadding", {
				PaddingLeft = UDim.new(0, Scale.u(10)), PaddingRight = UDim.new(0, Scale.u(10)),
				PaddingTop = UDim.new(0, Scale.u(9)), PaddingBottom = UDim.new(0, Scale.u(9)),
			}),
		})
		Theme:Paint(card, { BackgroundColor3 = "Element" })
		Util.Corner(card, Theme.Style.RadiusSmall)
		local stroke = Util.Stroke(card, Theme.C.OutlineSoft)
		Theme:Paint(stroke, { Color = "OutlineSoft" })

		-- coloured left bar for "callout" style paragraphs
		if cfg.Style then
			local token = ({ info = "Accent", warning = "Risky", error = "Danger", success = "Success" })[tostring(cfg.Style):lower()] or "Accent"
			local bar = Util.New("Frame", {
				BackgroundColor3 = Theme.C[token],
				Size = UDim2.new(0, 2, 1, 0),
				Parent = card,
			})
			Theme:Paint(bar, { BackgroundColor3 = token })
		end

		local titleLabel
		if cfg.Title then
			titleLabel = Util.New("TextLabel", {
				Name = "Title",
				BackgroundTransparency = 1,
				Font = Theme:Font("FontBold"),
				Text = Void.RichText.Parse(cfg.Title),
				RichText = true,
				TextColor3 = Theme.C.Text,
				TextSize = Scale.f(12),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 1,
				Parent = card,
			})
			Theme:Paint(titleLabel, { TextColor3 = "Text" })
		end

		local bodyLabel = Util.New("TextLabel", {
			Name = "Body",
			BackgroundTransparency = 1,
			Font = Theme:Font("Font"),
			Text = Void.RichText.Parse(cfg.Content or cfg.Text or ""),
			RichText = true,
			TextColor3 = Theme.C.TextDim,
			TextSize = Scale.f(11),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Parent = card,
		})
		Theme:Paint(bodyLabel, { TextColor3 = "TextDim" })

		control._get = function() return bodyLabel.Text end
		control._set = function(value)
			if type(value) == "table" then
				if value.Title and titleLabel then titleLabel.Text = Void.RichText.Parse(value.Title) end
				if value.Content then bodyLabel.Text = Void.RichText.Parse(value.Content) end
			else
				bodyLabel.Text = Void.RichText.Parse(value)
			end
		end

		function control:Set(title, body)
			if type(title) == "table" then
				control._set(title)
				return self
			end
			if title and titleLabel then titleLabel.Text = Void.RichText.Parse(title) end
			if body then bodyLabel.Text = Void.RichText.Parse(body) end
			return self
		end
		function control:SetContent(text)
			bodyLabel.Text = Void.RichText.Parse(text)
			return self
		end

		control:_finalise(card, card)
		return control
	end

	-- ── DIVIDER ─────────────────────────────────────────────────────────
	Void.Elements.Divider = function(ctx, cfg)
		if type(cfg) == "string" then cfg = { Name = cfg } end
		cfg = cfg or {}
		local control = Void.Control.new("Divider", cfg, ctx)

		local caption = cfg.Name or cfg.Text

		if not caption then
			local line = Util.New("Frame", {
				Name = "Divider",
				BackgroundColor3 = Theme.C.OutlineSoft,
				Size = UDim2.new(1, 0, 0, 1),
				Parent = ctx.Parent,
			})
			Theme:Paint(line, { BackgroundColor3 = "OutlineSoft" })
			control:_finalise(line, line)
			control._cfg.Searchable = false
			return control
		end

		local row = Util.New("Frame", {
			Name = "Divider",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, Scale.u(16)),
			Parent = ctx.Parent,
		})
		local label = Util.New("TextLabel", {
			BackgroundTransparency = 1,
			Font = Theme:Font("Font"),
			Text = tostring(caption),
			TextColor3 = Theme.C.TextDark,
			TextSize = Scale.f(10),
			TextXAlignment = Enum.TextXAlignment.Left,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, Scale.u(16)),
			Parent = row,
		})
		Theme:Paint(label, { TextColor3 = "TextDark" })

		local line = Util.New("Frame", {
			BackgroundColor3 = Theme.C.OutlineSoft,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(1, 0, 0, 1),
			Parent = row,
		})
		Theme:Paint(line, { BackgroundColor3 = "OutlineSoft" })

		task.defer(function()
			if label.Parent then
				line.Size = UDim2.new(1, -label.AbsoluteSize.X - Scale.u(8), 0, 1)
			end
		end)

		control:_finalise(row, row)
		return control
	end

	-- ── PROGRESS BAR (roadmap #10) ──────────────────────────────────────
	Void.Elements.ProgressBar = function(ctx, cfg)
		cfg = cfg or {}
		local control = Void.Control.new("ProgressBar", cfg, ctx)

		local value = math.clamp(tonumber(cfg.Value or cfg.CurrentValue or 0) or 0, 0, 1)
		local showPercent = cfg.ShowPercent ~= false

		local holder = Common.Stack(ctx.Parent, Scale:Metric("Row") + Scale.u(10))
		local label = Common.Label(holder, cfg.Name or "Progress", {
			Token = "TextDim",
			Size2 = UDim2.new(0.7, 0, 0, Scale.u(14)),
		})

		local percent = Common.Label(holder, "", {
			Token = "Accent",
			Font = "FontMedium",
			Align = Enum.TextXAlignment.Right,
			Size2 = UDim2.new(0.3, 0, 0, Scale.u(14)),
			Position = UDim2.new(0.7, 0, 0, 0),
		})
		percent.Visible = showPercent

		local barHeight = Scale.u(cfg.Height or 7)
		local track = Util.New("Frame", {
			Name = "Track",
			BackgroundColor3 = Theme.C.Element,
			Position = UDim2.fromOffset(0, Scale.u(19)),
			Size = UDim2.new(1, 0, 0, barHeight),
			Parent = holder,
		})
		Theme:Paint(track, { BackgroundColor3 = "Element" })
		Util.Corner(track, math.floor(barHeight / 2))
		local trackStroke = Util.Stroke(track, Theme.C.OutlineSoft)
		Theme:Paint(trackStroke, { Color = "OutlineSoft" })

		local fill = Util.New("Frame", {
			Name = "Fill",
			BackgroundColor3 = Theme.C[cfg.Color or "Accent"],
			Size = UDim2.fromScale(value, 1),
			Parent = track,
		})
		Theme:Paint(fill, { BackgroundColor3 = cfg.Color or "Accent" })
		Util.Corner(fill, math.floor(barHeight / 2))

		-- moving sheen so an active bar looks alive
		local sheen = Util.New("Frame", {
			Name = "Sheen",
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.78,
			Size = UDim2.fromScale(0.35, 1),
			Parent = fill,
		}, {
			Util.New("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 0.3),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})

		local animating = false
		local function startSheen()
			if animating or cfg.Animated == false then return end
			animating = true
			task.spawn(function()
				while animating and sheen.Parent do
					sheen.Position = UDim2.fromScale(-0.35, 0)
					Util.Tween(sheen, { Position = UDim2.fromScale(1, 0) }, 1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
					task.wait(1.4)
				end
			end)
		end

		local function render(instant)
			local dur = instant and 0 or Util.Motion.Slow
			Util.Tween(fill, { Size = UDim2.fromScale(value, 1) }, dur, Enum.EasingStyle.Quint)
			percent.Text = ("%d%%"):format(math.floor(value * 100 + 0.5))
			if value > 0 and value < 1 then
				startSheen()
			else
				animating = false
			end
		end

		control._get = function() return value end
		control._raw = function() return value end
		control._set = function(newValue, fire)
			value = math.clamp(tonumber(newValue) or 0, 0, 1)
			render(false)
			if fire then control:_emit(value) end
		end

		function control:SetProgress(alpha) control._set(alpha, false) return self end
		function control:SetColor(token)
			Theme:Unpaint(fill)
			fill.BackgroundColor3 = typeof(token) == "Color3" and token or Theme.C[token]
			return self
		end
		function control:SetText(text) label.Text = text return self end
		control._setName = control.SetText

		control:_finalise(holder, holder)
		render(true)
		control._cfg.SaveToConfig = false
		return control
	end

	-- ── IMAGE (roadmap #11) ─────────────────────────────────────────────
	Void.Elements.Image = function(ctx, cfg)
		cfg = cfg or {}
		local control = Void.Control.new("Image", cfg, ctx)

		local height = Scale.u(cfg.Height or 110)
		local holder = Util.New("Frame", {
			Name = "Image",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, height + (cfg.Caption and Scale.u(16) or 0)),
			Parent = ctx.Parent,
		})

		local frame = Util.New("Frame", {
			BackgroundColor3 = Theme.C.Element,
			Size = UDim2.new(1, 0, 0, height),
			ClipsDescendants = true,
			Parent = holder,
		})
		Theme:Paint(frame, { BackgroundColor3 = "Element" })
		Util.Corner(frame, Theme.Style.RadiusSmall)
		local stroke = Util.Stroke(frame, Theme.C.OutlineSoft)
		Theme:Paint(stroke, { Color = "OutlineSoft" })

		local _, resolved = Void.Icons:Resolve(cfg.Image or cfg.Asset or 0)
		local image = Util.New("ImageLabel", {
			Name = "Bitmap",
			Image = tostring(resolved or cfg.Image or ""),
			ScaleType = cfg.ScaleType or Enum.ScaleType.Fit,
			ImageTransparency = cfg.Transparency or 0,
			ImageColor3 = cfg.Tint or Color3.new(1, 1, 1),
			Size = UDim2.fromScale(1, 1),
			Parent = frame,
		})

		-- loading shimmer until the asset resolves
		local shimmer = Util.New("Frame", {
			BackgroundColor3 = Theme.C.ElementHover,
			Size = UDim2.fromScale(1, 1),
			Parent = frame,
		}, {
			Util.New("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 0.4),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
		task.spawn(function()
			while shimmer.Parent and not image.IsLoaded do
				shimmer.Position = UDim2.fromScale(-1, 0)
				Util.Tween(shimmer, { Position = UDim2.fromScale(1, 0) }, 0.9, Enum.EasingStyle.Sine)
				task.wait(1)
			end
			if shimmer.Parent then
				Util.Tween(shimmer, { BackgroundTransparency = 1 }, Util.Motion.Normal)
				task.delay(0.3, function() shimmer:Destroy() end)
			end
		end)

		if cfg.Caption then
			local caption = Common.Label(holder, cfg.Caption, {
				Token = "TextDark",
				Size = 10,
				Align = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(0, height + Scale.u(2)),
				Size2 = UDim2.new(1, 0, 0, Scale.u(14)),
			})
		end

		control._get = function() return image.Image end
		control._set = function(value)
			local _, newResolved = Void.Icons:Resolve(value)
			image.Image = tostring(newResolved or value)
		end
		function control:SetImage(value) control._set(value) return self end

		control:_finalise(holder, frame)
		control._cfg.SaveToConfig = false
		return control
	end

	-- ── COLLAPSIBLE SUB-SECTION ─────────────────────────────────────────
	-- Returns an object with the full Section element API, so you can nest:
	--   local adv = Section:CreateCollapsible({ Name = "Advanced" })
	--   adv:CreateToggle({ ... })
	Void.Elements.Collapsible = function(ctx, cfg)
		cfg = cfg or {}
		local control = Void.Control.new("Collapsible", cfg, ctx)
		local maid = control:GetMaid()
		local open = cfg.Open == true

		local holder = Util.New("Frame", {
			Name = "Collapsible",
			BackgroundColor3 = Theme.C.Element,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			ClipsDescendants = true,
			Parent = ctx.Parent,
		})
		Theme:Paint(holder, { BackgroundColor3 = "Element" })
		Util.Corner(holder, Theme.Style.RadiusSmall)
		local stroke = Util.Stroke(holder, Theme.C.OutlineSoft)
		Theme:Paint(stroke, { Color = "OutlineSoft" })

		local headerHeight = Scale.touch(24)
		local header = Util.New("TextButton", {
			Name = "Header",
			BackgroundTransparency = 1,
			Text = "",
			Size = UDim2.new(1, 0, 0, headerHeight),
			Parent = holder,
		})

		local chevron = Util.New("TextLabel", {
			Name = "Chevron",
			BackgroundTransparency = 1,
			Font = Theme:Font("FontBold"),
			Text = "▸",
			TextColor3 = Theme.C.Accent,
			TextSize = Scale.f(11),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, Scale.u(9), 0.5, 0),
			Size = UDim2.fromOffset(Scale.u(12), Scale.u(12)),
			Rotation = open and 90 or 0,
			Parent = header,
		})
		Theme:Paint(chevron, { TextColor3 = "Accent" })

		local title = Common.Label(header, cfg.Name or "Section", {
			Token = "Text",
			Font = "FontMedium",
			Position = UDim2.fromOffset(Scale.u(26), 0),
			Size2 = UDim2.new(1, -Scale.u(60), 1, 0),
		})

		local counter = Common.Label(header, "", {
			Token = "TextDark",
			Size = 10,
			Align = Enum.TextXAlignment.Right,
			Anchor = Vector2.new(1, 0),
			Position = UDim2.new(1, -Scale.u(9), 0, 0),
			Size2 = UDim2.new(0, Scale.u(40), 1, 0),
		})

		local body = Util.New("Frame", {
			Name = "Body",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, headerHeight),
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Visible = open,
			Parent = holder,
		}, {
			Util.New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, Scale:Metric("RowGap")) }),
			Util.New("UIPadding", {
				PaddingLeft = UDim.new(0, Scale.u(10)), PaddingRight = UDim.new(0, Scale.u(10)),
				PaddingTop = UDim.new(0, Scale.u(2)), PaddingBottom = UDim.new(0, Scale.u(9)),
			}),
		})

		local function setOpen(state, instant)
			open = state
			body.Visible = state
			Util.Tween(chevron, { Rotation = state and 90 or 0 }, instant and 0 or Util.Motion.Normal, Enum.EasingStyle.Back)
			Util.Tween(stroke, { Color = state and Theme.C.OutlineStrong or Theme.C.OutlineSoft }, Util.Motion.Fast)
		end

		maid:Give(header.MouseButton1Click:Connect(function()
			setOpen(not open)
		end))
		maid:Give(header.MouseEnter:Connect(function()
			Util.Tween(title, { TextColor3 = Theme.C.Accent }, Util.Motion.Fast)
		end))
		maid:Give(header.MouseLeave:Connect(function()
			Util.Tween(title, { TextColor3 = Theme.C.Text }, Util.Motion.Fast)
		end))

		control:_finalise(holder, header)

		-- Build a nested element host that mirrors the Section API.
		local nested = Void.MakeElementHost({
			Window = ctx.Window,
			Tab = ctx.Tab,
			Section = ctx.Section,
			Parent = body,
			Maid = maid,
			Name = cfg.Name,
			OnElementAdded = function()
				local count = 0
				for _, child in ipairs(body:GetChildren()) do
					if child:IsA("GuiObject") then count = count + 1 end
				end
				counter.Text = tostring(count)
			end,
		})

		nested.Control = control
		nested.Instance = holder
		function nested:Open() setOpen(true) return self end
		function nested:Close() setOpen(false) return self end
		function nested:Toggle() setOpen(not open) return open end
		function nested:IsOpen() return open end
		function nested:SetName(name) title.Text = name return self end
		function nested:Destroy() control:Destroy() end

		setOpen(open, true)
		return nested
	end
end
