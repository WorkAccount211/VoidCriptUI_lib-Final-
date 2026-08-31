--[[
	VoidCriptUI · Core/Theme.lua
	Runtime re-themeable design tokens (roadmap #26, #27, #28, #29).

	Any instance created through `Theme:Paint(inst, map)` is registered in a
	weak-keyed registry together with the token each property should follow.
	`Theme:Set{...}` then repaints every live instance with a tween — no UI
	rebuild, no flicker, and destroyed instances are swept lazily.

	Tokens are intentionally flat so a whole theme is one table:

		VoidLib:SetTheme({
			Accent     = Color3.fromRGB(100, 0, 255),
			Background = Color3.fromRGB(20, 20, 20),
			Text       = Color3.fromRGB(255, 255, 255),
		})
]]

return function(Void)
	local Util = Void.Util

	local Theme = {
		_registry = setmetatable({}, { __mode = "k" }),
		_listeners = {},
		Name = "Midnight",
	}

	-- ── tokens ──────────────────────────────────────────────────────────
	Theme.Tokens = {
		Accent       = Color3.fromRGB(199, 62, 110),
		AccentDark   = Color3.fromRGB(140, 40, 78),
		AccentSoft   = Color3.fromRGB(232, 118, 158),
		Risky        = Color3.fromRGB(240, 196, 64),
		Danger       = Color3.fromRGB(224, 72, 72),
		Success      = Color3.fromRGB(80, 200, 120),

		Backdrop     = Color3.fromRGB(0, 0, 0),
		Background   = Color3.fromRGB(12, 12, 14),
		Sidebar      = Color3.fromRGB(9, 9, 11),
		Header       = Color3.fromRGB(15, 15, 17),
		Section      = Color3.fromRGB(16, 16, 18),
		Element      = Color3.fromRGB(24, 24, 27),
		ElementHover = Color3.fromRGB(32, 32, 36),
		ElementActive= Color3.fromRGB(40, 40, 46),
		Overlay      = Color3.fromRGB(20, 20, 23),

		Outline      = Color3.fromRGB(38, 38, 42),
		OutlineSoft  = Color3.fromRGB(28, 28, 32),
		OutlineStrong= Color3.fromRGB(56, 56, 64),

		Text         = Color3.fromRGB(232, 232, 238),
		TextDim      = Color3.fromRGB(138, 138, 148),
		TextDark     = Color3.fromRGB(92, 92, 102),
		TextOnAccent = Color3.fromRGB(255, 255, 255),
	}

	-- Non-colour tokens (fonts, radii, transparency) live here.
	Theme.Style = {
		Font        = Enum.Font.Gotham,
		FontMedium  = Enum.Font.GothamMedium,
		FontBold    = Enum.Font.GothamBold,
		FontMono    = Enum.Font.Code,
		Radius      = 5,
		RadiusSmall = 3,
		BackdropTransparency = 0.42,
		GlassStrength = 0.94,
		ShadowTransparency = 0.45,
	}

	-- ── presets (roadmap #27) ───────────────────────────────────────────
	Theme.Presets = {
		Midnight = {
			Accent = Color3.fromRGB(199, 62, 110), AccentDark = Color3.fromRGB(140, 40, 78),
			AccentSoft = Color3.fromRGB(232, 118, 158),
			Background = Color3.fromRGB(12, 12, 14), Sidebar = Color3.fromRGB(9, 9, 11),
			Header = Color3.fromRGB(15, 15, 17), Section = Color3.fromRGB(16, 16, 18),
			Element = Color3.fromRGB(24, 24, 27), ElementHover = Color3.fromRGB(32, 32, 36),
			ElementActive = Color3.fromRGB(40, 40, 46), Overlay = Color3.fromRGB(20, 20, 23),
			Outline = Color3.fromRGB(38, 38, 42), OutlineSoft = Color3.fromRGB(28, 28, 32),
			OutlineStrong = Color3.fromRGB(56, 56, 64),
			Text = Color3.fromRGB(232, 232, 238), TextDim = Color3.fromRGB(138, 138, 148),
			TextDark = Color3.fromRGB(92, 92, 102),
		},
		Blood = {
			Accent = Color3.fromRGB(214, 48, 49), AccentDark = Color3.fromRGB(138, 26, 28),
			AccentSoft = Color3.fromRGB(240, 112, 112),
			Background = Color3.fromRGB(14, 10, 10), Sidebar = Color3.fromRGB(10, 7, 7),
			Header = Color3.fromRGB(17, 12, 12), Section = Color3.fromRGB(18, 13, 13),
			Element = Color3.fromRGB(27, 19, 19), ElementHover = Color3.fromRGB(36, 25, 25),
			ElementActive = Color3.fromRGB(46, 31, 31), Overlay = Color3.fromRGB(22, 15, 15),
			Outline = Color3.fromRGB(46, 30, 30), OutlineSoft = Color3.fromRGB(32, 22, 22),
			OutlineStrong = Color3.fromRGB(64, 40, 40),
			Text = Color3.fromRGB(236, 228, 228), TextDim = Color3.fromRGB(152, 130, 130),
			TextDark = Color3.fromRGB(102, 86, 86),
		},
		Ocean = {
			Accent = Color3.fromRGB(56, 152, 219), AccentDark = Color3.fromRGB(32, 98, 145),
			AccentSoft = Color3.fromRGB(126, 196, 240),
			Background = Color3.fromRGB(10, 13, 16), Sidebar = Color3.fromRGB(8, 10, 13),
			Header = Color3.fromRGB(12, 16, 20), Section = Color3.fromRGB(14, 18, 22),
			Element = Color3.fromRGB(21, 27, 33), ElementHover = Color3.fromRGB(28, 36, 44),
			ElementActive = Color3.fromRGB(36, 46, 56), Overlay = Color3.fromRGB(16, 21, 26),
			Outline = Color3.fromRGB(36, 46, 55), OutlineSoft = Color3.fromRGB(26, 34, 41),
			OutlineStrong = Color3.fromRGB(50, 64, 76),
			Text = Color3.fromRGB(228, 235, 240), TextDim = Color3.fromRGB(126, 142, 152),
			TextDark = Color3.fromRGB(86, 100, 110),
		},
		Mono = {
			Accent = Color3.fromRGB(222, 222, 228), AccentDark = Color3.fromRGB(150, 150, 156),
			AccentSoft = Color3.fromRGB(240, 240, 244),
			Background = Color3.fromRGB(13, 13, 13), Sidebar = Color3.fromRGB(10, 10, 10),
			Header = Color3.fromRGB(16, 16, 16), Section = Color3.fromRGB(17, 17, 17),
			Element = Color3.fromRGB(25, 25, 25), ElementHover = Color3.fromRGB(33, 33, 33),
			ElementActive = Color3.fromRGB(42, 42, 42), Overlay = Color3.fromRGB(20, 20, 20),
			Outline = Color3.fromRGB(40, 40, 40), OutlineSoft = Color3.fromRGB(29, 29, 29),
			OutlineStrong = Color3.fromRGB(58, 58, 58),
			Text = Color3.fromRGB(232, 232, 232), TextDim = Color3.fromRGB(136, 136, 136),
			TextDark = Color3.fromRGB(92, 92, 92),
		},
		Toxic = {
			Accent = Color3.fromRGB(146, 226, 64), AccentDark = Color3.fromRGB(94, 150, 40),
			AccentSoft = Color3.fromRGB(190, 244, 130),
			Background = Color3.fromRGB(11, 14, 11), Sidebar = Color3.fromRGB(8, 11, 8),
			Header = Color3.fromRGB(14, 18, 14), Section = Color3.fromRGB(15, 19, 15),
			Element = Color3.fromRGB(22, 28, 22), ElementHover = Color3.fromRGB(30, 38, 30),
			ElementActive = Color3.fromRGB(38, 48, 38), Overlay = Color3.fromRGB(17, 22, 17),
			Outline = Color3.fromRGB(36, 46, 36), OutlineSoft = Color3.fromRGB(26, 33, 26),
			OutlineStrong = Color3.fromRGB(52, 66, 52),
			Text = Color3.fromRGB(230, 238, 228), TextDim = Color3.fromRGB(132, 148, 130),
			TextDark = Color3.fromRGB(90, 102, 88),
		},
		Amethyst = {
			Accent = Color3.fromRGB(150, 96, 255), AccentDark = Color3.fromRGB(98, 60, 176),
			AccentSoft = Color3.fromRGB(190, 156, 255),
			Background = Color3.fromRGB(13, 12, 17), Sidebar = Color3.fromRGB(10, 9, 14),
			Header = Color3.fromRGB(16, 15, 21), Section = Color3.fromRGB(17, 16, 23),
			Element = Color3.fromRGB(25, 23, 33), ElementHover = Color3.fromRGB(34, 31, 44),
			ElementActive = Color3.fromRGB(43, 39, 56), Overlay = Color3.fromRGB(20, 18, 27),
			Outline = Color3.fromRGB(40, 37, 52), OutlineSoft = Color3.fromRGB(29, 27, 38),
			OutlineStrong = Color3.fromRGB(58, 53, 76),
			Text = Color3.fromRGB(232, 230, 240), TextDim = Color3.fromRGB(140, 136, 156),
			TextDark = Color3.fromRGB(94, 90, 108),
		},
		Light = {
			Accent = Color3.fromRGB(180, 46, 96), AccentDark = Color3.fromRGB(130, 30, 68),
			AccentSoft = Color3.fromRGB(226, 118, 156),
			Background = Color3.fromRGB(242, 242, 245), Sidebar = Color3.fromRGB(232, 232, 236),
			Header = Color3.fromRGB(248, 248, 250), Section = Color3.fromRGB(250, 250, 252),
			Element = Color3.fromRGB(232, 232, 238), ElementHover = Color3.fromRGB(222, 222, 230),
			ElementActive = Color3.fromRGB(210, 210, 220), Overlay = Color3.fromRGB(252, 252, 254),
			Outline = Color3.fromRGB(206, 206, 214), OutlineSoft = Color3.fromRGB(222, 222, 230),
			OutlineStrong = Color3.fromRGB(180, 180, 190),
			Text = Color3.fromRGB(24, 24, 28), TextDim = Color3.fromRGB(96, 96, 108),
			TextDark = Color3.fromRGB(140, 140, 152),
		},
	}

	-- ── token access ────────────────────────────────────────────────────
	-- Theme.C is a live proxy: Theme.C.Accent always reads the current value,
	-- so element code never caches a stale colour.
	Theme.C = setmetatable({}, {
		__index = function(_, key)
			local v = Theme.Tokens[key]
			if v == nil then
				Void.Log:Debug("unknown theme token '%s'", tostring(key))
				return Theme.Tokens.Text
			end
			return v
		end,
		__newindex = function(_, key, value)
			Theme.Tokens[key] = value
		end,
	})

	function Theme:Get(token)
		return self.Tokens[token]
	end

	function Theme:Font(kind)
		return self.Style[kind or "Font"] or self.Style.Font
	end

	-- ── paint registry ──────────────────────────────────────────────────
	-- map = { PropertyName = "TokenName", ... }
	-- Example: Theme:Paint(frame, { BackgroundColor3 = "Section" })
	function Theme:Paint(inst, map)
		if not inst then return inst end
		local entry = self._registry[inst]
		if entry then
			for prop, token in pairs(map) do entry[prop] = token end
		else
			entry = {}
			for prop, token in pairs(map) do entry[prop] = token end
			self._registry[inst] = entry
		end
		for prop, token in pairs(map) do
			local value = self.Tokens[token]
			if value ~= nil then
				pcall(function() inst[prop] = value end)
			end
		end
		return inst
	end

	-- Stop tracking an instance (called by element:Destroy()).
	function Theme:Unpaint(inst)
		self._registry[inst] = nil
	end

	-- Register a callback that re-derives non-trivial visuals (gradients,
	-- ColorSequences, canvas tints) when the theme changes.
	function Theme:OnChanged(fn)
		table.insert(self._listeners, fn)
		return function()
			for i = #self._listeners, 1, -1 do
				if self._listeners[i] == fn then table.remove(self._listeners, i) end
			end
		end
	end

	local function normalise(value)
		if type(value) == "string" then
			local c = Util.FromHex(value)
			if c then return c end
			return nil
		end
		return value
	end

	-- Apply overrides and repaint everything that is alive.
	function Theme:Set(overrides, instant)
		if type(overrides) ~= "table" then
			Void.Log:Warn("SetTheme expects a table of tokens")
			return self
		end

		local touched = false
		for key, raw in pairs(overrides) do
			if self.Style[key] ~= nil and typeof(raw) ~= "Color3" and type(raw) ~= "string" then
				self.Style[key] = raw
				touched = true
			elseif key == "Font" or key == "FontMedium" or key == "FontBold" or key == "FontMono" then
				self.Style[key] = raw
				touched = true
			elseif self.Tokens[key] ~= nil then
				local value = normalise(raw)
				if value ~= nil then
					self.Tokens[key] = value
					touched = true
				else
					Void.Log:Warn("theme token '%s' got an invalid value", tostring(key))
				end
			elseif typeof(raw) == "Color3" or (type(raw) == "string" and Util.FromHex(raw)) then
				-- allow brand-new custom tokens for plugins
				self.Tokens[key] = normalise(raw)
				touched = true
			else
				Void.Log:Debug("ignoring unknown theme key '%s'", tostring(key))
			end
		end

		if not touched then return self end
		self:Repaint(instant)
		return self
	end

	function Theme:Repaint(instant)
		local dur = instant and 0 or Void.Util.Motion.Normal
		local dead = {}
		for inst, map in pairs(self._registry) do
			if typeof(inst) == "Instance" and inst.Parent ~= nil or typeof(inst) ~= "Instance" then
				for prop, token in pairs(map) do
					local value = self.Tokens[token]
					if value ~= nil then
						if dur > 0 and (prop:find("Color3") or prop:find("Colour")) then
							Util.Tween(inst, { [prop] = value }, dur)
						else
							pcall(function() inst[prop] = value end)
						end
					end
				end
			else
				dead[#dead + 1] = inst
			end
		end
		for _, inst in ipairs(dead) do self._registry[inst] = nil end

		for _, fn in ipairs(self._listeners) do
			local ok, err = pcall(fn, self.Tokens, self.Style)
			if not ok then Void.Log:Error("theme listener failed: %s", tostring(err)) end
		end
	end

	function Theme:SetPreset(name, instant)
		local preset = self.Presets[name]
		if not preset then
			Void.Log:Warn("unknown theme preset '%s' (available: %s)", tostring(name), table.concat(self:ListPresets(), ", "))
			return false
		end
		self.Name = name
		self:Set(Util.DeepCopy(preset), instant)
		return true
	end

	function Theme:ListPresets()
		local out = {}
		for name in pairs(self.Presets) do out[#out + 1] = name end
		table.sort(out)
		return out
	end

	function Theme:RegisterPreset(name, tokens)
		if type(name) ~= "string" or type(tokens) ~= "table" then
			Void.Log:Warn("RegisterPreset(name, tokens) got bad arguments")
			return false
		end
		self.Presets[name] = tokens
		return true
	end

	-- Serialise the current theme for the config file.
	function Theme:Serialize()
		local out = { __preset = self.Name, Tokens = {} }
		for token, color in pairs(self.Tokens) do
			out.Tokens[token] = Util.ToHex(color)
		end
		return out
	end

	function Theme:Deserialize(data)
		if type(data) ~= "table" then return false end
		if data.__preset and self.Presets[data.__preset] then
			self.Name = data.__preset
		end
		self:Set(data.Tokens or data)
		return true
	end

	-- Registry size — surfaced in the performance panel.
	function Theme:RegistryCount()
		local n = 0
		for _ in pairs(self._registry) do n = n + 1 end
		return n
	end

	Void.Theme = Theme
	return Theme
end
