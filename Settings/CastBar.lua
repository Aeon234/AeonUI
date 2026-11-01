local AUI = select(2, ...)

local L = AUI.L
local lib = LibStub("LibAeonSettings-1.0")

local PREVIEW_HEIGHT = 84

local STRATA_LABELS = {
	BACKGROUND = L["Background"],
	LOW = L["Low"],
	MEDIUM = L["Medium"],
	HIGH = L["High"],
	DIALOG = L["Dialog"],
}

local ORIENTATION_LABELS = {
	HORIZONTAL = L["Horizontal"],
	VERTICAL = L["Vertical"],
}

local SIDE_LABELS = {
	LEFT = L["Left"],
	RIGHT = L["Right"],
}

local TIME_FORMAT_LABELS = {
	REMAINING = L["Remaining"],
	ELAPSED = L["Elapsed"],
	REMAINING_TOTAL = L["Remaining / Total"],
	ELAPSED_TOTAL = L["Elapsed / Total"],
}

local CASTING, CHANNELING, EMPOWERED, NOT_INTERRUPTIBLE = L["Casting"], L["Channeling"], L["Empowered"],
	L["Not Interruptible"]

---The Cast Bar page, under the Unit Frames header: the module's switch, a sample bar with its states as its preview,
---and the Bar, Icon, Text, Spell Name, Time, Feedback, Latency, Pushback and Empowered Casts cards.
---@class AUISettingsCastBar
local SettingsCastBar = {}
AUI.SettingsCastBar = SettingsCastBar

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

---A still bar in each state, styled as the live bar is.
---@class AUICastBarPreview
---@field bar AUICastBarFrame?
local CastBarPreview = {}

---@param canvas Frame
function CastBarPreview:Create(canvas)
	local bar = AUI.CastBar:Build(canvas)

	bar:SetPoint("CENTER")
	bar:Show()
	self.bar = bar
end

---@param state string a state's label
---@param preview table
---@return number width
---@return number height
function CastBarPreview:Refresh(state, preview)
	local bar = self.bar --[[@as AUICastBarFrame]]
	local STATES = AUI.CastBarOptions.STATES
	local keys = {
		[CASTING] = STATES.CASTING,
		[CHANNELING] = STATES.CHANNELING,
		[EMPOWERED] = STATES.EMPOWERED,
		[NOT_INTERRUPTIBLE] = STATES.NOT_INTERRUPTIBLE,
		[INTERRUPTED] = STATES.INTERRUPTED,
	}

	AUI.CastBar:Style(bar)
	AUI.CastBar:DrawSample(bar, keys[state], state)

	preview:Part(bar.bar, "color")

	if bar.latency:IsShown() then
		preview:Part(bar.latency, "latency")
	end

	if bar.icon:IsShown() then
		preview:Part(bar.icon, "icon")
	end

	if bar.text:IsShown() then
		preview:Part(bar.text, "nameEnabled", { text = true })
	end

	if bar.time:IsShown() then
		preview:Part(bar.time, "timeEnabled", { text = true })
	end

	return bar:GetSize()
end

---@param page table
function SettingsCastBar:DeclareBar(page)
	local Options = AUI.CastBarOptions
	local card = page:Section("castBarBar", L["Bar"])

	card:Slider(Field("width", L["Width"], "castBar.width", {
		min = Options.MIN_WIDTH,
		max = Options.MAX_WIDTH,
		step = 1,
	}))
	card:Slider(Field("height", L["Height"], "castBar.height", {
		min = Options.MIN_HEIGHT,
		max = Options.MAX_HEIGHT,
		step = 1,
	}))
	card:Dropdown(Field("texture", L["Texture"], "castBar.texture", { picker = "texture" }))
	card:Color(Field("color", L["Fill Color"], "castBar.color", {
		classColor = Field("classColor", L["Class Color"], "castBar.classColor"),
	}))
	card:Checkbox(Field("gradient", L["Gradient"], "castBar.gradient"))
	card:Color(Field("gradientColor", L["Gradient End Color"], "castBar.gradientColor", { depends = "gradient" }))
	card:Dropdown(Field("gradientDirection", L["Gradient Direction"], "castBar.gradientDirection", {
		depends = "gradient",
		options = ChoiceOptions(Options.ORIENTATIONS, ORIENTATION_LABELS),
	}))
	card:Color(Field("notInterruptible", L["Not Interruptible"], "castBar.notInterruptible"))
	card:Color(Field("background", L["Background"], "castBar.background", { hasOpacity = true }))
	card:Slider(Field("border", L["Border Size"], "castBar.border", { min = 0, max = Options.MAX_BORDER, step = 1 }))
	card:Checkbox(Field("spark", L["Show Spark"], "castBar.spark"))
	card:Checkbox(Field("reverse", L["Reverse Fill"], "castBar.reverse"))
	card:Checkbox(Field("smooth", L["Smooth Animation"], "castBar.smooth"))
	card:Checkbox(Field("alwaysShow", L["Always Show"], "castBar.alwaysShow"))
	card:Dropdown(Field("strata", L["Frame Strata"], "castBar.strata", {
		options = ChoiceOptions(Options.STRATAS, STRATA_LABELS),
	}))
end

---@param page table
function SettingsCastBar:DeclareIcon(page)
	local Options = AUI.CastBarOptions
	local card = page:Section("castBarIcon", L["Icon"])

	card:Checkbox(Field("icon", L["Show Icon"], "castBar.icon"))
	card:Dropdown(Field("iconSide", L["Icon Side"], "castBar.iconSide", {
		depends = "icon",
		options = ChoiceOptions(Options.SIDES, SIDE_LABELS),
	}))
end

---@param page table
function SettingsCastBar:DeclareText(page)
	local card = page:Section("castBarText", L["Text"])

	card:Dropdown(Field("outline", L["Outline"], "castBar.outline", { options = lib.OUTLINES }))
	card:Checkbox(Field("shadow", L["Text Shadow"], "castBar.shadow"))
end

---The settings a text shares: its size, color and offsets.
---@param card table
---@param key string `name` or `time`
---@param switch string the id of the card's switch
local function DeclareTextPlace(card, key, switch)
	local Options = AUI.CastBarOptions
	local base = "castBar." .. key .. "."

	card:Slider(Field(key .. "Size", L["Size"], base .. "size", {
		depends = switch,
		min = Options.MIN_TEXT,
		max = Options.MAX_TEXT,
		step = 1,
	}))
	card:Color(Field(key .. "Color", COLOR, base .. "color", { depends = switch }))
	card:Slider(Field(key .. "X", L["X Offset"], base .. "x", {
		depends = switch,
		min = -Options.MAX_OFFSET,
		max = Options.MAX_OFFSET,
		step = 1,
	}))
	card:Slider(Field(key .. "Y", L["Y Offset"], base .. "y", {
		depends = switch,
		min = -Options.MAX_OFFSET,
		max = Options.MAX_OFFSET,
		step = 1,
	}))
end

---@param page table
function SettingsCastBar:DeclareName(page)
	local Options = AUI.CastBarOptions
	local card = page:Section("castBarName", L["Spell Name"])

	card:Checkbox(Field("nameEnabled", L["Show Spell Name"], "castBar.name.enabled"))
	DeclareTextPlace(card, "name", "nameEnabled")
	card:Slider(Field("nameLength", L["Max Length"], "castBar.name.maxLength", {
		depends = "nameEnabled",
		description = L["0 shortens a name only where it meets the time."],
		min = 0,
		max = Options.MAX_LENGTH,
		step = 1,
	}))
end

---@param page table
function SettingsCastBar:DeclareTime(page)
	local Options = AUI.CastBarOptions
	local card = page:Section("castBarTime", L["Time"])

	card:Checkbox(Field("timeEnabled", L["Show Time"], "castBar.time.enabled"))
	card:Dropdown(Field("timeFormat", L["Time Format"], "castBar.time.format", {
		depends = "timeEnabled",
		options = ChoiceOptions(Options.TIME_FORMATS, TIME_FORMAT_LABELS),
	}))
	DeclareTextPlace(card, "time", "timeEnabled")
end

---@param page table
function SettingsCastBar:DeclareFeedback(page)
	local Options = AUI.CastBarOptions
	local card = page:Section("castBarFeedback", L["Feedback"])

	card:Color(Field("interrupted", INTERRUPTED, "castBar.interrupted"))
	card:Slider(Field("holdTime", L["Hold Time"], "castBar.holdTime", {
		min = 0,
		max = Options.MAX_HOLD,
		step = 0.1,
		format = "decimal",
	}))
	card:Checkbox(Field("fade", L["Fade Out"], "castBar.fade"))
end

---@param page table
function SettingsCastBar:DeclareLatency(page)
	local card = page:Section("castBarLatency", L["Latency"])

	card:Checkbox(Field("latency", L["Show Latency"], "castBar.latency"))
	card:Color(Field("latencyColor", L["Latency Color"], "castBar.latencyColor", {
		depends = "latency",
		hasOpacity = true,
	}))
	card:Checkbox(Field("latencyText", L["Show Latency Text"], "castBar.latencyText", { depends = "latency" }))
end

---@param page table
function SettingsCastBar:DeclarePushback(page)
	local card = page:Section("castBarPushback", L["Pushback"])

	card:Checkbox(Field("pushback", L["Show Pushback"], "castBar.pushback"))
	card:Color(Field("pushbackColor", L["Pushback Color"], "castBar.pushbackColor", { depends = "pushback" }))
end

---@param page table
function SettingsCastBar:DeclareEmpowered(page)
	local Options = AUI.CastBarOptions
	local card = page:Section("castBarEmpowered", L["Empowered Casts"])

	card:Checkbox(Field("empowerColors", L["Colored Stages"], "castBar.empowerColors"))

	for index = 1, Options.STAGE_COLORS do
		card:Color(Field("stage" .. index, L["Stage %d Color"]:format(index), "castBar.stage." .. index, {
			depends = "empowerColors",
		}))
	end

	card:Checkbox(Field("stageLabel", L["Show Stage Label"], "castBar.stageLabel", {
		description = L["Shows the stage reached, and Hold at full charge, in place of the time."],
	}))
end

---@param window table
function SettingsCastBar:Declare(window)
	local Options = AUI.CastBarOptions

	window:Header("unitFramesHeader", L["Unit Frames"])

	local page = window:Page("castBar", {
		title = L["Cast Bar"],
		under = "unitFramesHeader",
		icon = AUI.Media.sidebar.castBar,
		iconTint = true,
		switch = {
			path = Options.ENABLED_PATH,
			default = AUI.Settings:Default(Options.ENABLED_PATH),
			label = L["Show Cast Bar"],
		},
	})

	if not page then
		return
	end

	page:Preview({
		height = PREVIEW_HEIGHT,
		states = { CASTING, CHANNELING, EMPOWERED, NOT_INTERRUPTIBLE, INTERRUPTED },
		create = function(canvas)
			CastBarPreview:Create(canvas)
		end,
		refresh = function(_, state, preview)
			return CastBarPreview:Refresh(state or CASTING, preview)
		end,
	})

	self:DeclareBar(page)
	self:DeclareIcon(page)
	self:DeclareText(page)
	self:DeclareName(page)
	self:DeclareTime(page)
	self:DeclareFeedback(page)
	self:DeclareLatency(page)
	self:DeclarePushback(page)
	self:DeclareEmpowered(page)
end
