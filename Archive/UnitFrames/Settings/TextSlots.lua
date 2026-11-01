local AUI = select(2, ...)

local L = AUI.L
local Schema = AUI.Schema
local Pages = AUI.SettingsPages

local Section, Row, Choice, Slider, Setting = Pages.Section, Pages.Row, Pages.Choice, Pages.Slider, Pages.Setting

-- The slot settings that override the frame's text style.
local STYLE_FIELDS = { "font", "size", "outline", "color" }

-- Contents that join two values, and so offer a separator.
local COMBINED = { healthAndPercent = true, levelName = true }

local CONTENTS = {
	none = NONE,
	name = NAME,
	level = LEVEL,
	levelName = L["Level + Name"],
	health = HEALTH,
	healthPercent = L["Health %"],
	healthAndPercent = L["Health + %"],
	missingHealth = L["Missing Health"],
	absorb = L["Absorb"],
	healAbsorb = L["Heal Absorb"],
	power = L["Power"],
	powerPercent = L["Power %"],
}

local SEPARATORS = {
	bar = "|",
	dash = "-",
	slash = "/",
	space = L["Space"],
	parentheses = "( )",
	brackets = "[ ]",
	bullet = "•",
}

local ANCHORS = {
	TOPLEFT = L["Top Left"],
	TOP = L["Top"],
	TOPRIGHT = L["Top Right"],
	LEFT = L["Left"],
	CENTER = L["Center"],
	RIGHT = L["Right"],
	BOTTOMLEFT = L["Bottom Left"],
	BOTTOM = L["Bottom"],
	BOTTOMRIGHT = L["Bottom Right"],
}

local PLACEMENTS = {
	inside = L["Inside"],
	edge = L["On Edge"],
	outside = L["Outside"],
}

local COLOR_MODES = {
	custom = CUSTOM,
	class = L["Class / Reaction"],
	power = L["Power"],
	difficulty = L["Level Difficulty"],
}

local NAME_FORMATS = {
	first = L["First Name"],
	full = L["Full Name"],
}

---The Text and Text Slots sections of a frame's page. One slot is edited at a time, chosen in the Slot dropdown or
---by clicking it in the preview.
---@class AUISettingsText
---@field chosen table<string, integer> the slot being edited, per frame, for the session
local Text = {
	chosen = {},
}
AUI.SettingsText = Text

-- Shared with the indicator settings, which place things the same way.
Text.ANCHORS = ANCHORS
Text.PLACEMENTS = PLACEMENTS

---@param key string
---@return string title the frame's page title
function Text:FrameTitle(key)
	if key == "player" then
		return PLAYER
	end

	if key == "target" then
		return TARGET
	end

	if key == "pet" then
		return PET
	end

	if key == "targettarget" then
		return L["Target of Target"]
	end

	if key == "focus" then
		return L["Focus"]
	end

	if key == "boss" then
		return L["Bosses"]
	end

	return L["Player Power"]
end

---@param key string
---@return integer index
function Text:Chosen(key)
	local index = self.chosen[key]

	if index and index >= 1 and index <= Schema.textSlots[key] then
		return index
	end

	return 1
end

---@param key string
---@param index integer
function Text:Choose(key, index)
	self.chosen[key] = index
end

---@param key string
---@param index integer
---@return string path the slot's path, ending in a dot
local function SlotPath(key, index)
	return ("frames.%s.text.slots.%d."):format(key, index)
end

---@param key string
---@return table[] options one per slot, labeled with its content
local function SlotOptions(key)
	local options = {}

	for index = 1, Schema.textSlots[key] do
		local content = AUI.Profile:Get(SlotPath(key, index) .. "content")

		options[index] = { value = index, text = L["Text %d: %s"]:format(index, CONTENTS[content] or content) }
	end

	return options
end

---@param key string
---@return table[] elements the frame-level Text section
local function TextSection(key)
	local base = "frames." .. key .. ".text."
	local status = { { value = 0, text = NONE } }

	for index = 1, Schema.textSlots[key] do
		status[#status + 1] = { value = index, text = L["Text %d"]:format(index) }
	end

	local Shared = AUI.SettingsShared
	local elements = {
		Shared:Section("text", L["Text"], key, Shared.SCOPES.text, true),
		Row(
			Setting("dropdown", "font", L["Font"], base .. "font", { picker = "font", options = {} }),
			Slider("size", L["Size"], base .. "size", Pages.Range(base .. "size"))
		),
		Row(
			Choice("outline", L["Outline"], base .. "outline", Pages.Options("outline", Pages.OUTLINES)),
			Pages.Color("color", COLOR, base .. "color")
		),
	}

	local statusSetting = Choice("status", L["Status Text In"], base .. "status", status, {
		description = L["The slot that shows Offline, Ghost or Dead in place of health. Other health text hides meanwhile."],
	})

	if Schema:Field(base .. "statusLine") then
		elements[#elements + 1] = Row(Pages.Check("statusLine", L["Status Line"], base .. "statusLine", {
			description = L["Show Offline, Ghost or Dead at the right of the bar when no text slot shows the status."],
		}))
	end

	if AUI.can.surnames then
		elements[#elements + 1] = Row(
			statusSetting,
			Choice("nameFormat", L["Name Format"], base .. "nameFormat", Pages.Options("nameFormat", NAME_FORMATS))
		)
	else
		elements[#elements + 1] = Row(statusSetting)
	end

	return elements
end

---A setting of the chosen slot that overrides the frame's text style: it shows the effective value and saves the
---slot's own.
---@param key string
---@param index integer
---@param control string
---@param field string
---@param label string
---@param fields table?
---@return table setting
local function StyleSetting(key, index, control, field, label, fields)
	local path = SlotPath(key, index) .. field

	return Setting(control, "slot" .. field, label, path, Pages.Merge({
		rebuild = true,
		description = AUI.Profile:Get(path) ~= nil and L["Custom for this slot."] or nil,
		get = function()
			return AUI.Text:Resolve(AUI.Profile.config, key, index)[field]
		end,
	}, fields))
end

---@param key string
---@return table[] elements the Text Slots section for the chosen slot
local function SlotsSection(key)
	local index = Text:Chosen(key)
	local path = SlotPath(key, index)
	local content = AUI.Profile:Get(path .. "content")
	local xMin, xMax = Pages.Range(path .. "x")
	local yMin, yMax = Pages.Range(path .. "y")
	local sizeMin, sizeMax = Pages.Range(path .. "size")
	local widthMin, widthMax = Pages.Range(path .. "width")

	local useStyle = {
		id = "useTextStyle",
		control = "action",
		label = L["Use Text Style"],
		verb = L["Use Text Style"],
		blocked = function()
			for _, field in ipairs(STYLE_FIELDS) do
				if AUI.Profile:Get(path .. field) ~= nil then
					return nil
				end
			end

			return L["This slot uses the frame's text style."]
		end,
		set = function()
			for _, field in ipairs(STYLE_FIELDS) do
				AUI.Profile:Set(path .. field, nil)
			end

			return true
		end,
	}

	local contentSetting = Choice("content", L["Content"], path .. "content", Pages.Options("content", CONTENTS), {
		rebuild = true,
	})
	local colorMode = Choice("colorMode", L["Color Mode"], path .. "colorMode", Pages.Options("colorMode", COLOR_MODES), {
		rebuild = true,
	})

	local elements = {
		Section("textSlots", L["Text Slots"], { action = useStyle }),
		Row(Setting("dropdown", "slot", L["Slot"], path .. "content", {
			rebuild = true,
			options = function()
				return SlotOptions(key)
			end,
			get = function()
				return index
			end,
			set = function(value)
				Text:Choose(key, value)
			end,
		})),
	}

	if COMBINED[content] then
		elements[#elements + 1] = Row(
			contentSetting,
			Choice("separator", L["Separator"], path .. "separator", Pages.Options("separator", SEPARATORS))
		)
	else
		elements[#elements + 1] = Row(contentSetting)
	end

	elements[#elements + 1] = Row(
		Choice("anchor", L["Anchor"], path .. "anchor", Pages.Options("anchor", ANCHORS)),
		Choice("placement", L["Placement"], path .. "placement", Pages.Options("placement", PLACEMENTS))
	)
	elements[#elements + 1] = Row(
		StyleSetting(key, index, "dropdown", "font", L["Font"], { picker = "font", options = {} }),
		StyleSetting(key, index, "slider", "size", L["Size"], { min = sizeMin, max = sizeMax, step = 1, format = "integer" })
	)
	elements[#elements + 1] = Row(colorMode, StyleSetting(key, index, "dropdown", "outline", L["Outline"], {
		options = Pages.Options("outline", Pages.OUTLINES),
	}))

	if AUI.Profile:Get(path .. "colorMode") == "custom" then
		elements[#elements + 1] = Row(StyleSetting(key, index, "color", "color", COLOR, {
			set = function(value)
				if not AUI.Profile:Set(path .. "color", { r = value.r, g = value.g, b = value.b }) then
					return false
				end
			end,
		}))
	end

	elements[#elements + 1] = Pages.Details("textSlots", L["Text Slots"])
	elements[#elements + 1] = Row(
		Slider("slotX", L["X Offset"], path .. "x", math.max(xMin, -100), math.min(xMax, 100)),
		Slider("slotY", L["Y Offset"], path .. "y", math.max(yMin, -100), math.min(yMax, 100))
	)
	elements[#elements + 1] = Row(
		Slider("slotWidth", L["Width"], path .. "width", widthMin, widthMax, { format = "percent", step = 5 })
	)

	return elements
end

---@param key string
---@return table[] elements the Text and Text Slots sections
function Text:Sections(key)
	local elements = TextSection(key)

	for _, element in ipairs(SlotsSection(key)) do
		elements[#elements + 1] = element
	end

	return elements
end
