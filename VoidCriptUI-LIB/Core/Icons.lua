--[[
	VoidCriptUI · Core/Icons.lua
	Custom icon set — 100% ours, no external icon pack dependency.

	Every icon is available in two forms:
	  · Glyph  — a Unicode symbol drawn with the UI font. Zero download, zero
	             image memory, tints instantly with the theme.
	  · Asset  — an optional rbxassetid override, if you prefer bitmaps.

	Resolution order in `Icons.Resolve`:
	  1. number                → "rbxassetid://<n>"           (image)
	  2. "rbxassetid://..."    → used as-is                     (image)
	  3. registered icon name  → glyph (or asset if registered) (text/image)
	  4. short raw string      → used as the glyph directly     (text)
	  5. anything else         → fallback dot

	Register your own without touching the library core:
		VoidLib.Icons:Register("mymod", { Glyph = "✦" })
		VoidLib.Icons:Register("logo",  { Asset = 12345678 })
]]

return function(Void)
	local Icons = {
		_set = {},
		Fallback = "•",
	}

	local GLYPHS = {
		-- navigation / structure
		home      = "⌂",
		menu      = "☰",
		grid      = "▦",
		list      = "☰",
		layers    = "▤",
		folder    = "🗀",
		file      = "🖹",
		search    = "🔍",
		filter    = "⛛",
		settings  = "⚙",
		sliders   = "⇅",
		tune      = "⇵",
		plug      = "⏻",
		puzzle    = "🧩",

		-- combat / cheat-menu classics
		skull     = "☠",
		crosshair = "✛",
		target    = "◎",
		aim       = "⊕",
		eye       = "◉",
		eyeOff    = "◌",
		radar     = "◈",
		shield    = "⛨",
		sword     = "⚔",
		bolt      = "⚡",
		zap       = "⚡",
		flame     = "🔥",
		ghost     = "☁",

		-- world / player
		world     = "🌐",
		globe     = "🌐",
		map       = "▧",
		user      = "☺",
		users     = "⚇",
		player    = "☺",
		car       = "⛍",
		box       = "▣",

		-- visuals
		brush     = "✎",
		palette   = "◐",
		droplet   = "◍",
		sparkle   = "✦",
		star      = "★",
		starOff   = "☆",
		moon      = "☾",
		sun       = "☀",
		image     = "🖼",
		camera    = "⛶",

		-- feedback
		info      = "ⓘ",
		warning   = "⚠",
		error     = "✖",
		success   = "✔",
		check     = "✔",
		cross     = "✖",
		question  = "?",
		bell      = "🔔",

		-- controls
		play      = "▶",
		pause     = "⏸",
		stop      = "■",
		refresh   = "⟳",
		undo      = "↺",
		redo      = "↻",
		plus      = "＋",
		minus     = "－",
		chevronUp = "▴",
		chevronDown = "▾",
		chevronLeft = "◂",
		chevronRight = "▸",
		arrowUp   = "↑",
		arrowDown = "↓",
		expand    = "⤢",
		collapse  = "⤡",
		pin       = "⚲",
		lock      = "🔒",
		unlock    = "🔓",
		save      = "🖫",
		trash     = "🗑",
		copy      = "🗐",
		edit      = "✎",
		keyboard  = "⌨",
		mouse     = "🖱",
		terminal  = "‹›",
		code      = "‹›",
		clock     = "◷",
		gauge     = "◔",
		chart     = "▥",
		cpu       = "▩",
		wifi      = "≋",
		link      = "🔗",
		download  = "⭳",
		upload    = "⭱",
		power     = "⏻",
		void      = "◇",
	}

	for name, glyph in pairs(GLYPHS) do
		Icons._set[name:lower()] = { Glyph = glyph }
	end

	function Icons:Register(name, def)
		if type(name) ~= "string" or name == "" then
			Void.Log:Warn("Icons:Register needs a non-empty name")
			return false
		end
		if type(def) == "string" then def = { Glyph = def } end
		if type(def) == "number" then def = { Asset = def } end
		if type(def) ~= "table" then
			Void.Log:Warn("Icons:Register('%s') needs a glyph string, asset id, or table", name)
			return false
		end
		self._set[name:lower()] = def
		return true
	end

	function Icons:RegisterPack(pack)
		local count = 0
		for name, def in pairs(pack or {}) do
			if self:Register(name, def) then count = count + 1 end
		end
		return count
	end

	function Icons:Has(name)
		return type(name) == "string" and self._set[name:lower()] ~= nil
	end

	function Icons:List()
		local out = {}
		for name in pairs(self._set) do out[#out + 1] = name end
		table.sort(out)
		return out
	end

	-- Returns kind ("image"|"text"), value
	function Icons:Resolve(icon)
		if icon == nil then return nil, nil end
		if type(icon) == "number" then
			return "image", "rbxassetid://" .. tostring(math.floor(icon))
		end
		if type(icon) == "string" then
			if icon:match("^rbxassetid://") or icon:match("^rbxasset://") or icon:match("^https?://") then
				return "image", icon
			end
			local def = self._set[icon:lower()]
			if def then
				if def.Asset then
					return "image", type(def.Asset) == "number" and ("rbxassetid://" .. def.Asset) or def.Asset
				end
				return "text", def.Glyph or self.Fallback
			end
			-- treat short unknown strings as raw glyphs (e.g. "★", "AB")
			if utf8 and utf8.len(icon) and utf8.len(icon) <= 3 then
				return "text", icon
			end
			Void.Log:Debug("unknown icon '%s', using fallback", icon)
			return "text", self.Fallback
		end
		return "text", self.Fallback
	end

	Void.Icons = Icons
	return Icons
end
