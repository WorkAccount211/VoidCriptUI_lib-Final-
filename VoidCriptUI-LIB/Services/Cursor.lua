--[[
	VoidCriptUI · Services/Cursor.lua
	Custom in-menu cursor + optional game input lock (roadmap #18).

	· A crisp vector-style crosshair/arrow drawn from Frames (no image asset),
	  tinted with the accent colour and animated on click.
	· Only visible while the pointer is over a VoidCript window, so it never
	  fights the game's own cursor.
	· `Cursor:SetInputLock(true)` sinks movement/attack bindings through
	  ContextActionService while a menu is open, so clicking a slider does not
	  swing your sword. Mouse look is unlocked so the player can still aim the
	  camera if the script wants that.
]]

return function(Void)
	local UserInputService = game:GetService("UserInputService")
	local ContextActionService = game:GetService("ContextActionService")
	local RunService = game:GetService("RunService")
	local Util, Theme, Scale = Void.Util, Void.Theme, Void.Scale

	local Cursor = {
		Enabled = false,
		LockInput = false,
		Style = "Arrow", -- Arrow | Cross | Dot
		_hoverCount = 0,
	}

	local LOCK_ACTION = "VoidCriptInputLock"
	local SINK_KEYS = {
		Enum.UserInputType.MouseButton1,
		Enum.UserInputType.MouseButton2,
		Enum.KeyCode.ButtonR2,
		Enum.KeyCode.ButtonL2,
	}

	local function build()
		if Cursor._gui then return end
		local gui = Util.Screen("VoidCriptCursor", Void.RootMaid)
		gui.DisplayOrder = 100001
		Cursor._gui = gui

		local holder = Util.New("Frame", {
			Name = "Cursor",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(Scale.u(22), Scale.u(22)),
			AnchorPoint = Vector2.new(0, 0),
			Visible = false,
			ZIndex = 100,
			Parent = gui,
		})
		Cursor._holder = holder

		-- arrow: two rotated bars forming a caret + a soft shadow copy
		local function bar(name, size, position, rotation, color, transparency, zIndex)
			local b = Util.New("Frame", {
				Name = name,
				BackgroundColor3 = color,
				BackgroundTransparency = transparency or 0,
				Size = size,
				Position = position,
				Rotation = rotation or 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				ZIndex = zIndex or 2,
				Parent = holder,
			})
			Util.Corner(b, 1)
			return b
		end

		Cursor._parts = {
			-- shadow
			bar("ShadowA", UDim2.fromOffset(Scale.u(2), Scale.u(13)), UDim2.fromOffset(Scale.u(7), Scale.u(9)), 22, Color3.new(0, 0, 0), 0.55, 1),
			bar("ShadowB", UDim2.fromOffset(Scale.u(2), Scale.u(9)), UDim2.fromOffset(Scale.u(12), Scale.u(12)), -30, Color3.new(0, 0, 0), 0.55, 1),
			-- accent caret
			bar("EdgeA", UDim2.fromOffset(Scale.u(2), Scale.u(13)), UDim2.fromOffset(Scale.u(6), Scale.u(8)), 22, Theme.C.Accent, 0, 3),
			bar("EdgeB", UDim2.fromOffset(Scale.u(2), Scale.u(9)), UDim2.fromOffset(Scale.u(11), Scale.u(11)), -30, Theme.C.Accent, 0, 3),
		}
		Theme:Paint(Cursor._parts[3], { BackgroundColor3 = "Accent" })
		Theme:Paint(Cursor._parts[4], { BackgroundColor3 = "Accent" })

		local dot = Util.New("Frame", {
			Name = "Dot",
			BackgroundColor3 = Theme.C.Text,
			Size = UDim2.fromOffset(Scale.u(3), Scale.u(3)),
			Position = UDim2.fromOffset(Scale.u(2), Scale.u(2)),
			ZIndex = 4,
			Parent = holder,
		})
		Util.Corner(dot, 2)
		Theme:Paint(dot, { BackgroundColor3 = "Text" })
		Cursor._dot = dot

		-- click pulse ring
		local ring = Util.New("Frame", {
			Name = "Ring",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(Scale.u(4), Scale.u(4)),
			Size = UDim2.fromOffset(Scale.u(6), Scale.u(6)),
			ZIndex = 2,
			Parent = holder,
		})
		Util.Corner(ring, 999)
		local ringStroke = Util.Stroke(ring, Theme.C.Accent, 1, 1)
		Theme:Paint(ringStroke, { Color = "Accent" })
		Cursor._ring, Cursor._ringStroke = ring, ringStroke
	end

	local function follow()
		if not Cursor._holder then return end
		local pos = UserInputService:GetMouseLocation()
		Cursor._holder.Position = UDim2.fromOffset(pos.X, pos.Y - 36)
	end

	function Cursor:Pulse()
		if not self._ring then return end
		self._ring.Size = UDim2.fromOffset(Scale.u(6), Scale.u(6))
		self._ringStroke.Transparency = 0.2
		Util.Tween(self._ring, { Size = UDim2.fromOffset(Scale.u(26), Scale.u(26)) }, 0.3)
		Util.Tween(self._ringStroke, { Transparency = 1 }, 0.3)
	end

	function Cursor:Start(maid)
		if self._started then return end
		self._started = true
		build()

		-- Single RenderStepped follower, only while visible. This is the one
		-- place a per-frame connection is justified: the cursor must not lag
		-- behind the pointer.
		self._render = RunService.RenderStepped:Connect(function()
			if Cursor._holder and Cursor._holder.Visible then follow() end
		end)
		maid:Give(self._render)

		maid:Give(UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 and Cursor._holder and Cursor._holder.Visible then
				Cursor:Pulse()
			end
		end))
	end

	-- Windows call these on mouse enter/leave so the cursor only shows in-menu.
	function Cursor:PushHover()
		self._hoverCount = self._hoverCount + 1
		self:_refresh()
	end

	function Cursor:PopHover()
		self._hoverCount = math.max(0, self._hoverCount - 1)
		self:_refresh()
	end

	function Cursor:_refresh()
		if not self._holder then return end
		local shouldShow = self.Enabled and self._hoverCount > 0 and not Util.IsMobile()
		if self._holder.Visible == shouldShow then return end
		self._holder.Visible = shouldShow
		UserInputService.MouseIconEnabled = not shouldShow
		if shouldShow then follow() end
	end

	function Cursor:SetEnabled(state)
		self.Enabled = state and true or false
		if self.Enabled then
			build()
			if not self._started then self:Start(Void.RootMaid) end
		end
		self:_refresh()
		if not self.Enabled then
			UserInputService.MouseIconEnabled = true
		end
		return self.Enabled
	end

	function Cursor:SetStyle(style)
		self.Style = style
		if not self._parts then return end
		local isDot = style == "Dot"
		for i = 1, 4 do
			self._parts[i].Visible = not isDot
		end
		self._dot.Visible = true
		self._dot.Size = isDot and UDim2.fromOffset(Scale.u(6), Scale.u(6)) or UDim2.fromOffset(Scale.u(3), Scale.u(3))
		return style
	end

	-- Sink attack/aim inputs while a menu is open so clicks do not reach the
	-- game. Camera look stays free.
	function Cursor:SetInputLock(state)
		state = state and true or false
		if self.LockInput == state then return state end
		self.LockInput = state
		if state then
			ContextActionService:BindActionAtPriority(
				LOCK_ACTION, function() return Enum.ContextActionResult.Sink end,
				false, 3000, table.unpack(SINK_KEYS)
			)
			Void.Log:Debug("game input lock enabled")
		else
			pcall(function() ContextActionService:UnbindAction(LOCK_ACTION) end)
			Void.Log:Debug("game input lock disabled")
		end
		return state
	end

	function Cursor:Stop()
		self:SetInputLock(false)
		self:SetEnabled(false)
		if self._render then self._render:Disconnect() self._render = nil end
		self._started = false
		UserInputService.MouseIconEnabled = true
	end

	Void.Cursor = Cursor
	return Cursor
end
