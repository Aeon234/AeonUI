local AUI = select(2, ...)

local L = AUI.L
local Schema = AUI.Schema

---A movement ability the alert can track: its spell IDs, the one a character knows first being the one tracked, the
---specializations it applies to (all of the class's when absent), and whether it starts unchecked.
---@class AUIMovementSpell
---@field ids number[]
---@field specs table<number, true>?
---@field off boolean?

---The Movement Alerts settings and their frame-free rules: each class's abilities, which of them a character tracks,
---the text's format, its number's format, the curve that hides short cooldowns and the lines' places.
---@class AUIMovementAlertOptions
---@field ENABLED_PATH string the page's switch
---@field COMBAT_ONLY_PATH string the lines show only in combat
---@field ARRANGEMENT_PATH string a `movementAlertArrangement` choice
---@field DECIMAL_PATH string the number shows one decimal rather than whole seconds
---@field FONT_PATH string
---@field SIZE_PATH string
---@field OUTLINE_PATH string
---@field COLOR_PATH string
---@field CLASS_COLOR_PATH string the player's class color instead of `COLOR_PATH`
---@field POSITION_PATH string
---@field SPELLS_PATH string the branch holding, per ability, whether it is tracked
---@field ARRANGEMENTS string[] the Arrangement choices, in the order the page lists them
---@field MIN_COOLDOWN number seconds; a cooldown shorter than this is a global cooldown or a shared lockout
---@field WIDTH number
---@field LINE_HEIGHT number
---@field LINE_GAP number
---@field MIN_SIZE number
---@field MAX_SIZE number
local Options = {
	ENABLED_PATH = "movementAlert.enabled",
	COMBAT_ONLY_PATH = "movementAlert.combatOnly",
	ARRANGEMENT_PATH = "movementAlert.arrangement",
	DECIMAL_PATH = "movementAlert.decimal",
	FONT_PATH = "movementAlert.font",
	SIZE_PATH = "movementAlert.size",
	OUTLINE_PATH = "movementAlert.outline",
	COLOR_PATH = "movementAlert.color",
	CLASS_COLOR_PATH = "movementAlert.classColor",
	POSITION_PATH = "movementAlert.position",
	SPELLS_PATH = "movementAlert.spells",
	ARRANGEMENTS = { "DURATION_NAME", "NAME_DURATION", "DURATION" },
	MIN_COOLDOWN = 3,
	WIDTH = 200,
	LINE_HEIGHT = 40,
	LINE_GAP = 2,
	MIN_SIZE = 8,
	MAX_SIZE = 72,
}
AUI.MovementAlertOptions = Options

-- Spell IDs are the client's; each is confirmed known on its class through `/aui dev` before it is relied on.
local CLASS_SPELLS = {
	DEATHKNIGHT = {
		{ ids = { 48265 } },
		{ ids = { 212552 }, off = true },
		{ ids = { 444347, 444010 }, specs = { [252] = true } },
	},
	DEMONHUNTER = {
		{ ids = { 195072 }, specs = { [577] = true } },
		{ ids = { 189110 }, specs = { [581] = true } },
		{ ids = { 1234796 }, specs = { [1480] = true } },
	},
	DRUID = {
		{ ids = { 102401, 102417 } },
		{ ids = { 1850 }, off = true },
		{ ids = { 252216 }, off = true },
		{ ids = { 106898, 77761, 77764 }, specs = { [104] = true }, off = true },
	},
	EVOKER = {
		{ ids = { 358267 } },
	},
	HUNTER = {
		{ ids = { 186257 } },
		{ ids = { 781 } },
	},
	MAGE = {
		{ ids = { 212653, 1953 } },
	},
	MONK = {
		{ ids = { 115008, 109132 } },
		{ ids = { 119085 } },
		{ ids = { 361138 } },
		{ ids = { 101545 }, specs = { [269] = true } },
	},
	PALADIN = {
		{ ids = { 190784 } },
	},
	PRIEST = {
		{ ids = { 121536 } },
		{ ids = { 73325 }, off = true },
	},
	ROGUE = {
		{ ids = { 36554 }, specs = { [259] = true, [261] = true } },
		{ ids = { 195457 }, specs = { [260] = true } },
		{ ids = { 2983 }, off = true },
	},
	SHAMAN = {
		{ ids = { 79206 }, specs = { [262] = true, [264] = true }, off = true },
		{ ids = { 192063 } },
		{ ids = { 58875, 90328 }, off = true },
	},
	WARLOCK = {
		{ ids = { 48020 } },
	},
	WARRIOR = {
		{ ids = { 6544 } },
	},
}
local NO_SPELLS = {}

---@param spell AUIMovementSpell
---@return string path whether the ability is tracked
function Options:SpellPath(spell)
	return self.SPELLS_PATH .. "." .. spell.ids[1]
end

Schema:Choices("movementAlertArrangement", Options.ARRANGEMENTS)

Schema:Boolean(Options.ENABLED_PATH, false)
Schema:Boolean(Options.COMBAT_ONLY_PATH, false)
Schema:Choice(Options.ARRANGEMENT_PATH, "movementAlertArrangement", "DURATION_NAME")
Schema:Boolean(Options.DECIMAL_PATH, true)
Schema:String(Options.FONT_PATH, "Friz Quadrata TT", 64)
Schema:Number(Options.SIZE_PATH, 24, Options.MIN_SIZE, Options.MAX_SIZE, true)
Schema:Choice(Options.OUTLINE_PATH, "fontOutline", "SLUG")
Schema:Color(Options.COLOR_PATH, { r = 1, g = 1, b = 1 })
Schema:Boolean(Options.CLASS_COLOR_PATH, false)
Schema:Position(Options.POSITION_PATH)

for _, spells in pairs(CLASS_SPELLS) do
	for _, spell in ipairs(spells) do
		Schema:Boolean(Options:SpellPath(spell), not spell.off)
	end
end

---@param class string the class's file name
---@return AUIMovementSpell[] spells the class's abilities, in the order the page lists them and the lines stack
function Options:ClassSpells(class)
	return CLASS_SPELLS[class] or NO_SPELLS
end

---The spell IDs a character tracks: one per checked ability of its specialization that it knows.
---@param class string the class's file name
---@param specID number? nil while the specialization is not known yet, which tracks nothing
---@param known fun(spellID: number): boolean whether the character knows a spell
---@param tracked fun(spell: AUIMovementSpell): boolean whether an ability is checked
---@return number[] spellIDs
function Options:TrackedSpells(class, specID, known, tracked)
	local spellIDs = {}

	if not specID then
		return spellIDs
	end

	for _, spell in ipairs(self:ClassSpells(class)) do
		if (not spell.specs or spell.specs[specID]) and tracked(spell) then
			for _, id in ipairs(spell.ids) do
				if known(id) then
					spellIDs[#spellIDs + 1] = id
					break
				end
			end
		end
	end

	return spellIDs
end

---@param combatOnly boolean Combat Only is on
---@param inCombat boolean
---@return boolean allowed lines may show now
function Options:LinesAllowed(combatOnly, inCombat)
	return inCombat or not combatOnly
end

---Whether a cooldown is the spell's own rather than the global cooldown, from fields the client never makes secret.
---@param cooldown table? `C_Spell.GetSpellCooldown`'s answer
---@param charges boolean the spell has charges, which an unknown `isOnGCD` may be banked behind
---@return boolean own
function Options:OnOwnCooldown(cooldown, charges)
	if not cooldown or not cooldown.isActive then
		return false
	end

	return cooldown.isOnGCD == false or (cooldown.isOnGCD == nil and not charges)
end

---A duration text binding's format for a line: `{}` is where the binding writes the time.
---@param arrangement string a `movementAlertArrangement` choice
---@param name string the spell's name
---@return string format
function Options:TextFormat(arrangement, name)
	if arrangement == "DURATION" then
		return "{}"
	end

	local text = L["No %s"]:format(name)

	if arrangement == "NAME_DURATION" then
		return text .. " {}"
	end

	return "{} " .. text
end

---A numeric rule formatter's breakpoints for the time.
---@param decimal boolean one decimal rather than whole seconds
---@return table[] breakpoints
function Options:TimeBreakpoints(decimal)
	if decimal then
		return { { threshold = 0, step = 0.1, format = "%.1f" } }
	end

	return { { threshold = 0, step = 1, format = "%.0f" } }
end

---A step curve's points, as `{ x, y }` with x a cooldown's total in seconds and y a line's opacity.
---@return number[][] points
function Options:VisibilityCurve()
	return { { 0, 0 }, { self.MIN_COOLDOWN, 1 } }
end

---A line's text with a time standing in for the running one, for samples.
---@param arrangement string a `movementAlertArrangement` choice
---@param decimal boolean one decimal rather than whole seconds
---@param name string the spell's name
---@return string text
function Options:SampleText(arrangement, decimal, name)
	local text = self:TextFormat(arrangement, name):gsub("{}", decimal and "12.3" or "12")

	return text
end

---@param size number the font's size
---@return number height a line's height, which clears a large font
function Options:LineHeight(size)
	return math.max(self.LINE_HEIGHT, math.ceil(size * 1.25))
end

---@param index number a line's place in the stack, the bottom's being 1
---@param size number the font's size
---@return number y its bottom's offset from the frame's bottom
function Options:LineOffset(index, size)
	return (index - 1) * (self:LineHeight(size) + self.LINE_GAP)
end

---Where the frame sits by default: its bottom 30 units above the screen's center.
---@param parentHeight number UIParent's height
---@return { point: string, x: number, y: number }
function Options:DefaultPosition(parentHeight)
	return { point = "BOTTOM", x = 0, y = math.floor(parentHeight / 2 + 30 + 0.5) }
end
