--[[
	VoidCriptUI · Core/Util.lua
	Instance factory, tween helpers, dragging, debounce/throttle.

	Performance notes:
	  · `New` sets Parent LAST. Parenting an unfinished instance forces Roblox
	    to re-layout on every following property write; setting it last is a
	    measurable win when building hundreds of elements.
	  · `Tween` reuses cached TweenInfo objects instead of allocating a new one
	    per call (thousands of hover tweens per session otherwise).
	  · `Debounce` / `Throttle` wrap user callbacks so heavy code never runs
	    more than once per interval.
]]

return function(Void)
	local TweenService = game:GetService("TweenService")
	local UserInputService = game:GetService("UserInputService")
	local RunService = game:GetService("RunService")
	local Players = game:GetService("Players")

	local Util = {}

	Util.LocalPlayer = Players.LocalPlayer

	-- ── instance factory ────────────────────────────────────────────────
	local DEFAULTS = {
		Frame = { BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1) },
		TextLabel = { BorderSizePixel = 0, BackgroundTransparency = 1, RichText = false },
		TextButton = { BorderSizePixel = 0, AutoButtonColor = false, Text = "" },
		TextBox = { BorderSizePixel = 0, ClearTextOnFocus = false },
		ImageLabel = { BorderSizePixel = 0, BackgroundTransparency = 1 },
		ImageButton = { BorderSizePixel = 0, BackgroundTransparency = 1, AutoButtonColor = false },
		ScrollingFrame = {
			BorderSizePixel = 0,
			BackgroundTransparency = 1,
			ScrollBarThickness = 3,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ElasticBehavior = Enum.ElasticBehavior.Never,
		},
		CanvasGroup = { BorderSizePixel = 0, BackgroundTransparency = 1 },
	}

	function Util.New(class, props, children)
		local inst
		local ok, err = pcall(function()
			inst = Instance.new(class)
		end)
		if not ok or not inst then
			-- roadmap: log element creation failures instead of dying silently
			Void.Log:Error("could not create instance of class '%s': %s", tostring(class), tostring(err))
			inst = Instance.new("Frame")
			inst.BackgroundTransparency = 1
		end

		local defaults = DEFAULTS[class]
		if defaults then
			for k, v in pairs(defaults) do
				if props == nil or props[k] == nil then
					pcall(function() inst[k] = v end)
				end
			end
		end

		local parent
		if props then
			for k, v in pairs(props) do
				if k == "Parent" then
					parent = v
				else
					local okSet, setErr = pcall(function() inst[k] = v end)
					if not okSet then
						Void.Log:Warn("property '%s' on %s rejected: %s", tostring(k), class, tostring(setErr))
					end
				end
			end
		end

		if children then
			for _, child in ipairs(children) do
				if child then child.Parent = inst end
			end
		end

		if parent then inst.Parent = parent end
		return inst
	end

	-- ── tweening ────────────────────────────────────────────────────────
	local infoCache = {}
	local function tweenInfo(dur, style, dir)
		style = style or Enum.EasingStyle.Quad
		dir = dir or Enum.EasingDirection.Out
		local key = string.format("%.3f|%d|%d", dur, style.Value, dir.Value)
		local cached = infoCache[key]
		if not cached then
			cached = TweenInfo.new(dur, style, dir)
			infoCache[key] = cached
		end
		return cached
	end
	Util.TweenInfo = tweenInfo

	Util.Motion = {
		Fast   = 0.10,
		Normal = 0.16,
		Slow   = 0.28,
		Boot   = 0.45,
	}

	-- Global animation switch — the built-in "Reduce animations" setting flips
	-- this for low-end machines. When off, properties are applied instantly.
	Util.AnimationsEnabled = true

	function Util.Tween(inst, props, dur, style, dir)
		if not inst or not inst.Parent and not props then return end
		if not Util.AnimationsEnabled or dur == 0 then
			for k, v in pairs(props) do
				pcall(function() inst[k] = v end)
			end
			return nil
		end
		local tween = TweenService:Create(inst, tweenInfo(dur or Util.Motion.Normal, style, dir), props)
		tween:Play()
		return tween
	end

	function Util.TweenBack(inst, props, dur)
		return Util.Tween(inst, props, dur or Util.Motion.Slow, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	end

	-- ── decorations ─────────────────────────────────────────────────────
	function Util.Corner(parent, radius)
		return Util.New("UICorner", { CornerRadius = UDim.new(0, radius or 4), Parent = parent })
	end

	function Util.Stroke(parent, color, thickness, transparency)
		return Util.New("UIStroke", {
			Color = color or Color3.fromRGB(40, 40, 46),
			Thickness = thickness or 1,
			Transparency = transparency or 0,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			LineJoinMode = Enum.LineJoinMode.Round,
			Parent = parent,
		})
	end

	function Util.Padding(parent, all, extra)
		local props = {
			PaddingLeft = UDim.new(0, all or 0),
			PaddingRight = UDim.new(0, all or 0),
			PaddingTop = UDim.new(0, all or 0),
			PaddingBottom = UDim.new(0, all or 0),
			Parent = parent,
		}
		for k, v in pairs(extra or {}) do props[k] = v end
		return Util.New("UIPadding", props)
	end

	function Util.List(parent, padding, dir, extra)
		local props = {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, padding or 6),
			FillDirection = dir or Enum.FillDirection.Vertical,
			Parent = parent,
		}
		for k, v in pairs(extra or {}) do props[k] = v end
		return Util.New("UIListLayout", props)
	end

	-- Subtle vertical "glass" sheen used on windows/cards. Pure UIGradient, so
	-- it costs nothing at runtime (no blur, no DepthOfField, no EditableImage).
	function Util.Glass(parent, strength)
		strength = strength or 0.94
		return Util.New("Frame", {
			Name = "Glass",
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = strength,
			Size = UDim2.fromScale(1, 1),
			ZIndex = (parent.ZIndex or 1),
			Parent = parent,
		}, {
			Util.New("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.45, 0.75),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
			Util.New("UICorner", { CornerRadius = UDim.new(0, 6) }),
		})
	end

	-- Soft outer shadow built from a single 9-slice image asset.
	function Util.Shadow(parent, size, transparency)
		return Util.New("ImageLabel", {
			Name = "Shadow",
			Image = "rbxassetid://6014261993",
			ImageColor3 = Color3.new(0, 0, 0),
			ImageTransparency = transparency or 0.45,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(49, 49, 450, 450),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, size or 46, 1, size or 46),
			ZIndex = -1,
			Parent = parent,
		})
	end

	-- ── gui parent resolution ───────────────────────────────────────────
	function Util.GuiParent()
		local ok, hidden = pcall(function()
			return gethui and gethui()
		end)
		if ok and hidden then return hidden end
		local okCore, core = pcall(function()
			return game:GetService("CoreGui")
		end)
		if okCore and core then
			-- confirm we may actually parent there
			local canUse = pcall(function()
				local probe = Instance.new("Folder")
				probe.Parent = core
				probe:Destroy()
			end)
			if canUse then return core end
		end
		return Util.LocalPlayer:WaitForChild("PlayerGui")
	end

	function Util.Screen(name, maid)
		local gui = Util.New("ScreenGui", {
			Name = name or "VoidCript",
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = 9999,
			Parent = Util.GuiParent(),
		})
		if syn and syn.protect_gui then pcall(syn.protect_gui, gui) end
		if maid then maid:Give(gui) end
		return gui
	end

	-- ── dragging (shared input pass, clamped to viewport) ───────────────
	function Util.Draggable(handle, target, maid, onDrag)
		local dragging, startInput, startPos = false, nil, nil

		local function finish()
			dragging = false
		end

		local c1 = handle.InputBegan:Connect(function(input)
			local t = input.UserInputType
			if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
				dragging = true
				startInput = input.Position
				startPos = target.Position
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then finish() end
				end)
			end
		end)

		local c2 = UserInputService.InputChanged:Connect(function(input)
			if not dragging then return end
			local t = input.UserInputType
			if t ~= Enum.UserInputType.MouseMovement and t ~= Enum.UserInputType.Touch then return end
			local delta = input.Position - startInput
			local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
			local size = target.AbsoluteSize
			local x = startPos.X.Offset + delta.X
			local y = startPos.Y.Offset + delta.Y
			-- keep at least 40px of the window on screen
			local minX = -(viewport.X * startPos.X.Scale) - size.X + 40
			local maxX = viewport.X - (viewport.X * startPos.X.Scale) - 40
			local minY = -(viewport.Y * startPos.Y.Scale) - size.Y + 40
			local maxY = viewport.Y - (viewport.Y * startPos.Y.Scale) - 40
			target.Position = UDim2.new(
				startPos.X.Scale, math.clamp(x, minX, maxX),
				startPos.Y.Scale, math.clamp(y, minY, maxY)
			)
			if onDrag then onDrag(target.Position) end
		end)

		local c3 = UserInputService.InputEnded:Connect(function(input)
			local t = input.UserInputType
			if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then finish() end
		end)

		if maid then maid:GiveMany(c1, c2, c3) end
		return function() finish() end
	end

	-- Drag helper for sliders / colour bars. Uses the shared InputChanged pass
	-- (never a while-loop) and reads AbsolutePosition only while dragging.
	function Util.BindDrag(bar, maid, onMove, onRelease, axis)
		local dragging = false
		axis = axis or "X"

		local function compute(input)
			local pos, size = bar.AbsolutePosition, bar.AbsoluteSize
			if axis == "XY" then
				return math.clamp((input.Position.X - pos.X) / math.max(size.X, 1), 0, 1),
					math.clamp((input.Position.Y - pos.Y) / math.max(size.Y, 1), 0, 1)
			elseif axis == "Y" then
				return math.clamp((input.Position.Y - pos.Y) / math.max(size.Y, 1), 0, 1)
			end
			return math.clamp((input.Position.X - pos.X) / math.max(size.X, 1), 0, 1)
		end

		local c1 = bar.InputBegan:Connect(function(input)
			local t = input.UserInputType
			if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
				dragging = true
				onMove(compute(input))
			end
		end)
		local c2 = UserInputService.InputChanged:Connect(function(input)
			if not dragging then return end
			local t = input.UserInputType
			if t ~= Enum.UserInputType.MouseMovement and t ~= Enum.UserInputType.Touch then return end
			onMove(compute(input))
		end)
		local c3 = UserInputService.InputEnded:Connect(function(input)
			local t = input.UserInputType
			if dragging and (t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch) then
				dragging = false
				if onRelease then onRelease() end
			end
		end)
		if maid then maid:GiveMany(c1, c2, c3) end
		return function() return dragging end
	end

	-- ── rate limiting ───────────────────────────────────────────────────
	-- Trailing-edge debounce: fires once, `delay` seconds after the last call.
	function Util.Debounce(fn, delay)
		delay = delay or 0.1
		local thread
		return function(...)
			local args = table.pack(...)
			if thread then task.cancel(thread) end
			thread = task.delay(delay, function()
				thread = nil
				fn(table.unpack(args, 1, args.n))
			end)
		end, function()
			if thread then task.cancel(thread); thread = nil end
		end
	end

	-- Leading-edge throttle with trailing flush: fires immediately, then at
	-- most once per interval, and always delivers the final value.
	function Util.Throttle(fn, interval)
		interval = interval or 0.05
		local last, pending, thread = 0, nil, nil
		return function(...)
			local now = os.clock()
			if now - last >= interval then
				last = now
				fn(...)
			else
				pending = table.pack(...)
				if not thread then
					thread = task.delay(interval - (now - last), function()
						thread = nil
						last = os.clock()
						if pending then
							local args = pending
							pending = nil
							fn(table.unpack(args, 1, args.n))
						end
					end)
				end
			end
		end
	end

	-- ── misc ────────────────────────────────────────────────────────────
	-- Snap a value to a step and strip float noise (0.30000000000000004 → 0.3).
	-- The decimal count comes from the increment's own text form rather than
	-- log10, which is both exact and free of edge cases at powers of ten.
	local decimalCache = {}
	local function decimalsOf(increment)
		local cached = decimalCache[increment]
		if cached then return cached end
		local text = string.format("%.10f", increment):gsub("0+$", "")
		local fraction = text:match("%.(%d*)$") or ""
		local count = math.min(#fraction, 6)
		decimalCache[increment] = count
		return count
	end

	function Util.Round(value, increment)
		value = tonumber(value) or 0
		if not increment or increment <= 0 then return value end
		local rounded = math.floor(value / increment + 0.5) * increment
		return tonumber(string.format("%." .. decimalsOf(increment) .. "f", rounded)) or rounded
	end

	function Util.FromHex(hex)
		if typeof(hex) == "Color3" then return hex end
		hex = tostring(hex):gsub("#", ""):gsub("%s", "")
		if #hex == 3 then
			hex = hex:sub(1, 1):rep(2) .. hex:sub(2, 2):rep(2) .. hex:sub(3, 3):rep(2)
		end
		if #hex ~= 6 or hex:match("[^0-9a-fA-F]") then return nil end
		return Color3.fromRGB(
			tonumber(hex:sub(1, 2), 16),
			tonumber(hex:sub(3, 4), 16),
			tonumber(hex:sub(5, 6), 16)
		)
	end

	function Util.ToHex(color)
		return string.format("#%02X%02X%02X",
			math.floor(color.R * 255 + 0.5),
			math.floor(color.G * 255 + 0.5),
			math.floor(color.B * 255 + 0.5))
	end

	function Util.Lerp(a, b, t)
		return a + (b - a) * t
	end

	function Util.LerpColor(a, b, t)
		return a:Lerp(b, t)
	end

	-- Deep copy that only recurses into *plain* tables. Roblox datatypes
	-- (Color3, UDim2, EnumItem, …) are immutable values and must be carried
	-- across by reference — copying their fields would strip their methods.
	function Util.DeepCopy(tbl)
		local out = {}
		for k, v in pairs(tbl) do
			if type(v) == "table" and typeof(v) == "table" then
				out[k] = Util.DeepCopy(v)
			else
				out[k] = v
			end
		end
		return out
	end

	function Util.Slug(text)
		return tostring(text):lower():gsub("[^%w]+", "")
	end

	-- Case/spacing-insensitive fuzzy match used by the global search.
	function Util.Matches(haystack, needle)
		if not needle or needle == "" then return true end
		return Util.Slug(haystack):find(Util.Slug(needle), 1, true) ~= nil
	end

	function Util.IsMobile()
		local touch = UserInputService.TouchEnabled
		local keyboard = UserInputService.KeyboardEnabled
		local mouse = UserInputService.MouseEnabled
		return touch and not keyboard and not mouse
	end

	function Util.Viewport()
		local cam = workspace.CurrentCamera
		return cam and cam.ViewportSize or Vector2.new(1920, 1080)
	end

	-- Wait one render frame — used to let AutomaticSize settle before we read
	-- AbsoluteSize (avoids the classic "element measured at 0" bug).
	function Util.NextFrame()
		return RunService.RenderStepped:Wait()
	end

	Void.Util = Util
	return Util
end
