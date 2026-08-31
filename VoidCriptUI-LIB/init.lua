--[[
	════════════════════════════════════════════════════════════════════════
	VoidCriptUI · init.lua
	Assembles every module into the public `Library` table.
	════════════════════════════════════════════════════════════════════════

	This file is what `VoidCriptUI.lua` (the loader) ends up returning. It can
	also be required directly if you vendor the library into your own project.

	Dependency order is explicit and acyclic — each module receives the shared
	`Void` namespace and only touches modules loaded before it:

		Logger → Signal → Maid → Util → Icons → Theme → Scale → Profiler
		→ RichText → Flags → Dependencies → Keybinds → Control → Search
		→ Config → Plugins
		→ Backdrop → Tooltip → Notify → Dialog → Cursor → InterfaceSettings
		→ Common → Elements/*
		→ Boot → Watermark → Keylist → MobileToggle → KeySystem
		→ Host → Section → Tab → Window → InterfaceTab

	Nothing reaches "backwards", so the graph can be unit-tested module by
	module and there is no circular-require hazard.
]]

local Void = {
	Version = "3.0.0",
	Windows = {},
	Elements = {},
}

-- ══════════════════════════════════════════════════════════════════════════
-- MODULE LOADING
-- ══════════════════════════════════════════════════════════════════════════
-- When the library is loaded through the GitHub loader, `VOIDCRIPT_MODULES`
-- holds every already-fetched module source keyed by relative path. When it is
-- used from a local file tree, we fall back to `require`.
local sources = rawget(_G, "VOIDCRIPT_MODULES") or (getgenv and getgenv().VOIDCRIPT_MODULES) or nil

local ORDER = {
	"Core/Logger",
	"Core/Signal",
	"Core/Maid",
	"Core/Util",
	"Core/Icons",
	"Core/Theme",
	"Core/Scale",
	"Core/Profiler",
	"Core/RichText",
	"Core/Flags",
	"Core/Dependencies",
	"Core/Keybinds",
	"Core/Control",
	"Core/Search",
	"Core/Config",
	"Core/Plugins",
	"Services/Backdrop",
	"Services/Tooltip",
	"Services/Notify",
	"Services/Dialog",
	"Services/Cursor",
	"Core/InterfaceSettings",
	"Elements/Common",
	"Elements/Toggle",
	"Elements/Slider",
	"Elements/Knob",
	"Elements/Dropdown",
	"Elements/Input",
	"Elements/Keybind",
	"Elements/ColorPicker",
	"Elements/Button",
	"Elements/Display",
	"Elements/ListBox",
	"Components/Boot",
	"Components/Watermark",
	"Components/Keylist",
	"Components/MobileToggle",
	"Components/KeySystem",
	"Window/Host",
	"Window/Section",
	"Window/Tab",
	"Window/Window",
	"Window/InterfaceTab",
}

local function loadModule(path)
	local factory

	if sources and sources[path] then
		local chunk, err = loadstring(sources[path], "@VoidCriptUI/" .. path .. ".lua")
		if not chunk then
			error(("[VoidCript] could not compile module '%s': %s"):format(path, tostring(err)), 0)
		end
		factory = chunk()
	else
		local ok, result = pcall(function()
			local segments = {}
			for segment in path:gmatch("[^/]+") do segments[#segments + 1] = segment end
			local module = script
			for _, segment in ipairs(segments) do
				module = module:WaitForChild(segment)
			end
			return require(module)
		end)
		if not ok then
			error(("[VoidCript] could not load module '%s': %s"):format(path, tostring(result)), 0)
		end
		factory = result
	end

	if type(factory) ~= "function" then
		error(("[VoidCript] module '%s' must return a function(Void)"):format(path), 0)
	end
	factory(Void)
end

for _, path in ipairs(ORDER) do
	loadModule(path)
end

local Util, Theme, Scale, Log = Void.Util, Void.Theme, Void.Scale, Void.Log

-- ══════════════════════════════════════════════════════════════════════════
-- PUBLIC LIBRARY
-- ══════════════════════════════════════════════════════════════════════════
local Library = {
	Version = Void.Version,
	Void = Void,          -- escape hatch for advanced users / plugin authors

	-- direct access to subsystems
	Theme = Theme,
	Scale = Scale,
	Log = Log,
	Icons = Void.Icons,
	Tooltip = Void.Tooltip,
	Cursor = Void.Cursor,
	Keybinds = Void.Keybinds,
	Config = Void.Config,
	Profiler = Void.Profiler,
	Plugins = Void.Plugins,
	Search = Void.Search,
	RichText = Void.RichText,
	Windows = Void.Windows,
	Signal = Void.Signal,
	Maid = Void.Maid,
	Util = Util,
}
Void.Library = Library

-- ── callable module proxies ────────────────────────────────────────────────
-- Four subsystems are useful both as a shorthand method and as a module:
--
--     VoidLib:Notify({ ... })            -- the common case
--     VoidLib.Notify:SetPosition("…")    -- the full module API
--     VoidLib.Notify.Max = 4             -- and its fields
--
-- A plain function cannot do both, so these are proxy tables: __call forwards
-- to the shorthand, __index forwards method lookups to the real module (bound
-- correctly, so `self` is the module and never the proxy), and __newindex
-- writes straight through.
local function callableModule(module, invoke)
	local proxy = {}
	return setmetatable(proxy, {
		__index = function(_, key)
			local value = module[key]
			if type(value) == "function" then
				return function(first, ...)
					-- `proxy:Method(a)` → rebind self to the module
					if rawequal(first, proxy) then
						return value(module, ...)
					end
					return value(first, ...)
				end
			end
			return value
		end,
		__newindex = function(_, key, value)
			module[key] = value
		end,
		__call = function(_, first, ...)
			-- `Library:Notify(cfg)` passes Library as the first argument
			if rawequal(first, Library) then
				return invoke(...)
			end
			return invoke(first, ...)
		end,
		__tostring = function()
			return "VoidCript." .. tostring(module._name or "Module")
		end,
	})
end

-- `Library.Flags` is the proxy: reading returns values, writing drives controls.
Library.Flags = Void.Flags.Proxy
Library.Controls = Void.Flags.Controls

Void.SliderStyle = "Slider"

-- ── idempotent re-load guard (roadmap #31) ─────────────────────────────────
if type(getgenv) == "function" then
	local existing = getgenv().VoidCript
	if existing and existing ~= Library and type(existing.Unload) == "function" then
		Log:Warn("a previous VoidCript instance was running — unloading it first")
		pcall(function() existing:Unload() end)
	end
	getgenv().VoidCript = Library
	getgenv().VoidCriptUI = Library
end

-- ── bootstrap the always-on subsystems ─────────────────────────────────────
Scale:Start(Void.RootMaid)
Void.Keybinds:Start(Void.RootMaid)
Void.Profiler:Start(Void.RootMaid)

-- ══════════════════════════════════════════════════════════════════════════
-- WINDOW
-- ══════════════════════════════════════════════════════════════════════════
--[[
	Library:CreateWindow({
		Name = "voidcript",
		Subtitle = "universal",
		Size = Vector2.new(760, 500),        -- desktop only; mobile auto-fits
		ToggleKey = "RightShift",
		LazyLoading = true,
		Resizable = true,
		FloatingButton = nil,                -- nil = auto (on for touch)
		MinimiseStyle = "Icon",              -- Icon | MiniBar
		LockGameInput = false,
		Theme = "Midnight",                  -- or a token table
		ConfigurationSaving = {
			Enabled = true,
			FolderName = "VoidCript",
			FileName = "Config",
			AutoSave = true,
			PerGame = false,
		},
		KeySystem = false,
		KeySettings = { ... },
		Loading = { Enabled = true, Title = "voidcript", Subtitle = "loading" },
	})
]]
function Library:CreateWindow(cfg)
	cfg = cfg or {}

	if cfg.Theme then
		if type(cfg.Theme) == "string" then
			Theme:SetPreset(cfg.Theme, true)
		elseif type(cfg.Theme) == "table" then
			Theme:Set(cfg.Theme, true)
		end
	end

	if cfg.Scale then Scale:SetMultiplier(cfg.Scale) end
	if cfg.Compact ~= nil then Scale:SetCompact(cfg.Compact) end
	if cfg.LogLevel then Log:SetLevel(cfg.LogLevel) end

	-- config system
	Void.Config:Configure(cfg.ConfigurationSaving or cfg.Config or { Enabled = false })

	-- key system gate
	if cfg.KeySystem then
		local passed = Void.KeySystem:Run(cfg.KeySettings or cfg.KeySettings)
		if not passed then
			Log:Warn("key system rejected — window not created")
			return nil
		end
	end

	-- optional boot screen driven by the library itself (the loader has its
	-- own, this one is for scripts that want a second staged load)
	local boot
	if cfg.Loading and cfg.Loading.Enabled ~= false then
		boot = Void.Boot.new({
			Title = cfg.Loading.Title or cfg.Name,
			Subtitle = cfg.Loading.Subtitle or cfg.Subtitle,
			Steps = cfg.Loading.Steps or 3,
			Cancellable = cfg.Loading.Cancellable == true,
		})
		boot:SetStage("Building interface", 0.2)
	end

	local window = Void.MakeWindow(cfg)

	if cfg.Watermark then
		local settings = type(cfg.Watermark) == "table" and cfg.Watermark or {}
		settings.Title = settings.Title or cfg.Name
		Library:Watermark(settings)
	end
	if cfg.Keylist then
		Library:Keylist(type(cfg.Keylist) == "table" and cfg.Keylist or {})
	end
	if cfg.Cursor then Void.Cursor:SetEnabled(true) end

	-- auto-load the saved config once the script finished declaring its UI
	if Void.Config.Enabled and cfg.AutoLoadConfig ~= false then
		task.defer(function()
			task.wait(cfg.AutoLoadDelay or 0.6)
			if Void.Config.PerGame then
				local gamePath = Void.Config:GamePath()
				if type(isfile) == "function" and isfile(gamePath) then
					Log:Info("loading per-game profile for place %s", tostring(game.PlaceId))
				end
			end
			Void.Config:Load(Void.Config.File, true)
		end)
	end

	if boot then
		task.defer(function()
			boot:SetStage("Ready", 1)
			boot:Finish()
		end)
	end

	return window
end

function Library:GetWindow(index)
	return Void.Windows[index or 1]
end

-- ══════════════════════════════════════════════════════════════════════════
-- FLAGS
-- ══════════════════════════════════════════════════════════════════════════
function Library:GetFlag(flag, default)
	return Void.Flags:Get(flag, default)
end

function Library:SetFlag(flag, value, silent)
	return Void.Flags:Set(flag, value, silent)
end

function Library:HasFlag(flag)
	return Void.Flags:Exists(flag)
end

function Library:GetControl(flag)
	return Void.Flags:GetControl(flag)
end

function Library:OnFlagChanged(flag, callback)
	return Void.Flags:OnChanged(flag, callback)
end
Library.OnChanged = Library.OnFlagChanged

function Library:ListFlags()
	return Void.Flags:List()
end

function Library:SnapshotFlags()
	return Void.Flags:Snapshot()
end

-- When strict mode is on, reading an unknown flag raises instead of warning.
function Library:SetStrictFlags(state)
	Void.Flags.Strict = state and true or false
	return Void.Flags.Strict
end

-- ══════════════════════════════════════════════════════════════════════════
-- THEME
-- ══════════════════════════════════════════════════════════════════════════
function Library:SetTheme(overrides, instant)
	Theme:Set(overrides, instant)
	return self
end

function Library:SetThemePreset(name, instant)
	return Theme:SetPreset(name, instant)
end

function Library:RegisterTheme(name, tokens)
	return Theme:RegisterPreset(name, tokens)
end

function Library:ListThemes()
	return Theme:ListPresets()
end

function Library:GetTheme()
	return Theme.Tokens
end

-- ══════════════════════════════════════════════════════════════════════════
-- SCALE / DEVICE
-- ══════════════════════════════════════════════════════════════════════════
function Library:SetScale(multiplier)
	return Scale:SetMultiplier(multiplier)
end

function Library:SetCompact(state)
	return Scale:SetCompact(state)
end

function Library:GetDevice()
	return Scale.Device, Scale.Factor
end

function Library:IsMobile()
	return Scale:IsMobileClass()
end

-- Slider vs knob preference for numeric elements created afterwards.
function Library:SetSliderStyle(style)
	style = (style == "Knob") and "Knob" or "Slider"
	Void.SliderStyle = style
	-- swap the factory so future CreateSlider calls honour the preference
	if style == "Knob" then
		Void.Elements.Slider = Void.Elements._SliderKnob or Void.Elements.Knob
	else
		Void.Elements.Slider = Void.Elements._SliderLinear
	end
	Log:Debug("slider style set to %s", style)
	return style
end
Void.Elements._SliderLinear = Void.Elements.Slider

-- ══════════════════════════════════════════════════════════════════════════
-- NOTIFICATIONS · DIALOGS · TOOLTIPS
-- ══════════════════════════════════════════════════════════════════════════
-- `Library.Notify` is callable *and* a module (see callableModule above):
--     Library:Notify{...}   ·   Library.Notify:SetPosition("TopLeft")
Void.Notify._name = "Notify"
Library.Notify = callableModule(Void.Notify, function(cfg)
	return Void.Notify:Push(cfg)
end)

function Library:NotifyProgress(cfg)
	return Void.Notify:Progress(cfg)
end

Void.Dialog._name = "Dialog"
Library.Dialog = callableModule(Void.Dialog, function(cfg)
	return Void.Dialog:Confirm(cfg)
end)

function Library:Prompt(cfg)
	return Void.Dialog:Prompt(cfg)
end

function Library:Choice(cfg)
	return Void.Dialog:Choice(cfg)
end

-- ══════════════════════════════════════════════════════════════════════════
-- WATERMARK · KEYLIST
-- ══════════════════════════════════════════════════════════════════════════
Void.Watermark._name = "Watermark"
Library.Watermark = callableModule(Void.Watermark, function(cfg)
	return Void.Watermark:Create(cfg)
end)

function Library:RegisterWatermarkModule(name, provider, options)
	return Void.Watermark:RegisterModule(name, provider, options)
end

Void.Keylist._name = "Keylist"
Library.Keylist = callableModule(Void.Keylist, function(cfg)
	return Void.Keylist:Create(cfg)
end)

-- ══════════════════════════════════════════════════════════════════════════
-- CONFIGS
-- ══════════════════════════════════════════════════════════════════════════
function Library:SaveConfig(name)
	return Void.Config:Save(name)
end

function Library:LoadConfig(name)
	return Void.Config:Load(name)
end

function Library:ListConfigs()
	return Void.Config:List()
end

function Library:DeleteConfig(name)
	return Void.Config:Delete(name)
end

function Library:RenameConfig(oldName, newName)
	return Void.Config:Rename(oldName, newName)
end

function Library:ExportConfig(name)
	return Void.Config:Export(name)
end

function Library:ImportConfig(payload, saveAs)
	return Void.Config:Import(payload, saveAs)
end

function Library:SetAutoSave(state, delay)
	Void.Config.AutoSave = state and true or false
	Void.Config.Enabled = Void.Config.Enabled or state
	if delay then Void.Config.AutoSaveDelay = delay end
	return Void.Config.AutoSave
end

-- ══════════════════════════════════════════════════════════════════════════
-- LOGGING
-- ══════════════════════════════════════════════════════════════════════════
function Library:SetLogLevel(level)
	return Log:SetLevel(level)
end

function Library:GetLogLevel()
	return Log:GetLevel()
end

function Library:GetLogs(minLevel)
	if minLevel then return Log:Dump(minLevel) end
	return Log.History
end

function Library:ClearLogs()
	Log:Clear()
	return self
end

-- Guarded call helper for script authors: never let your own error kill the UI.
function Library:Guard(context, fn, ...)
	return Log:Guard(context, fn, ...)
end

-- ══════════════════════════════════════════════════════════════════════════
-- PLUGINS
-- ══════════════════════════════════════════════════════════════════════════
function Library:RegisterPlugin(plugin)
	return Void.Plugins:Register(plugin)
end

function Library:UnregisterPlugin(name)
	return Void.Plugins:Unregister(name)
end

function Library:ListPlugins()
	return Void.Plugins:List()
end

-- ══════════════════════════════════════════════════════════════════════════
-- BOOT SCREEN (exposed so scripts can drive their own staged loading)
-- ══════════════════════════════════════════════════════════════════════════
function Library:Boot(cfg)
	return Void.Boot.new(cfg)
end

-- ══════════════════════════════════════════════════════════════════════════
-- PROFILING
-- ══════════════════════════════════════════════════════════════════════════
function Library:GetProfile()
	return Void.Profiler:Report()
end

function Library:GetProfileString()
	return Void.Profiler:ReportString()
end

function Library:GetMetrics()
	local p = Void.Profiler
	return {
		FPS = p.FPS,
		Low1 = p.Low1,
		FrameTimeMs = p.FrameTimeMs,
		Ping = p.Ping,
		Memory = p.Memory,
		Instances = p.InstanceCount,
		Flags = Void.Flags:Count(),
		ThemedInstances = Theme:RegistryCount(),
		Connections = Void.RootMaid:Count(),
		Device = Scale.Device,
		ScaleFactor = Scale.Factor,
	}
end

-- ══════════════════════════════════════════════════════════════════════════
-- UNLOAD
-- ══════════════════════════════════════════════════════════════════════════
function Library:Unload()
	Log:Info("unloading VoidCriptUI v%s", tostring(Void.Version))

	Void.Config:FlushAutoSave()

	for _, window in ipairs(table.clone(Void.Windows)) do
		pcall(function() window:Destroy() end)
	end
	table.clear(Void.Windows)

	pcall(function() Void.Watermark:Destroy() end)
	pcall(function() Void.Keylist:Destroy() end)
	pcall(function() Void.Notify:DismissAll() end)
	pcall(function() Void.Dialog:CloseAll() end)
	pcall(function() Void.Cursor:Stop() end)
	pcall(function() Void.Plugins:Fire("OnUnload", self) end)
	pcall(function() Void.Profiler:Stop() end)

	Void.Keybinds:Clear()
	Void.Flags:Clear()
	Void.Search:Reset()
	Void.Dependencies:Clear()
	Void.RootMaid:Clean()

	if type(getgenv) == "function" and getgenv().VoidCript == self then
		getgenv().VoidCript = nil
		getgenv().VoidCriptUI = nil
	end

	Log:Info("unloaded cleanly")
	return true
end
Library.Destroy = Library.Unload

-- ══════════════════════════════════════════════════════════════════════════
-- CONVENIENCE ALIASES (drop-in familiarity with other libraries)
-- ══════════════════════════════════════════════════════════════════════════
Library.Window = Library.CreateWindow
Library.MakeWindow = Library.CreateWindow
Library.SetFolder = function(self, folder)
	Void.Config.Folder = folder
	Void.Config:EnsureTree()
	return self
end

Library.FromHex = Util.FromHex
Library.ToHex = Util.ToHex
Library.Debounce = Util.Debounce
Library.Throttle = Util.Throttle

-- A tiny greeting in the console at Debug level, and one intentionally quiet
-- marker so we can tell at a glance which build shipped.
Log:Debug("VoidCriptUI %s ready · device=%s factor=%.2f", Void.Version, Scale.Device, Scale.Factor)
if rawget(_G, "VOIDCRIPT_VERBOSE") then
	print("CL was here!!!") -- signature of the assistant that helped build v3
end

return Library
