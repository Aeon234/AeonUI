local AUI = select(2, ...)

local L = AUI.L
local Schema = AUI.Schema
local Pages = AUI.SettingsPages

local Section, Row, Choice, Slider, Setting = Pages.Section, Pages.Row, Pages.Choice, Pages.Slider, Pages.Setting

-- Every setting a slot holds, as copied between slots.
local SLOT_FIELDS = {
	"content", "separator", "anchor", "placement", "x", "y", "width", "colorMode", "font", "size", "outline", "color",
}

-- The slot settings that override the frame's text style.
local STYLE_FIELDS = { "font", "size", "outline", "color" }

-- The frame-level text settings copied with Copy Text From, besides the slots.
local TEXT_FIELDS = { "font", "size", "outline", "color", "nameFormat" }

-- Contents that join two values, and so offer a separator.
local COMBINED = { healthAndPercent = true, levelName = true }

-- The frames that hold text, in the order Copy Text From and Apply to All Frames list them.
local FRAME_KEYS = { "player", "target", "playerPower" }

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

---@param key string
---@return string title the frame's page title
function Text:FrameTitle(key)
	if key == "player" then
		return PLAYER
	end

	if key == "target" then
		return TARGET
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

---The settings that copy one slot onto another.
---@param map table<string, string>
---@param fromKey string
---@param fromIndex integer
---@param toKey string
---@param toIndex integer
local function AddSlot(map, fromKey, fromIndex, toKey, toIndex)
	local from, to = SlotPath(fromKey, fromIndex), SlotPath(toKey, toIndex)

	for _, field in ipairs(SLOT_FIELDS) do
		map[to .. field] = from .. field
	end
end

---Copies one frame's text onto another: the text style and every slot both frames have.
---@param fromKey string
---@param toKey string
---@return boolean ok
function Text:CopyFrame(fromKey, toKey)
	local map = {}
	local from, to = "frames." .. fromKey .. ".text.", "frames." .. toKey .. ".text."

	for _, field in ipairs(TEXT_FIELDS) do
		map[to .. field] = from .. field
	end

	if AUI.Profile:Get(from .. "status") <= Schema.textSlots[toKey] then
		map[to .. "status"] = from .. "status"
	end

	for index = 1, math.min(Schema.textSlots[fromKey], Schema.textSlots[toKey]) do
		AddSlot(map, fromKey, index, toKey, index)
	end

	return (AUI.Profile:CopyPaths(map))
end

---Copies one slot onto the same slot of every other frame that has it.
---@param key string
---@param index integer
---@return boolean ok
function Text:ApplyToAll(key, index)
	local map = {}

	for _, other in ipairs(FRAME_KEYS) do
		if other ~= key and Schema.textSlots[other] >= index then
			AddSlot(map, key, index, other, index)
		end
	end

	return (AUI.Profile:CopyPaths(map))
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

	local elements = {
		Section("text", L["Text"]),
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

	local copyOptions = {}

	for _, other in ipairs(FRAME_KEYS) do
		if other ~= key then
			copyOptions[#copyOptions + 1] = { value = other, text = Text:FrameTitle(other) }
		end
	end

	local copyMenu = {
		id = "copyText",
		control = "dropdown",
		label = L["Copy Text From"],
		placeholder = L["Copy Text From"],
		verb = L["Copy"],
		width = "fit",
		rebuild = true,
		options = copyOptions,
		confirm = function(from)
			return L["Replace this frame's text with the text of %s?"]:format(Text:FrameTitle(from))
		end,
		get = function()
			return nil
		end,
		set = function(from)
			if not Text:CopyFrame(from, key) then
				return false
			end
		end,
	}

	local contentSetting = Choice("content", L["Content"], path .. "content", Pages.Options("content", CONTENTS), {
		rebuild = true,
	})
	local colorMode = Choice("colorMode", L["Color Mode"], path .. "colorMode", Pages.Options("colorMode", COLOR_MODES), {
		rebuild = true,
	})

	local elements = {
		Section("textSlots", L["Text Slots"], { action = useStyle, menu = copyMenu }),
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
		Slider("slotX", L["X Offset"], path .. "x", math.max(xMin, -100), math.min(xMax, 100)),
		Slider("slotY", L["Y Offset"], path .. "y", math.max(yMin, -100), math.min(yMax, 100))
	)
	elements[#elements + 1] = Row(
		Slider("slotWidth", L["Width"], path .. "width", widthMin, widthMax, { format = "percent", step = 5 }),
		colorMode
	)
	elements[#elements + 1] = Row(
		StyleSetting(key, index, "dropdown", "font", L["Font"], { picker = "font", options = {} }),
		StyleSetting(key, index, "slider", "size", L["Size"], { min = sizeMin, max = sizeMax, step = 1, format = "integer" })
	)

	local outline = StyleSetting(key, index, "dropdown", "outline", L["Outline"], {
		options = Pages.Options("outline", Pages.OUTLINES),
	})

	if AUI.Profile:Get(path .. "colorMode") == "custom" then
		elements[#elements + 1] = Row(outline, StyleSetting(key, index, "color", "color", COLOR, {
			set = function(value)
				if not AUI.Profile:Set(path .. "color", { r = value.r, g = value.g, b = value.b }) then
					return false
				end
			end,
		}))
	else
		elements[#elements + 1] = Row(outline)
	end

	elements[#elements + 1] = Row({
		id = "applyToAll",
		control = "action",
		label = L["Apply to All Frames"],
		verb = L["Apply"],
		description = L["Copy this slot's settings to the same slot on every other frame."],
		confirm = L["Copy the settings of Text %d to the same slot on every other frame?"]:format(index),
		set = function()
			return Text:ApplyToAll(key, index)
		end,
	})

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
