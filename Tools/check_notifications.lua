-- Checks Notifications/ outside the game: the paths, defaults and frame-free rules (the stack's place, who should have a
-- pet and when its reminders apply, the pet health curve, the lowest durability, a potion's cooldown); the stack (slots
-- replacing each other in their order, timed notices fading after the duration, reminders staying, samples kept apart
-- from live notices, a restyle on each change); Entering and Leaving Combat with the grace that keeps a brief drop out
-- of combat quiet; Pet Missing, Pet Passive and Pet Low Health (spells, Lone Wolf, Marksmanship, Grimoire of Sacrifice
-- with a secret aura, the places they apply, dismounting's grace, the health curve); Unspent Talent Points and Low
-- Durability out of combat; Potion Ready from a bag potion's cast, its cooldown waited out, a secret one ignored; and
-- every event followed only while a notice needs it.
-- Run from any directory with Lua 5.1: lua Tools/check_notifications.lua
-- Loads the real files against stubbed globals. Widgets are modeled by type. Exits non-zero on the first failed check.

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

local now = 100
function GetTime()
	return now
end

-- Timers run when `Advance` passes their time; `After(0)` runs at once.
local timers = {}
C_Timer = {
	After = function(delay, callback)
		if delay == 0 then
			callback()
		else
			timers[#timers + 1] = { at = now + delay, callback = callback }
		end
	end,
	NewTimer = function(delay, callback)
		local timer = { at = now + delay, callback = callback }
		function timer:Cancel()
			self.cancelled = true
		end
		timers[#timers + 1] = timer

		return timer
	end,
}

local function Advance(seconds)
	now = now + seconds

	for _, timer in ipairs(timers) do
		if not timer.cancelled and not timer.done and timer.at <= now then
			timer.done = true
			timer.callback()
		end
	end
end

local SECRET = {}
function issecretvalue(value)
	return value == SECRET
end

local function FontString()
	local text = { shown = true, alpha = 1 }
	function text:SetFont(file, size, flags)
		self.font = ("%s %d %s"):format(file, size, flags)
	end
	function text:SetText(value)
		assert(self.font, "Font not set")
		self.text = value
	end
	function text:SetTextColor(r, g, b)
		self.color = ("%s %s %s"):format(r, g, b)
	end
	function text:Show()
		self.shown = true
	end
	function text:Hide()
		self.shown = false
	end
	function text:SetAlpha(alpha)
		self.shownAlpha = alpha
	end
	function text:ClearAllPoints() end
	function text:SetPoint(_, _, _, _, y)
		self.shownOffset = y + 0
	end
	function text:GetStringWidth()
		return #(self.text or "") * 10
	end
	function text:GetStringHeight()
		return 20
	end

	return text
end

local eventFrame
function CreateFrame(kind, name)
	assert(kind == "Frame")
	local frame = { name = name, events = {}, width = 1, height = 1 }
	function frame:RegisterEvent(event)
		self.events[event] = true
	end
	function frame:UnregisterEvent(event)
		self.events[event] = nil
	end
	function frame:SetScript(name, handler)
		if name == "OnUpdate" then
			self.onUpdate = handler
		else
			self.onEvent = handler
		end
	end
	function frame:SetSize(width, height)
		self.width, self.height = width, height
	end
	function frame:SetFrameStrata(strata)
		self.strata = strata
	end
	function frame:EnableMouse() end
	function frame:ClearAllPoints() end
	function frame:SetPoint(point, _, _, x, y)
		self.point = ("%s %d %d"):format(point, x, y)
	end
	function frame:CreateFontString()
		return FontString()
	end
	eventFrame = eventFrame or frame

	return frame
end

UIParent = { GetHeight = function()
	return 768
end }

local function Fire(event, ...)
	if eventFrame.events[event] then
		eventFrame.onEvent(eventFrame, event, ...)
	end
end

-- The world the notices read.
local known, inCombat, instance, mounted, vehicle, taxi, dead = {}, false, false, false, false, false, false
local pet, petDead, passive, spec, sacrificeAura, aurasSecret = true, false, false, nil, nil, false
local petHealth, unspent, durability = 1, false, {}
local playerHealth, trackings, form = 1, {}, nil
local bags, cooldowns = {}, {}

C_SpellBook = { IsSpellKnown = function(spell)
	return known[spell] == true
end }
function InCombatLockdown()
	return inCombat
end
function IsInInstance()
	return instance, instance and "party" or "none"
end
function IsMounted()
	return mounted
end
function UnitInVehicle()
	return vehicle
end
function UnitOnTaxi()
	return taxi
end
function UnitIsDeadOrGhost()
	return dead
end
function UnitExists(unit)
	assert(unit == "pet")

	return pet
end
function UnitIsDead()
	return petDead
end
NUM_PET_ACTION_SLOTS = 10
function GetPetActionInfo(slot)
	if slot == 10 then
		return "PET_MODE_PASSIVE", nil, true, passive
	end

	return "PET_MODE_ASSIST", nil, true, not passive
end
C_SpecializationInfo = {
	GetSpecialization = function()
		return spec and 1
	end,
	GetSpecializationInfo = function()
		return spec
	end,
	CanPlayerUseTalentUI = function()
		return true
	end,
}
C_Secrets = { ShouldAurasBeSecret = function()
	return aurasSecret
end }
C_UnitAuras = { GetPlayerAuraBySpellID = function()
	return sacrificeAura
end }
Enum = {
	LuaCurveType = { Step = 1 },
	ItemClass = { Consumable = 0 },
	ItemConsumableSubclass = { Potion = 1 },
}
C_CurveUtil = { CreateCurve = function()
	local curve = { points = {} }
	function curve:SetType(curveType)
		self.type = curveType
	end
	function curve:AddPoint(x, y)
		self.points[#self.points + 1] = { x, y }
	end

	return curve
end }
---A step curve's value at `x`: the last point at or before it.
function UnitHealthPercent(unit, _, curve)
	assert(unit == "pet" or unit == "player")
	local health = unit == "pet" and petHealth or playerHealth
	local value

	for _, point in ipairs(curve.points) do
		if point[1] <= health then
			value = point[2]
		end
	end

	return value
end
C_Minimap = {
	GetNumTrackingTypes = function()
		return #trackings
	end,
	GetTrackingInfo = function(index)
		return trackings[index]
	end,
}
function GetShapeshiftFormID()
	return form
end
C_ClassTalents = { HasUnspentTalentPoints = function()
	return unspent, 0, 0
end }
function GetInventoryItemDurability(slot)
	local piece = durability[slot]

	return piece and piece[1], piece and piece[2]
end
NUM_BAG_SLOTS = 4
C_Container = {
	GetContainerNumSlots = function(bag)
		return bags[bag] and #bags[bag] or 0
	end,
	GetContainerItemID = function(bag, slot)
		return bags[bag][slot]
	end,
	GetItemCooldown = function(itemID)
		local cooldown = cooldowns[itemID] or { 0, 0, 1 }

		return cooldown[1], cooldown[2], cooldown[3]
	end,
}
local items = { [1001] = { 0, 1, 431932 }, [2002] = { 0, 5 } }
C_Item = {
	GetItemInfoInstant = function(itemID)
		local item = items[itemID]

		return itemID, nil, nil, nil, nil, item[1], item[2]
	end,
	GetItemSpell = function(itemID)
		local item = items[itemID]

		return item[3] and "Potion", item[3]
	end,
}

-- Addon table ---------------------------------------------------------------------------------------------

local AUI = {}
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
assert(loadfile(root .. "Core/Core.lua"))("AeonUI", AUI)
AUI.can = { petNotices = true, petHealthNotice = true, talentNotice = true, durabilityNotice = true,
	lowHealthNotice = true, trackingNotice = true,
	potionNotice = true, specializations = true }
AUI.Media = {
	Font = function(_, name)
		return "LSM:" .. name
	end,
	FontFlags = function(_, outline)
		return outline
	end,
}

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

local settingsLibrary = {}
local springs = assert(loadfile(root .. "Tools/springs.lua"))(settingsLibrary)
function LibStub(name)
	assert(name == "LibAeonSettings-1.0", name)

	return settingsLibrary
end

for _, file in ipairs({ "AeonUI_QoL/Notifications/Options.lua", "AeonUI_QoL/Notifications/Notifications.lua", "AeonUI_QoL/Notifications/Combat.lua",
	"AeonUI_QoL/Notifications/Pet.lua", "AeonUI_QoL/Notifications/Character.lua", "AeonUI_QoL/Notifications/Potion.lua", "AeonUI_QoL/Notifications/Health.lua",
	"AeonUI_QoL/Notifications/Tracking.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local Options, Notifications = AUI.NotificationOptions, AUI.Notifications

-- Harness -------------------------------------------------------------------------------------------------

local checks = 0

local function Equal(name, actual, expected)
	checks = checks + 1
	if actual ~= expected then
		io.stderr:write(("FAIL: %s: expected %s, got %s\n"):format(name, tostring(expected), tostring(actual)))
		os.exit(1)
	end
end

---@return string shown the live lines' texts, top first
local function Shown()
	local texts = {}

	for _, line in ipairs(Notifications.lines) do
		if not line.sample and not line.leaving then
			texts[#texts + 1] = line.text
		end
	end

	return table.concat(texts, " | ")
end

local function Line(key)
	for _, line in ipairs(Notifications.lines) do
		if line.key == key and not line.sample then
			return line
		end
	end
end

local Frames = springs.Frames

local function On(key)
	Set(Options:Path(key, "enabled"), true)
end

-- Rules ---------------------------------------------------------------------------------------------------

Equal("a notice's path", Options:Path("petHealth", "color"), "notifications.petHealth.color")
local defaults = {}
for _, notice in ipairs(Options.NOTICES) do
	defaults[#defaults + 1] = notice.key .. "=" .. tostring(AUI.Profile:Get(Options:Path(notice.key, "enabled")))
end
Equal("every notice off by default", table.concat(defaults, " "), "enter=false leave=false lowHealth=false "
	.. "potion=false petMissing=false petPassive=false petHealth=false talents=false durability=false tracking=false")
Equal("Low Health is the stack's last slot, Pet Low Health just above it", Options:SlotOrder("health") .. " "
	.. Options:SlotOrder("petHealth") .. " " .. #Options.SLOTS, "9 8 9")
Equal("Low Health shows below 35% by default", AUI.Profile:Get(Options.LOW_HEALTH_PATH), 35)

local hunter, dwarfPaladin = {}, {}
for _, tracking in ipairs(Options:TrackingsFor("HUNTER", "Orc")) do
	hunter[#hunter + 1] = tracking.key
end
for _, tracking in ipairs(Options:TrackingsFor("PALADIN", "Dwarf")) do
	dwarfPaladin[#dwarfPaladin + 1] = tracking.key
end
Equal("a hunter's trackings, then the professions'", table.concat(hunter, " "),
	"beasts humanoids undead hidden elementals demons giants dragonkin herbs minerals")
Equal("a dwarf paladin's", table.concat(dwarfPaladin, " "), "senseUndead treasure herbs minerals")
local function Missing(tracked, shape, skip)
	return table.concat(Options:MissingTrackings(tracked, shape, function(key)
		return key ~= skip
	end), ", ")
end
Equal("only listed trackings that are off are missing", Missing({ [1494] = false, [19883] = true, [2383] = false }),
	"Beasts, Herbs")
Equal("a profession's second rank counts as the profession", Missing({ [2383] = false, [8387] = true }), "")
Equal("one Tracking does not remind about is left out", Missing({ [1494] = false, [2580] = false }, nil, "beasts"),
	"Minerals")
Equal("a druid's humanoids only in Cat Form", Missing({ [5225] = false }, nil) .. " | " .. Missing({ [5225] = false }, 1),
	" | Humanoids")
Equal("the line names them after its text", Options:TrackingText({ "Beasts", "Herbs" }), "Not Tracking: Beasts, Herbs")
Equal("the style's defaults", AUI.Profile:Get(Options.FONT_PATH) .. " " .. AUI.Profile:Get(Options.SIZE_PATH) .. " "
	.. AUI.Profile:Get(Options.OUTLINE_PATH) .. " " .. AUI.Profile:Get(Options.DURATION_PATH), "Friz Quadrata TT 22 SLUG 3")
Equal("an empty text is the notice's own", (function()
	values[Options:Path("enter", "text")] = ""
	local text = Options:Text("enter")
	values[Options:Path("enter", "text")] = nil

	return text
end)(), "+Combat")
local position = Options:DefaultPosition(768)
Equal("the stack's top 150 above the center", position.point .. " " .. position.x .. " " .. position.y, "TOP 0 -234")

local function Knows(...)
	local set = {}
	for _, spell in ipairs({ ... }) do
		set[spell] = true
	end

	return function(spell)
		return set[spell] == true
	end
end
Equal("a hunter with Call Pet", Options:PetEligible(Knows(883), nil, false), true)
Equal("no pet summon", Options:PetEligible(Knows(), nil, false), false)
Equal("Lone Wolf", Options:PetEligible(Knows(883, 415370), nil, false), false)
Equal("Marksmanship without its pet talent", Options:PetEligible(Knows(883), 254, false), false)
Equal("Marksmanship with it", Options:PetEligible(Knows(883, 1223323), 254, false), true)
Equal("a sacrificed demon", Options:PetEligible(Knows(688), nil, true), false)
local state = { inCombat = false, inInstance = true, mounted = false, vehicle = false, taxi = false, dead = false }
Equal("in an instance", Options:PetRemindersApply(state), true)
state.inInstance = false
Equal("out of combat in the world", Options:PetRemindersApply(state), false)
state.inCombat = true
Equal("in combat", Options:PetRemindersApply(state), true)
state.mounted = true
Equal("not mounted", Options:PetRemindersApply(state), false)
Equal("a house is not an instance", Options:CountsAsInstance(true, "interior"), false)
local curve = Options:HealthCurve(25)
Equal("the health curve", curve[2][1] .. ":" .. curve[2][2] .. " " .. curve[3][1] .. ":" .. curve[3][2], "0.249:1 0.25:0")
Equal("the lowest durability", Options:LowestDurability({ { current = 50, maximum = 100 },
	{ current = 9, maximum = 30 }, { current = 0, maximum = 0 } }), 30)
Equal("nothing with durability", Options:LowestDurability({}), nil)
Equal("a potion's cooldown waiting to start", (Options:PotionCooldown(0, 0, 0, 100)), "waiting")
local cooldownState, remaining = Options:PotionCooldown(90, 300, 1, 100)
Equal("running", cooldownState .. " " .. remaining, "running 290")
Equal("the global cooldown is not the potion's", (Options:PotionCooldown(99, 1.5, 1, 100)), "over")

-- Off -----------------------------------------------------------------------------------------------------

Notifications:Start()
Notifications:Start()
Equal("nothing followed while every notice is off", tostring(eventFrame.events.PLAYER_REGEN_DISABLED) .. " "
	.. tostring(eventFrame.events.UNIT_PET) .. " " .. tostring(eventFrame.events.UNIT_SPELLCAST_SUCCEEDED), "nil nil nil")

-- The stack -----------------------------------------------------------------------------------------------

Notifications:Show("durability", "Low Durability (20%)")
Frames(2)
Notifications:Show("enter")
Equal("the stack keeps its slots' order", Shown(), "+Combat | Low Durability (20%)")
Equal("the named stack, sized to its lines", Notifications.frame.name .. " " .. Notifications.frame.width .. "x"
	.. Notifications.frame.height, "AeonUINotifications 200x42")
Equal("in the chosen style and the notice's color", Line("enter").font .. " / " .. Line("enter").color,
	"LSM:Friz Quadrata TT 22 SLUG / 1 0.25 0.25")
local entering, below = Line("enter"), Line("durability")
Equal("a new line starts clear, above its place, and pushes the line below down from where it was",
	entering.shownAlpha .. " " .. entering.shownOffset .. " " .. below.shownOffset, "0 8 0")
Equal("moving", springs.Moving(), true)
Frames(0.1)
Equal("partway", entering.shownAlpha > 0.3 and entering.shownAlpha < 1 and entering.shownOffset < 8 and entering.shownOffset > 0
	and below.shownOffset < 0 and below.shownOffset > -22, true)
Frames(2)
Equal("at rest: in place, opaque, and nothing moving", entering.shownAlpha .. " " .. entering.shownOffset .. " "
	.. below.shownOffset .. " " .. tostring(springs.Moving()), "1 0 -22 false")
Notifications:Show("leave")
Equal("Leaving replaces Entering in its slot", Shown(), "-Combat | Low Durability (20%)")
local leaving = Line("leave")
Equal("cross-fading in place", #Notifications.lines .. " " .. leaving.shownOffset .. " " .. tostring(entering.leaving)
	.. " " .. entering.shownOffset, "3 0 true 0")
Frames(2)
Equal("the replaced line is released", #Notifications.lines, 2)
Advance(3)
Equal("a timed notice leaves after the duration", Shown(), "Low Durability (20%)")
Equal("giving its room to the line below", below.offset.target, 0)
Frames(0.1)
Equal("moving up as it fades", leaving.shownOffset > 0 and leaving.shownAlpha < 1 and below.shownOffset > -22, true)
Notifications:Show("leave")
Equal("shown again while leaving, it turns back from where it is", leaving.leaving == nil
	and leaving.shownAlpha < 1 and leaving.shownOffset > 0 and #Notifications.lines == 2, true)
Frames(2)
Equal("back in place", leaving.shownAlpha .. " " .. leaving.shownOffset .. " " .. below.shownOffset, "1 0 -22")
Notifications:Dismiss("leave")
Frames(2)
Equal("and is gone", Shown() .. " " .. #Notifications.lines .. " " .. below.shownOffset, "Low Durability (20%) 1 0")
springs.reduce = true
Notifications:Show("enter")
Equal("Reduce Motion: in place at once", Line("enter").shownAlpha .. " " .. Line("enter").shownOffset .. " " .. below.shownOffset
	.. " " .. tostring(springs.Moving()), "1 0 -22 false")
Notifications:Dismiss("enter")
Equal("and gone at once", #Notifications.lines .. " " .. below.shownOffset, "1 0")
springs.reduce = false
Advance(30)
Equal("a reminder stays", Shown(), "Low Durability (20%)")
Notifications:Sample(true)
Equal("samples beside live notices", #Notifications.lines .. " " .. Shown(), "2 Low Durability (20%)")
Notifications:Sample(false)
Notifications:Dismiss("durability")
Frames(2)
Equal("dismissed", #Notifications.lines, 0)

-- Combat --------------------------------------------------------------------------------------------------

On("enter")
On("leave")
Fire("PLAYER_REGEN_DISABLED")
Equal("Entering Combat", Shown(), "+Combat")
Fire("PLAYER_REGEN_ENABLED")
Equal("Leaving waits a moment", Shown(), "+Combat")
Advance(0.6)
Equal("then shows", Shown(), "-Combat")
Fire("PLAYER_REGEN_DISABLED")
Fire("PLAYER_REGEN_ENABLED")
Advance(0.2)
Fire("PLAYER_REGEN_DISABLED")
Advance(1)
Equal("a brief drop out of combat stays quiet", Shown(), "+Combat")
Set(Options:Path("enter", "color"), { r = 0, g = 1, b = 0 })
Equal("a setting change restyles what shows", Line("enter").color, "0 1 0")
Set(Options:Path("enter", "enabled"), false)
Set(Options:Path("leave", "enabled"), false)
Equal("off: dismissed and no longer followed", Shown() .. tostring(eventFrame.events.PLAYER_REGEN_DISABLED), "nil")
inCombat = false

-- Pet -----------------------------------------------------------------------------------------------------

known[883] = true
instance = true
pet = false
On("petMissing")
Equal("a hunter in an instance without a pet", Shown(), "Pet Missing")
pet = true
Fire("UNIT_PET", "player")
Equal("the pet is back", Shown(), "")
petDead = true
Fire("UNIT_PET", "player")
Equal("a dead pet is missing", Shown(), "Pet Missing")
petDead = false
On("petPassive")
passive = true
Fire("PET_BAR_UPDATE")
Equal("Pet Passive", Shown(), "Pet Passive")
passive = false
Fire("PET_BAR_UPDATE")
Equal("Assist again", Shown(), "")
instance = false
pet = false
Fire("ZONE_CHANGED_NEW_AREA")
Equal("out of combat in the world, nothing", Shown(), "")
Fire("PLAYER_REGEN_DISABLED")
Equal("in combat it applies at once", Shown(), "Pet Missing")
mounted = true
Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
Equal("not while mounted", Shown(), "")
mounted = false
Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
Equal("nor just after dismounting", Shown(), "")
Advance(3)
Equal("then it applies again", Shown(), "Pet Missing")
known[415370] = true
Fire("SPELLS_CHANGED")
Equal("Lone Wolf needs no pet", Shown(), "")
known[415370] = nil
spec = 254
Fire("PLAYER_SPECIALIZATION_CHANGED")
Equal("nor Marksmanship without its pet talent", Shown(), "")
spec = nil
known[883], known[688], known[108503] = nil, true, true
sacrificeAura = {}
Fire("UNIT_AURA", "player")
Equal("a sacrificed demon is not missing", Shown(), "")
aurasSecret = true
sacrificeAura = nil
Fire("UNIT_AURA", "player")
Equal("while the aura is secret, the last answer stands", Shown(), "")
aurasSecret = false
Fire("UNIT_AURA", "player")
Equal("the demon back from sacrifice is missing", Shown(), "Pet Missing")
pet = true
petHealth = 0.8
On("petHealth")
local health = Line("petHealth")
Equal("Pet Low Health is shown without opacity above the mark", tostring(health and health.shownAlpha), "0")
petHealth = 0.2
Fire("UNIT_HEALTH", "pet")
Equal("and with it below", health.shownAlpha, 1)
Fire("UNIT_HEALTH", "target")
Equal("another unit's health is ignored", health.shownAlpha, 1)
Set(Options.PET_HEALTH_PATH, 10)
Equal("a new mark redraws it", Line("petHealth").shownAlpha, 0)
for _, key in ipairs({ "petMissing", "petPassive", "petHealth" }) do
	Set(Options:Path(key, "enabled"), false)
end
Equal("off: dismissed and no longer followed", Shown() .. tostring(eventFrame.events.UNIT_PET), "nil")
Fire("PLAYER_REGEN_ENABLED")

-- Character -----------------------------------------------------------------------------------------------

unspent = true
On("talents")
Equal("Unspent Talent Points", Shown(), "Unspent Talent Points")
Fire("PLAYER_REGEN_DISABLED")
Equal("hidden in combat", Shown(), "")
Fire("PLAYER_REGEN_ENABLED")
unspent = false
Fire("TRAIT_CONFIG_UPDATED")
Equal("gone once spent", Shown(), "")
durability = { [1] = { 30, 100 }, [5] = { 90, 100 } }
On("durability")
Equal("Low Durability with the lowest", Shown(), "Low Durability (30%)")
durability[1] = { 100, 100 }
Fire("UPDATE_INVENTORY_DURABILITY")
Equal("repaired", Shown(), "")
Set(Options:Path("talents", "enabled"), false)
Set(Options:Path("durability", "enabled"), false)
Equal("off: no longer followed", tostring(eventFrame.events.UPDATE_INVENTORY_DURABILITY), "nil")

-- Potion --------------------------------------------------------------------------------------------------

bags = { [0] = { 1001, 2002 } }
On("potion")
Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 12345)
Fire("BAG_UPDATE_COOLDOWN")
Equal("another spell starts no watch", AUI.PotionNotice.watched, nil)
Fire("UNIT_SPELLCAST_SUCCEEDED", "party1", "guid", 431932)
Equal("another unit's potion is ignored", AUI.PotionNotice.watched, nil)
Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 431932)
Equal("the player's potion is watched", AUI.PotionNotice.watched, 1001)
Fire("BAG_UPDATE_COOLDOWN")
Equal("an over cooldown never seen running shows nothing", Shown(), "")
cooldowns[1001] = { now, 300, 0 }
Fire("BAG_UPDATE_COOLDOWN")
Equal("a cooldown waiting for combat to end shows nothing", Shown(), "")
cooldowns[1001] = { SECRET, 300, 1 }
Fire("BAG_UPDATE_COOLDOWN")
Equal("nor a secret one", Shown(), "")
cooldowns[1001] = { now, 300, 1 }
Fire("BAG_UPDATE_COOLDOWN")
Advance(299)
Equal("running", Shown(), "")
cooldowns[1001] = { 0, 0, 1 }
Advance(2)
Equal("Potion Ready once it is over", Shown(), "Potion Ready")
Equal("and the watch ends", AUI.PotionNotice.watched, nil)
Set(Options:Path("potion", "enabled"), false)
Equal("off: no longer followed", tostring(eventFrame.events.UNIT_SPELLCAST_SUCCEEDED), "nil")

-- Low Health ----------------------------------------------------------------------------------------------

dead = false
playerHealth = 0.8
On("lowHealth")
local low = Line("lowHealth")
Equal("Low Health is shown without opacity above the mark", tostring(low and low.shownAlpha), "0")
playerHealth = 0.2
Fire("UNIT_HEALTH", "player")
Equal("and fully below it, the health never read", Line("lowHealth").shownAlpha, 1)
Fire("UNIT_HEALTH", "target")
Equal("another unit's health changes nothing", Line("lowHealth").shownAlpha, 1)
Set(Options.LOW_HEALTH_PATH, 15)
Equal("a new mark redraws it", Line("lowHealth").shownAlpha, 0)
Set(Options.LOW_HEALTH_PATH, 35)
dead = true
Fire("PLAYER_DEAD")
Equal("dismissed while dead", Line("lowHealth") ~= nil and not Line("lowHealth").leaving, false)
dead = false
Fire("PLAYER_ALIVE")
Equal("back once alive", Line("lowHealth") ~= nil and not Line("lowHealth").leaving, true)
Set(Options:Path("lowHealth", "enabled"), false)
Equal("off: no longer followed", tostring(eventFrame.events.UNIT_MAXHEALTH), "nil")
Frames(1)

-- Tracking ------------------------------------------------------------------------------------------------

trackings = { { spellID = 2383, active = false }, { spellID = 2580, active = true }, { spellID = 1494, active = false } }
instance, taxi = false, false
On("tracking")
Advance(0)
Equal("Tracking names what is off", Shown(), "Not Tracking: Beasts, Herbs")
Set(Options.TRACKING_PATH .. ".beasts", false)
Advance(0)
Equal("leaving out what it does not remind about", Shown(), "Not Tracking: Herbs")
trackings[1].active = true
Fire("MINIMAP_UPDATE_TRACKING")
Advance(0)
Equal("gone once everything is on", Shown(), "")
trackings[1].active = false
instance = true
Fire("ZONE_CHANGED_NEW_AREA")
Advance(0)
Equal("hidden in instances", Shown(), "")
instance = false
taxi = true
Fire("PLAYER_CONTROL_LOST")
Advance(0)
Equal("and on a taxi", Shown(), "")
taxi = false
Fire("PLAYER_CONTROL_GAINED")
Advance(0)
Equal("back after landing", Shown(), "Not Tracking: Herbs")
Equal("its sample names two professions", Notifications:SampleText("tracking"), "Not Tracking: Herbs, Minerals")
Set(Options:Path("tracking", "enabled"), false)
Advance(0)
Equal("off: dismissed and no longer followed", tostring(eventFrame.events.MINIMAP_UPDATE_TRACKING) .. " " .. Shown(),
	"nil ")

Equal("no Lua error in the run", errors[1], nil)

io.stdout:write(("check_notifications: %d checks passed\n"):format(checks))
