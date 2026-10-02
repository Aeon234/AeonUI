-- Checks Profile/Schema.lua, Store.lua and Profile.lua outside the game: pristine, damaged, newer and older saved data,
-- quarantine and the fallback it causes, name rules, delete remapping, resets, dormant settings and rollback when
-- publishing fails.
-- Run from any directory with Lua 5.1: lua Tools/check_profile.lua
-- Loads the real files against stubbed globals. It proves the store logic, not the file the client writes.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

UNKNOWN = "Unknown"
SlashCmdList = {}
C_AddOns = {
	GetAddOnMetadata = function() end,
}

function CallErrorHandler(message)
	error(message, 0)
end

local luaXpcall = xpcall
function xpcall(fn, handler, ...)
	local count, args = select("#", ...), { ... }

	return luaXpcall(function()
		return fn(unpack(args, 1, count))
	end, handler)
end

function CreateFrame()
	return { RegisterEvent = function() end, UnregisterEvent = function() end, SetScript = function() end }
end

-- The client folds case for every script; this stand-in folds ASCII and the two non-ASCII letters the checks use.
local FOLD = { ["Ä"] = "ä", ["Ö"] = "ö" }

local function Fold(text)
	return (text:lower():gsub("\195[\128-\159]", FOLD))
end

function strcmputf8i(a, b)
	a, b = Fold(a), Fold(b)

	return a == b and 0 or (a < b and -1 or 1)
end

function strlenutf8(text)
	local _, count = text:gsub("[^\128-\191]", "")

	return count
end

local AUI = {}
assert(loadfile(root .. "Core/Core.lua"))("AeonUI", AUI)
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
assert(loadfile(root .. "Core/Callbacks.lua"))("AeonUI", AUI)
assert(loadfile(root .. "Profile/Schema.lua"))("AeonUI", AUI)
assert(loadfile(root .. "Profile/Store.lua"))("AeonUI", AUI)
assert(loadfile(root .. "Profile/Profile.lua"))("AeonUI", AUI)

local Schema, Store, Profile = AUI.Schema, AUI.Store, AUI.Profile

local fired = {}
AUI.Callbacks:Register("Profile", fired, function(_, path)
	fired[#fired + 1] = path or "*"
end)

local saves = 0
local saveFails = false
function Profile:Save(data)
	if saveFails then
		error("injected publish failure")
	end
	saves = saves + 1
	AeonUIDB = data
end

-- Starts the owner from scratch on the given saved data.
local function Load(data, characterID)
	AeonUIDB = data
	saves = 0
	fired = {}
	AUI.Callbacks:Register("Profile", fired, function(_, path)
		fired[#fired + 1] = path or "*"
	end)
	Profile.root, Profile.quarantined = nil, {}
	Profile:Initialize(data, characterID or "Player-1")
end

-- Harness -------------------------------------------------------------------------------------------------

local checks = 0

local function Equal(name, actual, expected)
	checks = checks + 1
	if actual ~= expected then
		io.stderr:write(("FAIL: %s: expected %s, got %s\n"):format(name, tostring(expected), tostring(actual)))
		os.exit(1)
	end
end

local function Refused(name, ok, problem)
	Equal(name .. " is refused", ok, false)
	Equal(name .. " explains itself", type(problem), "string")
end

local function Serialize(value)
	if type(value) ~= "table" then
		return type(value) == "string" and ("%q"):format(value) or tostring(value)
	end
	local keys = {}
	for key in pairs(value) do
		keys[#keys + 1] = key
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	local parts = {}
	for _, key in ipairs(keys) do
		parts[#parts + 1] = tostring(key) .. "=" .. Serialize(value[key])
	end

	return "{" .. table.concat(parts, ",") .. "}"
end

local function Valid(characterID)
	return Store:NewRoot(characterID or "Player-1")
end

-- Schema --------------------------------------------------------------------------------------------------

Equal("default width", Schema:Defaults().frames.player.width, 270)
Equal("target fills right to left", Schema:Defaults().frames.target.reverse, true)
Equal("in range", (Schema:CheckValue("frames.player.width", 300)), true)
Equal("below range", (Schema:CheckValue("frames.player.width", 10)), false)
Equal("not a number", (Schema:CheckValue("frames.player.width", "300")), false)
Equal("not finite", (Schema:CheckValue("frames.player.x", 1 / 0)), false)
Equal("NaN", (Schema:CheckValue("frames.player.x", 0 / 0)), false)
Equal("unknown path", (Schema:CheckValue("frames.player.colour", true)), false)
Equal("read falls back to the default", Schema:Read({}, "frames.target.x"), 330)
Equal("a function is not plain", Schema:IsPlain({ f = function() end }), false)
Equal("a zero key is not plain", Schema:IsPlain({ [0] = 1 }), false)
local shared = {}
Equal("a shared table is not plain", Schema:IsPlain({ a = shared, b = shared }), false)
local deep = {}
local node = deep
for _ = 1, 40 do
	node.child = {}
	node = node.child
end
Equal("too deep is not plain", Schema:IsPlain(deep), false)
Equal("branch that is not a table", (Schema:ValidateConfig({ frames = { player = 5 } })), false)
Equal("a dormant key is accepted", (Schema:ValidateConfig({ frames = { arena = { width = 9 } }, future = "x" })), true)

-- Pristine ------------------------------------------------------------------------------------------------

Load(nil)
Equal("pristine publishes a store", saves, 1)
Equal("pristine is normal", Profile.mode, "normal")
Equal("pristine activates Default", Profile.activeID, Store.DEFAULT_ID)
Equal("pristine store is saved", AeonUIDB, Profile.root)
Equal("pristine character record", AeonUIDB.charactersByID["Player-1"].activeProfileID, Store.DEFAULT_ID)
Equal("pristine reads defaults", Profile:Get("frames.playerPower.y"), -184)

-- A second character joins an existing store.
local existing = Valid("Player-1")
Load(existing, "Player-2")
Equal("new character publishes once", saves, 1)
Equal("new character starts on Default", AeonUIDB.charactersByID["Player-2"].activeProfileID, Store.DEFAULT_ID)
Equal("first character kept", AeonUIDB.charactersByID["Player-1"].activeProfileID, Store.DEFAULT_ID)
Equal("new character publishes a copy", AeonUIDB ~= existing, true)

-- Saved data that cannot be used ----------------------------------------------------------------------------

local function ExpectRecovery(name, data, newer)
	local before = Serialize(data)
	Load(data)
	Equal(name .. " enters recovery", Profile.mode, "recovery")
	Equal(name .. " publishes nothing", saves, 0)
	Equal(name .. " leaves the saved data alone", Serialize(AeonUIDB), before)
	Equal(name .. " reports newer", Profile.newer == true, newer == true)
	Equal(name .. " shows defaults", Profile:Get("frames.player.width"), 270)
	Refused(name .. " set", Profile:Set("frames.player.width", 300))
	Refused(name .. " create", Profile:Create("Mine"))
end

ExpectRecovery("an empty table", {})
ExpectRecovery("a string", "AeonUIDB")
local newer = Valid()
newer.schemaVersion = Store.SCHEMA + 1
ExpectRecovery("a newer schema", newer, true)
local older = Valid()
older.schemaVersion = 0
ExpectRecovery("an older schema without a migration", older)
local noProfiles = Valid()
noProfiles.profilesByID = {}
ExpectRecovery("no profiles", noProfiles)
local badID = Valid()
badID.profilesByID.nope = badID.profilesByID[Store.DEFAULT_ID]
ExpectRecovery("a malformed profile ID", badID)
local badCharacter = Valid()
badCharacter.charactersByID["Player-1"].specAssignments = { [0] = Store.DEFAULT_ID }
ExpectRecovery("a malformed specialization assignment", badCharacter)

local damaged = {}
Load(damaged)
Equal("explicit reset publishes a new store", (Profile:ResetStore()), true)
Equal("reset store is normal", Profile.mode, "normal")
Equal("reset store is saved", AeonUIDB, Profile.root)
Equal("reset store announces itself", fired[#fired], "*")
Load(Valid())
Refused("store reset outside recovery", Profile:ResetStore())

-- Migration -----------------------------------------------------------------------------------------------

local schemaBefore, migrationsBefore = Store.SCHEMA, Store.migrations
Store.SCHEMA = schemaBefore + 1
Store.migrations = {
	[schemaBefore] = function(data)
		data.migrated = true
	end,
}
local old = Valid()
old.schemaVersion = schemaBefore
Load(old)
Equal("migration publishes", saves, 1)
Equal("migrated store is normal", Profile.mode, "normal")
Equal("migrated schema", AeonUIDB.schemaVersion, schemaBefore + 1)
Equal("migration step ran", AeonUIDB.migrated, true)
Equal("migration keeps a backup of the original", AeonUIDB.migrationBackup.schemaVersion, schemaBefore)
Equal("migration leaves the original table alone", old.schemaVersion, schemaBefore)
Store.migrations = {
	[schemaBefore] = function()
		error("step failed")
	end,
}
local failing = Valid()
failing.schemaVersion = schemaBefore
ExpectRecovery("a failing migration", failing)
Store.SCHEMA, Store.migrations = schemaBefore, migrationsBefore

-- Shared settings --------------------------------------------------------------------------------------------

Load(Valid())
Equal("shared: a frame reads the shared value", Profile:Get("frames.focus.text.font"), "Expressway")
Equal("shared: follows a change to the shared value", (Profile:Set("text.font", "Friz Quadrata TT")), true)
Equal("shared: the frame follows", Profile:Get("frames.focus.text.font"), "Friz Quadrata TT")
Equal("shared: not custom", Profile:IsCustom("frames.focus.text.font"), false)
Equal("shared: a value equal to the shared one is saved as the frame's own",
	(Profile:Set("frames.focus.text.font", "Friz Quadrata TT")), true)
Equal("shared: now custom", Profile:IsCustom("frames.focus.text.font"), true)
Equal("shared: custom ignores the shared value", (Profile:Set("text.font", "Expressway")) and
	Profile:Get("frames.focus.text.font"), "Friz Quadrata TT")
Equal("shared: clearing", (Profile:Set("frames.focus.text.font", nil)), true)
Equal("shared: follows again", Profile:Get("frames.focus.text.font"), "Expressway")
Equal("shared: a shared setting itself is never custom", Profile:IsCustom("text.font"), false)
Equal("shared: bounds follow the shared field", (Profile:Set("frames.focus.bars.border", 9)), false)
Equal("shared: a frame resets to Shared", (Profile:Set("frames.player.bars.border", 3)) and
	(Profile:Reset("frames.player")) and Profile:IsCustom("frames.player.bars.border"), false)
Equal("shared: defaults hold no frame appearance", Schema:Defaults().frames.player.text.font, nil)

-- Quarantine ----------------------------------------------------------------------------------------------

local mixed = Valid()
mixed.profilesByID.p00000002 = {
	name = "Broken",
	schemaVersion = Schema.VERSION,
	config = { frames = { player = { width = "x" } } },
}
mixed.profilesByID.p00000003 = { name = "DEFAULT", schemaVersion = Schema.VERSION, config = {} }
mixed.profilesByID.p00000004 = { name = "Later", schemaVersion = Schema.VERSION + 1, config = {} }
mixed.nextID = 5
local brokenBefore = Serialize(mixed.profilesByID.p00000002)
Load(mixed)
Equal("inactive quarantine stays normal", Profile.mode, "normal")
Equal("bad field quarantined", type(Profile.quarantined.p00000002), "string")
Equal("case-insensitive duplicate quarantined", type(Profile.quarantined.p00000003), "string")
Equal("newer profile quarantined", type(Profile.quarantined.p00000004), "string")
Equal("valid profile kept", Profile.quarantined[Store.DEFAULT_ID], nil)
Equal("valid profiles stay editable", (Profile:Set("frames.player.width", 280)), true)
Refused("selecting a quarantined profile", Profile:Select("p00000002"))
Refused("renaming a quarantined profile", Profile:Rename("p00000002", "Fixed"))
Refused("copying a quarantined profile", Profile:Duplicate("p00000002", "Copy"))
Equal("quarantined record untouched", Serialize(AeonUIDB.profilesByID.p00000002), brokenBefore)
Refused("a name a quarantined profile holds", Profile:Create("broken"))

-- Fallback when the active profile cannot be used.
local fallback = Valid()
fallback.profilesByID[Store.DEFAULT_ID].config.frames.player.width = 400
fallback.profilesByID.p00000002 = { name = "Mine", schemaVersion = Schema.VERSION, config = { frames = { target = 5 } } }
fallback.charactersByID["Player-1"].activeProfileID = "p00000002"
fallback.charactersByID["Player-1"].specAssignments = { [62] = "p00000002" }
fallback.nextID = 3
Load(fallback)
Equal("active quarantined profile falls back", Profile.mode, "fallback")
Equal("fallback shows Default's settings", Profile:Get("frames.player.width"), 400)
Refused("editing the fallback", Profile:Set("frames.player.width", 300))
Refused("resetting the fallback", Profile:Reset())
Profile.config.frames.player.width = 123
Equal("the fallback is a disposable copy", AeonUIDB.profilesByID[Store.DEFAULT_ID].config.frames.player.width, 400)
Equal("selecting a valid profile", (Profile:Select(Store.DEFAULT_ID)), true)
Equal("selection restores normal", Profile.mode, "normal")
Equal("selection is saved", AeonUIDB.charactersByID["Player-1"].activeProfileID, Store.DEFAULT_ID)
Equal("selection leaves specialization assignments", AeonUIDB.charactersByID["Player-1"].specAssignments[62], "p00000002")

local dangling = Valid()
dangling.charactersByID["Player-1"].activeProfileID = "p00000009"
Load(dangling)
Equal("a missing active profile falls back", Profile.mode, "fallback")
Equal("the missing reference is kept", AeonUIDB.charactersByID["Player-1"].activeProfileID, "p00000009")

-- Editing -------------------------------------------------------------------------------------------------

Load(Valid())
fired = {}
Equal("set", (Profile:Set("frames.target.height", 40)), true)
Equal("set is stored", AeonUIDB.profilesByID[Store.DEFAULT_ID].config.frames.target.height, 40)
Equal("set announces its path", fired[#fired], "frames.target.height")
local count = #fired
Equal("setting the same value", (Profile:Set("frames.target.height", 40)), true)
Equal("the same value announces nothing", #fired, count)
Refused("an out-of-range value", Profile:Set("frames.target.height", 400))
Refused("a wrong type", Profile:Set("frames.target.reverse", 1))
Refused("an unknown setting", Profile:Set("frames.target.colour", 1))

-- Names and profiles ---------------------------------------------------------------------------------------

Load(Valid())
local ok, id = Profile:Create("Raid")
Equal("create", ok, true)
Equal("create activates", Profile.activeID, id)
Equal("create uses the next ID", id, "p00000002")
Equal("create uses defaults", Profile:Get("frames.player.width"), 270)
Refused("an empty name", Profile:Create("  "))
Refused("a case-insensitive duplicate", Profile:Create("RAID"))
Refused("a non-ASCII case-insensitive duplicate", (function()
	Profile:Create("Äther")

	return Profile:Create("äther")
end)())
Refused("a 33-letter name", Profile:Create(("ä"):rep(33)))
Equal("a 32-letter name", (Profile:Create(("ö"):rep(32))), true)
Refused("the default profile's name", Profile:Create("default"))
Equal("rename", (Profile:Rename(id, "Raid Night")), true)
Equal("rename to a new case of its own name", (Profile:Rename(id, "RAID NIGHT")), true)
Refused("renaming the default profile", Profile:Rename(Store.DEFAULT_ID, "Main"))

Profile:Select(id)
Profile:Set("frames.player.width", 333)
Profile.root.profilesByID[id].config.future = { kept = true }
local copied
ok, copied = Profile:Duplicate(id, "Raid Copy")
Equal("duplicate", ok, true)
Equal("duplicate activates", Profile.activeID, copied)
Equal("duplicate copies settings", Profile:Get("frames.player.width"), 333)
Equal("duplicate copies dormant settings", AeonUIDB.profilesByID[copied].config.future.kept, true)

-- Dormant settings survive edits; resets remove them only inside their scope.
Profile:Set("frames.player.height", 50)
Equal("dormant settings survive an edit", AeonUIDB.profilesByID[copied].config.future.kept, true)
Profile.root.profilesByID[copied].config.frames.player.future = 1
Equal("section reset", (Profile:Reset("frames.player")), true)
Equal("section reset restores defaults", Profile:Get("frames.player.width"), 270)
Equal("section reset clears dormant settings in scope", AeonUIDB.profilesByID[copied].config.frames.player.future, nil)
Equal("section reset keeps dormant settings outside", AeonUIDB.profilesByID[copied].config.future.kept, true)
Refused("an unknown reset scope", Profile:Reset("frames.nothing"))
Profile:Set("frames.player.width", 300)
Profile:Set("frames.target.width", 300)
Profile:Set("frames.focus.width", 300)
Equal("several scopes reset together", (Profile:Reset({ "frames.player", "frames.target" })), true)
Equal("first scope reset", Profile:Get("frames.player.width"), 270)
Equal("second scope reset", Profile:Get("frames.target.width"), 270)
Equal("other scopes kept", Profile:Get("frames.focus.width"), 300)
Refused("any unknown scope refuses the reset", Profile:Reset({ "frames.player", "frames.nothing" }))
Equal("full reset", (Profile:Reset()), true)
Equal("full reset clears every dormant setting", AeonUIDB.profilesByID[copied].config.future, nil)

-- Delete remaps every reference.
local multi = Valid("Player-1")
multi.profilesByID.p00000002 = { name = "Alt", schemaVersion = Schema.VERSION, config = {} }
multi.charactersByID["Player-2"] = { activeProfileID = "p00000002", specAssignments = { [250] = "p00000002" } }
multi.charactersByID["Player-1"].activeProfileID = "p00000002"
multi.nextID = 3
Load(multi)
Refused("deleting with itself as replacement", Profile:Delete("p00000002", "p00000002"))
Refused("deleting with a missing replacement", Profile:Delete("p00000002", "p00000077"))
Equal("delete", (Profile:Delete("p00000002", Store.DEFAULT_ID)), true)
Equal("delete removes the profile", AeonUIDB.profilesByID.p00000002, nil)
Equal("delete remaps this character", Profile.activeID, Store.DEFAULT_ID)
Equal("delete remaps other characters", AeonUIDB.charactersByID["Player-2"].activeProfileID, Store.DEFAULT_ID)
Equal("delete remaps assignments", AeonUIDB.charactersByID["Player-2"].specAssignments[250], Store.DEFAULT_ID)
Refused("deleting the last profile", Profile:Delete(Store.DEFAULT_ID, Store.DEFAULT_ID))

local quarantinedDelete = Valid()
quarantinedDelete.profilesByID.p00000002 = { name = "Broken", schemaVersion = 9, config = {} }
quarantinedDelete.nextID = 3
Load(quarantinedDelete)
Equal("a quarantined profile can be deleted", (Profile:Delete("p00000002", Store.DEFAULT_ID)), true)

-- IDs continue past the highest in use even when nextID lags.
local lagging = Valid()
lagging.profilesByID.p00000007 = { name = "Seven", schemaVersion = Schema.VERSION, config = {} }
Load(lagging)
ok, id = Profile:Create("Eight")
Equal("IDs never reuse one in use", id, "p00000008")

-- Rollback ------------------------------------------------------------------------------------------------

Load(Valid())
local published = AeonUIDB
local before = Serialize(published)
saveFails = true
Refused("a create whose publish fails", Profile:Create("Lost"))
saveFails = false
Equal("a failed publish keeps the store", Profile.root, published)
Equal("a failed publish keeps the saved data", Serialize(AeonUIDB), before)
Equal("a failed publish keeps the active profile", Profile.activeID, Store.DEFAULT_ID)
Equal("the name is free after a failed create", (Profile:Create("Lost")), true)

Load(Valid())
before = Serialize(AeonUIDB)
local okCommit, problem = Profile:Commit(function(candidate)
	candidate.profilesByID[Store.DEFAULT_ID].config.frames.player.width = "x"
end)
Refused("a change that would damage a profile", okCommit, problem)
Equal("a refused change publishes nothing", Serialize(AeonUIDB), before)
okCommit = Profile:Commit(function()
	error("mid-change failure")
end)
Equal("an error inside a change is contained", okCommit, false)
Equal("an error inside a change publishes nothing", Serialize(AeonUIDB), before)

-- Editor session helpers ------------------------------------------------------------------------------------------

Load(Valid())
local snapshot = Profile:Snapshot()
Equal("snapshot names the profile", snapshot and snapshot.id, Store.DEFAULT_ID)
Equal("a fresh snapshot is unchanged", Profile:Changed(snapshot), false)
Equal("several settings in one change", (Profile:SetPaths({ ["frames.player.x"] = 12.5, ["frames.player.y"] = -40 })),
	true)
Equal("first path saved", Profile:Get("frames.player.x"), 12.5)
Equal("second path saved", Profile:Get("frames.player.y"), -40)
Equal("a change shows", Profile:Changed(snapshot), true)
Refused("a bad value refuses every path", Profile:SetPaths({ ["frames.player.x"] = 0, ["frames.player.width"] = 1 }))
Equal("nothing saved from a refused change", Profile:Get("frames.player.x"), 12.5)
Equal("restore", (Profile:Restore(snapshot)), true)
Equal("restored value", Profile:Get("frames.player.x"), -330)
Equal("restored is unchanged", Profile:Changed(snapshot), false)
Equal("a preference saves quietly", Profile:SetEditorPreference("snap", false), true)
Equal("a preference reads back", Profile:EditorPreference("snap", true), false)
Equal("a preference does not change the profile", Profile:Changed(snapshot), false)

io.stdout:write(("check_profile: %d checks passed\n"):format(checks))
