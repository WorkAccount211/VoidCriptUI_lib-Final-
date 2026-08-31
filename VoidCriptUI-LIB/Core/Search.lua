--[[
	VoidCriptUI · Core/Search.lua
	Global settings search (roadmap #13).

	Every control registers a lightweight index entry (name, tooltip, kind,
	tab, section). Typing in the header search box filters live: matching
	elements stay visible, non-matching ones hide, sections with no visible
	children collapse, and tabs with no matches dim in the rail.

	The filter runs on a debounced pass over a flat array — no per-frame work
	and no tree walking.
]]

return function(Void)
	local Search = {
		_entries = {},
		_active = "",
		_listeners = {},
	}

	function Search:Add(control)
		if not control then return end
		local cfg = control._cfg or {}
		local ctx = control._ctx or {}
		local haystack = table.concat({
			tostring(control.Name or ""),
			tostring(cfg.Tooltip or ""),
			tostring(cfg.Description or ""),
			tostring(cfg.Flag or ""),
			tostring(control._kind or ""),
			ctx.Section and tostring(ctx.Section.Name or "") or "",
			ctx.Tab and tostring(ctx.Tab.Name or "") or "",
		}, " ")

		local entry = {
			Control = control,
			Haystack = Void.Util.Slug(haystack),
			Name = control.Name,
			Tab = ctx.Tab,
			Section = ctx.Section,
		}
		control._searchEntry = entry
		table.insert(self._entries, entry)

		-- If a filter is already active, apply it to the freshly built element
		-- (relevant with lazy loading: elements appear after the user typed).
		if self._active ~= "" then
			self:_applyToEntry(entry, self._active)
		end
		return entry
	end

	function Search:Remove(control)
		for i = #self._entries, 1, -1 do
			if self._entries[i].Control == control then
				table.remove(self._entries, i)
			end
		end
	end

	function Search:_applyToEntry(entry, needle)
		local control = entry.Control
		if control._destroyed then return false end
		local match = needle == "" or entry.Haystack:find(needle, 1, true) ~= nil
		-- respect DependsOn: a hidden dependant stays hidden
		if control._dependencyVisible == false then
			control:SetVisible(false)
			return false
		end
		control:SetVisible(match)
		return match
	end

	function Search:Apply(query)
		local needle = Void.Util.Slug(query or "")
		self._active = needle

		local matchedSections, matchedTabs = {}, {}
		local total, matched = 0, 0

		for i = #self._entries, 1, -1 do
			local entry = self._entries[i]
			if entry.Control._destroyed then
				table.remove(self._entries, i)
			else
				total = total + 1
				if self:_applyToEntry(entry, needle) then
					matched = matched + 1
					if entry.Section then matchedSections[entry.Section] = true end
					if entry.Tab then matchedTabs[entry.Tab] = true end
				end
			end
		end

		-- hide empty sections, dim empty tabs
		for _, window in ipairs(Void.Windows or {}) do
			for _, tab in ipairs(window._tabs or {}) do
				local tabHasMatch = needle == "" or matchedTabs[tab] == true
				if tab._setSearchDim then tab:_setSearchDim(not tabHasMatch) end
				for _, section in ipairs(tab._sections or {}) do
					if section._root then
						section._root.Visible = (needle == "") or (matchedSections[section] == true)
					end
				end
			end
		end

		for _, fn in ipairs(self._listeners) do
			pcall(fn, needle, matched, total)
		end

		return matched, total
	end

	function Search:Clear()
		self:Apply("")
	end

	function Search:OnApplied(fn)
		table.insert(self._listeners, fn)
		return function()
			for i = #self._listeners, 1, -1 do
				if self._listeners[i] == fn then table.remove(self._listeners, i) end
			end
		end
	end

	function Search:Query()
		return self._active
	end

	function Search:Reset()
		table.clear(self._entries)
		table.clear(self._listeners)
		self._active = ""
	end

	Void.Search = Search
	return Search
end
