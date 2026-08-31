--[[
	VoidCriptUI · Services/Notify.lua
	Notification system with action buttons, progress notifications and types.

		VoidLib:Notify({
			Title = "Saved",
			Content = "Config **default** written to disk",
			Type = "success",           -- info | success | warning | error
			Duration = 4,
			Icon = "save",
			Actions = {
				{ Name = "Open folder", Callback = function() end },
				{ Name = "Undo", Style = "ghost", Callback = function() end },
			},
		})

	Each card is a CanvasGroup: the whole card fades and slides with a single
	GroupTransparency tween instead of touching every descendant.
	`Notify:Progress{...}` returns a handle with :Set(0..1) / :Finish() for
	long-running work.
]]

return function(Void)
	local Util, Theme, Scale = Void.Util, Void.Theme, Void.Scale

	local Notify = {
		Position = "TopRight",  -- TopRight | TopLeft | BottomRight | BottomLeft | TopCenter
		Max = 6,
		Enabled = true,
		_cards = {},
	}

	local TYPE_TOKENS = {
		info = "Accent",
		success = "Success",
		warning = "Risky",
		error = "Danger",
	}
	local TYPE_ICONS = {
		info = "info", success = "success", warning = "warning", error = "error",
	}

	local ANCHORS = {
		TopRight     = { Anchor = Vector2.new(1, 0), Pos = UDim2.new(1, -16, 0, 16), H = Enum.HorizontalAlignment.Right, V = Enum.VerticalAlignment.Top, Slide = 1 },
		TopLeft      = { Anchor = Vector2.new(0, 0), Pos = UDim2.new(0, 16, 0, 16), H = Enum.HorizontalAlignment.Left, V = Enum.VerticalAlignment.Top, Slide = -1 },
		BottomRight  = { Anchor = Vector2.new(1, 1), Pos = UDim2.new(1, -16, 1, -16), H = Enum.HorizontalAlignment.Right, V = Enum.VerticalAlignment.Bottom, Slide = 1 },
		BottomLeft   = { Anchor = Vector2.new(0, 1), Pos = UDim2.new(0, 16, 1, -16), H = Enum.HorizontalAlignment.Left, V = Enum.VerticalAlignment.Bottom, Slide = -1 },
		TopCenter    = { Anchor = Vector2.new(0.5, 0), Pos = UDim2.new(0.5, 0, 0, 16), H = Enum.HorizontalAlignment.Center, V = Enum.VerticalAlignment.Top, Slide = 0 },
	}

	local function build()
		if Notify._gui then return end
		local gui = Util.Screen("VoidCriptNotifications", Void.RootMaid)
		gui.DisplayOrder = 99000
		Notify._gui = gui

		local anchor = ANCHORS[Notify.Position] or ANCHORS.TopRight
		local holder = Util.New("Frame", {
			Name = "Stack",
			BackgroundTransparency = 1,
			AnchorPoint = anchor.Anchor,
			Position = anchor.Pos,
			Size = UDim2.fromOffset(Scale.u(300), 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = gui,
		}, {
			Util.New("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Scale.u(8)),
				HorizontalAlignment = anchor.H,
				VerticalAlignment = anchor.V,
			}),
		})
		Notify._holder = holder

		Void.Scale:OnChanged(function()
			if holder.Parent then
				holder.Size = UDim2.fromOffset(Scale.u(300), 0)
			end
		end)
	end

	function Notify:SetPosition(position)
		if not ANCHORS[position] then
			Void.Log:Warn("unknown notification position '%s'", tostring(position))
			return false
		end
		self.Position = position
		if self._holder then
			local anchor = ANCHORS[position]
			self._holder.AnchorPoint = anchor.Anchor
			self._holder.Position = anchor.Pos
			local layout = self._holder:FindFirstChildOfClass("UIListLayout")
			if layout then
				layout.HorizontalAlignment = anchor.H
				layout.VerticalAlignment = anchor.V
			end
		end
		return true
	end

	local function trim()
		while #Notify._cards > Notify.Max do
			local oldest = table.remove(Notify._cards, 1)
			if oldest and oldest.Dismiss then oldest:Dismiss(true) end
		end
	end

	function Notify:Push(cfg)
		if not self.Enabled then return nil end
		cfg = cfg or {}
		build()

		local kind = tostring(cfg.Type or "info"):lower()
		local token = TYPE_TOKENS[kind] or "Accent"
		local duration = cfg.Duration or (kind == "error" and 8 or 5)
		local anchor = ANCHORS[self.Position] or ANCHORS.TopRight

		local canvas = Util.New("CanvasGroup", {
			Name = "Notification",
			BackgroundTransparency = 1,
			GroupTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = self._holder,
		})

		local card = Util.New("Frame", {
			Name = "Card",
			BackgroundColor3 = Theme.C.Header,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = canvas,
		})
		Theme:Paint(card, { BackgroundColor3 = "Header" })
		Util.Corner(card, Theme.Style.Radius)
		local stroke = Util.Stroke(card, Theme.C.Outline)
		Theme:Paint(stroke, { Color = "Outline" })
		Util.Glass(card, 0.965)

		-- type accent line
		local accent = Util.New("Frame", {
			Name = "Accent",
			BackgroundColor3 = Theme.C[token],
			Size = UDim2.new(0, 2, 1, 0),
			ZIndex = 3,
			Parent = card,
		})
		Theme:Paint(accent, { BackgroundColor3 = token })

		local body = Util.New("Frame", {
			Name = "Body",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(Scale.u(12), 0),
			Size = UDim2.new(1, -Scale.u(22), 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = card,
		}, {
			Util.New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, Scale.u(4)) }),
			Util.New("UIPadding", {
				PaddingTop = UDim.new(0, Scale.u(10)),
				PaddingBottom = UDim.new(0, Scale.u(10)),
			}),
		})

		-- title row (icon + title + close)
		local titleRow = Util.New("Frame", {
			Name = "TitleRow",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, Scale.u(16)),
			LayoutOrder = 1,
			Parent = body,
		})

		local iconKind, iconValue = Void.Icons:Resolve(cfg.Icon or TYPE_ICONS[kind])
		local titleOffset = 0
		if iconValue then
			titleOffset = Scale.u(18)
			if iconKind == "image" then
				local img = Util.New("ImageLabel", {
					Image = iconValue,
					ImageColor3 = Theme.C[token],
					Size = UDim2.fromOffset(Scale.u(13), Scale.u(13)),
					Position = UDim2.new(0, 0, 0.5, -Scale.u(7)),
					Parent = titleRow,
				})
				Theme:Paint(img, { ImageColor3 = token })
			else
				local glyph = Util.New("TextLabel", {
					Font = Theme:Font("FontBold"),
					Text = iconValue,
					TextColor3 = Theme.C[token],
					TextSize = Scale.f(13),
					Size = UDim2.fromOffset(Scale.u(14), Scale.u(16)),
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = titleRow,
				})
				Theme:Paint(glyph, { TextColor3 = token })
			end
		end

		local title = Util.New("TextLabel", {
			Font = Theme:Font("FontBold"),
			Text = tostring(cfg.Title or "Notification"),
			TextColor3 = Theme.C.Text,
			TextSize = Scale.f(13),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(titleOffset, 0),
			Size = UDim2.new(1, -titleOffset - Scale.u(16), 1, 0),
			Parent = titleRow,
		})
		Theme:Paint(title, { TextColor3 = "Text" })

		local close = Util.New("TextButton", {
			Font = Theme:Font("FontBold"),
			Text = "×",
			TextColor3 = Theme.C.TextDark,
			TextSize = Scale.f(15),
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(Scale.u(16), Scale.u(16)),
			Parent = titleRow,
		})
		Theme:Paint(close, { TextColor3 = "TextDark" })

		local content
		if cfg.Content and cfg.Content ~= "" then
			content = Util.New("TextLabel", {
				Font = Theme:Font("Font"),
				Text = Void.RichText.Parse(cfg.Content),
				RichText = true,
				TextColor3 = Theme.C.TextDim,
				TextSize = Scale.f(12),
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
				Parent = body,
			})
			Theme:Paint(content, { TextColor3 = "TextDim" })
		end

		-- progress bar (used by Notify:Progress)
		local progressFill
		if cfg.Progress then
			local track = Util.New("Frame", {
				Name = "Progress",
				BackgroundColor3 = Theme.C.Element,
				Size = UDim2.new(1, 0, 0, Scale.u(4)),
				LayoutOrder = 3,
				Parent = body,
			})
			Theme:Paint(track, { BackgroundColor3 = "Element" })
			Util.Corner(track, 2)
			progressFill = Util.New("Frame", {
				BackgroundColor3 = Theme.C[token],
				Size = UDim2.fromScale(0, 1),
				Parent = track,
			})
			Theme:Paint(progressFill, { BackgroundColor3 = token })
			Util.Corner(progressFill, 2)
		end

		local handle = { _canvas = canvas, _dismissed = false }

		-- action buttons
		if cfg.Actions and #cfg.Actions > 0 then
			local row = Util.New("Frame", {
				Name = "Actions",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, Scale.touch(24)),
				LayoutOrder = 4,
				Parent = body,
			}, {
				Util.New("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, Scale.u(6)),
				}),
			})

			for index, action in ipairs(cfg.Actions) do
				local ghost = action.Style == "ghost"
				local btn = Util.New("TextButton", {
					BackgroundColor3 = ghost and Theme.C.Element or Theme.C[token],
					Font = Theme:Font("FontMedium"),
					Text = tostring(action.Name or ("Action " .. index)),
					TextColor3 = ghost and Theme.C.Text or Theme.C.TextOnAccent,
					TextSize = Scale.f(12),
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.new(0, 0, 1, 0),
					LayoutOrder = index,
					Parent = row,
				}, {
					Util.New("UIPadding", { PaddingLeft = UDim.new(0, Scale.u(11)), PaddingRight = UDim.new(0, Scale.u(11)) }),
				})
				Theme:Paint(btn, {
					BackgroundColor3 = ghost and "Element" or token,
					TextColor3 = ghost and "Text" or "TextOnAccent",
				})
				Util.Corner(btn, Theme.Style.RadiusSmall)
				if ghost then
					local s = Util.Stroke(btn, Theme.C.Outline)
					Theme:Paint(s, { Color = "Outline" })
				end

				btn.MouseEnter:Connect(function()
					Util.Tween(btn, { BackgroundColor3 = ghost and Theme.C.ElementHover or Theme.C.AccentDark }, Util.Motion.Fast)
				end)
				btn.MouseLeave:Connect(function()
					Util.Tween(btn, { BackgroundColor3 = ghost and Theme.C.Element or Theme.C[token] }, Util.Motion.Fast)
				end)
				btn.MouseButton1Click:Connect(function()
					Void.Log:GuardAsync(("notification action '%s'"):format(tostring(action.Name)), action.Callback)
					if action.Close ~= false then handle:Dismiss() end
				end)
			end
		end

		-- ── animation in: slide + fade via the CanvasGroup ──────────────
		local slide = anchor.Slide * Scale.u(28)
		card.Position = UDim2.fromOffset(slide, 0)
		Util.Tween(canvas, { GroupTransparency = 0 }, Util.Motion.Slow)
		Util.Tween(card, { Position = UDim2.fromOffset(0, 0) }, Util.Motion.Slow, Enum.EasingStyle.Quint)

		local timer
		function handle:Dismiss(instant)
			if self._dismissed then return end
			self._dismissed = true
			if timer then pcall(task.cancel, timer) end
			for i = #Notify._cards, 1, -1 do
				if Notify._cards[i] == self then table.remove(Notify._cards, i) end
			end
			if instant then
				canvas:Destroy()
				return
			end
			Util.Tween(canvas, { GroupTransparency = 1 }, Util.Motion.Normal)
			Util.Tween(card, { Position = UDim2.fromOffset(slide, 0) }, Util.Motion.Normal)
			task.delay(Util.Motion.Normal + 0.05, function()
				if canvas then canvas:Destroy() end
			end)
		end

		function handle:SetProgress(alpha)
			if progressFill then
				Util.Tween(progressFill, { Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1) }, Util.Motion.Fast)
			end
			return self
		end

		function handle:SetContent(text)
			if content then
				content.Text = Void.RichText.Parse(text)
			end
			return self
		end

		function handle:SetTitle(text)
			title.Text = tostring(text)
			return self
		end

		close.MouseButton1Click:Connect(function() handle:Dismiss() end)
		close.MouseEnter:Connect(function() Util.Tween(close, { TextColor3 = Theme.C.Danger }, Util.Motion.Fast) end)
		close.MouseLeave:Connect(function() Util.Tween(close, { TextColor3 = Theme.C.TextDark }, Util.Motion.Fast) end)

		if duration > 0 and not cfg.Sticky then
			timer = task.delay(duration, function() handle:Dismiss() end)
		end

		table.insert(self._cards, handle)
		trim()
		return handle
	end

	-- Long-running progress notification.
	function Notify:Progress(cfg)
		cfg = cfg or {}
		cfg.Progress = true
		cfg.Sticky = true
		local handle = self:Push(cfg)
		if not handle then return nil end

		function handle:Finish(message, kind)
			self:SetProgress(1)
			if message then self:SetContent(message) end
			task.delay(kind == "keep" and 3 or 1.2, function()
				self:Dismiss()
			end)
		end
		return handle
	end

	function Notify:DismissAll()
		for _, card in ipairs(table.clone(self._cards)) do
			card:Dismiss()
		end
	end

	function Notify:SetEnabled(state)
		self.Enabled = state and true or false
		if not self.Enabled then self:DismissAll() end
		return self.Enabled
	end

	Void.Notify = Notify
	return Notify
end
