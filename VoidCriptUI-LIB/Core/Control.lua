--[[
	VoidCriptUI · Core/Control.lua
	Base class shared by every element.

	It owns the boring-but-critical parts so each element file only has to
	describe its visuals:
	  · flag registration + change notification
	  · Get / Set / GetRaw / OnChanged
	  · SetVisible, Enable/Disable, DependsOn (conditional visibility)
	  · Tooltip attachment and search indexing
	  · Destroy (unpaints theme, unregisters flag, cleans its own Maid)
	  · callback invocation through Log:Guard (a broken callback can never
	    take the UI down)
]]

return function(Void)
	local Util = Void.Util
	local Theme = Void.Theme

	local Control = {}
	Control.__index = Control

	function Control.new(kind, cfg, context)
		local self = setmetatable({
			_kind = kind,
			_cfg = cfg or {},
			_ctx = context,               -- { Window, Tab, Section, Parent, Maid }
			_maid = Void.Maid.new(kind),
			_listeners = {},
			_visible = true,
			_enabled = true,
			_destroyed = false,
			Name = (cfg and cfg.Name) or kind,
			Flag = cfg and cfg.Flag or nil,
			Risky = cfg and (cfg.Risky or cfg.Warning) or false,
		}, Control)

		if context and context.Maid then
			context.Maid:Give(self._maid)
		end
		return self
	end

	function Control:GetMaid()
		return self._maid
	end

	-- ── value plumbing ──────────────────────────────────────────────────
	-- Elements assign self._get / self._set / self._raw during construction.
	function Control:Get()
		if self._get then return self._get() end
		return self._value
	end

	function Control:GetRaw()
		if self._raw then return self._raw() end
		return self:Get()
	end

	function Control:Set(value, fire)
		if self._destroyed then return self end
		if self._set then
			self._set(value, fire ~= false)
		else
			self._value = value
			if fire ~= false then self:_emit(value) end
		end
		return self
	end

	-- Called by elements after their internal state changed.
	function Control:_emit(value)
		if self._destroyed then return end
		self._value = value

		-- 1. element callback
		if self._cfg.Callback then
			Void.Log:GuardAsync(("%s '%s' callback"):format(self._kind, tostring(self.Name)), self._cfg.Callback, value, self)
		end
		-- 2. per-control listeners
		for i = #self._listeners, 1, -1 do
			Void.Log:GuardAsync(("%s '%s' listener"):format(self._kind, tostring(self.Name)), self._listeners[i], value, self)
		end
		-- 3. global flag bus
		if self.Flag then
			Void.Flags:Fire(self.Flag, value)
		end
		-- 4. dependants may need to show/hide
		Void.Dependencies:Notify(self.Flag, value)
		-- 5. autosave
		if self._ctx and self._ctx.Window and self._ctx.Window._requestAutoSave then
			self._ctx.Window._requestAutoSave()
		end
	end

	function Control:OnChanged(fn)
		if type(fn) ~= "function" then return function() end end
		table.insert(self._listeners, fn)
		return function()
			for i = #self._listeners, 1, -1 do
				if self._listeners[i] == fn then table.remove(self._listeners, i) end
			end
		end
	end

	-- ── visibility / state (roadmap #32, #33) ───────────────────────────
	function Control:SetVisible(state)
		state = state and true or false
		self._visible = state
		if self._root then
			self._root.Visible = state
		end
		if self._ctx and self._ctx.Section and self._ctx.Section._invalidate then
			self._ctx.Section:_invalidate()
		end
		return self
	end

	function Control:IsVisible()
		return self._visible
	end

	function Control:SetEnabled(state)
		state = state and true or false
		if self._enabled == state then return self end
		self._enabled = state
		if self._setEnabled then
			self._setEnabled(state)
		elseif self._root then
			for _, d in ipairs(self._root:GetDescendants()) do
				if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
					d.TextTransparency = state and 0 or 0.55
				elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
					d.ImageTransparency = state and 0 or 0.55
				end
			end
			if self._root:IsA("GuiButton") then
				self._root.Active = state
			end
		end
		return self
	end

	function Control:IsEnabled()
		return self._enabled
	end

	function Control:SetName(name)
		self.Name = name
		if self._setName then self._setName(name) end
		if self._searchEntry then self._searchEntry.Name = name end
		return self
	end

	function Control:SetTooltip(text)
		self._cfg.Tooltip = text
		if self._tooltipTarget then
			Void.Tooltip:Attach(self._tooltipTarget, text, self._maid)
		end
		return self
	end

	-- ── lifecycle ───────────────────────────────────────────────────────
	function Control:Destroy()
		if self._destroyed then return end
		self._destroyed = true

		if self.Flag then Void.Flags:Unregister(self.Flag) end
		Void.Dependencies:Remove(self)
		Void.Search:Remove(self)
		Void.Keybinds:Remove(self)

		if self._root then
			for _, d in ipairs(self._root:GetDescendants()) do
				Theme:Unpaint(d)
			end
			Theme:Unpaint(self._root)
		end

		self._maid:Destroy()
		if self._root then
			pcall(function() self._root:Destroy() end)
		end
		if self._ctx and self._ctx.Section and self._ctx.Section._removeElement then
			self._ctx.Section:_removeElement(self)
		end
		table.clear(self._listeners)
	end

	-- ── shared post-construction wiring ─────────────────────────────────
	-- Every element calls this once its root frame exists.
	function Control:_finalise(root, tooltipTarget)
		self._root = root
		self._tooltipTarget = tooltipTarget or root

		if self._cfg.Tooltip then
			Void.Tooltip:Attach(self._tooltipTarget, self._cfg.Tooltip, self._maid)
		end
		if self.Flag then
			Void.Flags:Register(self.Flag, self)
		end
		if self._cfg.Visible == false then
			self:SetVisible(false)
		end
		if self._cfg.Enabled == false then
			self:SetEnabled(false)
		end
		if self._cfg.DependsOn then
			Void.Dependencies:Add(self, self._cfg.DependsOn)
		end
		if self._cfg.Searchable ~= false then
			Void.Search:Add(self)
		end
		if self._cfg.LayoutOrder then
			root.LayoutOrder = self._cfg.LayoutOrder
		end
		return self
	end

	-- Hover/press feedback shared by every interactive element:
	-- colour + optional 1px lift, plus an accent focus ring (the "accent line
	-- around the active element" requirement).
	function Control:_hoverable(button, target, baseToken, hoverToken, stroke)
		target = target or button
		baseToken = baseToken or "Element"
		hoverToken = hoverToken or "ElementHover"

		local function enter()
			if not self._enabled then return end
			Util.Tween(target, { BackgroundColor3 = Theme.C[hoverToken] }, Util.Motion.Fast)
			if stroke then
				Util.Tween(stroke, { Color = Theme.C.OutlineStrong }, Util.Motion.Fast)
			end
		end
		local function leave()
			Util.Tween(target, { BackgroundColor3 = Theme.C[baseToken] }, Util.Motion.Fast)
			if stroke and not self._focused then
				Util.Tween(stroke, { Color = Theme.C.OutlineSoft }, Util.Motion.Fast)
			end
		end

		self._maid:Give(button.MouseEnter:Connect(enter))
		self._maid:Give(button.MouseLeave:Connect(leave))
		self._maid:Give(button.MouseButton1Down:Connect(function()
			if not self._enabled then return end
			Util.Tween(target, { BackgroundColor3 = Theme.C.ElementActive }, 0.06)
		end))
		self._maid:Give(button.MouseButton1Up:Connect(enter))
		return { Enter = enter, Leave = leave }
	end

	-- Accent focus ring used by inputs / active fields.
	function Control:_focusRing(stroke, on)
		self._focused = on
		Util.Tween(stroke, { Color = on and Theme.C.Accent or Theme.C.OutlineSoft }, Util.Motion.Fast)
	end

	-- Guarded click that respects `Risky`/`Confirm` (danger confirmation).
	function Control:_confirmedClick(fn)
		local cfg = self._cfg
		local needsConfirm = cfg.Confirm or cfg.Risky or cfg.Warning
		if not needsConfirm then
			fn()
			return
		end
		Void.Dialog:Confirm({
			Title = cfg.ConfirmTitle or "Are you sure?",
			Content = cfg.ConfirmText
				or ("\"%s\" is marked as a risky action. Continue?"):format(tostring(self.Name)),
			Accept = cfg.ConfirmAccept or "Yes, run it",
			Decline = cfg.ConfirmDecline or "Cancel",
			OnAccept = fn,
		})
	end

	Void.Control = Control
	return Control
end
