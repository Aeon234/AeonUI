-- Checks Alerts/ outside the game: each event's group and sound kit on the Master channel, a battleground pop sounded
-- once, premade group invites, boss emotes only when they ask, secret payloads, groups turned off, and the events
-- followed only while some group is on; and Joined Group in Chat: the activity linked to its Adventure Guide page at
-- the group's difficulty, named without a link when it has none, nothing printed when any part of the listing is
-- secret or unknown, and the join followed only while it is on.
-- Run from any directory with Lua 5.1: lua Tools/check_alerts.lua
-- Loads the real files against stubbed globals. Exits non-zero on the first failed check.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

WOW_PROJECT_ID = 1
SlashCmdList = {}
StaticPopupDialogs = {}
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

-- Stands in for a secret value; `issecretvalue` knows it.
local SECRET = {}
function issecretvalue(value)
	return value == SECRET
end

local eventFrame
function CreateFrame()
	local frame = { events = {} }
	function frame:RegisterEvent(event)
		self.events[event] = true
	end
	function frame:UnregisterEvent(event)
		self.events[event] = nil
	end
	function frame:SetScript(_, handler)
		self.onEvent = handler
	end
	eventFrame = frame

	return frame
end

local function Fire(event, ...)
	if eventFrame.events[event] then
		eventFrame.onEvent(eventFrame, event, ...)
	end
end

SOUNDKIT = { READY_CHECK = 8960, UI_PET_BATTLES_PVP_THROUGH_QUEUE = 36609, TELL_MESSAGE = 3081,
	IG_PLAYER_INVITE = 880, PVP_THROUGH_QUEUE = 8459, RAID_BOSS_EMOTE_WARNING = 12197,
	UI_RAID_BOSS_WHISPER_WARNING = 37666 }
local played = {}
function PlaySound(kit, channel, noDuplicates)
	played[#played + 1] = kit .. "@" .. channel .. (noDuplicates and "" or " duplicates")
end

-- Stands in for a table Lua may not index; `canaccesstable` knows it.
local FORBIDDEN = {}
function canaccesstable(value)
	return value ~= FORBIDDEN
end

LFG_LIST_APP_INVITE_ACCEPTED = "Joined"
local results, activities = {}, {}
C_LFGList = {
	GetSearchResultInfo = function(id)
		return results[id]
	end,
	GetActivityInfoTable = function(id)
		return activities[id]
	end,
}
local instances = { [2660] = 1271 }
C_EncounterJournal = { GetInstanceForGameMap = function(mapID)
	return instances[mapID]
end }

local printed = {}
function print(message)
	printed[#printed + 1] = message
end

local battlefields = {}
function GetBattlefieldStatus(index)
	return battlefields[index]
end

-- Addon table ---------------------------------------------------------------------------------------------

local AUI = {}
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
assert(loadfile(root .. "Core/Core.lua"))("AeonUI", AUI)
AUI.can = {}

for _, file in ipairs({ "Core/Callbacks.lua", "Core/Events.lua", "Profile/Schema.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local values = {}
AUI.Profile = {
	Get = function(_, path)
		local value = values[path]
		if value == nil then
			local field = AUI.Schema:Field(path)
			value = field and field.default
		end

		return value
	end,
}

local function Set(path, value)
	values[path] = value
	AUI.Callbacks:Fire("Profile", path)
end

for _, file in ipairs({ "AeonUI_QoL/Alerts/Options.lua", "AeonUI_QoL/Alerts/SoundAlerts.lua", "AeonUI_QoL/Alerts/PremadeJoined.lua",
	"AeonUI_QoL/Alerts/Alerts.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local Options = AUI.AlertOptions

-- Harness -------------------------------------------------------------------------------------------------

local checks = 0

local function Equal(name, actual, expected)
	checks = checks + 1
	if actual ~= expected then
		io.stderr:write(("FAIL: %s: expected %s, got %s\n"):format(name, tostring(expected), tostring(actual)))
		os.exit(1)
	end
end

---Fires an event and returns what it played, joined.
local function Played(event, ...)
	played = {}
	Fire(event, ...)

	return table.concat(played, ",")
end

-- Rules ---------------------------------------------------------------------------------------------------

Equal("a move to confirm is a pop", Options.BattlefieldPopped("queued", "confirm"), true)
Equal("once", Options.BattlefieldPopped("confirm", "confirm"), false)
Equal("other statuses are not", Options.BattlefieldPopped(nil, "queued"), false)
for _, group in ipairs(Options.SOUND_GROUPS) do
	Equal(group .. " is off by default", AUI.Profile:Get(Options.SoundPath(group)), false)
end

-- Sound Alerts --------------------------------------------------------------------------------------------

AUI.Alerts:Start()
AUI.Alerts:Start()
Equal("with every group off, nothing is followed", next(eventFrame.events), nil)

for _, group in ipairs(Options.SOUND_GROUPS) do
	Set(Options.SoundPath(group), true)
end
Equal("a dungeon finder proposal", Played("LFG_PROPOSAL_SHOW"), "8960@Master")
Equal("a pet battle match", Played("PET_BATTLE_QUEUE_PROPOSE_MATCH"), "36609@Master")
Equal("a ready check", Played("READY_CHECK", "Leader", 30), "8960@Master")
Equal("a role poll", Played("ROLE_POLL_BEGIN"), "8960@Master")
Equal("a dungeon finder role check", Played("LFG_ROLE_CHECK_SHOW"), "8960@Master")
Equal("a whisper", Played("CHAT_MSG_WHISPER", SECRET, SECRET), "3081@Master")
Equal("a Battle.net whisper", Played("CHAT_MSG_BN_WHISPER", SECRET), "3081@Master")
Equal("a party invite", Played("PARTY_INVITE_REQUEST", "Thrall"), "880@Master")

battlefields[1] = "queued"
Equal("a battleground queue joined is quiet", Played("UPDATE_BATTLEFIELD_STATUS", 1), "")
battlefields[1] = "confirm"
Equal("its pop sounds", Played("UPDATE_BATTLEFIELD_STATUS", 1), "8459@Master")
Equal("once", Played("UPDATE_BATTLEFIELD_STATUS", 1), "")
battlefields[1] = "active"
Played("UPDATE_BATTLEFIELD_STATUS", 1)
battlefields[1] = "confirm"
Equal("a later pop sounds again", Played("UPDATE_BATTLEFIELD_STATUS", 1), "8459@Master")

Equal("a premade group invite", Played("LFG_LIST_APPLICATION_STATUS_UPDATED", 7, "invited", "applied", "Group"),
	"880@Master")
Equal("other application changes are quiet", Played("LFG_LIST_APPLICATION_STATUS_UPDATED", 7, "declined", "applied"), "")
Equal("a secret status is quiet", Played("LFG_LIST_APPLICATION_STATUS_UPDATED", 7, SECRET, "applied"), "")

Equal("a boss emote that warns", Played("RAID_BOSS_EMOTE", "text", "Boss", 5, true), "12197@Master")
Equal("one that does not is quiet", Played("RAID_BOSS_EMOTE", "text", "Boss", 5, false), "")
Equal("a boss whisper that warns", Played("RAID_BOSS_WHISPER", "text", "Boss", 5, true), "37666@Master")
Equal("a secret warning is quiet", Played("RAID_BOSS_WHISPER", "text", "Boss", 5, SECRET), "")

Set(Options.SoundPath("whispers"), false)
Equal("a group turned off is quiet", Played("CHAT_MSG_WHISPER"), "")
Equal("the others still sound", Played("READY_CHECK"), "8960@Master")

SOUNDKIT.READY_CHECK = nil
Equal("a sound kit the client lacks is skipped", Played("READY_CHECK"), "")
SOUNDKIT.READY_CHECK = 8960

for _, group in ipairs(Options.SOUND_GROUPS) do
	Set(Options.SoundPath(group), false)
end
Equal("with every group off, nothing is followed again", next(eventFrame.events), nil)
Equal("and the queues are forgotten", next(AUI.SoundAlerts.battlefields), nil)
values = {}
Set(Options.SoundPath("readyChecks"), true)
Equal("one group on follows again", Played("READY_CHECK"), "8960@Master")

-- Joined Group in Chat ----------------------------------------------------------------------------------

---Fires a join and returns what it printed, without the prefix.
local function Joined(id)
	printed = {}
	Fire("LFG_LIST_JOINED_GROUP", id, "a group name")

	return printed[1] and printed[1]:gsub("^.-|r: ", "") or "nothing"
end

results[1] = { activityIDs = { 1284 } }
activities[1284] = { fullName = "Ara-Kara, City of Echoes (Mythic Keystone)", mapID = 2660, difficultyID = 8 }
Equal("off by default", AUI.Profile:Get(Options.PREMADE_JOINED_PATH), false)
Equal("off: the join is not followed", Joined(1), "nothing")
AUI.can.premadeJoined = true
Set(Options.PREMADE_JOINED_PATH, true)
Equal("on: Blizzard's Joined and the activity, linked at its difficulty", Joined(1),
	"Joined |cff66bbff|Hjournal:0:1271:8|h[Ara-Kara, City of Echoes (Mythic Keystone)]|h|r")
results[2] = { activityIDs = { 16 } }
activities[16] = { fullName = "Questing", mapID = 0, difficultyID = 0 }
Equal("an activity with no instance is named without a link", Joined(2), "Joined Questing")
results[3] = { activityIDs = { 99 } }
activities[99] = { fullName = "Somewhere", mapID = 1234 }
Equal("a map with no Adventure Guide page too", Joined(3), "Joined Somewhere")
Equal("an unknown listing prints nothing", Joined(4), "nothing")
Equal("a secret listing ID prints nothing", Joined(SECRET), "nothing")
results[5] = FORBIDDEN
Equal("a listing that cannot be read prints nothing", Joined(5), "nothing")
results[6] = { activityIDs = FORBIDDEN }
Equal("nor activities that cannot be read", Joined(6), "nothing")
results[7] = { activityIDs = { SECRET } }
Equal("nor a secret activity", Joined(7), "nothing")
results[8] = { activityIDs = { 1285 } }
activities[1285] = { fullName = SECRET, mapID = 2660, difficultyID = 8 }
Equal("nor a secret name", Joined(8), "nothing")
activities[1285] = { fullName = "Ara-Kara, City of Echoes (Mythic Keystone)", mapID = SECRET, difficultyID = 8 }
Equal("a secret map: named without a link", Joined(8), "Joined Ara-Kara, City of Echoes (Mythic Keystone)")
Set(Options.PREMADE_JOINED_PATH, false)
Equal("off again: no longer followed", eventFrame.events.LFG_LIST_JOINED_GROUP, nil)

io.stdout:write(("check_alerts: %d checks passed\n"):format(checks))
