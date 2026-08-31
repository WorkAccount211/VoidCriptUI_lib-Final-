--[[
	════════════════════════════════════════════════════════════════════════
	VoidCriptUI · examples/BaseExample.lua
	Every element, once, with every option commented.
	════════════════════════════════════════════════════════════════════════

	This is the reference sheet. It is not a useful cheat — it is a catalogue.
	Run it and click through the tabs to see what each element looks like, then
	copy the block you need into your own script.

	Element index
	-------------
	Inputs      Toggle · Switch toggle · Slider · Range slider · Knob
	            Dropdown · Searchable dropdown · Multi dropdown
	            Input · Numeric input · Multiline input
	            Keybind · Colour picker · Rainbow colour picker
	Actions     Button · Risky button · Double-click button · Image button
	Display     Label · Paragraph · Divider · Progress bar · Image
	Data        List box · Table
	Layout      Collapsible section · Sections with fixed height · Subtabs
	Combined    Toggle + keybind · Toggle + colour picker
]]

local VoidLib = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/WorkAccount211/VoidCriptUI_lib-Final-/main/VoidCriptUI.lua"
))()

VoidLib:SetLogLevel("Info") -- show info lines in the F9 console while exploring

local Window = VoidLib:CreateWindow({
	Name = "voidcript",
	Subtitle = "element catalogue",
	Size = Vector2.new(820, 540),
	ToggleKey = "RightShift",
	LazyLoading = true,             -- tabs build on first open
	Resizable = true,
	Theme = "Midnight",
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "VoidCriptDemo",
		FileName = "catalogue",
		AutoSave = true,
	},
})

-- ══════════════════════════════════════════════════════════════════════════
-- TAB 1 · INPUTS
-- ══════════════════════════════════════════════════════════════════════════
local Inputs = Window:CreateTab("Inputs", "sliders", { "Toggles", "Numbers", "Choices", "Text" })

-- ── TOGGLES ───────────────────────────────────────────────────────────────
local toggles = Inputs:CreateSection({ Name = "Toggle styles", Subtab = "Toggles", Side = "left" })

toggles:CreateToggle({
	Name = "Checkbox toggle",
	Flag = "demo_checkbox",
	CurrentValue = true,
	Style = "Checkbox",                 -- default
	Tooltip = "The classic CompKiller square checkbox",
	Callback = function(value) print("checkbox:", value) end,
})

toggles:CreateToggle({
	Name = "Switch toggle",
	Flag = "demo_switch",
	Style = "Switch",                   -- pill switch on the right
	Tooltip = "Same control, different look",
	Callback = function(value) print("switch:", value) end,
})

toggles:CreateToggle({
	Name = "Toggle with icon",
	Flag = "demo_icon_toggle",
	Icon = "bolt",                      -- any name from VoidLib.Icons:List()
	Callback = function(value) print("icon toggle:", value) end,
})

toggles:CreateToggle({
	Name = "Risky toggle",
	Flag = "demo_risky",
	Risky = true,                       -- ⚠ marker + confirmation when enabling
	ConfirmText = "This one is dangerous. Continue?",
	Callback = function(value) print("risky:", value) end,
})

toggles:CreateToggle({
	Name = "Disabled toggle",
	Flag = "demo_disabled",
	Enabled = false,                    -- greyed out; enable with :SetEnabled(true)
})

-- ── COMBINED ROWS ─────────────────────────────────────────────────────────
local combined = Inputs:CreateSection({ Name = "Combined rows", Subtab = "Toggles", Side = "right" })

combined:CreateToggle({
	Name = "Toggle + keybind",
	Flag = "demo_toggle_bind",
	Keybind = "F",                      -- inline keybind that flips the toggle
	KeybindMode = "Toggle",
	Tooltip = "Press F to flip this without opening the menu",
	Callback = function(value) print("bound toggle:", value) end,
})

combined:CreateToggle({
	Name = "Toggle + colour",
	Flag = "demo_toggle_color",
	Color = Color3.fromRGB(80, 200, 120),   -- inline colour picker
	ColorFlag = "demo_toggle_color_value",
	Callback = function(value) print("esp-style toggle:", value) end,
	ColorCallback = function(payload) print("esp colour:", payload.Color) end,
})

combined:CreateToggle({
	Name = "Toggle + keybind + colour",
	Flag = "demo_toggle_all",
	Keybind = "G",
	Color = Color3.fromRGB(56, 152, 219),
})

-- ── NUMBERS ───────────────────────────────────────────────────────────────
local numbers = Inputs:CreateSection({ Name = "Sliders", Subtab = "Numbers", Side = "left" })

numbers:CreateSlider({
	Name = "Integer slider",
	Flag = "demo_slider_int",
	Range = { 0, 100 },
	Increment = 1,
	CurrentValue = 42,
	Suffix = "%",
	Editable = true,                    -- click the number to type a value
	Tooltip = "Drag the track, or click the value to type it",
	Callback = function(value) print("int:", value) end,
})

numbers:CreateSlider({
	Name = "Decimal slider",
	Flag = "demo_slider_float",
	Range = { 0, 1 },
	Increment = 0.05,
	CurrentValue = 0.35,
	Callback = function(value) print("float:", value) end,
})

numbers:CreateSlider({
	Name = "Heavy operation slider",
	Flag = "demo_slider_heavy",
	Range = { 1, 64 },
	Increment = 1,
	CurrentValue = 8,
	CallbackOnRelease = true,           -- fires once, when you let go
	Tooltip = "Use this for expensive work: the callback runs on release only",
	Callback = function(value) print("committed:", value) end,
})

numbers:CreateRangeSlider({
	Name = "Distance range",
	Flag = "demo_range",
	Range = { 0, 500 },
	Increment = 10,
	CurrentMin = 50,
	CurrentMax = 300,
	Suffix = "m",
	Tooltip = "Two grips; the value is `{ Min = n, Max = n }`",
	Callback = function(value) print("range:", value.Min, value.Max) end,
})

local dials = Inputs:CreateSection({ Name = "Knobs", Subtab = "Numbers", Side = "right" })

dials:CreateKnob({
	Name = "FOV",
	Flag = "demo_knob",
	Range = { 30, 120 },
	Increment = 1,
	CurrentValue = 90,
	Suffix = "°",
	Tooltip = "Drag up/down or scroll. Double-click resets to the default.",
	Callback = function(value) print("knob:", value) end,
})

dials:CreateKnob({
	Name = "Smoothing",
	Flag = "demo_knob_2",
	Range = { 0, 1 },
	Increment = 0.05,
	CurrentValue = 0.5,
	Sweep = 300,
})

dials:CreateProgressBar({
	Name = "Something loading",
	Value = 0.65,
})

-- ── CHOICES ───────────────────────────────────────────────────────────────
local choices = Inputs:CreateSection({ Name = "Dropdowns", Subtab = "Choices", Side = "left" })

choices:CreateDropdown({
	Name = "Simple dropdown",
	Flag = "demo_dropdown",
	Options = { "Head", "Torso", "HumanoidRootPart" },
	CurrentOption = "Head",
	Callback = function(option) print("target:", option) end,
})

choices:CreateDropdown({
	Name = "Searchable dropdown",
	Flag = "demo_dropdown_search",
	Options = (function()
		local list = {}
		for index = 1, 60 do list[index] = "Option " .. index end
		return list
	end)(),
	SearchBox = true,                   -- filter box inside the list
	MaxVisible = 8,
	Callback = function(option) print("picked:", option) end,
})

choices:CreateMultiDropdown({
	Name = "Multi select",
	Flag = "demo_multi",
	Options = { "Walls", "Players", "NPCs", "Loot", "Vehicles" },
	CurrentOption = { "Players", "Loot" },
	Max = 4,                            -- optional cap
	Chips = true,                       -- show selected values as chips below
	Callback = function(list) print("selected:", table.concat(list, ", ")) end,
})

local pickers = Inputs:CreateSection({ Name = "Colour pickers", Subtab = "Choices", Side = "right" })

pickers:CreateColorPicker({
	Name = "Solid colour",
	Flag = "demo_color",
	Color = Color3.fromRGB(199, 62, 110),
	Callback = function(payload) print("colour:", payload.Color) end,
})

pickers:CreateColorPicker({
	Name = "Colour + alpha",
	Flag = "demo_color_alpha",
	Color = Color3.fromRGB(56, 152, 219),
	Alpha = 0.6,                        -- adding Alpha shows the alpha bar
	Callback = function(payload) print("colour:", payload.Color, "alpha:", payload.Alpha) end,
})

pickers:CreateColorPicker({
	Name = "Rainbow capable",
	Flag = "demo_color_rainbow",
	Color = Color3.fromRGB(146, 226, 64),
	Rainbow = false,                    -- the user can tick "rainbow" in the panel
	RainbowSpeed = 0.4,
	Palette = { "#ff004c", "#00e5c0", "#ffd200" },   -- extra preset swatches
})

-- ── TEXT ──────────────────────────────────────────────────────────────────
local text = Inputs:CreateSection({ Name = "Text inputs", Subtab = "Text", Side = "left" })

text:CreateInput({
	Name = "Plain input",
	Flag = "demo_input",
	PlaceholderText = "type anything",
	Callback = function(value) print("input:", value) end,
})

text:CreateInput({
	Name = "Numeric input",
	Flag = "demo_input_number",
	Numeric = true,                     -- digits only, value comes back as a number
	Min = 0,
	Max = 1000,
	CurrentValue = "100",
	Callback = function(value) print("number:", value) end,
})

text:CreateInput({
	Name = "Validated URL",
	Flag = "demo_input_url",
	PlaceholderText = "https://…",
	Pattern = "^https://",
	PatternMessage = "Must start with https://",
	MaxLength = 200,
	Callback = function(value) print("url:", value) end,
})

text:CreateInput({
	Name = "Custom validator",
	Flag = "demo_input_custom",
	PlaceholderText = "at least 4 characters",
	Validate = function(value)
		if #value < 4 then return false, "Too short" end
		return true
	end,
	Callback = function(value) print("validated:", value) end,
})

text:CreateInput({
	Name = "Multiline note",
	Flag = "demo_input_multi",
	Multiline = true,
	PlaceholderText = "notes…",
})

local binds = Inputs:CreateSection({ Name = "Keybinds", Subtab = "Text", Side = "right" })

binds:CreateKeybind({
	Name = "Simple bind",
	Flag = "demo_bind",
	CurrentKeybind = "F",
	Mode = "Always",
	Callback = function() print("pressed") end,
})

binds:CreateKeybind({
	Name = "Mouse bind",
	Flag = "demo_bind_mouse",
	CurrentKeybind = "MB2",             -- MB1 / MB2 / MB3
	Mode = "Hold",
	Category = "Combat",
	Callback = function(held) print("holding:", held) end,
})

binds:CreateKeybind({
	Name = "Combo bind",
	Flag = "demo_bind_combo",
	CurrentKeybind = "Ctrl+Shift+K",    -- modifiers are supported
	Mode = "Toggle",
	Callback = function(state) print("toggled:", state) end,
})

binds:CreateParagraph({
	Title = "Recording a bind",
	Content = "Click the chip, then press any key or mouse button.\n> Hold **Ctrl/Shift/Alt** while pressing for a combo.\n> **Escape** cancels, **Backspace** clears.",
})

-- ══════════════════════════════════════════════════════════════════════════
-- TAB 2 · ACTIONS
-- ══════════════════════════════════════════════════════════════════════════
local Actions = Window:CreateTab("Actions", "zap")

local buttons = Actions:CreateSection({ Name = "Buttons", Side = "left" })

buttons:CreateButton({
	Name = "Plain button",
	Callback = function() print("clicked") end,
})

buttons:CreateButton({
	Name = "Button with icon",
	Icon = "refresh",
	Callback = function() print("refresh") end,
})

buttons:CreateButton({
	Name = "Risky button",
	Icon = "trash",
	Risky = true,                       -- modal confirmation
	ConfirmTitle = "Delete everything?",
	ConfirmText = "This cannot be undone.",
	Callback = function() print("deleted") end,
})

buttons:CreateButton({
	Name = "Double-click button",
	DoubleClick = true,                 -- inline arm/confirm, no modal
	ConfirmLabel = "Click again to confirm",
	Callback = function() print("confirmed inline") end,
})

local imageButtons = Actions:CreateSection({ Name = "Image buttons", Side = "right" })

imageButtons:CreateImageButton({
	Name = "Icon only",
	Image = "star",
	Size = 36,
	Layout = "Icon",
	Round = true,
	Tooltip = "Just an icon",
	Callback = function() print("star") end,
})

imageButtons:CreateImageButton({
	Name = "Icon + text",
	Image = "link",
	Layout = "IconText",
	Callback = function() print("link") end,
})

imageButtons:CreateImageButton({
	Name = "Custom asset",
	Image = "https://raw.githubusercontent.com/WorkAccount211/VoidCriptUI_lib-Final-/main/images/icon.png",
	Layout = "IconText",
})

local feedback = Actions:CreateSection({ Name = "Notifications & dialogs", Side = "left" })

for _, kind in ipairs({ "info", "success", "warning", "error" }) do
	feedback:CreateButton({
		Name = ("Notify · %s"):format(kind),
		Callback = function()
			VoidLib:Notify({
				Title = kind:upper(),
				Content = ("A **%s** notification with `formatting`"):format(kind),
				Type = kind,
				Duration = 5,
			})
		end,
	})
end

feedback:CreateButton({
	Name = "Notification with actions",
	Callback = function()
		VoidLib:Notify({
			Title = "Update available",
			Content = "Version **3.1.0** is out.",
			Type = "info",
			Sticky = true,
			Actions = {
				{ Name = "Update", Callback = function() print("updating") end },
				{ Name = "Later", Style = "ghost" },
			},
		})
	end,
})

feedback:CreateButton({
	Name = "Progress notification",
	Callback = function()
		local handle = VoidLib:NotifyProgress({
			Title = "Downloading",
			Content = "Fetching assets…",
			Type = "info",
		})
		task.spawn(function()
			for step = 1, 10 do
				task.wait(0.25)
				handle:SetProgress(step / 10)
				handle:SetContent(("Chunk %d of 10"):format(step))
			end
			handle:Finish("Done")
		end)
	end,
})

feedback:CreateButton({
	Name = "Confirm dialog",
	Callback = function()
		VoidLib:Dialog({
			Title = "Are you sure?",
			Content = "This is what `Risky = true` uses under the hood.",
			Accept = "Do it",
			Decline = "Cancel",
			OnAccept = function() print("accepted") end,
			OnDecline = function() print("declined") end,
		})
	end,
})

feedback:CreateButton({
	Name = "Prompt dialog",
	Callback = function()
		VoidLib:Prompt({
			Title = "Enter a name",
			Content = "Used by the config manager for renaming.",
			Default = "my-config",
			OnAccept = function(value) print("entered:", value) end,
		})
	end,
})

feedback:CreateButton({
	Name = "Choice dialog",
	Callback = function()
		VoidLib:Choice({
			Title = "Pick a mode",
			Content = "Three ways to do the same thing.",
			Choices = {
				{ Text = "Fast", Primary = true, Callback = function() print("fast") end },
				{ Text = "Balanced", Callback = function() print("balanced") end },
				{ Text = "Quality", Callback = function() print("quality") end },
			},
		})
	end,
})

-- ══════════════════════════════════════════════════════════════════════════
-- TAB 3 · DISPLAY
-- ══════════════════════════════════════════════════════════════════════════
local Display = Window:CreateTab("Display", "image")

local labels = Display:CreateSection({ Name = "Labels & text", Side = "left" })

labels:CreateLabel({ Name = "A plain label" })
labels:CreateLabel({ Name = "Label with an icon", Icon = "info" })
labels:CreateLabel({ Name = "**Bold**, *italic*, `code`", Color = "Text" })
labels:CreateLabel({ Name = "Accent coloured", Color = "Accent" })

labels:CreateDivider()
labels:CreateDivider("a divider with a caption")

labels:CreateParagraph({
	Title = "Formatting reference",
	Content = table.concat({
		"**bold** · *italic* · __underline__ · ~~strike~~",
		"`inline code` and ```code block```",
		"||spoiler|| shows dimmed",
		"[coloured span](Accent) and [hex span](#00e5c0)",
		"# Heading",
		"> A quote line",
		"- a bullet",
		"- another bullet",
	}, "\n"),
})

labels:CreateParagraph({
	Title = "Callout styles",
	Content = "Pass `Style = \"warning\"` for a coloured left bar.",
	Style = "warning",
})

local progress = Display:CreateSection({ Name = "Progress & images", Side = "right" })

local bar = progress:CreateProgressBar({
	Name = "Animated bar",
	Value = 0,
})

progress:CreateButton({
	Name = "Run the bar",
	Callback = function()
		task.spawn(function()
			for step = 0, 20 do
				task.wait(0.1)
				bar:SetProgress(step / 20)
			end
		end)
	end,
})

progress:CreateImage({
	Image = "https://github.com/WorkAccount211/VoidCriptUI_lib-Final-/blob/main/images/Watermark.png?raw=true",
	Height = 90,
	Caption = "an image element with a caption",
})

-- ── COLLAPSIBLE ───────────────────────────────────────────────────────────
local advanced = Display:CreateSection({ Name = "Nesting", Side = "left" })

local collapsible = advanced:CreateCollapsible({
	Name = "Advanced options",
	Open = false,
})
collapsible:CreateToggle({ Name = "Nested toggle", Flag = "demo_nested_toggle" })
collapsible:CreateSlider({ Name = "Nested slider", Flag = "demo_nested_slider", Range = { 0, 10 }, CurrentValue = 5 })
collapsible:CreateInput({ Name = "Nested input", Flag = "demo_nested_input" })

-- ══════════════════════════════════════════════════════════════════════════
-- TAB 4 · DATA
-- ══════════════════════════════════════════════════════════════════════════
local Data = Window:CreateTab("Data", "table")

local lists = Data:CreateSection({ Name = "List box", Side = "left" })

local whitelist = lists:CreateListBox({
	Name = "Whitelist",
	Flag = "demo_listbox",
	Items = { "Alice", "Bob", "Carol" },
	MultiSelect = true,
	Height = 130,
	AllowAdd = true,
	AllowRemove = true,
	Callback = function(selection)
		print("selected:", table.concat(selection, ", "))
	end,
})

lists:CreateButton({
	Name = "Add every player",
	Callback = function()
		local names = {}
		for _, player in ipairs(game.Players:GetPlayers()) do
			names[#names + 1] = player.Name
		end
		whitelist:SetItems(names)
	end,
})

local tables = Data:CreateSection({ Name = "Table", Side = "right", Height = 260 })

local playerTable = tables:CreateTable({
	Name = "Players",
	Columns = { "Name", "Display", "Team" },
	Rows = {},
	Height = 200,
	OnRowSelected = function(row, index)
		print("row", index, row[1])
	end,
})

local function refreshPlayers()
	local rows = {}
	for _, player in ipairs(game.Players:GetPlayers()) do
		rows[#rows + 1] = {
			player.Name,
			player.DisplayName,
			player.Team and player.Team.Name or "—",
		}
	end
	playerTable:SetRows(rows)
end
refreshPlayers()

tables:CreateButton({ Name = "Refresh", Icon = "refresh", Callback = refreshPlayers })

-- ══════════════════════════════════════════════════════════════════════════
-- TAB 5 · LIBRARY FEATURES
-- ══════════════════════════════════════════════════════════════════════════
local Lib = Window:CreateTab("Library", "settings")

local overlays = Lib:CreateSection({ Name = "Overlays", Side = "left" })

overlays:CreateButton({
	Name = "Show watermark",
	Callback = function()
		VoidLib:Watermark({
			Title = "voidcript demo",
			Modules = { "logo", "title", "user", "fps", "fps1", "ping", "memory", "time" },
			Position = "TopRight",
		})
	end,
})

overlays:CreateButton({
	Name = "Show keybind list",
	Callback = function()
		VoidLib:Keylist({
			Title = "binds",
			Columns = { "Name", "Mode", "Key", "State", "Hits" },
			Position = "LeftCenter",
		})
	end,
})

overlays:CreateButton({
	Name = "Custom watermark module",
	Callback = function()
		VoidLib:RegisterWatermarkModule("hp", function()
			local character = game.Players.LocalPlayer.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			return humanoid and ("hp %d"):format(math.floor(humanoid.Health)) or nil
		end, { Interval = 0.5, Color = "Success" })

		VoidLib:Watermark({
			Modules = { "logo", "title", "hp", "fps", "ping" },
		})
		VoidLib:Notify({ Title = "Module registered", Content = "`hp` added to the watermark", Type = "success" })
	end,
})

local configs = Lib:CreateSection({ Name = "Configs", Side = "right" })

configs:CreateButton({ Name = "Save config", Icon = "save", Callback = function() VoidLib:SaveConfig("catalogue") end })
configs:CreateButton({ Name = "Load config", Icon = "download", Callback = function() VoidLib:LoadConfig("catalogue") end })
configs:CreateButton({
	Name = "Export to clipboard",
	Icon = "upload",
	Callback = function()
		local payload = VoidLib:ExportConfig()
		if payload and setclipboard then setclipboard(payload) end
		VoidLib:Notify({ Title = "Exported", Content = "Config string copied", Type = "success" })
	end,
})

local misc = Lib:CreateSection({ Name = "Everything else", Side = "left" })

misc:CreateButton({ Name = "Open interface settings", Icon = "settings", Callback = function() Window:OpenInterfaceTab() end })
misc:CreateButton({ Name = "Print metrics", Icon = "gauge", Callback = function()
	local metrics = VoidLib:GetMetrics()
	VoidLib:Notify({
		Title = ("%d FPS · %d ms ping"):format(metrics.FPS, metrics.Ping),
		Content = ("%d flags · %d themed instances · device **%s**"):format(metrics.Flags, metrics.ThemedInstances, metrics.Device),
		Type = "info",
		Duration = 6,
	})
end })
misc:CreateButton({ Name = "Unload", Icon = "power", Risky = true, Callback = function() VoidLib:Unload() end })

misc:CreateParagraph({
	Title = "Where to go next",
	Content = "`examples/advanced.lua` shows a real script built on this library, and `examples/theming.lua` covers colours, presets and plugins.",
})

VoidLib:Notify({
	Title = "Catalogue loaded",
	Content = "Five tabs, every element. Press **RightShift** to hide.",
	Type = "success",
	Duration = 6,
})
