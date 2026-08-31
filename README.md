<div align="center">

<img src="https://raw.githubusercontent.com/WorkAccount211/VoidCriptUI_lib-Final-/main/images/banner.png" width="100%" alt="VoidCriptUI banner">

<br>

<img src="https://raw.githubusercontent.com/WorkAccount211/VoidCriptUI_lib-Final-/main/images/icon.png" width="96" alt="VoidCript icon">

# VoidCriptUI

### Modern • Modular • Adaptive • Performance-focused Roblox UI Library

**Built by VoidCript**

<p>
  <a href="https://github.com/WorkAccount211/VoidCriptUI_lib-Final-"><img src="https://img.shields.io/badge/version-3.0.0-8B5CF6?style=for-the-badge&labelColor=111318" alt="Version"></a>
  <a href="https://github.com/WorkAccount211/VoidCriptUI_lib-Final-/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-VoidCript_Custom-9CA3AF?style=for-the-badge&labelColor=111318" alt="License"></a>
  <a href="https://github.com/WorkAccount211/VoidCriptUI_lib-Final-/tree/main/examples"><img src="https://img.shields.io/badge/examples-included-22C55E?style=for-the-badge&labelColor=111318" alt="Examples"></a>
  <a href="https://github.com/WorkAccount211/VoidCriptUI_lib-Final-/wiki"><img src="https://img.shields.io/badge/docs-Wiki-38BDF8?style=for-the-badge&labelColor=111318" alt="Documentation"></a>
</p>

[Quick Start](#-quick-start) · [Features](#-features) · [Elements](#-elements) · [Flags](#-flags) · [Configs](#-configs) · [Themes](#-themes) · [Watermark](#-watermark) · [Keylist](#-keylist) · [Plugins](#-plugins) · [API](#-api-reference) · [Documentation](#-documentation)

</div>

---

## About

VoidCriptUI is a modular Luau GUI framework for Roblox scripts that need a polished interface without sacrificing responsiveness.

The project focuses on modern dark visuals, lazy UI creation, adaptive layouts, runtime theming, flags, JSON configuration, keybinds, overlays, notifications, plugins, logging and performance tooling.

**Project identity:** the public-facing author and brand is **VoidCript**.

---

## ✨ Features

| Area | Included |
|---|---|
| UI architecture | Modular Core / Elements / Services / Window layers |
| Lazy loading | Tab contents materialize on first use |
| Animation | TweenService + CanvasGroup based fades |
| Responsive UI | Phone / Tablet / Desktop / Wide profiles |
| Mobile UX | Touch-sized controls + floating toggle |
| Search | Global settings search |
| Window | Resize, minimize, toggle key, saved geometry |
| Elements | Toggle, Slider, RangeSlider, Knob, Dropdown, MultiDropdown, Input, Keybind, ColorPicker, Button, ImageButton, Paragraph, ProgressBar, Image, ListBox, Table, Collapsible |
| State | Global `Flags`, control lookup, subscriptions, dependencies |
| Configuration | JSON, typed values, autosave, migrations, export/import |
| Theme system | Runtime `SetTheme`, presets, editor, scale and fonts |
| Watermark | Player, FPS, ping, memory, time, date, game and custom modules |
| Keylist | Name, mode, key, state, hits, category, last used |
| DX | Logging levels, guarded callbacks, profiler |
| Plugins | Third-party elements, themes, icons and Watermark modules |
| Distribution | Single-file versioned loader + minified loader |

---

## 🚀 Quick Start

The recommended entry point is the single-file loader in the repository root:

```lua
local VoidLib = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/WorkAccount211/VoidCriptUI_lib-Final-/main/VoidCriptUI.lua"
))({
    Version = "main",
    Cache = true,
    Loading = true,
    Cancellable = true,
    Parallel = 6,
    Retries = 2,
})

if not VoidLib then
    return
end

local Window = VoidLib:CreateWindow({
    Name = "My Script",
    Subtitle = "VoidCriptUI",
    ToggleKey = "RightShift",

    ConfigurationSaving = {
        Enabled = true,
        FolderName = "MyScript",
        FileName = "Default",
        AutoSave = true,
    },
})

local Main = Window:CreateTab("Main", "home")
local Section = Main:CreateSection("General")

Section:CreateToggle({
    Name = "Example Toggle",
    Flag = "ExampleToggle",
    Callback = function(value)
        print("ExampleToggle:", value)
    end,
})

Section:CreateSlider({
    Name = "Example Slider",
    Flag = "ExampleSlider",
    Range = {0, 100},
    Increment = 1,
    CurrentValue = 50,
})

print("Toggle:", VoidLib.Flags.ExampleToggle)
print("Slider:", VoidLib.Flags.ExampleSlider)
```

For reproducible deployments, pin a version instead of following `main`:

```lua
local VoidLib = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/WorkAccount211/VoidCriptUI_lib-Final-/v3.0.0/VoidCriptUI.lua"
))()
```

---

## 📦 Loader

`VoidCriptUI.lua` is the public distribution entry point. It downloads the modular library, shows the loading UI, handles retries/fallbacks and can use a local cache when the runtime exposes filesystem functions.

### Loader options

```lua
local VoidLib = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/WorkAccount211/VoidCriptUI_lib-Final-/main/VoidCriptUI.lua"
))({
    Version     = "main",
    Cache       = true,
    Loading     = true,
    Cancellable = true,
    Parallel    = 6,
    Retries     = 2,
    Title       = "VoidCriptUI",
    Subtitle    = "v3.0.0",
    Width       = 390,
    OnProgress  = function(done, total, stage)
        print(("[VoidCript.Loader] %d/%d — %s"):format(done, total, stage))
    end,
    Logger      = true,
})
```

The boot screen is generated by the loader and uses CanvasGroup-based fades. It presents progress, percentage, stage, elapsed time and estimated time remaining.

---

## 🧩 Elements

| Element | Constructor | Main capabilities |
|---|---|---|
| Toggle | `CreateToggle` | Styles, flags, keybind, icon |
| Slider | `CreateSlider` | Numeric editing and callback throttling |
| Range Slider | `CreateRangeSlider` | Two handles for min/max |
| Knob | `CreateKnob` | Circular alternative to a slider |
| Dropdown | `CreateDropdown` | Searchable single selection |
| MultiDropdown | `CreateMultiDropdown` | Checkbox-based multi-selection |
| Input | `CreateInput` | Numeric, max length, pattern and validation |
| Keybind | `CreateKeybind` | Keyboard, mouse buttons, modifiers, modes |
| ColorPicker | `CreateColorPicker` | HEX, alpha, palette and rainbow |
| Button | `CreateButton` | Confirmation / warning flow |
| Image Button | `CreateImageButton` | Icon-focused actions |
| Paragraph | `CreateParagraph` | Rich text and callouts |
| Progress Bar | `CreateProgressBar` | Animated progress display |
| Image | `CreateImage` | Image content and loading presentation |
| ListBox | `CreateListBox` | Selectable rows and add/remove |
| Table | `CreateTable` | Columns, rows, selection and scrolling |
| Collapsible | `CreateCollapsible` | Expandable nested content |

### Common control API

```lua
local control = Section:CreateToggle({
    Name = "Fly",
    Flag = "Fly",
})

print(control:Get())
control:Set(true)

control:OnChanged(function(value)
    print("Changed:", value)
end)

control:SetVisible(true)
control:SetEnabled(true)
control:SetName("Flight")
control:SetTooltip("Enables the flight system.")
control:Destroy()
```

---

## 🎛️ Flags

Flags are the shared state layer of VoidCriptUI.

```lua
Section:CreateToggle({
    Name = "Fly",
    Flag = "Fly_Toggle",
})

Section:CreateSlider({
    Name = "Speed",
    Flag = "Fly_Speed",
    Range = {0, 500},
    CurrentValue = 100,
})
```

Read from anywhere:

```lua
if VoidLib.Flags["Fly_Toggle"] then
    print("Speed:", VoidLib.Flags["Fly_Speed"])
end
```

Equivalent accessors:

```lua
VoidLib:GetFlag("Fly_Toggle")
VoidLib:GetControl("Fly_Toggle"):Get()
```

Change values:

```lua
VoidLib:SetFlag("Fly_Toggle", true)
VoidLib:SetFlag("Fly_Speed", 250)
```

Subscribe:

```lua
VoidLib:OnFlagChanged("Fly_Toggle", function(value)
    print("Fly changed:", value)
end)

VoidLib:OnFlagChanged("*", function(flag, value)
    print(flag, value)
end)
```

Strict development validation:

```lua
VoidLib:SetStrictFlags(true)
```

---

## 🔗 Conditional visibility

```lua
Section:CreateToggle({
    Name = "ESP",
    Flag = "ESP",
})

Section:CreateSlider({
    Name = "Distance",
    Flag = "ESP_Distance",
    DependsOn = "ESP",
    Range = {0, 1000},
})
```

Complex predicates are also supported:

```lua
Section:CreateKnob({
    Name = "FOV",
    Flag = "FOV",
    DependsOn = function(flags)
        return flags.ESP and flags.ESP_Distance > 100
    end,
})
```

Dependencies are event-driven instead of being evaluated every frame.

---

## 💾 Configs

```lua
VoidLib:SaveConfig("Default")
VoidLib:LoadConfig("Default")

local configs = VoidLib:ListConfigs()

VoidLib:RenameConfig("Default", "PvP")
VoidLib:DeleteConfig("PvP")
```

Share configuration as a string:

```lua
local code = VoidLib:ExportConfig()
VoidLib:ImportConfig(code, "Imported")
```

Configuration can preserve typed values and library state such as flags, UI geometry, active tab, theme tokens, scale and keybind descriptors, subject to the active configuration settings.

---

## 🎨 Themes

```lua
VoidLib:SetTheme({
    Accent = Color3.fromRGB(100, 0, 255),
    Background = Color3.fromRGB(20, 20, 20),
    Text = Color3.fromRGB(255, 255, 255),
})
```

Built-in presets:

```lua
VoidLib:SetThemePreset("Midnight")
VoidLib:SetThemePreset("Blood")
VoidLib:SetThemePreset("Ocean")
VoidLib:SetThemePreset("Mono")
VoidLib:SetThemePreset("Toxic")
VoidLib:SetThemePreset("Amethyst")
VoidLib:SetThemePreset("Light")
```

Custom theme:

```lua
VoidLib:RegisterTheme("MyTheme", {
    Accent = Color3.fromRGB(145, 80, 255),
    Background = Color3.fromRGB(15, 16, 22),
    Text = Color3.fromRGB(245, 245, 250),
})

VoidLib:SetThemePreset("MyTheme")
```

---

## 📱 Mobile and responsive UI

VoidCriptUI uses adaptive sizing and device profiles rather than a single fixed desktop layout.

```lua
VoidLib:SetScale(0.95)
VoidLib:SetCompact(true)

print("Device:", VoidLib:GetDevice())
print("Mobile:", VoidLib:IsMobile())
```

Profiles include:

```text
Phone
Tablet
Desktop
Wide
```

Mobile-specific behaviour includes larger touch targets, a floating toggle bubble, compact mode and viewport-aware layouts.

---

## 🏷️ Watermark

The Watermark is a native runtime UI component and is not merely a screenshot placed over the game.

<img src="https://raw.githubusercontent.com/WorkAccount211/VoidCriptUI_lib-Final-/main/images/Watermark.png" width="900" alt="VoidCriptUI Watermark">

### Basic usage

```lua
local Watermark = VoidLib:Watermark({
    Position = "TopRight",
    Title = "My Script",

    Modules = {
        "logo",
        "title",
        "version",
        "user",
        "fps",
        "fps1",
        "ping",
        "memory",
        "time",
    },

    Draggable = true,
    Visible = true,
})
```

### Player name

The `user` module resolves the current Roblox player at runtime:

```lua
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local playerName = player and player.Name or "Player"
print(playerName)
```

No username is hard-coded into the Watermark.

### Built-in modules

```text
logo
 title
 version
 user
displayname
 fps
 fps1
 frametime
 ping
 memory
 time
 date
 game
 instances
```

### Custom Watermark modules

```lua
VoidLib:RegisterWatermarkModule(
    "hp",
    function()
        local player = game:GetService("Players").LocalPlayer
        local character = player and player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")

        if not humanoid then
            return nil
        end

        return ("HP %d"):format(math.floor(humanoid.Health))
    end,
    {
        Interval = 0.5,
    }
)
```

Then include it:

```lua
VoidLib:Watermark({
    Modules = {
        "logo",
        "title",
        "user",
        "fps",
        "ping",
        "hp",
    },
})
```

---

## ⌨️ Keylist

```lua
VoidLib:Keylist({
    Title = "Keybinds",
    Columns = {
        "Name",
        "Mode",
        "Key",
        "State",
        "Hits",
        "Category",
        "LastUsed",
    },
    Position = "LeftCenter",
    HideEmpty = true,
    OnlyActive = false,
    Draggable = true,
})
```

The Keylist is designed to display more than a key label:

```text
Name
Mode
Key
State
Hits
Category
LastUsed
```

Supported modes include `Always`, `Toggle` and `Hold`.

---

## 🔔 Notifications and dialogs

```lua
VoidLib:Notify({
    Title = "VoidCriptUI",
    Content = "Settings saved successfully.",
    Duration = 3,
})
```

Confirmation flow:

```lua
VoidLib:Dialog({
    Title = "Confirm action",
    Content = "Are you sure you want to continue?",
})
```

---

## 🧰 Logging and debugging

```lua
VoidLib:SetLogLevel("Debug")
```

Levels:

```text
Off
Error
Warning
Info
Debug
```

Read and clear logs:

```lua
local logs = VoidLib:GetLogs()
VoidLib:ClearLogs()
```

Guard callbacks:

```lua
VoidLib:Guard("MyFeature", function()
    error("test error")
end)
```

The guarded callback model prevents a user callback exception from automatically destroying the entire UI flow.

---

## 🧩 Plugins

Plugins can add behaviour without editing the library core.

```lua
VoidLib:RegisterPlugin({
    Name = "MyPlugin",
    Version = "1.0.0",

    Icons = {
        spark = "✦",
    },

    Themes = {
        Neon = {
            Accent = Color3.fromRGB(0, 255, 210),
        },
    },

    WatermarkModules = {
        status = function()
            return "ONLINE"
        end,
    },
})
```

The plugin architecture can provide custom elements, icons, themes, Watermark modules and lifecycle hooks.

---

## ⚡ Performance design

VoidCriptUI is structured around low-overhead updates.

### Lazy tabs

```text
Create tab
    ↓
Create lightweight handles
    ↓
User opens tab
    ↓
Materialize controls
```

### CanvasGroup fades

Window-level fades use:

```lua
CanvasGroup.GroupTransparency
```

rather than updating every descendant separately.

### Slider callback throttling

```lua
Section:CreateSlider({
    Name = "Heavy Feature",
    Flag = "Heavy",
    Range = {0, 100},
    CallbackOnRelease = true,
    Callback = function(value)
        -- expensive work
    end,
})
```

### Profiling

```lua
local profile = VoidLib:GetProfile()
local metrics = VoidLib:GetMetrics()
```

Use these APIs to inspect runtime information exposed by the built-in profiler.

---

## 📝 Rich text

Supported rich-text syntax depends on the active component/parser, with the project documentation covering the supported markdown-like forms.

Examples:

```text
**bold**
*italic*
__underline__
~~strike~~
`inline code`
> quote
- bullet
```

---

## 📚 API reference

### Window

```lua
local Window = VoidLib:CreateWindow({
    Name = "My Script",
    Subtitle = "v1.0",
    ToggleKey = "RightShift",
    LazyLoading = true,
    Resizable = true,
    MinimiseStyle = "Icon",
})
```

Common methods include:

```text
CreateTab
SelectTab
GetTabs
GetActiveTab
Show
Hide
Toggle
IsVisible
Minimise
Restore
ToggleMinimise
SetTitle
SetSubtitle
SetToggleKey
GetToggleKey
SaveConfiguration
LoadConfiguration
OpenInterfaceTab
Destroy
```

### Library

```text
GetFlag
SetFlag
HasFlag
GetControl
OnFlagChanged
ListFlags
SnapshotFlags
SetStrictFlags

SetTheme
SetThemePreset
RegisterTheme
ListThemes
GetTheme

SetScale
SetCompact
GetDevice
IsMobile

Notify
NotifyProgress
Dialog
Prompt
Choice

Watermark
RegisterWatermarkModule
Keylist

SaveConfig
LoadConfig
ListConfigs
DeleteConfig
RenameConfig
ExportConfig
ImportConfig
SetAutoSave

SetLogLevel
GetLogLevel
GetLogs
ClearLogs
Guard
GetProfile
GetProfileString
GetMetrics

RegisterPlugin
UnregisterPlugin
ListPlugins
Boot
Unload
ClearLoaderCache
```

For the complete API surface, use the [official Wiki](https://github.com/WorkAccount211/VoidCriptUI_lib-Final-/wiki).

---

## 📁 Project structure

```text
VoidCriptUI_lib-Final-/
│
├── VoidCriptUI.lua              # public full loader
├── VoidCriptUI.min.lua           # compact loader
├── README.md
├── LICENSE
├── .gitignore
│
├── images/
│   ├── banner.png
│   ├── icon.png
│   └── Watermark.png
│
├── VoidCriptUI-LIB/
│   ├── Core/
│   ├── Elements/
│   ├── Services/
│   ├── Components/
│   ├── Window/
│   └── init.lua
│
├── examples/
│   ├── basic.lua
│   ├── BaseExample.lua
│   ├── advanced.lua
│   └── theming.lua
│
└── wiki/
    └── Wiki source Markdown files
```

---

## 🧪 Examples

| File | Purpose |
|---|---|
| `examples/basic.lua` | Smallest practical starting point |
| `examples/BaseExample.lua` | Broad element showcase |
| `examples/advanced.lua` | Advanced composition and extension examples |
| `examples/theming.lua` | Themes, presets, scaling and customization |

---

## 🗺️ Roadmap

The project includes the selected Roadmap scope from the VoidCript specification, covering the requested UI controls, adaptive behaviour, configuration, runtime themes, lifecycle APIs, validation, Watermark, Keylist and versioned loader work.

The full roadmap source is kept in:

```text
VoidCript_RoadMap.txt
```

---

## ⚠️ Compatibility

VoidCriptUI targets the Roblox/Luau runtime and uses services and APIs available in that environment.

Optional filesystem-backed caching depends on the runtime exposing compatible filesystem functions. Exact behaviour can also vary with Roblox changes and third-party execution environments.

Test the exact release you deploy.

---

## 📄 License

VoidCriptUI is distributed under the **VoidCript Community Software License, Version 1.0**.

The complete license is maintained in the repository:

**[Read the VoidCript License](https://github.com/WorkAccount211/VoidCriptUI_lib-Final-/blob/main/LICENSE)**

---

## 💜 Credits

<div align="center">

**Built by VoidCript**

Independent modular Roblox/Luau UI project focused on visual quality, extensibility, responsiveness and predictable runtime behaviour.

</div>
