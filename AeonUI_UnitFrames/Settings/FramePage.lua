local AUI = select(2, ...)

local L = AUI.L
local lib = LibStub("LibAeonSettings-1.0")
local Options = AUI.UnitFrameOptions

local PREVIEW_HEIGHT = 84

local TITLES = {
	player = PLAYER,
}

local SWITCHES = {
	player = L["Show Player Frame"],
}

local ICONS = {
	player = "unitPlayer",
}

local CONTENT_LABELS = {
	none = NONE,
	name = L["Name"],
	level = L["Level"],
	levelName = L["Level + Name"],
	health = L["Health"],
	healthPercent = L["Health %"],
	healthAndPercent = L["Health + %"],
	missingHealth = L["Missing Health"],
	absorb = L["Absorb"],
	healAbsorb = L["Heal Absorb"],
	power = L["Power"],
	powerPercent = L["Power %"],
}

local SEPARATOR_LABELS = {
	bar = "|",
	dash = "-",
	slash = "/",
	space = L["Space"],
	parentheses = "( )",
	brackets = "[ ]",
	bullet = "•",
}

local ANCHOR_LABELS = {
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

local PLACEMENT_LABELS = {
	inside = L["Inside"],
	edge = L["On Edge"],
	outside = L["Outside"],
}

local COLOR_MODE_LABELS = {
	custom = L["Custom"],
	class = L["Class / Reaction"],
	power = L["Power"],
	difficulty = L["Level Difficulty"],
}

local NAME_FORMAT_LABELS = {
	first = L["First Name"],
	full = L["Full Name"],
}

-- Contents that join two values, and so use the separator.
local COMBINED = { levelName = true, healthAndPercent = true }

---@param values string[]
---@param labels table<string, string>
---@return table[] options
local function ChoiceOptions(values, labels)
	local options = {}

	for index, value in ipairs(values) do
		options[index] = { value = value, text = labels[value] }
	end

	return options
end

---A frame's settings page: its switch, a sample as its preview, then the cards. One object per frame, built from the
---frame table.
---@class AUISettingsFramePage
---@field spec AUIFrameSpec
local FramePage = {}
FramePage.__index = FramePage

---@param id string
---@param label string
---@param path string
---@param extra table? more of the setting's fields
---@return table setting
local function Field(id, label, path, extra)
	local setting = extra or {}

	setting.id, setting.label, setting.path, setting.default = id, label, path, AUI.Settings:Default(path)

	return setting
end

---A setting that follows a shared one until changed.
---@param id string
---@param label string
---@param path string
---@param shared string the setting it follows
---@param from string what the setting says it follows
---@param extra table? more of the setting's fields
---@return table setting
local function Inherited(id, label, path, shared, from, extra)
	local setting = Field(id, label, path, extra)

	setting.default = AUI.Settings:Default(shared)
	setting.inherits = {
		from = from,
		get = function()
			return AUI.Profile:Get(shared)
		end,
	}

	return setting
end

---@param paths string[]
---@return string summary "All Frames", or how many of the settings hold their own value
local function InheritSummary(paths)
	local changed = 0

	for _, path in ipairs(paths) do
		if AUI.Profile:IsCustom(path) then
			changed = changed + 1
		end
	end

	return changed > 0 and L["%d changed"]:format(changed) or L["All Frames"]
end

---@param page table
function FramePage:DeclareSize(page)
	local key = self.spec.key
	local card = page:Section(key .. "Size", L["Size"])

	card:Slider(Field("width", L["Width"], Options:Path(key, "width"), {
		min = Options.MIN_WIDTH,
		max = Options.MAX_WIDTH,
		step = 1,
	}))
	card:Slider(Field("height", L["Height"], Options:Path(key, "height"), {
		min = Options.MIN_HEIGHT,
		max = Options.MAX_HEIGHT,
		step = 1,
	}))
	card:Checkbox(Field("reverse", L["Reverse Fill"], Options:Path(key, "reverse")))
end

---The frame's border and bars, which follow All Frames until changed.
---@param page table
function FramePage:DeclareBars(page)
	local key = self.spec.key
	local AllFrames = AUI.SettingsAllFrames
	local card = page:Section(key .. "Bars", L["Bars"])
	local details = key .. "BarsLook"
	local from = L["All Frames"]

	local function Own(field)
		return Options:Path(key, "bars." .. field)
	end

	local function Shared(field)
		return Options.ALL .. "bars." .. field
	end

	local function Style()
		return AUI.Profile:Get(Own("borderStyle"))
	end

	card:Dropdown(Inherited("borderStyle", L["Border Style"], Own("borderStyle"), Shared("borderStyle"), from, {
		options = AllFrames.BorderOptions,
		titleCase = false,
	}))
	card:Details({
		id = details,
		label = L["Look"],
		summary = function()
			return InheritSummary({
				Own("texture"), Own("background"), Own("borderColor"), Own("lineColor"), Own("borderThickness"),
				Own("hover"), Own("hoverColor"),
			})
		end,
	})
	card:Dropdown(Inherited("barTexture", L["Bar Texture"], Own("texture"), Shared("texture"), from, {
		details = details,
		picker = "texture",
	}))
	card:Color(Inherited("barBackground", L["Background"], Own("background"), Shared("background"), from, {
		details = details,
		hasOpacity = true,
	}))
	card:Color(Inherited("borderColor", L["Border Color"], Own("borderColor"), Shared("borderColor"), from, {
		details = details,
		show = function()
			return AllFrames:HasTint(Style())
		end,
	}))
	card:Color(Inherited("lineColor", L["Border Color"], Own("lineColor"), Shared("lineColor"), from, {
		details = details,
		hasOpacity = true,
		show = function()
			return Style() == "THIN_LINE"
		end,
	}))
	card:Slider(Inherited("borderThickness", L["Border Thickness"], Own("borderThickness"), Shared("borderThickness"),
		from, {
			details = details,
			min = Options.MIN_BORDER_THICKNESS,
			max = Options.MAX_BORDER_THICKNESS,
			step = 10,
			format = "percent",
			show = function()
				return AllFrames:HasThickness(Style())
			end,
		}))
	card:Checkbox(Inherited("hover", L["Highlight on Hover"], Own("hover"), Shared("hover"), from, {
		details = details,
		show = function()
			return Style() ~= "NONE"
		end,
	}))
	card:Color(Inherited("hoverColor", L["Hover Color"], Own("hoverColor"), Shared("hoverColor"), from, {
		details = details,
		depends = "hover",
		show = function()
			return AllFrames:HasHoverColor(Style())
		end,
	}))
end

---A slot's row, opening to what the slot shows and where.
---@param card table
---@param index integer
function FramePage:DeclareSlot(card, index)
	local key = self.spec.key
	local prefix = "slot" .. index
	local details = prefix .. "Details"

	local function SlotField(field)
		return Options:SlotPath(key, index, field)
	end

	local function Extra(extra)
		extra.details = details

		return extra
	end

	card:Details({
		id = details,
		label = L["Text %d"]:format(index),
		summary = function()
			local content = AUI.Profile:Get(SlotField("content"))

			if content == "none" then
				return NONE
			end

			return ("%s, %s"):format(CONTENT_LABELS[content], ANCHOR_LABELS[AUI.Profile:Get(SlotField("anchor"))])
		end,
	})
	card:Dropdown(Field(prefix .. "Content", L["Content"], SlotField("content"), Extra({
		options = ChoiceOptions(Options.CONTENTS, CONTENT_LABELS),
	})))
	card:Dropdown(Field(prefix .. "Separator", L["Separator"], SlotField("separator"), Extra({
		options = ChoiceOptions(Options.SEPARATORS, SEPARATOR_LABELS),
		show = function()
			return COMBINED[AUI.Profile:Get(SlotField("content"))] == true
		end,
	})))
	card:Dropdown(Field(prefix .. "Anchor", L["Anchor"], SlotField("anchor"), Extra({
		options = ChoiceOptions(Options.ANCHORS, ANCHOR_LABELS),
	})))
	card:Dropdown(Field(prefix .. "Placement", L["Placement"], SlotField("placement"), Extra({
		options = ChoiceOptions(Options.PLACEMENTS, PLACEMENT_LABELS),
	})))
	card:Slider(Field(prefix .. "X", L["X Offset"], SlotField("x"), Extra({
		min = -Options.MAX_OFFSET,
		max = Options.MAX_OFFSET,
		step = 1,
	})))
	card:Slider(Field(prefix .. "Y", L["Y Offset"], SlotField("y"), Extra({
		min = -Options.MAX_OFFSET,
		max = Options.MAX_OFFSET,
		step = 1,
	})))
	card:Slider(Field(prefix .. "Width", L["Width %"], SlotField("width"), Extra({
		min = Options.MIN_SLOT_WIDTH,
		max = Options.MAX_SLOT_WIDTH,
		step = 1,
	})))
	card:Dropdown(Field(prefix .. "ColorMode", L["Text Color"], SlotField("colorMode"), Extra({
		options = ChoiceOptions(Options.COLOR_MODES, COLOR_MODE_LABELS),
	})))

	local from = L["Frame Text"]

	local function Text(field)
		return Options:Path(key, "text." .. field)
	end

	card:Dropdown(Inherited(prefix .. "Font", L["Font"], SlotField("font"), Text("font"), from, Extra({
		picker = "font",
	})))
	card:Slider(Inherited(prefix .. "TextSize", L["Size"], SlotField("size"), Text("size"), from, Extra({
		min = Options.MIN_TEXT,
		max = Options.MAX_TEXT,
		step = 1,
	})))
	card:Dropdown(Inherited(prefix .. "Outline", L["Outline"], SlotField("outline"), Text("outline"), from, Extra({
		options = lib.OUTLINES,
	})))
	card:Color(Inherited(prefix .. "Color", COLOR, SlotField("color"), Text("color"), from, Extra({
		show = function()
			return AUI.Profile:Get(SlotField("colorMode")) == "custom"
		end,
	})))
end

---The frame's text style and numbers, which follow All Frames until changed.
---@param card table
function FramePage:DeclareStyle(card)
	local key = self.spec.key
	local details = key .. "TextStyle"
	local from = L["All Frames"]

	local function Own(field)
		return Options:Path(key, field)
	end

	local function Shared(field)
		return Options.ALL .. field
	end

	card:Details({
		id = details,
		label = L["Style"],
		summary = function()
			return InheritSummary({
				Own("text.font"), Own("text.size"), Own("text.outline"), Own("text.color"), Own("numbers.precision"),
				Own("numbers.percentDecimals"),
			})
		end,
	})
	card:Dropdown(Inherited("textFont", L["Font"], Own("text.font"), Shared("text.font"), from, {
		details = details,
		picker = "font",
	}))
	card:Slider(Inherited("textSize", L["Size"], Own("text.size"), Shared("text.size"), from, {
		details = details,
		min = Options.MIN_TEXT,
		max = Options.MAX_TEXT,
		step = 1,
	}))
	card:Dropdown(Inherited("textOutline", L["Outline"], Own("text.outline"), Shared("text.outline"), from, {
		details = details,
		options = lib.OUTLINES,
	}))
	card:Color(Inherited("textColor", COLOR, Own("text.color"), Shared("text.color"), from, { details = details }))
	card:Dropdown(Inherited("precision", L["Number Format"], Own("numbers.precision"), Shared("numbers.precision"),
		from, {
			details = details,
			options = ChoiceOptions(Options.PRECISIONS, AUI.SettingsAllFrames.PRECISION_LABELS),
		}))
	card:Slider(Inherited("percentDecimals", L["Percent Decimals"], Own("numbers.percentDecimals"),
		Shared("numbers.percentDecimals"), from, {
			details = details,
			min = 0,
			max = 1,
			step = 1,
		}))
end

---@param page table
function FramePage:DeclareText(page)
	local key = self.spec.key
	local card = page:Section(key .. "Text", L["Text"])

	for index = 1, self.spec.slots do
		self:DeclareSlot(card, index)
	end

	local statusOptions = { { value = 0, text = NONE } }

	for index = 1, self.spec.slots do
		statusOptions[index + 1] = { value = index, text = L["Text %d"]:format(index) }
	end

	card:Dropdown(Field("status", L["Status Text In"], Options:Path(key, "text.status"), { options = statusOptions }))

	if AUI.can.surnames then
		card:Dropdown(Field("nameFormat", L["Name Format"], Options:Path(key, "text.nameFormat"), {
			options = ChoiceOptions(Options.NAME_FORMATS, NAME_FORMAT_LABELS),
		}))
	end

	self:DeclareStyle(card)
end

---@param window table
function FramePage:Declare(window)
	local spec = self.spec
	local enabled = Options:Path(spec.key, "enabled")
	local page = window:Page(spec.page, {
		title = TITLES[spec.key],
		under = "unitFramesHeader",
		icon = AUI.Media.sidebar[ICONS[spec.key]],
		iconTint = true,
		switch = {
			path = enabled,
			default = AUI.Settings:Default(enabled),
			label = SWITCHES[spec.key],
		},
	})

	if not page then
		return
	end

	local preview = AUI.FramePreview:New(spec)

	page:Preview({
		height = PREVIEW_HEIGHT,
		states = AUI.FramePreview.STATES,
		create = function(canvas)
			preview:Create(canvas)
		end,
		refresh = function(_, state, target)
			return preview:Refresh(state, target)
		end,
	})

	self:DeclareSize(page)
	self:DeclareBars(page)
	self:DeclareText(page)
end

for _, spec in ipairs(Options.FRAMES) do
	AUI.Modules:Register({
		group = "unitFrames",
		page = setmetatable({ spec = spec }, FramePage),
		start = function() end,
		editTargets = {
			{
				key = spec.page,
				path = Options:Path(spec.key, "position"),
				target = function()
					local frame = AUI.Frames.objects[spec.key]

					if frame then
						return {
							label = TITLES[spec.key],
							frame = frame,
							default = spec.position,
							settings = { page = spec.page, section = spec.key .. "Size" },
						}
					end
				end,
			},
		},
	})
end
