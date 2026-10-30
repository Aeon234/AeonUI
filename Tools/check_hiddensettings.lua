-- Checks HiddenSettings/ outside the game: the loot sparkle's held values, what a save keeps, what a hold writes and
-- what a restore puts back.
-- Run from any directory with Lua 5.1: lua Tools/check_hiddensettings.lua
-- Loads the real files against stubbed globals. Exits non-zero on the first failed check.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

WOW_PROJECT_ID = 1
SlashCmdList = {}
C_AddOns = {
	GetAddOnMetadata = function(_, field)
		return field == "Version" and "dev" or "AeonUI"
	end,
}

function CallErrorHandler(message)
	error(message, 0)
end

-- WoW's xpcall forwards extra arguments to the function, as Lua 5.2 does; Lua 5.1's does not.
local luaXpcall = xpcall
function xpcall(fn, handler, ...)
	local count, args = select("#", ...), { ... }

	return luaXpcall(function()
		return fn(unpack(args, 1, count))
	end, handler)
end

C_Timer = { After = function(_, callback)
	callback()
end }

function Mixin(object, ...)
	for index = 1, select("#", ...) do
		for key, value in pairs((select(index, ...))) do
			object[key] = value
		end
	end

	return object
end

local inCombat = false
function InCombatLockdown()
	return inCombat
end

-- Console variables: the client's, and each write.
local cvars, lacking, readOnly, refused, writes = {}, {}, {}, {}, {}
C_CVar = {
	GetCVar = function(name)
		return cvars[name]
	end,
	SetCVar = function(name, value)
		assert(not inCombat, "a console variable written in combat")
		assert(type(value) == "string", "a console variable written with a " .. type(value))
		if refused[name] then
			return false
		end
		cvars[name] = value
		writes[#writes + 1] = name .. "=" .. value

		return true
	end,
	-- value, defaultValue, isStoredServerAccount, isStoredServerCharacter, isLockedFromUser, isSecure, isReadOnly
	GetCVarInfo = function(name)
		if lacking[name] then
			return nil
		end

		return cvars[name], cvars[name], true, false, false, false, readOnly[name] == true
	end,
}

local eventFrame
function CreateFrame()
	eventFrame = { events = {} }
	function eventFrame:RegisterEvent(event)
		self.events[event] = true
	end
	function eventFrame:UnregisterEvent(event)
		self.events[event] = nil
	end
	function eventFrame:SetScript(_, handler)
		self.onEvent = handler
	end

	return eventFrame
end

local function Fire(event, ...)
	if eventFrame.events[event] then
		eventFrame.onEvent(eventFrame, event, ...)
	end
end

-- Addon table ---------------------------------------------------------------------------------------------

local AUI = {}
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
assert(loadfile(root .. "Core/Core.lua"))("AeonUI", AUI)
AUI.can = { lootSparkle = true }

local global = {}
AUI.Profile = {
	Global = function()
		return global
	end,
}

for _, file in ipairs({ "Core/Callbacks.lua", "Core/Events.lua", "HiddenSettings/Options.lua",
	"HiddenSettings/CVarHolder.lua", "HiddenSettings/HiddenSettings.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local HiddenSettings = AUI.HiddenSettings

local Options = AUI.HiddenSettingsOptions

-- Harness -------------------------------------------------------------------------------------------------

local checks = 0

local function Equal(name, actual, expected)
	checks = checks + 1
	if actual ~= expected then
		io.stderr:write(("FAIL: %s: expected %s, got %s\n"):format(name, tostring(expected), tostring(actual)))
		os.exit(1)
	end
end

---@param entries AUIHeldCVar[]
local function Join(entries)
	local parts = {}
	for index, entry in ipairs(entries) do
		parts[index] = entry.name .. "=" .. entry.value
	end

	return table.concat(parts, " ")
end

---@param map table<string, string>
local function Keys(map)
	local names = {}
	for name in pairs(map) do
		names[#names + 1] = name
	end
	table.sort(names)
	for index, name in ipairs(names) do
		names[index] = name .. "=" .. map[name]
	end

	return table.concat(names, " ")
end

-- Rules ---------------------------------------------------------------------------------------------------

local current = { graphicsOutlineMode = "2", OutlineEngineMode = "2", outlineModeShowLootEffectWhenDisabled = "0" }
local function read(name)
	return current[name]
end

Equal("held values", Join(Options.LOOT_SPARKLE), "outlineModeShowLootEffectWhenDisabled=1 graphicsOutlineMode=0 "
	.. "raidGraphicsOutlineMode=0 OutlineEngineMode=0 RAIDOutlineEngineMode=0")
Equal("graphics presets reset them", table.concat(Options.LOOT_SPARKLE_TRIGGERS, " "),
	"graphicsQuality raidGraphicsQuality")
Equal("pending skips lacking and equal", Join(Options.Pending(Options.LOOT_SPARKLE, read)),
	"outlineModeShowLootEffectWhenDisabled=1 graphicsOutlineMode=0 OutlineEngineMode=0")
local saved = Options.Save(Options.LOOT_SPARKLE, read, { graphicsOutlineMode = "3" })
Equal("save keeps existing, skips lacking", Keys(saved),
	"OutlineEngineMode=2 graphicsOutlineMode=3 outlineModeShowLootEffectWhenDisabled=0")
current.graphicsOutlineMode = "0"
Equal("restore writes what differs", Join(Options.Restore(Options.LOOT_SPARKLE, saved, read)), "graphicsOutlineMode=3")
current.OutlineEngineMode = nil
Equal("restore skips lacking", Join(Options.Restore(Options.LOOT_SPARKLE, { OutlineEngineMode = "2" }, read)), "")
Equal("restore in held order", Join(Options.Restore(Options.LOOT_SPARKLE, { graphicsOutlineMode = "1",
	outlineModeShowLootEffectWhenDisabled = "1" }, read)), "outlineModeShowLootEffectWhenDisabled=1 graphicsOutlineMode=1")
Equal("restore only held names and text values", Join(Options.Restore(Options.LOOT_SPARKLE, { autoLootDefault = "1",
	graphicsOutlineMode = true, outlineModeShowLootEffectWhenDisabled = "1" }, read)),
	"outlineModeShowLootEffectWhenDisabled=1")
Equal("watches ignore case", tostring(Options.Watches(Options.LOOT_SPARKLE_TRIGGERS, "graphicsquality")), "true")
Equal("watches others", tostring(Options.Watches(Options.LOOT_SPARKLE_TRIGGERS, "autoLootDefault")), "false")
Equal("watches nil", tostring(Options.Watches(Options.LOOT_SPARKLE_TRIGGERS, nil)), "false")

-- Quest Items -----------------------------------------------------------------------------------------------

local OWN = { outlineModeShowLootEffectWhenDisabled = "0", graphicsOutlineMode = "2", raidGraphicsOutlineMode = "2",
	OutlineEngineMode = "2", RAIDOutlineEngineMode = "2", graphicsQuality = "7", raidGraphicsQuality = "5" }

---The player's own values, changed by `changes`, and no writes yet; then a start, as after a login.
---@param changes table<string, string>?
local function Login(changes)
	for name, value in pairs(OWN) do
		cvars[name] = value
	end
	for name, value in pairs(changes or {}) do
		cvars[name] = value
	end
	for index = #writes, 1, -1 do
		writes[index] = nil
	end
	HiddenSettings:Start()
end

local function Held()
	return table.concat({ cvars.outlineModeShowLootEffectWhenDisabled, cvars.graphicsOutlineMode,
		cvars.raidGraphicsOutlineMode, cvars.OutlineEngineMode, cvars.RAIDOutlineEngineMode }, " ")
end

local function Saved()
	local state = global and global.hiddenSettings
	local saved = state and state.saved and state.saved.lootSparkles

	return saved and Keys(saved) or "none"
end

Login()
Equal("never enabled writes nothing", #writes, 0)
Equal("and follows nothing", eventFrame.events.CVAR_UPDATE, nil)
Equal("starts off", tostring(HiddenSettings:IsQuestItems()), "false")

HiddenSettings:SetQuestItems(true)
Equal("enable saves the player's values", Saved(), "OutlineEngineMode=2 RAIDOutlineEngineMode=2 graphicsOutlineMode=2 "
	.. "outlineModeShowLootEffectWhenDisabled=0 raidGraphicsOutlineMode=2")
Equal("then holds", Held(), "1 0 0 0 0")
Equal("the row is on", tostring(HiddenSettings:IsQuestItems()), "true")

cvars.graphicsOutlineMode = "3"
Fire("CVAR_UPDATE", "graphicsOutlineMode")
Equal("preset reset re-applied", cvars.graphicsOutlineMode, "0")
cvars.graphicsOutlineMode = "3"
Fire("CVAR_UPDATE", "graphicsoutlinemode")
Equal("lowercase CVAR_UPDATE", cvars.graphicsOutlineMode, "0")
cvars.raidGraphicsOutlineMode, cvars.graphicsQuality = "2", "3"
Fire("CVAR_UPDATE", "graphicsquality")
Equal("a graphics preset re-applies", cvars.raidGraphicsOutlineMode, "0")
local count = #writes
Fire("CVAR_UPDATE", "autoLootDefault")
Equal("another setting's change is ignored", #writes, count)

HiddenSettings:SetQuestItems(false)
Equal("disable restores", Held(), "0 2 2 2 2")
Equal("and clears the save", Saved(), "none")
Equal("and stops following", eventFrame.events.CVAR_UPDATE, nil)
count = #writes
cvars.graphicsOutlineMode = "3"
Fire("CVAR_UPDATE", "graphicsOutlineMode")
Equal("a later change is the player's", #writes, count)

cvars.graphicsOutlineMode = "1"
HiddenSettings:SetQuestItems(true)
Equal("re-enable saves afresh", Saved(), "OutlineEngineMode=2 RAIDOutlineEngineMode=2 graphicsOutlineMode=1 "
	.. "outlineModeShowLootEffectWhenDisabled=0 raidGraphicsOutlineMode=2")
HiddenSettings:SetQuestItems(false)
Equal("and restores that", cvars.graphicsOutlineMode, "1")

Login()
inCombat = true
HiddenSettings:SetQuestItems(true)
HiddenSettings:SetQuestItems(false)
Equal("nothing written in combat", #writes, 0)
inCombat = false
Fire("PLAYER_REGEN_ENABLED")
Equal("latest state after combat", Held(), "0 2 2 2 2")
Equal("leaves no save", Saved(), "none")
Equal("and stops waiting", eventFrame.events.PLAYER_REGEN_ENABLED, nil)

inCombat = true
HiddenSettings:SetQuestItems(true)
inCombat = false
Fire("PLAYER_REGEN_ENABLED")
Equal("a hold in combat applies after it", Held(), "1 0 0 0 0")
HiddenSettings:SetQuestItems(false)

global = {}
lacking.OutlineEngineMode = true
Login()
HiddenSettings:SetQuestItems(true)
Equal("lacking CVar not saved", Saved(), "RAIDOutlineEngineMode=2 graphicsOutlineMode=2 "
	.. "outlineModeShowLootEffectWhenDisabled=0 raidGraphicsOutlineMode=2")
Equal("lacking CVar not written", cvars.OutlineEngineMode, "2")
HiddenSettings:SetQuestItems(false)
lacking.OutlineEngineMode = nil

global = {}
readOnly.RAIDOutlineEngineMode = true
Login()
HiddenSettings:SetQuestItems(true)
Equal("read-only CVar not saved", Saved(), "OutlineEngineMode=2 graphicsOutlineMode=2 "
	.. "outlineModeShowLootEffectWhenDisabled=0 raidGraphicsOutlineMode=2")
Equal("read-only CVar not written", cvars.RAIDOutlineEngineMode, "2")
HiddenSettings:SetQuestItems(false)
readOnly.RAIDOutlineEngineMode = nil

Login()
HiddenSettings:SetQuestItems(true)
refused.graphicsOutlineMode = true
HiddenSettings:SetQuestItems(false)
Equal("a refused restore keeps the save", Saved(), "graphicsOutlineMode=2")
refused.graphicsOutlineMode = nil
HiddenSettings:Start()
Equal("and restores it at the next login", cvars.graphicsOutlineMode .. " " .. Saved(), "2 none")

global = { hiddenSettings = { saved = { lootSparkles = { graphicsOutlineMode = {}, autoLootDefault = "1" } } } }
Login()
Equal("a damaged save writes nothing", #writes, 0)

global = { hiddenSettings = { saved = { lootSparkles = { graphicsOutlineMode = "2" } } } }
Login({ graphicsOutlineMode = "0" })
Equal("stale save restored at login", table.concat(writes, " "), "graphicsOutlineMode=2")
Equal("and cleared", Saved(), "none")

global = { hiddenSettings = { lootSparkles = { questItems = true },
	saved = { lootSparkles = { graphicsOutlineMode = "3" } } } }
Login()
Equal("save kept at login while on", Saved(), "OutlineEngineMode=2 RAIDOutlineEngineMode=2 graphicsOutlineMode=3 "
	.. "outlineModeShowLootEffectWhenDisabled=0 raidGraphicsOutlineMode=2")
Equal("and held", Held(), "1 0 0 0 0")
HiddenSettings:SetQuestItems(false)
Equal("restoring the older save", cvars.graphicsOutlineMode, "3")

global = nil
Login()
HiddenSettings:SetQuestItems(true)
Equal("no saved data, no writes", #writes, 0)
Equal("and the row reads off", tostring(HiddenSettings:IsQuestItems()), "false")

print(("check_hiddensettings: %d checks passed"):format(checks))
