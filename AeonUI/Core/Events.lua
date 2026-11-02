local AUI = select(2, ...)

local Callbacks = AUI.Callbacks

---@class AUIEvents
---@field private registered table<string, true>
---@field private pending table<string, fun()>
local Events = {
	registered = {},
	pending = {},
}
AUI.Events = Events

local CHANNEL = "event:"

local frame = CreateFrame("Frame")

frame:SetScript("OnEvent", function(_, event, ...)
	Callbacks:Fire(CHANNEL .. event, event, ...)
end)

---@param event string
---@param owner table
---@param handler fun(owner: table, event: string, ...: any)
function Events:Register(event, owner, handler)
	if not self.registered[event] then
		self.registered[event] = true
		frame:RegisterEvent(event)
	end

	Callbacks:Register(CHANNEL .. event, owner, handler)
end

---@param event string
---@param owner table
function Events:Unregister(event, owner)
	if not Callbacks:Unregister(CHANNEL .. event, owner) then
		return
	end

	if Callbacks:Count(CHANNEL .. event) == 0 then
		self.registered[event] = nil
		frame:UnregisterEvent(event)
	end
end

---@param owner table
function Events:UnregisterAll(owner)
	for event in pairs(self.registered) do
		self:Unregister(event, owner)
	end
end

---@param key string
---@param work fun()
function Events:Coalesce(key, work)
	self:Merge(key, 0, work)
end

---@param key string
---@param delay number seconds; 0 means the next frame
---@param work fun()
function Events:Merge(key, delay, work)
	local waiting = self.pending[key] ~= nil

	self.pending[key] = work

	if waiting then
		return
	end

	C_Timer.After(delay, function()
		local scheduled = self.pending[key]
		self.pending[key] = nil

		if scheduled then
			scheduled()
		end
	end)
end

---@param key string
function Events:Cancel(key)
	self.pending[key] = nil
end
