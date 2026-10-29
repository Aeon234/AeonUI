local AUI = select(2, ...)

local L = AUI.L
local Schema = AUI.Schema

---A notification: its key, the slot it shows in (notices sharing a slot replace each other), its default text and
---color, and whether it fades after the duration (timed) or stays until its condition ends.
---@class AUINotice
---@field key string
---@field slot string
---@field text string
---@field color { r: number, g: number, b: number }
---@field timed boolean?

---The Notifications settings and their frame-free rules: the notices, their paths and texts, the stack's order, the
---timings, who should have a pet and when pet reminders apply, the health curve, the lowest durability, when a used
---potion is ready again, and which trackings are off.
---@class AUINotificationOptions
---@field NOTICES AUINotice[] every notice, in the order the page lists them
---@field SLOTS string[] the slots, top of the stack first
---@field FONT_PATH string
---@field SIZE_PATH string
---@field OUTLINE_PATH string
---@field DURATION_PATH string seconds a timed notice stays before it fades
---@field POSITION_PATH string
---@field PET_HEALTH_PATH string the pet's health, a percentage, below which Pet Low Health shows
---@field DURABILITY_PATH string the lowest durability, a percentage, below which Low Durability shows
---@field LOW_HEALTH_PATH string the player's health, a percentage, below which Low Health shows
---@field TRACKING_PATH string the branch holding, per tracking, whether Tracking reminds about it
---@field MOVE_RESPONSE number seconds; the spring that moves a line to its place
---@field FADE_IN number seconds; the spring that brings a line's opacity up
---@field FADE_OUT number seconds; the spring that takes a line's opacity down
---@field TRAVEL number units a line moves down as it enters and up as it leaves
---@field REST_DISTANCE number units from its place within which a moving line comes to rest
---@field REST_ALPHA number opacity from its target within which a fading line comes to rest
---@field COMBAT_GRACE number seconds after leaving combat in which entering it again shows nothing new
---@field DISMOUNT_GRACE number seconds after dismounting before pet reminders apply again
---@field LINE_GAP number
---@field MIN_SIZE number
---@field MAX_SIZE number
local Options = {
	NOTICES = {
		{ key = "enter", slot = "combat", text = L["+Combat"], color = { r = 1, g = 0.25, b = 0.25 }, timed = true },
		{ key = "leave", slot = "combat", text = L["-Combat"], color = { r = 0.3, g = 0.6, b = 1 }, timed = true },
		{ key = "lowHealth", slot = "health", text = L["Low Health"], color = { r = 1, g = 0.2, b = 0.2 } },
		{ key = "potion", slot = "potion", text = L["Potion Ready"], color = { r = 0.1, g = 1, b = 0.1 }, timed = true },
		{ key = "petMissing", slot = "pet", text = L["Pet Missing"], color = { r = 0.522, g = 0.427, b = 0.914 } },
		{ key = "petPassive", slot = "petStance", text = L["Pet Passive"], color = { r = 0.882, g = 0.882, b = 0.882 } },
		{ key = "petHealth", slot = "petHealth", text = L["Pet Low Health"], color = { r = 1, g = 0.3, b = 0.3 } },
		{ key = "talents", slot = "talents", text = L["Unspent Talent Points"], color = { r = 1, g = 0.82, b = 0 } },
		{ key = "durability", slot = "durability", text = L["Low Durability"], color = { r = 1, g = 0.27, b = 0.27 } },
		{ key = "tracking", slot = "tracking", text = L["Not Tracking"], color = { r = 1, g = 0.6, b = 0.2 } },
	},
	-- Pet Low Health and Low Health come last: their lines stay shown at no opacity while health is above the mark, so
	-- they hold no room between other lines. The player's own is the very last, the one that never leaves a gap.
	SLOTS = { "combat", "potion", "pet", "petStance", "talents", "durability", "tracking", "petHealth", "health" },
	FONT_PATH = "notifications.font",
	SIZE_PATH = "notifications.size",
	OUTLINE_PATH = "notifications.outline",
	DURATION_PATH = "notifications.duration",
	POSITION_PATH = "notifications.position",
	PET_HEALTH_PATH = "notifications.petHealth.below",
	DURABILITY_PATH = "notifications.durability.below",
	LOW_HEALTH_PATH = "notifications.lowHealth.below",
	TRACKING_PATH = "notifications.tracking.remind",
	MOVE_RESPONSE = 0.35,
	FADE_IN = 0.3,
	FADE_OUT = 0.3,
	TRAVEL = 8,
	REST_DISTANCE = 0.1,
	REST_ALPHA = 0.01,
	COMBAT_GRACE = 0.5,
	DISMOUNT_GRACE = 3,
	LINE_GAP = 2,
	MIN_SIZE = 10,
	MAX_SIZE = 48,
}
AUI.NotificationOptions = Options

local BY_KEY = {}
for _, notice in ipairs(Options.NOTICES) do
	BY_KEY[notice.key] = notice
end

local SLOT_ORDER = {}
for index, slot in ipairs(Options.SLOTS) do
	SLOT_ORDER[slot] = index
end

---@param key string a notice's key
---@param field string "enabled", "text" or "color"
---@return string path
function Options:Path(key, field)
	return "notifications." .. key .. "." .. field
end

---@param key string
---@return AUINotice
function Options:Notice(key)
	return BY_KEY[key]
end

---@param slot string
---@return number order the slot's place in the stack, top first
function Options:SlotOrder(slot)
	return SLOT_ORDER[slot] or #Options.SLOTS + 1
end

for _, notice in ipairs(Options.NOTICES) do
	Schema:Boolean(Options:Path(notice.key, "enabled"), false)
	Schema:String(Options:Path(notice.key, "text"), notice.text, 40)
	Schema:Color(Options:Path(notice.key, "color"), notice.color)
end

Schema:String(Options.FONT_PATH, "Friz Quadrata TT", 64)
Schema:Number(Options.SIZE_PATH, 22, Options.MIN_SIZE, Options.MAX_SIZE, true)
Schema:Choice(Options.OUTLINE_PATH, "fontOutline", "SLUG")
Schema:Number(Options.DURATION_PATH, 3, 1, 10, true)
Schema:Position(Options.POSITION_PATH)
Schema:Number(Options.PET_HEALTH_PATH, 25, 5, 90, true)
Schema:Number(Options.DURABILITY_PATH, 40, 10, 90, true)
Schema:Number(Options.LOW_HEALTH_PATH, 35, 5, 90, true)

---@param key string
---@return boolean on
function Options:On(key)
	return AUI.Profile:Get(self:Path(key, "enabled")) == true
end

---@param key string
---@return string text the notice's text, or its default when the saved text is empty
function Options:Text(key)
	local text = AUI.Profile:Get(self:Path(key, "text"))

	if type(text) ~= "string" or text == "" then
		return BY_KEY[key].text
	end

	return text
end

---@param key string
---@return { r: number, g: number, b: number }
function Options:Color(key)
	return AUI.Profile:Get(self:Path(key, "color")) or BY_KEY[key].color
end

---Where the stack sits by default: its top 150 units above the screen's center.
---@param parentHeight number UIParent's height
---@return { point: string, x: number, y: number }
function Options:DefaultPosition(parentHeight)
	return { point = "TOP", x = 0, y = -math.floor(parentHeight / 2 - 150 + 0.5) }
end

-- Pet --------------------------------------------------------------------------------------------------------

-- Permanent pet summons; a character knowing any of them is reminded about its pet. Spells a client lacks are never
-- known.
Options.PET_SPELLS = {
	883, -- Call Pet 1
	688, -- Summon Imp
	697, -- Summon Voidwalker
	691, -- Summon Felhunter
	712, -- Summon Succubus
	366222, -- Summon Sayaad
	30146, -- Summon Felguard
	46584, -- Raise Dead (Unholy)
}
-- Hunter choices to fight without a pet: Lone Wolf and its taught version.
Options.NO_PET_SPELLS = { 415370, 409979 }
Options.MARKSMANSHIP = 254
-- The talent that gives Marksmanship a pet.
Options.MARKSMANSHIP_PET = 1223323
Options.SACRIFICE_TALENT = 108503
Options.SACRIFICE_AURA = 196099

---@param known fun(spellID: number): boolean whether the character knows a spell
---@param specID number? the character's specialization, where the client has them
---@param sacrificed boolean the warlock's demon is sacrificed
---@return boolean eligible the character should have its pet out
function Options:PetEligible(known, specID, sacrificed)
	local summons = false

	for _, spell in ipairs(self.PET_SPELLS) do
		if known(spell) then
			summons = true
			break
		end
	end

	if not summons or sacrificed then
		return false
	end

	for _, spell in ipairs(self.NO_PET_SPELLS) do
		if known(spell) then
			return false
		end
	end

	if specID == self.MARKSMANSHIP and not known(self.MARKSMANSHIP_PET) then
		return false
	end

	return true
end

---@class AUIPetState
---@field inCombat boolean
---@field inInstance boolean in an instance that is not a house or neighborhood
---@field mounted boolean mounted, or within the grace after dismounting
---@field vehicle boolean
---@field taxi boolean
---@field dead boolean the player is dead or a ghost

---@param state AUIPetState
---@return boolean apply pet reminders apply now
function Options:PetRemindersApply(state)
	return (state.inCombat or state.inInstance) and not state.mounted and not state.vehicle and not state.taxi
		and not state.dead
end

---@param inInstance boolean
---@param instanceType string?
---@return boolean counts an instance for pet reminders: not a house or neighborhood
function Options:CountsAsInstance(inInstance, instanceType)
	return inInstance == true and instanceType ~= "interior" and instanceType ~= "neighborhood"
end

---A health curve's points, for the pet's or the player's, as `{ x, y }` with x the health from 0 to 1: opaque below the
---mark, clear at it and above.
---@param below number the mark, a percentage
---@return number[][] points
function Options:HealthCurve(below)
	local mark = below / 100

	return { { 0, 1 }, { mark - 0.001, 1 }, { mark, 0 }, { 1, 0 } }
end

-- Durability and potions -------------------------------------------------------------------------------------

---@param pieces { current: number, maximum: number }[] the equipped items that have durability
---@return number? percent the lowest durability, rounded down; nil when nothing has durability
function Options:LowestDurability(pieces)
	local lowest

	for _, piece in ipairs(pieces) do
		if piece.maximum and piece.maximum > 0 then
			local percent = math.floor(piece.current / piece.maximum * 100)

			lowest = lowest and math.min(lowest, percent) or percent
		end
	end

	return lowest
end

---@param key string "durability"
---@param percent number
---@return string text Low Durability's text with the lowest durability
function Options:DurabilityText(key, percent)
	return ("%s (%d%%)"):format(self:Text(key), percent)
end

-- A cooldown at most this long is the global cooldown, not the potion's own.
Options.GCD_CEILING = 1.5

---Where a used potion's cooldown stands.
---@param start number
---@param duration number
---@param enable number 0 while the cooldown waits to start (some clients start it when combat ends)
---@param now number
---@return string state "waiting" before the cooldown runs, "running", or "over"
---@return number? remaining seconds left while running
function Options:PotionCooldown(start, duration, enable, now)
	if enable == 0 then
		return "waiting"
	end

	if duration > self.GCD_CEILING then
		local remaining = start + duration - now

		if remaining > 0 then
			return "running", remaining
		end
	end

	return "over"
end

-- Tracking ---------------------------------------------------------------------------------------------------

-- Cat Form's shapeshift form ID, the form a druid tracks humanoids in.
local CAT_FORM = 1

---A tracking Tracking reminds about: the minimap tracking spells that turn it on (a profession's ranks), who has it,
---for the page's list, and the form it applies in.
---@class AUITracking
---@field key string
---@field spells number[]
---@field label string
---@field class string? the class that learns it
---@field race string? the race that has it
---@field form number? the shapeshift form ID it applies in

Options.TRACKINGS = {
	{ key = "beasts", spells = { 1494 }, class = "HUNTER", label = L["Beasts"] },
	{ key = "humanoids", spells = { 19883 }, class = "HUNTER", label = L["Humanoids"] },
	{ key = "undead", spells = { 19884 }, class = "HUNTER", label = L["Undead"] },
	{ key = "hidden", spells = { 19885 }, class = "HUNTER", label = L["Hidden"] },
	{ key = "elementals", spells = { 19880 }, class = "HUNTER", label = L["Elementals"] },
	{ key = "demons", spells = { 19878 }, class = "HUNTER", label = L["Demons"] },
	{ key = "giants", spells = { 19882 }, class = "HUNTER", label = L["Giants"] },
	{ key = "dragonkin", spells = { 19879 }, class = "HUNTER", label = L["Dragonkin"] },
	{ key = "druidHumanoids", spells = { 5225 }, class = "DRUID", form = CAT_FORM, label = L["Humanoids"] },
	{ key = "senseUndead", spells = { 5502 }, class = "PALADIN", label = L["Undead"] },
	{ key = "senseDemons", spells = { 5500 }, class = "WARLOCK", label = L["Demons"] },
	{ key = "treasure", spells = { 2481 }, race = "Dwarf", label = L["Treasure"] },
	{ key = "herbs", spells = { 2383, 8387 }, label = L["Herbs"] },
	{ key = "minerals", spells = { 2580, 8388 }, label = L["Minerals"] },
}

for _, tracking in ipairs(Options.TRACKINGS) do
	Schema:Boolean(Options.TRACKING_PATH .. "." .. tracking.key, true)
end

---@param class string? the character's class token
---@param race string? the character's race token
---@return AUITracking[] trackings those the character can have: its class's, its race's and the professions'
function Options:TrackingsFor(class, race)
	local list = {}

	for _, tracking in ipairs(self.TRACKINGS) do
		if (tracking.class == nil or tracking.class == class) and (tracking.race == nil or tracking.race == race) then
			list[#list + 1] = tracking
		end
	end

	return list
end

---The trackings that are off. Only trackings in the minimap's tracking list count, so one the character lacks is never
---missing; one tied to a form counts only in that form.
---@param tracked table<number, boolean> each tracking spell in the minimap's list, and whether it is on
---@param form number? the character's shapeshift form ID
---@param remind fun(key: string): boolean whether Tracking reminds about a tracking
---@return string[] labels the missing trackings' labels, in list order
function Options:MissingTrackings(tracked, form, remind)
	local labels = {}

	for _, tracking in ipairs(self.TRACKINGS) do
		local listed, on = false, false

		for _, spell in ipairs(tracking.spells) do
			if tracked[spell] ~= nil then
				listed = true
				on = on or tracked[spell]
			end
		end

		if listed and not on and remind(tracking.key) and (tracking.form == nil or tracking.form == form) then
			labels[#labels + 1] = tracking.label
		end
	end

	return labels
end

---@param labels string[]
---@return string text Tracking's text followed by the missing trackings
function Options:TrackingText(labels)
	return ("%s: %s"):format(self:Text("tracking"), table.concat(labels, ", "))
end
