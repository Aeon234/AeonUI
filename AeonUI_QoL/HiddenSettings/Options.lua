local AUI = select(2, ...)

---A console variable and the value a hold keeps it at.
---@class AUIHeldCVar
---@field name string
---@field value string

---The Hidden Settings rules: the values each hold keeps, and what saving, holding and restoring console variables
---write. Every function reads console variables through `read`, which returns nil for one the client lacks.
---@class AUIHiddenSettingsOptions
---@field LOOT_SPARKLE AUIHeldCVar[] quest items sparkle only while the outline mode is off and the loot effect is on
---@field LOOT_SPARKLE_TRIGGERS string[] console variables whose change resets the loot sparkle's
---@field SOFT_TARGET AUIHeldCVar[] interaction soft targeting all around, far and with its icons; the gate last
---@field GATE string the gate: the game's nameplate on the interaction target, open only while it should sparkle
---@field SPARKLE_TYPES string[] the approached objects that can sparkle, in the order the page lists them
---@field POLL_INTERVAL number seconds between checks of the target while a soft target exists
---@field STATE_DELAY number seconds a new state must hold before it shows
---@field LOCK_DELAY number the same for the locked state
---@field BOBBER_ID number the fishing bobber's object ID
---@field CONTAINER_CAP number the most looted containers the account remembers
local Options = {
	LOOT_SPARKLE = {
		{ name = "outlineModeShowLootEffectWhenDisabled", value = "1" },
		{ name = "graphicsOutlineMode", value = "0" },
		{ name = "raidGraphicsOutlineMode", value = "0" },
		{ name = "OutlineEngineMode", value = "0" },
		{ name = "RAIDOutlineEngineMode", value = "0" },
	},
	LOOT_SPARKLE_TRIGGERS = { "graphicsQuality", "raidGraphicsQuality" },
	SOFT_TARGET = {
		{ name = "SoftTargetInteract", value = "3" },
		{ name = "SoftTargetInteractRange", value = "60" },
		{ name = "SoftTargetInteractArc", value = "2" },
		{ name = "SoftTargetInteractOnlyInRange", value = "0" },
		{ name = "SoftTargetIconInteract", value = "1" },
		{ name = "SoftTargetIconGameObject", value = "1" },
		{ name = "SoftTargetLowPriorityIcons", value = "1" },
		{ name = "SoftTargetNameplateInteract", value = "0" },
	},
	GATE = "SoftTargetNameplateInteract",
	SPARKLE_TYPES = { "ore", "herbs", "questObjects", "corpses", "chests", "bobber" },
	POLL_INTERVAL = 0.15,
	STATE_DELAY = 0.15,
	LOCK_DELAY = 0.6,
	BOBBER_ID = 35591,
	CONTAINER_CAP = 500,
}

-- Keywords in a cursor's file path or atlas name, lowercased, and the type each names; the first match wins.
local CURSOR_KEYWORDS = {
	{ "gather", "herbs" },
	{ "herb", "herbs" },
	{ "mine", "ore" },
	{ "quest", "questObjects" },
	{ "lootall", "chests" },
	{ "pickup", "chests" },
	{ "picklock", "chests" },
	{ "interact", "other" },
	{ "mail", "service" },
	{ "speak", "service" },
	{ "buy", "service" },
	{ "trainer", "service" },
	{ "taxi", "service" },
	{ "innkeeper", "service" },
	{ "repair", "service" },
	{ "stablemaster", "service" },
}
local GOLD = { 1, 0.88, 0.52 }
local GRAY = { 0.62, 0.62, 0.62 }
AUI.HiddenSettingsOptions = Options

---Adds the current value of each held console variable not yet saved. Values already saved are kept.
---@param held AUIHeldCVar[]
---@param read fun(name: string): string?
---@param saved table<string, string>
---@return table<string, string> saved
function Options.Save(held, read, saved)
	for _, entry in ipairs(held) do
		if saved[entry.name] == nil then
			saved[entry.name] = read(entry.name)
		end
	end

	return saved
end

---@param wanted AUIHeldCVar[]
---@param read fun(name: string): string?
---@return AUIHeldCVar[] writes the entries whose console variable exists and holds another value, in order
function Options.Pending(wanted, read)
	local writes = {}

	for _, entry in ipairs(wanted) do
		local value = read(entry.name)

		if value ~= nil and value ~= entry.value then
			writes[#writes + 1] = entry
		end
	end

	return writes
end

---@param held AUIHeldCVar[]
---@param saved table<string, any> a save, possibly damaged: only held names with text values are restored
---@param read fun(name: string): string?
---@return AUIHeldCVar[] writes the saved values that differ from the current ones, in held order
function Options.Restore(held, saved, read)
	local wanted = {}

	for _, entry in ipairs(held) do
		local value = saved[entry.name]

		if type(value) == "string" then
			wanted[#wanted + 1] = { name = entry.name, value = value }
		end
	end

	return Options.Pending(wanted, read)
end

---@param names string[]
---@param cvar string? a console variable's name, in any case
---@return boolean
function Options.Watches(names, cvar)
	if type(cvar) ~= "string" then
		return false
	end

	cvar = cvar:lower()

	for _, name in ipairs(names) do
		if name:lower() == cvar then
			return true
		end
	end

	return false
end

---@param name string? a cursor's file path or atlas name
---@return string? type `ore`, `herbs`, `questObjects`, `chests`, `service` (a mailbox or an NPC's service, never a chest)
---or `other`; nil for a cursor that names none
---@return boolean unable the cursor's Unable variant: the object cannot be used now
function Options.CursorType(name)
	if type(name) ~= "string" then
		return nil, false
	end

	name = name:lower()

	local unable = name:find("unable", 1, true) ~= nil

	for _, keyword in ipairs(CURSOR_KEYWORDS) do
		if name:find(keyword[1], 1, true) then
			return keyword[2], unable
		end
	end

	return nil, unable
end

---@param text string an objective's text, such as "Soaked Saw: 0/1"
---@return string text lowercased, without counters, spaces normalized and the ends trimmed
function Options.NormalizeObjective(text)
	text = text:lower():gsub("\194\160", " "):gsub("\226\128\153", "'"):gsub("%d+%s*/%s*%d+", "")
	text = text:gsub("^[%s:%-]+", ""):gsub("[%s:%-]+$", "")

	return text
end

---An object's name names an objective when the objective contains it, or it contains an objective of five letters or
---more ("Supplies" in "Crate of Supplies").
---@param name string?
---@param objectives string[] unfinished objectives, normalized
---@return boolean
function Options.MatchesObjective(name, objectives)
	if type(name) ~= "string" then
		return false
	end

	if #name < 4 then
		return false
	end

	name = Options.NormalizeObjective(name)

	for _, objective in ipairs(objectives) do
		if objective:find(name, 1, true) or (#objective >= 5 and name:find(objective, 1, true)) then
			return true
		end
	end

	return false
end

---@param inRange boolean? within interaction range; nil when the client does not say
---@param unable boolean the cursor's Unable variant
---@return string state `far`, `ready` or `locked`
function Options.State(inRange, unable)
	if inRange == false then
		return "far"
	end

	if unable then
		return inRange == true and "locked" or "far"
	end

	return "ready"
end

---A new state shows only once it has held for `STATE_DELAY`, or `LOCK_DELAY` for locked.
---@param shown string the state shown
---@param pending string? the state waiting to show
---@param since number? when it started waiting
---@param state string the state read now
---@param now number
---@return string shown
---@return string? pending
---@return number? since
function Options.Propose(shown, pending, since, state, now)
	if state == shown then
		return shown, nil, nil
	end

	if pending ~= state or not since then
		return shown, state, now
	end

	if now - since >= (state == "locked" and Options.LOCK_DELAY or Options.STATE_DELAY) then
		return state, nil, nil
	end

	return shown, pending, since
end

---@param from number
---@param to number
---@param share number
---@return number
local function Lerp(from, to, share)
	return from + (to - from) * share
end

---The glints' look for a blend of states: dimmer and calmer out of range, gray and slow when locked.
---@param appear number 0 to 1, the fade in
---@param ready number 0 to 1, the share of the ready state
---@param locked number 0 to 1, the share of the locked state
---@return number alpha
---@return number speed
---@return number r
---@return number g
---@return number b
function Options.Blend(appear, ready, locked)
	return appear * Lerp(0.55, 1, ready) * (1 - 0.55 * locked), Lerp(0.8, 1.2, ready) * (1 - 0.5 * locked),
		Lerp(GOLD[1], GRAY[1], locked), Lerp(GOLD[2], GRAY[2], locked), Lerp(GOLD[3], GRAY[3], locked)
end

---@param guid string? a game object's GUID: `GameObject-0-<server>-<instance>-<zone>-<id>-<spawn>`
---@return number? id the object's ID, the same for every object of its kind; nil for anything else
function Options.ObjectID(guid)
	if type(guid) ~= "string" then
		return nil
	end

	return tonumber(guid:match("^GameObject%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
end

---@param text string space-separated words
---@return string[] words lowercased
function Options.ChestWords(text)
	local words = {}

	for word in text:lower():gmatch("%S+") do
		words[#words + 1] = word
	end

	return words
end

---A name names a chest when one of its words starts or ends with a chest word.
---@param name string?
---@param words string[] chest words, lowercased
---@return boolean
function Options.NamesChest(name, words)
	if type(name) ~= "string" then
		return false
	end

	for part in name:lower():gmatch("[^%s%p]+") do
		for _, word in ipairs(words) do
			if part:sub(1, #word) == word or (#part > #word and part:sub(-#word) == word) then
				return true
			end
		end
	end

	return false
end

---Adds a looted container's object ID, then drops the oldest beyond `cap`.
---@param list number[] the IDs, oldest first
---@param id number
---@param cap number
---@return boolean added false when it was listed already
function Options.Learn(list, id, cap)
	for _, listed in ipairs(list) do
		if listed == id then
			return false
		end
	end

	list[#list + 1] = id

	while #list > cap do
		table.remove(list, 1)
	end

	return true
end
