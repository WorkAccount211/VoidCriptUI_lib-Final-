--[[
	VoidCriptUI · Core/Dependencies.lua
	Conditional visibility (roadmap #33).

	Elements declare a dependency instead of wiring callbacks by hand:

		Section:CreateToggle({ Name = "ESP", Flag = "esp" })
		Section:CreateSlider({ Name = "ESP distance", DependsOn = "esp" })
		Section:CreateDropdown({ Name = "Mode", DependsOn = { esp = true, mode = "Advanced" } })
		Section:CreateInput({ Name = "Custom", DependsOn = function(flags) return flags.mode == "Custom" end })

	Evaluation is event-driven — a dependency is only re-checked when one of the
	flags it watches actually changes, never per frame.
]]

return function(Void)
	local Dependencies = {
		_entries = {},         -- { Control = control, Spec = spec, Flags = {flag,...} }
		_byFlag = {},          -- flag -> { entry, ... }
	}

	local function normaliseSpec(spec)
		-- "flag"                     → truthy check
		-- { flag = value, ... }      → all must match
		-- { Flag = "x", Value = 1 }  → explicit form
		-- function(flagsProxy)       → custom predicate
		if type(spec) == "string" then
			return { mode = "truthy", flags = { spec } }
		end
		if type(spec) == "function" then
			return { mode = "custom", fn = spec, flags = {} }
		end
		if type(spec) == "table" then
			if spec.Flag then
				return { mode = "match", pairs = { [spec.Flag] = spec.Value == nil and true or spec.Value }, flags = { spec.Flag } }
			end
			local pairsMap, flags = {}, {}
			for flag, value in pairs(spec) do
				pairsMap[flag] = value
				flags[#flags + 1] = flag
			end
			return { mode = "match", pairs = pairsMap, flags = flags }
		end
		return nil
	end

	function Dependencies:Add(control, spec)
		local norm = normaliseSpec(spec)
		if not norm then
			Void.Log:Warn("DependsOn on '%s' is not a string/table/function", tostring(control.Name))
			return
		end

		local entry = { Control = control, Spec = norm }
		table.insert(self._entries, entry)
		for _, flag in ipairs(norm.flags) do
			self._byFlag[flag] = self._byFlag[flag] or {}
			table.insert(self._byFlag[flag], entry)
			if not Void.Flags:Exists(flag) then
				Void.Log:Debug("DependsOn references flag '%s' which is not registered yet", flag)
			end
		end

		-- Custom predicates cannot be indexed by flag, so they are re-evaluated
		-- on every flag change (there are usually very few of them).
		if norm.mode == "custom" then
			self._custom = self._custom or {}
			table.insert(self._custom, entry)
		end

		self:Evaluate(entry)
	end

	function Dependencies:Remove(control)
		for i = #self._entries, 1, -1 do
			if self._entries[i].Control == control then table.remove(self._entries, i) end
		end
		for _, list in pairs(self._byFlag) do
			for i = #list, 1, -1 do
				if list[i].Control == control then table.remove(list, i) end
			end
		end
		if self._custom then
			for i = #self._custom, 1, -1 do
				if self._custom[i].Control == control then table.remove(self._custom, i) end
			end
		end
	end

	function Dependencies:Evaluate(entry)
		local spec = entry.Spec
		local visible = true

		if spec.mode == "truthy" then
			local value = Void.Flags:Get(spec.flags[1])
			visible = value and value ~= false and value ~= 0 and true or false
		elseif spec.mode == "match" then
			for flag, expected in pairs(spec.pairs) do
				local actual = Void.Flags:Get(flag)
				if type(expected) == "function" then
					local ok, result = pcall(expected, actual)
					if not ok or not result then visible = false break end
				elseif type(expected) == "table" then
					-- any-of list
					local found = false
					for _, candidate in ipairs(expected) do
						if actual == candidate then found = true break end
					end
					if not found then visible = false break end
				elseif expected == true then
					if not actual then visible = false break end
				elseif actual ~= expected then
					visible = false
					break
				end
			end
		elseif spec.mode == "custom" then
			local ok, result = pcall(spec.fn, Void.Flags.Proxy)
			if not ok then
				Void.Log:Error("DependsOn predicate on '%s' errored: %s", tostring(entry.Control.Name), tostring(result))
				visible = true
			else
				visible = result and true or false
			end
		end

		local control = entry.Control
		if control._destroyed then return end
		if control._dependencyVisible ~= visible then
			control._dependencyVisible = visible
			control:SetVisible(visible)
		end
	end

	function Dependencies:Notify(flag, _value)
		if flag then
			local list = self._byFlag[flag]
			if list then
				for _, entry in ipairs(list) do self:Evaluate(entry) end
			end
		end
		if self._custom then
			for _, entry in ipairs(self._custom) do self:Evaluate(entry) end
		end
	end

	function Dependencies:EvaluateAll()
		for _, entry in ipairs(self._entries) do self:Evaluate(entry) end
	end

	function Dependencies:Clear()
		table.clear(self._entries)
		table.clear(self._byFlag)
		self._custom = nil
	end

	Void.Dependencies = Dependencies
	return Dependencies
end
