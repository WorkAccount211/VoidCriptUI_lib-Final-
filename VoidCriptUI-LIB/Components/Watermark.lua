--[[
    VoidCriptUI · Components/Watermark.lua
    Visual HUD watermark inspired by the VoidCript showcase artwork.

    Important:
      - Player is read from Roblox at runtime (Players.LocalPlayer.Name).
      - No hard-coded player name is used.
      - FPS/Ping/Time/Date are updated independently.
      - Custom watermark modules remain supported.
      - The UI is built from Roblox instances; the generated Watermark.png is
        intended as artwork/preview, not as a static replacement for the HUD.
]]

return function(Void)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")

    local Util = Void.Util
    local Theme = Void.Theme
    local Scale = Void.Scale

    local Watermark = {
        _modules = {},
        _instance = nil,
    }

    local SYMBOL = "https://raw.githubusercontent.com/WorkAccount211/VoidCriptUI_lib-Final-/main/images/symbol.png"

    local DEFAULT_ORDER = {
        "clock",
        "player",
        "fps",
        "ping",
    }

    local ANCHORS = {
        TopRight    = { Anchor = Vector2.new(1, 0), Pos = UDim2.new(1, -12, 0, 12) },
        TopLeft     = { Anchor = Vector2.new(0, 0), Pos = UDim2.new(0, 12, 0, 12) },
        BottomRight = { Anchor = Vector2.new(1, 1), Pos = UDim2.new(1, -12, 1, -12) },
        BottomLeft  = { Anchor = Vector2.new(0, 1), Pos = UDim2.new(0, 12, 1, -12) },
        TopCenter   = { Anchor = Vector2.new(0.5, 0), Pos = UDim2.new(0.5, 0, 0, 12) },
    }

    local function safePlayerName()
        local player = Players.LocalPlayer
        if not player then
            return "Player"
        end
        return player.Name
    end

    local function safeDisplayName()
        local player = Players.LocalPlayer
        if not player then
            return "Player"
        end
        return player.DisplayName
    end

    local function textLabel(parent, props)
        props = props or {}
        props.Parent = parent
        return Util.New("TextLabel", props)
    end

    local function frame(parent, props, children)
        props = props or {}
        props.Parent = parent
        return Util.New("Frame", props, children)
    end

    local function bindTheme(instance, map)
        Theme:Paint(instance, map)
        return instance
    end

    function Watermark:RegisterModule(name, provider, options)
        if type(name) ~= "string" or type(provider) ~= "function" then
            Void.Log:Warn("Watermark:RegisterModule(name, provider) got bad arguments")
            return false
        end

        options = options or {}
        self._modules[name:lower()] = {
            Name = name,
            Provider = provider,
            Interval = tonumber(options.Interval) or 0.5,
            Color = options.Color or "TextDim",
            Icon = options.Icon,
            Static = options.Static == true,
        }

        if self._instance then
            self._instance:RebuildModules()
        end

        return true
    end

    function Watermark:RemoveModule(name)
        self._modules[tostring(name):lower()] = nil
        if self._instance then
            self._instance:RebuildModules()
        end
    end

    function Watermark:ListModules()
        local result = {}
        for name in pairs(self._modules) do
            result[#result + 1] = name
        end
        table.sort(result)
        return result
    end

    local function registerBuiltins()
        Watermark:RegisterModule("clock", function()
            local t = os.date("*t")
            return string.format("%02d:%02d:%02d", t.hour, t.min, t.sec)
        end, { Interval = 1, Color = "Text" })

        Watermark:RegisterModule("date", function()
            return os.date("%b %d, %Y")
        end, { Interval = 30, Color = "Accent" })

        Watermark:RegisterModule("player", function()
            return safePlayerName()
        end, { Interval = 2, Color = "TextDim" })

        Watermark:RegisterModule("displayname", function()
            return safeDisplayName()
        end, { Interval = 2, Color = "TextDim" })

        Watermark:RegisterModule("fps", function()
            return tostring(math.max(0, math.floor(tonumber(Void.Profiler.FPS) or 0)))
        end, { Interval = 0.5, Color = "Text" })

        Watermark:RegisterModule("ping", function()
            return tostring(math.max(0, math.floor(tonumber(Void.Profiler.Ping) or 0))) .. " ms"
        end, { Interval = 1, Color = "Text" })

        Watermark:RegisterModule("version", function()
            return "v" .. tostring(Void.Version or "3.0.0")
        end, { Static = true, Color = "Text" })

        Watermark:RegisterModule("game", function()
            return tostring(game.PlaceId)
        end, { Static = true, Color = "TextDim" })

        Watermark:RegisterModule("memory", function()
            return tostring(math.max(0, math.floor(tonumber(Void.Profiler.Memory) or 0))) .. " MB"
        end, { Interval = 2, Color = "TextDim" })
    end

    local Instance_ = {}
    Instance_.__index = Instance_

    function Watermark:Create(cfg)
        cfg = cfg or {}

        if self._instance then
            self._instance:Configure(cfg)
            self._instance:Show()
            return self._instance
        end

        local self_ = setmetatable({
            _maid = Void.Maid.new("Watermark"),
            _visible = cfg.Visible ~= false,
            _position = cfg.Position or "TopRight",
            _title = cfg.Title or "VOIDCRIPT",
            _creator = cfg.Creator or "VoidCript",
            _version = cfg.Version or ("v" .. tostring(Void.Version or "3.0.0")),
            _logo = cfg.Logo ~= false,
            _showDate = cfg.ShowDate ~= false,
            _showClock = cfg.ShowClock ~= false,
            _showFPS = cfg.ShowFPS ~= false,
            _showPing = cfg.ShowPing ~= false,
            _playerLabel = cfg.PlayerLabel or "Player",
            _order = cfg.Modules or DEFAULT_ORDER,
            _userModules = {},
            _updateClock = 0,
            _customPosition = nil,
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
            Size = UDim2.fromOffset(Scale.u(650), Scale.u(76)),
            Parent = gui,
        })
        self_._canvas = canvas

        local shadow = frame(canvas, {
            Name = "Shadow",
            Position = UDim2.fromOffset(Scale.u(2), Scale.u(3)),
            Size = UDim2.new(1, -Scale.u(2), 1, -Scale.u(3)),
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 0.72,
            ZIndex = 1,
        })
        Util.Corner(shadow, Scale.u(12))

        local card = frame(canvas, {
            Name = "Card",
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Theme.C.Header,
            ZIndex = 2,
        })
        Util.Corner(card, Scale.u(12))
        local stroke = Util.Stroke(card, Theme.C.Accent, Scale.u(1), 0.2)
        bindTheme(card, { BackgroundColor3 = "Header" })
        bindTheme(stroke, { Color = "Accent" })
        Util.Glass(card, 0.965)
        self_._card = card

        local accent = frame(card, {
            Name = "AccentLine",
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(1, 0, 0, Scale.u(1)),
            BackgroundColor3 = Theme.C.Accent,
            ZIndex = 8,
        })
        bindTheme(accent, { BackgroundColor3 = "Accent" })

        local left = frame(card, {
            Name = "LogoPanel",
            Position = UDim2.fromOffset(Scale.u(4), Scale.u(4)),
            Size = UDim2.fromOffset(Scale.u(68), Scale.u(68)),
            BackgroundColor3 = Theme.C.Background,
            ZIndex = 3,
        })
        Util.Corner(left, Scale.u(10))
        local leftStroke = Util.Stroke(left, Theme.C.OutlineStrong, 1, 0.25)
        bindTheme(left, { BackgroundColor3 = "Background" })
        bindTheme(leftStroke, { Color = "OutlineStrong" })

        if self_._logo then
            local glow = Util.New("ImageLabel", {
                Name = "Glow",
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                Image = SYMBOL,
                ImageColor3 = Theme.C.Accent,
                ImageTransparency = 0.84,
                ZIndex = 4,
                Parent = left,
            })
            bindTheme(glow, { ImageColor3 = "Accent" })

            Util.New("ImageLabel", {
                Name = "Symbol",
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.new(1, -Scale.u(12), 1, -Scale.u(12)),
                BackgroundTransparency = 1,
                Image = SYMBOL,
                ScaleType = Enum.ScaleType.Fit,
                ZIndex = 5,
                Parent = left,
            })
        end

        local body = frame(card, {
            Name = "Body",
            Position = UDim2.fromOffset(Scale.u(80), Scale.u(7)),
            Size = UDim2.new(1, -Scale.u(85), 1, -Scale.u(12)),
            BackgroundTransparency = 1,
            ZIndex = 3,
        })

        textLabel(body, {
            Name = "Eyebrow",
            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.new(0.54, 0, 0, Scale.u(12)),
            Text = "UI  LIBRARY",
            Font = Theme:Font("FontMono"),
            TextSize = Scale.f(9),
            TextColor3 = Theme.C.TextDim,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 4,
        })

        local title = textLabel(body, {
            Name = "Title",
            Position = UDim2.fromOffset(0, Scale.u(11)),
            Size = UDim2.new(0.58, 0, 0, Scale.u(27)),
            Text = self_._title,
            Font = Theme:Font("FontBold"),
            TextSize = Scale.f(21),
            TextColor3 = Theme.C.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 4,
        })
        bindTheme(title, { TextColor3 = "Text" })

        textLabel(body, {
            Name = "Tagline",
            Position = UDim2.fromOffset(0, Scale.u(39)),
            Size = UDim2.new(0.6, 0, 0, Scale.u(14)),
            Text = "MODULAR  •  MODERN  •  ADAPTIVE",
            Font = Theme:Font("FontMedium"),
            TextSize = Scale.f(8),
            TextColor3 = Theme.C.Accent,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 4,
        })

        local right = frame(card, {
            Name = "Stats",
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -Scale.u(12), 0.5, 0),
            Size = UDim2.fromOffset(Scale.u(280), Scale.u(52)),
            BackgroundTransparency = 1,
            ZIndex = 3,
        })

        local grid = Util.New("UIGridLayout", {
            CellSize = UDim2.fromOffset(Scale.u(132), Scale.u(24)),
            CellPadding = UDim2.fromOffset(Scale.u(8), Scale.u(4)),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = right,
        })

        local function makeStat(name, labelText, accentText, order)
            local tile = frame(right, {
                Name = name,
                BackgroundColor3 = Theme.C.Background,
                BackgroundTransparency = 0.12,
                LayoutOrder = order,
                ZIndex = 4,
            })
            Util.Corner(tile, Scale.u(6))
            local tileStroke = Util.Stroke(tile, Theme.C.Outline, 1, 0.5)
            bindTheme(tile, { BackgroundColor3 = "Background" })
            bindTheme(tileStroke, { Color = "Outline" })

            textLabel(tile, {
                Name = "Label",
                Position = UDim2.fromOffset(Scale.u(7), Scale.u(3)),
                Size = UDim2.new(0.46, 0, 1, -Scale.u(6)),
                Text = labelText,
                Font = Theme:Font("FontMedium"),
                TextSize = Scale.f(7.5),
                TextColor3 = Theme.C.TextDark,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Center,
                ZIndex = 5,
            })

            local value = textLabel(tile, {
                Name = "Value",
                Position = UDim2.new(0.43, 0, 0, Scale.u(3)),
                Size = UDim2.new(0.53, -Scale.u(6), 1, -Scale.u(6)),
                Text = accentText,
                Font = Theme:Font("FontMedium"),
                TextSize = Scale.f(9),
                TextColor3 = Theme.C.Text,
                TextXAlignment = Enum.TextXAlignment.Right,
                TextYAlignment = Enum.TextYAlignment.Center,
                TextTruncate = Enum.TextTruncate.AtEnd,
                ZIndex = 5,
            })
            return value
        end

        self_._clockValue = makeStat("Clock", "TIME", "--:--:--", 1)
        self_._dateValue = makeStat("Date", "DATE", "---", 2)
        self_._playerValue = makeStat("Player", self_._playerLabel, safePlayerName(), 3)
        self_._fpsValue = makeStat("FPS", "FPS", "0", 4)
        self_._pingValue = makeStat("Ping", "PING", "0 ms", 5)
        self_._versionValue = makeStat("Version", "BUILD", self_._version, 6)

        local footer = frame(card, {
            Name = "Footer",
            Position = UDim2.fromOffset(Scale.u(82), Scale.u(57)),
            Size = UDim2.new(1, -Scale.u(94), 0, Scale.u(13)),
            BackgroundTransparency = 1,
            ZIndex = 4,
        })

        textLabel(footer, {
            Name = "Creator",
            Size = UDim2.new(0.5, 0, 1, 0),
            Text = "Built by " .. self_._creator,
            Font = Theme:Font("FontMono"),
            TextSize = Scale.f(7.5),
            TextColor3 = Theme.C.TextDim,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 5,
        })

        self_._footerVersion = textLabel(footer, {
            Position = UDim2.fromScale(0.5, 0),
            Size = UDim2.fromScale(0.5, 1),
            Text = self_._version,
            Font = Theme:Font("FontMono"),
            TextSize = Scale.f(7.5),
            TextColor3 = Theme.C.Accent,
            TextXAlignment = Enum.TextXAlignment.Right,
            ZIndex = 5,
        })
        bindTheme(self_._footerVersion, { TextColor3 = "Accent" })

        if cfg.Draggable ~= false then
            local handle = Util.New("TextButton", {
                Name = "DragHandle",
                BackgroundTransparency = 1,
                Text = "",
                Size = UDim2.fromScale(1, 1),
                ZIndex = 20,
                Parent = card,
            })
            Util.Draggable(handle, canvas, self_._maid, function(position)
                self_._customPosition = position
            end)
        end

        self_:RebuildModules()

        local themeDisconnect = Void.Theme:OnChanged(function()
            self_:Repaint()
        end)
        self_._maid:Give(themeDisconnect)

        self_._maid:Give(Void.Scale:OnChanged(function()
            self_:RebuildModules()
            self_:Repaint()
        end))

        self_._maid:Give(RunService.Heartbeat:Connect(function(dt)
            if not self_._visible then
                return
            end
            self_._updateClock += dt
            if self_._updateClock < 0.25 then
                return
            end
            self_._updateClock = 0
            self_:_updateRealtime()
        end))

        Watermark._instance = self_
        Util.Tween(canvas, { GroupTransparency = 0 }, Util.Motion.Slow)
        return self_
    end

    function Instance_:Repaint()
        if not self._card then return end
        bindTheme(self._card, { BackgroundColor3 = "Header" })
        local stroke = self._card:FindFirstChildOfClass("UIStroke")
        if stroke then bindTheme(stroke, { Color = "Accent" }) end
    end

    function Instance_:_updateRealtime()
        if self._clockValue then
            local t = os.date("*t")
            self._clockValue.Text = string.format("%02d:%02d:%02d", t.hour, t.min, t.sec)
        end
        if self._dateValue then
            self._dateValue.Text = os.date("%b %d, %Y")
        end
        if self._playerValue then
            self._playerValue.Text = safePlayerName()
        end
        if self._fpsValue then
            self._fpsValue.Text = tostring(math.max(0, math.floor(tonumber(Void.Profiler.FPS) or 0)))
        end
        if self._pingValue then
            self._pingValue.Text = tostring(math.max(0, math.floor(tonumber(Void.Profiler.Ping) or 0))) .. " ms"
        end
    end

    function Instance_:RebuildModules()
        -- The showcase watermark has fixed high-value stat slots. Custom modules
        -- are kept through the public module API and can be used by the compact
        -- legacy layout elsewhere; the core stats stay visually stable here.
        self:_updateRealtime()
        return self
    end

    function Instance_:Configure(cfg)
        cfg = cfg or {}
        if cfg.Title then
            self._title = tostring(cfg.Title)
            local title = self._card and self._card:FindFirstChild("Body") and self._card.Body:FindFirstChild("Title")
            if title then title.Text = self._title end
        end
        if cfg.Creator then self._creator = tostring(cfg.Creator) end
        if cfg.Version then self._version = tostring(cfg.Version) end
        if cfg.Position then self:SetPosition(cfg.Position) end
        if cfg.Logo ~= nil then self._logo = cfg.Logo ~= false end
        if cfg.Modules then self._order = cfg.Modules end
        self:_updateRealtime()
        return self
    end

    function Instance_:SetPosition(position)
        local anchor = ANCHORS[position]
        if not anchor then
            Void.Log:Warn("unknown watermark position '%s'", tostring(position))
            return self
        end
        self._position = position
        if self._canvas then
            self._canvas.AnchorPoint = anchor.Anchor
            self._canvas.Position = anchor.Pos
        end
        return self
    end

    function Instance_:SetVisible(value)
        if value then
            return self:Show()
        end
        return self:Hide()
    end

    function Instance_:SetTitle(title)
        self._title = tostring(title)
        if self._card and self._card:FindFirstChild("Body") then
            local label = self._card.Body:FindFirstChild("Title")
            if label then label.Text = self._title end
        end
        return self
    end

    function Instance_:SetState(key, value)
        self[key] = value
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
            if not self._visible and self._canvas then
                self._canvas.Visible = false
            end
        end)
        return self
    end

    function Instance_:Toggle()
        if self._visible then
            self:Hide()
        else
            self:Show()
        end
        return self._visible
    end

    function Instance_:IsVisible()
        return self._visible
    end

    function Instance_:Destroy()
        self._maid:Destroy()
        if Watermark._instance == self then
            Watermark._instance = nil
        end
    end

    function Watermark:Get()
        return self._instance
    end

    function Watermark:Destroy()
        if self._instance then
            self._instance:Destroy()
        end
    end

    registerBuiltins()
    Void.Watermark = Watermark
    return Watermark
end
