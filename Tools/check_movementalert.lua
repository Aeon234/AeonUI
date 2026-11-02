-- Checks MovementAlert/ outside the game: the fields' defaults and bounds, each class's abilities and their paths, which
-- spells a character tracks (specialization, the first known of an ability's IDs, unchecked abilities), the text's
-- arrangements, the time's formats, the curve that hides short cooldowns and the lines' places.
-- Run from any directory with Lua 5.1: lua Tools/check_movementalert.lua
-- Loads the real files against stubbed globals. Exits non-zero on the first failed check.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Addon table ---------------------------------------------------------------------------------------------

local AUI = {}
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
assert(loadfile(root .. "AeonUI/Profile/Schema.lua"))("AeonUI", AUI)
assert(loadfile(root .. "AeonUI_QoL/MovementAlert/Options.lua"))("AeonUI", AUI)

local Schema, Options = AUI.Schema, AUI.MovementAlertOptions

-- Harness -------------------------------------------------------------------------------------------------

local checks = 0

local function Equal(name, actual, expected)
	checks = checks + 1

	if actual ~= expected then
		error(("%s: expected %s, got %s"):format(name, tostring(expected), tostring(actual)), 2)
	end
end

local function Known(...)
	local set = {}

	for _, id in ipairs({ ... }) do
		set[id] = true
	end

	return function(id)
		return set[id] == true
	end
end

local function Default(spell)
	return Schema:Field(Options:SpellPath(spell)).default
end

local function Tracked(class, specID, known, tracked)
	return table.concat(Options:TrackedSpells(class, specID, known, tracked or Default), " ")
end

-- Fields --------------------------------------------------------------------------------------------------

Equal("off by default", Schema:Field(Options.ENABLED_PATH).default, false)
Equal("Combat Only off by default", Schema:Field(Options.COMBAT_ONLY_PATH).default, false)
Equal("duration first by default", Schema:Field(Options.ARRANGEMENT_PATH).default, "DURATION_NAME")
Equal("a decimal by default", Schema:Field(Options.DECIMAL_PATH).default, true)
Equal("size 24 by default", Schema:Field(Options.SIZE_PATH).default, 24)
Equal("Slug by default", Schema:Field(Options.OUTLINE_PATH).default, "SLUG")
Equal("white by default", Schema:Field(Options.COLOR_PATH).default.g, 1)
Equal("no saved place by default", Schema:Field(Options.POSITION_PATH).optional, true)

-- Abilities -----------------------------------------------------------------------------------------------

local CLASSES = { "DEATHKNIGHT", "DEMONHUNTER", "DRUID", "EVOKER", "HUNTER", "MAGE", "MONK", "PALADIN", "PRIEST", "ROGUE",
	"SHAMAN", "WARLOCK", "WARRIOR" }

for _, class in ipairs(CLASSES) do
	checks = checks + 1
	assert(Options:ClassSpells(class)[1], class .. " has an ability")

	for _, spell in ipairs(Options:ClassSpells(class)) do
		Equal(class .. "'s field exists", Schema:Field(Options:SpellPath(spell)).kind, "boolean")
	end
end

Equal("an unknown class has none", #Options:ClassSpells("NOPE"), 0)

local Sprint = Options:ClassSpells("ROGUE")[3]
Equal("an ability's path takes its first ID", Options:SpellPath(Sprint), "movementAlert.spells.2983")
Equal("Sprint starts unchecked", Default(Sprint), false)
Equal("Heroic Leap starts checked", Default(Options:ClassSpells("WARRIOR")[1]), true)

-- Tracking ------------------------------------------------------------------------------------------------

Equal("a known ability is tracked", Tracked("WARRIOR", 71, Known(6544)), "6544")
Equal("an unknown one is not", Tracked("WARRIOR", 71, Known()), "")
Equal("nothing until the specialization is known", Tracked("WARRIOR", nil, Known(6544)), "")
Equal("Shimmer wins over Blink", Tracked("MAGE", 62, Known(1953, 212653)), "212653")
Equal("Blink without Shimmer", Tracked("MAGE", 62, Known(1953)), "1953")
Equal("only the specialization's abilities", Tracked("ROGUE", 260, Known(36554, 195457)), "195457")
Equal("in the class's order", Tracked("HUNTER", 253, Known(781, 186257)), "186257 781")
Equal("an ability starting unchecked is left out", Tracked("ROGUE", 261, Known(36554, 2983)), "36554")

local function All()
	return true
end

Equal("and tracked once checked", Tracked("ROGUE", 261, Known(36554, 2983), All), "36554 2983")
Equal("an ability unchecked is left out", Tracked("WARRIOR", 71, Known(6544), function()
	return false
end), "")

-- Text ----------------------------------------------------------------------------------------------------

Equal("Duration Name", Options:TextFormat("DURATION_NAME", "Blink"), "{} No Blink")
Equal("Name Duration", Options:TextFormat("NAME_DURATION", "Blink"), "No Blink {}")
Equal("Duration", Options:TextFormat("DURATION", "Blink"), "{}")
Equal("a decimal", Options:TimeBreakpoints(true)[1].format, "%.1f")
Equal("in tenths", Options:TimeBreakpoints(true)[1].step, 0.1)
Equal("whole seconds", Options:TimeBreakpoints(false)[1].format, "%.0f")
Equal("in seconds", Options:TimeBreakpoints(false)[1].step, 1)

-- Places --------------------------------------------------------------------------------------------------

local curve = Options:VisibilityCurve()
Equal("short cooldowns clear", curve[1][1] .. " " .. curve[1][2], "0 0")
Equal("from three seconds opaque", curve[2][1] .. " " .. curve[2][2], "3 1")
Equal("the first line at the bottom", Options:LineOffset(1), 0)
Equal("the next above it", Options:LineOffset(2), 42)
Equal("the frame's place", Options:DefaultPosition().point .. " " .. Options:DefaultPosition().y, "CENTER 50")

io.stdout:write(("check_movementalert: %d checks passed\n"):format(checks))
