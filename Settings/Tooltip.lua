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

	font:Slider({
		id = "fontScale",
		resettable = true,
		label = L["Font Scale"],
		description = L["Scales Blizzard's text sizes: 14 for the title, 12 for the other lines."],
		path = Options.FONT_SCALE_PATH,
		default = Settings:Default(Options.FONT_SCALE_PATH),
		min = 70,
		max = 150,
		step = 5,
		format = "percent",
	})
	font:Checkbox({
		id = "customFont",
		label = L["Custom Font"],
		description = L["Draws every tooltip's text in the font and outline below instead of Blizzard's."],
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

	bar:Checkbox({
		id = "showHealthBar",
		label = L["Show Health Bar"],
		description = L["The health bar on unit tooltips."],
		path = Options.BAR_SHOWN_PATH,
		default = Settings:Default(Options.BAR_SHOWN_PATH),
	})
	bar:Dropdown({
		id = "barStyle",
		label = L["Style"],
		description = L["Blizzard's place under the tooltip, or a strip along the inside of its bottom edge."],
		path = Options.BAR_STYLE_PATH,
		default = Settings:Default(Options.BAR_STYLE_PATH),
		depends = "showHealthBar",
		options = styles,
	})
	bar:Dropdown({
		id = "barTexture",
		label = L["Texture"],
		path = Options.BAR_TEXTURE_PATH,
		default = Settings:Default(Options.BAR_TEXTURE_PATH),
		depends = "showHealthBar",
		picker = "texture",
	})
	bar:Slider({
		id = "barHeight",
		resettable = true,
		label = L["Height"],
		description = L["A strip keeps room above it, so the tooltip's lines never reach it."],
		path = Options.BAR_HEIGHT_PATH,
		default = Settings:Default(Options.BAR_HEIGHT_PATH),
		depends = "showHealthBar",
		min = 1,
		max = 16,
		step = 1,
	})
end

---@param section table
---@param id string
---@param label string
---@param description string
---@param path string
---@param show (fun(): boolean)?
local function Checkbox(section, id, label, description, path, show)
	section:Checkbox({
		id = id,
		label = label,
		description = description,
		path = path,
		default = AUI.Settings:Default(path),
		show = show,
	})
end

---@param window table
function SettingsTooltip:DeclareUnits(window)
	local Settings, Options = AUI.Settings, AUI.TooltipOptions
	local page = window:Page("tooltipUnits", {
		title = L["Units"],
		description = L["What unit tooltips show and the colors of their lines. Blizzard's lines all stay."],
		under = "tooltipHeader",
		switch = { path = Options.ENABLED_PATH, default = Settings:Default(Options.ENABLED_PATH) },
	})

	if not page then
		return
	end

	self.pageIDs.tooltipUnits = true

	local lines = page:Section("tooltipUnitLines", L["Lines"])

	Checkbox(lines, "showTitles", L["Show Titles"], L["Player titles on the name line."], Options.TITLES_PATH)
	Checkbox(lines, "showGuildRank", L["Show Guild Rank"], L["The player's rank after the guild's name."],
		Options.GUILD_RANK_PATH)
	Checkbox(lines, "colorLevels", L["Color Levels"],
		L["The level in its difficulty color, followed by + for elite, Rare or Boss."], Options.LEVEL_COLOR_PATH)
	Checkbox(lines, "mutedLines", L["Color Owners and Pets"],
		L["Owner and corpse lines in gray, and battle-pet names in their reaction color."], Options.MUTED_LINES_PATH)

	local added = page:Section("tooltipUnitAdded", L["Added Lines"])

	Checkbox(added, "showTarget", TARGET, L["Whom the unit is targeting."], Options.TARGET_PATH)
	Checkbox(added, "showRating", DUNGEON_SCORE, L["The player's Mythic+ rating, in its color."], Options.RATING_PATH,
		function()
			return AUI.can.mythicPlus == true
		end)
	Checkbox(added, "showMount", MOUNT, L["The player's mount, with a mark for whether you have it."],
		Options.MOUNT_PATH)
	Checkbox(added, "auraCasters", L["Aura Caster Names"], L["Aura tooltips name who cast the aura."],
		Options.AURA_CASTERS_PATH, function()
			return AUI.can.auraCasterNames == true
		end)
end

---@param window table
function SettingsTooltip:Declare(window)
	window:Header("tooltipHeader", L["Tooltip"])
	self:DeclareAppearance(window)
	self:DeclareUnits(window)
end
