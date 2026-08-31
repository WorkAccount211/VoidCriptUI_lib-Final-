--[[
	VoidCriptUI · Components/Keylist.lua
	Floating list of active binds (roadmap #42, extended).

	Columns (configurable): Name · Mode · Key · State · Hits.
	  Name  — the function the bind belongs to
	  Mode  — Always / Toggle / Hold
	  Key   — the resolved label, including modifiers ("Ctrl+F", "MB2")
	  State — live ON/OFF for Toggle and Hold binds
	  Hits  — how many times it fired this session (handy for debugging)
	Extra optional columns: Category, LastUsed.

		VoidLib:Keylist({
			Title = "keybinds",
			Columns = { "Name", "Mode", "Key", "State" },
			Position = "LeftCenter",
			HideEmpty = true,
			OnlyActive = false,
		})

	Updates are event-driven: the list only re-renders when the keybind manager
	says something changed, plus a 4 Hz refresh for the State/Hits columns.
]]

return function(Void)
	local RunService = game:GetService("RunService")
	local Util, Theme, Scale = Void.Util, Void.Theme, Void.Scale

	local Keylist = { _instance = nil }

	local Instance_ = {}
	Instance_.__index = Instance_

	local ANCHORS = {
		LeftCenter  = { Anchor = Vector2.new(0, 0.5), Pos = UDim2.new(0, 12, 0.5, 0) },
		RightCenter = { Anchor = Vector2.new(1, 0.5), Pos = UDim2.new(1, -12, 0.5, 0) },
		TopLeft     = { Anchor = Vector2.new(0, 0), Pos = UDim2.new(0, 12, 0, 48) },
		TopRight    = { Anchor = Vector2.new(1, 0), Pos = UDim2.new(1, -12, 0, 48) },
		BottomLeft  = { Anchor = Vector2.new(0, 1), Pos = UDim2.new(0, 12, 1, -12) },
		BottomRight = { Anchor = Vector2.new(1, 1), Pos = UDim2.new(1, -12, 1, -12) },
	}

	local COLUMN_WIDTH = {
		Name = 0.42, Mode = 0.18, Key = 0.22, State = 0.18, Hits = 0.12, Category = 0.24, LastUsed = 0.2,
	}

	function Keylist:Create(cfg)
		cfg = cfg or {}
		if self._instance then
			self._instance:Configure(cfg)
			self._instance:Show()
			return self._instance
		end

		local self_ = setmetatable({
			_maid = Void.Maid.new("Keylist"),
			_columns = cfg.Columns or { "Name", "Mode", "Key", "State" },
			_position = cfg.Position or "LeftCenter",
			_title = cfg.Title or "keybinds",
			_hideEmpty = cfg.HideEmpty ~= false,
			_onlyActive = cfg.OnlyActive or false,
			_rows = {},
			_visible = true,
		}, Instance_)

		local gui = Util.Screen("VoidCriptKeylist")
		gui.DisplayOrder = 97500
		self_._gui = gui
		self_._maid:Give(gui)

		local anchor = ANCHORS[self_._position] or ANCHORS.LeftCenter
		local canvas = Util.New("CanvasGroup", {
			Name = "Canvas",
			BackgroundTransparency = 1,
			GroupTransparency = 1,
			AnchorPoint = anchor.Anchor,
			Position = anchor.Pos,
			Size = UDim2.fromOffset(Scale.u(cfg.Width or 232), Scale.u(40)),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = gui,
		})
		self_._canvas = canvas

		local card = Util.New("Frame", {
			Name = "Card",
			BackgroundColor3 = Theme.C.Header,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = canvas,
		})
		Theme:Paint(card, { BackgroundColor3 = "Header" })
		Util.Corner(card, Theme.Style.RadiusSmall + 1)
		local stroke = Util.Stroke(card, Theme.C.Outline)
		Theme:Paint(stroke, { Color = "Outline" })
		Util.Glass(card, 0.965)
		self_._card = card

		local accent = Util.New("Frame", {
			BackgroundColor3 = Theme.C.Accent,
			Size = UDim2.new(1, 0, 0, 1),
			ZIndex = 4,
			Parent = card,
		})
		Theme:Paint(accent, { BackgroundColor3 = "Accent" })

		local body = Util.New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = card,
		}, {
			Util.New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, Scale.u(3)) }),
			Util.New("UIPadding", {
				PaddingLeft = UDim.new(0, Scale.u(9)), PaddingRight = UDim.new(0, Scale.u(9)),
				PaddingTop = UDim.new(0, Scale.u(7)), PaddingBottom = UDim.new(0, Scale.u(8)),
			}),
		})
		self_._body = body

		-- header row: title + count
		local titleRow = Util.New("Frame", {
			Name = "Title",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, Scale.u(15)),
			LayoutOrder = 1,
			Parent = body,
		})
		local title = Util.New("TextLabel", {
			Font = Theme:Font("FontBold"),
			Text = self_._title,
			TextColor3 = Theme.C.Text,
			TextSize = Scale.f(12),
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(0.7, 0, 1, 0),
			Parent = titleRow,
		})
		Theme:Paint(title, { TextColor3 = "Text" })
		self_._titleLabel = title

		local count = Util.New("TextLabel", {
			Font = Theme:Font("Font"),
			Text = "0",
			TextColor3 = Theme.C.Accent,
			TextSize = Scale.f(11),
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.new(0.3, 0, 1, 0),
			Parent = titleRow,
		})
		Theme:Paint(count, { TextColor3 = "Accent" })
		self_._countLabel = count

		Util.New("Frame", {
			Name = "Divider",
			BackgroundColor3 = Theme.C.OutlineSoft,
			Size = UDim2.new(1, 0, 0, 1),
			LayoutOrder = 2,
			Parent = body,
		})

		-- column header
		self_._columnHeader = Util.New("Frame", {
			Name = "Columns",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, Scale.u(12)),
			LayoutOrder = 3,
			Parent = body,
		})

		self_._rowHolder = Util.New("Frame", {
			Name = "Rows",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 4,
			Parent = body,
		}, {
			Util.New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, Scale.u(2)) }),
		})

		self_._empty = Util.New("TextLabel", {
			Font = Theme:Font("Font"),
			Text = "no binds yet",
			TextColor3 = Theme.C.TextDark,
			TextSize = Scale.f(11),
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, Scale.u(14)),
			LayoutOrder = 5,
			Parent = body,
		})
		Theme:Paint(self_._empty, { TextColor3 = "TextDark" })

		if cfg.Draggable ~= false then
			local handle = Util.New("TextButton", {
				Name = "DragHandle",
				BackgroundTransparency = 1,
				Text = "",
				Size = UDim2.new(1, 0, 0, Scale.u(20)),
				ZIndex = 6,
				Parent = card,
			})
			Util.Draggable(handle, canvas, self_._maid)
		end

		self_:_buildColumnHeader()
		self_:Refresh()

		-- event-driven refresh
		self_._maid:Give(Void.Keybinds:OnUpdated(function()
			self_:Refresh()
		end))

		-- light 4 Hz refresh for State/Hits
		local accum = 0
		self_._maid:Give(RunService.Heartbeat:Connect(function(dt)
			if not self_._visible then return end
			accum = accum + dt
			if accum < 0.25 then return end
			accum = 0
			self_:_refreshDynamic()
		end))

		self_._maid:Give(Void.Scale:OnChanged(function()
			self_:_buildColumnHeader()
			self_:Refresh()
		end))

		Util.Tween(canvas, { GroupTransparency = 0 }, Util.Motion.Slow)
		Keylist._instance = self_
		return self_
	end

	function Instance_:_buildColumnHeader()
		for _, child in ipairs(self._columnHeader:GetChildren()) do child:Destroy() end
		local x = 0
		for _, column in ipairs(self._columns) do
			local width = COLUMN_WIDTH[column] or 0.2
			local label = Util.New("TextLabel", {
				Font = Theme:Font("Font"),
				Text = tostring(column):lower(),
				TextColor3 = Theme.C.TextDark,
				TextSize = Scale.f(10),
				TextXAlignment = Enum.TextXAlignment.Left,
				Position = UDim2.fromScale(x, 0),
				Size = UDim2.fromScale(width, 1),
				Parent = self._columnHeader,
			})
			Theme:Paint(label, { TextColor3 = "TextDark" })
			x = x + width
		end
	end

	local function cellText(column, bind)
		if column == "Name" then
			return tostring(bind.Name or "?"), "Text"
		elseif column == "Mode" then
			return tostring(bind.Mode or "Always"):lower(), "TextDim"
		elseif column == "Key" then
			return Void.Keybinds.Label(bind.Descriptor), "Accent"
		elseif column == "State" then
			if bind.Mode == "Always" then return "—", "TextDark" end
			return bind.State and "on" or "off", bind.State and "Success" or "TextDark"
		elseif column == "Hits" then
			return tostring(bind.Hits or 0), "TextDim"
		elseif column == "Category" then
			return tostring(bind.Category or "—"), "TextDim"
		elseif column == "LastUsed" then
			if not bind.LastUsed then return "never", "TextDark" end
			local ago = os.clock() - bind.LastUsed
			if ago < 1 then return "now", "Success" end
			if ago < 60 then return ("%ds"):format(math.floor(ago)), "TextDim" end
			return ("%dm"):format(math.floor(ago / 60)), "TextDark"
		end
		return "", "TextDim"
	end

	function Instance_:Refresh()
		local binds = Void.Keybinds:ActiveList()
		if self._onlyActive then
			local filtered = {}
			for _, bind in ipairs(binds) do
				if bind.Mode == "Always" or bind.State then filtered[#filtered + 1] = bind end
			end
			binds = filtered
		end

		for _, row in ipairs(self._rows) do
			pcall(function() row.Instance:Destroy() end)
		end
		table.clear(self._rows)

		for index, bind in ipairs(binds) do
			local rowFrame = Util.New("Frame", {
				Name = "Row" .. index,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, Scale.u(14)),
				LayoutOrder = index,
				Parent = self._rowHolder,
			})
			local cells = {}
			local x = 0
			for _, column in ipairs(self._columns) do
				local width = COLUMN_WIDTH[column] or 0.2
				local text, token = cellText(column, bind)
				local label = Util.New("TextLabel", {
					Font = Theme:Font(column == "Key" and "FontMedium" or "Font"),
					Text = text,
					TextColor3 = Theme.C[token],
					TextSize = Scale.f(11),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Position = UDim2.fromScale(x, 0),
					Size = UDim2.fromScale(width, 1),
					Parent = rowFrame,
				})
				cells[column] = label
				x = x + width
			end
			table.insert(self._rows, { Instance = rowFrame, Bind = bind, Cells = cells })
		end

		self._countLabel.Text = tostring(#binds)
		self._empty.Visible = #binds == 0
		self._columnHeader.Visible = #binds > 0

		if self._hideEmpty then
			local shouldShow = #binds > 0
			if shouldShow ~= self._canvas.Visible then
				if shouldShow then self:Show() else self:Hide() end
			end
		end
		return self
	end

	-- Only rewrites the volatile cells; no instance churn.
	function Instance_:_refreshDynamic()
		for _, row in ipairs(self._rows) do
			for _, column in ipairs({ "State", "Hits", "LastUsed" }) do
				local cell = row.Cells[column]
				if cell then
					local text, token = cellText(column, row.Bind)
					if cell.Text ~= text then
						cell.Text = text
						cell.TextColor3 = Theme.C[token]
					end
				end
			end
		end
	end

	function Instance_:Configure(cfg)
		cfg = cfg or {}
		if cfg.Columns then self._columns = cfg.Columns self:_buildColumnHeader() end
		if cfg.Position then
			local anchor = ANCHORS[cfg.Position]
			if anchor then
				self._position = cfg.Position
				self._canvas.AnchorPoint = anchor.Anchor
				self._canvas.Position = anchor.Pos
			end
		end
		if cfg.Title then
			self._title = cfg.Title
			self._titleLabel.Text = cfg.Title
		end
		if cfg.HideEmpty ~= nil then self._hideEmpty = cfg.HideEmpty end
		if cfg.OnlyActive ~= nil then self._onlyActive = cfg.OnlyActive end
		self:Refresh()
		return self
	end

	function Instance_:Show()
		self._visible = true
		self._canvas.Visible = true
		Util.Tween(self._canvas, { GroupTransparency = 0 }, Util.Motion.Normal)
		return self
	end

	function Instance_:Hide()
		self._visible = false
		Util.Tween(self._canvas, { GroupTransparency = 1 }, Util.Motion.Normal)
		task.delay(Util.Motion.Normal + 0.05, function()
			if not self._visible and self._canvas then self._canvas.Visible = false end
		end)
		return self
	end

	function Instance_:Toggle()
		if self._visible then self:Hide() else self:Show() end
		return self._visible
	end

	function Instance_:Destroy()
		self._maid:Destroy()
		if Keylist._instance == self then Keylist._instance = nil end
	end

	function Keylist:Get()
		return self._instance
	end

	function Keylist:Destroy()
		if self._instance then self._instance:Destroy() end
	end

	Void.Keylist = Keylist
	return Keylist
end
