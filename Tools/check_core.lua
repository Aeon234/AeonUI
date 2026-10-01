-- Checks Core/Core.lua, Callbacks.lua and Events.lua outside the game: metadata, chat output, the slash command,
-- callback dispatch and isolation, event registration and coalescing.
-- Run from any directory with Lua 5.1: lua Tools/check_core.lua
-- Loads the real Core files against stubbed globals. Exits non-zero on the first failed check.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

UNKNOWN = "Unknown"
SlashCmdList = {}

local metadata = { Title = "AeonUI", Version = "@project-version@" }
C_AddOns = {
	GetAddOnMetadata = function(_, field)
		return metadata[field]
	end,
}

local errors = {}
function CallErrorHandler(message)
	errors[#errors + 1] = message
end

-- WoW's xpcall forwards extra arguments to the function, as Lua 5.2 does; Lua 5.1's does not.
local luaXpcall = xpcall
function xpcall(fn, handler, ...)
	local count, args = select("#", ...), { ... }

	return luaXpcall(function()
		return fn(unpack(args, 1, count))
	end, handler)
end

local timers = {}
C_Timer = {
	After = function(delay, callback)
		timers[#timers + 1] = { delay = delay, callback = callback }
	end,
}

local function RunTimers()
	local due = timers
	timers = {}
	for _, timer in ipairs(due) do
		timer.callback()
	end
end

-- A Frame, modeled with only the methods Events.lua calls.
local eventFrame
function CreateFrame(kind)
	assert(kind == "Frame", "unexpected frame type " .. tostring(kind))
	local frame = { events = {}, scripts = {} }
	function frame:RegisterEvent(event)
		self.events[event] = true
	end
	function frame:UnregisterEvent(event)
		self.events[event] = nil
	end
	function frame:SetScript(name, handler)
		self.scripts[name] = handler
	end
	eventFrame = frame

	return frame
end

local printed = {}
function print(text)
	printed[#printed + 1] = text
end

local AUI = {}
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
assert(loadfile(root .. "Core/Core.lua"))("AeonUI", AUI)
assert(loadfile(root .. "Core/Callbacks.lua"))("AeonUI", AUI)
assert(loadfile(root .. "Core/Events.lua"))("AeonUI", AUI)

-- Harness -------------------------------------------------------------------------------------------------

local checks = 0

local function Equal(name, actual, expected)
	checks = checks + 1
	if actual ~= expected then
		io.stderr:write(("FAIL: %s: expected %s, got %s\n"):format(name, tostring(expected), tostring(actual)))
		os.exit(1)
	end
end

-- Core ----------------------------------------------------------------------------------------------------

Equal("name", AUI.name, "AeonUI")
Equal("title", AUI.title, "AeonUI")
Equal("unsubstituted version reads as dev", AUI.version, "dev")

AUI:Print("%d frames", 2)
Equal("print formats", printed[#printed], "|cff9e754aAeonUI|r: 2 frames")
AUI:Print("100%")
Equal("print without arguments leaves % alone", printed[#printed], "|cff9e754aAeonUI|r: 100%")

SlashCmdList.AEONUI("")
Equal("slash without a window warns", printed[#printed]:find("not available yet", 1, true) ~= nil, true)

local opened = {}
AUI.Settings = {
	Open = function(_, page)
		opened[#opened + 1] = page or "<none>"
	end,
}
SlashCmdList.AEONUI("")
Equal("bare slash opens the window", opened[#opened], "<none>")
SlashCmdList.AEONUI("  Target  extra")
Equal("slash word opens that page, lowercased", opened[#opened], "target")
Equal("both slash aliases", SLASH_AEONUI1 .. " " .. SLASH_AEONUI2, "/aeonui /aui")

-- Callbacks -----------------------------------------------------------------------------------------------

local Callbacks = AUI.Callbacks
local log = {}
local first, second, third = {}, {}, {}

Callbacks:Register("Test", first, function(_, value)
	log[#log + 1] = "first " .. value
end)
Callbacks:Register("Test", second, function(_, value)
	log[#log + 1] = "second " .. value
end)
Callbacks:Fire("Test", 1)
Equal("fires in registration order", table.concat(log, ","), "first 1,second 1")

log = {}
Callbacks:Register("Test", first, function(_, value)
	log[#log + 1] = "first again " .. value
end)
Callbacks:Fire("Test", 2)
Equal("registering twice replaces in place", table.concat(log, ","), "first again 2,second 2")

log = {}
Callbacks:Register("Test", third, function()
	error("boom")
end)
Callbacks:Register("Test", first, function()
	log[#log + 1] = "first"
	Callbacks:Unregister("Test", second)
end)
Callbacks:Fire("Test", 3)
Equal("an error reaches the error handler", #errors, 1)
Equal("an unregister during firing takes effect at once", table.concat(log, ","), "first")
Equal("count drops after unregister", Callbacks:Count("Test"), 2)

Callbacks:UnregisterAll(first)
Callbacks:UnregisterAll(third)
Equal("an empty channel is removed", Callbacks.channels.Test, nil)
Equal("unregistering an unknown owner reports nothing removed", Callbacks:Unregister("Test", first), false)

-- Events --------------------------------------------------------------------------------------------------

local Events = AUI.Events
local owner, other = {}, {}
local seen = {}

Events:Register("PLAYER_LOGIN", owner, function(_, event, argument)
	seen[#seen + 1] = event .. ":" .. tostring(argument)
end)
Events:Register("PLAYER_LOGIN", other, function()
	seen[#seen + 1] = "other"
end)
Equal("first listener registers the event", eventFrame.events.PLAYER_LOGIN, true)

eventFrame.scripts.OnEvent(eventFrame, "PLAYER_LOGIN", "x")
Equal("dispatch reaches every listener", table.concat(seen, ","), "PLAYER_LOGIN:x,other")

Events:Unregister("PLAYER_LOGIN", owner)
Equal("event stays registered while a listener remains", eventFrame.events.PLAYER_LOGIN, true)
Events:UnregisterAll(other)
Equal("last listener gone unregisters the event", eventFrame.events.PLAYER_LOGIN, nil)

local runs = {}
Events:Coalesce("redraw", function()
	runs[#runs + 1] = "a"
end)
Events:Coalesce("redraw", function()
	runs[#runs + 1] = "b"
end)
Equal("a burst schedules one timer", #timers, 1)
RunTimers()
Equal("the latest work runs once", table.concat(runs, ","), "b")

Events:Merge("save", 0.5, function()
	runs[#runs + 1] = "saved"
end)
Equal("merge waits the given delay", timers[1].delay, 0.5)
Events:Cancel("save")
RunTimers()
Equal("cancelled work does not run", runs[#runs], "b")

print = _G.print
io.stdout:write(("check_core: %d checks passed\n"):format(checks))
