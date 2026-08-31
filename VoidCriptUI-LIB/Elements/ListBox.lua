--[[
	VoidCriptUI · Elements/ListBox.lua
	Scrollable list with selection, plus a table/player-list variant
	(roadmap #12, and the "List Box" request from the DX section).

		local list = Section:CreateListBox({
			Name = "Whitelist",
			Flag = "whitelist",
			Items = { "Alice", "Bob" },
			MultiSelect = true,
			Height = 130,
			AllowAdd = true,          -- shows an "+ add" input row
			AllowRemove = true,       -- shows a "− remove selected" button
			Callback = function(selection) end,
		})
		list:Add("Carol"); list:Remove("Bob"); list:SetItems({...})

		local players = Section:CreateTable({
			Name = "Players",
			Columns = { "Name", "Team", "Ping" },
			Rows = { { "Alice", "Red", "42" } },
			Height = 150,
			OnRowSelected = function(row, index) end,
		})
		players:SetRows({ ... })

	Rows are pooled and reused, so refreshing a 200-player table every second
	does not create a single new Instance after the first pass.
]]

return function(Void)
	local Util, Theme, Scale, Common = Void.Util, Void.Theme, Void.Scale, Void.Common

	local ROW = 20

	-- ── LIST BOX ────────────────────────────────────────────────────────
	Void.Elements.ListBox = function(ctx, cfg)
		cfg = cfg or {}
		local control = Void.Control.new("ListBox", cfg, ctx)
		local maid = control:GetMaid()

		local items = table.clone(cfg.Items or cfg.Values or {})
		local multi = cfg.MultiSelect or false
		local selected = {}
		local single = nil
		local allowAdd = cfg.AllowAdd or false
		local allowRemove = cfg.AllowRemove or false

		local listHeight = Scale.u(cfg.Height or 120)
		local controlsHeight = (allowAdd or allowRemove) and Scale.touch(24) + Scale.u(4) or 0
		local holder = Common.Stack(ctx.Parent, Scale.u(17) + listHeight + controlsHeight)

		local label = Common.Label(holder, cfg.Name or "List", {
			Token = "TextDim",
			Size2 = UDim2.new(0.7, 0, 0, Scale.u(14)),
		})
		local counter = Common.Label(holder, "", {
			Token = "TextDark",
			Size = 10,
			Align = Enum.TextXAlignment.Right,
			Position = UDim2.new(0.7, 0, 0, 0),
			Size2 = UDim2.new(0.3, 0, 0, Scale.u(14)),
		})

		local frame, frameStroke = Common.Surface(holder, listHeight, {
			Position = UDim2.fromOffset(0, Scale.u(17)),
			Clip = true,
		})

		local scroll = Util.New("ScrollingFrame", {
			Name = "Items",
			Size = UDim2.fromScale(1, 1),
			ScrollBarThickness = Scale.M.ScrollBar,
			ScrollBarImageColor3 = Theme.C.Accent,
			Parent = frame,
		}, {
			Util.New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1) }),
			Util.New("UIPadding", {
				PaddingLeft = UDim.new(0, Scale.u(3)), PaddingRight = UDim.new(0, Scale.u(3)),
				PaddingTop = UDim.new(0, Scale.u(3)), PaddingBottom = UDim.new(0, Scale.u(3)),
			}),
		})
		Theme:Paint(scroll, { ScrollBarImageColor3 = "Accent" })

		local emptyLabel = Common.Label(frame, cfg.EmptyText or "empty", {
			Token = "TextDark",
			Align = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, Scale.u(8)),
			Size2 = UDim2.new(1, 0, 0, Scale.u(18)),
		})

		local pool = {}

		local function isSelected(item)
			if multi then return selected[item] == true end
			return single == item
		end

		local function selection()
			if multi then
				local out = {}
				for _, item in ipairs(items) do
					if selected[item] then out[#out + 1] = item end
				end
				return out
			end
			return single
		end

		local function paintRow(row)
			local active = isSelected(row.Item)
			Util.Tween(row.Instance, { BackgroundTransparency = active and 0.85 or 1 }, Util.Motion.Fast)
			Util.Tween(row.Label, { TextColor3 = active and Theme.C.Text or Theme.C.TextDim }, Util.Motion.Fast)
			row.Indicator.Visible = active
			if row.Check then row.Check.Set(active) end
		end

		local function refresh()
			for _, row in ipairs(pool) do
				if row.Item ~= nil then paintRow(row) end
			end
			local count = 0
			if multi then
				for _ in pairs(selected) do count = count + 1 end
				counter.Text = ("%d/%d"):format(count, #items)
			else
				counter.Text = tostring(#items)
			end
		end

		local function commit()
			control:_emit(selection())
		end

		local function acquireRow(index)
			local row = pool[index]
			if row then return row end

			local instance = Util.New("TextButton", {
				Name = "Item" .. index,
				BackgroundColor3 = Theme.C.ElementHover,
				BackgroundTransparency = 1,
				Text = "",
				Size = UDim2.new(1, 0, 0, Scale.u(ROW)),
				LayoutOrder = index,
				Parent = scroll,
			})
			Util.Corner(instance, Theme.Style.RadiusSmall - 1)

			local indicator = Util.New("Frame", {
				BackgroundColor3 = Theme.C.Accent,
				Size = UDim2.new(0, 2, 0.6, 0),
				Position = UDim2.new(0, 0, 0.2, 0),
				Visible = false,
				Parent = instance,
			})
			Theme:Paint(indicator, { BackgroundColor3 = "Accent" })

			local check, offset = nil, Scale.u(8)
			if multi then
				check = Common.Checkbox(instance, { Size = 11, Position = UDim2.new(0, Scale.u(6), 0.5, 0) })
				offset = Scale.u(23)
			end

			local text = Common.Label(instance, "", {
				Token = "TextDim",
				Position = UDim2.fromOffset(offset, 0),
				Size2 = UDim2.new(1, -offset - Scale.u(6), 1, 0),
			})

			row = { Instance = instance, Label = text, Indicator = indicator, Check = check }

			instance.MouseEnter:Connect(function()
				if not isSelected(row.Item) then
					Util.Tween(instance, { BackgroundTransparency = 0.92 }, Util.Motion.Fast)
				end
			end)
			instance.MouseLeave:Connect(function()
				if not isSelected(row.Item) then
					Util.Tween(instance, { BackgroundTransparency = 1 }, Util.Motion.Fast)
				end
			end)
			instance.MouseButton1Click:Connect(function()
				if row.Item == nil or not control:IsEnabled() then return end
				if multi then
					selected[row.Item] = not selected[row.Item] or nil
				else
					single = row.Item
				end
				refresh()
				commit()
			end)

			pool[index] = row
			return row
		end

		local function render()
			for index, item in ipairs(items) do
				local row = acquireRow(index)
				row.Item = item
				row.Label.Text = tostring(item)
				row.Instance.Visible = true
				paintRow(row)
			end
			for i = #items + 1, #pool do
				pool[i].Instance.Visible = false
				pool[i].Item = nil
			end
			emptyLabel.Visible = #items == 0
			refresh()
		end

		-- ── add / remove controls ───────────────────────────────────────
		if allowAdd or allowRemove then
			local bar = Util.New("Frame", {
				Name = "Controls",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, Scale.u(17) + listHeight + Scale.u(4)),
				Size = UDim2.new(1, 0, 0, Scale.touch(24)),
				Parent = holder,
			})

			local addBox
			if allowAdd then
				addBox = Util.New("TextBox", {
					BackgroundColor3 = Theme.C.Element,
					Font = Theme:Font("Font"),
					PlaceholderText = cfg.AddPlaceholder or "add an item…",
					PlaceholderColor3 = Theme.C.TextDark,
					Text = "",
					TextColor3 = Theme.C.Text,
					TextSize = Scale.f(11),
					TextXAlignment = Enum.TextXAlignment.Left,
					Size = UDim2.new(allowRemove and 0.62 or 1, -Scale.u(4), 1, 0),
					Parent = bar,
				}, {
					Util.New("UIPadding", { PaddingLeft = UDim.new(0, Scale.u(8)), PaddingRight = UDim.new(0, Scale.u(8)) }),
				})
				Theme:Paint(addBox, { BackgroundColor3 = "Element", TextColor3 = "Text", PlaceholderColor3 = "TextDark" })
				Util.Corner(addBox, Theme.Style.RadiusSmall)
				local addStroke = Util.Stroke(addBox, Theme.C.OutlineSoft)

				maid:Give(addBox.Focused:Connect(function()
					Util.Tween(addStroke, { Color = Theme.C.Accent }, Util.Motion.Fast)
				end))
				maid:Give(addBox.FocusLost:Connect(function(enter)
					Util.Tween(addStroke, { Color = Theme.C.OutlineSoft }, Util.Motion.Fast)
					if not enter then return end
					local text = addBox.Text:match("^%s*(.-)%s*$")
					if text == "" then return end
					if table.find(items, text) then
						Void.Notify:Push({ Title = "Already in the list", Content = ("`%s` is already there"):format(text), Type = "warning", Duration = 3 })
						return
					end
					table.insert(items, text)
					addBox.Text = ""
					render()
					commit()
				end))
			end

			if allowRemove then
				local removeBtn = Util.New("TextButton", {
					BackgroundColor3 = Theme.C.Element,
					Font = Theme:Font("FontMedium"),
					Text = cfg.RemoveText or "remove",
					TextColor3 = Theme.C.TextDim,
					TextSize = Scale.f(11),
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, 0, 0, 0),
					Size = UDim2.new(allowAdd and 0.36 or 1, 0, 1, 0),
					Parent = bar,
				})
				Theme:Paint(removeBtn, { BackgroundColor3 = "Element", TextColor3 = "TextDim" })
				Util.Corner(removeBtn, Theme.Style.RadiusSmall)
				local removeStroke = Util.Stroke(removeBtn, Theme.C.OutlineSoft)

				maid:Give(removeBtn.MouseEnter:Connect(function()
					Util.Tween(removeBtn, { BackgroundColor3 = Theme.C.ElementHover, TextColor3 = Theme.C.Danger }, Util.Motion.Fast)
					Util.Tween(removeStroke, { Color = Theme.C.Danger }, Util.Motion.Fast)
				end))
				maid:Give(removeBtn.MouseLeave:Connect(function()
					Util.Tween(removeBtn, { BackgroundColor3 = Theme.C.Element, TextColor3 = Theme.C.TextDim }, Util.Motion.Fast)
					Util.Tween(removeStroke, { Color = Theme.C.OutlineSoft }, Util.Motion.Fast)
				end))
				maid:Give(removeBtn.MouseButton1Click:Connect(function()
					local toRemove = multi and selection() or (single and { single } or {})
					if #toRemove == 0 then
						Void.Notify:Push({ Title = "Nothing selected", Content = "Pick an item first", Type = "info", Duration = 3 })
						return
					end
					for _, item in ipairs(toRemove) do
						local index = table.find(items, item)
						if index then table.remove(items, index) end
						selected[item] = nil
						if single == item then single = nil end
					end
					render()
					commit()
				end))
			end
		end

		-- ── API ─────────────────────────────────────────────────────────
		control._get = selection
		control._raw = selection
		control._set = function(value, fire)
			table.clear(selected)
			single = nil
			if multi and type(value) == "table" then
				for _, item in ipairs(value) do selected[item] = true end
			elseif value ~= nil then
				single = value
			end
			refresh()
			if fire then commit() end
		end

		function control:SetItems(newItems)
			items = table.clone(newItems or {})
			for item in pairs(selected) do
				if not table.find(items, item) then selected[item] = nil end
			end
			if single and not table.find(items, single) then single = nil end
			render()
			return self
		end
		function control:GetItems() return items end
		function control:Add(item)
			if table.find(items, item) then return self end
			table.insert(items, item)
			render()
			return self
		end
		function control:Remove(item)
			local index = table.find(items, item)
			if index then table.remove(items, index) end
			selected[item] = nil
			if single == item then single = nil end
			render()
			return self
		end
		function control:Clear()
			items = {}
			table.clear(selected)
			single = nil
			render()
			return self
		end
		function control:GetSelection() return selection() end

		control._setName = function(name) label.Text = name end
		control:_finalise(holder, frame)

		-- restore initial selection
		if multi then
			for _, item in ipairs(cfg.Selected or {}) do selected[item] = true end
		else
			single = cfg.Selected
		end
		render()
		return control
	end

	-- ── TABLE (roadmap #12) ─────────────────────────────────────────────
	Void.Elements.Table = function(ctx, cfg)
		cfg = cfg or {}
		local control = Void.Control.new("Table", cfg, ctx)
		local maid = control:GetMaid()

		local columns = cfg.Columns or { "Value" }
		local rows = table.clone(cfg.Rows or {})
		local selectedIndex = nil

		local tableHeight = Scale.u(cfg.Height or 140)
		local holder = Common.Stack(ctx.Parent, Scale.u(17) + tableHeight)

		local label = Common.Label(holder, cfg.Name or "Table", {
			Token = "TextDim",
			Size2 = UDim2.new(0.7, 0, 0, Scale.u(14)),
		})
		local counter = Common.Label(holder, "", {
			Token = "TextDark",
			Size = 10,
			Align = Enum.TextXAlignment.Right,
			Position = UDim2.new(0.7, 0, 0, 0),
			Size2 = UDim2.new(0.3, 0, 0, Scale.u(14)),
		})

		local frame = Common.Surface(holder, tableHeight, {
			Position = UDim2.fromOffset(0, Scale.u(17)),
			Clip = true,
		})

		-- header
		local headerHeight = Scale.u(18)
		local header = Util.New("Frame", {
			Name = "Header",
			BackgroundColor3 = Theme.C.Header,
			Size = UDim2.new(1, 0, 0, headerHeight),
			Parent = frame,
		})
		Theme:Paint(header, { BackgroundColor3 = "Header" })

		local columnWidth = 1 / #columns
		for index, column in ipairs(columns) do
			local head = Util.New("TextLabel", {
				BackgroundTransparency = 1,
				Font = Theme:Font("FontMedium"),
				Text = tostring(column),
				TextColor3 = Theme.C.TextDim,
				TextSize = Scale.f(10),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromScale((index - 1) * columnWidth, 0),
				Size = UDim2.fromScale(columnWidth, 1),
				Parent = header,
			}, {
				Util.New("UIPadding", { PaddingLeft = UDim.new(0, Scale.u(7)) }),
			})
			Theme:Paint(head, { TextColor3 = "TextDim" })
		end

		Util.New("Frame", {
			BackgroundColor3 = Theme.C.OutlineSoft,
			Position = UDim2.new(0, 0, 1, -1),
			Size = UDim2.new(1, 0, 0, 1),
			Parent = header,
		})

		local scroll = Util.New("ScrollingFrame", {
			Name = "Rows",
			Position = UDim2.fromOffset(0, headerHeight),
			Size = UDim2.new(1, 0, 1, -headerHeight),
			ScrollBarThickness = Scale.M.ScrollBar,
			ScrollBarImageColor3 = Theme.C.Accent,
			Parent = frame,
		}, {
			Util.New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		Theme:Paint(scroll, { ScrollBarImageColor3 = "Accent" })

		local emptyLabel = Common.Label(frame, cfg.EmptyText or "no rows", {
			Token = "TextDark",
			Align = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, headerHeight + Scale.u(8)),
			Size2 = UDim2.new(1, 0, 0, Scale.u(18)),
		})

		local pool = {}

		local function paintRow(row, index)
			local active = selectedIndex == index
			Util.Tween(row.Instance, { BackgroundTransparency = active and 0.82 or (index % 2 == 0 and 0.96 or 1) }, Util.Motion.Fast)
			for _, cell in ipairs(row.Cells) do
				Util.Tween(cell, { TextColor3 = active and Theme.C.Text or Theme.C.TextDim }, Util.Motion.Fast)
			end
			row.Indicator.Visible = active
		end

		local function acquireRow(index)
			local row = pool[index]
			if row then return row end

			local instance = Util.New("TextButton", {
				Name = "Row" .. index,
				BackgroundColor3 = Theme.C.ElementHover,
				BackgroundTransparency = 1,
				Text = "",
				Size = UDim2.new(1, 0, 0, Scale.u(ROW)),
				LayoutOrder = index,
				Parent = scroll,
			})

			local indicator = Util.New("Frame", {
				BackgroundColor3 = Theme.C.Accent,
				Size = UDim2.new(0, 2, 1, 0),
				Visible = false,
				Parent = instance,
			})
			Theme:Paint(indicator, { BackgroundColor3 = "Accent" })

			local cells = {}
			for column = 1, #columns do
				cells[column] = Util.New("TextLabel", {
					BackgroundTransparency = 1,
					Font = Theme:Font("Font"),
					Text = "",
					TextColor3 = Theme.C.TextDim,
					TextSize = Scale.f(11),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Position = UDim2.fromScale((column - 1) * columnWidth, 0),
					Size = UDim2.fromScale(columnWidth, 1),
					Parent = instance,
				}, {
					Util.New("UIPadding", { PaddingLeft = UDim.new(0, Scale.u(7)) }),
				})
			end

			row = { Instance = instance, Cells = cells, Indicator = indicator }

			instance.MouseEnter:Connect(function()
				if selectedIndex ~= row.Index then
					Util.Tween(instance, { BackgroundTransparency = 0.9 }, Util.Motion.Fast)
				end
			end)
			instance.MouseLeave:Connect(function()
				if selectedIndex ~= row.Index then
					Util.Tween(instance, { BackgroundTransparency = (row.Index or 1) % 2 == 0 and 0.96 or 1 }, Util.Motion.Fast)
				end
			end)
			instance.MouseButton1Click:Connect(function()
				if not row.Data then return end
				selectedIndex = row.Index
				for i, poolRow in ipairs(pool) do
					if poolRow.Data then paintRow(poolRow, poolRow.Index) end
				end
				control:_emit(row.Data)
				if cfg.OnRowSelected then
					Void.Log:GuardAsync("table row selected", cfg.OnRowSelected, row.Data, row.Index)
				end
			end)

			pool[index] = row
			return row
		end

		local function render()
			for index, data in ipairs(rows) do
				local row = acquireRow(index)
				row.Data = data
				row.Index = index
				row.Instance.Visible = true
				for column = 1, #columns do
					local value = type(data) == "table" and (data[column] or data[columns[column]]) or data
					row.Cells[column].Text = tostring(value == nil and "" or value)
				end
				paintRow(row, index)
			end
			for i = #rows + 1, #pool do
				pool[i].Instance.Visible = false
				pool[i].Data = nil
			end
			emptyLabel.Visible = #rows == 0
			counter.Text = ("%d rows"):format(#rows)
		end

		control._get = function()
			return selectedIndex and rows[selectedIndex] or nil
		end
		control._raw = function() return selectedIndex end
		control._set = function(value, fire)
			if type(value) == "number" then
				selectedIndex = value
			else
				selectedIndex = nil
				for index, data in ipairs(rows) do
					if data == value then selectedIndex = index break end
				end
			end
			render()
			if fire then control:_emit(control._get()) end
		end

		function control:SetRows(newRows)
			rows = table.clone(newRows or {})
			if selectedIndex and selectedIndex > #rows then selectedIndex = nil end
			render()
			return self
		end
		function control:AddRow(row)
			table.insert(rows, row)
			render()
			return self
		end
		function control:RemoveRow(index)
			table.remove(rows, index)
			if selectedIndex == index then selectedIndex = nil end
			render()
			return self
		end
		function control:Clear()
			rows = {}
			selectedIndex = nil
			render()
			return self
		end
		function control:GetRows() return rows end
		function control:GetSelectedIndex() return selectedIndex end

		control._setName = function(name) label.Text = name end
		control:_finalise(holder, frame)
		control._cfg.SaveToConfig = false
		render()
		return control
	end
end
