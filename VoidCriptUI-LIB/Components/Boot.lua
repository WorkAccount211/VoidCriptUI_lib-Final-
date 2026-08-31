--[[
	VoidCriptUI · Components/Boot.lua
	The loading screen.

	Appearance: a deep-dimmed glass backdrop, then the panel scales out from
	the centre (0.86 → 1.00 with a Back ease) while its CanvasGroup fades in.
	Inside, top to bottom: the VoidCript symbol, the product name, a stage
	label, the progress bar, and a footer with "% · ETA · elapsed".

	ETA is a moving average of the last few stage durations extrapolated over
	the remaining progress, so it settles quickly instead of jumping around.

		local boot = VoidLib:Boot({ Title = "voidcript", Subtitle = "universal" })
		boot:SetStage("Fetching modules", 0.25)
		boot:Step("Building UI")          -- advances one weighted step
		boot:Finish()                     -- fills to 100% and dissolves
		boot:Fail("Download failed")      -- red state, stays for a moment

	The whole thing is one CanvasGroup, so fade-in/out is a single tween — no
	per-descendant transparency loop.
]]

return function(Void)
	local Util, Theme, Scale = Void.Util, Void.Theme, Void.Scale

	local Boot = {}
	Boot.__index = Boot

	local SYMBOL = "https://raw.githubusercontent.com/WorkAccount211/VoidCriptUI_lib-Final-/refs/heads/main/images/symbol.png"

	function Boot.new(cfg)
		cfg = cfg or {}
		local self = setmetatable({
			_maid = Void.Maid.new("Boot"),
			_progress = 0,
			_target = 0,
			_start = os.clock(),
			_stageTimes = {},
			_steps = cfg.Steps or 0,
			_step = 0,
			_done = false,
			_cancellable = cfg.Cancellable ~= false,
		}, Boot)

		local gui = Util.Screen("VoidCriptBoot")
		gui.DisplayOrder = 99800
		self._gui = gui
		self._maid:Give(gui)

		-- backdrop: deep dim + glass, click does nothing (modal)
		self._backdrop = Void.Backdrop.new(gui, { Strength = cfg.Dim or 0.5, ZIndex = 0 })
		self._backdrop:Show(Util.Motion.Slow)

		local width = math.min(Scale.u(cfg.Width or 380), Util.Viewport().X - Scale.u(40))
		local canvas = Util.New("CanvasGroup", {
			Name = "Canvas",
			BackgroundTransparency = 1,
			GroupTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(width, Scale.u(232)),
			ZIndex = 5,
			Parent = gui,
		})
		self._canvas = canvas

		local scaler = Util.New("UIScale", { Scale = 0.86, Parent = canvas })
		self._scaler = scaler

		local card = Util.New("Frame", {
			Name = "Card",
			BackgroundColor3 = Theme.C.Background,
			Size = UDim2.fromScale(1, 1),
			Parent = canvas,
		})
		Theme:Paint(card, { BackgroundColor3 = "Background" })
		Util.Corner(card, Theme.Style.Radius + 3)
		local stroke = Util.Stroke(card, Theme.C.Outline)
		Theme:Paint(stroke, { Color = "Outline" })
		Util.Glass(card, 0.955)
		self._card = card

		-- top accent line, animates as a "scanner" while loading
		local accent = Util.New("Frame", {
			Name = "Accent",
			BackgroundColor3 = Theme.C.Accent,
			Size = UDim2.new(0.35, 0, 0, 2),
			ZIndex = 6,
			Parent = card,
		})
		Theme:Paint(accent, { BackgroundColor3 = "Accent" })
		self._accent = accent

		local content = Util.New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Parent = card,
		}, {
			Util.New("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Scale.u(8)),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			Util.New("UIPadding", {
				PaddingLeft = UDim.new(0, Scale.u(22)), PaddingRight = UDim.new(0, Scale.u(22)),
				PaddingTop = UDim.new(0, Scale.u(20)), PaddingBottom = UDim.new(0, Scale.u(18)),
			}),
		})

		-- ── logo ────────────────────────────────────────────────────────
		local logoHolder = Util.New("Frame", {
			Name = "Logo",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(Scale.u(64), Scale.u(64)),
			LayoutOrder = 1,
			Parent = content,
		})

		local glow = Util.New("ImageLabel", {
			Name = "Glow",
			Image = "rbxassetid://6014261993",
			ImageColor3 = Theme.C.Accent,
			ImageTransparency = 0.55,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(49, 49, 450, 450),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, Scale.u(34), 1, Scale.u(34)),
			ZIndex = 1,
			Parent = logoHolder,
		})
		Theme:Paint(glow, { ImageColor3 = "Accent" })

		local logo = Util.New("ImageLabel", {
			Name = "Symbol",
			Image = cfg.Logo or SYMBOL,
			ImageTransparency = 0,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
			Parent = logoHolder,
		})
		self._logo = logo

		-- gentle breathing pulse on the glow while loading
		self._pulse = task.spawn(function()
			while not self._done and glow.Parent do
				Util.Tween(glow, { ImageTransparency = 0.3 }, 0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				task.wait(0.9)
				if self._done then break end
				Util.Tween(glow, { ImageTransparency = 0.62 }, 0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				task.wait(0.9)
			end
		end)
		self._maid:Give(self._pulse)

		-- ── titles ──────────────────────────────────────────────────────
		local title = Util.New("TextLabel", {
			Font = Theme:Font("FontBold"),
			Text = tostring(cfg.Title or "voidcript"),
			TextColor3 = Theme.C.Text,
			TextSize = Scale.f(19),
			Size = UDim2.new(1, 0, 0, Scale.u(22)),
			LayoutOrder = 2,
			Parent = content,
		})
		Theme:Paint(title, { TextColor3 = "Text" })

		local subtitle = Util.New("TextLabel", {
			Font = Theme:Font("Font"),
			Text = tostring(cfg.Subtitle or "ui library"),
			TextColor3 = Theme.C.Accent,
			TextSize = Scale.f(11),
			Size = UDim2.new(1, 0, 0, Scale.u(14)),
			LayoutOrder = 3,
			Parent = content,
		})
		Theme:Paint(subtitle, { TextColor3 = "Accent" })

		-- ── stage label ─────────────────────────────────────────────────
		local stage = Util.New("TextLabel", {
			Font = Theme:Font("Font"),
			Text = cfg.Stage or "Initialising…",
			TextColor3 = Theme.C.TextDim,
			TextSize = Scale.f(12),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, 0, 0, Scale.u(16)),
			LayoutOrder = 4,
			Parent = content,
		})
		Theme:Paint(stage, { TextColor3 = "TextDim" })
		self._stage = stage

		-- ── progress bar ────────────────────────────────────────────────
		local track = Util.New("Frame", {
			Name = "Track",
			BackgroundColor3 = Theme.C.Element,
			Size = UDim2.new(1, 0, 0, Scale.u(6)),
			LayoutOrder = 5,
			Parent = content,
		})
		Theme:Paint(track, { BackgroundColor3 = "Element" })
		Util.Corner(track, 3)
		local trackStroke = Util.Stroke(track, Theme.C.OutlineSoft)
		Theme:Paint(trackStroke, { Color = "OutlineSoft" })

		local fill = Util.New("Frame", {
			Name = "Fill",
			BackgroundColor3 = Theme.C.Accent,
			Size = UDim2.fromScale(0, 1),
			Parent = track,
		})
		Theme:Paint(fill, { BackgroundColor3 = "Accent" })
		Util.Corner(fill, 3)
		self._fill = fill

		-- animated sheen sliding across the fill
		Util.New("Frame", {
			Name = "Sheen",
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.75,
			Size = UDim2.fromScale(1, 1),
			Parent = fill,
		}, {
			Util.New("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 0.35),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})

		-- ── footer: percent · eta · elapsed ─────────────────────────────
		local footer = Util.New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, Scale.u(14)),
			LayoutOrder = 6,
			Parent = content,
		})
		local percent = Util.New("TextLabel", {
			Font = Theme:Font("FontMedium"),
			Text = "0%",
			TextColor3 = Theme.C.Text,
			TextSize = Scale.f(11),
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.fromScale(0.3, 1),
			Parent = footer,
		})
		Theme:Paint(percent, { TextColor3 = "Text" })
		self._percent = percent

		local eta = Util.New("TextLabel", {
			Font = Theme:Font("Font"),
			Text = "estimating…",
			TextColor3 = Theme.C.TextDark,
			TextSize = Scale.f(11),
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromScale(0.3, 0),
			Size = UDim2.fromScale(0.4, 1),
			Parent = footer,
		})
		Theme:Paint(eta, { TextColor3 = "TextDark" })
		self._eta = eta

		local elapsed = Util.New("TextLabel", {
			Font = Theme:Font("Font"),
			Text = "0.0s",
			TextColor3 = Theme.C.TextDark,
			TextSize = Scale.f(11),
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.fromScale(0.7, 0),
			Size = UDim2.fromScale(0.3, 1),
			Parent = footer,
		})
		Theme:Paint(elapsed, { TextColor3 = "TextDark" })
		self._elapsed = elapsed

		-- ── optional cancel button (async loading) ──────────────────────
		if self._cancellable then
			local cancel = Util.New("TextButton", {
				Name = "Cancel",
				BackgroundColor3 = Theme.C.Element,
				Font = Theme:Font("FontMedium"),
				Text = cfg.CancelText or "Cancel",
				TextColor3 = Theme.C.TextDim,
				TextSize = Scale.f(11),
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 0, Scale.touch(22)),
				LayoutOrder = 7,
				Parent = content,
			}, {
				Util.New("UIPadding", { PaddingLeft = UDim.new(0, Scale.u(14)), PaddingRight = UDim.new(0, Scale.u(14)) }),
			})
			Theme:Paint(cancel, { BackgroundColor3 = "Element", TextColor3 = "TextDim" })
			Util.Corner(cancel, Theme.Style.RadiusSmall)
			local cs = Util.Stroke(cancel, Theme.C.OutlineSoft)
			self._maid:Give(cancel.MouseEnter:Connect(function()
				Util.Tween(cancel, { BackgroundColor3 = Theme.C.ElementHover }, Util.Motion.Fast)
				Util.Tween(cs, { Color = Theme.C.Danger }, Util.Motion.Fast)
			end))
			self._maid:Give(cancel.MouseLeave:Connect(function()
				Util.Tween(cancel, { BackgroundColor3 = Theme.C.Element }, Util.Motion.Fast)
				Util.Tween(cs, { Color = Theme.C.OutlineSoft }, Util.Motion.Fast)
			end))
			self._maid:Give(cancel.MouseButton1Click:Connect(function()
				self:Cancel()
			end))
			self._cancelButton = cancel
		end

		-- ── entrance: expand from the centre ────────────────────────────
		Util.Tween(canvas, { GroupTransparency = 0 }, Util.Motion.Boot)
		Util.Tween(scaler, { Scale = 1 }, Util.Motion.Boot, Enum.EasingStyle.Back)

		-- scanner animation on the accent line
		self._scanner = task.spawn(function()
			while not self._done and accent.Parent do
				accent.Position = UDim2.fromScale(-0.35, 0)
				Util.Tween(accent, { Position = UDim2.fromScale(1, 0) }, 1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				task.wait(1.25)
			end
		end)
		self._maid:Give(self._scanner)

		-- ticker for elapsed/ETA (2 Hz — cheap and readable)
		self._ticker = task.spawn(function()
			while not self._done do
				self:_refreshTiming()
				task.wait(0.25)
			end
		end)
		self._maid:Give(self._ticker)

		self.OnCancel = Void.Signal.new("BootCancel")
		return self
	end

	function Boot:_refreshTiming()
		if not self._elapsed or not self._elapsed.Parent then return end
		local elapsed = os.clock() - self._start
		self._elapsed.Text = string.format("%.1fs", elapsed)

		if self._progress <= 0.001 then
			self._eta.Text = "estimating…"
			return
		end
		if self._progress >= 0.999 then
			self._eta.Text = "done"
			return
		end
		-- linear extrapolation on the smoothed rate
		local rate = self._progress / math.max(elapsed, 0.001)
		local remaining = (1 - self._progress) / math.max(rate, 0.0001)
		if remaining > 120 then
			self._eta.Text = "~ a while left"
		elseif remaining >= 1 then
			self._eta.Text = string.format("~%ds left", math.ceil(remaining))
		else
			self._eta.Text = "~1s left"
		end
	end

	-- progress: 0..1
	function Boot:SetProgress(progress)
		progress = math.clamp(tonumber(progress) or 0, 0, 1)
		self._progress = progress
		Util.Tween(self._fill, { Size = UDim2.fromScale(progress, 1) }, Util.Motion.Slow, Enum.EasingStyle.Quint)
		self._percent.Text = string.format("%d%%", math.floor(progress * 100 + 0.5))
		self:_refreshTiming()
		return self
	end

	function Boot:SetStage(text, progress)
		if text then
			self._stage.Text = tostring(text)
			-- tiny fade so the change is noticeable but not distracting
			self._stage.TextTransparency = 0.6
			Util.Tween(self._stage, { TextTransparency = 0 }, Util.Motion.Normal)
			table.insert(self._stageTimes, os.clock())
		end
		if progress then self:SetProgress(progress) end
		return self
	end

	-- Advance one weighted step out of cfg.Steps.
	function Boot:Step(text)
		self._step = self._step + 1
		local total = math.max(self._steps, self._step)
		self:SetStage(text, self._step / (total + 0.35))
		return self
	end

	function Boot:SetTitle(text)
		if self._card then
			local title = self._card:FindFirstChild("TextLabel", true)
			if title then title.Text = tostring(text) end
		end
		return self
	end

	function Boot:Cancel()
		if self._done then return end
		self._cancelled = true
		self:SetStage("Cancelled", self._progress)
		Util.Tween(self._fill, { BackgroundColor3 = Theme.C.Risky }, Util.Motion.Fast)
		Theme:Unpaint(self._fill)
		self.OnCancel:Fire()
		task.delay(0.4, function() self:Destroy() end)
	end

	function Boot:IsCancelled()
		return self._cancelled == true
	end

	function Boot:Fail(message)
		self._done = true
		self:SetStage(message or "Failed to load", self._progress)
		Theme:Unpaint(self._fill)
		Util.Tween(self._fill, { BackgroundColor3 = Theme.C.Danger }, Util.Motion.Normal)
		Util.Tween(self._accent, { BackgroundColor3 = Theme.C.Danger }, Util.Motion.Normal)
		self._eta.Text = "aborted"
		Void.Log:Error("boot failed: %s", tostring(message))
		task.delay(3, function() self:Destroy() end)
		return self
	end

	function Boot:Finish(message, holdSeconds)
		if self._done then return self end
		self:SetProgress(1)
		self:SetStage(message or "Ready")
		self._done = true
		if self._cancelButton then
			Util.Tween(self._cancelButton, { BackgroundTransparency = 1, TextTransparency = 1 }, Util.Motion.Fast)
		end
		task.delay(holdSeconds or 0.45, function()
			self:Destroy()
		end)
		return self
	end

	function Boot:Destroy()
		if self._destroyed then return end
		self._destroyed = true
		self._done = true

		if self._backdrop then self._backdrop:Hide(Util.Motion.Slow, true) end
		if self._canvas then
			Util.Tween(self._canvas, { GroupTransparency = 1 }, Util.Motion.Normal)
			Util.Tween(self._scaler, { Scale = 1.06 }, Util.Motion.Normal)
		end
		task.delay(Util.Motion.Normal + 0.1, function()
			self._maid:Destroy()
		end)
	end

	Void.Boot = Boot
	return Boot
end
