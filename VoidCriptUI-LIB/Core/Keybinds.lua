--[[
	VoidCriptUI · Core/Keybinds.lua
	Central keybind manager (roadmap #5, #42).

	One InputBegan / InputEnded pass drives every bind in the library — not one
	connection per element. Supports:
	  · keyboard keys, mouse buttons (MB1/MB2/MB3, wheel), gamepad buttons
	  · modifiers: Ctrl / Shift / Alt combos ("Ctrl+X")
	  · modes: Always, Toggle, Hold
	  · a live keylist feed (name, mode, key, state, hits, last used)

	Binds are stored as a descriptor table so serialising them to JSON is
	trivial and lossless.
]]

return function(Void)
	local UserInputService = game:GetService("UserInputService")

	local Keybinds = {
		_binds = {},          -- ordered list of bind entries
		_listeners = {},      -- keylist / UI observers
		Enabled = true,
	}

	local MOUSE_NAMES = {
		[Enum.UserInputType.MouseButton1] = "MB1",
		[Enum.UserInputType.MouseButton2] = "MB2",
		[Enum.UserInputType.MouseButton3] = "MB3",
	}
	local MOUSE_BY_NAME = {
		MB1 = Enum.UserInputType.MouseButton1,
		MB2 = Enum.UserInputType.MouseButton2,
		MB3 = Enum.UserInputType.MouseButton3,
	}

	local MODIFIER_KEYS = {
		[Enum.KeyCode.LeftControl] = "Ctrl", [Enum.KeyCode.RightControl] = "Ctrl",
		[Enum.KeyCode.LeftShift] = "Shift", [Enum.KeyCode.RightShift] = "Shift",
		[Enum.KeyCode.LeftAlt] = "Alt", [Enum.KeyCode.RightAlt] = "Alt",
	}

	Keybinds.Modes = { "Always", "Toggle", "Hold" }

	-- ── descriptor helpers ──────────────────────────────────────────────
	-- A descriptor is { Key = KeyCode|nil, Mouse = "MB2"|nil, Modifiers = {"Ctrl"} }
	function Keybinds.Descriptor(input)
		if input == nil then return nil end

		if type(input) == "table" and (input.Key or input.Mouse or input.KeyName) then
			local desc = {
				Modifiers = input.Modifiers and table.clone(input.Modifiers) or {},
			}
			if input.Mouse then desc.Mouse = input.Mouse end
			if typeof(input.Key) == "EnumItem" then
				desc.Key = input.Key
			elseif type(input.KeyName) == "string" and Enum.KeyCode[input.KeyName] then
				desc.Key = Enum.KeyCode[input.KeyName]
			elseif type(input.Key) == "string" then
				if MOUSE_BY_NAME[input.Key:upper()] then
					desc.Mouse = input.Key:upper()
				elseif Enum.KeyCode[input.Key] then
					desc.Key = Enum.KeyCode[input.Key]
				end
			end
			return desc
		end

		if typeof(input) == "EnumItem" then
			if input.EnumType == Enum.KeyCode then
				return { Key = input, Modifiers = {} }
			end
			if MOUSE_NAMES[input] then
				return { Mouse = MOUSE_NAMES[input], Modifiers = {} }
			end
			return nil
		end

		if type(input) == "string" then
			-- "Ctrl+Shift+F", "MB2", "RightShift"
			local parts = {}
			for token in input:gmatch("[^%+%s]+") do parts[#parts + 1] = token end
			local desc = { Modifiers = {} }
			for _, token in ipairs(parts) do
				local upper = token:upper()
				if upper == "CTRL" or upper == "CONTROL" then
					table.insert(desc.Modifiers, "Ctrl")
				elseif upper == "SHIFT" then
					table.insert(desc.Modifiers, "Shift")
				elseif upper == "ALT" then
					table.insert(desc.Modifiers, "Alt")
				elseif MOUSE_BY_NAME[upper] then
					desc.Mouse = upper
				elseif Enum.KeyCode[token] then
					desc.Key = Enum.KeyCode[token]
				else
					-- try capitalised form: "f" -> "F"
					local cap = token:sub(1, 1):upper() .. token:sub(2)
					if Enum.KeyCode[cap] then desc.Key = Enum.KeyCode[cap] end
				end
			end
			if not desc.Key and not desc.Mouse then return nil end
			return desc
		end

		return nil
	end

	function Keybinds.Label(desc)
		if not desc then return "None" end
		local parts = {}
		for _, mod in ipairs(desc.Modifiers or {}) do parts[#parts + 1] = mod end
		if desc.Mouse then
			parts[#parts + 1] = desc.Mouse
		elseif desc.Key then
			local name = desc.Key.Name
			-- prettify the long ones
			local pretty = {
				RightShift = "RShift", LeftShift = "LShift",
				RightControl = "RCtrl", LeftControl = "LCtrl",
				RightAlt = "RAlt", LeftAlt = "LAlt",
				LeftBracket = "[", RightBracket = "]",
				Semicolon = ";", Quote = "'", Comma = ",", Period = ".",
				Slash = "/", Backslash = "\\", Minus = "-", Equals = "=",
				Backquote = "`", Space = "Space", Return = "Enter",
			}
			parts[#parts + 1] = pretty[name] or name
		end
		if #parts == 0 then return "None" end
		return table.concat(parts, "+")
	end

	function Keybinds.Serialize(desc)
		if not desc then return nil end
		return {
			__t = "keybind",
			Key = desc.Key and desc.Key.Name or nil,
			Mouse = desc.Mouse,
			Modifiers = desc.Modifiers,
		}
	end

	function Keybinds.Deserialize(raw)
		if type(raw) ~= "table" then return Keybinds.Descriptor(raw) end
		return Keybinds.Descriptor({
			KeyName = raw.Key,
			Mouse = raw.Mouse,
			Modifiers = raw.Modifiers or {},
		})
	end

	-- ── registration ────────────────────────────────────────────────────
	--[[
		Keybinds:Register({
			Name = "Fly",
			Descriptor = <desc>,
			Mode = "Toggle",           -- Always | Toggle | Hold
			Control = <control|nil>,
			OnPress = function() end,
			OnRelease = function() end,
			OnState = function(bool) end,   -- Toggle/Hold state changes
			ShowInKeylist = true,
			Category = "Movement",
		})
	]]
	function Keybinds:Register(entry)
		entry.Mode = entry.Mode or "Always"
		entry.State = entry.State or false
		entry.Hits = 0
		entry.LastUsed = nil
		entry.ShowInKeylist = entry.ShowInKeylist ~= false
		table.insert(self._binds, entry)
		self:_notify()
		return entry
	end

	function Keybinds:Remove(controlOrEntry)
		local removed = false
		for i = #self._binds, 1, -1 do
			local bind = self._binds[i]
			if bind == controlOrEntry or bind.Control == controlOrEntry then
				table.remove(self._binds, i)
				removed = true
			end
		end
		if removed then self:_notify() end
		return removed
	end

	function Keybinds:List()
		return self._binds
	end

	function Keybinds:ActiveList()
		local out = {}
		for _, bind in ipairs(self._binds) do
			if bind.ShowInKeylist and (bind.Descriptor or bind.Mode == "Always") then
				out[#out + 1] = bind
			end
		end
		table.sort(out, function(a, b)
			if a.Mode == b.Mode then return tostring(a.Name) < tostring(b.Name) end
			return a.Mode < b.Mode
		end)
		return out
	end

	function Keybinds:OnUpdated(fn)
		table.insert(self._listeners, fn)
		return function()
			for i = #self._listeners, 1, -1 do
				if self._listeners[i] == fn then table.remove(self._listeners, i) end
			end
		end
	end

	function Keybinds:_notify()
		for _, fn in ipairs(self._listeners) do
			pcall(fn, self._binds)
		end
	end

	-- ── matching ────────────────────────────────────────────────────────
	local function modifiersHeld(mods)
		if not mods or #mods == 0 then return true end
		for _, mod in ipairs(mods) do
			if mod == "Ctrl" then
				if not (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then return false end
			elseif mod == "Shift" then
				if not (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)) then return false end
			elseif mod == "Alt" then
				if not (UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)) then return false end
			end
		end
		return true
	end

	local function inputMatches(desc, input)
		if not desc then return false end
		if desc.Mouse then
			if MOUSE_NAMES[input.UserInputType] ~= desc.Mouse then return false end
		elseif desc.Key then
			if input.KeyCode ~= desc.Key then return false end
		else
			return false
		end
		return modifiersHeld(desc.Modifiers)
	end

	Keybinds.InputMatches = inputMatches
	Keybinds.IsModifier = function(keyCode) return MODIFIER_KEYS[keyCode] ~= nil end
	Keybinds.ModifierName = function(keyCode) return MODIFIER_KEYS[keyCode] end
	Keybinds.MouseName = function(inputType) return MOUSE_NAMES[inputType] end

	-- Capture mode: used by the keybind element while it waits for a key.
	function Keybinds:BeginCapture(callback)
		self._capture = callback
	end

	function Keybinds:CancelCapture()
		self._capture = nil
	end

	function Keybinds:IsCapturing()
		return self._capture ~= nil
	end

	function Keybinds:SetBindState(bind, state)
		bind.State = state and true or false
		if bind.OnState then
			Void.Log:GuardAsync(("keybind '%s' state"):format(tostring(bind.Name)), bind.OnState, bind.State)
		end
		self:_notify()
	end

	-- ── the single input pass ───────────────────────────────────────────
	function Keybinds:Start(maid)
		if self._started then return end
		self._started = true

		maid:Give(UserInputService.InputBegan:Connect(function(input, gameProcessed)
			-- capture takes priority and ignores gameProcessed so the user can
			-- bind keys the game also uses
			if self._capture then
				local capture = self._capture
				-- Escape clears, Backspace unbinds
				if input.KeyCode == Enum.KeyCode.Escape then
					self._capture = nil
					capture(nil, "cancel")
					return
				end
				if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
					self._capture = nil
					capture(nil, "clear")
					return
				end
				if MODIFIER_KEYS[input.KeyCode] then
					return -- modifiers alone are not a bind; wait for the real key
				end
				local desc
				if MOUSE_NAMES[input.UserInputType] then
					desc = { Mouse = MOUSE_NAMES[input.UserInputType], Modifiers = {} }
				elseif input.UserInputType == Enum.UserInputType.Keyboard then
					desc = { Key = input.KeyCode, Modifiers = {} }
				elseif input.UserInputType == Enum.UserInputType.Gamepad1 then
					desc = { Key = input.KeyCode, Modifiers = {} }
				end
				if desc then
					if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
						table.insert(desc.Modifiers, "Ctrl")
					end
					if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
						table.insert(desc.Modifiers, "Shift")
					end
					if UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt) then
						table.insert(desc.Modifiers, "Alt")
					end
					self._capture = nil
					capture(desc, "set")
				end
				return
			end

			if not self.Enabled then return end
			if gameProcessed and not self.IgnoreGameProcessed then return end

			for _, bind in ipairs(self._binds) do
				if bind.Enabled ~= false and inputMatches(bind.Descriptor, input) then
					bind.Hits = (bind.Hits or 0) + 1
					bind.LastUsed = os.clock()
					if bind.Mode == "Toggle" then
						self:SetBindState(bind, not bind.State)
					elseif bind.Mode == "Hold" then
						self:SetBindState(bind, true)
					end
					if bind.OnPress then
						Void.Log:GuardAsync(("keybind '%s'"):format(tostring(bind.Name)), bind.OnPress, bind)
					end
					self:_notify()
				end
			end
		end))

		maid:Give(UserInputService.InputEnded:Connect(function(input)
			if not self.Enabled then return end
			for _, bind in ipairs(self._binds) do
				if bind.Enabled ~= false and bind.Descriptor then
					local sameKey = (bind.Descriptor.Mouse and MOUSE_NAMES[input.UserInputType] == bind.Descriptor.Mouse)
						or (bind.Descriptor.Key and input.KeyCode == bind.Descriptor.Key)
					if sameKey then
						if bind.Mode == "Hold" and bind.State then
							self:SetBindState(bind, false)
						end
						if bind.OnRelease then
							Void.Log:GuardAsync(("keybind '%s' release"):format(tostring(bind.Name)), bind.OnRelease, bind)
						end
					end
				end
			end
		end))
	end

	function Keybinds:Clear()
		table.clear(self._binds)
		table.clear(self._listeners)
		self._capture = nil
	end

	Void.Keybinds = Keybinds
	return Keybinds
end
