local AUI = select(2, ...)

local L = AUI.L
local lib = LibStub("LibAeonSettings-1.0")

local BAR_STYLE_LABELS = {
	BLIZZARD = L["Blizzard"],
	STRIP = L["Strip"],
}

---The Tooltip header and its pages, each carrying the module's switch. Changes take effect at once.
---@class AUISettingsTooltip
---@field pageIDs table<string, true> the pages under the Tooltip header
local SettingsTooltip = {
	pageIDs = {},
}
AUI.SettingsTooltip = SettingsTooltip

---@param style string
---@return fun(): boolean shown while the health bar has that style
local function WithBarStyle(style)
	return function()
		return AUI.Profile:Get(AUI.TooltipOptions.BAR_STYLE_PATH) == style
	end
end

---@param window table
function SettingsTooltip:DeclareAppearance(window)
	local Settings, Options = AUI.Settings, AUI.TooltipOptions
	local page = window:Page("tooltipAppearance", {
		title = L["Appearance"],
		description = L["The tooltip's text and health bar. Blizzard's background and border stay as they are."],
		under = "tooltipHeader",
		switch = { path = Options.ENABLED_PATH, default = Settings:Default(Options.ENABLED_PATH) },
	})

	if not page then
		return
	end

	self.pageIDs.tooltipAppearance = true

	local font = page:Section("tooltipFont", L["Text"])

	font:Checkbox({
		id = "customFont",
		label = L["Custom Font"],
		description = L["Draws every tooltip's text in the font below instead of Blizzard's."],
		path = Options.FONT_CUSTOM_PATH,
		default = Settings:Default(Options.FONT_CUSTOM_PATH),
	})
	font:Dropdown({
		id = "fontFace",
		label = L["Font"],
		path = Options.FONT_FACE_PATH,
		default = Settings:Default(Options.FONT_FACE_PATH),
		depends = "customFont",
		picker = "font",
	})
	font:Slider({
		id = "headerSize",
		resettable = true,
		label = L["Title Size"],
		description = L["The first line: the name of the unit, item or spell."],
		path = Options.FONT_HEADER_PATH,
		default = Settings:Default(Options.FONT_HEADER_PATH),
		depends = "customFont",
		min = 8,
		max = 24,
		step = 1,
	})
	font:Slider({
		id = "bodySize",
		resettable = true,
		label = L["Text Size"],
		description = L["Every other line. Blizzard's smaller text stays a little smaller."],
		path = Options.FONT_BODY_PATH,
		default = Settings:Default(Options.FONT_BODY_PATH),
		depends = "customFont",
		min = 8,
		max = 20,
		step = 1,
	})
	font:Dropdown({
		id = "fontOutline",
		label = L["Outline"],
		path = Options.FONT_OUTLINE_PATH,
		default = Settings:Default(Options.FONT_OUTLINE_PATH),
		depends = "customFont",
		options = lib.OUTLINES,
	})

	local styles = {}

	for index, style in ipairs(Options.BAR_STYLES) do
		styles[index] = { value = style, text = BAR_STYLE_LABELS[style] }
	end

	local bar = page:Section("tooltipHealthBar", L["Health Bar"])

	bar:Dropdown({
		id = "barStyle",
		label = L["Style"],
		description = L["Blizzard's place under the tooltip, or a strip along the inside of its bottom edge."],
		path = Options.BAR_STYLE_PATH,
		default = Settings:Default(Options.BAR_STYLE_PATH),
		options = styles,
	})
	bar:Dropdown({
		id = "barTexture",
		label = L["Texture"],
		path = Options.BAR_TEXTURE_PATH,
		default = Settings:Default(Options.BAR_TEXTURE_PATH),
		picker = "texture",
	})
	bar:Slider({
		id = "barHeight",
		resettable = true,
		label = L["Height"],
		path = Options.BAR_HEIGHT_PATH,
		default = Settings:Default(Options.BAR_HEIGHT_PATH),
		show = WithBarStyle("BLIZZARD"),
		min = 2,
		max = 16,
		step = 1,
	})
	bar:Slider({
		id = "stripHeight",
		resettable = true,
		label = L["Height"],
		path = Options.STRIP_HEIGHT_PATH,
		default = Settings:Default(Options.STRIP_HEIGHT_PATH),
		show = WithBarStyle("STRIP"),
		min = 1,
		max = 8,
		step = 1,
	})
end

---@param window table
function SettingsTooltip:Declare(window)
	window:Header("tooltipHeader", L["Tooltip"])
	self:DeclareAppearance(window)
end
