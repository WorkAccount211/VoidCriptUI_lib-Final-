--[[
	VoidCriptUI · Components/KeySystem.lua
	Optional key gate shown before the window is created.

	Matches the boot screen visually (glass backdrop, centred panel that
	expands from the middle). Supports multiple valid keys, saving the key to
	disk, a "get key" link button, and an attempt limit.

		VoidLib:CreateWindow({
			KeySystem = true,
			KeySettings = {
				Title = "voidcript",
				Subtitle = "key system",
				Note = "Get your key from the Discord",
				Key = { "abc123", "def456" },
				SaveKey = true,
				FileName = "VoidCriptKey",
				GetKeyLink = "https://example.com/key",
				MaxAttempts = 5,
			},
		})
]]

return function(Void)
	local Util, Theme, Scale = Void.Util, Void.Theme, Void.Scale

	local KeySystem = {}

	function KeySystem:Run(settings)
		settings = settings or {}
		local keys = type(settings.Key) == "table" and settings.Key or { tostring(settings.Key or "") }
		local fileName = (settings.FileName or "VoidCriptKey") .. ".key"
		local maxAttempts = settings.MaxAttempts or 0

		-- saved key fast path
		if settings.SaveKey and type(readfile) == "function" and type(isfile) == "function" then
			local ok, saved = pcall(function()
				return isfile(fileName) and readfile(fileName) or nil
			end)
			if ok and saved then
				for _, key in ipairs(keys) do
					if saved == key then
						Void.Log:Info("key system: saved key accepted")
						return true
					end
				end
				Void.Log:Warn("key system: saved key is no longer valid")
			end
		end

		local maid = Void.Maid.new("KeySystem")
		local gui = Util.Screen("VoidCriptKeySystem")
		gui.DisplayOrder = 99700
		maid:Give(gui)

		local backdrop = Void.Backdrop.new(gui, { Strength = 0.55 })
		backdrop:Show(Util.Motion.Slow)

		local width = math.min(Scale.u(340), Util.Viewport().X - Scale.u(40))
		local canvas = Util.New("CanvasGroup", {
			BackgroundTransparency = 1,
			GroupTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(width, Scale.u(210)),
			AutomaticSize = Enum.AutomaticSize.Y,
			ZIndex = 5,
			Parent = gui,
		})
		local scaler = Util.New("UIScale", { Scale = 0.88, Parent = canvas })

		local card = Util.New("Frame", {
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

		local accent = Util.New("Frame", {
			BackgroundColor3 = Theme.C.Accent,
			Size = UDim2.new(1, 0, 0, 2),
			ZIndex = 4,
			Parent = card,
		})
		Theme:Paint(accent, { BackgroundColor3 = "Accent" })

		local body = Util.New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = card,
		}, {
			Util.New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, Scale.u(8)) }),
			Util.New("UIPadding", {
				PaddingLeft = UDim.new(0, Scale.u(18)), PaddingRight = UDim.new(0, Scale.u(18)),
				PaddingTop = UDim.new(0, Scale.u(16)), PaddingBottom = UDim.new(0, Scale.u(16)),
			}),
		})

		local title = Util.New("TextLabel", {
			Font = Theme:Font("FontBold"),
			Text = tostring(settings.Title or "voidcript"),
			TextColor3 = Theme.C.Text,
			TextSize = Scale.f(17),
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, Scale.u(20)),
			LayoutOrder = 1,
			Parent = body,
		})
		Theme:Paint(title, { TextColor3 = "Text" })

		if settings.Subtitle then
			local subtitle = Util.New("TextLabel", {
				Font = Theme:Font("Font"),
				Text = tostring(settings.Subtitle),
				TextColor3 = Theme.C.Accent,
				TextSize = Scale.f(12),
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, 0, 0, Scale.u(14)),
				LayoutOrder = 2,
				Parent = body,
			})
			Theme:Paint(subtitle, { TextColor3 = "Accent" })
		end

		if settings.Note then
			local note = Util.New("TextLabel", {
				Font = Theme:Font("Font"),
				Text = Void.RichText.Parse(settings.Note),
				RichText = true,
				TextColor3 = Theme.C.TextDim,
				TextSize = Scale.f(12),
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 3,
				Parent = body,
			})
			Theme:Paint(note, { TextColor3 = "TextDim" })
		end

		local box = Util.New("TextBox", {
			BackgroundColor3 = Theme.C.Element,
			Font = Theme:Font("Font"),
			PlaceholderText = settings.Placeholder or "Enter your key…",
			PlaceholderColor3 = Theme.C.TextDark,
			Text = "",
			TextColor3 = Theme.C.Text,
			TextSize = Scale.f(13),
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, Scale.touch(32)),
			LayoutOrder = 4,
			Parent = body,
		}, {
			Util.New("UIPadding", { PaddingLeft = UDim.new(0, Scale.u(10)), PaddingRight = UDim.new(0, Scale.u(10)) }),
		})
		Theme:Paint(box, { BackgroundColor3 = "Element", TextColor3 = "Text", PlaceholderColor3 = "TextDark" })
		Util.Corner(box, Theme.Style.RadiusSmall)
		local boxStroke = Util.Stroke(box, Theme.C.OutlineSoft)
		maid:Give(box.Focused:Connect(function()
			Util.Tween(boxStroke, { Color = Theme.C.Accent }, Util.Motion.Fast)
		end))
		maid:Give(box.FocusLost:Connect(function()
			Util.Tween(boxStroke, { Color = Theme.C.OutlineSoft }, Util.Motion.Fast)
		end))

		local status = Util.New("TextLabel", {
			Font = Theme:Font("Font"),
			Text = "",
			TextColor3 = Theme.C.Danger,
			TextSize = Scale.f(11),
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, Scale.u(13)),
			LayoutOrder = 5,
			Parent = body,
		})

		local row = Util.New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, Scale.touch(30)),
			LayoutOrder = 6,
			Parent = body,
		}, {
			Util.New("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Scale.u(8)),
			}),
		})

		local function makeButton(text, primary, order, width_)
			local btn = Util.New("TextButton", {
				BackgroundColor3 = primary and Theme.C.Accent or Theme.C.Element,
				Font = Theme:Font("FontMedium"),
				Text = text,
				TextColor3 = primary and Theme.C.TextOnAccent or Theme.C.Text,
				TextSize = Scale.f(12),
				Size = UDim2.new(width_, 0, 1, 0),
				LayoutOrder = order,
				Parent = row,
			})
			Theme:Paint(btn, {
				BackgroundColor3 = primary and "Accent" or "Element",
				TextColor3 = primary and "TextOnAccent" or "Text",
			})
			Util.Corner(btn, Theme.Style.RadiusSmall)
			if not primary then
				local s = Util.Stroke(btn, Theme.C.Outline)
				Theme:Paint(s, { Color = "Outline" })
			end
			maid:Give(btn.MouseEnter:Connect(function()
				Util.Tween(btn, { BackgroundColor3 = primary and Theme.C.AccentDark or Theme.C.ElementHover }, Util.Motion.Fast)
			end))
			maid:Give(btn.MouseLeave:Connect(function()
				Util.Tween(btn, { BackgroundColor3 = primary and Theme.C.Accent or Theme.C.Element }, Util.Motion.Fast)
			end))
			return btn
		end

		local hasLink = settings.GetKeyLink ~= nil
		local unlock = makeButton(settings.SubmitText or "Unlock", true, 1, hasLink and 0.58 or 1)
		local getKey
		if hasLink then
			getKey = makeButton(settings.GetKeyText or "Get key", false, 2, 0.4)
			maid:Give(getKey.MouseButton1Click:Connect(function()
				local copied = false
				if type(setclipboard) == "function" then
					copied = pcall(setclipboard, settings.GetKeyLink)
				end
				Void.Notify:Push({
					Title = copied and "Link copied" or "Get your key",
					Content = tostring(settings.GetKeyLink),
					Type = "info",
					Duration = 8,
				})
			end))
		end

		Util.Tween(canvas, { GroupTransparency = 0 }, Util.Motion.Boot)
		Util.Tween(scaler, { Scale = 1 }, Util.Motion.Boot, Enum.EasingStyle.Back)

		local done = Instance.new("BindableEvent")
		local passed, attempts = false, 0

		local function attempt()
			local entered = box.Text
			for _, key in ipairs(keys) do
				if entered == key then
					passed = true
					if settings.SaveKey and type(writefile) == "function" then
						pcall(writefile, fileName, entered)
					end
					status.TextColor3 = Theme.C.Success
					status.Text = "Key accepted"
					Void.Log:Info("key system: key accepted")
					task.delay(0.35, function() done:Fire() end)
					return
				end
			end

			attempts = attempts + 1
			box.Text = ""
			status.TextColor3 = Theme.C.Danger
			if maxAttempts > 0 then
				status.Text = ("Wrong key (%d/%d attempts)"):format(attempts, maxAttempts)
			else
				status.Text = "Wrong key"
			end
			Void.Log:Warn("key system: wrong key entered (attempt %d)", attempts)

			-- shake
			local basePos = canvas.Position
			for i, offset in ipairs({ -8, 7, -5, 3, 0 }) do
				task.delay(i * 0.045, function()
					if canvas.Parent then
						canvas.Position = basePos + UDim2.fromOffset(offset, 0)
					end
				end)
			end

			if maxAttempts > 0 and attempts >= maxAttempts then
				status.Text = "Too many attempts"
				task.delay(0.8, function() done:Fire() end)
			end
		end

		maid:Give(unlock.MouseButton1Click:Connect(attempt))
		maid:Give(box.FocusLost:Connect(function(enter)
			if enter then attempt() end
		end))

		done.Event:Wait()
		done:Destroy()

		backdrop:Hide(Util.Motion.Normal, true)
		Util.Tween(canvas, { GroupTransparency = 1 }, Util.Motion.Normal)
		Util.Tween(scaler, { Scale = 0.9 }, Util.Motion.Normal)
		task.wait(Util.Motion.Normal + 0.05)
		maid:Destroy()

		return passed
	end

	Void.KeySystem = KeySystem
	return KeySystem
end
