--[[
	VoidCriptUI · Core/RichText.lua
	Markdown-ish formatting for Paragraph / Label / Notification bodies.

	Supported (Discord/Telegram flavoured):
		**bold**            __underline__
		*italic*  _italic_
		~~strike~~
		`inline code`       ```block code```
		||spoiler||         (hidden until hovered — rendered dimmed)
		[label](accent)     coloured span using a theme token or #hex
		# Heading           (line prefix, larger + bold)
		> quote             (line prefix, dim + bar)
		- bullet            (line prefix, • )

	Output is a Roblox RichText string. Everything is escaped first so user
	text containing "<" can never break the markup.
]]

return function(Void)
	local Util = Void.Util
	local Theme = Void.Theme

	local RichText = {}

	local function escape(text)
		return (tostring(text)
			:gsub("&", "&amp;")
			:gsub("<", "&lt;")
			:gsub(">", "&gt;")
			:gsub("\"", "&quot;")
			:gsub("'", "&apos;"))
	end
	RichText.Escape = escape

	local function hex(color)
		return string.format("rgb(%d,%d,%d)",
			math.floor(color.R * 255 + 0.5),
			math.floor(color.G * 255 + 0.5),
			math.floor(color.B * 255 + 0.5))
	end

	local function colorTag(color, inner)
		return ("<font color=\"%s\">%s</font>"):format(hex(color), inner)
	end

	-- Parse a single line of inline markup.
	local function inline(line)
		local out = escape(line)

		-- code blocks first so their contents are not further formatted
		local codeStore = {}
		out = out:gsub("```(.-)```", function(code)
			codeStore[#codeStore + 1] = code
			return ("\1CODEBLOCK%d\1"):format(#codeStore)
		end)
		out = out:gsub("`([^`]+)`", function(code)
			codeStore[#codeStore + 1] = code
			return ("\1CODE%d\1"):format(#codeStore)
		end)

		out = out:gsub("%*%*(.-)%*%*", "<b>%1</b>")
		out = out:gsub("__(.-)__", "<u>%1</u>")
		out = out:gsub("~~(.-)~~", "<s>%1</s>")
		out = out:gsub("%*(.-)%*", "<i>%1</i>")
		out = out:gsub("_(.-)_", "<i>%1</i>")

		out = out:gsub("||(.-)||", function(inner)
			return colorTag(Theme.C.TextDark, inner)
		end)

		-- [text](Accent) or [text](#ff00aa)
		out = out:gsub("%[(.-)%]%((.-)%)", function(label, target)
			local color = Util.FromHex(target) or Theme.Tokens[target]
			if color then return colorTag(color, label) end
			return colorTag(Theme.C.Accent, label)
		end)

		-- restore code spans with monospace + accent colour
		out = out:gsub("\1CODEBLOCK(%d+)\1", function(index)
			local code = codeStore[tonumber(index)]
			return ("<font face=\"Code\" color=\"%s\">%s</font>"):format(hex(Theme.C.AccentSoft), code)
		end)
		out = out:gsub("\1CODE(%d+)\1", function(index)
			local code = codeStore[tonumber(index)]
			return ("<font face=\"Code\" color=\"%s\">%s</font>"):format(hex(Theme.C.AccentSoft), code)
		end)

		return out
	end

	-- Full parse including line prefixes.
	function RichText.Parse(text)
		if text == nil then return "" end
		text = tostring(text)
		if text == "" then return "" end

		local lines = {}
		for line in (text .. "\n"):gmatch("(.-)\n") do
			lines[#lines + 1] = line
		end

		local out = {}
		for _, line in ipairs(lines) do
			local trimmed = line:match("^%s*(.-)%s*$")
			local heading = trimmed:match("^#%s+(.+)$")
			local quote = trimmed:match("^>%s?(.*)$")
			local bullet = trimmed:match("^[%-%*]%s+(.+)$")

			if heading then
				out[#out + 1] = ("<b><font size=\"15\">%s</font></b>"):format(inline(heading))
			elseif quote then
				out[#out + 1] = colorTag(Theme.C.TextDim, "▏ " .. inline(quote))
			elseif bullet then
				out[#out + 1] = colorTag(Theme.C.Accent, "• ") .. inline(bullet)
			else
				out[#out + 1] = inline(line)
			end
		end

		return table.concat(out, "\n")
	end

	-- Strip formatting for search indexing / plain contexts.
	function RichText.Plain(text)
		if text == nil then return "" end
		return (tostring(text)
			:gsub("```(.-)```", "%1")
			:gsub("`([^`]+)`", "%1")
			:gsub("%*%*(.-)%*%*", "%1")
			:gsub("__(.-)__", "%1")
			:gsub("~~(.-)~~", "%1")
			:gsub("%*(.-)%*", "%1")
			:gsub("_(.-)_", "%1")
			:gsub("||(.-)||", "%1")
			:gsub("%[(.-)%]%((.-)%)", "%1")
			:gsub("^#%s+", "")
			:gsub("\n#%s+", "\n")
			:gsub("^>%s?", "")
			:gsub("<[^>]->", ""))
	end

	-- Apply parsed text to a TextLabel and keep it correct across theme swaps
	-- (colours are baked into the markup, so we re-parse on theme change).
	function RichText.Bind(label, text, maid)
		label.RichText = true
		label.Text = RichText.Parse(text)
		local disconnect = Theme:OnChanged(function()
			if label.Parent then
				label.Text = RichText.Parse(label:GetAttribute("VoidSource") or text)
			end
		end)
		label:SetAttribute("VoidSource", tostring(text))
		if maid then maid:Give(disconnect) end
		return function(newText)
			text = newText
			label:SetAttribute("VoidSource", tostring(newText))
			label.Text = RichText.Parse(newText)
		end
	end

	Void.RichText = RichText
	return RichText
end
