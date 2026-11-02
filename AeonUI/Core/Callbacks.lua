local AUI = select(2, ...)

---@class AUICallbacks
---@field channels table<string, AUICallbackChannel>
---@field firing integer
local Callbacks = {
	channels = {},
	firing = 0,
}
AUI.Callbacks = Callbacks

---@class AUICallbackEntry
---@field owner table
---@field handler fun(owner: table, ...: any)
---@field dead boolean

---@class AUICallbackChannel
---@field entries AUICallbackEntry[]
---@field byOwner table<table, AUICallbackEntry>
---@field live integer entries not marked dead
---@field dirty boolean a dead entry is waiting to be compacted

---@param name string
---@return AUICallbackChannel
local function ChannelFor(name)
	local channel = Callbacks.channels[name]

	if not channel then
		channel = { entries = {}, byOwner = {}, live = 0, dirty = false }
		Callbacks.channels[name] = channel
	end

	return channel
end

---@param name string
---@param channel AUICallbackChannel
local function Compact(name, channel)
	local entries = channel.entries

	for index = #entries, 1, -1 do
		if entries[index].dead then
			table.remove(entries, index)
		end
	end

	channel.dirty = false

	if #entries == 0 then
		Callbacks.channels[name] = nil
	end
end

---One handler per owner per channel; registering twice replaces the first handler.
---@param name string
---@param owner table
---@param handler fun(owner: table, ...: any)
function Callbacks:Register(name, owner, handler)
	local channel = ChannelFor(name)
	local existing = channel.byOwner[owner]

	if existing then
		existing.handler = handler

		return
	end

	local entry = { owner = owner, handler = handler, dead = false }

	channel.entries[#channel.entries + 1] = entry
	channel.byOwner[owner] = entry
	channel.live = channel.live + 1
end

---@param name string
---@param owner table
---@return boolean removed
function Callbacks:Unregister(name, owner)
	local channel = self.channels[name]
	local entry = channel and channel.byOwner[owner]

	if not entry then
		return false
	end

	entry.dead = true
	channel.byOwner[owner] = nil
	channel.live = channel.live - 1
	channel.dirty = true

	if self.firing == 0 then
		Compact(name, channel)
	end

	return true
end

---@param owner table
function Callbacks:UnregisterAll(owner)
	for name in pairs(self.channels) do
		self:Unregister(name, owner)
	end
end

---@param name string
---@return integer count listeners still live on this channel
function Callbacks:Count(name)
	local channel = self.channels[name]

	return channel and channel.live or 0
end

---@param name string
---@param ... any
function Callbacks:Fire(name, ...)
	local channel = self.channels[name]

	if not channel then
		return
	end

	self.firing = self.firing + 1

	local entries = channel.entries

	for index = 1, #entries do
		local entry = entries[index]

		if not entry.dead then
			xpcall(entry.handler, CallErrorHandler, entry.owner, ...)
		end
	end

	self.firing = self.firing - 1

	if self.firing == 0 and channel.dirty then
		Compact(name, channel)
	end
end
