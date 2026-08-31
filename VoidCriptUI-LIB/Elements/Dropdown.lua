--[[
	VoidCriptUI · Elements/Dropdown.lua
	Single-select, multi-select and searchable dropdowns
	(roadmap #1 multi-select with chips, #2 searchable).

		Section:CreateDropdown({
			Name = "Target part",
			Flag = "target",
			Options = { "Head", "Torso", "HumanoidRootPart" },
			CurrentOption = "Head",
			Searchable = true,       -- adds a filter box inside the list
			MultiSelect = false,     -- true → checkboxes + chips, value is a table
			Max = 3,                 -- multi-select cap (optional)
			Callback = function(value) end,
		})

	The list lives on the window overlay layer, so it is never clipped by the
	section's ScrollingFrame and always renders above other elements. Options
	are pooled: refreshing a 500-entry list reuses existing rows instead of
	destroying and rebuilding them.
]]

return function(Void)
	local Util, Theme, Scale, Common = Void.Util, Void.Theme, Void.Scale, Void.Common

	local ROW_HEIGHT = 22

	Void.Elements.Dropdown = function(ctx, cfg)
		cfg = cfg or {}
		local control = Void.Control.new("Dropdown", cfg, ctx)
		local maid = control:GetMaid()

		local options = cfg.Options or cfg.Values or {}
		local multi = cfg.MultiSelect or cfg.Multi or false
		local searchable = cfg.Searchable ~= false and (cfg.SearchBox or #options > 8)
		local maxSelected = cfg.Max

		-- selection state
		local selected = {}   -- multi: option -> true
		local current = nil   -- single

		if multi then
			for _, option in ipairs(cfg.CurrentOption or cfg.Default or {}) do
				selected[option] = true
			end
		else
			current = cfg.CurrentOption or cfg.Default or options[1]
		end

		-- ── row shell ───────────────────────────────────────────────────
		local holder = Common.Stack(ctx.Parent, nil)
		local label = Common.Label(holder, cfg.Name or "Dropdown", {
			Token = "TextDim",
			Size2 = UDim2.new(1, 0, 0, Scale.u(14)),
		})

		local buttonHeight = Scale.touch(24)
		local button, buttonStroke = Common.Surface(holder, buttonHeight, {
			Class = "TextButton",
			Position = UDim2.fromOffset(0, Scale.u(17)),
			Name = "Button",
		})
		holder.Size = UDim2.new(1, 0, 0, Scale.u(17) + buttonHeight)

		local valueLabel = Common.Label(button, "", {
			Token = "Text",
			Position = UDim2.fromOffset(Scale.u(9), 0),
			Size2 = UDim2.new(1, -Scale.u(30), 1, 0),
		})

		local arrow = Util.New("TextLabel", {
			Name = "Arrow",
			BackgroundTransparency = 1,
			Font = Theme:Font("Font"),
			Text = "▾",
			TextColor3 = Theme.C.Accent,
			TextSize = Scale.f(11),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -Scale.u(8), 0.5, 0),
			Size = UDim2.fromOffset(Scale.u(12), Scale.u(12)),
			Parent = button,
		})
		Theme:Paint(arrow, { TextColor3 = "Accent" })

		-- ── chips row for multi-select (roadmap #1) ─────────────────────
		local chipRow
		if multi and cfg.Chips ~= false then
			chipRow = Util.New("Frame", {
				Name = "Chips",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, Scale.u(17) + buttonHeight + Scale.u(4)),
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Parent = holder,
			}, {
				Util.New("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Wraps = true,
					Padding = UDim.new(0, Scale.u(4)),
				}),
			})
			holder.AutomaticSize = Enum.AutomaticSize.Y
		end

		-- ── popup list ──────────────────────────────────────────────────
		local maxRows = cfg.MaxVisible or 7
		local searchHeight = searchable and Scale.touch(24) + Scale.u(4) or 0
		local popupHeight = Scale.u(ROW_HEIGHT) * math.min(#options, maxRows) + Scale.u(8) + searchHeight

		local popup = Common.Popup(ctx, button, UDim2.fromOffset(200, popupHeight), { AutomaticSize = Enum.AutomaticSize.None })
		maid:Give(function() popup.Destroy() end)

		local searchBox
		if searchable then
			searchBox = Util.New("TextBox", {
				Name = "Filter",
				BackgroundColor3 = Theme.C.Element,
				Font = Theme:Font("Font"),
				PlaceholderText = "Search…",
				PlaceholderColor3 = Theme.C.TextDark,
				Text = "",
				TextColor3 = Theme.C.Text,
				TextSize = Scale.f(11),
				TextXAlignment = Enum.TextXAlignment.Left,
				Position = UDim2.fromOffset(Scale.u(4), Scale.u(4)),
				Size = UDim2.new(1, -Scale.u(8), 0, Scale.touch(22)),
				Parent = popup.Card,
			}, {
				Util.New("UIPadding", { PaddingLeft = UDim.new(0, Scale.u(8)), PaddingRight = UDim.new(0, Scale.u(8)) }),
			})
			Theme:Paint(searchBox, { BackgroundColor3 = "Element", TextColor3 = "Text", PlaceholderColor3 = "TextDark" })
			Util.Corner(searchBox, Theme.Style.RadiusSmall)
			Util.Stroke(searchBox, Theme.C.OutlineSoft)
		end

		local scroll = Util.New("ScrollingFrame", {
			Name = "List",
			Position = UDim2.fromOffset(0, Scale.u(4) + searchHeight),
			Size = UDim2.new(1, 0, 1, -Scale.u(8) - searchHeight),
			ScrollBarThickness = Scale.M.ScrollBar,
			ScrollBarImageColor3 = Theme.C.Accent,
			Parent = popup.Card,
		}, {
			Util.New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1) }),
			Util.New("UIPadding", { PaddingLeft = UDim.new(0, Scale.u(3)), PaddingRight = UDim.new(0, Scale.u(3)) }),
		})
		Theme:Paint(scroll, { ScrollBarImageColor3 = "Accent" })

		local emptyLabel = Common.Label(popup.Card, "no matches", {
			Token = "TextDark",
			Align = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, Scale.u(4) + searchHeight),
			Size2 = UDim2.new(1, 0, 0, Scale.u(22)),
		})
		emptyLabel.Visible = false

		-- ── row pool ────────────────────────────────────────────────────
		local pool = {}

		local function isSelected(option)
			if multi then return selected[option] == true end
			return current == option
		end

		local function displayText()
			if multi then
				local list = {}
				for _, option in ipairs(options) do
					if selected[option] then list[#list + 1] = tostring(option) end
				end
				if #list == 0 then return cfg.EmptyText or "none" end
				if #list <= 2 then return table.concat(list, ", ") end
				return ("%d selected"):format(#list)
			end
			if current == nil then return cfg.EmptyText or "none" end
			return tostring(current)
		end

		local rebuildChips

		local function updateDisplay()
			valueLabel.Text = displayText()
			local empty = multi and next(selected) == nil or (not multi and current == nil)
			valueLabel.TextColor3 = empty and Theme.C.TextDark or Theme.C.Text
			if rebuildChips then rebuildChips() end
		end

		local function commit()
			if multi then
				local list = {}
				for _, option in ipairs(options) do
					if selected[option] then list[#list + 1] = option end
				end
				control:_emit(list)
			else
				control:_emit(current)
			end
		end

		local function paintRow(row, option)
			local active = isSelected(option)
			Util.Tween(row.Label, { TextColor3 = active and Theme.C.Text or Theme.C.TextDim }, Util.Motion.Fast)
			Util.Tween(row.Instance, { BackgroundTransparency = active and 0.86 or 1 }, Util.Motion.Fast)
			row.Indicator.Visible = active
			if row.Check then row.Check.Set(active) end
		end

		local function refreshRows()
			for _, row in ipairs(pool) do
				if row.Option ~= nil then paintRow(row, row.Option) end
			end
		end

		local function selectOption(option)
			if multi then
				if selected[option] then
					selected[option] = nil
				else
					local count = 0
					for _ in pairs(selected) do count = count + 1 end
					if maxSelected and count >= maxSelected then
						Void.Notify:Push({
							Title = "Limit reached",
							Content = ("You can select at most **%d** options"):format(maxSelected),
							Type = "warning", Duration = 4,
						})
						return
					end
					selected[option] = true
				end
				refreshRows()
			else
				current = option
				refreshRows()
				popup.Hide()
				arrow.Text = "▾"
			end
			updateDisplay()
			commit()
		end

		local function acquireRow(index)
			local row = pool[index]
			if row then return row end

			local instance = Util.New("TextButton", {
				Name = "Option" .. index,
				BackgroundColor3 = Theme.C.ElementHover,
				BackgroundTransparency = 1,
				Text = "",
				Size = UDim2.new(1, 0, 0, Scale.u(ROW_HEIGHT)),
				LayoutOrder = index,
				Parent = scroll,
			})
			Util.Corner(instance, Theme.Style.RadiusSmall - 1)

			local indicator = Util.New("Frame", {
				Name = "Indicator",
				BackgroundColor3 = Theme.C.Accent,
				Size = UDim2.new(0, 2, 0.6, 0),
				Position = UDim2.new(0, 0, 0.2, 0),
				Visible = false,
				Parent = instance,
			})
			Theme:Paint(indicator, { BackgroundColor3 = "Accent" })

			local check
			local textOffset = Scale.u(9)
			if multi then
				check = Common.Checkbox(instance, { Size = 12, Position = UDim2.new(0, Scale.u(7), 0.5, 0) })
				textOffset = Scale.u(25)
			end

			local text = Common.Label(instance, "", {
				Token = "TextDim",
				Position = UDim2.fromOffset(textOffset, 0),
				Size2 = UDim2.new(1, -textOffset - Scale.u(6), 1, 0),
			})

			row = { Instance = instance, Label = text, Indicator = indicator, Check = check }

			instance.MouseEnter:Connect(function()
				if not isSelected(row.Option) then
					Util.Tween(instance, { BackgroundTransparency = 0.9 }, Util.Motion.Fast)
				end
			end)
			instance.MouseLeave:Connect(function()
				if not isSelected(row.Option) then
					Util.Tween(instance, { BackgroundTransparency = 1 }, Util.Motion.Fast)
				end
			end)
			instance.MouseButton1Click:Connect(function()
				if row.Option ~= nil then selectOption(row.Option) end
			end)

			pool[index] = row
			return row
		end

		local function renderList(filter)
			local needle = Util.Slug(filter or "")
			local shown = 0
			for _, option in ipairs(options) do
				local text = tostring(option)
				if needle == "" or Util.Slug(text):find(needle, 1, true) then
					shown = shown + 1
					local row = acquireRow(shown)
					row.Option = option
					row.Label.Text = text
					row.Instance.Visible = true
					row.Instance.LayoutOrder = shown
					paintRow(row, option)
				end
			end
			for i = shown + 1, #pool do
				pool[i].Instance.Visible = false
				pool[i].Option = nil
			end
			emptyLabel.Visible = shown == 0
			scroll.Visible = shown > 0

			local visibleRows = math.min(shown, maxRows)
			local height = Scale.u(ROW_HEIGHT) * math.max(visibleRows, 1) + Scale.u(8) + searchHeight
			popup.Canvas.Size = UDim2.fromOffset(popup.Canvas.AbsoluteSize.X > 0 and popup.Canvas.AbsoluteSize.X or 200, height)
			popup.Reposition()
		end

		if chipRow then
			rebuildChips = function()
				for _, child in ipairs(chipRow:GetChildren()) do
					if child:IsA("GuiObject") then child:Destroy() end
				end
				local order = 0
				for _, option in ipairs(options) do
					if selected[option] then
						order = order + 1
						local chip = Util.New("TextButton", {
							Name = "Chip",
							BackgroundColor3 = Theme.C.Element,
							Font = Theme:Font("Font"),
							Text = tostring(option) .. "  ×",
							TextColor3 = Theme.C.Accent,
							TextSize = Scale.f(11),
							AutomaticSize = Enum.AutomaticSize.X,
							Size = UDim2.fromOffset(0, Scale.u(17)),
							LayoutOrder = order,
							Parent = chipRow,
						}, {
							Util.New("UIPadding", { PaddingLeft = UDim.new(0, Scale.u(7)), PaddingRight = UDim.new(0, Scale.u(7)) }),
						})
						Theme:Paint(chip, { BackgroundColor3 = "Element", TextColor3 = "Accent" })
						Util.Corner(chip, 999)
						local chipStroke = Util.Stroke(chip, Theme.C.OutlineSoft)
						chip.MouseEnter:Connect(function()
							Util.Tween(chipStroke, { Color = Theme.C.Danger }, Util.Motion.Fast)
						end)
						chip.MouseLeave:Connect(function()
							Util.Tween(chipStroke, { Color = Theme.C.OutlineSoft }, Util.Motion.Fast)
						end)
						chip.MouseButton1Click:Connect(function()
							selected[option] = nil
							refreshRows()
							updateDisplay()
							commit()
						end)
					end
				end
			end
		end

		-- ── open / close ────────────────────────────────────────────────
		local function open()
			renderList(searchBox and searchBox.Text or "")
			popup.Show()
			arrow.Text = "▴"
			Util.Tween(buttonStroke, { Color = Theme.C.Accent }, Util.Motion.Fast)
			if searchBox then
				task.defer(function() pcall(function() searchBox:CaptureFocus() end) end)
			end
		end

		local function close()
			popup.Hide()
			arrow.Text = "▾"
			Util.Tween(buttonStroke, { Color = Theme.C.OutlineSoft }, Util.Motion.Fast)
		end

		popup.OnClose = close

		maid:Give(button.MouseButton1Click:Connect(function()
			if not control:IsEnabled() then return end
			if popup.Open then close() else open() end
		end))

		control:_hoverable(button, button, "Element", "ElementHover", buttonStroke)

		if searchBox then
			local filter = Util.Debounce(function(text)
				renderList(text)
			end, 0.08)
			maid:Give(searchBox:GetPropertyChangedSignal("Text"):Connect(function()
				filter(searchBox.Text)
			end))
		end

		-- ── control API ─────────────────────────────────────────────────
		control._get = function()
			if multi then
				local list = {}
				for _, option in ipairs(options) do
					if selected[option] then list[#list + 1] = option end
				end
				return list
			end
			return current
		end
		control._raw = control._get
		control._set = function(value, fire)
			if multi then
				table.clear(selected)
				if type(value) == "table" then
					for _, option in ipairs(value) do selected[option] = true end
				elseif value ~= nil then
					selected[value] = true
				end
			else
				if value ~= nil and not table.find(options, value) then
					Void.Log:Warn("dropdown '%s': option '%s' is not in the list", tostring(cfg.Name), tostring(value))
				end
				current = value
			end
			refreshRows()
			updateDisplay()
			if fire then commit() end
		end

		function control:Refresh(newOptions, keepSelection)
			options = newOptions or {}
			if multi then
				if not keepSelection then
					table.clear(selected)
				else
					for option in pairs(selected) do
						if not table.find(options, option) then selected[option] = nil end
					end
				end
			else
				if current ~= nil and not table.find(options, current) then
					current = keepSelection and nil or options[1]
				end
			end
			renderList(searchBox and searchBox.Text or "")
			updateDisplay()
			return self
		end
		control.SetOptions = control.Refresh

		function control:GetOptions()
			return options
		end

		function control:SelectAll()
			if not multi then return self end
			for _, option in ipairs(options) do selected[option] = true end
			refreshRows()
			updateDisplay()
			commit()
			return self
		end

		function control:Clear()
			if multi then table.clear(selected) else current = nil end
			refreshRows()
			updateDisplay()
			commit()
			return self
		end

		function control:Open() open() return self end
		function control:Close() close() return self end

		control._setName = function(name) label.Text = name end
		control._setEnabled = function(enabled)
			label.TextTransparency = enabled and 0 or 0.5
			valueLabel.TextTransparency = enabled and 0 or 0.5
			button.BackgroundTransparency = enabled and 0 or 0.4
		end

		control:_finalise(holder, button)
		renderList("")
		updateDisplay()
		return control
	end

	-- Alias so `Section:CreateMultiDropdown{...}` reads naturally.
	Void.Elements.MultiDropdown = function(ctx, cfg)
		cfg = cfg or {}
		cfg.MultiSelect = true
		return Void.Elements.Dropdown(ctx, cfg)
	end
end
