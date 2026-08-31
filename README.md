<div align="center">

<img src="https://raw.githubusercontent.com/WorkAccount211/VoidCriptUI_lib-Final-/refs/heads/main/images/symbol.png" width="110" alt="VoidCriptUI">

# VoidCriptUI

**A modern, modular Roblox/Luau GUI library built by VoidCript.**

CompKiller-inspired visual polish · Weave-inspired ergonomics · lazy loading · adaptive UI · runtime themes · flags · JSON configs · plugins

[![Version](https://img.shields.io/badge/version-3.0.0-C73E6E?style=for-the-badge)](https://github.com/WorkAccount211/VoidCriptUI_lib-Final-/releases)
[![Luau](https://img.shields.io/badge/Luau-5.1%2B-blue?style=for-the-badge)](https://luau-lang.org/)
[![Mobile](https://img.shields.io/badge/Mobile-Supported-50C878?style=for-the-badge)](#mobile--responsive-ui)
[![License](https://img.shields.io/badge/License-MIT-lightgrey?style=for-the-badge)](LICENSE)

[Quick Start](#quick-start) · [Features](#features) · [API](#api-reference) · [Examples](#examples) · [Wiki](../../wiki)

</div>

---

## Overview

VoidCriptUI is a modular GUI library for Roblox/Luau scripts. It is designed to keep the public API small while providing a large feature set: adaptive layouts, lazy-built tabs, live theming, flags, JSON configuration management, keybinds, notifications, tooltips, watermark/keybind overlays, plugin hooks and a versioned single-file loader.

The repository contains the loader, modular source, examples, images and documentation sources. The loader is the intended distribution entry point; users do not need to manually require individual library modules.

> **Runtime note:** compatibility depends on the Roblox runtime/executor environment and the APIs it exposes. Repository/static checks do not replace a real Roblox runtime test.

---

## Features

| Area | Included |
|---|---|
| UI architecture | Modular source, lazy tabs, reusable controls, sections and overlays |
| Performance | CanvasGroup fades, shared input routing, throttled callbacks, pooled/list rendering where applicable |
| Responsive UI | Phone, tablet, desktop and wide-screen profiles; compact mode; touch hit-target scaling |
| Navigation | Global search, active-tab indicator, minimise/restore, resize, mobile bubble |
| Controls | Toggle, Slider, RangeSlider, Knob, Dropdown, MultiDropdown, Input, Keybind, ColorPicker, Button, ImageButton |
| Display | Label, Paragraph, Divider, ProgressBar, Image, ListBox, Table, Collapsible sections |
| State | Flags, `DependsOn`, visibility/enabled state, change signals, strict flag diagnostics |
| Configs | JSON, typed values, autosave, per-game profiles, rename/delete/list, import/export, migrations |
| Themes | Runtime `SetTheme`, presets, theme editor, custom fonts, scale controls |
| Input | Keyboard modifiers, MB1/MB2/MB3, Toggle/Hold/Always modes, game input lock |
| Feedback | Notifications, progress notifications, confirm/prompt/choice dialogs, delayed tooltips |
| DX | Log levels, guarded callbacks, ring-buffer logs, performance profiler |
| Extensibility | Third-party plugins, custom elements, icons, themes and watermark modules |
| Overlays | Configurable Watermark, FPS/Ping telemetry, extended Keybind List |
| Distribution | Versioned loader, bounded parallel download, retries, jsDelivr fallback, local cache, cancellation |

---

## Quick Start

The simplest supported installation is a single `loadstring` call:

```lua
local VoidLib = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/WorkAccount211/VoidCriptUI_lib-Final-/main/VoidCriptUI.lua"
))()

local Window = VoidLib:CreateWindow({
    Name = "My Script",
    Subtitle = "VoidCriptUI demo",
    ToggleKey = "RightShift",
})

local Tab = Window:CreateTab("Main", "home")
local Section = Tab:CreateSection("Example")

Section:CreateToggle({
    Name = "Enabled",
    Flag = "Enabled",
    Default = false,
    Callback = function(value)
        print("Enabled:", value)
    end,
})

Section:CreateSlider({
    Name = "Amount",
    Flag = "Amount",
    Range = {0, 100},
    Increment = 1,
    CurrentValue = 50,
})
```

For production scripts, pin a version tag instead of tracking `main`:

```lua
local VoidLib = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/WorkAccount211/VoidCriptUI_lib-Final-/v3.0.0/VoidCriptUI.lua"
))()
```

---

## Loader

`VoidCriptUI.lua` is the main single-file distribution loader. It downloads the modular library, displays a loading UI, caches sources when supported, retries failed downloads and falls back to jsDelivr.

### Loader configuration

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
    Title = "VoidCriptUI",
    Subtitle = "v3.0.0",
    OnProgress = function(done, total, stage)
        print(("[%d/%d] %s"):format(done, total, stage))
    end,
})

if not VoidLib then
    return -- cancelled or failed to load
end
```

### Loader options

| Option | Type | Default | Description |
|---|---|---:|---|
| `Version` | string | `"main"` | Branch, tag or commit SHA |
| `Cache` | boolean | `true` | Cache downloaded sources when filesystem APIs exist |
| `Loading` | boolean | `true` | Show the boot/loading UI |
| `Cancellable` | boolean | `true` | Show the Cancel button |
| `Parallel` | number | `6` | Maximum concurrent module downloads |
| `Retries` | number | `2` | Retries per source before CDN fallback |
| `Title` | string | `"voidcript"` | Loader title |
| `Subtitle` | string | library version | Loader subtitle |
| `Logo` | string | built-in logo | Override loader image |
| `OnProgress` | function | `nil` | `function(done, total, stage)` |
| `Logger` | boolean | `false` | Print loader diagnostics |

### Loader diagnostics

```lua
local info = VoidLib:GetLoaderInfo()

print(info.Version)
print(info.LibraryVersion)
print(info.CachePath)
print(info.CachedSources)
print(info.Modules)
print(info.LoadedIn)

VoidLib:ClearLoaderCache()
```

---

## Creating Windows, Tabs and Sections

```lua
local Window = VoidLib:CreateWindow({
    Name = "VoidCript",
    Subtitle = "Control Panel",
    ToggleKey = "RightShift",
    LazyLoading = true,
    Resizable = true,
    MinimiseStyle = "Icon", -- Icon | MiniBar
})

local Combat = Window:CreateTab("Combat", "sword")
local Aim = Combat:CreateSection({
    Name = "Aim Assist",
    Side = "left",
})

Aim:CreateToggle({
    Name = "Enabled",
    Flag = "Aim.Enabled",
})
```

Sections may also be attached to subtabs and can be cleared or destroyed at runtime:

```lua
Aim:SetVisible(false)
Aim:Clear()
Aim:Destroy()
```

---

## Elements

### Toggle

```lua
local Toggle = Section:CreateToggle({
    Name = "Fly",
    Flag = "Fly.Enabled",
    Default = false,
    Callback = function(value)
        print("Fly:", value)
    end,
})

Toggle:Set(true)
print(Toggle:Get())
```

### Slider

```lua
Section:CreateSlider({
    Name = "Speed",
    Flag = "Fly.Speed",
    Range = {0, 500},
    Increment = 1,
    CurrentValue = 100,
    CallbackOnRelease = true,
    Callback = function(value)
        print("Speed:", value)
    end,
})
```

The value can also be edited numerically through the slider's value field.

### Range Slider

```lua
Section:CreateRangeSlider({
    Name = "Distance",
    Flag = "Distance",
    Range = {0, 1000},
    CurrentMin = 100,
    CurrentMax = 500,
    Increment = 10,
})
```

### Knob / Dial

```lua
Section:CreateKnob({
    Name = "FOV",
    Flag = "FOV",
    Range = {30, 180},
    CurrentValue = 90,
    Increment = 1,
})
```

### Dropdown / MultiDropdown

```lua
Section:CreateDropdown({
    Name = "Mode",
    Flag = "Mode",
    Options = {"Legit", "Rage", "Custom"},
    SearchBox = true,
})

Section:CreateMultiDropdown({
    Name = "Features",
    Flag = "Features",
    Options = {"ESP", "Tracers", "Boxes", "Names"},
    Max = 4,
})
```

### Input

```lua
Section:CreateInput({
    Name = "Username",
    Flag = "Username",
    PlaceholderText = "Enter a name",
    MaxLength = 32,
    Pattern = "^[%w_]+$",
})
```

### Keybind

```lua
Section:CreateKeybind({
    Name = "Aimbot",
    Flag = "Aimbot.Key",
    Key = "MB2",
    Mode = "Hold", -- Always | Toggle | Hold
})
```

Modifiers are supported:

```lua
Key = "Ctrl+Shift+K"
```

Mouse buttons are supported as `MB1`, `MB2` and `MB3` where the runtime exposes them.

### ColorPicker

```lua
Section:CreateColorPicker({
    Name = "ESP Color",
    Flag = "ESP.Color",
    Default = Color3.fromRGB(100, 0, 255),
    Alpha = 0.9,
    Rainbow = false,
})
```

HEX values can be entered manually; palettes and rainbow mode are also supported.

### Buttons and confirmation dialogs

```lua
Section:CreateButton({
    Name = "Reset Everything",
    Risky = true,
    Callback = function()
        print("reset confirmed")
    end,
})
```

### Rich text paragraph

```lua
Section:CreateParagraph({
    Title = "About",
    Content = [[
**VoidCriptUI** supports *rich text*, `inline code`,
> quotes
and ```code blocks```.
]],
})
```

### ListBox / Table

```lua
Section:CreateListBox({
    Name = "Players",
    Flag = "SelectedPlayer",
    Items = {"Alice", "Bob", "Charlie"},
    MultiSelect = false,
})

Section:CreateTable({
    Name = "Statistics",
    Columns = {"Player", "Kills", "Deaths"},
    Rows = {
        {"Alice", 12, 4},
        {"Bob", 7, 8},
    },
    Selectable = true,
})
```

---

## Flags and State

Flags are the library-wide state layer. A control with a `Flag` becomes readable and writable from any part of the script.

```lua
Section:CreateToggle({
    Name = "Fly",
    Flag = "Fly.Enabled",
})

Section:CreateSlider({
    Name = "Fly Speed",
    Flag = "Fly.Speed",
    Range = {0, 500},
    Increment = 1,
})

if VoidLib.Flags["Fly.Enabled"] then
    print("Fly speed:", VoidLib.Flags["Fly.Speed"])
end

VoidLib:SetFlag("Fly.Enabled", true)
local speed = VoidLib:GetFlag("Fly.Speed", 100)
```

### Flag events

```lua
VoidLib:OnFlagChanged("Fly.Enabled", function(value)
    print("Fly changed:", value)
end)

VoidLib:OnFlagChanged("*", function(flag, value)
    print("Changed:", flag, value)
end)
```

### Conditional visibility

```lua
Section:CreateToggle({
    Name = "ESP",
    Flag = "ESP.Enabled",
})

Section:CreateSlider({
    Name = "ESP Distance",
    Flag = "ESP.Distance",
    Range = {0, 2000},
    DependsOn = "ESP.Enabled",
})
```

`DependsOn` is evaluated from flag changes rather than from a per-frame polling loop.

---

## Configs

The configuration layer supports JSON, typed values, autosave, migrations and optional per-game profiles.

```lua
VoidLib:SaveConfig("Default")
VoidLib:LoadConfig("Default")
VoidLib:ListConfigs()
VoidLib:RenameConfig("Default", "PvP")
VoidLib:DeleteConfig("PvP")
```

Import/export allows configs to be shared as strings:

```lua
local code = VoidLib:ExportConfig()
print(code)

VoidLib:ImportConfig(code, "Shared")
```

Enable autosave in the window configuration:

```lua
local Window = VoidLib:CreateWindow({
    Name = "My Script",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "MyScript",
        FileName = "Default",
        AutoSave = true,
        AutoSaveDelay = 1,
        PerGame = true,
    },
})
```

Persistence depends on filesystem APIs supplied by the runtime. Without them, the library can still run, but file-backed config persistence is unavailable.

---

## Themes

Themes are live: token changes repaint registered instances without rebuilding the window.

```lua
VoidLib:SetTheme({
    Accent = Color3.fromRGB(100, 0, 255),
    Background = Color3.fromRGB(20, 20, 20),
    Text = Color3.fromRGB(255, 255, 255),
})

VoidLib:SetThemePreset("Ocean")
VoidLib:RegisterTheme("Sunset", {
    Accent = "#FF6B4A",
    Background = "#14100F",
})
```

Built-in presets include:

```text
Midnight
Blood
Ocean
Mono
Toxic
Amethyst
Light
```

The Appearance interface also exposes theme editing, font selection and UI scaling.

### Blur / glass note

The production backdrop uses deep dimming, vignette, gradients and glass-like UI primitives. It deliberately does not claim to implement a framebuffer blur through `EditableImage`; the Roblox API does not expose a generic “capture the game framebuffer behind this ScreenGui and blur it” primitive. The shipped implementation therefore prioritises a low-overhead visual effect over a misleading or expensive pseudo-blur implementation.

---

## Mobile & Responsive UI

VoidCriptUI is designed around multiple viewport profiles instead of one fixed desktop layout:

| Profile | Behaviour |
|---|---|
| Phone | One-column content, enlarged touch targets, floating bubble |
| Tablet | Two-column content where space allows, touch-friendly hitboxes |
| Desktop | Full controls, resize handle, keyboard toggle |
| Wide | Additional horizontal space, expanded layout |

A compact mode reduces spacing on small screens. The mobile floating bubble replaces the need for a keyboard toggle on touch devices.

---

## Watermark

The watermark is modular and configurable.

```lua
VoidLib:Watermark({
    Title = "My Script",
    Position = "TopRight",
    Draggable = true,
    Modules = {
        "logo",
        "title",
        "user",
        "fps",
        "frametime",
        "ping",
        "memory",
        "time",
    },
})
```

Custom modules can be registered:

```lua
VoidLib:RegisterWatermarkModule("health", function()
    local player = game:GetService("Players").LocalPlayer
    local character = player and player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")

    return humanoid and ("HP %d"):format(humanoid.Health) or nil
end, {
    Interval = 0.5,
})
```

---

## Keybind List

```lua
VoidLib:Keylist({
    Title = "Active Keybinds",
    Position = "LeftCenter",
    Columns = {
        "Name",
        "Mode",
        "Key",
        "State",
        "Hits",
        "Category",
        "LastUsed",
    },
    HideEmpty = true,
    OnlyActive = false,
    Draggable = true,
})
```

The keybind list can display the function name, binding mode, resolved key, active state, activation count, category and last-use information.

---

## Logging & Debugging

```lua
VoidLib:SetLogLevel("Debug")

local entries = VoidLib:GetLogs()
VoidLib:ClearLogs()
```

Supported levels:

```text
Off
Error
Warning
Info
Debug
```

Callbacks are guarded so an exception in a user callback can be logged without tearing down the whole UI.

```lua
VoidLib:Guard("My operation", function()
    -- code that should be isolated from UI failure
end)
```

The runtime console / F9 is the primary low-level debugging surface; the Interface tab also exposes the recorded log history where supported by the build.

---

## Plugins

Plugins extend the library without modifying its core source.

```lua
VoidLib:RegisterPlugin({
    Name = "MyWidgets",
    Version = "1.0.0",

    Icons = {
        spark = "✦",
    },

    Themes = {
        Neon = {
            Accent = "#00FFD0",
        },
    },

    WatermarkModules = {
        status = function()
            return "READY"
        end,
    },

    OnWindow = function(window)
        -- optional hook
    end,

    OnUnload = function(lib)
        -- optional cleanup
    end,
})
```

The plugin system is intended for custom elements, icons, themes and lifecycle hooks.

---

## API Reference

### Window

```lua
Window:CreateTab(name, icon, subtabs)
Window:SelectTab(tab)
Window:GetTabs()
Window:GetActiveTab()

Window:Show()
Window:Hide()
Window:Toggle()
Window:IsVisible()

Window:Minimise()
Window:Restore()
Window:ToggleMinimise()

Window:SetTitle(text)
Window:SetSubtitle(text)
Window:SetToggleKey(key)
Window:GetToggleKey()

Window:SaveConfiguration()
Window:LoadConfiguration()
Window:OpenInterfaceTab()
Window:Destroy()
```

### Library

```lua
-- Flags
VoidLib:GetFlag(flag, default)
VoidLib:SetFlag(flag, value, silent)
VoidLib:HasFlag(flag)
VoidLib:GetControl(flag)
VoidLib:OnFlagChanged(flag, callback)
VoidLib:ListFlags()
VoidLib:SnapshotFlags()
VoidLib:SetStrictFlags(enabled)

-- Themes
VoidLib:SetTheme(tokens, instant)
VoidLib:SetThemePreset(name)
VoidLib:RegisterTheme(name, tokens)
VoidLib:ListThemes()
VoidLib:GetTheme()

-- Scale
VoidLib:SetScale(value)
VoidLib:SetCompact(enabled)
VoidLib:GetDevice()
VoidLib:IsMobile()
VoidLib:SetSliderStyle(style)

-- Feedback
VoidLib:Notify(config)
VoidLib:NotifyProgress(config)
VoidLib:Dialog(config)
VoidLib:Prompt(config)
VoidLib:Choice(config)

-- Overlays
VoidLib:Watermark(config)
VoidLib:RegisterWatermarkModule(name, callback, options)
VoidLib:Keylist(config)

-- Configs
VoidLib:SaveConfig(name)
VoidLib:LoadConfig(name)
VoidLib:ListConfigs()
VoidLib:DeleteConfig(name)
VoidLib:RenameConfig(oldName, newName)
VoidLib:ExportConfig()
VoidLib:ImportConfig(code, name)
VoidLib:SetAutoSave(enabled, delay)

-- Logging / profiling
VoidLib:SetLogLevel(level)
VoidLib:GetLogLevel()
VoidLib:GetLogs(limit)
VoidLib:ClearLogs()
VoidLib:Guard(context, callback, ...)
VoidLib:GetProfile()
VoidLib:GetProfileString()
VoidLib:GetMetrics()

-- Plugins / lifecycle
VoidLib:RegisterPlugin(plugin)
VoidLib:UnregisterPlugin(name)
VoidLib:ListPlugins()
VoidLib:Unload()
VoidLib:ClearLoaderCache()
VoidLib:GetLoaderInfo()
```

> The exact available constructor fields are the source of truth for the release. See the Wiki/API Reference for the full option-by-option list and examples.

---

## Project Structure

```text
VoidCriptUI_lib-Final-/
│
├─ VoidCriptUI.lua              # main versioned loader
├─ VoidCriptUI.min.lua           # minified loader
├─ README.md                     # this file
├─ LICENSE                       # project license
├─ .gitignore
│
├─ VoidCriptUI-LIB/
│  ├─ init.lua
│  ├─ Core/
│  ├─ Elements/
│  ├─ Services/
│  ├─ Components/
│  └─ Window/
│
├─ examples/
│  ├─ basic.lua
│  ├─ BaseExample.lua
│  ├─ advanced.lua
│  └─ theming.lua
│
├─ images/
│  ├─ symbol.png
│  └─ Watermark.png
│
└─ wiki/                        # Markdown sources prepared for GitHub Wiki
```

---

## Examples

| File | Purpose |
|---|---|
| [`basic.lua`](examples/basic.lua) | Minimal first GUI |
| [`BaseExample.lua`](examples/BaseExample.lua) | Broad element showcase and options |
| [`advanced.lua`](examples/advanced.lua) | Advanced multi-feature example |
| [`theming.lua`](examples/theming.lua) | Themes, fonts, scaling and customisation |

Start with `basic.lua`, then use `BaseExample.lua` as the reference while building your own script.

---

## Documentation

Full documentation is intended to live in the GitHub Wiki:

```text
Home
Getting Started
Elements
Flags & State
Configs
Theming
Mobile & Scaling
Logging & Debugging
Plugins
Performance
API Reference
FAQ
Loader
```

The repository's `wiki/` directory contains the prepared Markdown sources used to publish that documentation.

---

## Roadmap / Release Scope

### Included in v3.0.0

The selected Roadmap scope includes range sliders, keyboard-editable slider values, advanced keybinds, combined control rows, HEX/rainbow color controls, progress bars, images, tables, global search, resize/minimise, saved window state, mobile support, custom cursor/input lock, config manager, runtime themes, presets/editor/fonts/scale, idempotent unload, destroy/clear, `DependsOn`, validation, connection cleanup, slider throttling, guarded callbacks, window visibility signals, extended watermark, keybind list and the versioned/minified loader.

### Not part of this selected scope

The original 45-item Roadmap also contains ideas that were not selected in the original specification, including free drag-and-drop tab ordering, pinned favourites, cloud configs, strict type exports, standalone unit-test infrastructure and CI. They should not be described as shipped unless they are added explicitly in a later release.

---

## Versioning

Use the moving `main` entry point for development:

```lua
loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/WorkAccount211/VoidCriptUI_lib-Final-/main/VoidCriptUI.lua"
))()
```

Use a tag for reproducible production deployments:

```lua
loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/WorkAccount211/VoidCriptUI_lib-Final-/v3.0.0/VoidCriptUI.lua"
))()
```

The same tag can be used in the loader's `Version` option to pin internal module downloads.

---

## Repository & Links

```text
Repository:
https://github.com/WorkAccount211/VoidCriptUI_lib-Final-

Raw loader:
https://raw.githubusercontent.com/WorkAccount211/VoidCriptUI_lib-Final-/main/VoidCriptUI.lua

Wiki:
https://github.com/WorkAccount211/VoidCriptUI_lib-Final-/wiki
```

---

<div align="center">

**Built by VoidCript.**

A modular UI library focused on visual polish, responsive UX and predictable runtime behaviour.

<sub>Design language inspired by the visual direction of CompKiller and the ergonomics of Weave; implementation in this repository is maintained as VoidCriptUI.</sub>

</div>
