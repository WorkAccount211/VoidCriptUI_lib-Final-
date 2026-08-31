--[[
	════════════════════════════════════════════════════════════════════════
	VoidCriptUI · examples/basic.lua
	The 60-second start. Copy, run, adapt.
	════════════════════════════════════════════════════════════════════════

	Everything you need for a normal script: a window, a tab, a section, and
	the five elements you will use 90% of the time.
]]

local VoidLib = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/WorkAccount211/VoidCriptUI_lib-Final-/main/VoidCriptUI.lua"
))()

-- ── 1. window ──────────────────────────────────────────────────────────────
local Window = VoidLib:CreateWindow({
	Name = "my script",
	Subtitle = "basic example",
	ToggleKey = "RightShift",           -- press this to hide/show the menu

	ConfigurationSaving = {
		Enabled = true,                 -- settings survive a rejoin
		FolderName = "MyScript",
		FileName = "default",
	},
})

-- ── 2. tab ─────────────────────────────────────────────────────────────────
local Main = Window:CreateTab("Main", "bolt")

-- ── 3. section ─────────────────────────────────────────────────────────────
local Movement = Main:CreateSection("Movement")

-- ── 4. elements ────────────────────────────────────────────────────────────
local player = game.Players.LocalPlayer

Movement:CreateToggle({
	Name = "Infinite jump",
	Flag = "inf_jump",                  -- readable anywhere: VoidLib.Flags.inf_jump
	CurrentValue = false,
	Tooltip = "Jump again while already in the air",
	Callback = function(enabled)
		print("infinite jump:", enabled)
	end,
})

Movement:CreateSlider({
	Name = "Walk speed",
	Flag = "walk_speed",
	Range = { 16, 250 },
	Increment = 1,
	CurrentValue = 16,
	Suffix = " studs",
	Callback = function(value)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid.WalkSpeed = value end
	end,
})

Movement:CreateKeybind({
	Name = "Speed boost",
	Flag = "speed_key",
	CurrentKeybind = "LeftShift",
	Mode = "Hold",                      -- Always | Toggle | Hold
	Callback = function(held)
		print("boost held:", held)
	end,
})

Movement:CreateDivider()

Movement:CreateDropdown({
	Name = "Movement mode",
	Flag = "move_mode",
	Options = { "Normal", "Fly", "Noclip" },
	CurrentOption = "Normal",
	Callback = function(mode)
		print("mode:", mode)
	end,
})

Movement:CreateButton({
	Name = "Reset character",
	Icon = "refresh",
	Risky = true,                       -- asks "Are you sure?" before running
	Callback = function()
		player.Character:BreakJoints()
	end,
})

-- ── 5. a second section on the right column ────────────────────────────────
local Visuals = Main:CreateSection({ Name = "Visuals", Side = "right" })

Visuals:CreateToggle({
	Name = "ESP",
	Flag = "esp",
	Callback = function(enabled)
		print("esp:", enabled)
	end,
})

Visuals:CreateColorPicker({
	Name = "ESP colour",
	Flag = "esp_color",
	Color = Color3.fromRGB(199, 62, 110),
	DependsOn = "esp",                  -- hidden until the ESP toggle is on
	Callback = function(payload)
		print("colour:", payload.Color)
	end,
})

Visuals:CreateInput({
	Name = "Filter by name",
	Flag = "esp_filter",
	PlaceholderText = "leave empty for everyone",
	MaxLength = 40,
	Callback = function(text)
		print("filter:", text)
	end,
})

-- ── 6. reading flags from anywhere ─────────────────────────────────────────
task.spawn(function()
	while task.wait(5) do
		if VoidLib.Flags.esp then
			print("ESP is on, colour:", VoidLib.Flags.esp_color)
		end
	end
end)

-- ── 7. extras ──────────────────────────────────────────────────────────────
VoidLib:Watermark({
	Title = "my script",
	Modules = { "logo", "title", "user", "fps", "ping", "time" },
})

VoidLib:Notify({
	Title = "Loaded",
	Content = "Press **RightShift** to hide the menu",
	Type = "success",
	Duration = 5,
})
