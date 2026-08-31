--[[
	VoidCriptUI · Window/InterfaceTab.lua
	The built-in "Interface" tab: theme editor, config manager, performance
	panel, keybind settings and the console log viewer
	(roadmap #21 config manager, #28 theme editor, #30 UI scale).

	It is created lazily the first time the user clicks the ⚙ button, so a
	script that never opens it pays nothing.
]]

return function(Void)
	local Util, Theme, Scale = Void.Util, Void.Theme, Void.Scale

	function Void.BuildInterfaceTab(window)
		local tab = window:CreateTab("Interface", "settings", { "Appearance", "Configs", "Keybinds", "Performance", "Console" })

		-- ══════════════════ APPEARANCE ══════════════════
		local themeSection = tab:CreateSection({ Name = "Theme", Subtab = "Appearance", Side = "left" })

		local presetDropdown
		presetDropdown = themeSection:CreateDropdown({
			Name = "Preset",
			Options = Theme:ListPresets(),
			CurrentOption = Theme.Name,
			Tooltip = "Swap the whole colour palette instantly. Every live element repaints — nothing is rebuilt.",
			SaveToConfig = false,
			Callback = function(preset)
				Theme:SetPreset(preset)
				Void.Notify:Push({ Title = "Theme applied", Content = ("Preset **%s**"):format(preset), Type = "success", Duration = 3 })
			end,
		})

		local TOKEN_ROWS = {
			{ "Accent", "Accent colour" },
			{ "AccentDark", "Accent (pressed)" },
			{ "Background", "Window background" },
			{ "Sidebar", "Rail background" },
			{ "Header", "Header background" },
			{ "Section", "Section background" },
			{ "Element", "Element background" },
			{ "Outline", "Outlines" },
			{ "Text", "Primary text" },
			{ "TextDim", "Secondary text" },
		}

		local editorSection = tab:CreateSection({ Name = "Theme editor", Subtab = "Appearance", Side = "right" })
		for _, row in ipairs(TOKEN_ROWS) do
			local token, labelText = row[1], row[2]
			editorSection:CreateColorPicker({
				Name = labelText,
				Color = Theme.Tokens[token],
				SaveToConfig = false,
				Callback = function(payload)
					local color = typeof(payload) == "Color3" and payload or (type(payload) == "table" and payload.Color)
					if color then
						Theme:Set({ [token] = color })
					end
				end,
			})
		end

		editorSection:CreateButton({
			Name = "Copy theme as Lua",
			Icon = "copy",
			Tooltip = "Puts a ready-to-paste `SetTheme` call on your clipboard",
			Callback = function()
				local lines = { "VoidLib:SetTheme({" }
				for _, row in ipairs(TOKEN_ROWS) do
					lines[#lines + 1] = ("\t%s = Color3.fromRGB(%d, %d, %d),"):format(
						row[1],
						math.floor(Theme.Tokens[row[1]].R * 255 + 0.5),
						math.floor(Theme.Tokens[row[1]].G * 255 + 0.5),
						math.floor(Theme.Tokens[row[1]].B * 255 + 0.5))
				end
				lines[#lines + 1] = "})"
				local code = table.concat(lines, "\n")
				local ok = type(setclipboard) == "function" and pcall(setclipboard, code)
				Void.Notify:Push({
					Title = ok and "Copied to clipboard" or "Theme code",
					Content = ok and "Paste it into your script" or "```" .. code .. "```",
					Type = "info", Duration = 6,
				})
			end,
		})

		-- ── layout / scale ───────────────────────────────────────────────
		local layoutSection = tab:CreateSection({ Name = "Layout", Subtab = "Appearance", Side = "left" })

		layoutSection:CreateSlider({
			Name = "UI scale",
			Range = { 0.7, 1.6 },
			Increment = 0.05,
			CurrentValue = Scale.Multiplier,
			Suffix = "×",
			Tooltip = "Multiplies every size in the UI. Handy on 1440p/4K or on a small phone.",
			SaveToConfig = false,
			CallbackOnRelease = true,
			Callback = function(value)
				Scale:SetMultiplier(value)
			end,
		})

		layoutSection:CreateToggle({
			Name = "Compact mode",
			CurrentValue = Scale.Compact,
			Tooltip = "Tighter paddings and single-column sections — designed for narrow monitors and tablets.",
			SaveToConfig = false,
			Callback = function(state)
				Scale:SetCompact(state)
				Void.Notify:Push({
					Title = state and "Compact mode on" or "Compact mode off",
					Content = "Re-open a tab to see the new column layout",
					Type = "info", Duration = 4,
				})
			end,
		})

		layoutSection:CreateToggle({
			Name = "Animations",
			CurrentValue = Util.AnimationsEnabled,
			Tooltip = "Turning this off applies every property change instantly. Recommended on very weak machines.",
			SaveToConfig = false,
			Callback = function(state)
				Util.AnimationsEnabled = state
			end,
		})

		layoutSection:CreateToggle({
			Name = "Tooltips",
			CurrentValue = Void.Tooltip.Enabled,
			Tooltip = "Show these little hover cards",
			SaveToConfig = false,
			Callback = function(state) Void.Tooltip:SetEnabled(state) end,
		})

		layoutSection:CreateSlider({
			Name = "Tooltip delay",
			Range = { 0, 1.5 },
			Increment = 0.1,
			CurrentValue = Void.Tooltip.HoverDelay,
			Suffix = "s",
			SaveToConfig = false,
			Callback = function(value) Void.Tooltip:SetDelay(value) end,
		})

		layoutSection:CreateDropdown({
			Name = "Slider style",
			Options = { "Slider", "Knob" },
			CurrentOption = Void.SliderStyle or "Slider",
			Tooltip = "Choose between a linear slider and a circular dial for numeric values created after this change.",
			SaveToConfig = false,
			Callback = function(style)
				Void.Library:SetSliderStyle(style)
			end,
		})

		local extrasSection = tab:CreateSection({ Name = "Extras", Subtab = "Appearance", Side = "right" })

		extrasSection:CreateToggle({
			Name = "Custom cursor",
			CurrentValue = Void.Cursor.Enabled,
			Tooltip = "Draws our own accent-coloured cursor while the pointer is over the menu",
			SaveToConfig = false,
			Callback = function(state) Void.Cursor:SetEnabled(state) end,
		})

		extrasSection:CreateToggle({
			Name = "Lock game input in menu",
			CurrentValue = Void.Cursor.LockInput,
			Tooltip = "Stops clicks in the menu from reaching the game (no accidental swinging/shooting)",
			SaveToConfig = false,
			Callback = function(state) Void.Cursor:SetInputLock(state) end,
		})

		extrasSection:CreateToggle({
			Name = "Watermark",
			CurrentValue = Void.Watermark:Get() ~= nil,
			SaveToConfig = false,
			Callback = function(state)
				local instance = Void.Watermark:Get()
				if state then
					if instance then instance:Show() else Void.Library:Watermark({}) end
				elseif instance then
					instance:Hide()
				end
			end,
		})

		extrasSection:CreateToggle({
			Name = "Keybind list",
			CurrentValue = Void.Keylist:Get() ~= nil,
			SaveToConfig = false,
			Callback = function(state)
				local instance = Void.Keylist:Get()
				if state then
					if instance then instance:Show() else Void.Library:Keylist({}) end
				elseif instance then
					instance:Hide()
				end
			end,
		})

		extrasSection:CreateDropdown({
			Name = "Notification corner",
			Options = { "TopRight", "TopLeft", "BottomRight", "BottomLeft", "TopCenter" },
			CurrentOption = Void.Notify.Position,
			SaveToConfig = false,
			Callback = function(position) Void.Notify:SetPosition(position) end,
		})

		-- ══════════════════ CONFIGS (roadmap #21) ══════════════════
		local configSection = tab:CreateSection({ Name = "Config manager", Subtab = "Configs", Side = "left" })

		local configList
		local selectedConfig = nil

		local function refreshConfigs()
			local names = Void.Config:List()
			if configList then configList:SetItems(names) end
			return names
		end

		configList = configSection:CreateListBox({
			Name = "Saved configs",
			Items = Void.Config:List(),
			Height = 120,
			EmptyText = "no configs saved yet",
			SaveToConfig = false,
			Callback = function(name) selectedConfig = name end,
		})

		configSection:CreateInput({
			Name = "New config name",
			PlaceholderText = "my-setup",
			MaxLength = 40,
			Pattern = "^[%w%-_ ]+$",
			PatternMessage = "Letters, numbers, spaces, - and _ only",
			SaveToConfig = false,
			ClearAfterCommit = true,
			Callback = function(name)
				if name == "" then return end
				local ok = Void.Config:Save(name)
				refreshConfigs()
				Void.Notify:Push({
					Title = ok and "Config saved" or "Save failed",
					Content = ok and ("`%s.json` written"):format(name) or "Your executor may not support file writes",
					Type = ok and "success" or "error",
					Duration = 4,
				})
			end,
		})

		local configActions = tab:CreateSection({ Name = "Actions", Subtab = "Configs", Side = "right" })

		configActions:CreateButton({
			Name = "Load selected",
			Icon = "download",
			Callback = function()
				if not selectedConfig then
					Void.Notify:Push({ Title = "Nothing selected", Content = "Pick a config from the list first", Type = "info", Duration = 3 })
					return
				end
				local ok = Void.Config:Load(selectedConfig)
				Void.Notify:Push({
					Title = ok and "Config loaded" or "Load failed",
					Content = ("`%s`"):format(tostring(selectedConfig)),
					Type = ok and "success" or "error",
					Duration = 4,
				})
			end,
		})

		configActions:CreateButton({
			Name = "Overwrite selected",
			Icon = "save",
			Risky = true,
			ConfirmText = "This replaces the saved config with your current settings.",
			Callback = function()
				if not selectedConfig then return end
				Void.Config:Save(selectedConfig)
				Void.Notify:Push({ Title = "Config overwritten", Content = ("`%s`"):format(selectedConfig), Type = "success", Duration = 3 })
			end,
		})

		configActions:CreateButton({
			Name = "Rename selected",
			Icon = "edit",
			Callback = function()
				if not selectedConfig then return end
				Void.Dialog:Prompt({
					Title = "Rename config",
					Content = ("Current name: `%s`"):format(selectedConfig),
					Default = selectedConfig,
					Accept = "Rename",
					OnAccept = function(newName)
						if newName == "" or newName == selectedConfig then return end
						Void.Config:Rename(selectedConfig, newName)
						selectedConfig = newName
						refreshConfigs()
					end,
				})
			end,
		})

		configActions:CreateButton({
			Name = "Delete selected",
			Icon = "trash",
			Risky = true,
			ConfirmTitle = "Delete this config?",
			ConfirmText = "The file is removed from disk. This cannot be undone.",
			Callback = function()
				if not selectedConfig then return end
				local ok = Void.Config:Delete(selectedConfig)
				selectedConfig = nil
				refreshConfigs()
				Void.Notify:Push({
					Title = ok and "Config deleted" or "Delete failed",
					Type = ok and "success" or "error",
					Duration = 3,
				})
			end,
		})

		configActions:CreateDivider("share")

		configActions:CreateButton({
			Name = "Export to clipboard",
			Icon = "upload",
			Tooltip = "Copies a base64 string you can send to a friend",
			Callback = function()
				local payload = Void.Config:Export(selectedConfig)
				if not payload then
					Void.Notify:Push({ Title = "Export failed", Type = "error", Duration = 3 })
					return
				end
				local ok = type(setclipboard) == "function" and pcall(setclipboard, payload)
				Void.Notify:Push({
					Title = ok and "Copied" or "Export string",
					Content = ok and "The config string is on your clipboard" or "Your executor has no clipboard API",
					Type = ok and "success" or "warning",
					Duration = 4,
				})
			end,
		})

		configActions:CreateInput({
			Name = "Import from string",
			PlaceholderText = "VOIDCFG1:…",
			SaveToConfig = false,
			ClearAfterCommit = true,
			Callback = function(payload)
				if payload == "" then return end
				local ok, err = Void.Config:Import(payload)
				refreshConfigs()
				Void.Notify:Push({
					Title = ok and "Config imported" or "Import failed",
					Content = ok and "Settings applied" or tostring(err),
					Type = ok and "success" or "error",
					Duration = 5,
				})
			end,
		})

		local autoSection = tab:CreateSection({ Name = "Auto-save", Subtab = "Configs", Side = "left" })

		autoSection:CreateToggle({
			Name = "Auto-save settings",
			CurrentValue = Void.Config.AutoSave,
			Tooltip = "Writes your settings to `workspace/" .. Void.Config.Folder .. "/" .. Void.Config.File .. ".json` a moment after every change.",
			SaveToConfig = false,
			Callback = function(state)
				Void.Config.AutoSave = state
				Void.Config.Enabled = state or Void.Config.Enabled
			end,
		})

		autoSection:CreateToggle({
			Name = "Per-game profile",
			CurrentValue = Void.Config.PerGame == true,
			Tooltip = "Also keeps a separate config per PlaceId, so each game remembers its own settings.",
			SaveToConfig = false,
			Callback = function(state) Void.Config.PerGame = state end,
		})

		autoSection:CreateSlider({
			Name = "Auto-save delay",
			Range = { 0.5, 10 },
			Increment = 0.5,
			CurrentValue = Void.Config.AutoSaveDelay,
			Suffix = "s",
			SaveToConfig = false,
			Callback = function(value) Void.Config.AutoSaveDelay = value end,
		})

		autoSection:CreateButton({
			Name = "Save now",
			Icon = "save",
			Callback = function()
				local ok = Void.Config:Save()
				Void.Notify:Push({
					Title = ok and "Saved" or "Save failed",
					Type = ok and "success" or "error",
					Duration = 3,
				})
			end,
		})

		autoSection:CreateParagraph({
			Title = "Where are my configs?",
			Content = ("Files live in `workspace/%s/`. Per-game profiles go to `workspace/%s/games/<PlaceId>.json`."):format(Void.Config.Folder, Void.Config.Folder),
		})

		-- ══════════════════ KEYBINDS ══════════════════
		local bindSection = tab:CreateSection({ Name = "Menu keybind", Subtab = "Keybinds", Side = "left" })

		bindSection:CreateKeybind({
			Name = "Toggle menu",
			CurrentKeybind = window:GetToggleKey(),
			Mode = "Always",
			ModeSelectable = false,
			ShowInKeylist = false,
			Tooltip = "Press the chip, then hit any key or mouse button. Hold Ctrl/Shift/Alt for a combo.",
			SaveToConfig = false,
			Callback = function(descriptor)
				if descriptor then
					window:SetToggleKey(descriptor)
					Void.Notify:Push({
						Title = "Menu keybind updated",
						Content = ("Now bound to **%s**"):format(Void.Keybinds.Label(descriptor)),
						Type = "success", Duration = 3,
					})
				end
			end,
		})

		bindSection:CreateDropdown({
			Name = "Keylist columns",
			Options = { "Name", "Mode", "Key", "State", "Hits", "Category", "LastUsed" },
			CurrentOption = { "Name", "Mode", "Key", "State" },
			MultiSelect = true,
			SaveToConfig = false,
			Callback = function(columns)
				local instance = Void.Keylist:Get()
				if instance and #columns > 0 then
					instance:Configure({ Columns = columns })
				end
			end,
		})

		bindSection:CreateDropdown({
			Name = "Keylist position",
			Options = { "LeftCenter", "RightCenter", "TopLeft", "TopRight", "BottomLeft", "BottomRight" },
			CurrentOption = "LeftCenter",
			SaveToConfig = false,
			Callback = function(position)
				local instance = Void.Keylist:Get()
				if instance then instance:Configure({ Position = position }) end
			end,
		})

		local bindTable = tab:CreateSection({ Name = "All binds", Subtab = "Keybinds", Side = "right", Height = 200 })
		local bindsTableElement = bindTable:CreateTable({
			Name = "Registered keybinds",
			Columns = { "Name", "Mode", "Key", "State" },
			Rows = {},
			Height = 160,
			SaveToConfig = false,
		})

		local function refreshBindTable()
			local rows = {}
			for _, bind in ipairs(Void.Keybinds:List()) do
				rows[#rows + 1] = {
					tostring(bind.Name),
					tostring(bind.Mode):lower(),
					Void.Keybinds.Label(bind.Descriptor),
					bind.Mode == "Always" and "—" or (bind.State and "on" or "off"),
				}
			end
			bindsTableElement:SetRows(rows)
		end
		refreshBindTable()
		tab._maid:Give(Void.Keybinds:OnUpdated(Util.Debounce(refreshBindTable, 0.2)))

		-- ══════════════════ PERFORMANCE ══════════════════
		local perfSection = tab:CreateSection({ Name = "Live metrics", Subtab = "Performance", Side = "left" })

		local fpsLabel = perfSection:CreateLabel({ Name = "FPS: —", Icon = "gauge", Color = "Text" })
		local lowLabel = perfSection:CreateLabel({ Name = "1% low: —", Icon = "chart" })
		local frameLabel = perfSection:CreateLabel({ Name = "Frame time: —", Icon = "clock" })
		local pingLabel = perfSection:CreateLabel({ Name = "Ping: —", Icon = "wifi" })
		local memLabel = perfSection:CreateLabel({ Name = "Memory: —", Icon = "cpu" })
		local instLabel = perfSection:CreateLabel({ Name = "Instances: —", Icon = "box" })

		local statsSection = tab:CreateSection({ Name = "Library stats", Subtab = "Performance", Side = "right" })
		local flagLabel = statsSection:CreateLabel({ Name = "Flags: —", Icon = "list" })
		local paintLabel = statsSection:CreateLabel({ Name = "Themed instances: —", Icon = "palette" })
		local tabLabel = statsSection:CreateLabel({ Name = "Tabs built: —", Icon = "layers" })
		local connLabel = statsSection:CreateLabel({ Name = "Tracked connections: —", Icon = "link" })

		local perfBar = perfSection:CreateProgressBar({
			Name = "Frame budget (16.6 ms)",
			Value = 0,
			ShowPercent = false,
		})

		-- one 2 Hz updater for the whole panel
		tab._maid:Give(task.spawn(function()
			while true do
				task.wait(0.5)
				-- only refresh while this tab is the one on screen
				local shouldUpdate = window._activeTab == tab and window._visible
				if shouldUpdate then
					local p = Void.Profiler
					fpsLabel:SetText(("FPS: **%d**"):format(p.FPS))
					lowLabel:SetText(("1%% low: %d"):format(p.Low1))
					frameLabel:SetText(("Frame time: %.2f ms"):format(p.FrameTimeMs))
					pingLabel:SetText(("Ping: %d ms"):format(p.Ping))
					memLabel:SetText(("Memory: %d MB"):format(p.Memory))
					instLabel:SetText(("Instances: %d"):format(p.InstanceCount))
					perfBar:SetProgress(math.clamp(p.FrameTimeMs / 33.3, 0, 1))

					local builtTabs = 0
					for _, candidate in ipairs(window._tabs) do
						if candidate._built then builtTabs = builtTabs + 1 end
					end
					flagLabel:SetText(("Flags: %d"):format(Void.Flags:Count()))
					paintLabel:SetText(("Themed instances: %d"):format(Theme:RegistryCount()))
					tabLabel:SetText(("Tabs built: %d / %d"):format(builtTabs, #window._tabs))
					connLabel:SetText(("Tracked connections: %d"):format(Void.RootMaid:Count()))
				end
			end
		end))

		local profileSection = tab:CreateSection({ Name = "Profiler", Subtab = "Performance", Side = "left" })

		profileSection:CreateToggle({
			Name = "Enable profiling",
			CurrentValue = Void.Profiler.Enabled,
			Tooltip = "Records how long each part of the UI takes to build. Adds a tiny overhead.",
			SaveToConfig = false,
			Callback = function(state) Void.Profiler.Enabled = state end,
		})

		local profileParagraph = profileSection:CreateParagraph({
			Title = "Span report",
			Content = "Open a few tabs, then press **Refresh report**.",
		})

		profileSection:CreateButton({
			Name = "Refresh report",
			Icon = "refresh",
			Callback = function()
				local rows = Void.Profiler:Report()
				if #rows == 0 then
					profileParagraph:SetContent("No spans recorded yet.")
					return
				end
				local lines = {}
				for index, row in ipairs(rows) do
					if index > 8 then break end
					lines[#lines + 1] = ("`%-22s` %d× · %.2f ms total · %.2f ms avg"):format(row.Name, row.Calls, row.TotalMs, row.AvgMs)
				end
				profileParagraph:SetContent(table.concat(lines, "\n"))
			end,
		})

		profileSection:CreateButton({
			Name = "Print report to console",
			Icon = "terminal",
			Callback = function()
				Void.Log.Level = math.max(Void.Log.Level, 3)
				Void.Log:Info("profiler report:\n%s", Void.Profiler:ReportString())
				Void.Notify:Push({ Title = "Report printed", Content = "Open the F9 console to read it", Type = "info", Duration = 4 })
			end,
		})

		-- ══════════════════ CONSOLE ══════════════════
		local logSection = tab:CreateSection({ Name = "Logging", Subtab = "Console", Side = "left" })

		logSection:CreateDropdown({
			Name = "Log level",
			Options = { "Off", "Error", "Warning", "Info", "Debug" },
			CurrentOption = Void.Log:GetLevel(),
			Tooltip = "**Warning** is the default: only warnings and errors reach the F9 console. Raise it to **Debug** while developing.",
			SaveToConfig = false,
			Callback = function(level)
				Void.Log:SetLevel(level)
				Void.Log:Warn("log level is now %s", level)
			end,
		})

		logSection:CreateToggle({
			Name = "Errors also notify",
			CurrentValue = Void.Log.MirrorToNotify,
			Tooltip = "Pops a red notification whenever something logs an error",
			SaveToConfig = false,
			Callback = function(state) Void.Log.MirrorToNotify = state end,
		})

		local logTable = tab:CreateSection({ Name = "Recent log", Subtab = "Console", Side = "right", Height = 240 })
		local logElement = logTable:CreateTable({
			Name = "Entries",
			Columns = { "Time", "Level", "Message" },
			Rows = {},
			Height = 200,
			SaveToConfig = false,
		})

		local function refreshLog()
			local rows = {}
			local history = Void.Log.History
			for index = #history, math.max(1, #history - 60), -1 do
				local entry = history[index]
				rows[#rows + 1] = { entry.Time, entry.Level:lower(), entry.Message }
			end
			logElement:SetRows(rows)
		end

		logSection:CreateButton({
			Name = "Refresh log",
			Icon = "refresh",
			Callback = refreshLog,
		})

		logSection:CreateButton({
			Name = "Copy log",
			Icon = "copy",
			Callback = function()
				local dump = Void.Log:Dump(4)
				local ok = type(setclipboard) == "function" and pcall(setclipboard, dump)
				Void.Notify:Push({
					Title = ok and "Log copied" or "Clipboard unavailable",
					Type = ok and "success" or "warning",
					Duration = 3,
				})
			end,
		})

		logSection:CreateButton({
			Name = "Clear log",
			Icon = "trash",
			Risky = true,
			ConfirmText = "Clears the in-memory log history.",
			Callback = function()
				Void.Log:Clear()
				refreshLog()
			end,
		})

		refreshLog()

		local aboutSection = tab:CreateSection({ Name = "About", Subtab = "Console", Side = "left" })
		aboutSection:CreateParagraph({
			Title = ("VoidCriptUI v%s"):format(tostring(Void.Version)),
			Content = table.concat({
				("device: **%s** · scale **%.2f×**"):format(Scale.Device, Scale.Factor),
				("theme: **%s**"):format(Theme.Name),
				("plugins: %d"):format(#Void.Plugins:List()),
				"",
				"> Logging goes to the Roblox developer console (**F9**).",
			}, "\n"),
		})

		aboutSection:CreateButton({
			Name = "Unload library",
			Icon = "power",
			Risky = true,
			ConfirmTitle = "Unload VoidCriptUI?",
			ConfirmText = "Destroys every window, watermark and connection. Re-execute the script to bring it back.",
			Callback = function() Void.Library:Unload() end,
		})

		tab:SelectSubtab("Appearance")
		return tab
	end
end
