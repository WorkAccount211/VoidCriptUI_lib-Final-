--[[
	VoidCriptUI · Window/Host.lua
	The element host — the shared surface that exposes every Create* method.

	Sections, collapsibles and tabs all delegate to a host, which means:
	  · one place defines the element API (no duplicated method lists)
	  · plugin elements appear automatically through the __index fallback, even
	    if the plugin was registered after the UI was built
	  · every element receives the same context table

	`Void.MakeElementHost(ctx)` returns a table with:
		CreateToggle, CreateSlider, CreateRangeSlider, CreateKnob,
		CreateDropdown, CreateMultiDropdown, CreateInput/CreateTextbox,
		CreateKeybind/CreateBind, CreateColorPicker, CreateButton,
		CreateImageButton, CreateLabel, CreateParagraph, CreateDivider,
		CreateProgressBar, CreateImage, CreateListBox, CreateTable,
		CreateCollapsible, plus Clear / GetElements / FindElement.
]]

return function(Void)
	local BUILTIN = {
		"Toggle", "Slider", "RangeSlider", "Knob", "Dropdown", "MultiDropdown",
		"Input", "Textbox", "Keybind", "Bind", "ColorPicker", "Button",
		"ImageButton", "Label", "Paragraph", "Divider", "ProgressBar",
		"Image", "ListBox", "Table", "Collapsible",
	}

	function Void.MakeElementHost(ctx)
		local host = {
			Name = ctx.Name,
			_ctx = ctx,
			_elements = {},
			_parent = ctx.Parent,
			_maid = ctx.Maid,
		}

		local function context()
			return {
				Window = ctx.Window,
				Tab = ctx.Tab,
				Section = ctx.Section or host,
				Host = host,
				Parent = ctx.Parent,
				Maid = ctx.Maid,
				Control = Void.Control,
				Util = Void.Util,
				Theme = Void.Theme,
				Scale = Void.Scale,
				Common = Void.Common,
				Void = Void,
			}
		end
		host._context = context

		local function track(control, kind)
			if not control then return nil end
			table.insert(host._elements, control)
			if ctx.OnElementAdded then
				pcall(ctx.OnElementAdded, control, kind)
			end
			Void.Plugins:Fire("OnElement", control, kind)
			return control
		end

		-- Generate the built-in Create* methods.
		for _, kind in ipairs(BUILTIN) do
			host["Create" .. kind] = function(_, cfg)
				local factory = Void.Elements[kind]
				if not factory then
					Void.Log:Error("element type '%s' is not available", kind)
					return nil
				end
				Void.Profiler:Begin("element:" .. kind)
				local ok, control = pcall(factory, context(), cfg)
				Void.Profiler:End()
				if not ok then
					-- roadmap: log element creation failures loudly, but never
					-- let one bad element abort the whole UI build
					Void.Log:Error("failed to create %s '%s': %s", kind,
						tostring(type(cfg) == "table" and cfg.Name or cfg), tostring(control))
					Void.Notify:Push({
						Title = "Element failed",
						Content = ("Could not create **%s** — see the F9 console"):format(kind),
						Type = "error", Duration = 6,
					})
					return nil
				end
				return track(control, kind)
			end
		end

		-- Aliases people expect from other libraries.
		host.CreateTextBox = host.CreateTextbox
		host.CreateColourPicker = host.CreateColorPicker
		host.CreateSection2 = nil
		host.AddToggle = host.CreateToggle
		host.AddSlider = host.CreateSlider
		host.AddDropdown = host.CreateDropdown
		host.AddButton = host.CreateButton
		host.AddInput = host.CreateInput
		host.AddKeybind = host.CreateKeybind
		host.AddColorPicker = host.CreateColorPicker
		host.AddLabel = host.CreateLabel
		host.AddParagraph = host.CreateParagraph
		host.AddDivider = host.CreateDivider

		-- roadmap #32: clear a section at runtime
		function host:Clear()
			for i = #self._elements, 1, -1 do
				local control = self._elements[i]
				if control and not control._destroyed then
					control:Destroy()
				end
				self._elements[i] = nil
			end
			return self
		end

		function host:GetElements()
			return self._elements
		end

		function host:FindElement(name)
			for _, control in ipairs(self._elements) do
				if control.Name == name then return control end
			end
			return nil
		end

		function host:_removeElement(control)
			for i = #self._elements, 1, -1 do
				if self._elements[i] == control then table.remove(self._elements, i) end
			end
		end

		function host:CountElements()
			return #self._elements
		end

		-- Plugin elements: resolved lazily so plugins registered after the UI
		-- was built still work.
		return setmetatable(host, {
			__index = function(_, key)
				local elementName = tostring(key):match("^Create(.+)$")
				if elementName then
					if Void.Plugins:HasElement(elementName) then
						return function(_, cfg)
							return track(Void.Plugins:BuildElement(elementName, context(), cfg), elementName)
						end
					end
					if Void.Elements[elementName] then
						return function(_, cfg)
							local ok, control = pcall(Void.Elements[elementName], context(), cfg)
							if not ok then
								Void.Log:Error("failed to create %s: %s", elementName, tostring(control))
								return nil
							end
							return track(control, elementName)
						end
					end
					return function()
						Void.Log:Warn("there is no element type '%s' — register a plugin that provides it", elementName)
						return nil
					end
				end
				return nil
			end,
		})
	end
end
