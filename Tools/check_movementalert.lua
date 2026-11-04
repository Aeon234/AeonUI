-- Checks MovementAlert/ outside the game: the fields' defaults and bounds, each class's abilities and their paths, which
-- spells a character tracks (specialization, the first known of an ability's IDs, unchecked abilities), the text's
-- arrangements, the time's formats, the curve that hides short cooldowns and the lines' places; then nothing built
-- while off or on a client without it, a line per spell on its own cooldown, the global cooldown and short lockouts,
-- secret totals passed on, charges, overrides, the stack, a cooldown's end, Combat Only, every setting, off and on;
-- the edit mode sample, the settings page and its preview.
-- Run from any directory with Lua 5.1: lua Tools/check_movementalert.lua
-- Loads the real files against the shared stub client. Exits non-zero on the first failed check.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"
local client = assert(loadfile(root .. "Tools/stub_client.lua"))({ project = "retail" })
local Equal = client.Equal

-- Environment ---------------------------------------------------------------------------------------------

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

client.now = 100

Enum = {
	LuaCurveType = { Step = "step" },
	DurationTextBindingProperty = { RemainingDuration = 0 },
}

UIParent:SetHeight(800)

function UnitClass()
	return "Mage", "MAGE"
end

C_ClassColor = { GetClassColor = function()
	return { GetRGB = function()
		return 0.25, 0.78, 0.92
	end }
end }

local spec, known, overrides = 62, { [1953] = true }, {}
C_SpecializationInfo = {
	GetSpecialization = function()
		return spec and 1 or nil
	end,
	GetSpecializationInfo = function()
		return spec
	end,
}
C_SpellBook = { IsSpellKnown = function(id)
	return known[id] == true
end }

-- What the client answers for each spell.
local cooldowns, charges, ownDurations, gcdDurations, chargeDurations = {}, {}, {}, {}, {}
local SPELL_NAMES = { [1953] = "Blink", [212653] = "Shimmer", [186257] = "Cheetah" }
C_Spell = {
	GetSpellCooldown = function(id)
		return cooldowns[id]
	end,
	GetSpellCharges = function(id)
		return charges[id]
	end,
	GetSpellCooldownDuration = function(id, ignoreGCD)
		if ignoreGCD then
			return ownDurations[id]
		end

		return gcdDurations[id] or ownDurations[id]
	end,
	GetSpellChargeDuration = function(id)
		return chargeDurations[id]
	end,
	GetOverrideSpell = function(id)
		return overrides[id] or id
	end,
	GetSpellName = function(id)
		return SPELL_NAMES[id]
	end,
}

---A duration object that answers a curve: the opacity for `total`, or the secret standing in for it.
local function Duration(total, secret)
	return {
		EvaluateTotalDuration = function(_, curve)
			if secret then
				return secret
			end

			local value = 0

			for _, point in ipairs(curve.points) do
				if total >= point[1] then
					value = point[2]
				end
			end

			return value
		end,
	}
end

C_CurveUtil = { CreateCurve = function()
	local curve = { points = {} }
	curve.SetType = function(self, kind)
		self.kind = kind
	end
	curve.AddPoint = function(self, x, y)
		self.points[#self.points + 1] = { x, y }
	end

	return curve
end }
C_StringUtil = { CreateNumericRuleFormatter = function()
	local formatter = {}
	formatter.SetBreakpoints = function(self, breakpoints)
		self.breakpoints = breakpoints
	end

	return formatter
end }
C_DurationUtil = { CreateDurationTextBinding = function()
	local binding = { enabled = true }
	binding.SetFontString = function(self, text)
		self.text = text
	end
	binding.SetEnabled = function(self, enabled)
		self.enabled = enabled
	end
	binding.SetTextFormat = function(self, format, components)
		self.format, self.components = format, components
		self.formats = (self.formats or 0) + 1
	end
	binding.SetDuration = function(self, duration)
		self.duration = duration
	end

	return binding
end }

-- Addon table ---------------------------------------------------------------------------------------------

local AUI = {}
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
assert(loadfile(root .. "AeonUI/Core/Core.lua"))("AeonUI", AUI)
AUI.can = { movementAlert = true }

for _, file in ipairs({ "AeonUI/Core/Callbacks.lua", "AeonUI/Core/Events.lua", "AeonUI/Profile/Schema.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local eventFrame = client.frames[#client.frames]

AUI.Media = {
	Font = function(_, name)
		return "font:" .. name
	end,
	FontFlags = function(_, outline)
		return "flags:" .. outline
	end,
}

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
	client:RunTimers()
end

local function Fire(event, ...)
	client:Fire(event, ...)
	client:RunTimers()
end

for _, file in ipairs({ "AeonUI_QoL/MovementAlert/Options.lua", "AeonUI_QoL/MovementAlert/MovementAlert.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local Schema, Options, Alert = AUI.Schema, AUI.MovementAlertOptions, AUI.MovementAlert

-- Harness -------------------------------------------------------------------------------------------------

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

---@param region table
---@return string font its font file, size and flags
local function Font(region)
	return region.font[1] .. " " .. region.font[2] .. " " .. region.font[3]
end

---@param region table
---@return string color its text color's channels
local function TextColor(region)
	return table.concat(region.textColor, " ")
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
	Equal(class .. " has an ability", Options:ClassSpells(class)[1] ~= nil, true)

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
Equal("the first line at the bottom", Options:LineOffset(1, 24), 0)
Equal("the next above it", Options:LineOffset(2, 24), 42)
Equal("the frame's place", Options:DefaultPosition(800).point .. " " .. Options:DefaultPosition(800).y, "BOTTOM 430")

-- When a line shows ---------------------------------------------------------------------------------------

Equal("inactive: none", Options:OnOwnCooldown({ isActive = false, isOnGCD = false }, false), false)
Equal("no answer: none", Options:OnOwnCooldown(nil, false), false)
Equal("its own cooldown: shows", Options:OnOwnCooldown({ isActive = true, isOnGCD = false }, false), true)
Equal("on the global cooldown: none", Options:OnOwnCooldown({ isActive = true, isOnGCD = true }, false), false)
Equal("unknown, no charges: shows", Options:OnOwnCooldown({ isActive = true }, false), true)
Equal("unknown, charges: none", Options:OnOwnCooldown({ isActive = true }, true), false)
Equal("Combat Only, out of combat", Options:LinesAllowed(true, false), false)
Equal("Combat Only, in combat", Options:LinesAllowed(true, true), true)
Equal("always", Options:LinesAllowed(false, false), true)

-- Nothing while off ---------------------------------------------------------------------------------------

local frameCount = #client.frames

Alert:Start()
Equal("off: nothing built", #client.frames, frameCount)
Equal("off: no frame", Alert.frame, nil)
Equal("off: no events", eventFrame.events.SPELL_UPDATE_COOLDOWN, nil)

AUI.can.movementAlert = false
Set(Options.ENABLED_PATH, true)
Equal("a client without it: nothing built", #client.frames, frameCount)
AUI.can.movementAlert = true
Set(Options.ENABLED_PATH, false)

-- Lines ---------------------------------------------------------------------------------------------------

local function SetCooldown(id, seconds, secret)
	cooldowns[id] = { isActive = true, isOnGCD = false }
	ownDurations[id] = Duration(seconds, secret)
end

local function Clear(id)
	cooldowns[id], ownDurations[id], gcdDurations[id], chargeDurations[id], charges[id] = nil, nil, nil, nil, nil
end

Set(Options.ENABLED_PATH, true)
Equal("on: the named frame", Alert.frame.name, "AeonUIMovementAlert")
Equal("in its place", Alert.frame.points[1][1] .. " " .. Alert.frame.points[1][5], "BOTTOM 430")
Equal("no line before a cooldown", #Alert.lines, 0)

SetCooldown(1953, 15)
Fire("SPELL_UPDATE_COOLDOWN")

local line = Alert.lines[1]
Equal("a line shows", line.shown, true)
Equal("its text", line.binding.format, "{} No Blink")
Equal("its time from the formatter", line.binding.components[1].formatter.breakpoints[1].format, "%.1f")
Equal("the remaining duration", line.binding.components[1].property, 0)
Equal("the binding runs", line.binding.enabled, true)
Equal("on the spell's duration", line.binding.duration, ownDurations[1953])
Equal("the end from the same", line.ending.duration, ownDurations[1953])
Equal("opaque", line.alpha, 1)
Equal("the binding writes its text", line.binding.text, line.text)
Equal("the default font", Font(line.text), "font:Friz Quadrata TT 24 flags:SLUG")
Equal("the default color", TextColor(line.text), "1 1 1")

Fire("SPELL_UPDATE_COOLDOWN")
Equal("the format set once", line.binding.formats, 1)

cooldowns[1953].isOnGCD = true
Fire("SPELL_UPDATE_COOLDOWN")
Equal("the global cooldown: hidden", line.shown, false)
Equal("the binding stopped", line.binding.enabled, false)
Equal("the end cleared", line.ending.duration, nil)

SetCooldown(1953, 2)
Fire("SPELL_UPDATE_COOLDOWN")
Equal("a short lockout: clear", line.alpha, 0)

local SECRET = client.Secret()
SetCooldown(1953, 15, SECRET)
Fire("SPELL_UPDATE_COOLDOWN")
Equal("a secret total's opacity passed on", line.alpha, SECRET)

ownDurations[1953] = nil
Fire("SPELL_UPDATE_COOLDOWN")
Equal("no duration object: hidden", line.shown, false)

-- Charges -------------------------------------------------------------------------------------------------

SetCooldown(1953, 15)
charges[1953] = { maxCharges = 2 }
chargeDurations[1953] = Duration(20)
gcdDurations[1953] = Duration(1.5)
Fire("SPELL_UPDATE_CHARGES")
Equal("charges: the time from the recharge", line.binding.duration, chargeDurations[1953])
Equal("a banked charge: clear, read with the global cooldown", line.alpha, 0)

gcdDurations[1953] = Duration(20)
Fire("SPELL_UPDATE_CHARGES")
Equal("out of charges: opaque", line.alpha, 1)

charges[1953] = { maxCharges = client.Secret() }
Fire("SPELL_UPDATE_CHARGES")
Equal("a secret maximum keeps the last reading", line.binding.duration, chargeDurations[1953])

charges[1953] = { maxCharges = 1 }
Fire("SPELL_UPDATE_CHARGES")
Equal("one charge is no charge spell", line.binding.duration, ownDurations[1953])
Clear(1953)

-- The list ------------------------------------------------------------------------------------------------

overrides[1953] = 212653
Fire("SPELLS_CHANGED")
SetCooldown(1953, 15)
Fire("SPELL_UPDATE_COOLDOWN")
Equal("an override's name, the known spell's cooldown", line.binding.format, "{} No Shimmer")
overrides[1953] = nil
Fire("UPDATE_SHAPESHIFT_FORM")
Equal("back again", line.binding.format, "{} No Blink")

local Mage = Options:ClassSpells("MAGE")

Set(Options:SpellPath(Mage[1]), false)
Equal("unchecked: hidden", line.shown, false)
Set(Options:SpellPath(Mage[1]), true)
Equal("checked again: shown", line.shown, true)

spec = nil
Fire("PLAYER_SPECIALIZATION_CHANGED", "player")
Equal("no specialization yet: hidden", line.shown, false)
spec = 62
Fire("SPELLS_CHANGED")
Equal("specialization known: shown", line.shown, true)

-- Stacking ------------------------------------------------------------------------------------------------

local second = { ids = { 186257 } }
Mage[2] = second
values[Options:SpellPath(second)] = true
known[186257] = true
SetCooldown(186257, 30)
Fire("SPELLS_CHANGED")
Equal("a second line", Alert.lines[2].binding.format, "{} No Cheetah")
Equal("above the first", Alert.lines[2].points[1][5], 42)
Equal("the first at the bottom", Alert.lines[1].points[1][5], 0)
Clear(1953)
Fire("SPELL_UPDATE_COOLDOWN")
Equal("the first gone: the next takes its place", Alert.lines[1].binding.format, "{} No Cheetah")
Equal("no gap above", Alert.lines[2].shown, false)
Clear(186257)
Mage[2] = nil
known[186257] = nil
Fire("SPELLS_CHANGED")

-- The end of a cooldown -----------------------------------------------------------------------------------

SetCooldown(1953, 15)
Fire("SPELL_UPDATE_COOLDOWN")

local function Done()
	line.ending.scripts.OnCooldownDone()
	client:RunTimers()
end

cooldowns[1953].isActive = false
Done()
Equal("a report in the frame it was given changes nothing", line.shown, true)

client.now = client.now + 1
Done()
Equal("an end hides it", line.shown, false)

cooldowns[1953].isActive = true
Fire("SPELL_UPDATE_COOLDOWN")
client.now = client.now + 0.1
cooldowns[1953].isActive = false
Done()
Equal("reports too close together: the second waits", line.shown, true)
client.now = client.now + 0.2
Done()
Equal("after the gap it counts", line.shown, false)

client.now = client.now + 1
cooldowns[1953].isActive = true
Done()
Equal("a hidden line's report runs no check", line.shown, false)

-- Combat Only ---------------------------------------------------------------------------------------------

Fire("SPELL_UPDATE_COOLDOWN")
Equal("shown again", line.shown, true)
Set(Options.COMBAT_ONLY_PATH, true)
Equal("Combat Only, out of combat: hidden", line.shown, false)
Fire("PLAYER_REGEN_DISABLED")
Equal("in combat: shown", line.shown, true)
Fire("PLAYER_REGEN_ENABLED")
Equal("after combat: hidden", line.shown, false)
Set(Options.COMBAT_ONLY_PATH, false)
Equal("off again: shown", line.shown, true)

-- Settings ------------------------------------------------------------------------------------------------

Set(Options.ARRANGEMENT_PATH, "NAME_DURATION")
Equal("Name Duration", line.binding.format, "No Blink {}")
Set(Options.ARRANGEMENT_PATH, "DURATION")
Equal("Duration", line.binding.format, "{}")
Set(Options.ARRANGEMENT_PATH, "DURATION_NAME")

Set(Options.DECIMAL_PATH, false)
Equal("whole seconds reach the line", line.binding.components[1].formatter.breakpoints[1].format, "%.0f")
Set(Options.DECIMAL_PATH, true)

Set(Options.SIZE_PATH, 30)
Set(Options.FONT_PATH, "Other")
Set(Options.OUTLINE_PATH, "NONE")
Equal("the font follows", Font(line.text), "font:Other 30 flags:NONE")
Set(Options.COLOR_PATH, { r = 1, g = 0, b = 0 })
Equal("the color follows", TextColor(line.text), "1 0 0")
Set(Options.CLASS_COLOR_PATH, true)
Equal("Class Color", TextColor(line.text), "0.25 0.78 0.92")
Set(Options.CLASS_COLOR_PATH, false)

Set(Options.POSITION_PATH, { point = "TOP", x = 5, y = -10 })
Equal("a saved place", Alert.frame.points[1][1] .. " " .. Alert.frame.points[1][4] .. " " .. Alert.frame.points[1][5],
	"TOP 5 -10")
Set(Options.POSITION_PATH, nil)

-- Off and on again ----------------------------------------------------------------------------------------

frameCount = #client.frames
Set(Options.ENABLED_PATH, false)
Equal("off: hidden", line.shown, false)
Equal("off: the binding stopped", line.binding.enabled, false)
Equal("off: the end cleared", line.ending.duration, nil)
Equal("off: no cooldown event", eventFrame.events.SPELL_UPDATE_COOLDOWN, nil)
Equal("off: no list event", eventFrame.events.SPELLS_CHANGED, nil)
Equal("off: no combat event", eventFrame.events.PLAYER_REGEN_DISABLED, nil)

Set(Options.ENABLED_PATH, true)
Equal("on again: shown", line.shown, true)
Equal("on again: nothing built twice", #client.frames, frameCount)
Equal("on again: the events back", eventFrame.events.SPELL_UPDATE_COOLDOWN, true)

-- Sample and edit mode ------------------------------------------------------------------------------------

Equal("the sample's text", Options:SampleText("DURATION_NAME", true, "Blink"), "12.3 No Blink")
Equal("whole seconds", Options:SampleText("NAME_DURATION", false, "Blink"), "No Blink 12")
Equal("the time alone", Options:SampleText("DURATION", true, "Blink"), "12.3")
Equal("the first line's height", Options:LineHeight(24), 40)
Equal("a large font's", Options:LineHeight(72), 90)
Equal("lines clear a large font", Options:LineOffset(2, 72), 92)

Set(Options.SIZE_PATH, 72)
Equal("a large font lifts the frame", Alert.frame.height, 90)
Equal("and the line", line.height, 90)
Set(Options.SIZE_PATH, 24)
Equal("back at its size", Alert.frame.height, 40)

Alert:Sample(true)
Equal("a sample stops the binding", line.binding.enabled, false)
Equal("and shows its text", line.text.text, "12.3 No Blink")
Equal("opaque", line.alpha, 1)
Equal("and shown", line.shown, true)
Fire("SPELL_UPDATE_COOLDOWN")
Equal("a cooldown event leaves the sample", line.binding.enabled, false)
Set(Options.ARRANGEMENT_PATH, "DURATION")
Equal("the sample follows the settings", line.text.text, "12.3")
Set(Options.ARRANGEMENT_PATH, "DURATION_NAME")
Alert:Sample(false)
Equal("after it, the real line", line.binding.enabled, true)

cooldowns[1953].isActive = false
Alert:Sample(true)
Alert:Sample(false)
Equal("after it, no line without a cooldown", line.shown, false)
cooldowns[1953].isActive = true
Fire("SPELL_UPDATE_COOLDOWN")

-- The page ------------------------------------------------------------------------------------------------

COLOR = "Color"
AUI.Media.sidebar = { movementAlert = "SidebarMovementAlert.tga" }
AUI.Settings = { Default = function(_, path)
	return Schema:Field(path).default
end }
function LibStub()
	return { OUTLINES = { { value = "SLUG", text = "Slug" } } }
end

local declared
AUI.Modules = { Register = function(_, module)
	declared = module
end }
assert(loadfile(root .. "AeonUI_QoL/Settings/MovementAlert.lua"))("AeonUI", AUI)

local page = { sections = {} }
local function Section(_, id, title, options)
	local section = { id = id, title = title, options = options, rows = {} }

	for _, kind in ipairs({ "Checkbox", "Dropdown", "Slider", "Color" }) do
		section[kind] = function(self, row)
			row.kind = kind
			self.rows[#self.rows + 1] = row
		end
	end

	page.sections[#page.sections + 1] = section

	return section
end
page.Section = Section
page.Preview = function(self, info)
	self.preview = info
end
local pageID, pageInfo
AUI.SettingsMovementAlert:Declare({ Page = function(_, id, info)
	pageID, pageInfo = id, info

	return page
end })

local function RowIDs(section)
	local ids = {}

	for index, row in ipairs(section.rows) do
		ids[index] = row.id
	end

	return table.concat(ids, " ")
end

Equal("its id", pageID, "movementAlert")
Equal("under Quality of Life", pageInfo.under, "qualityOfLifeHeader")
Equal("its icon", pageInfo.icon, "SidebarMovementAlert.tga")
Equal("headed by the switch, off", pageInfo.switch.path .. " " .. tostring(pageInfo.switch.default),
	"movementAlert.enabled false")
Equal("the switch's label", pageInfo.switch.label, "Show Movement Alerts")
Equal("the Text card", RowIDs(page.sections[1]), "arrangement decimal font size outline color")
Equal("the Visibility card", RowIDs(page.sections[2]), "combatOnly")
Equal("the class's abilities", RowIDs(page.sections[3]), "spell212653")
Equal("named as the character knows it", page.sections[3].rows[1].label, "Blink")
Equal("the formats", page.sections[1].rows[1].options[2].text, "Name, Then Time")
Equal("Class Color beside the swatch", page.sections[1].rows[6].classColor.path, Options.CLASS_COLOR_PATH)
Equal("on this client", AUI.SettingsMovementAlert:IsAvailable(), true)
AUI.can.movementAlert = nil
Equal("not on a client without it", AUI.SettingsMovementAlert:IsAvailable(), false)
AUI.can.movementAlert = true

local canvas = CreateFrame("Frame")
local createFontString = canvas.CreateFontString

-- The sample's strings measure as the client would; the stub lays out no text.
function canvas:CreateFontString(...)
	local text = createFontString(self, ...)

	text.stringWidth = 100

	return text
end

local parts = {}
local previewParts = { Part = function(_, region, target)
	parts[#parts + 1] = target
	parts.region = region
end }
local width, height = page.preview.refresh(canvas, nil, previewParts)
Equal("the sample's text", parts.region.text, "12.3 No Blink")
Equal("the sample's size", width .. "x" .. height, "100x40")
Equal("it finds the font's row", parts[1], "font")

known[186257] = true
local extra = { ids = { 186257 } }
Options:ClassSpells("MAGE")[2] = extra
values[Options:SpellPath(extra)] = true
width, height = page.preview.refresh(canvas, nil, previewParts)
Equal("a line per tracked spell", height, 82)
Options:ClassSpells("MAGE")[2] = nil
known[186257] = nil
width, height = page.preview.refresh(canvas, nil, previewParts)
Equal("one again", height, 40)

known[1953] = nil
Equal("a class's name with nothing known", Alert:SampleNames()[1], "Shimmer")
known[1953] = true

local target = declared.editTargets[1]
Equal("the edit target's path", target.path, Options.POSITION_PATH)
local info = target.target()
Equal("its frame", info.frame, Alert.frame)
Equal("kept to the bottom edge", info.fixedEdge, "BOTTOM")
Equal("its default", info.default.point .. " " .. info.default.y, "BOTTOM 430")
info.sample(true)
Equal("its sample", line.text.text, "12.3 No Blink")
info.sample(false)
Set(Options.ENABLED_PATH, false)
Equal("no target while off", target.target(), nil)
Set(Options.ENABLED_PATH, true)
declared.start()
Equal("started once", Alert.active, true)

Equal("no Lua error in the run", errors[1], nil)

io.stdout:write(("check_movementalert: %d checks passed\n"):format(client.checks))
