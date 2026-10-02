local AUI = select(2, ...)

-- Deepest nesting accepted in profile data, including fields this version does not know.
local MAX_DEPTH = 32

---One setting a profile can hold: its type, default and bounds.
---@class AUISchemaField
---@field path string dot-separated path inside a profile's config
---@field kind "boolean"|"number"|"choice"|"string"|"color"
---@field default any the factory value; nil for an optional field, which then follows a shared setting
---@field min number?
---@field max number?
---@field integer boolean? a number must be whole
---@field options table<string, true>? the values a choice accepts
---@field maxLength integer? the longest string accepted
---@field allowEmpty boolean? a string may be empty
---@field optional boolean? absence is meaningful: the setting follows a shared one

---Every setting a profile can hold. A profile's config is validated against these fields; keys outside them are
---dormant data from another version and are kept as they are, provided they are plain data.
---@class AUISchema
---@field VERSION integer the profile config schema version
---@field textSlots table<string, integer> how many text slots each frame has
---@field fields table<string, AUISchemaField>
---@field order string[] field paths in declaration order
---@field branches table<string, true> every path that is a table on the way to a field
---@field choices table<string, string[]> each choice list in display order
local Schema = {
	VERSION = 1,
	textSlots = {
		player = 4,
		pet = 3,
		target = 4,
		targettarget = 3,
		focus = 4,
		boss = 4,
		playerPower = 2,
	},
	fields = {},
	order = {},
	branches = {},
	choices = {
		content = {
			"none", "name", "level", "levelName", "health", "healthPercent", "healthAndPercent", "missingHealth",
			"absorb", "healAbsorb", "power", "powerPercent",
		},
		separator = { "bar", "dash", "slash", "space", "parentheses", "brackets", "bullet" },
		anchor = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" },
		placement = { "inside", "edge", "outside" },
		outline = { "NONE", "OUTLINE", "THICKOUTLINE", "SLUG", "SLUG_OUTLINE", "SLUG_THICKOUTLINE" },
		colorMode = { "custom", "class", "power", "difficulty" },
		nameFormat = { "first", "full" },
		precision = { "default", "decimal" },
		overlayPosition = { "attach", "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", "LEFT", "RIGHT" },
		overshield = { "never", "always", "fromLeft" },
		growth = { "down", "up", "right", "left" },
		castSide = { "below", "above" },
		strata = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG" },
		orientation = { "HORIZONTAL", "VERTICAL" },
		iconSide = { "LEFT", "RIGHT" },
		timeFormat = { "remaining", "elapsed", "remainingTotal", "elapsedTotal" },
		glowStyle = { "pixel", "blizzard" },
		auraAnchor = { "aboveLeft", "aboveRight", "belowLeft", "belowRight", "left", "right" },
		auraGrowth = { "right", "left" },
		buffFilter = {
			"all", "own", "important", "importantOwn", "hasDuration", "tracked", "bigDefensive", "externalDefensive",
			"raidInCombat", "stealable", "anyDispellable", "notYours", "classCanApply",
		},
		debuffFilter = {
			"all", "own", "important", "importantOwn", "tracked", "crowdControl", "boss", "role", "raidInCombat",
			"dispellableByYou", "anyDispellable", "magic", "curse", "disease", "poison", "notYours", "classCanApply",
		},
		buffHide = {
			"important", "bigDefensive", "externalDefensive", "raidInCombat", "stealable", "anyDispellable", "yours",
			"notYours", "classCanApply",
		},
		debuffHide = {
			"crowdControl", "boss", "role", "raidInCombat", "important", "dispellableByYou", "anyDispellable", "magic",
			"curse", "disease", "poison", "yours", "notYours", "classCanApply",
		},
		listCaster = { "anyone", "yours" },
		classPowerAttach = { "power", "screen" },
		auraSort = { "stable", "shortest", "yours", "blizzard", "importance", "name" },
		auraCorner = { "BOTTOMRIGHT", "BOTTOMLEFT", "TOPRIGHT", "TOPLEFT", "CENTER" },
	},
}
AUI.Schema = Schema

---@param path string
---@param spec table the field's kind, default and bounds
local function Field(path, spec)
	spec.path = path
	Schema.fields[path] = spec
	Schema.order[#Schema.order + 1] = path

	local branch = path:match("^(.*)%.[^.]+$")

	while branch do
		Schema.branches[branch] = true
		branch = branch:match("^(.*)%.[^.]+$")
	end
end

---@param path string
---@param default boolean
local function Boolean(path, default)
	Field(path, { kind = "boolean", default = default })
end

---@param path string
---@param default number? nil makes the field optional
---@param min number
---@param max number
---@param integer boolean?
local function Number(path, default, min, max, integer)
	Field(path, { kind = "number", default = default, min = min, max = max, integer = integer, optional = default == nil })
end

---@param path string
---@param list string a choice list in `Schema.choices`
---@param default string? nil makes the field optional
local function Choice(path, list, default)
	local options = {}

	for _, value in ipairs(Schema.choices[list]) do
		options[value] = true
	end

	Field(path, { kind = "choice", default = default, options = options, optional = default == nil })
end

---@param path string
---@param default string? nil makes the field optional; an empty default lets the text be empty
---@param maxLength integer
local function String(path, default, maxLength)
	Field(path, {
		kind = "string",
		default = default,
		maxLength = maxLength,
		optional = default == nil,
		allowEmpty = default == "",
	})
end

---@param path string
---@param default table? `{ r, g, b, a? }`; nil makes the field optional
local function Color(path, default)
	Field(path, { kind = "color", default = default, optional = default == nil })
end

-- How numbers are shown on every frame; each frame can override these below.
Choice("numbers.precision", "precision", "default")
Number("numbers.percentDecimals", 0, 0, 1, true)

-- Health overlay colors, shared by every frame.
Color("overlays.colors.absorb", { r = 0.502, g = 0.753, b = 1, a = 0.8 })
Color("overlays.colors.healAbsorb", { r = 0.502, g = 0.251, b = 1, a = 1 })
Color("overlays.colors.healPrediction", { r = 0.251, g = 1, b = 0.251, a = 1 })

---@class AUITextSlotDefault
---@field content string
---@field separator string?
---@field anchor string
---@field placement string
---@field x number?
---@field colorMode string?

---@param base string the frame's text path, ending in a dot
---@param index integer
---@param slot AUITextSlotDefault?
local function TextSlot(base, index, slot)
	local path = base .. "slots." .. index .. "."

	slot = slot or { content = "none", anchor = "CENTER", placement = "inside" }

	Choice(path .. "content", "content", slot.content)
	Choice(path .. "separator", "separator", slot.separator or "dash")
	Choice(path .. "anchor", "anchor", slot.anchor)
	Choice(path .. "placement", "placement", slot.placement)
	Number(path .. "x", slot.x or 0, -200, 200)
	Number(path .. "y", 0, -200, 200)
	Number(path .. "width", 100, 20, 200, true)
	Choice(path .. "colorMode", "colorMode", slot.colorMode or "custom")
	String(path .. "font", nil, 64)
	Number(path .. "size", nil, 6, 48, true)
	Choice(path .. "outline", "outline", nil)
	Color(path .. "color", nil)
end

---A frame's text style, number overrides and slots.
---@param key string the frame's key under `frames`
---@param status integer the slot that shows status by default; 0 for none
---@param statusLine boolean? the Status Line default; nil for a frame without one
---@param slots AUITextSlotDefault[]
local function TextFields(key, status, statusLine, slots)
	local base = "frames." .. key .. "."
	local text = base .. "text."
	local count = Schema.textSlots[key]

	Choice(base .. "numbers.precision", "precision", nil)
	Number(base .. "numbers.percentDecimals", nil, 0, 1, true)

	String(text .. "font", "Expressway", 64)
	Number(text .. "size", 12, 6, 48, true)
	Choice(text .. "outline", "outline", "SLUG_OUTLINE")
	Color(text .. "color", { r = 1, g = 1, b = 1 })
	Number(text .. "status", status, 0, count, true)
	Choice(text .. "nameFormat", "nameFormat", "first")

	if statusLine ~= nil then
		Boolean(text .. "statusLine", statusLine)
	end

	for index = 1, count do
		TextSlot(text, index, slots[index])
	end
end

---@param key string the frame's key under `frames`
---@param width number
---@param height number
---@param minHeight number
---@param x number
---@param y number
local function Geometry(key, width, height, minHeight, x, y)
	local base = "frames." .. key .. "."

	Boolean(base .. "enabled", true)
	Number(base .. "width", width, 80, 600)
	Number(base .. "height", height, minHeight, 120)
	Number(base .. "x", x, -3000, 3000)
	Number(base .. "y", y, -3000, 3000)
end

---The health overlays of a frame: shields, heal absorbs and heal prediction.
---@param key string
local function Overlays(key)
	local base = "frames." .. key .. ".overlays."

	for _, kind in ipairs({ "absorb", "healAbsorb", "healPrediction" }) do
		local path = base .. kind .. "."

		Boolean(path .. "enabled", true)
		Choice(path .. "position", "overlayPosition", "attach")
		Number(path .. "height", 4, 1, 40, true)
		Boolean(path .. "matchHeight", true)
		String(path .. "texture", "flat", 64)
	end

	Choice(base .. "absorb.overshield", "overshield", "always")
	Boolean(base .. "absorb.glow", false)
	Number(base .. "healAbsorb.backing", 0, 0, 100, true)
	Number(base .. "healPrediction.overheal", 0, 0, 50, true)
end

---An optional power bar attached under a frame's health.
---@param key string
local function AttachedPower(key)
	Boolean("frames." .. key .. ".power.enabled", false)
	Number("frames." .. key .. ".power.height", 6, 4, 20, true)
end

---A frame's cast bar. The player's stands alone at a screen position; the others attach to their frame.
---@param key string
---@param defaults table `width`, `x`, `y`, `icon`, `target` (show the cast target), and `side` for an attached bar
local function CastBar(key, defaults)
	local base = "frames." .. key .. ".castbar."
	local white = { r = 1, g = 1, b = 1 }

	Boolean(base .. "enabled", true)
	Number(base .. "width", defaults.width, 40, 800, true)
	Number(base .. "height", 16, 6, 60, true)
	Number(base .. "x", defaults.x, -3000, 3000)
	Number(base .. "y", defaults.y, -3000, 3000)

	if defaults.side then
		Choice(base .. "side", "castSide", defaults.side)
		Boolean(base .. "matchWidth", true)
	end

	Choice(base .. "strata", "strata", "MEDIUM")
	Boolean(base .. "alwaysShow", false)
	String(base .. "texture", "flat", 64)
	Color(base .. "color", { r = 1, g = 0.71, b = 0.192 })
	Boolean(base .. "gradient", true)
	Color(base .. "gradientColor", { r = 1, g = 0.682, b = 0.224 })
	Choice(base .. "gradientDirection", "orientation", "HORIZONTAL")
	Boolean(base .. "classColor", false)
	Color(base .. "background", { r = 1, g = 1, b = 1, a = 0.5 })
	Number(base .. "border", 1, 0, 4, true)
	Boolean(base .. "spark", true)
	Boolean(base .. "reverse", false)
	Boolean(base .. "smooth", true)
	Boolean(base .. "icon", defaults.icon)
	Choice(base .. "iconSide", "iconSide", "LEFT")
	Boolean(base .. "name.enabled", true)
	Number(base .. "name.size", 14, 6, 48, true)
	Color(base .. "name.color", white)
	Number(base .. "name.x", 0, -200, 200)
	Number(base .. "name.y", 0, -200, 200)
	Number(base .. "name.maxLength", 0, 0, 60, true)
	Boolean(base .. "time.enabled", true)
	Number(base .. "time.size", 14, 6, 48, true)
	Color(base .. "time.color", white)
	Number(base .. "time.x", 0, -200, 200)
	Number(base .. "time.y", 0, -200, 200)
	Choice(base .. "time.format", "timeFormat", "remaining")
	Choice(base .. "outline", "outline", "SLUG")
	Boolean(base .. "shadow", true)
	Color(base .. "notInterruptible", { r = 0.8, g = 0.1, b = 0.1 })
	Color(base .. "interrupted", { r = 0.8, g = 0.1, b = 0.1 })
	Number(base .. "holdTime", 0.6, 0, 3)
	Boolean(base .. "target.enabled", defaults.target)
	Number(base .. "target.size", 14, 6, 48, true)
	Number(base .. "target.x", 0, -200, 200)
	Number(base .. "target.y", 0, -200, 200)

	if defaults.side then
		Boolean(base .. "interruptReady", true)
		Color(base .. "readyColor", { r = 0.92, g = 0.35, b = 0.2 })
		Boolean(base .. "interruptCooldown", false)
		Color(base .. "cooldownColor", { r = 0.8, g = 0.8, b = 0.8 })
		Boolean(base .. "kickMark", true)
		Boolean(base .. "kickWindow", false)
		Color(base .. "windowColor", { r = 0.318, g = 0.82, b = 0.357, a = 0.6 })
		Boolean(base .. "glow", false)
		Choice(base .. "glowStyle", "glowStyle", "pixel")
		Color(base .. "glowColor", { r = 1, g = 0.2, b = 0.2 })
		Number(base .. "glowLines", 8, 1, 20, true)
		Number(base .. "glowThickness", 2, 1, 6, true)
		Number(base .. "glowSpeed", 4, 1, 10, true)
	end

	if key == "player" then
		Boolean(base .. "latency", true)
		Color(base .. "latencyColor", { r = 1, g = 0.25, b = 0.25, a = 0.4 })
		Boolean(base .. "latencyText", false)
		Boolean(base .. "empowerColors", true)
		Color(base .. "stage.1", { r = 0.506, g = 0.525, b = 0.518 })
		Color(base .. "stage.2", { r = 0.624, g = 0.122, b = 0.161 })
		Color(base .. "stage.3", { r = 1, g = 0.447, b = 0.11 })
		Color(base .. "stage.4", { r = 1, g = 0.71, b = 0.192 })
		Boolean(base .. "stageLabel", false)
		Boolean(base .. "ticks", true)
		Color(base .. "tickColor", { r = 0, g = 0, b = 0, a = 0.7 })
		Boolean(base .. "lastTick", false)
	end
end

---A frame's buff or debuff display.
---@param key string
---@param kind "buffs"|"debuffs"
---@param defaults table `enabled`, `anchor`, `growth`, `limit` and `filter`
local function AuraDisplay(key, kind, defaults)
	local base = "frames." .. key .. "." .. kind .. "."

	Boolean(base .. "enabled", defaults.enabled)
	Number(base .. "size", 22, 10, 60, true)
	Number(base .. "limit", defaults.limit, 1, 40, true)
	Number(base .. "perRow", 0, 0, 40, true)
	Number(base .. "spacing", 2, 0, 20, true)
	Choice(base .. "anchor", "auraAnchor", defaults.anchor)
	Choice(base .. "growth", "auraGrowth", defaults.growth)
	Number(base .. "x", 0, -200, 200)
	Number(base .. "y", 0, -200, 200)
	Choice(base .. "filter", kind == "buffs" and "buffFilter" or "debuffFilter", defaults.filter)
	for _, category in ipairs(Schema.choices[kind == "buffs" and "buffHide" or "debuffHide"]) do
		Boolean(base .. "hide." .. category, false)
	end

	String(base .. "include", "", 1000)
	String(base .. "exclude", "", 1000)
	Choice(base .. "listCaster", "listCaster", "anyone")
	Choice(base .. "sort", "auraSort", "stable")
	Boolean(base .. "reverse", false)
	Boolean(base .. "clicks", false)
	Boolean(base .. "tooltips", true)
	Boolean(base .. "duration", false)
	Number(base .. "durationSize", 10, 6, 32, true)
	Number(base .. "durationX", 0, -40, 40)
	Number(base .. "durationY", 0, -40, 40)
	Choice(base .. "countCorner", "auraCorner", "BOTTOMRIGHT")
	Number(base .. "countSize", 14, 6, 32, true)
	Number(base .. "countX", -1, -40, 40)
	Number(base .. "countY", 0, -40, 40)
	Boolean(base .. "swipe", true)
	Boolean(base .. "border", true)
end

---@param key string
---@param buffs table
---@param debuffs table
local function Auras(key, buffs, debuffs)
	AuraDisplay(key, "buffs", buffs)
	AuraDisplay(key, "debuffs", debuffs)
end

-- Buffs start above-left; the player's, focus's and bosses' are off until enabled.
local function Buffs(enabled)
	return { enabled = enabled, anchor = "aboveLeft", growth = "right", limit = 4, filter = "all" }
end

---One indicator on a frame: shown, size, and where it sits (an anchor and placement as for text, then offsets).
---@param key string
---@param name string
---@param enabled boolean
---@param size number
---@param anchor string
---@param placement string
---@param x number?
---@param y number?
local function Indicator(key, name, enabled, size, anchor, placement, x, y)
	local base = "frames." .. key .. ".indicators." .. name .. "."

	Boolean(base .. "enabled", enabled)
	Number(base .. "size", size, 6, 64, true)
	Choice(base .. "anchor", "anchor", anchor)
	Choice(base .. "placement", "placement", placement)
	Number(base .. "x", x or 0, -200, 200)
	Number(base .. "y", y or 0, -200, 200)
end

---A frame's fade: on, and the opacity it fades to in percent.
---@param key string
---@param kind "range"|"idle"
local function Fade(key, kind)
	local base = "frames." .. key .. ".fade." .. kind .. "."

	Boolean(base .. "enabled", true)
	Number(base .. "alpha", 50, 0, 100, true)
end

-- The compact frames' default text: the name, left-aligned inside health.
local NAME_ONLY = {
	{ content = "name", anchor = "LEFT", placement = "inside", x = 4 },
}

Geometry("player", 270, 36, 16, -330, -200)
Boolean("frames.player.hideBlizzard", true)
Boolean("frames.player.reverse", false)
Overlays("player")
CastBar("player", { width = 386, x = 0, y = -254, icon = false, target = false })
Auras("player", Buffs(false), { enabled = false, anchor = "belowLeft", growth = "right", limit = 10, filter = "all" })
Indicator("player", "raid", true, 18, "CENTER", "inside")
Indicator("player", "resting", true, 9, "TOPLEFT", "inside", 3, -2)
Indicator("player", "combat", false, 16, "BOTTOMLEFT", "inside")
Indicator("player", "leader", true, 16, "TOPLEFT", "edge")
Indicator("player", "pvp", false, 24, "TOPRIGHT", "outside")
Boolean("frames.player.indicators.threat.enabled", true)
Number("frames.player.indicators.threat.size", 2, 1, 6, true)
Boolean("frames.player.totems.enabled", true)
Number("frames.player.totems.size", 22, 10, 60, true)
Number("frames.player.totems.spacing", 2, 0, 20, true)
Fade("player", "idle")
TextFields("player", 1, false, {
	{ content = "healthAndPercent", anchor = "TOPRIGHT", placement = "edge", x = -4 },
})

Geometry("target", 270, 36, 16, 330, -200)
Boolean("frames.target.hideBlizzard", true)
Boolean("frames.target.reverse", true)
AttachedPower("target")
Overlays("target")
CastBar("target", { width = 270, x = 0, y = 0, icon = true, target = true, side = "below" })
Auras("target", Buffs(true), { enabled = true, anchor = "belowLeft", growth = "right", limit = 20, filter = "all" })
Indicator("target", "raid", true, 18, "CENTER", "inside")
Indicator("target", "leader", true, 16, "TOPLEFT", "edge")
Indicator("target", "pvp", false, 24, "TOPRIGHT", "outside")
Indicator("target", "classification", false, 20, "TOPRIGHT", "edge", 10)
Fade("target", "range")
Boolean("frames.target.highlight", true)
TextFields("target", 1, false, {
	{ content = "healthAndPercent", anchor = "TOPLEFT", placement = "edge", x = 4 },
	{ content = "levelName", separator = "space", anchor = "TOPRIGHT", placement = "edge", x = -4, colorMode = "class" },
	{ content = "power", anchor = "BOTTOMLEFT", placement = "inside", x = 4, colorMode = "power" },
})

-- The pet frame, in the target-of-target style, 4 below the player frame and aligned with its left edge.
Geometry("pet", 120, 24, 16, -405, -234)
Boolean("frames.pet.hideBlizzard", true)
Boolean("frames.pet.reverse", false)
AttachedPower("pet")
TextFields("pet", 0, true, NAME_ONLY)
Indicator("pet", "raid", true, 14, "RIGHT", "outside", 2)
Fade("pet", "idle")

Geometry("targettarget", 120, 24, 16, 533, -206)
Boolean("frames.targettarget.reverse", false)
AttachedPower("targettarget")
TextFields("targettarget", 0, true, NAME_ONLY)
Indicator("targettarget", "raid", true, 14, "RIGHT", "outside", 2)

Geometry("focus", 200, 24, 16, -330, -140)
Boolean("frames.focus.hideBlizzard", true)
Boolean("frames.focus.reverse", false)
AttachedPower("focus")
Overlays("focus")
CastBar("focus", { width = 200, x = 0, y = 0, icon = false, target = true, side = "above" })
Auras("focus", Buffs(false), { enabled = true, anchor = "belowLeft", growth = "right", limit = 10, filter = "own" })
Indicator("focus", "raid", true, 14, "RIGHT", "outside", 2)
Fade("focus", "range")
Fade("focus", "idle")
Boolean("frames.focus.highlight", true)
TextFields("focus", 0, true, NAME_ONLY)

-- The boss frames: one group, the first slot at the position, the others following by growth and spacing.
Geometry("boss", 200, 32, 16, 720, -120)
Boolean("frames.boss.hideBlizzard", true)
Choice("frames.boss.growth", "growth", "down")
Number("frames.boss.spacing", 14, 0, 100, true)
Boolean("frames.boss.reverse", false)
AttachedPower("boss")
Overlays("boss")
CastBar("boss", { width = 200, x = 0, y = 0, icon = true, target = false, side = "below" })
Auras("boss", Buffs(false), { enabled = true, anchor = "left", growth = "left", limit = 10, filter = "own" })
Indicator("boss", "raid", true, 18, "CENTER", "inside")
TextFields("boss", 2, nil, {
	{ content = "name", anchor = "TOPLEFT", placement = "inside", x = 4 },
	{ content = "healthPercent", anchor = "TOPRIGHT", placement = "inside", x = -4 },
	{ content = "health", anchor = "BOTTOMLEFT", placement = "inside", x = 4 },
})

Geometry("playerPower", 360, 12, 4, 0, -184)
TextFields("playerPower", 0, nil, {
	{ content = "power", anchor = "CENTER", placement = "inside" },
})
Fade("playerPower", "idle")

-- The player's class resource, attached above the player power bar by default.
Boolean("frames.classPower.enabled", true)
Choice("frames.classPower.attach", "classPowerAttach", "power")
Number("frames.classPower.width", 360, 40, 800, true)
Number("frames.classPower.height", 10, 4, 40, true)
Number("frames.classPower.spacing", 2, 0, 10, true)
Number("frames.classPower.x", 0, -3000, 3000)
Number("frames.classPower.y", -168, -3000, 3000)
Boolean("frames.classPower.border", true)
Boolean("frames.classPower.classColor", false)
Color("frames.classPower.chargedColor", { r = 0.4, g = 0.8, b = 1 })
Boolean("frames.classPower.darkenPartial", true)
Boolean("frames.classPower.text", false)
Number("frames.classPower.textSize", 10, 6, 32, true)
Boolean("frames.classPower.runeTimers", false)
Boolean("frames.classPower.hideOutOfCombat", false)
Boolean("frames.classPower.extraMana", true)
Number("frames.classPower.extraManaHeight", 4, 2, 20, true)
Fade("classPower", "idle")

---@param path string
---@return AUISchemaField?
function Schema:Field(path)
	return self.fields[path]
end

---@param value any
---@return boolean
local function IsFinite(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

---@param value any
---@return boolean
local function IsColor(value)
	if type(value) ~= "table" then
		return false
	end

	for key, channel in pairs(value) do
		local known = key == "r" or key == "g" or key == "b" or key == "a"

		if not known or not IsFinite(channel) or channel < 0 or channel > 1 then
			return false
		end
	end

	return value.r ~= nil and value.g ~= nil and value.b ~= nil
end

---@param path string
---@param value any nil clears an optional field
---@return boolean ok
---@return string? problem why the value does not fit the field
function Schema:CheckValue(path, value)
	local field = self.fields[path]

	if not field then
		return false, ("%s is not a setting"):format(path)
	end

	if value == nil then
		if field.optional then
			return true
		end

		return false, ("%s needs a value"):format(path)
	end

	local kind = field.kind

	if kind == "number" then
		if not IsFinite(value) then
			return false, ("%s must be a finite number"):format(path)
		end

		local min, max = field.min, field.max
		local below = min ~= nil and value < min
		local above = max ~= nil and value > max

		if below or above then
			return false, ("%s must be between %s and %s"):format(path, tostring(min), tostring(max))
		end

		if field.integer and value ~= math.floor(value) then
			return false, ("%s must be a whole number"):format(path)
		end
	elseif kind == "choice" then
		if type(value) ~= "string" or not field.options[value] then
			return false, ("%s is not one of its choices"):format(path)
		end
	elseif kind == "string" then
		if type(value) ~= "string" or (value == "" and not field.allowEmpty) or #value > (field.maxLength or 0) then
			return false, ("%s must be a short text"):format(path)
		end
	elseif kind == "color" then
		if not IsColor(value) then
			return false, ("%s must be a color"):format(path)
		end
	elseif type(value) ~= kind then
		return false, ("%s must be a %s"):format(path, kind)
	end

	return true
end

---Whether a value is plain saved data: booleans, strings, finite numbers and tables of them, keyed by strings or
---positive integers, without shared tables and no deeper than the nesting limit.
---@param value any
---@param depth integer?
---@param seen table<table, true>?
---@return boolean plain
function Schema:IsPlain(value, depth, seen)
	local kind = type(value)

	if kind == "boolean" or kind == "string" then
		return true
	end

	if kind == "number" then
		return IsFinite(value)
	end

	if kind ~= "table" then
		return false
	end

	depth = depth or 1
	seen = seen or {}

	if depth > MAX_DEPTH or seen[value] or getmetatable(value) ~= nil then
		return false
	end

	seen[value] = true

	for key, child in pairs(value) do
		local keyKind = type(key)
		local validKey = keyKind == "string" or (keyKind == "number" and key >= 1 and key == math.floor(key))

		if not validKey or not self:IsPlain(child, depth + 1, seen) then
			return false
		end
	end

	return true
end

---@param config table
---@param path string
---@return any value the stored value, or nil when a step on the way is absent
local function Lookup(config, path)
	local node = config

	for key in path:gmatch("[^.]+") do
		if type(node) ~= "table" then
			return nil
		end

		node = node[key]
	end

	return node
end

---@param config table
---@param path string
---@return any value what the config stores at the path, without falling back to a default
function Schema:Lookup(config, path)
	return Lookup(config, path)
end

---Checks a profile config: every field that is present fits its definition, every branch that is present is a table,
---and everything is plain data.
---@param config any
---@return boolean ok
---@return string? problem the first problem found
function Schema:ValidateConfig(config)
	if type(config) ~= "table" then
		return false, "config is not a table"
	end

	if not self:IsPlain(config) then
		return false, "config holds something other than plain data"
	end

	for branch in pairs(self.branches) do
		local node = Lookup(config, branch)

		if node ~= nil and type(node) ~= "table" then
			return false, ("%s must be a table"):format(branch)
		end
	end

	for _, path in ipairs(self.order) do
		local value = Lookup(config, path)

		if value ~= nil then
			local ok, problem = self:CheckValue(path, value)

			if not ok then
				return false, problem
			end
		end
	end

	return true
end

---@param config table
---@param path string
---@return any value the stored value, or the field's default when the config does not hold one; a table value is
---the stored or default table itself, which callers must not change
function Schema:Read(config, path)
	local value = Lookup(config, path)

	if value == nil then
		local field = self.fields[path]

		return field and field.default
	end

	return value
end

---Writes a value at a path, creating the tables on the way.
---@param config table
---@param path string
---@param value any
function Schema:Write(config, path, value)
	local keys = {}

	for key in path:gmatch("[^.]+") do
		keys[#keys + 1] = key
	end

	local node = config

	for index = 1, #keys - 1 do
		local key = keys[index]
		local child = node[key]

		if type(child) ~= "table" then
			child = {}
			node[key] = child
		end

		node = child
	end

	node[keys[#keys]] = value
end

---Removes everything stored at a path.
---@param config table
---@param path string
function Schema:Clear(config, path)
	local parentPath, key = path:match("^(.*)%.([^.]+)$")
	local parent = parentPath and Lookup(config, parentPath) or config

	if type(parent) == "table" then
		parent[key or path] = nil
	end
end

---@param config table
---@param path string
local function WriteDefault(config, path)
	local default = Schema.fields[path].default

	if default ~= nil then
		Schema:Write(config, path, AUI:CopyTable(default))
	end
end

---@return table config a new config holding every field's default
function Schema:Defaults()
	local config = {}

	for _, path in ipairs(self.order) do
		WriteDefault(config, path)
	end

	return config
end

---Restores the defaults inside a scope, removing everything else stored there, dormant data included.
---@param config table
---@param scope string? a branch or field path; the whole config when nil
function Schema:ResetScope(config, scope)
	if not scope then
		for key in pairs(config) do
			config[key] = nil
		end
	else
		self:Clear(config, scope)
	end

	for _, path in ipairs(self.order) do
		if not scope or path == scope or path:sub(1, #scope + 1) == scope .. "." then
			WriteDefault(config, path)
		end
	end
end

---Counts the stored values this version does not know: each unknown key counts once, whatever it holds.
---@param config table
---@param prefix string? the path of `config` inside the whole config
---@return integer count
function Schema:CountDormant(config, prefix)
	local count = 0

	for key, value in pairs(config) do
		local path = prefix and (prefix .. "." .. tostring(key)) or tostring(key)

		if self.branches[path] and type(value) == "table" then
			count = count + self:CountDormant(value, path)
		elseif not self.fields[path] then
			count = count + 1
		end
	end

	return count
end

---@param scope string
---@return boolean known whether the scope names a field or a branch
function Schema:IsScope(scope)
	return self.fields[scope] ~= nil or self.branches[scope] ~= nil
end
