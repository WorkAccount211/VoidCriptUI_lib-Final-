--[[
	VoidCriptUI · Core/Config.lua
	JSON config system with auto-save, a config manager and per-game profiles
	(roadmap #16, #21, #22, #23, #24).

	Public API:
		Library:SaveConfig(name)        -- write flags + window state + theme
		Library:LoadConfig(name)        -- apply a saved config
		Library:ListConfigs()
		Library:DeleteConfig(name)
		Library:RenameConfig(old, new)
		Library:ExportConfig(name)      -- returns a shareable string
		Library:ImportConfig(str, name)

	Layout on disk:
		workspace/VoidCript/
			Config.json           <- default
			<name>.json
			games/<PlaceId>.json  <- automatic per-game profile
			default.txt           <- name of the config to autoload

	Values are serialised through typed envelopes ({__t="color"} etc.) so
	Color3 / EnumItem / keybind descriptors survive a JSON round-trip. A
	`__version` field lets us migrate older files instead of discarding them.
]]

return function(Void)
	local HttpService = game:GetService("HttpService")

	local Config = {
		Folder = "VoidCript",
		File = "Config",
		Enabled = false,
		AutoSave = true,
		AutoSaveDelay = 1.5,
		Version = 3,
		_debounce = nil,
		_lastError = nil,
	}

	-- ── filesystem shims (executors differ) ─────────────────────────────
	local fs = {
		write = writefile,
		read = readfile,
		isFile = isfile,
		isFolder = isfolder,
		makeFolder = makefolder,
		delete = delfile,
		listFiles = listfiles,
	}

	function Config:HasFileSystem()
		return type(fs.write) == "function" and type(fs.read) == "function" and type(fs.isFile) == "function"
	end

	local function ensureFolder(path)
		if type(fs.makeFolder) ~= "function" then return false end
		if fs.isFolder and fs.isFolder(path) then return true end
		local ok = pcall(fs.makeFolder, path)
		return ok
	end

	function Config:Root()
		return self.Folder
	end

	function Config:Path(name)
		return ("%s/%s.json"):format(self.Folder, name or self.File)
	end

	function Config:GamePath()
		return ("%s/games/%s.json"):format(self.Folder, tostring(game.PlaceId))
	end

	function Config:EnsureTree()
		if not self:HasFileSystem() then return false end
		ensureFolder(self.Folder)
		ensureFolder(self.Folder .. "/games")
		return true
	end

	-- ── typed serialisation ─────────────────────────────────────────────
	local function serialize(kind, value)
		if typeof(value) == "Color3" then
			return { __t = "color", hex = Void.Util.ToHex(value) }
		end
		if typeof(value) == "EnumItem" then
			return { __t = "enum", enum = tostring(value.EnumType), name = value.Name }
		end
		if typeof(value) == "UDim2" then
			return { __t = "udim2", xs = value.X.Scale, xo = value.X.Offset, ys = value.Y.Scale, yo = value.Y.Offset }
		end
		if typeof(value) == "Vector2" then
			return { __t = "vector2", x = value.X, y = value.Y }
		end
		if type(value) == "table" then
			-- keybind descriptor
			if value.Key ~= nil or value.Mouse ~= nil then
				if value.__t == nil and (typeof(value.Key) == "EnumItem" or type(value.Mouse) == "string") then
					return Void.Keybinds.Serialize(value)
				end
			end
			-- colour + alpha pair
			if typeof(value.Color) == "Color3" then
				return { __t = "coloralpha", hex = Void.Util.ToHex(value.Color), alpha = value.Alpha or 1, rainbow = value.Rainbow or false }
			end
			-- plain array/map: recurse
			local out = {}
			for k, v in pairs(value) do
				out[tostring(k)] = serialize(kind, v)
			end
			out.__map = true
			return out
		end
		return value
	end

	local function deserialize(raw)
		if type(raw) ~= "table" then return raw end
		local t = raw.__t
		if t == "color" then
			return Void.Util.FromHex(raw.hex) or Color3.new(1, 1, 1)
		elseif t == "coloralpha" then
			return { Color = Void.Util.FromHex(raw.hex) or Color3.new(1, 1, 1), Alpha = raw.alpha or 1, Rainbow = raw.rainbow or false }
		elseif t == "enum" then
			local enumName = tostring(raw.enum):gsub("^Enum%.", "")
			local enumType = Enum[enumName]
			if enumType then
				local ok, item = pcall(function() return enumType[raw.name] end)
				if ok then return item end
			end
			return nil
		elseif t == "keybind" then
			return Void.Keybinds.Deserialize(raw)
		elseif t == "udim2" then
			return UDim2.new(raw.xs, raw.xo, raw.ys, raw.yo)
		elseif t == "vector2" then
			return Vector2.new(raw.x, raw.y)
		elseif raw.__map then
			local out = {}
			for k, v in pairs(raw) do
				if k ~= "__map" then
					out[tonumber(k) or k] = deserialize(v)
				end
			end
			return out
		end
		-- plain array
		local out = {}
		for k, v in pairs(raw) do out[k] = deserialize(v) end
		return out
	end

	Config.Serialize = serialize
	Config.Deserialize = deserialize

	-- ── snapshot / restore ──────────────────────────────────────────────
	function Config:Snapshot()
		local flags = {}

		-- Values restored earlier for elements that have not been built yet
		-- (lazy tabs) must be written back, or saving before the user opened
		-- every tab would silently discard their settings.
		for flag, value in pairs(Void.Flags.Pending) do
			local ok, encoded = pcall(serialize, nil, value)
			if ok then flags[flag] = encoded end
		end

		for flag, control in pairs(Void.Flags.Controls) do
			if control._cfg == nil or control._cfg.SaveToConfig ~= false then
				local ok, raw = pcall(function()
					return control.GetRaw and control:GetRaw() or control:Get()
				end)
				if ok and raw ~= nil then
					flags[flag] = serialize(control._kind, raw)
				end
			else
				-- explicitly excluded: make sure a stale pending value does not
				-- sneak back in
				flags[flag] = nil
			end
		end

		local windows = {}
		for _, window in ipairs(Void.Windows or {}) do
			if window._serializeState then
				windows[window.Id or window.Name or tostring(#windows + 1)] = window:_serializeState()
			end
		end

		return {
			__version = self.Version,
			__saved = os.time(),
			__game = game.PlaceId,
			Flags = flags,
			Windows = windows,
			Theme = Void.Theme:Serialize(),
			Scale = { Multiplier = Void.Scale.Multiplier, Compact = Void.Scale.Compact },
			Interface = Void.InterfaceSettings and Void.InterfaceSettings:Snapshot() or nil,
		}
	end

	-- Migration hook: older files get upgraded in place instead of dropped.
	function Config:Migrate(data)
		local version = tonumber(data.__version) or 1
		if version >= self.Version then return data end

		if version == 1 then
			-- v1 stored flags at the top level and colours as {r,g,b}
			local flags = data.Flags or {}
			for key, value in pairs(data) do
				if not key:match("^__") and key ~= "Flags" and key ~= "Windows" and key ~= "Theme" then
					flags[key] = value
					data[key] = nil
				end
			end
			for key, value in pairs(flags) do
				if type(value) == "table" and value.__t == "color" and value.r then
					flags[key] = { __t = "color", hex = Void.Util.ToHex(Color3.new(value.r, value.g, value.b)) }
				end
			end
			data.Flags = flags
			version = 2
		end

		if version == 2 then
			-- v2 stored keybinds as {__t="key", name=...}
			for key, value in pairs(data.Flags or {}) do
				if type(value) == "table" and value.__t == "key" then
					data.Flags[key] = { __t = "keybind", Key = value.name, Modifiers = {} }
				end
			end
			version = 3
		end

		data.__version = self.Version
		Void.Log:Info("migrated config from v%d to v%d", tonumber(data.__version) or 1, self.Version)
		return data
	end

	function Config:Apply(data)
		data = self:Migrate(data)

		if data.Theme then
			pcall(function() Void.Theme:Deserialize(data.Theme) end)
		end
		if data.Scale then
			if data.Scale.Multiplier then Void.Scale:SetMultiplier(data.Scale.Multiplier) end
			if data.Scale.Compact ~= nil then Void.Scale:SetCompact(data.Scale.Compact) end
		end

		local applied, skipped = 0, 0
		for flag, raw in pairs(data.Flags or {}) do
			local control = Void.Flags.Controls[flag]
			if control then
				local value = deserialize(raw)
				local ok, err = pcall(function() control:Set(value, true) end)
				if ok then
					applied = applied + 1
				else
					Void.Log:Warn("could not apply flag '%s': %s", flag, tostring(err))
				end
			else
				-- No element yet (lazy tab). Park the value: Flags:Register
				-- applies it the moment the element is created.
				Void.Flags:SetPending(flag, deserialize(raw))
				skipped = skipped + 1
			end
		end

		for id, state in pairs(data.Windows or {}) do
			for _, window in ipairs(Void.Windows or {}) do
				if (window.Id or window.Name) == id and window._restoreState then
					pcall(function() window:_restoreState(state) end)
				end
			end
		end

		if data.Interface and Void.InterfaceSettings then
			pcall(function() Void.InterfaceSettings:Restore(data.Interface) end)
		end

		Void.Dependencies:EvaluateAll()
		Void.Log:Info("config applied — %d flags restored, %d pending", applied, skipped)
		return applied, skipped
	end

	-- ── read / write ────────────────────────────────────────────────────
	function Config:Save(name, silent)
		if not self:HasFileSystem() then
			self._lastError = "no filesystem"
			if not silent then Void.Log:Warn("SaveConfig: this executor has no file API") end
			return false, "no filesystem"
		end
		self:EnsureTree()
		name = name or self.File

		local data = self:Snapshot()
		local okEncode, encoded = pcall(HttpService.JSONEncode, HttpService, data)
		if not okEncode then
			Void.Log:Error("SaveConfig failed to encode: %s", tostring(encoded))
			return false, encoded
		end
		local okWrite, err = pcall(fs.write, self:Path(name), encoded)
		if not okWrite then
			Void.Log:Error("SaveConfig failed to write '%s': %s", name, tostring(err))
			return false, err
		end
		if not silent then
			Void.Log:Info("config '%s' saved (%d flags)", name, Void.Flags:Count())
		end
		return true
	end

	function Config:Load(name, silent)
		if not self:HasFileSystem() then
			if not silent then Void.Log:Warn("LoadConfig: this executor has no file API") end
			return false, "no filesystem"
		end
		name = name or self.File
		local path = self:Path(name)
		if not fs.isFile(path) then
			if not silent then Void.Log:Warn("config '%s' does not exist", name) end
			return false, "missing"
		end
		local okRead, content = pcall(fs.read, path)
		if not okRead then
			Void.Log:Error("could not read config '%s': %s", name, tostring(content))
			return false, content
		end
		local okDecode, data = pcall(HttpService.JSONDecode, HttpService, content)
		if not okDecode or type(data) ~= "table" then
			Void.Log:Error("config '%s' is not valid JSON", name)
			return false, "corrupt"
		end
		self:Apply(data)
		if not silent then Void.Log:Info("config '%s' loaded", name) end
		return true
	end

	function Config:List()
		if not self:HasFileSystem() or type(fs.listFiles) ~= "function" then return {} end
		local ok, files = pcall(fs.listFiles, self.Folder)
		if not ok then return {} end
		local out = {}
		for _, path in ipairs(files) do
			local name = tostring(path):match("([^/\\]+)%.json$")
			if name then out[#out + 1] = name end
		end
		table.sort(out)
		return out
	end

	function Config:Delete(name)
		if not self:HasFileSystem() or type(fs.delete) ~= "function" then return false end
		local path = self:Path(name)
		if not fs.isFile(path) then return false end
		local ok = pcall(fs.delete, path)
		if ok then Void.Log:Info("config '%s' deleted", name) end
		return ok
	end

	function Config:Rename(oldName, newName)
		if not self:HasFileSystem() then return false end
		local from = self:Path(oldName)
		if not fs.isFile(from) then return false end
		local ok, content = pcall(fs.read, from)
		if not ok then return false end
		pcall(fs.write, self:Path(newName), content)
		if type(fs.delete) == "function" then pcall(fs.delete, from) end
		Void.Log:Info("config '%s' renamed to '%s'", oldName, newName)
		return true
	end

	-- ── export / import as a string (roadmap #23) ───────────────────────
	local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

	local function encode64(data)
		return ((data:gsub(".", function(x)
			local r, b = "", x:byte()
			for i = 8, 1, -1 do r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and "1" or "0") end
			return r
		end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(x)
			if #x < 6 then return "" end
			local c = 0
			for i = 1, 6 do c = c + (x:sub(i, i) == "1" and 2 ^ (6 - i) or 0) end
			return B64:sub(c + 1, c + 1)
		end) .. ({ "", "==", "=" })[#data % 3 + 1])
	end

	local function decode64(data)
		data = tostring(data):gsub("[^" .. B64 .. "=]", "")
		return (data:gsub("=", ""):gsub(".", function(x)
			local r, f = "", (B64:find(x) - 1)
			for i = 6, 1, -1 do r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0") end
			return r
		end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
			if #x ~= 8 then return "" end
			local c = 0
			for i = 1, 8 do c = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0) end
			return string.char(c)
		end))
	end

	function Config:Export(name)
		local data
		if name and self:HasFileSystem() and fs.isFile(self:Path(name)) then
			local ok, content = pcall(fs.read, self:Path(name))
			data = ok and content or nil
		end
		if not data then
			local ok, encoded = pcall(HttpService.JSONEncode, HttpService, self:Snapshot())
			data = ok and encoded or nil
		end
		if not data then return nil end
		return "VOIDCFG1:" .. encode64(data)
	end

	function Config:Import(str, saveAs)
		if type(str) ~= "string" then return false, "not a string" end
		local payload = str:match("^VOIDCFG1:(.+)$") or str
		local okDecode, raw = pcall(decode64, payload)
		if not okDecode then return false, "bad base64" end
		local okJson, data = pcall(HttpService.JSONDecode, HttpService, raw)
		if not okJson or type(data) ~= "table" then return false, "bad payload" end
		self:Apply(data)
		if saveAs then
			pcall(function()
				self:EnsureTree()
				fs.write(self:Path(saveAs), raw)
			end)
		end
		Void.Log:Info("config imported from string")
		return true
	end

	-- ── autosave (roadmap: killer feature) ──────────────────────────────
	function Config:RequestAutoSave()
		if not self.Enabled or not self.AutoSave then return end
		if not self:HasFileSystem() then return end
		if self._debounce then task.cancel(self._debounce) end
		self._debounce = task.delay(self.AutoSaveDelay, function()
			self._debounce = nil
			self:Save(self.File, true)
			if self.PerGame then
				pcall(function()
					self:EnsureTree()
					local ok, encoded = pcall(HttpService.JSONEncode, HttpService, self:Snapshot())
					if ok then fs.write(self:GamePath(), encoded) end
				end)
			end
		end)
	end

	function Config:FlushAutoSave()
		if self._debounce then
			task.cancel(self._debounce)
			self._debounce = nil
			self:Save(self.File, true)
		end
	end

	function Config:Configure(settings)
		settings = settings or {}
		self.Enabled = settings.Enabled ~= false
		self.Folder = settings.FolderName or settings.Folder or self.Folder
		self.File = settings.FileName or settings.File or self.File
		self.AutoSave = settings.AutoSave ~= false
		self.AutoSaveDelay = settings.AutoSaveDelay or self.AutoSaveDelay
		self.PerGame = settings.PerGame or false
		if self.Enabled then self:EnsureTree() end
		return self
	end

	Void.Config = Config
	return Config
end
