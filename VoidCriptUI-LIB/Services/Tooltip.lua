--[[
	VoidCriptUI · Services/Tooltip.lua
	Hover tooltips with a delay and throttled follow (roadmap: UX section).

	Behaviour:
	  · appears only after HoverDelay (default 0.5s) of continuous hover
	  · follows the cursor at most every UpdateInterval (default 0.05s), never
	    per frame
	  · flips to stay inside the viewport
	  · on touch devices a long-press (0.35s) shows it instead
	  · one shared ScreenGui + one shared label for the whole library

	Attach automatically by passing `Tooltip = "text"` to any element, or
	manually with `VoidLib.Tooltip:Attach(instance, "text")`.
]]

return function(Void)
	local Util, Theme, Scale = Void.Util, Void.Theme, Void.Scale
	local UserInputService = game:GetService("UserInputService")

	local Tooltip = {
		HoverDelay = 0.5,
		UpdateInterval = 0.05,
		Enabled = true,
		_gui = nil,
		_current = nil,
	}

	local function build()
		if Tooltip._gui then return end

		local gui = Util.Screen("VoidCriptTooltip", Void.RootMaid)
		gui.DisplayOrder = 100000
		Tooltip._gui = gui

		-- CanvasGroup gives us a single-draw fade for the whole tooltip.
		local canvas = Util.New("CanvasGroup", {
			Name = "Canvas",
			BackgroundTransparency = 1,
			GroupTransparency = 1,
			Size = UDim2.fromOffset(1, 1),
			AutomaticSize = Enum.AutomaticSize.XY,
			Visible = false,
			ZIndex = 100,
			Parent = gui,
		})
		Tooltip._canvas = canvas

		local card = Util.New("Frame", {
			Name = "Card",
			BackgroundColor3 = Theme.C.Overlay,
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			Parent = canvas,
		})
		Theme:Paint(card, { BackgroundColor3 = "Overlay" })
		Util.Corner(card, Theme.Style.RadiusSmall)
		local stroke = Util.Stroke(card, Theme.C.Outline)
		Theme:Paint(stroke, { Color = "Outline" })

		-- accent bar on the left (CompKiller signature)
		local bar = Util.New("Frame", {
			Name = "Accent",
			BackgroundColor3 = Theme.C.Accent,
			Size = UDim2.new(0, 2, 1, 0),
			Parent = card,
		})
		Theme:Paint(bar, { BackgroundColor3 = "Accent" })

		local label = Util.New("TextLabel", {
			Name = "Text",
			Font = Theme:Font("Font"),
			Text = "",
			TextColor3 = Theme.C.Text,
			TextSize = Scale.f(12),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			RichText = true,
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			Parent = card,
		}, {
			Util.New("UIPadding", {
				PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 9),
				PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6),
			}),
			Util.New("UISizeConstraint", { MaxSize = Vector2.new(280, math.huge) }),
		})
		Theme:Paint(label, { TextColor3 = "Text" })
		Tooltip._label = label
	end

	local function place(x, y)
		local canvas = Tooltip._canvas
		if not canvas then return end
		local viewport = Util.Viewport()
		local size = canvas.AbsoluteSize
		local px = x + 16
		local py = y + 14
		if px + size.X > viewport.X - 8 then px = x - size.X - 10 end
		if py + size.Y > viewport.Y - 8 then py = y - size.Y - 10 end
		canvas.Position = UDim2.fromOffset(math.max(4, px), math.max(4, py))
	end

	function Tooltip:Show(text, x, y)
		if not self.Enabled or not text or text == "" then return end
		build()
		self._label.Text = Void.RichText.Parse(text)
		self._canvas.Visible = true
		place(x, y)
		Util.Tween(self._canvas, { GroupTransparency = 0 }, Util.Motion.Fast)
	end

	function Tooltip:Hide()
		if not self._canvas or not self._canvas.Visible then return end
		local canvas = self._canvas
		local tween = Util.Tween(canvas, { GroupTransparency = 1 }, Util.Motion.Fast)
		if tween then
			tween.Completed:Once(function()
				if canvas.GroupTransparency >= 0.99 then canvas.Visible = false end
			end)
		else
			canvas.Visible = false
		end
	end

	-- Attach to any GuiObject. Returns a detach function.
	function Tooltip:Attach(instance, text, maid)
		if not instance or not text or text == "" then return function() end end
		build()

		local hoverThread, moveClock = nil, 0
		local shown = false
		local lastPos = Vector2.new()

		local function cancel()
			if hoverThread then
				task.cancel(hoverThread)
				hoverThread = nil
			end
			if shown then
				shown = false
				Tooltip:Hide()
			end
		end

		local connections = {}

		connections[#connections + 1] = instance.MouseEnter:Connect(function(x, y)
			lastPos = Vector2.new(x, y)
			if hoverThread then task.cancel(hoverThread) end
			hoverThread = task.delay(Tooltip.HoverDelay, function()
				hoverThread = nil
				shown = true
				Tooltip._current = instance
				Tooltip:Show(text, lastPos.X, lastPos.Y)
			end)
		end)

		connections[#connections + 1] = instance.MouseLeave:Connect(cancel)

		connections[#connections + 1] = instance.InputChanged:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
			lastPos = Vector2.new(input.Position.X, input.Position.Y)
			if not shown then return end
			-- throttled follow: no per-frame updates
			local now = os.clock()
			if now - moveClock < Tooltip.UpdateInterval then return end
			moveClock = now
			place(lastPos.X, lastPos.Y)
		end)

		-- touch: long press reveals the tooltip
		connections[#connections + 1] = instance.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Touch then return end
			lastPos = Vector2.new(input.Position.X, input.Position.Y)
			if hoverThread then task.cancel(hoverThread) end
			hoverThread = task.delay(0.35, function()
				hoverThread = nil
				shown = true
				Tooltip:Show(text, lastPos.X, lastPos.Y - 40)
			end)
		end)
		connections[#connections + 1] = instance.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				task.delay(1.2, cancel)
			end
		end)

		if maid then
			for _, c in ipairs(connections) do maid:Give(c) end
			maid:Give(cancel)
		end

		return function()
			for _, c in ipairs(connections) do
				pcall(function() c:Disconnect() end)
			end
			cancel()
		end
	end

	function Tooltip:SetEnabled(state)
		self.Enabled = state and true or false
		if not self.Enabled then self:Hide() end
		return self.Enabled
	end

	function Tooltip:SetDelay(seconds)
		self.HoverDelay = math.max(0, tonumber(seconds) or 0.5)
		return self.HoverDelay
	end

	Void.Tooltip = Tooltip
	return Tooltip
end
