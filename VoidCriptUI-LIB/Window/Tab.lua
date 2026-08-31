--[[
	VoidCriptUI · Window/Tab.lua
	Icon-rail tab + optional subtab bar.

	The rail button is built immediately (it must be visible), but the tab's
	*content* is only materialised the first time the tab is selected — that is
	the lazy-loading path that makes the first frame cheap.

	The active tab icon pulses once on selection and the rail indicator slides
	between buttons, matching the CompKiller feel.
]]

return function(Void)
	local Util, Theme, Scale = Void.Util, Void.Theme, Void.Scale

	function Void.MakeTab(window, name, iconSpec, subtabs)
		if type(name) == "table" then
			local cfg = name
			name = cfg.Name
			iconSpec = cfg.Icon
			subtabs = cfg.Subtabs or cfg.SubTabs
		end
		subtabs = subtabs or {}

		local Tab = {
			Name = name or "Tab",
			_window = window,
			_sections = {},
			_subtabs = {},
			_subtabOrder = {},
			_activeSubtab = nil,
			_defaultSubtab = "__default",
			_maid = Void.Maid.new("Tab:" .. tostring(name)),
			_built = false,
			_active = false,
			_icon = iconSpec,
		}
		window._maid:Give(Tab._maid)

		-- ══════════════ rail button ══════════════
		local railHeight = Scale.touch(Scale.M.Rail * 0.68)
		local button = Util.New("TextButton", {
			Name = "Tab_" .. tostring(name),
			BackgroundColor3 = Theme.C.Sidebar,
			BackgroundTransparency = 1,
			Text = "",
			Size = UDim2.new(1, -Scale.u(10), 0, railHeight),
			LayoutOrder = #window._tabs + 1,
			Parent = window._rail,
		})
		Util.Corner(button, Theme.Style.RadiusSmall + 1)
		Tab._button = button

		local iconKind, iconValue = Void.Icons:Resolve(iconSpec)
		local iconHolder = Util.New("Frame", {
			Name = "IconHolder",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, Scale.u(6)),
			Size = UDim2.fromOffset(Scale.u(Scale.M.RailIcon), Scale.u(Scale.M.RailIcon)),
			Parent = button,
		})
		local iconScale = Util.New("UIScale", { Scale = 1, Parent = iconHolder })
		Tab._iconScale = iconScale

		local iconInstance
		if iconKind == "image" then
			iconInstance = Util.New("ImageLabel", {
				Name = "Icon",
				Image = iconValue,
				ImageColor3 = Theme.C.TextDark,
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(1, 1),
				Parent = iconHolder,
			})
		else
			iconInstance = Util.New("TextLabel", {
				Name = "Icon",
				BackgroundTransparency = 1,
				Font = Theme:Font("FontBold"),
				Text = iconValue or "•",
				TextColor3 = Theme.C.TextDark,
				TextSize = Scale.f(Scale.M.RailIcon * 0.85),
				Size = UDim2.fromScale(1, 1),
				Parent = iconHolder,
			})
		end
		Tab._iconInstance = iconInstance

		local nameLabel = Util.New("TextLabel", {
			Name = "Name",
			BackgroundTransparency = 1,
			Font = Theme:Font("Font"),
			Text = tostring(name),
			TextColor3 = Theme.C.TextDark,
			TextSize = Scale.f(Scale.M.RailFont),
			TextTruncate = Enum.TextTruncate.AtEnd,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -Scale.u(4)),
			Size = UDim2.new(1, -Scale.u(4), 0, Scale.u(11)),
			Parent = button,
		})
		Tab._nameLabel = nameLabel

		-- notification dot (Tab:SetBadge)
		local badge = Util.New("Frame", {
			Name = "Badge",
			BackgroundColor3 = Theme.C.Accent,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -Scale.u(6), 0, Scale.u(5)),
			Size = UDim2.fromOffset(Scale.u(6), Scale.u(6)),
			Visible = false,
			ZIndex = 4,
			Parent = button,
		})
		Theme:Paint(badge, { BackgroundColor3 = "Accent" })
		Util.Corner(badge, 999)
		Tab._badge = badge

		-- ══════════════ page ══════════════
		local page = Util.New("Frame", {
			Name = "Page_" .. tostring(name),
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			Parent = window._content,
		})
		Tab._page = page

		local hasSubtabs = #subtabs > 0
		local subtabBar
		if hasSubtabs then
			subtabBar = Util.New("Frame", {
				Name = "Subtabs",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(Scale:Metric("Pad") + Scale.u(2), Scale.u(8)),
				Size = UDim2.new(1, -Scale.u(24), 0, Scale.touch(26)),
				Parent = page,
			}, {
				Util.New("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, Scale.u(6)),
				}),
			})
		end

		local holderTop = hasSubtabs and Scale.touch(26) + Scale.u(14) or Scale.u(6)
		local pagesHolder = Util.New("Frame", {
			Name = "Pages",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, holderTop),
			Size = UDim2.new(1, 0, 1, -holderTop - Scale.u(4)),
			Parent = page,
		})
		Tab._pagesHolder = pagesHolder

		-- ══════════════ subtab pages ══════════════
		local function makeSubPage()
			local scroll = Util.New("ScrollingFrame", {
				Name = "Scroll",
				Size = UDim2.fromScale(1, 1),
				ScrollBarThickness = Scale.M.ScrollBar,
				ScrollBarImageColor3 = Theme.C.Accent,
				Visible = false,
				Parent = pagesHolder,
			})
			Theme:Paint(scroll, { ScrollBarImageColor3 = "Accent" })

			local pad = Scale:Metric("Pad")
			local gap = Scale:Metric("SectionGap")
			local columns = {}

			if Scale:Columns() == 1 then
				local single = Util.New("Frame", {
					Name = "Column1",
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(pad, 0),
					Size = UDim2.new(1, -pad * 2 - Scale.u(4), 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					Parent = scroll,
				})
				Util.List(single, gap)
				Util.New("UIPadding", { PaddingTop = UDim.new(0, gap), PaddingBottom = UDim.new(0, gap), Parent = single })
				columns[1] = single
				columns[2] = single
			else
				for index = 1, 2 do
					local col = Util.New("Frame", {
						Name = "Column" .. index,
						BackgroundTransparency = 1,
						Position = index == 1
							and UDim2.fromOffset(pad, 0)
							or UDim2.new(0.5, math.floor(gap / 2), 0, 0),
						Size = UDim2.new(0.5, -pad - math.floor(gap / 2), 0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						Parent = scroll,
					})
					Util.List(col, gap)
					Util.New("UIPadding", { PaddingTop = UDim.new(0, gap), PaddingBottom = UDim.new(0, gap), Parent = col })
					columns[index] = col
				end
			end

			return { Scroll = scroll, Columns = columns, Sections = {} }
		end
		Tab._makeSubPage = makeSubPage

		function Tab:_resolveSubtab(spec)
			if spec == nil then
				return self._activeSubtab or self._defaultSubtab
			end
			if type(spec) == "number" then
				local key = self._subtabOrder[spec]
				if key then return key end
				Void.Log:Warn("tab '%s': subtab index %d does not exist", tostring(self.Name), spec)
				return self._defaultSubtab
			end
			if self._subtabs[spec] then return spec end
			Void.Log:Warn("tab '%s': subtab '%s' does not exist", tostring(self.Name), tostring(spec))
			return self._defaultSubtab
		end

		function Tab:SelectSubtab(spec)
			local key = self:_resolveSubtab(spec)
			for subKey, subtab in pairs(self._subtabs) do
				local active = subKey == key
				subtab.Scroll.Visible = active
				if subtab.Button then
					Util.Tween(subtab.Button, {
						BackgroundColor3 = active and Theme.C.Element or Theme.C.Header,
					}, Util.Motion.Fast)
					Util.Tween(subtab.Label, {
						TextColor3 = active and Theme.C.Text or Theme.C.TextDim,
					}, Util.Motion.Fast)
					Util.Tween(subtab.Underline, {
						Size = active and UDim2.new(1, 0, 0, 2) or UDim2.new(0, 0, 0, 2),
					}, Util.Motion.Normal, Enum.EasingStyle.Quint)
				end
			end
			self._activeSubtab = key

			-- lazily build the sections that belong to this subtab
			local subtab = self._subtabs[key]
			if subtab then
				for _, section in ipairs(subtab.Sections) do
					section:_flush()
				end
			end
			return self
		end

		if hasSubtabs then
			for index, subName in ipairs(subtabs) do
				local subPage = makeSubPage()

				local sButton = Util.New("TextButton", {
					Name = "Subtab_" .. tostring(subName),
					BackgroundColor3 = Theme.C.Header,
					Text = "",
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.new(0, 0, 1, 0),
					LayoutOrder = index,
					Parent = subtabBar,
				}, {
					Util.New("UIPadding", {
						PaddingLeft = UDim.new(0, Scale.u(14)), PaddingRight = UDim.new(0, Scale.u(14)),
					}),
				})
				Theme:Paint(sButton, { BackgroundColor3 = "Header" })
				Util.Corner(sButton, Theme.Style.RadiusSmall)
				local sStroke = Util.Stroke(sButton, Theme.C.OutlineSoft)
				Theme:Paint(sStroke, { Color = "OutlineSoft" })

				local sLabel = Util.New("TextLabel", {
					BackgroundTransparency = 1,
					Font = Theme:Font("FontMedium"),
					Text = tostring(subName),
					TextColor3 = Theme.C.TextDim,
					TextSize = Scale:Font("FontBody"),
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.new(0, 0, 1, 0),
					Parent = sButton,
				})

				local underline = Util.New("Frame", {
					Name = "Underline",
					BackgroundColor3 = Theme.C.Accent,
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, 0),
					Size = UDim2.new(0, 0, 0, 2),
					Parent = sButton,
				})
				Theme:Paint(underline, { BackgroundColor3 = "Accent" })

				subPage.Button = sButton
				subPage.Label = sLabel
				subPage.Underline = underline
				subPage.Index = index

				Tab._maid:Give(sButton.MouseButton1Click:Connect(function()
					Tab:SelectSubtab(subName)
				end))
				Tab._maid:Give(sButton.MouseEnter:Connect(function()
					if Tab._activeSubtab ~= subName then
						Util.Tween(sLabel, { TextColor3 = Theme.C.Text }, Util.Motion.Fast)
						Util.Tween(sStroke, { Color = Theme.C.OutlineStrong }, Util.Motion.Fast)
					end
				end))
				Tab._maid:Give(sButton.MouseLeave:Connect(function()
					if Tab._activeSubtab ~= subName then
						Util.Tween(sLabel, { TextColor3 = Theme.C.TextDim }, Util.Motion.Fast)
						Util.Tween(sStroke, { Color = Theme.C.OutlineSoft }, Util.Motion.Fast)
					end
				end))

				Tab._subtabs[subName] = subPage
				Tab._subtabOrder[index] = subName
				if index == 1 then
					Tab._defaultSubtab = subName
					Tab._activeSubtab = subName
				end
			end
		else
			local single = makeSubPage()
			single.Scroll.Visible = true
			single.Index = 1
			Tab._subtabs["__default"] = single
			Tab._subtabOrder[1] = "__default"
			Tab._activeSubtab = "__default"
		end

		-- ══════════════ selection ══════════════
		function Tab:_paintRail(active)
			local iconProp = self._iconInstance:IsA("ImageLabel") and "ImageColor3" or "TextColor3"
			Util.Tween(self._iconInstance, { [iconProp] = active and Theme.C.Accent or Theme.C.TextDark }, Util.Motion.Normal)
			Util.Tween(self._nameLabel, { TextColor3 = active and Theme.C.Text or Theme.C.TextDark }, Util.Motion.Normal)
			Util.Tween(self._button, { BackgroundTransparency = active and 0 or 1, BackgroundColor3 = Theme.C.Element }, Util.Motion.Normal)
		end

		-- The "animated tab indicator": the icon pulses once on activation.
		function Tab:_pulse()
			self._iconScale.Scale = 1
			Util.Tween(self._iconScale, { Scale = 1.22 }, 0.12, Enum.EasingStyle.Quad)
			task.delay(0.13, function()
				if self._iconScale then
					Util.Tween(self._iconScale, { Scale = 1 }, 0.2, Enum.EasingStyle.Back)
				end
			end)
		end

		function Tab:_activate()
			self._active = true
			self._page.Visible = true
			self:_paintRail(true)
			self:_pulse()
			self:SetBadge(false)

			-- lazy build: realise everything queued for this tab
			if not self._built then
				Void.Profiler:Begin("tab:firstBuild")
				self._built = true
				for _, section in ipairs(self._sections) do
					section:_flush()
				end
				Void.Profiler:End()
				Void.Log:Debug("tab '%s' built on first open (%d sections)", tostring(self.Name), #self._sections)
			else
				for _, section in ipairs(self._sections) do
					if not section._built or #section._pending > 0 then section:_flush() end
				end
			end

			-- content fade so switching tabs feels smooth
			local canvas = self._page
			canvas.Position = UDim2.fromOffset(0, Scale.u(6))
			Util.Tween(canvas, { Position = UDim2.fromOffset(0, 0) }, Util.Motion.Normal, Enum.EasingStyle.Quint)

			Void.Plugins:Fire("OnTab", self)
		end

		function Tab:_deactivate()
			self._active = false
			self._page.Visible = false
			self:_paintRail(false)
		end

		function Tab:Select()
			window:SelectTab(self)
			return self
		end

		function Tab:CreateSection(cfg)
			return Void.MakeSection(self, cfg)
		end
		Tab.AddSection = Tab.CreateSection
		Tab.CreateGroupbox = Tab.CreateSection

		-- Convenience: elements straight on the tab go into a default section.
		function Tab:_default()
			if not self._defaultSection then
				self._defaultSection = self:CreateSection({ Name = self.Name })
			end
			return self._defaultSection
		end

		for _, kind in ipairs({
			"Toggle", "Slider", "RangeSlider", "Knob", "Dropdown", "MultiDropdown",
			"Input", "Textbox", "Keybind", "ColorPicker", "Button", "ImageButton",
			"Label", "Paragraph", "Divider", "ProgressBar", "Image", "ListBox",
			"Table", "Collapsible",
		}) do
			Tab["Create" .. kind] = function(selfRef, cfg)
				return selfRef:_default()["Create" .. kind](selfRef:_default(), cfg)
			end
		end

		function Tab:SetName(newName)
			self.Name = newName
			self._nameLabel.Text = tostring(newName)
			return self
		end

		function Tab:SetIcon(icon)
			local kind, value = Void.Icons:Resolve(icon)
			if kind == "image" and self._iconInstance:IsA("ImageLabel") then
				self._iconInstance.Image = value
			elseif kind == "text" and self._iconInstance:IsA("TextLabel") then
				self._iconInstance.Text = value
			end
			return self
		end

		function Tab:SetBadge(state)
			self._badge.Visible = state and true or false
			if state then
				self._badge.Size = UDim2.fromOffset(0, 0)
				Util.Tween(self._badge, { Size = UDim2.fromOffset(Scale.u(6), Scale.u(6)) }, Util.Motion.Normal, Enum.EasingStyle.Back)
			end
			return self
		end

		function Tab:SetVisible(state)
			self._button.Visible = state and true or false
			if not state and self._active then
				-- move to the first visible tab
				for _, other in ipairs(window._tabs) do
					if other ~= self and other._button.Visible then
						window:SelectTab(other)
						break
					end
				end
			end
			return self
		end

		-- dim the rail button when a global search finds nothing here
		function Tab:_setSearchDim(dim)
			local iconProp = self._iconInstance:IsA("ImageLabel") and "ImageTransparency" or "TextTransparency"
			Util.Tween(self._iconInstance, { [iconProp] = dim and 0.65 or 0 }, Util.Motion.Fast)
			Util.Tween(self._nameLabel, { TextTransparency = dim and 0.65 or 0 }, Util.Motion.Fast)
		end

		function Tab:GetSections()
			return self._sections
		end

		function Tab:Destroy()
			self._maid:Destroy()
			for _, section in ipairs(table.clone(self._sections)) do
				pcall(function() section:Destroy() end)
			end
			Theme:Unpaint(self._button)
			self._button:Destroy()
			self._page:Destroy()
			for i = #window._tabs, 1, -1 do
				if window._tabs[i] == self then table.remove(window._tabs, i) end
			end
		end

		-- rail hover
		Tab._maid:Give(button.MouseButton1Click:Connect(function()
			window:SelectTab(Tab)
		end))
		Tab._maid:Give(button.MouseEnter:Connect(function()
			if window._activeTab == Tab then return end
			local iconProp = iconInstance:IsA("ImageLabel") and "ImageColor3" or "TextColor3"
			Util.Tween(iconInstance, { [iconProp] = Theme.C.TextDim }, Util.Motion.Fast)
			Util.Tween(nameLabel, { TextColor3 = Theme.C.TextDim }, Util.Motion.Fast)
			Util.Tween(button, { BackgroundTransparency = 0.6, BackgroundColor3 = Theme.C.Element }, Util.Motion.Fast)
			Util.Tween(iconScale, { Scale = 1.08 }, Util.Motion.Fast)
		end))
		Tab._maid:Give(button.MouseLeave:Connect(function()
			Util.Tween(iconScale, { Scale = 1 }, Util.Motion.Fast)
			if window._activeTab == Tab then return end
			local iconProp = iconInstance:IsA("ImageLabel") and "ImageColor3" or "TextColor3"
			Util.Tween(iconInstance, { [iconProp] = Theme.C.TextDark }, Util.Motion.Fast)
			Util.Tween(nameLabel, { TextColor3 = Theme.C.TextDark }, Util.Motion.Fast)
			Util.Tween(button, { BackgroundTransparency = 1 }, Util.Motion.Fast)
		end))

		Void.Tooltip:Attach(button, tostring(name), Tab._maid)
		Tab:_paintRail(false)

		return Tab
	end
end
