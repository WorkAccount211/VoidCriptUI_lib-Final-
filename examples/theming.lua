--[[
	════════════════════════════════════════════════════════════════════════
	VoidCriptUI · examples/theming.lua
	Colours, presets, fonts, scaling, icons and plugins.
	════════════════════════════════════════════════════════════════════════

	The whole visual identity of the library is a flat table of tokens. Change
	a token and every live instance repaints — nothing is rebuilt, nothing
	flickers, and it works while the menu is open.

	Token reference
	---------------
	Accent        the brand colour: fills, active states, indicators
	AccentDark    pressed states, gradient bottoms
	AccentSoft    hover accents, code spans in rich text
	Risky         warnings, "risky" elements
	Danger        errors, destructive actions
	Success       confirmations

	Backdrop      the dim behind modals
	Background    window body
	Sidebar       icon rail
	Header        header bar, cards, notifications
	Section       groupbox body
	Element       inputs, buttons, tracks
	ElementHover  hover state
	ElementActive pressed state
	Overlay       dropdown/picker panels

	Outline       standard borders
	OutlineSoft   quiet borders and dividers
	OutlineStrong hover borders

	Text          primary text
	TextDim       secondary text
	TextDark      tertiary / placeholder text
	TextOnAccent  text drawn on top of Accent

	Style keys (non-colour): Font, FontMedium, FontBold, FontMono, Radius,
	RadiusSmall, BackdropTransparency, GlassStrength, ShadowTransparency.
]]

local VoidLib = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/WorkAccount211/VoidCriptUI_lib-Final-/main/VoidCriptUI.lua"
))()

-- ══════════════════════════════════════════════════════════════════════════
-- 1 · REGISTER YOUR OWN PRESETS
-- ══════════════════════════════════════════════════════════════════════════
-- Presets accept Color3 or hex strings interchangeably.
VoidLib:RegisterTheme("Sunset", {
	Accent = "#FF6B4A", AccentDark = "#B8452D", AccentSoft = "#FFA98F",
	Background = "#14100F", Sidebar = "#0F0C0B", Header = "#181312",
	Section = "#1A1514", Element = "#241C1A", ElementHover = "#302523",
	ElementActive = "#3B2E2B", Overlay = "#1E1716",
	Outline = "#382B28", OutlineSoft = "#281F1D", OutlineStrong = "#4A3934",
	Text = "#F5EAE6", TextDim = "#A8938C", TextDark = "#75625C",
})

VoidLib:RegisterTheme("Arctic", {
	Accent = "#6FD3FF", AccentDark = "#3D8CB0", AccentSoft = "#B4E9FF",
	Background = "#0B1015", Sidebar = "#080C10", Header = "#0E141A",
	Section = "#10171E", Element = "#18222B", ElementHover = "#212E39",
	ElementActive = "#2A3A47", Overlay = "#131B22",
	Outline = "#28353F", OutlineSoft = "#1B242C", OutlineStrong = "#374855",
	Text = "#E6F2F8", TextDim = "#8AA0AD", TextDark = "#5D6F7A",
})

VoidLib:RegisterTheme("Terminal", {
	Accent = "#33FF88", AccentDark = "#1FA355", AccentSoft = "#8CFFC0",
	Background = "#080C08", Sidebar = "#050805", Header = "#0B100B",
	Section = "#0C120C", Element = "#121A12", ElementHover = "#1A241A",
	ElementActive = "#233023", Overlay = "#0E150E",
	Outline = "#1F2C1F", OutlineSoft = "#162016", OutlineStrong = "#2C3E2C",
	Text = "#D6F5DE", TextDim = "#7FA98C", TextDark = "#55735E",
	-- non-colour tokens live in the same table
	Font = Enum.Font.Code,
	FontMedium = Enum.Font.Code,
	FontBold = Enum.Font.Code,
	Radius = 2,
	RadiusSmall = 1,
})

-- ══════════════════════════════════════════════════════════════════════════
-- 2 · REGISTER CUSTOM ICONS
-- ══════════════════════════════════════════════════════════════════════════
-- Glyphs cost nothing (no image download, tinted by the theme).
VoidLib.Icons:RegisterPack({
	paint    = "◐",
	swatch   = "▧",
	contrast = "◑",
	preset   = "▤",
	-- an asset id works too: mylogo = 1234567890,
})

-- ══════════════════════════════════════════════════════════════════════════
-- 3 · WINDOW
-- ══════════════════════════════════════════════════════════════════════════
local Window = VoidLib:CreateWindow({
	Name = "theming",
	Subtitle = "make it yours",
	Size = Vector2.new(780, 520),
	Theme = "Midnight",
	ConfigurationSaving = {
		Enabled = true,
		FolderName = "VoidCriptTheming",
		FileName = "theme",
	},
})

-- ══════════════════════════════════════════════════════════════════════════
-- 4 · PRESET SWITCHER
-- ══════════════════════════════════════════════════════════════════════════
local Theme = Window:CreateTab("Theme", "paint", { "Presets", "Tokens", "Layout" })

local presets = Theme:CreateSection({ Name = "Presets", Subtab = "Presets", Side = "left" })

presets:CreateDropdown({
	Name = "Active preset",
	Flag = "theme_preset",
	Options = VoidLib:ListThemes(),
	CurrentOption = VoidLib.Theme.Name,
	Tooltip = "Built-ins plus the three registered at the top of this file",
	Callback = function(name)
		VoidLib:SetThemePreset(name)
		VoidLib:Notify({
			Title = ("Theme · %s"):format(name),
			Content = "Every live element repainted — nothing was rebuilt.",
			Type = "success", Duration = 4,
		})
	end,
})

presets:CreateParagraph({
	Title = "Built-in presets",
	Content = table.concat({
		"`Midnight` — the default crimson-pink",
		"`Blood` — deep red",
		"`Ocean` — cool blue",
		"`Mono` — greyscale",
		"`Toxic` — acid green",
		"`Amethyst` — violet",
		"`Light` — a light theme",
		"",
		"From this file: `Sunset`, `Arctic`, `Terminal`.",
	}, "\n"),
})

-- One-click preset buttons, generated from the registry.
local quick = Theme:CreateSection({ Name = "Quick switch", Subtab = "Presets", Side = "right" })
for _, name in ipairs(VoidLib:ListThemes()) do
	quick:CreateButton({
		Name = name,
		Icon = "swatch",
		Callback = function()
			VoidLib:SetThemePreset(name)
			VoidLib:SetFlag("theme_preset", name, true)
		end,
	})
end

-- ══════════════════════════════════════════════════════════════════════════
-- 5 · LIVE TOKEN EDITOR
-- ══════════════════════════════════════════════════════════════════════════
local TOKEN_GROUPS = {
	{
		Name = "Brand",
		Side = "left",
		Tokens = {
			{ "Accent", "Accent" },
			{ "AccentDark", "Accent (pressed)" },
			{ "AccentSoft", "Accent (soft)" },
			{ "Risky", "Warning" },
			{ "Danger", "Error" },
			{ "Success", "Success" },
		},
	},
	{
		Name = "Surfaces",
		Side = "right",
		Tokens = {
			{ "Background", "Window body" },
			{ "Sidebar", "Icon rail" },
			{ "Header", "Header / cards" },
			{ "Section", "Groupbox" },
			{ "Element", "Inputs" },
			{ "ElementHover", "Hover" },
			{ "Overlay", "Popups" },
		},
	},
	{
		Name = "Lines & text",
		Side = "left",
		Tokens = {
			{ "Outline", "Outline" },
			{ "OutlineSoft", "Outline (soft)" },
			{ "OutlineStrong", "Outline (hover)" },
			{ "Text", "Primary text" },
			{ "TextDim", "Secondary text" },
			{ "TextDark", "Tertiary text" },
		},
	},
}

for _, group in ipairs(TOKEN_GROUPS) do
	local section = Theme:CreateSection({ Name = group.Name, Subtab = "Tokens", Side = group.Side })
	for _, entry in ipairs(group.Tokens) do
		local token, label = entry[1], entry[2]
		section:CreateColorPicker({
			Name = label,
			Color = VoidLib.Theme.Tokens[token],
			SaveToConfig = false,
			Tooltip = ("Token `%s`"):format(token),
			Callback = function(payload)
				local color = type(payload) == "table" and payload.Color or payload
				if color then
					VoidLib:SetTheme({ [token] = color })
					VoidLib:SetFlag("theme_preset", "Custom", true)
				end
			end,
		})
	end
end

-- Export the current theme as pasteable Lua.
local export = Theme:CreateSection({ Name = "Export", Subtab = "Tokens", Side = "right" })

export:CreateButton({
	Name = "Copy theme as Lua",
	Icon = "copy",
	Callback = function()
		local tokens = VoidLib:GetTheme()
		local lines = { "VoidLib:SetTheme({" }
		local names = {}
		for token in pairs(tokens) do names[#names + 1] = token end
		table.sort(names)
		for _, token in ipairs(names) do
			lines[#lines + 1] = ("\t%s = \"%s\","):format(token, VoidLib.ToHex(tokens[token]))
		end
		lines[#lines + 1] = "})"
		local code = table.concat(lines, "\n")
		if setclipboard then setclipboard(code) end
		VoidLib:Notify({ Title = "Copied", Content = "Paste it straight into your script", Type = "success", Duration = 4 })
	end,
})

export:CreateInput({
	Name = "Set accent from hex",
	PlaceholderText = "#7C5CFF",
	Pattern = "^#?%x%x%x%x%x%x$",
	PatternMessage = "Use #RRGGBB",
	SaveToConfig = false,
	Callback = function(hex)
		if hex == "" then return end
		VoidLib:SetTheme({ Accent = hex })
	end,
})

export:CreateParagraph({
	Title = "Hex strings are fine",
	Content = "`SetTheme` accepts `Color3` **or** a hex string:\n```VoidLib:SetTheme({ Accent = \"#7C5CFF\" })```",
})

-- ══════════════════════════════════════════════════════════════════════════
-- 6 · LAYOUT, FONTS AND SCALE
-- ══════════════════════════════════════════════════════════════════════════
local layout = Theme:CreateSection({ Name = "Scale", Subtab = "Layout", Side = "left" })

layout:CreateSlider({
	Name = "UI scale",
	Range = { 0.7, 1.6 }, Increment = 0.05,
	CurrentValue = VoidLib.Scale.Multiplier,
	Suffix = "×",
	CallbackOnRelease = true,
	SaveToConfig = false,
	Tooltip = "Every size in the library is derived from this and the viewport width.",
	Callback = function(value) VoidLib:SetScale(value) end,
})

layout:CreateToggle({
	Name = "Compact mode",
	CurrentValue = VoidLib.Scale.Compact,
	SaveToConfig = false,
	Tooltip = "Tighter paddings and one column — for narrow monitors and tablets.",
	Callback = function(state) VoidLib:SetCompact(state) end,
})

layout:CreateDropdown({
	Name = "Font family",
	Options = { "Gotham", "GothamMedium", "SourceSans", "Code", "Fondamento", "Michroma" },
	CurrentOption = "Gotham",
	SaveToConfig = false,
	Callback = function(fontName)
		local font = Enum.Font[fontName]
		if not font then return end
		VoidLib:SetTheme({
			Font = font,
			FontMedium = Enum.Font[fontName .. "Medium"] or font,
			FontBold = Enum.Font[fontName .. "Bold"] or font,
		})
		VoidLib:Notify({
			Title = "Font changed",
			Content = "Elements created from now on use it; existing text keeps its font until the tab rebuilds.",
			Type = "info", Duration = 5,
		})
	end,
})

layout:CreateSlider({
	Name = "Corner radius",
	Range = { 0, 12 }, Increment = 1,
	CurrentValue = VoidLib.Theme.Style.Radius,
	SaveToConfig = false,
	CallbackOnRelease = true,
	Callback = function(value)
		VoidLib:SetTheme({ Radius = value, RadiusSmall = math.max(1, value - 2) })
	end,
})

local effects = Theme:CreateSection({ Name = "Depth", Subtab = "Layout", Side = "right" })

effects:CreateSlider({
	Name = "Backdrop dim",
	Range = { 0, 0.9 }, Increment = 0.05,
	CurrentValue = VoidLib.Theme.Style.BackdropTransparency,
	SaveToConfig = false,
	Callback = function(value) VoidLib:SetTheme({ BackdropTransparency = value }) end,
})

effects:CreateSlider({
	Name = "Glass strength",
	Range = { 0.85, 1 }, Increment = 0.005,
	CurrentValue = VoidLib.Theme.Style.GlassStrength,
	SaveToConfig = false,
	Tooltip = "Lower = a more visible sheen on cards and windows.",
	Callback = function(value) VoidLib:SetTheme({ GlassStrength = value }) end,
})

effects:CreateSlider({
	Name = "Shadow strength",
	Range = { 0, 0.9 }, Increment = 0.05,
	CurrentValue = VoidLib.Theme.Style.ShadowTransparency,
	SaveToConfig = false,
	Callback = function(value) VoidLib:SetTheme({ ShadowTransparency = value }) end,
})

effects:CreateParagraph({
	Title = "Why there is no real blur",
	Content = table.concat({
		"`EditableImage` readback stalls the render thread, and `DepthOfField` affects the **whole game** — both cost FPS and get flagged in reviews.",
		"",
		"Instead the backdrop stacks a deep dim, two crossed vignette gradients and a faint glass sheen inside one `CanvasGroup`. It reads as frosted glass and costs nothing to animate.",
	}, "\n"),
})

-- ══════════════════════════════════════════════════════════════════════════
-- 7 · PREVIEW TAB — see the theme applied to every element
-- ══════════════════════════════════════════════════════════════════════════
local Preview = Window:CreateTab("Preview", "eye")

local left = Preview:CreateSection({ Name = "Controls", Side = "left" })
left:CreateToggle({ Name = "Checkbox", Flag = "prev_a", CurrentValue = true })
left:CreateToggle({ Name = "Switch", Flag = "prev_b", Style = "Switch", CurrentValue = true })
left:CreateSlider({ Name = "Slider", Flag = "prev_c", Range = { 0, 100 }, CurrentValue = 70, Suffix = "%" })
left:CreateDropdown({ Name = "Dropdown", Flag = "prev_d", Options = { "Alpha", "Beta", "Gamma" }, CurrentOption = "Beta" })
left:CreateInput({ Name = "Input", Flag = "prev_e", CurrentValue = "sample text" })
left:CreateKeybind({ Name = "Keybind", Flag = "prev_f", CurrentKeybind = "Ctrl+T", Mode = "Toggle" })
left:CreateColorPicker({ Name = "Colour", Flag = "prev_g", Color = VoidLib.Theme.Tokens.Accent, Alpha = 0.9 })

local right = Preview:CreateSection({ Name = "Feedback", Side = "right" })
right:CreateButton({ Name = "Primary action", Icon = "bolt", Callback = function() end })
right:CreateButton({ Name = "Risky action", Icon = "warning", Risky = true, Callback = function() end })
right:CreateProgressBar({ Name = "Progress", Value = 0.55 })
right:CreateLabel({ Name = "A label with `code`", Icon = "info" })
right:CreateParagraph({ Title = "Paragraph", Content = "**Bold**, *italic*, [accent](Accent) and `monospace`." })
right:CreateDivider("divider")

local states = Preview:CreateSection({ Name = "Semantic colours", Side = "left" })
for _, kind in ipairs({ "info", "success", "warning", "error" }) do
	states:CreateButton({
		Name = ("Notify · %s"):format(kind),
		Callback = function()
			VoidLib:Notify({
				Title = kind,
				Content = ("Uses the **%s** token"):format(kind == "info" and "Accent" or (kind == "success" and "Success" or (kind == "warning" and "Risky" or "Danger"))),
				Type = kind, Duration = 4,
			})
		end,
	})
end

local nested = Preview:CreateSection({ Name = "Nesting", Side = "right" })
local group = nested:CreateCollapsible({ Name = "Collapsible", Open = true })
group:CreateToggle({ Name = "Inside", Flag = "prev_nested" })
group:CreateSlider({ Name = "Also inside", Flag = "prev_nested_2", Range = { 0, 10 }, CurrentValue = 4 })

VoidLib:Notify({
	Title = "Theming demo ready",
	Content = "Switch a preset in the **Theme** tab, then look at **Preview** — everything repaints live.",
	Type = "success",
	Duration = 7,
})
