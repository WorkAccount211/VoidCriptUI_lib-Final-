--[[
	VoidCriptUI · Core/Maid.lua
	Centralised connection / instance manager (roadmap #36).

	Every connection, instance and thread the library creates is added to a
	Maid. Window:Destroy() / Library:Unload() sweeps them in one pass, so
	nothing keeps running after the UI is gone — this is what makes the
	library idempotent on re-execution.
]]

return function(Void)
	local Maid = {}
	Maid.__index = Maid

	function Maid.new(name)
		return setmetatable({
			_name = name or "Maid",
			_tasks = {},
			_dead = false,
		}, Maid)
	end

	-- Accepts: RBXScriptConnection, custom Signal connection, Instance,
	-- function, thread, or another Maid.
	function Maid:Give(item)
		if item == nil then return nil end
		if self._dead then
			-- already cleaned: dispose immediately instead of leaking
			self:_dispose(item)
			return item
		end
		table.insert(self._tasks, item)
		return item
	end
	Maid.Add = Maid.Give

	function Maid:GiveMany(...)
		for i = 1, select("#", ...) do
			self:Give((select(i, ...)))
		end
	end

	function Maid:_dispose(item)
		local t = typeof and typeof(item) or type(item)
		local ok, err = pcall(function()
			if type(item) == "function" then
				item()
			elseif t == "thread" or type(item) == "thread" then
				pcall(task.cancel, item)
			elseif t == "RBXScriptConnection" then
				item:Disconnect()
			elseif t == "Instance" then
				item:Destroy()
			elseif type(item) == "table" then
				if type(item.Disconnect) == "function" then
					item:Disconnect()
				elseif type(item.Destroy) == "function" then
					item:Destroy()
				elseif type(item.Clean) == "function" then
					item:Clean()
				end
			end
		end)
		if not ok and Void.Log then
			Void.Log:Debug(("maid '%s' failed to dispose an item: %s"):format(self._name, tostring(err)))
		end
	end

	-- Remove a single item early without waiting for a full sweep.
	function Maid:Remove(item)
		for i = #self._tasks, 1, -1 do
			if self._tasks[i] == item then
				table.remove(self._tasks, i)
				self:_dispose(item)
				return true
			end
		end
		return false
	end

	function Maid:Clean()
		local list = self._tasks
		self._tasks = {}
		for i = #list, 1, -1 do
			self:_dispose(list[i])
		end
	end
	Maid.DoCleaning = Maid.Clean

	function Maid:Destroy()
		self:Clean()
		self._dead = true
	end

	function Maid:Count()
		return #self._tasks
	end

	Void.Maid = Maid
	Void.RootMaid = Maid.new("Root")
	return Maid
end
