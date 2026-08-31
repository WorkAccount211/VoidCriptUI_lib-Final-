--[[
	VoidCriptUI · Components/MobileToggle.lua
	The floating "V" bubble that shows/hides the menu.

	· On phones and tablets it is created automatically: a small circular icon
	  pinned to a screen corner. Tap = toggle the window; drag = reposition
	  (with edge snapping so it never sits half-off screen).
	· On desktop it is optional (`FloatingButton = true`) and complements the
	  RightShift keybind.
	· When the window hides, the bubble grows slightly and pulses the accent
	  ring, so it is obvious where the menu went — this is the "collapse into an
	  icon" behaviour.
]]

return function(Void)
	local Util, Theme, Scale = Void.Util, Void.Theme, Void.Scale
	local UserInputService = game:GetService("UserInputService")

	local MobileToggle = {}
	MobileToggle.__index = MobileToggle

	local SYMBOL = "https://raw.githubusercontent.com/WorkAccount211/VoidCriptUI_lib-Final-/refs/heads/main/images/symbol.png"

	function MobileToggle.new(window, cfg)
		cfg = cfg or {}
		local self = setmetatable({
			_window = window,
			_maid = Void.Maid.new("MobileToggle"),
			_size = Scale.touch(cfg.Size or 46),
		}, MobileToggle)

		local gui = Util.Screen("VoidCriptFloatingToggle")
		gui.DisplayOrder = 98500
		self._gui = gui
		self._maid:Give(gui)

		local canvas = Util.New("CanvasGroup", {
			Name = "Canvas",
			BackgroundTransparency = 1,
			GroupTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = cfg.Position or UDim2.new(0, Scale.u(40), 0.5, -Scale.u(80)),
			Size = UDim2.fromOffset(self._size, self._size),
			Parent = gui,
		})
		self._canvas = canvas

		-- outer pulse ring
		local ring = Util.New("Frame", {
			Name = "Ring",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			Parent = canvas,
		})
		Util.Corner(ring, 999)
		local ringStroke = Util.Stroke(ring, Theme.C.Accent, 1, 0.4)
		Theme:Paint(ringStroke, { Color = "Accent" })
		self._ring, self._ringStroke = ring, ringStroke

		local button = Util.New("ImageButton", {
			Name = "Bubble",
			BackgroundColor3 = Theme.C.Header,
			BackgroundTransparency = 0,
			Image = "",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.86, 0.86),
			Parent = canvas,
		})
		Theme:Paint(button, { BackgroundColor3 = "Header" })
		Util.Corner(button, 999)
		local stroke = Util.Stroke(button, Theme.C.Outline)
		Theme:Paint(stroke, { Color = "Outline" })
		self._button = button

		-- inner glass sheen
		Util.New("Frame", {
			Name = "Sheen",
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0.93,
			Size = UDim2.fromScale(1, 1),
			Parent = button,
		}, {
			Util.New("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Util.New("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.4),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})

		local logo = Util.New("ImageLabel", {
			Name = "Symbol",
			Image = cfg.Icon or SYMBOL,
			ScaleType = Enum.ScaleType.Fit,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.58, 0.58),
			Parent = button,
		})
		self._logo = logo

		-- ── drag vs tap discrimination ──────────────────────────────────
		local dragStart, startPos, moved = nil, nil, false

		self._maid:Give(button.InputBegan:Connect(function(input)
			local t = input.UserInputType
			if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
			dragStart = input.Position
			startPos = canvas.Position
			moved = false
			Util.Tween(button, { Size = UDim2.fromScale(0.78, 0.78) }, Util.Motion.Fast)
		end))

		self._maid:Give(UserInputService.InputChanged:Connect(function(input)
			if not dragStart then return end
			local t = input.UserInputType
			if t ~= Enum.UserInputType.MouseMovement and t ~= Enum.UserInputType.Touch then return end
			local delta = input.Position - dragStart
			if delta.Magnitude > 6 then moved = true end
			local viewport = Util.Viewport()
			local half = self._size / 2
			canvas.Position = UDim2.new(
				0, math.clamp(startPos.X.Scale * viewport.X + startPos.X.Offset + delta.X, half, viewport.X - half),
				0, math.clamp(startPos.Y.Scale * viewport.Y + startPos.Y.Offset + delta.Y, half, viewport.Y - half)
			)
		end))

		self._maid:Give(UserInputService.InputEnded:Connect(function(input)
			local t = input.UserInputType
			if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
			if not dragStart then return end
			dragStart = nil
			Util.Tween(button, { Size = UDim2.fromScale(0.86, 0.86) }, Util.Motion.Normal, Enum.EasingStyle.Back)
			if moved then
				self:_snapToEdge()
			else
				self:_pulse()
				window:Toggle()
			end
		end))

		self._maid:Give(button.MouseEnter:Connect(function()
			Util.Tween(button, { BackgroundColor3 = Theme.C.ElementHover }, Util.Motion.Fast)
			Util.Tween(ringStroke, { Transparency = 0.1 }, Util.Motion.Fast)
		end))
		self._maid:Give(button.MouseLeave:Connect(function()
			Util.Tween(button, { BackgroundColor3 = Theme.C.Header }, Util.Motion.Fast)
			Util.Tween(ringStroke, { Transparency = 0.4 }, Util.Motion.Fast)
		end))

		self._maid:Give(Void.Scale:OnChanged(function()
			self._size = Scale.touch(cfg.Size or 46)
			canvas.Size = UDim2.fromOffset(self._size, self._size)
		end))

		Util.Tween(canvas, { GroupTransparency = 0 }, Util.Motion.Slow)
		Void.Tooltip:Attach(button, cfg.Tooltip or "Tap to open the menu · drag to move", self._maid)
		return self
	end

	-- Snap to the nearest screen edge so the bubble never floats awkwardly.
	function MobileToggle:_snapToEdge()
		local viewport = Util.Viewport()
		local pos = self._canvas.AbsolutePosition + self._canvas.AbsoluteSize / 2
		local margin = self._size / 2 + Scale.u(10)
		local targetX = pos.X < viewport.X / 2 and margin or viewport.X - margin
		local targetY = math.clamp(pos.Y, margin, viewport.Y - margin)
		Util.Tween(self._canvas, { Position = UDim2.fromOffset(targetX, targetY) }, Util.Motion.Slow, Enum.EasingStyle.Quint)
	end

	function MobileToggle:_pulse()
		self._ring.Size = UDim2.fromScale(1, 1)
		self._ringStroke.Transparency = 0.05
		Util.Tween(self._ring, { Size = UDim2.fromScale(1.6, 1.6) }, 0.36)
		Util.Tween(self._ringStroke, { Transparency = 1 }, 0.36)
		task.delay(0.4, function()
			if self._ring and self._ring.Parent then
				self._ring.Size = UDim2.fromScale(1, 1)
				self._ringStroke.Transparency = 0.4
			end
		end)
	end

	-- Called by the window when it hides/shows so the bubble reflects state.
	function MobileToggle:SetWindowVisible(visible)
		if not self._logo then return end
		Util.Tween(self._logo, { ImageTransparency = visible and 0.35 or 0 }, Util.Motion.Normal)
		Util.Tween(self._canvas, { Size = UDim2.fromOffset(
			visible and self._size or math.floor(self._size * 1.08),
			visible and self._size or math.floor(self._size * 1.08)
		) }, Util.Motion.Normal, Enum.EasingStyle.Back)
		if not visible then self:_pulse() end
	end

	function MobileToggle:Show()
		self._canvas.Visible = true
		Util.Tween(self._canvas, { GroupTransparency = 0 }, Util.Motion.Normal)
	end

	function MobileToggle:Hide()
		Util.Tween(self._canvas, { GroupTransparency = 1 }, Util.Motion.Normal)
		task.delay(Util.Motion.Normal + 0.05, function()
			if self._canvas then self._canvas.Visible = false end
		end)
	end

	function MobileToggle:Destroy()
		self._maid:Destroy()
	end

	Void.MobileToggle = MobileToggle
	return MobileToggle
end
