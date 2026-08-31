--[[
	VoidCriptUI · Services/Dialog.lua
	Modal dialogs: confirmation ("Are you sure?"), prompt, and choice.

	Used automatically by any element marked `Risky = true` / `Confirm = true`,
	and available directly:

		VoidLib:Dialog({
			Title = "Delete config",
			Content = "This **cannot** be undone.",
			Accept = "Delete", Decline = "Keep",
			OnAccept = function() end,
		})

		VoidLib.Dialog:Prompt({ Title = "Config name", Default = "default",
			OnAccept = function(text) end })

	The dialog owns a Backdrop (deep dim + glass) and scales itself with the
	adaptive unit system, so it is usable on a phone.
]]

return function(Void)
	local Util, Theme, Scale = Void.Util, Void.Theme, Void.Scale
	local UserInputService = game:GetService("UserInputService")

	local Dialog = { _open = nil }

	local function close(self)
		if not self then return end
		if self._maid then self._maid:Destroy() end
		if self._backdrop then self._backdrop:Hide(Util.Motion.Fast, true) end
		local canvas = self._canvas
		if canvas then
			Util.Tween(canvas, { GroupTransparency = 1 }, Util.Motion.Fast)
			Util.Tween(self._card, { Size = self._smallSize }, Util.Motion.Fast)
			task.delay(Util.Motion.Fast + 0.05, function()
				if self._gui then self._gui:Destroy() end
			end)
		elseif self._gui then
			self._gui:Destroy()
		end
		if Dialog._open == self then Dialog._open = nil end
	end

	local function build(cfg)
		local instance = { _maid = Void.Maid.new("Dialog") }

		local gui = Util.Screen("VoidCriptDialog")
		gui.DisplayOrder = 99500
		instance._gui = gui
		instance._maid:Give(gui)

		instance._backdrop = Void.Backdrop.new(gui, { Strength = 0.55, ZIndex = 0, Clickable = cfg.DismissOnBackdrop ~= false })
		instance._backdrop:Show(Util.Motion.Normal)

		local width = math.min(Scale.u(360), Util.Viewport().X - Scale.u(40))
		local canvas = Util.New("CanvasGroup", {
			Name = "Canvas",
			BackgroundTransparency = 1,
			GroupTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(width, Scale.u(200)),
			AutomaticSize = Enum.AutomaticSize.Y,
			ZIndex = 5,
			Parent = gui,
		})
		instance._canvas = canvas

		local card = Util.New("Frame", {
			Name = "Card",
			BackgroundColor3 = Theme.C.Background,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = canvas,
		})
		Theme:Paint(card, { BackgroundColor3 = "Background" })
		Util.Corner(card, Theme.Style.Radius + 2)
		local stroke = Util.Stroke(card, Theme.C.Outline)
		Theme:Paint(stroke, { Color = "Outline" })
		Util.Glass(card, 0.96)
		instance._card = card
		instance._smallSize = UDim2.fromOffset(math.floor(width * 0.9), Scale.u(180))

		-- top accent line
		local accentToken = cfg.Danger and "Danger" or (cfg.Risky and "Risky" or "Accent")
		local line = Util.New("Frame", {
			BackgroundColor3 = Theme.C[accentToken],
			Size = UDim2.new(1, 0, 0, 2),
			ZIndex = 4,
			Parent = card,
		})
		Theme:Paint(line, { BackgroundColor3 = accentToken })

		local body = Util.New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = card,
		}, {
			Util.New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, Scale.u(10)) }),
			Util.New("UIPadding", {
				PaddingLeft = UDim.new(0, Scale.u(16)), PaddingRight = UDim.new(0, Scale.u(16)),
				PaddingTop = UDim.new(0, Scale.u(16)), PaddingBottom = UDim.new(0, Scale.u(14)),
			}),
		})
		instance._body = body

		local titleRow = Util.New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, Scale.u(20)),
			LayoutOrder = 1,
			Parent = body,
		})
		local iconKind, iconValue = Void.Icons:Resolve(cfg.Icon or (cfg.Danger and "warning" or "question"))
		local offset = 0
		if iconValue and iconKind == "text" then
			local glyph = Util.New("TextLabel", {
				Font = Theme:Font("FontBold"),
				Text = iconValue,
				TextColor3 = Theme.C[accentToken],
				TextSize = Scale.f(16),
				Size = UDim2.fromOffset(Scale.u(20), Scale.u(20)),
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = titleRow,
			})
			Theme:Paint(glyph, { TextColor3 = accentToken })
			offset = Scale.u(24)
		end
		local title = Util.New("TextLabel", {
			Font = Theme:Font("FontBold"),
			Text = tostring(cfg.Title or "Are you sure?"),
			TextColor3 = Theme.C.Text,
			TextSize = Scale.f(15),
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(offset, 0),
			Size = UDim2.new(1, -offset, 1, 0),
			Parent = titleRow,
		})
		Theme:Paint(title, { TextColor3 = "Text" })

		if cfg.Content and cfg.Content ~= "" then
			local content = Util.New("TextLabel", {
				Font = Theme:Font("Font"),
				Text = Void.RichText.Parse(cfg.Content),
				RichText = true,
				TextColor3 = Theme.C.TextDim,
				TextSize = Scale.f(12),
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
				Parent = body,
			})
			Theme:Paint(content, { TextColor3 = "TextDim" })
		end

		return instance
	end

	local function addButtonRow(instance, cfg, buttons)
		local row = Util.New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, Scale.touch(30)),
			LayoutOrder = 10,
			Parent = instance._body,
		}, {
			Util.New("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Scale.u(8)),
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
			}),
		})

		for index, spec in ipairs(buttons) do
			local primary = spec.Primary
			local token = primary and (cfg.Danger and "Danger" or "Accent") or "Element"
			local btn = Util.New("TextButton", {
				BackgroundColor3 = Theme.C[token],
				Font = Theme:Font("FontMedium"),
				Text = tostring(spec.Text),
				TextColor3 = primary and Theme.C.TextOnAccent or Theme.C.Text,
				TextSize = Scale.f(12),
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				LayoutOrder = index,
				Parent = row,
			}, {
				Util.New("UIPadding", { PaddingLeft = UDim.new(0, Scale.u(16)), PaddingRight = UDim.new(0, Scale.u(16)) }),
			})
			Theme:Paint(btn, { BackgroundColor3 = token, TextColor3 = primary and "TextOnAccent" or "Text" })
			Util.Corner(btn, Theme.Style.RadiusSmall)
			if not primary then
				local s = Util.Stroke(btn, Theme.C.Outline)
				Theme:Paint(s, { Color = "Outline" })
			end
			btn.MouseEnter:Connect(function()
				Util.Tween(btn, { BackgroundColor3 = primary and Theme.C.AccentDark or Theme.C.ElementHover }, Util.Motion.Fast)
			end)
			btn.MouseLeave:Connect(function()
				Util.Tween(btn, { BackgroundColor3 = Theme.C[token] }, Util.Motion.Fast)
			end)
			btn.MouseButton1Click:Connect(function()
				if spec.OnClick then spec.OnClick() end
			end)
			spec.Instance = btn
		end
		return row
	end

	local function present(instance, cfg)
		-- pop-in animation
		instance._card.Size = instance._smallSize
		Util.Tween(instance._canvas, { GroupTransparency = 0 }, Util.Motion.Normal)
		Util.Tween(instance._card, { Size = UDim2.new(1, 0, 0, 0) }, Util.Motion.Slow, Enum.EasingStyle.Back)
		instance._card.Size = UDim2.new(1, 0, 0, 0)

		if instance._backdrop.OnClick and cfg.DismissOnBackdrop ~= false then
			instance._maid:Give(instance._backdrop.OnClick:Connect(function()
				close(instance)
				if cfg.OnDecline then Void.Log:GuardAsync("dialog decline", cfg.OnDecline) end
			end))
		end

		instance._maid:Give(UserInputService.InputBegan:Connect(function(input, gpe)
			if gpe then return end
			if input.KeyCode == Enum.KeyCode.Escape then
				close(instance)
				if cfg.OnDecline then Void.Log:GuardAsync("dialog decline", cfg.OnDecline) end
			end
		end))

		Dialog._open = instance
		return instance
	end

	-- ── public ──────────────────────────────────────────────────────────
	function Dialog:Confirm(cfg)
		cfg = cfg or {}
		if self._open then close(self._open) end
		local instance = build(cfg)

		local handle = {}
		addButtonRow(instance, cfg, {
			{
				Text = cfg.Decline or "Cancel",
				OnClick = function()
					close(instance)
					if cfg.OnDecline then Void.Log:GuardAsync("dialog decline", cfg.OnDecline) end
				end,
			},
			{
				Text = cfg.Accept or "Confirm",
				Primary = true,
				OnClick = function()
					close(instance)
					if cfg.OnAccept then Void.Log:GuardAsync("dialog accept", cfg.OnAccept) end
				end,
			},
		})

		present(instance, cfg)
		function handle:Close() close(instance) end
		return handle
	end

	function Dialog:Prompt(cfg)
		cfg = cfg or {}
		if self._open then close(self._open) end
		local instance = build(cfg)

		local box = Util.New("TextBox", {
			BackgroundColor3 = Theme.C.Element,
			Font = Theme:Font("Font"),
			PlaceholderText = cfg.Placeholder or "",
			PlaceholderColor3 = Theme.C.TextDark,
			Text = tostring(cfg.Default or ""),
			TextColor3 = Theme.C.Text,
			TextSize = Scale.f(12),
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, Scale.touch(28)),
			LayoutOrder = 5,
			Parent = instance._body,
		}, {
			Util.New("UIPadding", { PaddingLeft = UDim.new(0, Scale.u(9)), PaddingRight = UDim.new(0, Scale.u(9)) }),
		})
		Theme:Paint(box, { BackgroundColor3 = "Element", TextColor3 = "Text", PlaceholderColor3 = "TextDark" })
		Util.Corner(box, Theme.Style.RadiusSmall)
		local boxStroke = Util.Stroke(box, Theme.C.OutlineSoft)
		instance._maid:Give(box.Focused:Connect(function()
			Util.Tween(boxStroke, { Color = Theme.C.Accent }, Util.Motion.Fast)
		end))
		instance._maid:Give(box.FocusLost:Connect(function(enter)
			Util.Tween(boxStroke, { Color = Theme.C.OutlineSoft }, Util.Motion.Fast)
			if enter then
				close(instance)
				if cfg.OnAccept then Void.Log:GuardAsync("prompt accept", cfg.OnAccept, box.Text) end
			end
		end))

		addButtonRow(instance, cfg, {
			{
				Text = cfg.Decline or "Cancel",
				OnClick = function()
					close(instance)
					if cfg.OnDecline then Void.Log:GuardAsync("prompt decline", cfg.OnDecline) end
				end,
			},
			{
				Text = cfg.Accept or "OK",
				Primary = true,
				OnClick = function()
					local value = box.Text
					close(instance)
					if cfg.OnAccept then Void.Log:GuardAsync("prompt accept", cfg.OnAccept, value) end
				end,
			},
		})

		present(instance, cfg)
		task.defer(function() pcall(function() box:CaptureFocus() end) end)
		return { Close = function() close(instance) end }
	end

	-- Multi-choice dialog: cfg.Choices = { {Text=..., Callback=...}, ... }
	function Dialog:Choice(cfg)
		cfg = cfg or {}
		if self._open then close(self._open) end
		local instance = build(cfg)

		local buttons = {}
		for index, choice in ipairs(cfg.Choices or {}) do
			buttons[#buttons + 1] = {
				Text = choice.Text or ("Option " .. index),
				Primary = choice.Primary,
				OnClick = function()
					close(instance)
					if choice.Callback then Void.Log:GuardAsync("dialog choice", choice.Callback) end
				end,
			}
		end
		buttons[#buttons + 1] = {
			Text = cfg.Decline or "Cancel",
			OnClick = function() close(instance) end,
		}
		addButtonRow(instance, cfg, buttons)
		present(instance, cfg)
		return { Close = function() close(instance) end }
	end

	function Dialog:CloseAll()
		if self._open then close(self._open) end
	end

	Void.Dialog = Dialog
	return Dialog
end
