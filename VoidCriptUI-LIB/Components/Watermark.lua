--[[
	VoidCriptUI · Components/Watermark.lua
	Configurable watermark with a module system (roadmap #41).

	Built-in modules: logo, title, user, fps, fps1, ping, memory, time, game,
	version, instances. Order and separator are configurable, and any script
	can add its own module:

		VoidLib.Watermark:RegisterModule("hp", function()
			local h = game.Players.LocalPlayer.Character
			return h and ("HP " .. math.floor(h.Humanoid.Health)) or nil
		end, { Interval = 0.5, Color = "Success" })

		VoidLib:Watermark({
			Title = "voidcript",
			Modules = { "logo", "title", "user", "fps", "ping", "time" },
			Separator = " │ ",
			Position = "TopRight",
			Draggable = true,
		})

	Each module declares its own refresh interval; the component runs ONE
	Heartbeat-driven accumulator and only re-renders when a module's text
	actually changed, so a static watermark costs nothing.
]]

return function(Void)
	local RunService = game:GetService("RunService")
	local Players = game:GetService("Players")
	local Util, Theme, Scale = Void.Util, Void.Theme, Void.Scale

	local Watermark = {
		_modules = {},
		_instance = nil,
	}

	local WATERMARK_IMAGE = "https://github.com/WorkAccount211/VoidCriptUI_lib-Final-/blob/main/images/Watermark.png?raw=true"

	-- ── built-in modules ────────────────────────────────────────────────
	-- provider() returns a string (or nil to hide the segment)
	function Watermark:RegisterModule(name, provider, options)
		if type(name) ~= "string" or type(provider) ~= "function" then
			Void.Log:Warn("Watermark:RegisterModule(name, provider) got bad arguments")
			return false
		end
		options = options or {}
		self._modules[name:lower()] = {
			Name = name,
			Provider = provider,
			Interval = options.Interval or 0.5,
			Color = options.Color,     -- theme token name
			Icon = options.Icon,
			Static = options.Static or false,
			_clock = 0,
			_cache = nil,
		}
		if self._instance then self._instance:Rebuild() end
		return true
	end

	function Watermark:RemoveModule(name)
		self._modules[tostring(name):lower()] = nil
		if self._instance then self._instance:Rebuild() end
	end

	function Watermark:ListModules()
		local out = {}
		for name in pairs(self._modules) do out[#out + 1] = name end
		table.sort(out)
		return out
	end

	local function registerBuiltins()
		Watermark:RegisterModule("title", function(state)
			return state.Title or "voidcript"
		end, { Static = true, Color = "Text" })

		Watermark:RegisterModule("version", function()
			return "v" .. tostring(Void.Version or "2.0.0")
		end, { Static = true, Color = "TextDim" })

		Watermark:RegisterModule("user", function()
			local player = Players.LocalPlayer
			return player and player.Name or "player"
		end, { Static = true, Color = "TextDim" })

		Watermark:RegisterModule("displayname", function()
			local player = Players.LocalPlayer
			return player and player.DisplayName or nil
		end, { Static = true, Color = "TextDim" })

		Watermark:RegisterModule("fps", function()
			return ("%d fps"):format(Void.Profiler.FPS)
		end, { Interval = 0.5, Color = "Text" })

		Watermark:RegisterModule("fps1", function()
			return ("1%% low %d"):format(Void.Profiler.Low1)
		end, { Interval = 1, Color = "TextDim" })

		Watermark:RegisterModule("frametime", function()
			return ("%.1f ms"):format(Void.Profiler.FrameTimeMs)
		end, { Interval = 0.5, Color = "TextDim" })

		Watermark:RegisterModule("ping", function()
			return ("%d ms"):format(Void.Profiler.Ping)
		end, { Interval = 1, Color = "Text" })

		Watermark:RegisterModule("memory", function()
			return ("%d mb"):format(Void.Profiler.Memory)
		end, { Interval = 2, Color = "TextDim" })

		Watermark:RegisterModule("time", function()
			local t = os.date("*t")
			return ("%02d:%02d:%02d"):format(t.hour, t.min, t.sec)
		end, { Interval = 1, Color = "TextDim" })

		Watermark:RegisterModule("date", function()
			return os.date("%d.%m.%Y")
		end, { Interval = 30, Color = "TextDim" })

		Watermark:RegisterModule("game", function()
			return "place " .. tostring(game.PlaceId)
		end, { Static = true, Color = "TextDim" })

		Watermark:RegisterModule("instances", function()
			local count = Void.Profiler.InstanceCount
			return count > 0 and ("%d inst"):format(count) or nil
		end, { Interval = 10, Color = "TextDark" })
	end

	-- ── instance ────────────────────────────────────────────────────────
	local Instance_ = {}
	Instance_.__index = Instance_

	local ANCHORS = {
		TopRight    = { Anchor = Vector2.new(1, 0), Pos = UDim2.new(1, -12, 0, 12) },
		TopLeft     = { Anchor = Vector2.new(0, 0), Pos = UDim2.new(0, 12, 0, 12) },
		BottomRight = { Anchor = Vector2.new(1, 1), Pos = UDim2.new(1, -12, 1, -12) },
		BottomLeft  = { Anchor = Vector2.new(0, 1), Pos = UDim2.new(0, 12, 1, -12) },
		TopCenter   = { Anchor = Vector2.new(0.5, 0), Pos = UDim2.new(0.5, 0, 0, 12) },
	}

	function Watermark:Create(cfg)
		cfg = cfg or {}
		if self._instance then
			self._instance:Configure(cfg)
			self._instance:Show()
			return self._instance
		end

		local self_ = setmetatable({
			_maid = Void.Maid.new("Watermark"),
			_state = {
				Title = cfg.Title or "voidcript",
				Subtitle = cfg.Subtitle,
			},
			_order = cfg.Modules or { "logo", "title", "user", "fps", "ping", "time" },
			_separator = cfg.Separator or "  │  ",
			_position = cfg.Position or "TopRight",
			_showLogo = cfg.Logo ~= false,
			_segments = {},
			_visible = true,
		}, Instance_)

		local gui = Util.Screen("VoidCriptWatermark")
		gui.DisplayOrder = 98000
		self_._gui = gui
		self_._maid:Give(gui)

		local anchor = ANCHORS[self_._position] or ANCHORS.TopRight
		local canvas = Util.New("CanvasGroup", {
			Name = "Canvas",
			BackgroundTransparency = 1,
			GroupTransparency = 1,
			AnchorPoint = anchor.Anchor,
			Position = anchor.Pos,
			Size = UDim2.fromOffset(Scale.u(200), Scale.u(26)),
			AutomaticSize = Enum.AutomaticSize.X,
			Parent = gui,
		})
		self_._canvas = canvas

		local card = Util.New("Frame", {
			Name = "Card",
			BackgroundColor3 = Theme.C.Header,
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			Parent = canvas,
		})
		Theme:Paint(card, { BackgroundColor3 = "Header" })
		Util.Corner(card, Theme.Style.RadiusSmall + 1)
		local stroke = Util.Stroke(card, Theme.C.Outline)
		Theme:Paint(stroke, { Color = "Outline" })
		Util.Glass(card, 0.965)
		self_._card = card

		-- accent line on top (CompKiller signature)
		local accent = Util.New("Frame", {
			BackgroundColor3 = Theme.C.Accent,
			Size = UDim2.new(1, 0, 0, 1),
			ZIndex = 4,
			Parent = card,
		})
		Theme:Paint(accent, { BackgroundColor3 = "Accent" })

		local row = Util.New("Frame", {
			Name = "Row",
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			Parent = card,
		}, {
			Util.New("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 0),
			}),
			Util.New("UIPadding", {
				PaddingLeft = UDim.new(0, Scale.u(9)), PaddingRight = UDim.new(0, Scale.u(10)),
			}),
		})
		self_._row = row

		if cfg.Draggable ~= false then
			local handle = Util.New("TextButton", {
				Name = "DragHandle",
				BackgroundTransparency = 1,
				Text = "",
				Size = UDim2.fromScale(1, 1),
				ZIndex = 6,
				Parent = card,
			})
			Util.Draggable(handle, canvas, self_._maid, function(position)
				self_._customPosition = position
			end)
		end

		self_:Rebuild()

		-- single accumulator loop
		local accum = 0
		self_._maid:Give(RunService.Heartbeat:Connect(function(dt)
			if not self_._visible then return end
			accum = accum + dt
			if accum < 0.1 then return end -- cap at 10 Hz max
			local elapsed = accum
			accum = 0
			self_:_tick(elapsed)
		end))

		self_._maid:Give(Void.Scale:OnChanged(function()
			self_:Rebuild()
		end))

		Util.Tween(canvas, { GroupTransparency = 0 }, Util.Motion.Slow)
		Watermark._instance = self_
		return self_
	end

	function Instance_:Configure(cfg)
		cfg = cfg or {}
		if cfg.Title then self._state.Title = cfg.Title end
		if cfg.Modules then self._order = cfg.Modules end
		if cfg.Separator then self._separator = cfg.Separator end
		if cfg.Position then self:SetPosition(cfg.Position) end
		if cfg.Logo ~= nil then self._showLogo = cfg.Logo ~= false end
		self:Rebuild()
		return self
	end

	function Instance_:SetPosition(position)
		local anchor = ANCHORS[position]
		if not anchor then
			Void.Log:Warn("unknown watermark position '%s'", tostring(position))
			return self
		end
		self._position = position
		self._canvas.AnchorPoint = anchor.Anchor
		self._canvas.Position = anchor.Pos
		return self
	end

	-- Rebuild the segment list. Called on config/module/theme/scale changes,
	-- never per tick.
	function Instance_:Rebuild()
		for _, segment in ipairs(self._segments) do
			pcall(function() segment.Instance:Destroy() end)
			if segment.Separator then pcall(function() segment.Separator:Destroy() end)	end
		end
		table.clear(self._segments)

		local order = 0
		local function nextOrder()
			order = order + 1
			return order
		end

		local first = true
		for _, moduleName in ipairs(self._order) do
			local key = tostring(moduleName):lower()

			if key == "logo" then
				if self._showLogo then
					local logo = Util.New("ImageLabel", {
						Name = "Logo",
						Image = WATERMARK_IMAGE,
						ScaleType = Enum.ScaleType.Fit,
						Size = UDim2.fromOffset(Scale.u(15), Scale.u(15)),
						LayoutOrder = nextOrder(),
						Parent = self._row,
					}, {
						Util.New("UIPadding", { PaddingRight = UDim.new(0, Scale.u(7)) }),
					})
					table.insert(self._segments, { Instance = logo, Module = nil })
					first = false
				end
			else
				local moduleDef = Watermark._modules[key]
				if not moduleDef then
					Void.Log:Warn("watermark module '%s' is not registered", tostring(moduleName))
				else
					local separator
					if not first then
						separator = Util.New("TextLabel", {
							Name = "Sep",
							Font = Theme:Font("Font"),
							Text = self._separator,
							TextColor3 = Theme.C.OutlineStrong,
							TextSize = Scale.f(11),
							AutomaticSize = Enum.AutomaticSize.X,
							Size = UDim2.new(0, 0, 1, 0),
							LayoutOrder = nextOrder(),
							Parent = self._row,
						})
						Theme:Paint(separator, { TextColor3 = "OutlineStrong" })
					end

					local label = Util.New("TextLabel", {
						Name = "Seg_" .. key,
						Font = Theme:Font(moduleDef.Color == "Text" and "FontMedium" or "Font"),
						Text = "",
						TextColor3 = Theme.C[moduleDef.Color or "TextDim"],
						TextSize = Scale.f(11),
						AutomaticSize = Enum.AutomaticSize.X,
						Size = UDim2.new(0, 0, 1, 0),
						LayoutOrder = nextOrder(),
						Parent = self._row,
					})
					Theme:Paint(label, { TextColor3 = moduleDef.Color or "TextDim" })

					local segment = {
						Instance = label,
						Separator = separator,
						Module = moduleDef,
						Key = key,
						Clock = math.huge, -- force an immediate first render
					}
					table.insert(self._segments, segment)
					first = false
					self:_renderSegment(segment)
				end
			end
		end

		self._canvas.Size = UDim2.fromOffset(Scale.u(200), Scale.u(26))
		return self
	end

	function Instance_:_renderSegment(segment)
		local moduleDef = segment.Module
		if not moduleDef then return end
		local ok, value = pcall(moduleDef.Provider, self._state)
		if not ok then
			Void.Log:Debug("watermark module '%s' errored: %s", segment.Key, tostring(value))
			value = nil
		end
		if value == nil then
			-- hide the segment and its separator instead of showing "nil"
			segment.Instance.Visible = false
			if segment.Separator then segment.Separator.Visible = false end
			return
		end
		segment.Instance.Visible = true
		if segment.Separator then segment.Separator.Visible = true end
		local text = tostring(value)
		if segment.Cache ~= text then
			segment.Cache = text
			segment.Instance.Text = text
		end
	end

	function Instance_:_tick(dt)
		for _, segment in ipairs(self._segments) do
			local moduleDef = segment.Module
			if moduleDef and not moduleDef.Static then
				segment.Clock = (segment.Clock or 0) + dt
				if segment.Clock >= moduleDef.Interval then
					segment.Clock = 0
					self:_renderSegment(segment)
				end
			end
		end
	end

	function Instance_:SetTitle(title)
		self._state.Title = title
		for _, segment in ipairs(self._segments) do
			if segment.Key == "title" then
				segment.Cache = nil
				self:_renderSegment(segment)
			end
		end
		return self
	end

	function Instance_:SetState(key, value)
		self._state[key] = value
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

	function Instance_:IsVisible()
		return self._visible
	end

	function Instance_:Destroy()
		self._maid:Destroy()
		if Watermark._instance == self then Watermark._instance = nil end
	end

	function Watermark:Get()
		return self._instance
	end

	function Watermark:Destroy()
		if self._instance then self._instance:Destroy() end
	end

	registerBuiltins()
	Void.Watermark = Watermark
	return Watermark
end
