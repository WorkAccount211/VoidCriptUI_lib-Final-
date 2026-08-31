--[[
	VoidCriptUI · Window/Window.lua
	The main window: header with search, icon rail, content area, overlay layer,
	resize grip, minimise-to-icon, mobile adaptation and window state saving.

	Structure
	---------
	ScreenGui
	└─ CanvasGroup "Window"        ← one GroupTransparency drives every fade
	   ├─ Frame "Main"
	   │  ├─ accent hairline (top)
	   │  ├─ Frame "Header"        ← title, subtitle, search, buttons, drag
	   │  ├─ Frame "Rail"          ← tab icons
	   │  ├─ Frame "Content"       ← tab pages
	   │  └─ Frame "Resize"        ← corner grip
	   └─ Frame "Overlay"          ← dropdown lists, colour pickers (never clipped)

	Because the whole window lives in a CanvasGroup, show/hide is a single tween
	instead of walking hundreds of descendants — the same reason the boot screen
	and notifications use CanvasGroups.
]]

return function(Void)
	local UserInputService = game:GetService("UserInputService")
	local Util, Theme, Scale = Void.Util, Void.Theme, Void.Scale

	local nextWindowId = 0

	function Void.MakeWindow(cfg)
		cfg = cfg or {}
		Void.Profiler:Begin("window:create")

		nextWindowId = nextWindowId + 1

		local Window = {
			Id = cfg.Id or cfg.Name or ("Window" .. nextWindowId),
			Name = cfg.Name or "voidcript",
			_tabs = {},
			_activeTab = nil,
			_maid = Void.Maid.new("Window"),
			_popups = {},
			_visible = true,
			_minimised = false,
			_lazy = cfg.LazyLoading ~= false,
			_cfg = cfg,
		}
		Void.RootMaid:Give(Window._maid)

		Window.OnToggle = Void.Signal.new("Window.OnToggle")
		Window.OnClose = Void.Signal.new("Window.OnClose")
		Window.OnOpen = Void.Signal.new("Window.OnOpen")
		Window.OnResize = Void.Signal.new("Window.OnResize")
		Window.OnTabChanged = Void.Signal.new("Window.OnTabChanged")

		-- ══════════════════ gui ══════════════════
		local gui = Util.Screen("VoidCript_" .. tostring(Window.Id), Window._maid)
		Window._gui = gui

		local windowSize = cfg.Size and UDim2.fromOffset(Scale.u(cfg.Size.X or 760), Scale.u(cfg.Size.Y or 500)) or Scale:WindowSize()

		local canvas = Util.New("CanvasGroup", {
			Name = "Window",
			BackgroundTransparency = 1,
			GroupTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = cfg.Position or UDim2.fromScale(0.5, 0.5),
			Size = windowSize,
			Parent = gui,
		})
		Window._canvas = canvas

		local scaler = Util.New("UIScale", { Scale = 0.94, Parent = canvas })
		Window._scaler = scaler

		local main = Util.New("Frame", {
			Name = "Main",
			BackgroundColor3 = Theme.C.Background,
			Size = UDim2.fromScale(1, 1),
			ClipsDescendants = true,
			Parent = canvas,
		})
		Theme:Paint(main, { BackgroundColor3 = "Background" })
		Util.Corner(main, Theme.Style.Radius + 1)
		local mainStroke = Util.Stroke(main, Theme.C.Outline)
		Theme:Paint(mainStroke, { Color = "Outline" })
		Window._main = main

		-- soft shadow behind the window (outside the clipping frame)
		Util.Shadow(canvas, Scale.u(52), Theme.Style.ShadowTransparency)

		-- glass sheen across the top third
		Util.Glass(main, Theme.Style.GlassStrength)

		-- signature accent hairline
		local accentLine = Util.New("Frame", {
			Name = "AccentLine",
			BackgroundColor3 = Theme.C.Accent,
			Size = UDim2.new(1, 0, 0, 2),
			ZIndex = 10,
			Parent = main,
		})
		Theme:Paint(accentLine, { BackgroundColor3 = "Accent" })

		-- ══════════════════ header ══════════════════
		local headerHeight = Scale:Metric("Header")
		local header = Util.New("Frame", {
			Name = "Header",
			BackgroundColor3 = Theme.C.Header,
			Size = UDim2.new(1, 0, 0, headerHeight),
			ZIndex = 4,
			Parent = main,
		})
		Theme:Paint(header, { BackgroundColor3 = "Header" })
		Window._header = header

		local headerDivider = Util.New("Frame", {
			BackgroundColor3 = Theme.C.OutlineSoft,
			Position = UDim2.new(0, 0, 1, -1),
			Size = UDim2.new(1, 0, 0, 1),
			Parent = header,
		})
		Theme:Paint(headerDivider, { BackgroundColor3 = "OutlineSoft" })

		-- logo
		local logoSize = Scale.u(16)
		local logo = Util.New("ImageLabel", {
			Name = "Logo",
			Image = cfg.Logo or "https://raw.githubusercontent.com/WorkAccount211/VoidCriptUI_lib-Final-/main/images/icon.png",
			ScaleType = Enum.ScaleType.Fit,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, Scale.u(13), 0.5, 0),
			Size = UDim2.fromOffset(logoSize, logoSize),
			Parent = header,
		})

		local titleLabel = Util.New("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			Font = Theme:Font("FontBold"),
			Text = tostring(cfg.Name or "voidcript"),
			TextColor3 = Theme.C.Text,
			TextSize = Scale:Font("FontTitle"),
			TextXAlignment = Enum.TextXAlignment.Left,
			AutomaticSize = Enum.AutomaticSize.X,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, Scale.u(17) + logoSize, 0.5, 0),
			Size = UDim2.fromOffset(0, headerHeight),
			Parent = header,
		})
		Theme:Paint(titleLabel, { TextColor3 = "Text" })
		Window._titleLabel = titleLabel

		local subtitleLabel = Util.New("TextLabel", {
			Name = "Subtitle",
			BackgroundTransparency = 1,
			Font = Theme:Font("Font"),
			Text = tostring(cfg.Subtitle or cfg.LoadingSubtitle or ""),
			TextColor3 = Theme.C.Accent,
			TextSize = Scale:Font("FontSmall"),
			TextXAlignment = Enum.TextXAlignment.Left,
			AutomaticSize = Enum.AutomaticSize.X,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, Scale.u(17) + logoSize, 0.5, Scale.u(1)),
			Size = UDim2.fromOffset(0, headerHeight),
			Parent = header,
		})
		Theme:Paint(subtitleLabel, { TextColor3 = "Accent" })
		Window._subtitleLabel = subtitleLabel

		local function layoutTitles()
			task.defer(function()
				if not titleLabel.Parent then return end
				subtitleLabel.Position = UDim2.new(0, Scale.u(17) + logoSize + titleLabel.AbsoluteSize.X + Scale.u(8), 0.5, Scale.u(1))
			end)
		end
		layoutTitles()
		Window._maid:Give(titleLabel:GetPropertyChangedSignal("Text"):Connect(layoutTitles))

		-- ── header buttons (right side) ─────────────────────────────────
		local buttonRow = Util.New("Frame", {
			Name = "Buttons",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -Scale.u(10), 0.5, 0),
			Size = UDim2.fromOffset(0, Scale.touch(22)),
			AutomaticSize = Enum.AutomaticSize.X,
			Parent = header,
		}, {
			Util.New("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, Scale.u(4)),
			}),
		})

		local function headerButton(glyph, tooltip, order, onClick, dangerous)
			local size = Scale.touch(22)
			local btn = Util.New("TextButton", {
				Name = "HB_" .. tostring(order),
				BackgroundColor3 = Theme.C.Element,
				BackgroundTransparency = 1,
				Font = Theme:Font("FontBold"),
				Text = glyph,
				TextColor3 = Theme.C.TextDim,
				TextSize = Scale.f(13),
				Size = UDim2.fromOffset(size, size),
				LayoutOrder = order,
				Parent = buttonRow,
			})
			Util.Corner(btn, Theme.Style.RadiusSmall)
			Window._maid:Give(btn.MouseEnter:Connect(function()
				Util.Tween(btn, {
					BackgroundTransparency = 0,
					BackgroundColor3 = Theme.C.Element,
					TextColor3 = dangerous and Theme.C.Danger or Theme.C.Text,
				}, Util.Motion.Fast)
			end))
			Window._maid:Give(btn.MouseLeave:Connect(function()
				Util.Tween(btn, { BackgroundTransparency = 1, TextColor3 = Theme.C.TextDim }, Util.Motion.Fast)
			end))
			Window._maid:Give(btn.MouseButton1Click:Connect(onClick))
			Void.Tooltip:Attach(btn, tooltip, Window._maid)
			return btn
		end

		-- ── global search (roadmap #13) ─────────────────────────────────
		local searchWidth = Scale.u(Scale:IsMobileClass() and 110 or 168)
		local searchHolder = Util.New("Frame", {
			Name = "Search",
			BackgroundColor3 = Theme.C.Element,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -Scale.u(96), 0.5, 0),
			Size = UDim2.fromOffset(searchWidth, Scale.touch(22)),
			Parent = header,
		})
		Theme:Paint(searchHolder, { BackgroundColor3 = "Element" })
		Util.Corner(searchHolder, Theme.Style.RadiusSmall)
		local searchStroke = Util.Stroke(searchHolder, Theme.C.OutlineSoft)
		Theme:Paint(searchStroke, { Color = "OutlineSoft" })
		Window._searchHolder = searchHolder

		local searchIcon = Util.New("TextLabel", {
			BackgroundTransparency = 1,
			Font = Theme:Font("Font"),
			Text = "🔍",
			TextColor3 = Theme.C.TextDark,
			TextSize = Scale.f(11),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, Scale.u(7), 0.5, 0),
			Size = UDim2.fromOffset(Scale.u(13), Scale.u(13)),
			Parent = searchHolder,
		})
		Theme:Paint(searchIcon, { TextColor3 = "TextDark" })

		local searchBox = Util.New("TextBox", {
			Name = "Box",
			BackgroundTransparency = 1,
			Font = Theme:Font("Font"),
			PlaceholderText = "search settings…",
			PlaceholderColor3 = Theme.C.TextDark,
			Text = "",
			TextColor3 = Theme.C.Text,
			TextSize = Scale.f(11),
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(Scale.u(24), 0),
			Size = UDim2.new(1, -Scale.u(46), 1, 0),
			Parent = searchHolder,
		})
		Theme:Paint(searchBox, { TextColor3 = "Text", PlaceholderColor3 = "TextDark" })
		Window._searchBox = searchBox

		local searchCount = Util.New("TextLabel", {
			BackgroundTransparency = 1,
			Font = Theme:Font("Font"),
			Text = "",
			TextColor3 = Theme.C.Accent,
			TextSize = Scale.f(10),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -Scale.u(7), 0.5, 0),
			Size = UDim2.fromOffset(Scale.u(34), Scale.u(13)),
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = searchHolder,
		})
		Theme:Paint(searchCount, { TextColor3 = "Accent" })

		local applySearch = Util.Debounce(function(query)
			-- Ensure every tab is built so the search can actually reach its
			-- elements; this is the one place where lazy loading is forced.
			if query ~= "" then
				for _, tab in ipairs(Window._tabs) do
					if not tab._built then
						tab._built = true
						for _, section in ipairs(tab._sections) do section:_flush() end
					end
				end
			end
			local matched, total = Void.Search:Apply(query)
			searchCount.Text = query == "" and "" or ("%d/%d"):format(matched, total)
		end, 0.12)

		Window._maid:Give(searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			applySearch(searchBox.Text)
		end))
		Window._maid:Give(searchBox.Focused:Connect(function()
			Util.Tween(searchStroke, { Color = Theme.C.Accent }, Util.Motion.Fast)
			Util.Tween(searchHolder, { Size = UDim2.fromOffset(searchWidth + Scale.u(24), Scale.touch(22)) }, Util.Motion.Normal)
		end))
		Window._maid:Give(searchBox.FocusLost:Connect(function()
			Util.Tween(searchStroke, { Color = Theme.C.OutlineSoft }, Util.Motion.Fast)
			Util.Tween(searchHolder, { Size = UDim2.fromOffset(searchWidth, Scale.touch(22)) }, Util.Motion.Normal)
		end))

		-- ══════════════════ rail ══════════════════
		local railWidth = Scale:Metric("Rail")
		local rail = Util.New("Frame", {
			Name = "Rail",
			BackgroundColor3 = Theme.C.Sidebar,
			Position = UDim2.fromOffset(0, headerHeight),
			Size = UDim2.new(0, railWidth, 1, -headerHeight),
			ZIndex = 3,
			Parent = main,
		}, {
			Util.New("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, Scale.u(4)),
			}),
			Util.New("UIPadding", { PaddingTop = UDim.new(0, Scale.u(9)) }),
		})
		Theme:Paint(rail, { BackgroundColor3 = "Sidebar" })
		Window._rail = rail

		local railDivider = Util.New("Frame", {
			BackgroundColor3 = Theme.C.OutlineSoft,
			Position = UDim2.new(1, -1, 0, 0),
			Size = UDim2.new(0, 1, 1, 0),
			ZIndex = 4,
			Parent = rail,
		})
		Theme:Paint(railDivider, { BackgroundColor3 = "OutlineSoft" })

		-- sliding accent indicator on the rail
		local railIndicator = Util.New("Frame", {
			Name = "Indicator",
			BackgroundColor3 = Theme.C.Accent,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.fromOffset(2, Scale.u(20)),
			Visible = false,
			ZIndex = 5,
			Parent = rail,
		})
		Theme:Paint(railIndicator, { BackgroundColor3 = "Accent" })
		Util.Corner(railIndicator, 1)
		Window._railIndicator = railIndicator

		-- ══════════════════ content ══════════════════
		local content = Util.New("Frame", {
			Name = "Content",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(railWidth, headerHeight),
			Size = UDim2.new(1, -railWidth, 1, -headerHeight),
			Parent = main,
		})
		Window._content = content

		-- overlay layer for popups: sibling of Main inside the canvas so it is
		-- not clipped by Main.ClipsDescendants
		local overlay = Util.New("Frame", {
			Name = "Overlay",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 50,
			Parent = canvas,
		})
		Window._overlay = overlay

		-- ══════════════════ empty state ══════════════════
		local emptyState = Util.New("TextLabel", {
			Name = "Empty",
			BackgroundTransparency = 1,
			Font = Theme:Font("Font"),
			Text = "no tabs yet",
			TextColor3 = Theme.C.TextDark,
			TextSize = Scale.f(12),
			Size = UDim2.fromScale(1, 1),
			Parent = content,
		})
		Theme:Paint(emptyState, { TextColor3 = "TextDark" })
		Window._emptyState = emptyState

		-- ══════════════════ resize grip (roadmap #14) ══════════════════
		local minSize = Scale:MinWindowSize()
		local grip = Util.New("TextButton", {
			Name = "Resize",
			BackgroundTransparency = 1,
			Text = "",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(1, 1),
			Size = UDim2.fromOffset(Scale.touch(16), Scale.touch(16)),
			ZIndex = 20,
			Parent = main,
		})
		for i = 1, 3 do
			Util.New("Frame", {
				BackgroundColor3 = Theme.C.OutlineStrong,
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -Scale.u(3), 1, -Scale.u(2 + (i - 1) * 4)),
				Size = UDim2.fromOffset(Scale.u(2 + (i - 1) * 4), 2),
				Rotation = 0,
				Parent = grip,
			})
		end

		if cfg.Resizable ~= false and not Scale:IsPhone() then
			local resizing, startSize, startInput = false, nil, nil
			Window._maid:Give(grip.InputBegan:Connect(function(input)
				local t = input.UserInputType
				if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
				resizing = true
				startSize = canvas.AbsoluteSize
				startInput = input.Position
			end))
			Window._maid:Give(UserInputService.InputChanged:Connect(function(input)
				if not resizing then return end
				local t = input.UserInputType
				if t ~= Enum.UserInputType.MouseMovement and t ~= Enum.UserInputType.Touch then return end
				local delta = input.Position - startInput
				local viewport = Util.Viewport()
				canvas.Size = UDim2.fromOffset(
					math.clamp(startSize.X + delta.X, minSize.X, viewport.X - Scale.u(20)),
					math.clamp(startSize.Y + delta.Y, minSize.Y, viewport.Y - Scale.u(20))
				)
			end))
			Window._maid:Give(UserInputService.InputEnded:Connect(function(input)
				local t = input.UserInputType
				if (t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch) and resizing then
					resizing = false
					Window.OnResize:Fire(canvas.AbsoluteSize)
					Window:_requestAutoSave()
				end
			end))
			Void.Tooltip:Attach(grip, "Drag to resize", Window._maid)
		else
			grip.Visible = false
		end

		-- ══════════════════ dragging ══════════════════
		Util.Draggable(header, canvas, Window._maid, function()
			Window:_requestAutoSave()
		end)

		-- ══════════════════ minimise-to-icon (roadmap #15) ══════════════
		-- The window collapses into the floating bubble; on desktop the header
		-- alone can also stay as a "mini bar".
		local miniBarMode = cfg.MinimiseStyle == "MiniBar"
		local savedSize = nil

		function Window:Minimise()
			if self._minimised then return self end
			self._minimised = true
			savedSize = canvas.Size

			if miniBarMode then
				rail.Visible = false
				content.Visible = false
				grip.Visible = false
				Util.Tween(canvas, { Size = UDim2.fromOffset(canvas.AbsoluteSize.X, headerHeight + Scale.u(4)) }, Util.Motion.Slow, Enum.EasingStyle.Quint)
			else
				self:Hide()
			end
			if self._floatingToggle then self._floatingToggle:SetWindowVisible(false) end
			return self
		end

		function Window:Restore()
			if not self._minimised then return self end
			self._minimised = false
			if miniBarMode then
				rail.Visible = true
				content.Visible = true
				grip.Visible = cfg.Resizable ~= false and not Scale:IsPhone()
				Util.Tween(canvas, { Size = savedSize or windowSize }, Util.Motion.Slow, Enum.EasingStyle.Quint)
			else
				self:Show()
			end
			if self._floatingToggle then self._floatingToggle:SetWindowVisible(true) end
			return self
		end

		function Window:ToggleMinimise()
			if self._minimised then self:Restore() else self:Minimise() end
			return self._minimised
		end

		-- ══════════════════ show / hide ══════════════════
		function Window:Show(instant)
			self._visible = true
			canvas.Visible = true
			Util.Tween(canvas, { GroupTransparency = 0 }, instant and 0 or Util.Motion.Slow)
			Util.Tween(scaler, { Scale = 1 }, instant and 0 or Util.Motion.Slow, Enum.EasingStyle.Back)
			if self._floatingToggle then self._floatingToggle:SetWindowVisible(true) end
			if Void.Cursor.Enabled then Void.Cursor:_refresh() end
			self.OnOpen:Fire()
			self.OnToggle:Fire(true)
			return self
		end

		function Window:Hide(instant)
			self._visible = false
			self:_closePopups()
			Util.Tween(canvas, { GroupTransparency = 1 }, instant and 0 or Util.Motion.Normal)
			Util.Tween(scaler, { Scale = 0.96 }, instant and 0 or Util.Motion.Normal)
			task.delay(instant and 0 or (Util.Motion.Normal + 0.05), function()
				if not self._visible and canvas then canvas.Visible = false end
			end)
			if self._floatingToggle then self._floatingToggle:SetWindowVisible(false) end
			self.OnClose:Fire()
			self.OnToggle:Fire(false)
			return self
		end

		function Window:Toggle()
			if self._visible then self:Hide() else self:Show() end
			return self._visible
		end

		function Window:IsVisible()
			return self._visible
		end

		-- ══════════════════ popup bookkeeping ══════════════════
		function Window:_registerPopup(popup)
			-- close any other open popup: only one at a time
			for _, other in ipairs(self._popups) do
				if other ~= popup and other.Open then
					other.Hide()
					if other.OnClose then other.OnClose() end
				end
			end
			if not table.find(self._popups, popup) then
				table.insert(self._popups, popup)
			end
		end

		function Window:_closePopups()
			for _, popup in ipairs(self._popups) do
				if popup.Open then
					popup.Hide()
					if popup.OnClose then popup.OnClose() end
				end
			end
		end

		-- click outside closes popups
		Window._maid:Give(UserInputService.InputBegan:Connect(function(input, gpe)
			if gpe then return end
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
			local anyOpen = false
			for _, popup in ipairs(Window._popups) do
				if popup.Open then anyOpen = true break end
			end
			if not anyOpen then return end
			task.defer(function()
				local mouse = UserInputService:GetMouseLocation()
				for _, popup in ipairs(Window._popups) do
					if popup.Open then
						local pos, size = popup.Canvas.AbsolutePosition, popup.Canvas.AbsoluteSize
						local inside = mouse.X >= pos.X and mouse.X <= pos.X + size.X
							and mouse.Y >= pos.Y - 30 and mouse.Y <= pos.Y + size.Y
						if not inside then
							popup.Hide()
							if popup.OnClose then popup.OnClose() end
						end
					end
				end
			end)
		end))

		-- ══════════════════ tabs ══════════════════
		function Window:CreateTab(name, icon, subtabs)
			local tab = Void.MakeTab(self, name, icon, subtabs)
			table.insert(self._tabs, tab)
			self._emptyState.Visible = false
			Void.Plugins:Fire("OnTab", tab)
			if #self._tabs == 1 then
				self:SelectTab(tab)
			end
			return tab
		end
		Window.AddTab = Window.CreateTab

		function Window:SelectTab(target)
			local tab = target
			if type(target) == "string" then
				for _, candidate in ipairs(self._tabs) do
					if candidate.Name == target then tab = candidate break end
				end
			elseif type(target) == "number" then
				tab = self._tabs[target]
			end
			if type(tab) ~= "table" then
				Void.Log:Warn("SelectTab: no tab '%s'", tostring(target))
				return self
			end
			if self._activeTab == tab then return self end

			self:_closePopups()
			for _, candidate in ipairs(self._tabs) do
				if candidate ~= tab then candidate:_deactivate() end
			end
			self._activeTab = tab
			tab:_activate()

			-- slide the rail indicator to the active button
			task.defer(function()
				if not tab._button.Parent then return end
				local buttonPos = tab._button.AbsolutePosition.Y - rail.AbsolutePosition.Y
				local buttonHeight = tab._button.AbsoluteSize.Y
				railIndicator.Visible = true
				Util.Tween(railIndicator, {
					Position = UDim2.new(0, 0, 0, math.floor(buttonPos + buttonHeight / 2)),
				}, Util.Motion.Normal, Enum.EasingStyle.Quint)
			end)

			self.OnTabChanged:Fire(tab)
			self:_requestAutoSave()
			return self
		end

		function Window:GetTabs()
			return self._tabs
		end

		function Window:GetActiveTab()
			return self._activeTab
		end

		-- ══════════════════ titles ══════════════════
		function Window:SetTitle(text)
			titleLabel.Text = tostring(text)
			self.Name = text
			return self
		end

		function Window:SetSubtitle(text)
			subtitleLabel.Text = tostring(text)
			layoutTitles()
			return self
		end

		-- ══════════════════ config plumbing ══════════════════
		function Window:_serializeState()
			return {
				Position = Void.Config.Serialize(nil, canvas.Position),
				Size = Void.Config.Serialize(nil, canvas.Size),
				Tab = self._activeTab and self._activeTab.Name or nil,
				Subtab = self._activeTab and self._activeTab._activeSubtab or nil,
				Visible = self._visible,
				Minimised = self._minimised,
			}
		end

		function Window:_restoreState(state)
			if type(state) ~= "table" then return end
			if state.Position then
				local pos = Void.Config.Deserialize(state.Position)
				if typeof(pos) == "UDim2" then canvas.Position = pos end
			end
			if state.Size then
				local size = Void.Config.Deserialize(state.Size)
				if typeof(size) == "UDim2" then canvas.Size = size end
			end
			if state.Tab then
				task.defer(function() self:SelectTab(state.Tab) end)
			end
			if state.Visible == false then
				task.defer(function() self:Hide(true) end)
			end
		end

		function Window:_requestAutoSave()
			Void.Config:RequestAutoSave()
		end

		function Window:SaveConfiguration(name)
			return Void.Config:Save(name)
		end

		function Window:LoadConfiguration(name)
			return Void.Config:Load(name)
		end

		-- ══════════════════ toggle keybind ══════════════════
		Window._toggleDescriptor = Void.Keybinds.Descriptor(cfg.ToggleKey or "RightShift")
		Window._toggleBind = Void.Keybinds:Register({
			Name = "Toggle menu",
			Descriptor = Window._toggleDescriptor,
			Mode = "Always",
			Category = "Interface",
			ShowInKeylist = cfg.ShowToggleInKeylist ~= false,
			OnPress = function()
				Window:Toggle()
			end,
		})
		Window._maid:Give(function() Void.Keybinds:Remove(Window._toggleBind) end)

		function Window:SetToggleKey(key)
			local descriptor = Void.Keybinds.Descriptor(key)
			if not descriptor then
				Void.Log:Warn("SetToggleKey: '%s' is not a valid key", tostring(key))
				return self
			end
			self._toggleDescriptor = descriptor
			self._toggleBind.Descriptor = descriptor
			Void.Keybinds:_notify()
			return self
		end

		function Window:GetToggleKey()
			return self._toggleBind.Descriptor
		end

		-- ══════════════════ header buttons ══════════════════
		headerButton("⚙", "Interface settings", 1, function()
			Window:OpenInterfaceTab()
		end)
		headerButton("—", "Minimise" .. (Scale:IsMobileClass() and "" or " (or press " .. Void.Keybinds.Label(Window._toggleDescriptor) .. ")"), 2, function()
			Window:Minimise()
		end)
		headerButton("×", "Close (unloads the script UI)", 3, function()
			Void.Dialog:Confirm({
				Title = "Close the menu?",
				Content = "This unloads the interface. You will need to re-execute the script to bring it back.",
				Accept = "Close",
				Decline = "Keep it open",
				Danger = true,
				OnAccept = function() Void.Library:Unload() end,
			})
		end, true)

		-- ══════════════════ cursor hover tracking ══════════════════
		Window._maid:Give(main.MouseEnter:Connect(function()
			Void.Cursor:PushHover()
			if Void.Cursor.LockInput ~= false and cfg.LockGameInput then
				Void.Cursor:SetInputLock(true)
			end
		end))
		Window._maid:Give(main.MouseLeave:Connect(function()
			Void.Cursor:PopHover()
			if cfg.LockGameInput then
				Void.Cursor:SetInputLock(false)
			end
		end))

		-- ══════════════════ mobile floating toggle ══════════════════
		if cfg.FloatingButton == true or (cfg.FloatingButton ~= false and Scale:IsMobileClass()) then
			Window._floatingToggle = Void.MobileToggle.new(Window, cfg.FloatingButtonSettings or {})
			Window._maid:Give(Window._floatingToggle)
		end

		-- ══════════════════ responsive relayout ══════════════════
		Window._maid:Give(Scale:OnChanged(function()
			local newHeaderHeight = Scale:Metric("Header")
			local newRailWidth = Scale:Metric("Rail")
			header.Size = UDim2.new(1, 0, 0, newHeaderHeight)
			rail.Position = UDim2.fromOffset(0, newHeaderHeight)
			rail.Size = UDim2.new(0, newRailWidth, 1, -newHeaderHeight)
			content.Position = UDim2.fromOffset(newRailWidth, newHeaderHeight)
			content.Size = UDim2.new(1, -newRailWidth, 1, -newHeaderHeight)
			grip.Visible = cfg.Resizable ~= false and not Scale:IsPhone()
			searchHolder.Visible = not Scale:IsPhone()

			-- keep the window inside the viewport after a resolution change
			local viewport = Util.Viewport()
			if canvas.AbsoluteSize.X > viewport.X - Scale.u(20) or canvas.AbsoluteSize.Y > viewport.Y - Scale.u(20) then
				canvas.Size = Scale:WindowSize()
			end
			Void.Log:Debug("window relayout for %s (%.2fx)", Scale.Device, Scale.Factor)
		end))

		-- ══════════════════ interface settings tab ══════════════════
		-- Created on demand so it costs nothing unless the user opens it.
		function Window:OpenInterfaceTab()
			if not self._interfaceTab then
				self._interfaceTab = Void.BuildInterfaceTab(self)
			end
			self:SelectTab(self._interfaceTab)
			return self._interfaceTab
		end

		function Window:Destroy()
			self:_closePopups()
			for _, tab in ipairs(table.clone(self._tabs)) do
				pcall(function() tab:Destroy() end)
			end
			self._maid:Destroy()
			for i = #Void.Windows, 1, -1 do
				if Void.Windows[i] == self then table.remove(Void.Windows, i) end
			end
		end
		Window.Close = Window.Destroy

		-- entrance animation
		if cfg.Visible == false then
			canvas.GroupTransparency = 1
			canvas.Visible = false
			Window._visible = false
		else
			Window:Show()
		end

		table.insert(Void.Windows, Window)
		Void.Plugins:Fire("OnWindow", Window)
		Void.Profiler:End()

		return Window
	end
end
