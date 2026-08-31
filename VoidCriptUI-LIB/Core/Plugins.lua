--[[
	VoidCriptUI · Core/Plugins.lua
	Plugin system — third-party widgets and behaviour without touching the core.

	A plugin is a table (or a function returning one):

		VoidLib:RegisterPlugin({
			Name = "SpectrumWidget",
			Version = "1.0.0",
			Author = "you",

			-- optional: add new Section:CreateXxx methods
			Elements = {
				Spectrum = function(ctx, cfg)
					-- ctx = { Void, Section, Parent, Maid, Control, Util, Theme, Scale }
					local control = ctx.Control.new("Spectrum", cfg, ctx)
					local root = ctx.Util.New("Frame", { ... , Parent = ctx.Parent })
					control:_finalise(root)
					return control
				end,
			},

			-- optional lifecycle hooks
			OnLoad   = function(lib) end,
			OnWindow = function(window) end,
			OnTab    = function(tab) end,
			OnUnload = function(lib) end,

			-- optional: extra icons, theme presets, watermark modules
			Icons = { spectrum = "▁▃▅" },
			Themes = { Neon = { Accent = "#00ffd0" } },
			WatermarkModules = { ram = function() return "RAM 512" end },
		})

	Section methods are generated automatically: `Elements.Spectrum` becomes
	`Section:CreateSpectrum(cfg)` and `Tab:CreateSpectrum(cfg)`.
]]

return function(Void)
	local Plugins = {
		_list = {},
		_byName = {},
		Elements = {},   -- name -> factory(ctx, cfg)
		Hooks = { OnWindow = {}, OnTab = {}, OnSection = {}, OnUnload = {}, OnElement = {} },
	}

	local RESERVED = {
		Toggle = true, Slider = true, Dropdown = true, Input = true, Keybind = true,
		ColorPicker = true, Button = true, Label = true, Paragraph = true, Divider = true,
		Section = true, Tab = true,
	}

	function Plugins:Register(plugin)
		if type(plugin) == "function" then
			local ok, result = pcall(plugin, Void.Library)
			if not ok then
				Void.Log:Error("plugin factory errored: %s", tostring(result))
				return nil
			end
			plugin = result
		end
		if type(plugin) ~= "table" then
			Void.Log:Error("RegisterPlugin expects a table or a function returning a table")
			return nil
		end

		plugin.Name = plugin.Name or ("Plugin" .. tostring(#self._list + 1))
		plugin.Version = plugin.Version or "1.0.0"

		if self._byName[plugin.Name] then
			Void.Log:Warn("plugin '%s' is already registered — replacing it", plugin.Name)
			self:Unregister(plugin.Name)
		end

		-- element factories
		for name, factory in pairs(plugin.Elements or {}) do
			if type(factory) ~= "function" then
				Void.Log:Warn("plugin '%s': element '%s' is not a function", plugin.Name, tostring(name))
			elseif RESERVED[name] then
				Void.Log:Warn("plugin '%s': element name '%s' collides with a built-in element", plugin.Name, name)
			else
				if self.Elements[name] then
					Void.Log:Warn("plugin '%s': element '%s' overrides another plugin", plugin.Name, name)
				end
				self.Elements[name] = { Factory = factory, Plugin = plugin.Name }
				Void.Log:Debug("plugin '%s' registered element Create%s", plugin.Name, name)
			end
		end

		-- icons / themes / watermark modules
		if plugin.Icons then Void.Icons:RegisterPack(plugin.Icons) end
		for presetName, tokens in pairs(plugin.Themes or {}) do
			Void.Theme:RegisterPreset(presetName, tokens)
		end
		for moduleName, provider in pairs(plugin.WatermarkModules or {}) do
			if Void.Watermark then Void.Watermark:RegisterModule(moduleName, provider) end
		end

		-- hooks
		for hookName, list in pairs(self.Hooks) do
			if type(plugin[hookName]) == "function" then
				table.insert(list, { Fn = plugin[hookName], Plugin = plugin.Name })
			end
		end

		self._byName[plugin.Name] = plugin
		table.insert(self._list, plugin)

		if type(plugin.OnLoad) == "function" then
			Void.Log:Guard(("plugin '%s' OnLoad"):format(plugin.Name), plugin.OnLoad, Void.Library)
		end

		Void.Log:Info("plugin '%s' v%s loaded", plugin.Name, plugin.Version)

		-- late registration: apply to already-open windows
		for _, window in ipairs(Void.Windows or {}) do
			self:Fire("OnWindow", window)
		end

		return plugin
	end

	function Plugins:Unregister(name)
		local plugin = self._byName[name]
		if not plugin then return false end

		if type(plugin.OnUnload) == "function" then
			Void.Log:Guard(("plugin '%s' OnUnload"):format(name), plugin.OnUnload, Void.Library)
		end

		for elementName, def in pairs(self.Elements) do
			if def.Plugin == name then self.Elements[elementName] = nil end
		end
		for _, list in pairs(self.Hooks) do
			for i = #list, 1, -1 do
				if list[i].Plugin == name then table.remove(list, i) end
			end
		end

		self._byName[name] = nil
		for i = #self._list, 1, -1 do
			if self._list[i].Name == name then table.remove(self._list, i) end
		end
		Void.Log:Info("plugin '%s' unloaded", name)
		return true
	end

	function Plugins:Fire(hookName, ...)
		local list = self.Hooks[hookName]
		if not list then return end
		for _, entry in ipairs(list) do
			Void.Log:Guard(("plugin '%s' %s"):format(entry.Plugin, hookName), entry.Fn, ...)
		end
	end

	function Plugins:Get(name)
		return self._byName[name]
	end

	function Plugins:List()
		local out = {}
		for _, plugin in ipairs(self._list) do
			out[#out + 1] = { Name = plugin.Name, Version = plugin.Version, Author = plugin.Author }
		end
		return out
	end

	function Plugins:HasElement(name)
		return self.Elements[name] ~= nil
	end

	-- Called by Section to build a plugin element.
	function Plugins:BuildElement(name, ctx, cfg)
		local def = self.Elements[name]
		if not def then
			Void.Log:Warn("no plugin element named '%s'", tostring(name))
			return nil
		end
		local ok, control = pcall(def.Factory, ctx, cfg or {})
		if not ok then
			Void.Log:Error("plugin '%s' failed to build element '%s': %s", def.Plugin, name, tostring(control))
			return nil
		end
		self:Fire("OnElement", control, name)
		return control
	end

	-- Attach Create<Name> methods for every plugin element onto a section-like
	-- table. Called by Section:new so plugins registered later still work
	-- through the __index fallback in Section.
	function Plugins:AttachTo(sectionLike, ctxFactory)
		for name in pairs(self.Elements) do
			local methodName = "Create" .. name
			if sectionLike[methodName] == nil then
				sectionLike[methodName] = function(selfRef, cfg)
					return Plugins:BuildElement(name, ctxFactory(selfRef), cfg)
				end
			end
		end
	end

	function Plugins:Clear()
		for _, plugin in ipairs(table.clone(self._list)) do
			self:Unregister(plugin.Name)
		end
		table.clear(self.Elements)
		for _, list in pairs(self.Hooks) do table.clear(list) end
	end

	Void.Plugins = Plugins
	return Plugins
end
