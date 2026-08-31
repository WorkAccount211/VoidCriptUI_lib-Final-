--[[
	VoidCriptUI · Services/Backdrop.lua
	"Glass" background dimming — no EditableImage, no DepthOfField, no blur.

	Why not real blur: EditableImage readback stalls the render thread and
	DepthOfField affects the whole game (and gets flagged in reviews). Instead
	we stack three zero-cost layers inside one CanvasGroup:

	  1. deep dim      — solid black at a configurable transparency
	  2. vignette      — radial-ish darkening built from two UIGradients so the
	                     centre stays readable and the edges fall off
	  3. glass sheen   — a very faint white top-to-bottom gradient plus a
	                     hairline stroke, which reads as frosted glass

	Fading the whole thing is a single GroupTransparency tween.
]]

return function(Void)
	local Util, Theme = Void.Util, Void.Theme

	local Backdrop = {}
	Backdrop.__index = Backdrop

	-- parent: a ScreenGui or Frame to fill.
	function Backdrop.new(parent, options)
		options = options or {}
		local self = setmetatable({
			_strength = options.Strength or Theme.Style.BackdropTransparency,
			_visible = false,
		}, Backdrop)

		local canvas = Util.New("CanvasGroup", {
			Name = "Backdrop",
			BackgroundTransparency = 1,
			GroupTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0, 0),
			ZIndex = options.ZIndex or 0,
			Visible = false,
			Parent = parent,
		})
		self._canvas = canvas

		-- 1. deep dim
		local dim = Util.New("Frame", {
			Name = "Dim",
			BackgroundColor3 = Theme.C.Backdrop,
			BackgroundTransparency = self._strength,
			Size = UDim2.fromScale(1, 1),
			Parent = canvas,
		})
		Theme:Paint(dim, { BackgroundColor3 = "Backdrop" })
		self._dim = dim

		-- 2. vignette: two crossed gradients darken the edges
		local vignetteV = Util.New("Frame", {
			Name = "VignetteV",
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.35,
			Size = UDim2.fromScale(1, 1),
			Parent = canvas,
		}, {
			Util.New("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.15),
					NumberSequenceKeypoint.new(0.5, 1),
					NumberSequenceKeypoint.new(1, 0.15),
				}),
			}),
		})
		local vignetteH = Util.New("Frame", {
			Name = "VignetteH",
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.4,
			Size = UDim2.fromScale(1, 1),
			Parent = canvas,
		}, {
			Util.New("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.2),
					NumberSequenceKeypoint.new(0.5, 1),
					NumberSequenceKeypoint.new(1, 0.2),
				}),
			}),
		})

		-- 3. glass sheen + accent tint
		local sheen = Util.New("Frame", {
			Name = "Sheen",
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0.965,
			Size = UDim2.fromScale(1, 1),
			Parent = canvas,
		}, {
			Util.New("UIGradient", {
				Rotation = 115,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.55),
					NumberSequenceKeypoint.new(0.42, 0.92),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})

		local tint = Util.New("Frame", {
			Name = "Tint",
			BackgroundColor3 = Theme.C.Accent,
			BackgroundTransparency = 0.965,
			Size = UDim2.fromScale(1, 1),
			Parent = canvas,
		}, {
			Util.New("UIGradient", {
				Rotation = 140,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.82),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
		Theme:Paint(tint, { BackgroundColor3 = "Accent" })

		if options.Clickable then
			local hit = Util.New("TextButton", {
				Name = "Hit",
				BackgroundTransparency = 1,
				Text = "",
				Size = UDim2.fromScale(1, 1),
				Parent = canvas,
			})
			self._hit = hit
			self.OnClick = hit.MouseButton1Click
		end

		self._layers = { dim, vignetteV, vignetteH, sheen, tint }
		return self
	end

	function Backdrop:Show(duration)
		self._visible = true
		self._canvas.Visible = true
		Util.Tween(self._canvas, { GroupTransparency = 0 }, duration or Util.Motion.Slow)
		return self
	end

	function Backdrop:Hide(duration, destroy)
		self._visible = false
		local canvas = self._canvas
		local tween = Util.Tween(canvas, { GroupTransparency = 1 }, duration or Util.Motion.Normal)
		local function finish()
			if destroy then
				canvas:Destroy()
			elseif canvas.GroupTransparency >= 0.99 then
				canvas.Visible = false
			end
		end
		if tween then tween.Completed:Once(finish) else finish() end
		return self
	end

	function Backdrop:SetStrength(value)
		self._strength = math.clamp(tonumber(value) or 0.42, 0, 1)
		self._dim.BackgroundTransparency = self._strength
		return self
	end

	function Backdrop:IsVisible()
		return self._visible
	end

	function Backdrop:Destroy()
		for _, layer in ipairs(self._layers) do Theme:Unpaint(layer) end
		self._canvas:Destroy()
	end

	Void.Backdrop = Backdrop
	return Backdrop
end
