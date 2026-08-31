--[[
	════════════════════════════════════════════════════════════════════════
	VoidCriptUI · examples/advanced.lua
	A complete, working script: "Prism" — a lighting & shader studio.
	════════════════════════════════════════════════════════════════════════

	This is the example to read once you know the basics. It is a real script,
	not a catalogue: it drives Roblox Lighting, post-processing effects and a
	small ESP module through the library, and shows the patterns you actually
	need in production.

	Patterns demonstrated
	---------------------
	· a key gate + staged boot screen
	· flags as the single source of truth (no shadow variables)
	· `VoidLib:OnFlagChanged` instead of duplicating logic in callbacks
	· DependsOn for conditional UI, including a predicate function
	· presets that write many flags at once
	· throttled sliders for per-frame work
	· a plugin that adds a brand-new element type (`CreateSpectrum`)
	· custom watermark modules
	· a Maid-style cleanup on unload
	· a "Showcase" tab that renders every element for screenshots
]]

local VoidLib = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/WorkAccount211/VoidCriptUI_lib-Final-/main/VoidCriptUI.lua"
))({
	Cache = true,
	Loading = true,
	Title = "prism",
	Subtitle = "lighting studio",
})

if not VoidLib then return end -- the user cancelled the loader

local Lighting  = game:GetService("Lighting")
local Players   = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

VoidLib:SetLogLevel("Info")

-- ══════════════════════════════════════════════════════════════════════════
-- 0 · A PLUGIN: a spectrum bar element that does not exist in the core
-- ══════════════════════════════════════════════════════════════════════════
VoidLib:RegisterPlugin({
	Name = "PrismWidgets",
	Version = "1.0.0",
	Author = "prism",

	Icons = {
		prism = "◈",
		spectrum = "▁▃▅▇",
	},

	Themes = {
		Prism = {
			Accent = "#7C5CFF",
			AccentDark = "#4F39B3",
			AccentSoft = "#AE9BFF",
			Background = "#0C0B12",
			Sidebar = "#09080E",
			Header = "#100F17",
			Section = "#121019",
			Element = "#1A1824",
			ElementHover = "#231F30",
			Outline = "#2A2539",
			OutlineSoft = "#1E1A29",
			Text = "#E9E7F5",
			TextDim = "#8E88A8",
		},
	},

	WatermarkModules = {
		clockskew = function()
			return ("t%+.1f"):format(Lighting.ClockTime - 14)
		end,
	},

	Elements = {
		-- Section:CreateSpectrum({ Name = "…", Bars = 16 })
		Spectrum = function(ctx, cfg)
			cfg = cfg or {}
			local Util, Theme, Scale = ctx.Util, ctx.Theme, ctx.Scale
			local control = ctx.Control.new("Spectrum", cfg, ctx)
			local maid = control:GetMaid()

			local barCount = cfg.Bars or 18
			local height = Scale.u(cfg.Height or 42)

			local holder = Util.New("Frame", {
				Name = "Spectrum",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, height + Scale.u(16)),
				Parent = ctx.Parent,
			})

			local label = Util.New("TextLabel", {
				BackgroundTransparency = 1,
				Font = Theme:Font("Font"),
				Text = tostring(cfg.Name or "Spectrum"),
				TextColor3 = Theme.C.TextDim,
				TextSize = Scale.f(12),
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, 0, 0, Scale.u(14)),
				Parent = holder,
			})
			Theme:Paint(label, { TextColor3 = "TextDim" })

			local frame = Util.New("Frame", {
				BackgroundColor3 = Theme.C.Element,
				Position = UDim2.fromOffset(0, Scale.u(16)),
				Size = UDim2.new(1, 0, 0, height),
				Parent = holder,
			}, {
				Util.New("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Bottom,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0, Scale.u(2)),
				}),
				Util.New("UIPadding", {
					PaddingLeft = UDim.new(0, Scale.u(6)), PaddingRight = UDim.new(0, Scale.u(6)),
					PaddingBottom = UDim.new(0, Scale.u(5)),
				}),
			})
			Theme:Paint(frame, { BackgroundColor3 = "Element" })
			Util.Corner(frame, Theme.Style.RadiusSmall)
			local stroke = Util.Stroke(frame, Theme.C.OutlineSoft)
			Theme:Paint(stroke, { Color = "OutlineSoft" })

			local bars = {}
			for index = 1, barCount do
				local bar = Util.New("Frame", {
					BackgroundColor3 = Theme.C.Accent,
					Size = UDim2.new(1 / barCount, -Scale.u(2), 0.2, 0),
					LayoutOrder = index,
					Parent = frame,
				})
				Theme:Paint(bar, { BackgroundColor3 = "Accent" })
				Util.Corner(bar, 1)
				bars[index] = bar
			end

			-- one 15 Hz updater for the whole widget
			local accumulator = 0
			maid:Give(RunService.Heartbeat:Connect(function(dt)
				accumulator = accumulator + dt
				if accumulator < 1 / 15 then return end
				accumulator = 0
				if not holder.Visible or not holder.Parent then return end
				local seed = os.clock() * (cfg.Speed or 2.2)
				for index, bar in ipairs(bars) do
					local wave = (math.sin(seed + index * 0.55) + 1) / 2
					local level = 0.16 + wave * 0.8 * (control._level or 1)
					bar.Size = UDim2.new(1 / barCount, -Scale.u(2), level, 0)
				end
			end))

			control._get = function() return control._level or 1 end
			control._set = function(value) control._level = math.clamp(tonumber(value) or 1, 0, 1) end
			function control:SetLevel(value) control._set(value) return self end

			control:_finalise(holder, frame)
			return control
		end,
	},

	OnLoad = function(lib)
		lib.Log:Info("PrismWidgets plugin loaded")
	end,
})

-- ══════════════════════════════════════════════════════════════════════════
-- 1 · WINDOW
-- ══════════════════════════════════════════════════════════════════════════
local Window = VoidLib:CreateWindow({
	Name = "prism",
	Subtitle = "lighting studio",
	Size = Vector2.new(860, 560),
	ToggleKey = "RightShift",
	Theme = "Prism",                    -- the preset our plugin registered
	LazyLoading = true,
	Resizable = true,
	MinimiseStyle = "Icon",
	Cursor = true,                      -- custom in-menu cursor
	Watermark = {
		Title = "prism",
		Modules = { "logo", "title", "user", "fps", "ping", "clockskew", "time" },
	},
	Keylist = {
		Title = "prism binds",
		Columns = { "Name", "Mode", "Key", "State" },
	},
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "Prism",
		FileName = "default",
		AutoSave = true,
		PerGame = true,                 -- separate settings per game
	},

	-- Uncomment for a key gate:
	-- KeySystem = true,
	-- KeySettings = {
	--     Title = "prism", Subtitle = "key system",
	--     Note = "Grab a key from the Discord",
	--     Key = { "prism-demo" }, SaveKey = true,
	--     GetKeyLink = "https://example.com/key",
	-- },
})

if not Window then return end

-- ══════════════════════════════════════════════════════════════════════════
-- 2 · STATE + ENGINE
-- ══════════════════════════════════════════════════════════════════════════
-- Everything the script needs lives in flags. The engine reads flags; the UI
-- writes them. There is no third copy of the state to keep in sync.
local Engine = {
	_original = {},
	_effects = {},
	_connections = {},
}

local LIGHTING_PROPERTIES = {
	"Ambient", "OutdoorAmbient", "Brightness", "ClockTime", "GeographicLatitude",
	"ExposureCompensation", "FogColor", "FogEnd", "FogStart", "GlobalShadows",
	"EnvironmentDiffuseScale", "EnvironmentSpecularScale",
}

function Engine:Capture()
	for _, property in ipairs(LIGHTING_PROPERTIES) do
		self._original[property] = Lighting[property]
	end
	VoidLib.Log:Info("captured %d lighting properties", #LIGHTING_PROPERTIES)
end

function Engine:Restore()
	for property, value in pairs(self._original) do
		pcall(function() Lighting[property] = value end)
	end
	for _, effect in pairs(self._effects) do
		pcall(function() effect:Destroy() end)
	end
	table.clear(self._effects)
end

function Engine:Effect(className)
	if self._effects[className] then return self._effects[className] end
	local effect = Instance.new(className)
	effect.Name = "Prism_" .. className
	effect.Enabled = false
	effect.Parent = Lighting
	self._effects[className] = effect
	return effect
end

Engine:Capture()

-- ══════════════════════════════════════════════════════════════════════════
-- 3 · TAB: ATMOSPHERE
-- ══════════════════════════════════════════════════════════════════════════
local Atmosphere = Window:CreateTab("Atmosphere", "sun", { "Light", "Fog", "Sky" })

local master = Atmosphere:CreateSection({ Name = "Master", Subtab = "Light", Side = "left" })

master:CreateToggle({
	Name = "Enable Prism",
	Flag = "prism_enabled",
	CurrentValue = false,
	Tooltip = "Master switch. Turning this off restores the game's original lighting.",
	Callback = function(enabled)
		if not enabled then
			Engine:Restore()
			VoidLib:Notify({ Title = "Prism off", Content = "Original lighting restored", Type = "info", Duration = 3 })
		else
			VoidLib:Notify({ Title = "Prism on", Content = "Your settings are being applied", Type = "success", Duration = 3 })
		end
	end,
})

master:CreateDropdown({
	Name = "Preset",
	Flag = "prism_preset",
	Options = { "Custom", "Cinematic", "Midnight", "Vaporwave", "Overcast", "Hyperreal" },
	CurrentOption = "Custom",
	Tooltip = "Presets write several flags at once — the UI follows automatically.",
	Callback = function(preset)
		if preset == "Custom" then return end

		local PRESETS = {
			Cinematic = {
				prism_brightness = 2.4, prism_exposure = 0.18, prism_clock = 17.4,
				prism_ambient = { Color = Color3.fromRGB(38, 34, 48), Alpha = 1 },
				prism_fog_enabled = true, prism_fog_start = 40, prism_fog_end = 700,
				prism_bloom = true, prism_bloom_intensity = 0.9,
				prism_saturation = 0.12, prism_contrast = 0.14, prism_dof = true,
			},
			Midnight = {
				prism_brightness = 0.7, prism_exposure = -0.25, prism_clock = 0.4,
				prism_ambient = { Color = Color3.fromRGB(18, 20, 34), Alpha = 1 },
				prism_fog_enabled = true, prism_fog_start = 0, prism_fog_end = 320,
				prism_bloom = true, prism_bloom_intensity = 1.5,
				prism_saturation = -0.2, prism_contrast = 0.2, prism_dof = false,
			},
			Vaporwave = {
				prism_brightness = 2.1, prism_exposure = 0.32, prism_clock = 6.4,
				prism_ambient = { Color = Color3.fromRGB(72, 32, 96), Alpha = 1 },
				prism_tint = { Color = Color3.fromRGB(255, 128, 214), Alpha = 1 },
				prism_fog_enabled = true, prism_fog_start = 10, prism_fog_end = 480,
				prism_bloom = true, prism_bloom_intensity = 2.2,
				prism_saturation = 0.55, prism_contrast = 0.1,
			},
			Overcast = {
				prism_brightness = 1.2, prism_exposure = -0.05, prism_clock = 12,
				prism_ambient = { Color = Color3.fromRGB(96, 100, 108), Alpha = 1 },
				prism_fog_enabled = true, prism_fog_start = 60, prism_fog_end = 900,
				prism_bloom = false, prism_saturation = -0.35, prism_contrast = -0.05,
			},
			Hyperreal = {
				prism_brightness = 3.2, prism_exposure = 0.1, prism_clock = 15,
				prism_ambient = { Color = Color3.fromRGB(52, 52, 58), Alpha = 1 },
				prism_fog_enabled = false,
				prism_bloom = true, prism_bloom_intensity = 0.6,
				prism_saturation = 0.3, prism_contrast = 0.25, prism_dof = false,
			},
		}

		local values = PRESETS[preset]
		if not values then return end
		for flag, value in pairs(values) do
			VoidLib:SetFlag(flag, value)
		end
		VoidLib:Notify({
			Title = ("Preset · %s"):format(preset),
			Content = ("%d settings applied"):format(#values > 0 and #values or 8),
			Type = "success", Duration = 4,
		})
	end,
})

master:CreateKeybind({
	Name = "Toggle Prism",
	Flag = "prism_key",
	CurrentKeybind = "Ctrl+P",
	Mode = "Toggle",
	Category = "Prism",
	Callback = function(state)
		VoidLib:SetFlag("prism_enabled", state)
	end,
})

-- ── LIGHT ─────────────────────────────────────────────────────────────────
local light = Atmosphere:CreateSection({ Name = "Light", Subtab = "Light", Side = "right" })

light:CreateSlider({
	Name = "Brightness",
	Flag = "prism_brightness",
	Range = { 0, 6 },
	Increment = 0.1,
	CurrentValue = 2,
	DependsOn = "prism_enabled",
	Throttle = 0.05,
})

light:CreateSlider({
	Name = "Exposure",
	Flag = "prism_exposure",
	Range = { -1, 1 },
	Increment = 0.02,
	CurrentValue = 0,
	DependsOn = "prism_enabled",
})

light:CreateKnob({
	Name = "Clock time",
	Flag = "prism_clock",
	Range = { 0, 24 },
	Increment = 0.1,
	CurrentValue = 14,
	Suffix = "h",
	DependsOn = "prism_enabled",
	Tooltip = "Drag up/down. Double-click to reset to noon.",
})

light:CreateColorPicker({
	Name = "Ambient",
	Flag = "prism_ambient",
	Color = Color3.fromRGB(48, 48, 56),
	Alpha = 1,
	DependsOn = "prism_enabled",
})

light:CreateToggle({
	Name = "Global shadows",
	Flag = "prism_shadows",
	CurrentValue = true,
	DependsOn = "prism_enabled",
})

-- ── FOG ───────────────────────────────────────────────────────────────────
local fog = Atmosphere:CreateSection({ Name = "Fog", Subtab = "Fog", Side = "left" })

fog:CreateToggle({
	Name = "Enable fog",
	Flag = "prism_fog_enabled",
	CurrentValue = false,
	DependsOn = "prism_enabled",
})

fog:CreateColorPicker({
	Name = "Fog colour",
	Flag = "prism_fog_color",
	Color = Color3.fromRGB(28, 26, 38),
	DependsOn = { prism_enabled = true, prism_fog_enabled = true },
})

fog:CreateRangeSlider({
	Name = "Fog distance",
	Flag = "prism_fog_range",
	Range = { 0, 2000 },
	Increment = 10,
	CurrentMin = 30,
	CurrentMax = 600,
	Suffix = "m",
	DependsOn = { prism_enabled = true, prism_fog_enabled = true },
	Callback = function(range)
		VoidLib:SetFlag("prism_fog_start", range.Min, true)
		VoidLib:SetFlag("prism_fog_end", range.Max, true)
	end,
})

-- hidden mirrors so presets can write start/end independently
fog:CreateSlider({ Name = "Fog start", Flag = "prism_fog_start", Range = { 0, 2000 }, CurrentValue = 30, Visible = false, Searchable = false })
fog:CreateSlider({ Name = "Fog end", Flag = "prism_fog_end", Range = { 0, 2000 }, CurrentValue = 600, Visible = false, Searchable = false })

local post = Atmosphere:CreateSection({ Name = "Post-processing", Subtab = "Fog", Side = "right" })

post:CreateToggle({ Name = "Bloom", Flag = "prism_bloom", DependsOn = "prism_enabled" })
post:CreateSlider({
	Name = "Bloom intensity",
	Flag = "prism_bloom_intensity",
	Range = { 0, 4 }, Increment = 0.1, CurrentValue = 1,
	DependsOn = { prism_enabled = true, prism_bloom = true },
})
post:CreateSlider({
	Name = "Bloom size",
	Flag = "prism_bloom_size",
	Range = { 1, 56 }, Increment = 1, CurrentValue = 24,
	DependsOn = { prism_enabled = true, prism_bloom = true },
})

post:CreateDivider()

post:CreateSlider({ Name = "Saturation", Flag = "prism_saturation", Range = { -1, 1 }, Increment = 0.02, CurrentValue = 0, DependsOn = "prism_enabled" })
post:CreateSlider({ Name = "Contrast", Flag = "prism_contrast", Range = { -1, 1 }, Increment = 0.02, CurrentValue = 0, DependsOn = "prism_enabled" })
post:CreateColorPicker({ Name = "Tint", Flag = "prism_tint", Color = Color3.fromRGB(255, 255, 255), DependsOn = "prism_enabled" })

post:CreateToggle({ Name = "Depth of field", Flag = "prism_dof", DependsOn = "prism_enabled" })
post:CreateSlider({
	Name = "Focus distance",
	Flag = "prism_dof_focus",
	Range = { 0, 200 }, Increment = 1, CurrentValue = 30,
	-- a predicate dependency: shown only when DOF is on AND Prism is enabled
	DependsOn = function(flags)
		return flags.prism_enabled == true and flags.prism_dof == true
	end,
})

-- ── SKY ───────────────────────────────────────────────────────────────────
local sky = Atmosphere:CreateSection({ Name = "Sky", Subtab = "Sky", Side = "left" })

sky:CreateToggle({ Name = "Custom skybox", Flag = "prism_sky", DependsOn = "prism_enabled" })
sky:CreateInput({
	Name = "Skybox asset id",
	Flag = "prism_sky_id",
	Numeric = true,
	PlaceholderText = "e.g. 12345678",
	DependsOn = { prism_enabled = true, prism_sky = true },
})
sky:CreateSlider({
	Name = "Star count",
	Flag = "prism_stars",
	Range = { 0, 5000 }, Increment = 100, CurrentValue = 3000,
	DependsOn = { prism_enabled = true, prism_sky = true },
	CallbackOnRelease = true,
})

local monitor = Atmosphere:CreateSection({ Name = "Monitor", Subtab = "Sky", Side = "right" })
local spectrum = monitor:CreateSpectrum({ Name = "Activity", Bars = 20, Speed = 2.4 })
monitor:CreateParagraph({
	Title = "This widget comes from a plugin",
	Content = "`CreateSpectrum` is not part of the library core — it is registered by the **PrismWidgets** plugin at the top of this file. Plugins can add elements, icons, themes and watermark modules without touching library code.",
})

-- ══════════════════════════════════════════════════════════════════════════
-- 4 · TAB: PLAYERS (ESP)
-- ══════════════════════════════════════════════════════════════════════════
local PlayersTab = Window:CreateTab("Players", "users")

local esp = PlayersTab:CreateSection({ Name = "ESP", Side = "left" })

esp:CreateToggle({
	Name = "Enable ESP",
	Flag = "esp_enabled",
	Keybind = "Ctrl+E",
	KeybindMode = "Toggle",
	Color = Color3.fromRGB(124, 92, 255),
	ColorFlag = "esp_color",
	Tooltip = "Toggle + keybind + colour picker on one row",
})

esp:CreateMultiDropdown({
	Name = "Show",
	Flag = "esp_parts",
	Options = { "Box", "Name", "Distance", "Health", "Tracer" },
	CurrentOption = { "Box", "Name" },
	DependsOn = "esp_enabled",
})

esp:CreateSlider({
	Name = "Max distance",
	Flag = "esp_distance",
	Range = { 50, 2000 }, Increment = 50, CurrentValue = 500,
	Suffix = "m",
	DependsOn = "esp_enabled",
})

esp:CreateToggle({ Name = "Team check", Flag = "esp_team", CurrentValue = true, DependsOn = "esp_enabled" })

local targets = PlayersTab:CreateSection({ Name = "Targets", Side = "right", Height = 300 })

local playerList = targets:CreateListBox({
	Name = "Whitelist",
	Flag = "esp_whitelist",
	Items = {},
	MultiSelect = true,
	Height = 150,
	AllowRemove = true,
	EmptyText = "nobody whitelisted",
})

targets:CreateButton({
	Name = "Refresh player list",
	Icon = "refresh",
	Callback = function()
		local names = {}
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then names[#names + 1] = player.Name end
		end
		playerList:SetItems(names)
		VoidLib:Notify({ Title = "Refreshed", Content = ("%d players"):format(#names), Type = "info", Duration = 3 })
	end,
})

-- The ESP engine is a single loop reading flags. Note it never queries the UI.
local espFolder = Instance.new("Folder")
espFolder.Name = "PrismESP"
espFolder.Parent = workspace

local highlights = {}
local function clearHighlights()
	for _, highlight in pairs(highlights) do pcall(function() highlight:Destroy() end) end
	table.clear(highlights)
end

VoidLib:OnFlagChanged("esp_enabled", function(enabled)
	if not enabled then clearHighlights() end
end)

table.insert(Engine._connections, RunService.Heartbeat:Connect((function()
	local accumulator = 0
	return function(dt)
		accumulator = accumulator + dt
		if accumulator < 0.25 then return end
		accumulator = 0
		if not VoidLib.Flags.esp_enabled then return end

		local color = VoidLib.Flags.esp_color
		color = type(color) == "table" and color.Color or color or Color3.new(1, 1, 1)
		local maxDistance = VoidLib.Flags.esp_distance or 500
		local teamCheck = VoidLib.Flags.esp_team
		local origin = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local skip = teamCheck and player.Team and player.Team == LocalPlayer.Team
				local inRange = root and origin and (root.Position - origin.Position).Magnitude <= maxDistance

				if root and inRange and not skip then
					local highlight = highlights[player]
					if not highlight then
						highlight = Instance.new("Highlight")
						highlight.FillTransparency = 0.7
						highlight.OutlineTransparency = 0
						highlight.Parent = espFolder
						highlights[player] = highlight
					end
					highlight.Adornee = character
					highlight.FillColor = color
					highlight.OutlineColor = color
					highlight.Enabled = true
				elseif highlights[player] then
					highlights[player].Enabled = false
				end
			end
		end
	end
end)()))

-- ══════════════════════════════════════════════════════════════════════════
-- 5 · TAB: SHOWCASE (for screenshots / feature tour)
-- ══════════════════════════════════════════════════════════════════════════
local Showcase = Window:CreateTab("Showcase", "sparkle", { "Controls", "Feedback", "Data" })

local showControls = Showcase:CreateSection({ Name = "Every control", Subtab = "Controls", Side = "left" })
showControls:CreateToggle({ Name = "Checkbox", Flag = "show_a", CurrentValue = true })
showControls:CreateToggle({ Name = "Switch", Flag = "show_b", Style = "Switch", CurrentValue = true })
showControls:CreateSlider({ Name = "Slider", Flag = "show_c", Range = { 0, 100 }, CurrentValue = 64, Suffix = "%" })
showControls:CreateRangeSlider({ Name = "Range", Flag = "show_d", Range = { 0, 100 }, CurrentMin = 20, CurrentMax = 80 })
showControls:CreateDropdown({ Name = "Dropdown", Flag = "show_e", Options = { "One", "Two", "Three" }, CurrentOption = "Two" })
showControls:CreateMultiDropdown({ Name = "Multi", Flag = "show_f", Options = { "A", "B", "C", "D" }, CurrentOption = { "A", "C" } })
showControls:CreateInput({ Name = "Input", Flag = "show_g", CurrentValue = "hello" })
showControls:CreateKeybind({ Name = "Keybind", Flag = "show_h", CurrentKeybind = "MB2", Mode = "Hold" })
showControls:CreateColorPicker({ Name = "Colour", Flag = "show_i", Color = Color3.fromRGB(124, 92, 255), Alpha = 0.85 })

local showDials = Showcase:CreateSection({ Name = "Dials", Subtab = "Controls", Side = "right" })
showDials:CreateKnob({ Name = "Knob", Flag = "show_j", Range = { 0, 100 }, CurrentValue = 72, Suffix = "%" })
showDials:CreateSpectrum({ Name = "Plugin widget", Bars = 14 })
showDials:CreateProgressBar({ Name = "Progress", Value = 0.72 })

local showFeedback = Showcase:CreateSection({ Name = "Buttons", Subtab = "Feedback", Side = "left" })
showFeedback:CreateButton({ Name = "Normal button", Callback = function() end })
showFeedback:CreateButton({ Name = "With icon", Icon = "bolt", Callback = function() end })
showFeedback:CreateButton({ Name = "Risky button", Icon = "warning", Risky = true, Callback = function() end })
showFeedback:CreateImageButton({ Name = "Image button", Image = "star", Layout = "IconText", Callback = function() end })

local showText = Showcase:CreateSection({ Name = "Text", Subtab = "Feedback", Side = "right" })
showText:CreateLabel({ Name = "Label with an icon", Icon = "info" })
showText:CreateParagraph({
	Title = "Rich formatting",
	Content = "**bold** · *italic* · `code` · ~~strike~~ · [accent](Accent)\n> quotes work too\n- and bullets",
})
showText:CreateDivider("divider")
showText:CreateParagraph({ Title = "Warning callout", Content = "Style = \"warning\" adds the amber bar.", Style = "warning" })

local showData = Showcase:CreateSection({ Name = "Data", Subtab = "Data", Side = "left", Height = 320 })
showData:CreateListBox({
	Name = "List box",
	Items = { "First", "Second", "Third", "Fourth" },
	MultiSelect = true,
	Height = 110,
})
showData:CreateTable({
	Name = "Table",
	Columns = { "Key", "Value" },
	Rows = {
		{ "device", select(1, VoidLib:GetDevice()) },
		{ "version", VoidLib.Version },
		{ "theme", VoidLib.Theme.Name },
		{ "flags", tostring(#VoidLib:ListFlags()) },
	},
	Height = 110,
})

local showNested = Showcase:CreateSection({ Name = "Nesting", Subtab = "Data", Side = "right" })
local group = showNested:CreateCollapsible({ Name = "Collapsible group", Open = true })
group:CreateToggle({ Name = "Inside a collapsible", Flag = "show_nested" })
group:CreateSlider({ Name = "Also inside", Flag = "show_nested_2", Range = { 0, 10 }, CurrentValue = 3 })

-- ══════════════════════════════════════════════════════════════════════════
-- 6 · THE ENGINE LOOP — reads flags, writes Lighting
-- ══════════════════════════════════════════════════════════════════════════
local function applyLighting()
	if not VoidLib.Flags.prism_enabled then return end
	local F = VoidLib.Flags

	local function color(flag, fallback)
		local value = F[flag]
		if type(value) == "table" and value.Color then return value.Color end
		if typeof(value) == "Color3" then return value end
		return fallback
	end

	Lighting.Brightness = F.prism_brightness or 2
	Lighting.ExposureCompensation = F.prism_exposure or 0
	Lighting.ClockTime = F.prism_clock or 14
	Lighting.Ambient = color("prism_ambient", Color3.fromRGB(48, 48, 56))
	Lighting.OutdoorAmbient = Lighting.Ambient
	Lighting.GlobalShadows = F.prism_shadows ~= false

	if F.prism_fog_enabled then
		Lighting.FogColor = color("prism_fog_color", Color3.fromRGB(28, 26, 38))
		Lighting.FogStart = F.prism_fog_start or 30
		Lighting.FogEnd = F.prism_fog_end or 600
	else
		Lighting.FogEnd = 100000
	end

	local bloom = Engine:Effect("BloomEffect")
	bloom.Enabled = F.prism_bloom == true
	bloom.Intensity = F.prism_bloom_intensity or 1
	bloom.Size = F.prism_bloom_size or 24

	local correction = Engine:Effect("ColorCorrectionEffect")
	local saturation = F.prism_saturation or 0
	local contrast = F.prism_contrast or 0
	correction.Enabled = saturation ~= 0 or contrast ~= 0 or F.prism_tint ~= nil
	correction.Saturation = saturation
	correction.Contrast = contrast
	correction.TintColor = color("prism_tint", Color3.new(1, 1, 1))

	local dof = Engine:Effect("DepthOfFieldEffect")
	dof.Enabled = F.prism_dof == true
	dof.FocusDistance = F.prism_dof_focus or 30
	dof.InFocusRadius = 25
	dof.inFocusRadius = dof.InFocusRadius

	if F.prism_sky and tonumber(F.prism_sky_id) then
		local existing = Lighting:FindFirstChildOfClass("Sky")
		local skyInstance = Engine._effects.Sky
		if not skyInstance then
			skyInstance = Instance.new("Sky")
			skyInstance.Name = "Prism_Sky"
			skyInstance.Parent = Lighting
			Engine._effects.Sky = skyInstance
		end
		skyInstance.StarCount = F.prism_stars or 3000
	end

	-- feed the plugin widget so it reacts to brightness
	if spectrum and spectrum.SetLevel then
		spectrum:SetLevel(math.clamp((F.prism_brightness or 2) / 6, 0.15, 1))
	end
end

-- Any flag change re-applies the lighting, debounced so dragging a slider does
-- not write to Lighting 200 times a second.
local applyDebounced = VoidLib.Debounce(applyLighting, 0.03)
VoidLib:OnFlagChanged("*", function(flag)
	if tostring(flag):sub(1, 6) == "prism_" then
		applyDebounced()
	end
end)

table.insert(Engine._connections, RunService.Heartbeat:Connect((function()
	local accumulator = 0
	return function(dt)
		accumulator = accumulator + dt
		if accumulator < 1 then return end
		accumulator = 0
		applyLighting() -- a slow safety pass in case the game overrides us
	end
end)()))

-- ══════════════════════════════════════════════════════════════════════════
-- 7 · WINDOW HOOKS + CLEANUP
-- ══════════════════════════════════════════════════════════════════════════
Window.OnToggle:Connect(function(visible)
	VoidLib.Log:Debug("menu %s", visible and "opened" or "closed")
end)

Window.OnTabChanged:Connect(function(tab)
	VoidLib.Log:Debug("tab → %s", tostring(tab.Name))
end)

-- Register a plugin hook that runs on unload so our engine cleans up too.
VoidLib:RegisterPlugin({
	Name = "PrismCleanup",
	OnUnload = function()
		Engine:Restore()
		clearHighlights()
		for _, connection in ipairs(Engine._connections) do
			pcall(function() connection:Disconnect() end)
		end
		pcall(function() espFolder:Destroy() end)
		VoidLib.Log:Info("prism cleaned up")
	end,
})

VoidLib:Notify({
	Title = "Prism ready",
	Content = "Enable **Prism** in the Atmosphere tab, then try a preset.\n> `Ctrl+P` toggles it · `RightShift` hides the menu",
	Type = "success",
	Duration = 9,
	Actions = {
		{ Name = "Try Cinematic", Callback = function()
			VoidLib:SetFlag("prism_enabled", true)
			VoidLib:SetFlag("prism_preset", "Cinematic")
		end },
		{ Name = "Dismiss", Style = "ghost" },
	},
})
