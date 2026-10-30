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

-- Stands in for a secret value; `issecretvalue` knows it.
local SECRET = {}
function issecretvalue(value)
	return value == SECRET
end

local clock = 100
function GetTime()
	return clock
end

-- Tickers, recorded; `Tick` runs the live ones once.
local tickers = {}
C_Timer.NewTicker = function(interval, callback)
	local ticker = { interval = interval, callback = callback }
	function ticker:Cancel()
		self.cancelled = true
	end
	tickers[#tickers + 1] = ticker

	return ticker
end

local function LiveTickers()
	local live = 0
	for _, ticker in ipairs(tickers) do
		if not ticker.cancelled then
			live = live + 1
		end
	end

	return live
end

local function Tick()
	for _, ticker in ipairs(tickers) do
		if not ticker.cancelled then
			ticker.callback()
		end
	end
end

-- A texture: what it was given, and the methods a Texture has that the code uses.
local function Texture()
	local texture = { points = {} }
	function texture:SetTexture(file) self.file = file end
	function texture:GetTexture() return self.file end
	function texture:GetAtlas() return self.atlas end
	function texture:SetBlendMode(mode) self.blend = mode end
	function texture:SetVertexColor(r, g, b, a) self.color = { r, g, b, a } end
	function texture:SetPoint(...) self.points[#self.points + 1] = { ... } end
	function texture:ClearAllPoints() self.points = {} end
	function texture:SetSize(width, height) self.width, self.height = width, height end
	function texture:SetRotation(angle) self.rotation = angle end
	function texture:SetSnapToPixelGrid(snap) self.snap = snap end
	function texture:SetTexelSnappingBias(bias) self.bias = bias end
	function texture:Hide() self.shown = false end
	function texture:Show() self.shown = true end

	return texture
end

-- A frame: the first one made is `Core/Events.lua`'s; the rest are recorded by name.
local eventFrame ---@type table
local frames = {}
function CreateFrame(_, name, parent)
	local frame = { events = {}, shown = true, points = {}, parent = parent, name = name, textures = {} }
	function frame:RegisterEvent(event)
		self.events[event] = true
	end
	function frame:UnregisterEvent(event)
		self.events[event] = nil
	end
	function frame:SetScript(script, handler)
		if script == "OnEvent" then
			self.onEvent = handler
		else
			self[script] = handler
		end
	end
	function frame:SetSize(width, height) self.width, self.height = width, height end
	function frame:Show() self.shown = true end
	function frame:Hide() self.shown = false end
	function frame:IsShown() return self.shown end
	function frame:SetParent(newParent) self.parent = newParent end
	function frame:GetParent() return self.parent end
	function frame:ClearAllPoints() self.points = {} end
	function frame:SetPoint(...) self.points[#self.points + 1] = { ... } end
	function frame:SetFrameLevel(level) self.level = level end
	function frame:GetFrameLevel() return self.level or 5 end
	function frame:SetIgnoreParentAlpha(ignore) self.ignoreParentAlpha = ignore end
	function frame:CreateTexture()
		local texture = Texture()
		self.textures[#self.textures + 1] = texture

		return texture
	end
	if not eventFrame then
		eventFrame = frame
	end
	if name then
		frames[name] = frame
		_G[name] = frame
	end

	return frame
end
UIParent = { CreateTexture = Texture }

-- The `softinteract` unit and the nameplates.
local soft = {}
local plates = {}
local function Unit(unit)
	if unit == "softinteract" then
		return soft
	end

	return soft.plateUnit == unit and soft or {}
end
function UnitExists(unit) return Unit(unit).unit == true end
function UnitIsGameObject(unit) return Unit(unit).object == true end
function UnitName(unit) return Unit(unit).name end
function UnitGUID(unit) return Unit(unit).guid end
function UnitIsDead(unit) return Unit(unit).dead == true end
function UnitIsUnit(a, b)
	return Unit(a) == Unit(b) and Unit(a) == soft
end
function UnitIsInInteractRange(unit) return Unit(unit).inRange end
function CanLootUnit(guid)
	if guid ~= soft.guid or not soft.loot then
		return false, false
	end

	return soft.loot[1], soft.loot[2]
end
C_NamePlate = {
	GetNamePlateForUnit = function(unit)
		if unit == "softinteract" and soft.plateByToken == false then
			return nil
		end
		if unit == "softinteract" or unit == soft.plateUnit then
			return soft.plate
		end

		return plates[unit]
	end,
}

-- Cursors: file IDs for paths, and the cursor the target shows.
local FILE_IDS = { ["Interface\\Cursor\\Mine"] = 1001, ["Interface\\Cursor\\UnableMine"] = 1002,
	["Interface\\Cursor\\GatherHerbs"] = 1003, ["Interface\\Cursor\\Quest"] = 1004, ["Interface\\Cursor\\Interact"] = 1005,
	["Interface\\Cursor\\Mail"] = 1006 }
function GetFileIDFromPath(path)
	return FILE_IDS[path]
end
function SetUnitCursorTexture(texture, unit)
	local target = Unit(unit)
	texture.file, texture.atlas = target.cursor, target.atlas

	return target.cursor ~= nil or target.atlas ~= nil
end

-- The quest log and tooltips.
Enum = { TooltipDataLineType = { QuestObjective = 8 } }
local quests = {}
C_QuestLog = {
	GetNumQuestLogEntries = function() return #quests end,
	GetQuestIDForLogIndex = function(index) return quests[index] and quests[index].id end,
	GetQuestObjectives = function(id)
		for _, quest in ipairs(quests) do
			if quest.id == id then
				return quest.objectives
			end
		end
	end,
	UnitIsRelatedToActiveQuest = function(unit) return Unit(unit).questRelated == true end,
}
-- The loot window: each slot's sources, as `GetLootSourceInfo` gives them (GUID, quantity pairs).
local lootSlots = {}
function GetNumLootItems()
	return #lootSlots
end
function GetLootSourceInfo(slot)
	return unpack(lootSlots[slot] or {})
end

local tooltipReads = 0
C_TooltipInfo = {
	GetUnit = function(unit)
		tooltipReads = tooltipReads + 1

		return { lines = Unit(unit).tooltipQuest and { { type = 0 }, { type = 8 } } or { { type = 0 } } }
	end,
}

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
AUI.can = { lootSparkle = true, approachSparkles = true }

local global = {}
AUI.Profile = {
	Global = function()
		return global
	end,
}

for _, file in ipairs({ "Core/Callbacks.lua", "Core/Events.lua", "HiddenSettings/Options.lua",
	"HiddenSettings/CVarHolder.lua", "HiddenSettings/Target.lua", "HiddenSettings/Glints.lua",
	"HiddenSettings/Approach.lua", "HiddenSettings/HiddenSettings.lua" }) do
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

-- Approached objects: rules ------------------------------------------------------------------------------

Equal("soft target values", Join(Options.SOFT_TARGET), "SoftTargetInteract=3 SoftTargetInteractRange=60 "
	.. "SoftTargetInteractArc=2 SoftTargetInteractOnlyInRange=0 SoftTargetIconInteract=1 SoftTargetIconGameObject=1 "
	.. "SoftTargetLowPriorityIcons=1 SoftTargetNameplateInteract=0")
Equal("the gate", Options.GATE, "SoftTargetNameplateInteract")
Equal("sparkle types with chests and bobber", table.concat(Options.SPARKLE_TYPES, " "),
	"ore herbs questObjects corpses chests bobber")

---@param name string?
local function Cursor(name)
	local kind, unable = Options.CursorType(name)

	return tostring(kind) .. (unable and " unable" or "")
end
Equal("cursor types", table.concat({ Cursor("Mine"), Cursor("UnableMine"), Cursor("Cursor_Crosshair_UnableMine_64"),
	Cursor("Interface\\Cursor\\GatherHerbs"), Cursor("QuestTurnIn"), Cursor("PickLock"), Cursor("Point"), Cursor(nil) },
	", "), "ore, ore unable, ore unable, herbs, questObjects, chests, nil, nil")
Equal("objective normalize", Options.NormalizeObjective("Soaked Saw: 0/1"), "soaked saw")
Equal("objective normalize spaces and apostrophes",
	Options.NormalizeObjective("- Kurzen\194\160Supplies\226\128\153s 3 / 8 :"), "kurzen supplies's")
local objectives = { "soaked saw", "supplies" }
Equal("objective match both ways", tostring(Options.MatchesObjective("Soaked Saw", objectives)) .. " "
	.. tostring(Options.MatchesObjective("Crate of Supplies", objectives)) .. " "
	.. tostring(Options.MatchesObjective("Copper Vein", objectives)), "true true false")
Equal("short names never match", tostring(Options.MatchesObjective("Saw", { "saw" })) .. " "
	.. tostring(Options.MatchesObjective(nil, objectives)), "false false")
Equal("short objectives only match whole", tostring(Options.MatchesObjective("Sawmill Crate", { "saw" })), "false")
Equal("states", table.concat({ Options.State(false, false), Options.State(true, false), Options.State(nil, false),
	Options.State(true, true), Options.State(nil, true), Options.State(false, true) }, " "),
	"far ready ready locked far far")

local shown, pending, since = Options.Propose("far", nil, nil, "ready", 10)
Equal("proposal waits", shown .. " " .. tostring(pending), "far ready")
shown, pending, since = Options.Propose(shown, pending, since, "ready", 10.1)
Equal("still waiting before 0.15", shown, "far")
shown, pending, since = Options.Propose(shown, pending, since, "ready", 10.15)
Equal("shows after 0.15", shown .. " " .. tostring(pending), "ready nil")
shown, pending, since = Options.Propose(shown, nil, nil, "locked", 20)
shown, pending, since = Options.Propose(shown, pending, since, "locked", 20.5)
Equal("locked waits 0.6", shown, "ready")
shown, pending, since = Options.Propose(shown, pending, since, "locked", 20.6)
Equal("locked after 0.6", shown, "locked")
shown, pending = Options.Propose(shown, "far", 30, "locked", 30.1)
Equal("the shown state cancels a pending one", shown .. " " .. tostring(pending), "locked nil")

local function Blend(...)
	local alpha, speed, r, g, b = Options.Blend(...)

	return ("%.2f %.2f %.2f %.2f %.2f"):format(alpha, speed, r, g, b)
end
Equal("blend ready", Blend(1, 1, 0), "1.00 1.20 1.00 0.88 0.52")
Equal("blend far", Blend(1, 0, 0), "0.55 0.80 1.00 0.88 0.52")
Equal("blend locked", Blend(1, 0, 1), "0.25 0.40 0.62 0.62 0.62")
Equal("blend appearing", Blend(0, 1, 0), "0.00 1.20 1.00 0.88 0.52")

Equal("chest cursors", table.concat({ Cursor("LootAll"), Cursor("UnablePickLock"), Cursor("Pickup"),
	Cursor("Interact"), Cursor("Mail"), Cursor("UnableSpeak"), Cursor("Interface\\Cursor\\Taxi") }, ", "),
	"chests, chests unable, chests, other, service, service unable, service")
Equal("object ID from a GUID", tostring(Options.ObjectID("GameObject-0-1-2-3-35591-0000AB")) .. " "
	.. tostring(Options.ObjectID("Creature-0-1-2-3-299-0000AB")) .. " " .. tostring(Options.ObjectID(nil)), "35591 nil nil")
Equal("the bobber", Options.BOBBER_ID, 35591)
local words = Options.ChestWords("Chest  strongbox Coffer")
Equal("chest words", table.concat(words, " "), "chest strongbox coffer")
Equal("names a chest", table.concat({ tostring(Options.NamesChest("Battered Chest", words)),
	tostring(Options.NamesChest("Large Iron-Bound Strongbox", words)), tostring(Options.NamesChest("Chesterfield", words)),
	tostring(Options.NamesChest("Mailbox", words)), tostring(Options.NamesChest("Copper Vein", words)),
	tostring(Options.NamesChest(nil, words)) }, " "), "true true true false false false")
local chineseWords = Options.ChestWords("宝箱 箱子")
Equal("Chinese chest words, without the mailbox", table.concat({ tostring(Options.NamesChest("破损的箱子", chineseWords)),
	tostring(Options.NamesChest("宝箱", chineseWords)), tostring(Options.NamesChest("邮箱", chineseWords)),
	tostring(Options.NamesChest("工具箱", chineseWords)) }, " "), "true true false false")
local list = {}
for id = 1, Options.CONTAINER_CAP do
	list[id] = id
end
Equal("learn skips a listed ID", tostring(Options.Learn(list, 7, Options.CONTAINER_CAP)) .. " " .. #list, "false 500")
Equal("cap 500 drops the oldest", tostring(Options.Learn(list, 9001, Options.CONTAINER_CAP)) .. " " .. #list .. " "
	.. list[1] .. " " .. list[#list], "true 500 2 9001")

-- The gate: a held value that moves -------------------------------------------------------------------------

for _, entry in ipairs(Options.SOFT_TARGET) do
	cvars[entry.name] = "9"
end
for index = #writes, 1, -1 do
	writes[index] = nil
end
local gateSave = {}
local gate = AUI.CreateCVarHolder("gateCheck", Options.SOFT_TARGET, {}, function()
	return gateSave
end, function()
	gateSave = {}
end)
gate:Hold()
Equal("gate starts closed", cvars.SoftTargetNameplateInteract, "0")
gate:Change(Options.GATE, "1")
Equal("gate opens", cvars.SoftTargetNameplateInteract, "1")
cvars.SoftTargetNameplateInteract = "0"
Fire("CVAR_UPDATE", "SoftTargetNameplateInteract")
Equal("gate held at its moving value", cvars.SoftTargetNameplateInteract, "1")
Equal("the rules keep their value", Options.SOFT_TARGET[#Options.SOFT_TARGET].value, "0")
gate:Release()
Equal("release restores the gate too", cvars.SoftTargetNameplateInteract .. " " .. cvars.SoftTargetInteract, "9 9")
count = #writes
gate:Change(Options.GATE, "1")
Equal("a change while released writes nothing", #writes, count)

-- Approached objects: the module ------------------------------------------------------------------------

local Approach = AUI.ApproachSparkles
local SOFT_OWN = { SoftTargetInteract = "1", SoftTargetInteractRange = "20", SoftTargetInteractArc = "0",
	SoftTargetInteractOnlyInRange = "1", SoftTargetIconInteract = "0", SoftTargetIconGameObject = "0",
	SoftTargetLowPriorityIcons = "0", SoftTargetNameplateInteract = "1" }

local function SoftHeld()
	local values = {}
	for index, entry in ipairs(Options.SOFT_TARGET) do
		values[index] = cvars[entry.name]
	end

	return table.concat(values, " ")
end

---A target near the player: a game object with a cursor, a unit, or nothing.
---@param fields table?
local function Target(fields)
	for key in pairs(soft) do
		soft[key] = nil
	end
	for key, value in pairs(fields or {}) do
		soft[key] = value
	end
	if fields and fields.plate == nil and fields.plateByToken == nil then
		soft.plate = CreateFrame("Frame")
	end
end

local function Glint()
	return frames.AeonUILootSparkle
end

local function Showing()
	local glint = Glint()

	return glint ~= nil and glint.shown and glint.parent == soft.plate and soft.plate ~= nil
end

global = {}
for name, value in pairs(SOFT_OWN) do
	cvars[name] = value
end
Target()
Login()
Equal("approach: never enabled writes no soft target", SoftHeld(), "1 20 0 1 0 0 0 1")
Equal("registers no soft target events", tostring(eventFrame.events.PLAYER_SOFT_INTERACT_CHANGED), "nil")
Equal("starts no ticker", LiveTickers(), 0)
Equal("makes no glint", Glint(), nil)

HiddenSettings:SetSparkle("ore", true)
Equal("ore row on holds the soft target", SoftHeld(), "3 60 2 0 1 1 1 0")
Equal("saving the player's values", Keys(global.hiddenSettings.saved.softTarget), "SoftTargetIconGameObject=0 "
	.. "SoftTargetIconInteract=0 SoftTargetInteract=1 SoftTargetInteractArc=0 SoftTargetInteractOnlyInRange=1 "
	.. "SoftTargetInteractRange=20 SoftTargetLowPriorityIcons=0 SoftTargetNameplateInteract=1")
Equal("and follows the soft target", tostring(eventFrame.events.PLAYER_SOFT_INTERACT_CHANGED), "true")
Equal("the row reads on", tostring(HiddenSettings:IsSparkle("ore")) .. " " .. tostring(HiddenSettings:IsSparkle("herbs")),
	"true false")

Target({ object = true, name = "Copper Vein", cursor = 1001, inRange = true })
Fire("PLAYER_SOFT_INTERACT_CHANGED", "GameObject-1", "GameObject-2")
Equal("ore target opens the gate", cvars.SoftTargetNameplateInteract, "1")
Equal("glints on its plate", tostring(Showing()), "true")
Equal("below the plate's content, ignoring its alpha", Glint().level .. " " .. tostring(Glint().ignoreParentAlpha), "4 true")
Equal("seven glints", #Glint().textures, 7)
Equal("ticker while a soft target exists", LiveTickers(), 1)
Glint().OnUpdate(Glint(), 0.05)
Equal("the glints animate", Glint().textures[1].color ~= nil, true)

Target({ object = true, name = "Peacebloom", cursor = 1003, inRange = true })
Fire("PLAYER_SOFT_INTERACT_CHANGED", "GameObject-2", "GameObject-3")
Equal("herb target with only ore on closes the gate", cvars.SoftTargetNameplateInteract, "0")
Equal("and shows nothing", tostring(Glint().shown), "false")

Target({ object = true, name = "Mithril Deposit", cursor = 1002, inRange = true })
Fire("PLAYER_SOFT_INTERACT_CHANGED", "GameObject-3", "GameObject-4")
Equal("unable ore in range is locked", Approach.state, "locked")
Target({ object = true, name = "Mithril Deposit", atlas = "Cursor_Crosshair_UnableMine_64", inRange = false })
Fire("PLAYER_SOFT_INTERACT_CHANGED", "GameObject-4", "GameObject-5")
Equal("out of range is far, by the atlas", Approach.state, "far")

clock = 200
Target({ object = true, name = "Copper Vein", cursor = 1001, inRange = false })
Fire("PLAYER_SOFT_INTERACT_CHANGED", "GameObject-5", "GameObject-6")
local plate = soft.plate
soft.inRange = true
Tick()
Equal("walking into range waits", Approach.state, "far")
clock = 200.2
Tick()
Equal("then shows ready", Approach.state, "ready")
Equal("on the same plate", tostring(Glint().parent == plate), "true")
soft.cursor, soft.name = 1002, "Mithril Deposit"
Fire("PLAYER_SOFT_INTERACT_CHANGED", "GameObject-6", "GameObject-12")
Equal("a recycled plate on a new object starts over", Approach.state, "locked")

Target({ object = true, name = "Copper Vein", cursor = 1001, inRange = true, plateByToken = false,
	plateUnit = "nameplate3" })
soft.plate = CreateFrame("Frame")
Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
Equal("a plate found by its unit when the token gives none", tostring(Showing()), "true")
Fire("NAME_PLATE_UNIT_REMOVED", "nameplate3")
Equal("plate removed releases", tostring(Glint().shown) .. " " .. tostring(Glint().parent), "false nil")

Target({ unit = true, name = "Defias Thug" })
Fire("PLAYER_SOFT_INTERACT_CHANGED", "GameObject-6", "Creature-1")
Equal("an NPC target closes the gate", cvars.SoftTargetNameplateInteract, "0")

Target()
Fire("PLAYER_SOFT_INTERACT_CHANGED", "Creature-1", "")
Tick()
Equal("ticker only while a soft target exists", LiveTickers(), 0)

Target({ unit = SECRET, object = SECRET, name = SECRET })
UnitExists = function() return SECRET end
UnitIsGameObject = function() return SECRET end
Fire("PLAYER_SOFT_INTERACT_CHANGED", SECRET, SECRET)
Equal("secret target gets nothing", cvars.SoftTargetNameplateInteract .. " " .. tostring(Glint().shown), "0 false")
function UnitExists(unit) return Unit(unit).unit == true end
function UnitIsGameObject(unit) return Unit(unit).object == true end

HiddenSettings:SetSparkle("questObjects", true)
Target({ object = true, name = "Sealed Crate", cursor = 1005, tooltipQuest = true, inRange = true })
Fire("PLAYER_SOFT_INTERACT_CHANGED", "", "GameObject-7")
Equal("quest object by tooltip line", tostring(Showing()), "true")
quests[1] = { id = 7, objectives = { { text = "Soaked Saw: 0/1", finished = false },
	{ text = "Crates: 3/3", finished = true } } }
Fire("QUEST_LOG_UPDATE")
Target({ object = true, name = "Soaked Saw", cursor = 1005, inRange = true })
Fire("PLAYER_SOFT_INTERACT_CHANGED", "GameObject-7", "GameObject-8")
Equal("quest object by objective name", tostring(Showing()), "true")
Target({ object = true, name = "Crates", cursor = 1005, inRange = true })
Fire("PLAYER_SOFT_INTERACT_CHANGED", "GameObject-8", "GameObject-9")
Equal("a finished objective does not count", tostring(Glint().shown), "false")
HiddenSettings:SetSparkle("ore", false)
Target({ object = true, name = "Copper Vein", cursor = 1001, questRelated = true, inRange = true })
Fire("PLAYER_SOFT_INTERACT_CHANGED", "GameObject-9", "GameObject-10")
Equal("ore stays ore with a quest", tostring(Glint().shown), "false")
HiddenSettings:SetSparkle("questObjects", false)

HiddenSettings:SetSparkle("corpses", true)
Target({ unit = true, dead = true, guid = "Creature-2", loot = { true, true } })
Fire("PLAYER_SOFT_INTERACT_CHANGED", "", "Creature-2")
Equal("corpse with loot", tostring(Showing()), "true")
Target({ unit = true, dead = true, guid = "Creature-3", loot = { false, false } })
Fire("PLAYER_SOFT_INTERACT_CHANGED", "Creature-2", "Creature-3")
Equal("a corpse without loot gets nothing", tostring(Glint().shown) .. " " .. cvars.SoftTargetNameplateInteract,
	"false 0")

Target({ unit = true, dead = true, guid = "Creature-4", loot = { true, true } })
Fire("PLAYER_SOFT_INTERACT_CHANGED", "Creature-3", "Creature-4")
Fire("PLAYER_REGEN_DISABLED")
Equal("combat closes the gate", cvars.SoftTargetNameplateInteract .. " " .. tostring(Glint().shown), "0 false")
inCombat = true
Fire("PLAYER_SOFT_INTERACT_CHANGED", "Creature-4", "Creature-5")
Equal("and keeps it closed in combat, glints hidden", cvars.SoftTargetNameplateInteract .. " "
	.. tostring(Glint().shown), "0 false")
inCombat = false
Fire("PLAYER_REGEN_ENABLED")
Equal("after combat it opens again", tostring(Showing()) .. " " .. cvars.SoftTargetNameplateInteract, "true 1")

HiddenSettings:SetQuestItems(true)
Equal("two holders apart", tostring(global.hiddenSettings.saved.lootSparkles ~= nil) .. " "
	.. tostring(global.hiddenSettings.saved.softTarget ~= nil) .. " " .. cvars.outlineModeShowLootEffectWhenDisabled
	.. " " .. cvars.SoftTargetInteract, "true true 1 3")

HiddenSettings:SetSparkle("corpses", false)
Equal("off stops everything", table.concat({ tostring(Glint().shown), tostring(LiveTickers()),
	tostring(eventFrame.events.PLAYER_SOFT_INTERACT_CHANGED), tostring(eventFrame.events.NAME_PLATE_UNIT_ADDED) }, " "),
	"false 0 nil nil")
Equal("and restores the soft target", SoftHeld(), "1 20 0 1 0 0 0 1")
Equal("clearing its save", tostring(global.hiddenSettings.saved.softTarget), "nil")
Equal("Quest Items holds on", cvars.outlineModeShowLootEffectWhenDisabled, "1")
HiddenSettings:SetQuestItems(false)

HiddenSettings:SetSparkle("herbs", true)
Target({ object = true, name = "Peacebloom", atlas = "Cursor_GatherHerbs_64", inRange = true })
Fire("PLAYER_SOFT_INTERACT_CHANGED", "", "GameObject-11")
Equal("re-enable", SoftHeld() .. " " .. tostring(Showing()), "3 60 2 0 1 1 1 1 true")
HiddenSettings:SetSparkle("herbs", false)

HiddenSettings:SetSparkle("ore", true)
Target({ object = true, name = "Mailbox", cursor = 1005, inRange = true })
Fire("PLAYER_SOFT_INTERACT_CHANGED", "", "GameObject-13")
local reads = tooltipReads
Tick()
Tick()
Equal("no quest lookup while Quest Objects is off", tooltipReads, reads)
HiddenSettings:SetSparkle("questObjects", true)
Tick()
Equal("a quest lookup once it is on", tooltipReads > reads, true)
Fire("PLAYER_REGEN_DISABLED")
Equal("combat stops the ticker", LiveTickers(), 0)
inCombat = true
reads = tooltipReads
Fire("PLAYER_SOFT_INTERACT_CHANGED", "GameObject-13", "GameObject-14")
Equal("and nothing is classified in combat", tooltipReads, reads)
inCombat = false
Fire("PLAYER_REGEN_ENABLED")
Equal("the ticker comes back after combat", LiveTickers(), 1)
HiddenSettings:SetSparkle("questObjects", false)

Target({ object = true, name = "Copper Vein", cursor = 1001, inRange = true })
Fire("PLAYER_SOFT_INTERACT_CHANGED", "GameObject-14", "GameObject-15")
Equal("the gate open on ore", cvars.SoftTargetNameplateInteract, "1")
HiddenSettings:SetSparkle("ore", false)
Target({ unit = true, name = "Defias Thug" })
for index = #writes, 1, -1 do
	writes[index] = nil
end
HiddenSettings:SetSparkle("ore", true)
local gateOpened = false
for _, write in ipairs(writes) do
	gateOpened = gateOpened or write == "SoftTargetNameplateInteract=1"
end
Equal("turning back on starts with the gate closed", gateOpened, false)
HiddenSettings:SetSparkle("ore", false)

global = { hiddenSettings = { saved = { softTarget = { SoftTargetInteract = "1" } } } }
Login({ SoftTargetInteract = "3" })
Equal("a soft target save left at login is restored", cvars.SoftTargetInteract .. " "
	.. tostring(global.hiddenSettings.saved.softTarget), "1 nil")

-- Chests and the bobber ---------------------------------------------------------------------------------

global = {}
Login()
HiddenSettings:SetSparkle("bobber", true)
Target({ object = true, name = "Fishing Bobber", cursor = 1005, guid = "GameObject-0-1-2-3-35591-00AB", inRange = true,
	questRelated = true })
Fire("PLAYER_SOFT_INTERACT_CHANGED", "", "GameObject-20")
Equal("bobber by object ID", tostring(Showing()), "true")
HiddenSettings:SetSparkle("questObjects", true)
Fire("PLAYER_SOFT_INTERACT_CHANGED", "GameObject-20", "GameObject-21")
Equal("bobber beats quest", tostring(Showing()), "true")
HiddenSettings:SetSparkle("questObjects", false)
HiddenSettings:SetSparkle("bobber", false)

HiddenSettings:SetSparkle("chests", true)
Target({ object = true, name = "Locked Box", cursor = "Interface\\Cursor\\PickLock", guid = "GameObject-0-1-2-3-500-01",
	inRange = true })
Fire("PLAYER_SOFT_INTERACT_CHANGED", "", "GameObject-22")
Equal("chest by cursor", tostring(Showing()), "true")
Target({ object = true, name = "Battered Chest", cursor = 1005, guid = "GameObject-0-1-2-3-501-01", inRange = true })
Fire("PLAYER_SOFT_INTERACT_CHANGED", "GameObject-22", "GameObject-23")
Equal("chest by name", tostring(Showing()), "true")
Target({ object = true, name = "Mailbox", cursor = 1005, guid = "GameObject-0-1-2-3-502-01", inRange = true })
Fire("PLAYER_SOFT_INTERACT_CHANGED", "GameObject-23", "GameObject-24")
Equal("mailbox is not a chest", tostring(Glint().shown), "false")
Target({ object = true, name = "Battered Chest", cursor = 1004, guid = "GameObject-0-1-2-3-506-01", inRange = true })
Fire("PLAYER_SOFT_INTERACT_CHANGED", "GameObject-24", "GameObject-24b")
Equal("a quest cursor is not a chest by name", tostring(Glint().shown), "false")
Target({ object = true, name = "Old Chest Mailbox", cursor = 1006, guid = "GameObject-0-1-2-3-507-01", inRange = true })
Fire("PLAYER_SOFT_INTERACT_CHANGED", "GameObject-24b", "GameObject-24c")
Equal("a service cursor is never a chest", tostring(Glint().shown), "false")

Target({ object = true, name = "Copper Vein", cursor = 1001, guid = "GameObject-0-1-2-3-1731-01", inRange = true })
Fire("PLAYER_SOFT_INTERACT_CHANGED", "GameObject-24", "GameObject-25")
lootSlots = { { "GameObject-0-1-2-3-1731-01", 1 }, { "GameObject-0-1-2-3-503-01", 1, "GameObject-0-1-2-3-35591-01", 1 } }
Fire("LOOT_OPENED")
Equal("gathered nodes and the bobber are not learned", table.concat(global.hiddenSettings.containers, " "), "503")
Target({ object = true, name = "Dusty Barrel", cursor = 1005, guid = "GameObject-0-1-2-3-503-02", inRange = true })
Fire("PLAYER_SOFT_INTERACT_CHANGED", "GameObject-25", "GameObject-26")
Equal("chest by learned ID", tostring(Showing()), "true")

HiddenSettings:SetSparkle("questObjects", true)
Target({ object = true, name = "Supply Crate", cursor = "Interface\\Cursor\\Pickup", guid = "GameObject-0-1-2-3-504-01",
	tooltipQuest = true, inRange = true })
Fire("PLAYER_SOFT_INTERACT_CHANGED", "GameObject-26", "GameObject-27")
Equal("quest beats chest", tostring(Showing()) .. " " .. Approach.kind, "true questObjects")
HiddenSettings:SetSparkle("questObjects", false)
Fire("PLAYER_SOFT_INTERACT_CHANGED", "GameObject-27", "GameObject-28")
Equal("a quest crate is a chest without Quest Objects", tostring(Showing()) .. " " .. Approach.kind, "true chests")

lootSlots = { { SECRET, 1 }, { "Item-0-1-2", 1 } }
Fire("LOOT_OPENED")
Equal("secret GUID", table.concat(global.hiddenSettings.containers, " "), "503")
Target({ object = true, name = SECRET, cursor = 1005, guid = SECRET, inRange = true })
Fire("PLAYER_SOFT_INTERACT_CHANGED", "GameObject-28", "GameObject-29")
Equal("a secret object is nothing", tostring(Glint().shown), "false")

HiddenSettings:SetSparkle("chests", false)
HiddenSettings:SetSparkle("ore", true)
lootSlots = { { "GameObject-0-1-2-3-505-01", 1 } }
Fire("LOOT_OPENED")
Equal("loot learns only with Chests on", table.concat(global.hiddenSettings.containers, " "), "503")
HiddenSettings:SetSparkle("ore", false)
Login()
HiddenSettings:SetSparkle("chests", true)
Target({ object = true, name = "Dusty Barrel", cursor = 1005, guid = "GameObject-0-1-2-3-503-03", inRange = true })
Fire("PLAYER_SOFT_INTERACT_CHANGED", "", "GameObject-30")
Equal("learned list survives a login", tostring(Showing()), "true")
HiddenSettings:SetSparkle("chests", false)

AUI.can.approachSparkles = false
global = {}
Login()
HiddenSettings:SetSparkle("ore", true)
Equal("no capability, no soft target", cvars.SoftTargetInteract, "1")

print(("check_hiddensettings: %d checks passed"):format(checks))
