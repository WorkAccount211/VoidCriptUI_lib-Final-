--[[
	VoidCriptUI · Window/Section.lua
	Groupbox with CompKiller-style border title, plus lazy element building.

	Lazy loading
	------------
	Building 200 elements up front is what makes most libraries slow to open.
	Here, elements requested on a tab that has never been shown are not created:
	the call is recorded and a *deferred proxy* is returned. The proxy accepts
	every control method (`:Set`, `:Get`, `:SetVisible`, `:OnChanged`, …) and
	replays them the moment the tab is first opened and the real control exists.

	That means script authors write completely normal code:

		local speed = tab:CreateSection("Movement"):CreateSlider({ ... })
		speed:Set(120)            -- works even if the tab was never opened

	and the first frame only pays for the tab the user actually sees.

	Flags still resolve correctly because `Control:_finalise` picks up any value
	the config loader parked in `Flags.Values` for a not-yet-built element.
]]

return function(Void)
	local Util, Theme, Scale = Void.Util, Void.Theme, Void.Scale

	-- ── deferred proxy ──────────────────────────────────────────────────
	local function makeProxy(kind, cfg)
		local proxy = {
			_kind = kind,
			_cfg = cfg or {},
			_deferred = true,
			_queue = {},
			_real = nil,
			Name = (type(cfg) == "table" and cfg.Name) or kind,
			Flag = type(cfg) == "table" and cfg.Flag or nil,
		}

		function proxy:_resolve(real)
			self._real = real
			self._deferred = false
			for _, call in ipairs(self._queue) do
				local method = real[call.Method]
				if type(method) == "function" then
					local ok, err = pcall(method, real, table.unpack(call.Args, 1, call.Count))
					if not ok then
						Void.Log:Debug("deferred %s:%s failed: %s", kind, call.Method, tostring(err))
					end
				end
			end
			table.clear(self._queue)
			return real
		end

		return setmetatable(proxy, {
			__index = function(selfRef, key)
				local real = rawget(selfRef, "_real")
				if real then
					local value = real[key]
					if type(value) == "function" then
						return function(_, ...) return value(real, ...) end
					end
					return value
				end
				-- queue the call for replay after realisation
				return function(_, ...)
					table.insert(rawget(selfRef, "_queue"), {
						Method = key,
						Args = table.pack(...),
						Count = select("#", ...),
					})
					return selfRef
				end
			end,
		})
	end

	-- ── section ─────────────────────────────────────────────────────────
	function Void.MakeSection(tab, cfg)
		if type(cfg) == "string" then cfg = { Name = cfg } end
		cfg = cfg or {}

		local window = tab._window
		local subKey = tab:_resolveSubtab(cfg.Subtab)
		local subtab = tab._subtabs[subKey]
		if not subtab then
			Void.Log:Error("section '%s': subtab '%s' does not exist", tostring(cfg.Name), tostring(cfg.Subtab))
			subKey = tab._defaultSubtab
			subtab = tab._subtabs[subKey]
		end

		local column
		if Scale:Columns() == 1 then
			column = subtab.Columns[1]
		else
			local side = tostring(cfg.Side or ""):lower()
			if side == "right" or side == "r" or cfg.Column == 2 then
				column = subtab.Columns[2]
			elseif side == "left" or side == "l" or cfg.Column == 1 then
				column = subtab.Columns[1]
			else
				-- auto-balance: put it in the shorter column
				column = (#subtab.Sections % 2 == 0) and subtab.Columns[1] or subtab.Columns[2]
			end
		end

		local Section = {
			Name = cfg.Name or "Section",
			_tab = tab,
			_window = window,
			_cfg = cfg,
			_subKey = subKey,
			_maid = Void.Maid.new("Section:" .. tostring(cfg.Name)),
			_built = false,
			_pending = {},
			_column = column,
			_sections = subtab.Sections,
		}
		tab._maid:Give(Section._maid)

		-- ── construction (may be deferred) ──────────────────────────────
		function Section:_build()
			if self._built then return self end
			self._built = true
			Void.Profiler:Begin("section:build")

			local box = Util.New("Frame", {
				Name = "Section",
				BackgroundColor3 = Theme.C.Section,
				Size = UDim2.new(1, 0, 0, cfg.Height and Scale.u(cfg.Height) or 0),
				AutomaticSize = cfg.Height and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
				LayoutOrder = cfg.LayoutOrder or (#self._sections + 1),
				Parent = self._column,
			})
			Theme:Paint(box, { BackgroundColor3 = "Section" })
			Util.Corner(box, Theme.Style.Radius)
			local stroke = Util.Stroke(box, Theme.C.OutlineSoft)
			Theme:Paint(stroke, { Color = "OutlineSoft" })
			self._root = box
			self._stroke = stroke

			-- CompKiller groupbox title: sits on the border line
			local titleHolder = Util.New("Frame", {
				Name = "Title",
				BackgroundColor3 = Theme.C.Section,
				Position = UDim2.fromOffset(Scale.u(10), -Scale.u(7)),
				Size = UDim2.fromOffset(0, Scale.u(14)),
				AutomaticSize = Enum.AutomaticSize.X,
				ZIndex = 3,
				Parent = box,
			}, {
				Util.New("UIPadding", {
					PaddingLeft = UDim.new(0, Scale.u(5)), PaddingRight = UDim.new(0, Scale.u(5)),
				}),
			})
			Theme:Paint(titleHolder, { BackgroundColor3 = "Section" })

			local titleLabel = Util.New("TextLabel", {
				Name = "Text",
				BackgroundTransparency = 1,
				Font = Theme:Font("FontMedium"),
				Text = tostring(cfg.Name or "Section"),
				TextColor3 = Theme.C.Text,
				TextSize = Scale:Font("FontBody"),
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, Scale.u(14)),
				ZIndex = 3,
				Parent = titleHolder,
			})
			Theme:Paint(titleLabel, { TextColor3 = "Text" })
			self._titleLabel = titleLabel

			-- optional icon in the title
			if cfg.Icon then
				local kind, value = Void.Icons:Resolve(cfg.Icon)
				if kind == "text" then
					titleLabel.Text = value .. "  " .. tostring(cfg.Name or "Section")
				end
			end

			local pad = Scale:Metric("Pad")
			local elementsParent
			if cfg.Height then
				elementsParent = Util.New("ScrollingFrame", {
					Name = "Elements",
					Position = UDim2.fromOffset(0, Scale.u(12)),
					Size = UDim2.new(1, 0, 1, -Scale.u(18)),
					ScrollBarThickness = Scale.M.ScrollBar,
					ScrollBarImageColor3 = Theme.C.Accent,
					Parent = box,
				})
				Theme:Paint(elementsParent, { ScrollBarImageColor3 = "Accent" })
			else
				elementsParent = Util.New("Frame", {
					Name = "Elements",
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(0, Scale.u(12)),
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					Parent = box,
				})
			end
			Util.List(elementsParent, Scale:Metric("RowGap"))
			Util.New("UIPadding", {
				PaddingLeft = UDim.new(0, pad), PaddingRight = UDim.new(0, pad),
				PaddingTop = UDim.new(0, Scale.u(5)), PaddingBottom = UDim.new(0, pad),
				Parent = elementsParent,
			})
			self._elementsParent = elementsParent

			-- element host
			local host = Void.MakeElementHost({
				Window = window,
				Tab = tab,
				Section = self,
				Parent = elementsParent,
				Maid = self._maid,
				Name = cfg.Name,
			})
			self._host = host

			Void.Profiler:End()
			Void.Plugins:Fire("OnSection", self)
			return self
		end

		-- Flush queued element requests once the section is real.
		function Section:_flush()
			if not self._built then self:_build() end
			if #self._pending == 0 then return self end

			Void.Profiler:Begin("section:flush")
			local pending = self._pending
			self._pending = {}
			for _, request in ipairs(pending) do
				local method = self._host["Create" .. request.Kind]
				if type(method) == "function" then
					local control = method(self._host, request.Cfg)
					if control then
						request.Proxy:_resolve(control)
					end
				else
					Void.Log:Warn("section '%s': cannot build deferred '%s'", tostring(self.Name), request.Kind)
				end
			end
			Void.Profiler:End()
			return self
		end

		-- Every Create* call routes through here.
		local function request(kind, cfgArg)
			if Section._built and Section._host then
				local method = Section._host["Create" .. kind]
				if type(method) ~= "function" then
					Void.Log:Warn("unknown element type '%s'", kind)
					return nil
				end
				return method(Section._host, cfgArg)
			end
			-- deferred
			local proxy = makeProxy(kind, cfgArg)
			table.insert(Section._pending, { Kind = kind, Cfg = cfgArg, Proxy = proxy })
			return proxy
		end
		Section._request = request

		-- Public Create* surface (mirrors the host, works before building).
		local ELEMENTS = {
			"Toggle", "Slider", "RangeSlider", "Knob", "Dropdown", "MultiDropdown",
			"Input", "Textbox", "TextBox", "Keybind", "Bind", "ColorPicker",
			"ColourPicker", "Button", "ImageButton", "Label", "Paragraph",
			"Divider", "ProgressBar", "Image", "ListBox", "Table", "Collapsible",
		}
		for _, kind in ipairs(ELEMENTS) do
			local canonical = kind
			if kind == "TextBox" then canonical = "Textbox" end
			if kind == "ColourPicker" then canonical = "ColorPicker" end
			Section["Create" .. kind] = function(_, elementCfg)
				return request(canonical, elementCfg)
			end
		end
		Section.AddToggle = Section.CreateToggle
		Section.AddSlider = Section.CreateSlider
		Section.AddButton = Section.CreateButton
		Section.AddDropdown = Section.CreateDropdown
		Section.AddInput = Section.CreateInput
		Section.AddKeybind = Section.CreateKeybind
		Section.AddColorPicker = Section.CreateColorPicker
		Section.AddLabel = Section.CreateLabel
		Section.AddParagraph = Section.CreateParagraph
		Section.AddDivider = Section.CreateDivider

		-- ── section-level API ───────────────────────────────────────────
		function Section:SetName(name)
			self.Name = name
			if self._titleLabel then self._titleLabel.Text = tostring(name) end
			return self
		end

		function Section:SetVisible(state)
			if self._root then self._root.Visible = state and true or false end
			self._visible = state
			return self
		end

		function Section:IsVisible()
			return self._root and self._root.Visible or false
		end

		function Section:Clear()
			if self._host then self._host:Clear() end
			table.clear(self._pending)
			return self
		end

		function Section:GetElements()
			return self._host and self._host:GetElements() or {}
		end

		function Section:FindElement(name)
			return self._host and self._host:FindElement(name) or nil
		end

		function Section:_invalidate()
			-- AutomaticSize handles resizing; this hook exists so future
			-- layout strategies (virtualised lists) can plug in.
			return self
		end

		function Section:_removeElement(control)
			if self._host then self._host:_removeElement(control) end
		end

		function Section:Destroy()
			self._maid:Destroy()
			if self._root then
				Theme:Unpaint(self._root)
				self._root:Destroy()
			end
			for i = #self._sections, 1, -1 do
				if self._sections[i] == self then table.remove(self._sections, i) end
			end
			for i = #tab._sections, 1, -1 do
				if tab._sections[i] == self then table.remove(tab._sections, i) end
			end
		end

		-- Plugin elements before the section is built.
		setmetatable(Section, {
			__index = function(_, key)
				local elementName = tostring(key):match("^Create(.+)$")
				if elementName then
					return function(_, elementCfg)
						return request(elementName, elementCfg)
					end
				end
				return nil
			end,
		})

		table.insert(subtab.Sections, Section)
		table.insert(tab._sections, Section)

		-- Build immediately when the tab is already live (or lazy is off).
		if tab._built and (tab._active or not window._lazy) then
			Section:_build()
		elseif not window._lazy then
			Section:_build()
		end

		return Section
	end
end
