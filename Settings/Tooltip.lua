local AUI = select(2, ...)

local L = AUI.L
local lib = LibStub("LibAeonSettings-1.0")

local BAR_STYLE_LABELS = {
	BLIZZARD = L["Blizzard"],
	STRIP = L["Strip"],
}
local MODIFIER_LABELS = {
	NONE = NONE,
	SHIFT = SHIFT_KEY_TEXT,
	CTRL = CTRL_KEY_TEXT,
	ALT = ALT_KEY_TEXT,
}
-- Each ID line's checkbox, by its key in `TooltipOptions.ID_KEYS`.
local ID_LINES = {
	item = { id = "showItemID", label = L["Item ID"], description = L["Items and toys."] },
	spell = { id = "showSpellID", label = L["Spell ID"],
		description = L["Spells, auras, pet actions and a mount's spell."] },
	icon = { id = "showIconID", label = L["Icon ID"], description = L["The icons of items, spells and auras."] },
	npc = { id = "showNPCID", label = L["NPC ID"], description = L["Creatures and vehicles."] },
	age = { id = "showSpawnAge", label = L["Spawn Age"], description = L["How long ago an NPC spawned."] },
	currency = { id = "showCurrencyID", label = L["Currency ID"], description = L["Currencies."] },
	mount = { id = "showMountID", label = L["Mount ID"], description = L["Mounts."] },
	quest = { id = "showQuestID", label = L["Quest ID"], description = L["Quests, in the quest log and on the map too."] },
	macro = { id = "showMacroIDs", label = L["Macros"], description = L["The spell or item a macro uses."] },
}
local DETAILS_SAMPLE_ITEM = 6948 -- Hearthstone, cached on every character
local DETAILS_SAMPLE_SPELL = 8690 -- Hearthstone's spell
local DETAILS_PREVIEW_GAP = 12

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

---Two real tooltips, a sample item and a sample spell, built by the client and given the chosen lines by the Details
---post-calls, which treat them as previews.
local DetailsPreview = {
	---@param canvas Frame
	create = function(canvas)
		AUI.TooltipDetails.previews = {
			CreateFrame("GameTooltip", "AeonUITooltipPreviewItem", canvas, "GameTooltipTemplate"),
			CreateFrame("GameTooltip", "AeonUITooltipPreviewSpell", canvas, "GameTooltipTemplate"),
		}
	end,
	---@param canvas Frame
	---@return number width
	---@return number height
	refresh = function(canvas)
		local item, spell = unpack(AUI.TooltipDetails.previews)

		for _, tooltip in ipairs(AUI.TooltipDetails.previews) do
			tooltip:SetOwner(canvas, "ANCHOR_NONE")
			tooltip:SetFrameStrata(canvas:GetFrameStrata())
			tooltip:SetFrameLevel(canvas:GetFrameLevel() + 1)
		end

		item:SetItemByID(DETAILS_SAMPLE_ITEM)
		spell:SetSpellByID(DETAILS_SAMPLE_SPELL)
		item:ClearAllPoints()
		item:SetPoint("TOPLEFT", canvas, "TOPLEFT")
		spell:ClearAllPoints()
		spell:SetPoint("TOPLEFT", item, "TOPRIGHT", DETAILS_PREVIEW_GAP, 0)

		return item:GetWidth() + DETAILS_PREVIEW_GAP + spell:GetWidth(), math.max(item:GetHeight(), spell:GetHeight())
	end,
	stop = function()
		for _, tooltip in ipairs(AUI.TooltipDetails.previews or {}) do
			tooltip:Hide()
		end
	end,
}

---@param window table
function SettingsTooltip:DeclareDetails(window)
	local Settings, Options = AUI.Settings, AUI.TooltipOptions
	local page = window:Page("tooltipDetails", {
		title = L["Details"],
		description = L["Lines added to item, spell, aura, unit and other tooltips: an item's details, and IDs."],
		under = "tooltipHeader",
		switch = { path = Options.ENABLED_PATH, default = Settings:Default(Options.ENABLED_PATH) },
	})

	if not page then
		return
	end

	self.pageIDs.tooltipDetails = true
	page:Preview({
		height = 140,
		create = DetailsPreview.create,
		refresh = DetailsPreview.refresh,
		stop = DetailsPreview.stop,
	})

	local lines = page:Section("tooltipDetailLines", L["Lines"])

	Checkbox(lines, "showExpansion", EXPANSION_FILTER_TEXT, L["The expansion an item comes from."],
		Options.EXPANSION_PATH, function()
			return AUI.can.expansions == true
		end)
	Checkbox(lines, "showItemType", L["Category and Type"], L["An item's category and type, such as Armor / Plate."],
		Options.ITEM_TYPE_PATH)
	Checkbox(lines, "showMaxStack", L["Max Stack"], L["How many of an item fit in one stack."], Options.MAX_STACK_PATH)
	Checkbox(lines, "blankLine", L["Blank Line Before"], L["Keeps a blank line between the tooltip and the added lines."],
		Options.BLANK_LINE_PATH)

	local ids = page:Section("tooltipDetailIDs", L["IDs"])
	local modifiers = {}

	for index, modifier in ipairs(Options.MODIFIERS) do
		modifiers[index] = { value = modifier, text = MODIFIER_LABELS[modifier] }
	end

	ids:Dropdown({
		id = "idModifier",
		label = L["Modifier"],
		description = L["The key to hold for the ID lines. With None they always show."],
		path = Options.ID_MODIFIER_PATH,
		default = Settings:Default(Options.ID_MODIFIER_PATH),
		options = modifiers,
	})

	for _, key in ipairs(Options.ID_KEYS) do
		local line = ID_LINES[key]

		if line then
			Checkbox(ids, line.id, line.label, line.description, Options.ID_PATHS[key])
		end
	end
end

---Declared only where the client has upgrade tracks.
---@param window table
function SettingsTooltip:DeclareUpgrades(window)
	local Settings, Options = AUI.Settings, AUI.TooltipOptions

	if not AUI.can.upgrades then
		return
	end

	local page = window:Page("tooltipUpgrades", {
		title = L["Upgrades"],
		description = L["The upgrade line on items: the track's color, its item levels and the next upgrade's crest."],
		under = "tooltipHeader",
		switch = { path = Options.ENABLED_PATH, default = Settings:Default(Options.ENABLED_PATH) },
	})

	if not page then
		return
	end

	self.pageIDs.tooltipUpgrades = true

	local line = page:Section("tooltipUpgradeLine", L["Lines"])

	Checkbox(line, "upgradeRank", L["Rank"], L["Colors the track and rank, such as Hero 3/6."], Options.UPGRADE_RANK_PATH)
	Checkbox(line, "upgradeRange", L["Item Level Range"], L["The track's lowest and highest item level."],
		Options.UPGRADE_RANGE_PATH)
	line:Color({
		id = "upgradeRangeColor",
		resettable = true,
		label = L["Range Color"],
		path = Options.UPGRADE_RANGE_COLOR_PATH,
		default = Settings:Default(Options.UPGRADE_RANGE_COLOR_PATH),
		depends = "upgradeRange",
	})
	Checkbox(line, "upgradeCrest", L["Next Crest"], L["The crest the next upgrade costs, and whether it is discounted."],
		Options.UPGRADE_CREST_PATH)
end

---@param window table
function SettingsTooltip:Declare(window)
	window:Header("tooltipHeader", L["Tooltip"])
	self:DeclareAppearance(window)
	self:DeclareUnits(window)
	self:DeclareDetails(window)
	self:DeclareUpgrades(window)
end
