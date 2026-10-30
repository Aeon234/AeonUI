local AUI = select(2, ...)

local L = AUI.L
local lib = LibStub("LibAeonSettings-1.0")

local BAR_STYLE_LABELS = {
	BLIZZARD = L["Under the Tooltip"],
	STRIP = L["Inside Bottom Edge"],
}
local ROLE_STYLE_LABELS = {
	DEFAULT = DEFAULT,
	BLIZZARD = L["Blizzard"],
	COLOR = COLOR,
	ELVUI = "ElvUI",
	SQUARE = L["Square"],
	WHITE = L["White"],
}
-- The size of each role icon beside its style's name in the Role Icons dropdown.
local ROLE_SAMPLE_SIZE = 14
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
	currency = { id = "showCurrencyID", label = L["Currency ID"] },
	mount = { id = "showMountID", label = L["Mount ID"] },
	quest = { id = "showQuestID", label = L["Quest ID"], description = L["Quests, in the quest log and on the map too."] },
	macro = { id = "showMacroIDs", label = L["Macros"], description = L["The spell or item a macro uses."] },
}
local SHOW_MODE_LABELS = {
	ALWAYS = ALWAYS,
	OUT_OF_COMBAT = L["Out of Combat"],
	OUT_OF_BOSS_COMBAT = L["Out of Boss Combat"],
	NEVER = NEVER,
}
local CURSOR_POINT_LABELS = {
	TOP = L["Above"],
	BOTTOM = L["Below"],
	LEFT = L["Left"],
	RIGHT = L["Right"],
	TOPLEFT = L["Above Left"],
	TOPRIGHT = L["Above Right"],
	BOTTOMLEFT = L["Below Left"],
	BOTTOMRIGHT = L["Below Right"],
	CENTER = L["Centered"],
}
local GROWTH_LABELS = {
	DEFAULT = DEFAULT,
	UP = L["Up"],
	DOWN = L["Down"],
}
local DETAILS_SAMPLE_ITEM = 2589 -- Linen Cloth: stacks, and its ID never changes
local DETAILS_SAMPLE_SPELL = 8690 -- Hearthstone's spell
local DETAILS_PREVIEW_GAP = 12
-- Tall enough for the sample item with every line at full size.
local DETAILS_PREVIEW_HEIGHT = 210
-- Tall enough for the sample player with every line at full size.
local UNITS_PREVIEW_HEIGHT = 170

-- The module's switch, on the General page; the Units and Items pages show only while it is on.
local SWITCH = "tooltipGeneral/enabled"

---The Tooltip header and its pages: General, which carries the module's switch, and Units and Items while it is on.
---Changes take effect at once.
---@class AUISettingsTooltip
---@field pageIDs table<string, true> the pages under the Tooltip header
local SettingsTooltip = {
	pageIDs = {},
}
AUI.SettingsTooltip = SettingsTooltip

---The General page's text and health bar.
---@param page table
function SettingsTooltip:DeclareAppearance(page)
	local Settings, Options = AUI.Settings, AUI.TooltipOptions
	local font = page:Section("tooltipFont", L["Text"])

	font:Slider({
		id = "fontScale",
		resettable = true,
		label = L["Font Scale"],
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
		path = Options.BAR_SHOWN_PATH,
		default = Settings:Default(Options.BAR_SHOWN_PATH),
	})
	bar:Dropdown({
		id = "barStyle",
		label = L["Style"],
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

---@return boolean shown the module is on, so the Units and Items pages show
local function ModuleShown()
	return AUI.Profile:Get(AUI.TooltipOptions.ENABLED_PATH) == true
end

---@param values string[]
---@param labels table<string, string>
---@return { value: string, text: string }[] options
local function Choices(values, labels)
	local options = {}

	for index, value in ipairs(values) do
		options[index] = { value = value, text = labels[value] }
	end

	return options
end

---A checkbox on the Units or Items page, which follows the module's switch.
---@param section table
---@param id string
---@param label string
---@param description string?
---@param path string
---@param show (fun(): boolean)?
local function Checkbox(section, id, label, description, path, show)
	section:Checkbox({
		id = id,
		label = label,
		description = description,
		path = path,
		default = AUI.Settings:Default(path),
		depends = SWITCH,
		show = show,
	})
end

---A checkbox in a choice card on the Units or Items page, which follows the module's switch: what it adds is in its
---label's tooltip, as a choice card's rows have no second line.
---@param section table
---@param id string
---@param label string
---@param tooltip string?
---@param path string
---@param show (fun(): boolean)?
local function Choice(section, id, label, tooltip, path, show)
	section:Checkbox({
		id = id,
		label = label,
		tooltip = tooltip,
		path = path,
		default = AUI.Settings:Default(path),
		depends = SWITCH,
		show = show,
	})
end

---The General page's visibility and position.
---@param page table
function SettingsTooltip:DeclarePosition(page)
	local Settings, Options = AUI.Settings, AUI.TooltipOptions
	local visibility = page:Section("tooltipVisibility", L["Visibility"])

	visibility:Dropdown({
		id = "showMode",
		label = L["Show Tooltips"],
		path = Options.SHOW_MODE_PATH,
		default = Settings:Default(Options.SHOW_MODE_PATH),
		options = Choices(Options.SHOW_MODES, SHOW_MODE_LABELS),
	})
	visibility:Dropdown({
		id = "peekKey",
		label = L["Show While Held"],
		description = L["A key that shows a hidden tooltip while you hold it."],
		path = Options.PEEK_PATH,
		default = Settings:Default(Options.PEEK_PATH),
		options = Choices(Options.MODIFIERS, MODIFIER_LABELS),
		blocked = function()
			if AUI.Profile:Get(Options.SHOW_MODE_PATH) == "ALWAYS" then
				return L["Needs tooltips hidden at some time."]
			end
		end,
	})

	local place = page:Section("tooltipPlace", L["Position"])

	place:Checkbox({
		id = "anchorCursor",
		label = L["Anchor to Cursor"],
		description = L["Tooltips with no place of their own follow the cursor."],
		path = Options.CURSOR_PATH,
		default = Settings:Default(Options.CURSOR_PATH),
	})
	place:Dropdown({
		id = "cursorPoint",
		label = L["Cursor Position"],
		path = Options.CURSOR_POINT_PATH,
		default = Settings:Default(Options.CURSOR_POINT_PATH),
		depends = "anchorCursor",
		options = Choices(Options.CURSOR_POINTS, CURSOR_POINT_LABELS),
	})

	for _, axis in ipairs({ { id = "cursorX", label = L["X Offset"], path = Options.CURSOR_X_PATH },
		{ id = "cursorY", label = L["Y Offset"], path = Options.CURSOR_Y_PATH } }) do
		place:Slider({
			id = axis.id,
			resettable = true,
			label = axis.label,
			path = axis.path,
			default = Settings:Default(axis.path),
			depends = "anchorCursor",
			min = -200,
			max = 200,
			step = 1,
		})
	end

	place:Dropdown({
		id = "growth",
		label = L["Growth Direction"],
		description = L["Default lets Blizzard choose."],
		path = Options.GROWTH_PATH,
		default = Settings:Default(Options.GROWTH_PATH),
		options = Choices(Options.GROWTHS, GROWTH_LABELS),
		blocked = function()
			if AUI.Profile:Get(Options.CURSOR_PATH) == true then
				return L["Not while anchored to the cursor."]
			end
		end,
	})
	place:Checkbox({
		id = "enhancedTooltips",
		label = L["Action Bar Tooltips Here"],
		description = L["Instead of beside the button. A game setting, so profiles don't keep it."],
		get = function()
			return AUI.TooltipAnchor:Enhanced()
		end,
		set = function(value)
			AUI.TooltipAnchor:SetEnhanced(value)
		end,
	})
end

---@param window table
function SettingsTooltip:DeclareGeneral(window)
	local Settings, Options = AUI.Settings, AUI.TooltipOptions
	local page = window:Page("tooltipGeneral", {
		title = GENERAL,
		under = "tooltipHeader",
		icon = AUI.Media.sidebar.tooltipGeneral,
		iconTint = true,
		-- The Units and Items pages hidden while the module is off are found through this switch.
		switch = {
			path = Options.ENABLED_PATH,
			default = Settings:Default(Options.ENABLED_PATH),
			label = L["Tooltip"],
			keywords = table.concat({ L["Units"], L["Name, Guild and Level"], L["Extra Lines"], L["Items"],
				L["Item Details"], L["ID Lines"], L["Upgrades"] }, " "),
		},
	})

	if not page then
		return
	end

	self.pageIDs.tooltipGeneral = true
	self:DeclareAppearance(page)
	self:DeclarePosition(page)
end

---Two real tooltips, a sample item and a sample spell, built by the client and given the chosen lines by the Details
---post-calls, which treat them as previews, and a sample tooltip with the chosen lines of the tooltips the preview
---cannot build, shown while it has any. A tooltip settles its size after it is built, and again when its data
---arrives, so a size change measures the preview again on the next frame, without building the tooltips again.
---@class AUIDetailsPreview
---@field page string the page showing the preview
---@field measuring boolean the preview is measured again, its tooltips left as they are
local DetailsPreview = {
	page = "tooltipItems",
	measuring = false,
}

---@param canvas Frame
function DetailsPreview:Create(canvas)
	local tooltips = {
		CreateFrame("GameTooltip", "AeonUITooltipPreviewItem", canvas, "GameTooltipTemplate"),
		CreateFrame("GameTooltip", "AeonUITooltipPreviewSpell", canvas, "GameTooltipTemplate"),
		CreateFrame("GameTooltip", "AeonUITooltipPreviewOther", canvas, "GameTooltipTemplate"),
	}

	AUI.TooltipDetails.previews = tooltips

	for _, tooltip in ipairs(tooltips) do
		-- The template flags a data update but rebuilds only from `GameTooltip_OnUpdate`, which it does not run, so an
		-- item still loading would keep its placeholder text.
		tooltip:HookScript("OnEvent", function(self, event)
			if event == "TOOLTIP_DATA_UPDATE" and self.shouldRefreshData and self:IsShown() then
				self:RefreshData()
			end
		end)
		tooltip:HookScript("OnSizeChanged", function()
			AUI.Events:Merge("tooltipPreviewMeasure", 0, function()
				DetailsPreview:Measure()
			end)
		end)
	end
end

---Measures the preview again while its page shows it.
function DetailsPreview:Measure()
	local window = AUI.Settings.window

	if self.measuring or not window or not window:IsShown() or window.page ~= self.page then
		return
	end

	self.measuring = true
	window:RefreshFixedArea()
	self.measuring = false
end

---@param canvas Frame
---@return number width
---@return number height
function DetailsPreview:Refresh(canvas)
	local item, spell, other = unpack(AUI.TooltipDetails.previews)

	if not self.measuring then
		for _, tooltip in ipairs(AUI.TooltipDetails.previews) do
			tooltip:SetOwner(canvas, "ANCHOR_NONE")
			tooltip:SetFrameStrata(canvas:GetFrameStrata())
			tooltip:SetFrameLevel(canvas:GetFrameLevel() + 1)
		end

		item:SetItemByID(DETAILS_SAMPLE_ITEM)
		spell:SetSpellByID(DETAILS_SAMPLE_SPELL)
		other:ClearLines()

		if AUI.TooltipDetails:Sample(other) then
			other:Show()
		else
			other:Hide()
		end

		item:ClearAllPoints()
		item:SetPoint("TOPLEFT", canvas, "TOPLEFT")
		spell:ClearAllPoints()
		spell:SetPoint("TOPLEFT", item, "TOPRIGHT", DETAILS_PREVIEW_GAP, 0)
		other:ClearAllPoints()
		other:SetPoint("TOPLEFT", spell, "TOPRIGHT", DETAILS_PREVIEW_GAP, 0)
	end

	local width = item:GetWidth() + DETAILS_PREVIEW_GAP + spell:GetWidth()
	local height = math.max(item:GetHeight(), spell:GetHeight())

	if other:IsShown() then
		width = width + DETAILS_PREVIEW_GAP + other:GetWidth()
		height = math.max(height, other:GetHeight())
	end

	return width, height
end

function DetailsPreview:Stop()
	for _, tooltip in ipairs(AUI.TooltipDetails.previews or {}) do
		tooltip:Hide()
	end
end

---Three sample tooltips, a player, a creature and a pet, filled by `TooltipUnits:Sample` with the chosen lines. A
---tooltip settles its size after it is shown, so a size change measures the preview again on the next frame.
---@class AUIUnitsPreview
---@field page string
---@field measuring boolean
---@field tooltips GameTooltip[]
local UnitsPreview = {
	page = "tooltipUnits",
	measuring = false,
	tooltips = {},
	Measure = DetailsPreview.Measure,
}

---@param canvas Frame
function UnitsPreview:Create(canvas)
	for index, kind in ipairs({ "Player", "Creature", "Pet" }) do
		local tooltip = CreateFrame("GameTooltip", "AeonUITooltipPreview" .. kind, canvas, "GameTooltipTemplate")

		self.tooltips[index] = tooltip
		tooltip:HookScript("OnSizeChanged", function()
			AUI.Events:Merge("tooltipUnitsPreviewMeasure", 0, function()
				UnitsPreview:Measure()
			end)
		end)
	end
end

---@param canvas Frame
---@return number width
---@return number height
function UnitsPreview:Refresh(canvas)
	local tooltips = self.tooltips

	if not self.measuring then
		for _, tooltip in ipairs(tooltips) do
			tooltip:SetOwner(canvas, "ANCHOR_NONE")
			tooltip:SetFrameStrata(canvas:GetFrameStrata())
			tooltip:SetFrameLevel(canvas:GetFrameLevel() + 1)
		end

		AUI.TooltipUnits:Sample(tooltips[1], tooltips[2], tooltips[3])

		for index, tooltip in ipairs(tooltips) do
			tooltip:Show()
			tooltip:ClearAllPoints()

			if index == 1 then
				tooltip:SetPoint("TOPLEFT", canvas, "TOPLEFT")
			else
				tooltip:SetPoint("TOPLEFT", tooltips[index - 1], "TOPRIGHT", DETAILS_PREVIEW_GAP, 0)
			end
		end
	end

	local width, height = 0, 0

	for index, tooltip in ipairs(tooltips) do
		width = width + (index > 1 and DETAILS_PREVIEW_GAP or 0) + tooltip:GetWidth()
		height = math.max(height, tooltip:GetHeight())
	end

	return width, height
end

function UnitsPreview:Stop()
	for _, tooltip in ipairs(self.tooltips) do
		tooltip:Hide()
	end
end

---@param window table
function SettingsTooltip:DeclareUnits(window)
	local Options = AUI.TooltipOptions
	local page = window:Page("tooltipUnits", {
		title = L["Units"],
		under = "tooltipHeader",
		icon = AUI.Media.sidebar.tooltipUnits,
		iconTint = true,
		show = ModuleShown,
	})

	if not page then
		return
	end

	self.pageIDs.tooltipUnits = true
	page:Preview({
		height = UNITS_PREVIEW_HEIGHT,
		create = function(canvas)
			UnitsPreview:Create(canvas)
		end,
		refresh = function(canvas)
			return UnitsPreview:Refresh(canvas)
		end,
		stop = function()
			UnitsPreview:Stop()
		end,
	})

	local lines = page:Section("tooltipUnitLines", L["Name, Guild and Level"], { columns = 2 })

	Choice(lines, "showTitles", L["Show Titles"], L["Player titles on the name line."], Options.TITLES_PATH)
	Choice(lines, "showGuildRank", L["Show Guild Rank"], L["The player's rank after the guild's name."],
		Options.GUILD_RANK_PATH)
	Choice(lines, "colorLevels", L["Color Levels"],
		L["The level in its difficulty color, followed by + for elite, Rare or Boss."], Options.LEVEL_COLOR_PATH)
	Choice(lines, "mutedLines", L["Color Owners and Pets"],
		L["Owner and corpse lines in gray, and battle-pet names in their reaction color."], Options.MUTED_LINES_PATH)

	local added = page:Section("tooltipUnitAdded", L["Extra Lines"], { columns = 2 })

	Choice(added, "showTarget", TARGET, L["Whom the unit is targeting."], Options.TARGET_PATH)
	Choice(added, "showRating", DUNGEON_SCORE, L["The player's Mythic+ rating, in its color."], Options.RATING_PATH,
		function()
			return AUI.can.mythicPlus == true
		end)
	Choice(added, "showMount", MOUNT, L["The player's mount, with a mark for whether you have it."],
		Options.MOUNT_PATH)
	Choice(added, "showItemLevel", STAT_AVERAGE_ITEM_LEVEL,
		L["The player's average item level, inspected once the cursor rests on them."], Options.ITEM_LEVEL_PATH)
	Choice(added, "showSpecialization", SPECIALIZATION,
		L["The player's specialization and role, from an inspect or shared by their addons."],
		Options.SPECIALIZATION_PATH, function()
			return AUI.can.specializations == true
		end)
	Choice(added, "auraCasters", L["Aura Caster Names"], L["Aura tooltips name who cast the aura."],
		Options.AURA_CASTERS_PATH, function()
			return AUI.can.auraCasterNames == true
		end)

	local roles = page:Section("tooltipUnitRoles", L["Role Icons"], {
		show = function()
			return AUI.can.specializations == true
		end,
	})
	local styles = {}

	for index, style in ipairs(AUI.Media.ROLE_STYLES) do
		local icons = {}

		for _, role in ipairs({ "TANK", "HEALER", "DAMAGER" }) do
			icons[#icons + 1] = AUI.Media:RoleMarkup(style, role, ROLE_SAMPLE_SIZE)
		end

		styles[index] = { value = style, text = ROLE_STYLE_LABELS[style] .. "  " .. table.concat(icons) }
	end

	roles:Dropdown({
		id = "roleIcons",
		label = L["Style"],
		path = Options.ROLE_ICONS_PATH,
		default = AUI.Settings:Default(Options.ROLE_ICONS_PATH),
		depends = "showSpecialization",
		options = styles,
	})
end

---The Items page: the Details preview, the item lines, the IDs and, where the client has upgrade tracks, the upgrade
---line.
---@param window table
function SettingsTooltip:DeclareItems(window)
	local Settings, Options = AUI.Settings, AUI.TooltipOptions
	local page = window:Page("tooltipItems", {
		title = L["Items"],
		under = "tooltipHeader",
		icon = AUI.Media.sidebar.tooltipItems,
		iconTint = true,
		show = ModuleShown,
	})

	if not page then
		return
	end

	self.pageIDs.tooltipItems = true
	page:Preview({
		height = DETAILS_PREVIEW_HEIGHT,
		create = function(canvas)
			DetailsPreview:Create(canvas)
		end,
		refresh = function(canvas)
			return DetailsPreview:Refresh(canvas)
		end,
		stop = function()
			DetailsPreview:Stop()
		end,
	})

	local lines = page:Section("tooltipDetailLines", L["Item Details"], { columns = 2 })

	Choice(lines, "showExpansion", EXPANSION_FILTER_TEXT, nil, Options.EXPANSION_PATH, function()
			return AUI.can.expansions == true
		end)
	Choice(lines, "showItemType", L["Category and Type"], L["An item's category and type, such as Armor / Plate."],
		Options.ITEM_TYPE_PATH)
	Choice(lines, "showMaxStack", L["Max Stack"], nil, Options.MAX_STACK_PATH)
	Choice(lines, "blankLine", L["Blank Line Before"], nil, Options.BLANK_LINE_PATH)

	local ids = page:Section("tooltipDetailIDs", L["ID Lines"])
	local modifiers = {}

	for index, modifier in ipairs(Options.MODIFIERS) do
		modifiers[index] = { value = modifier, text = MODIFIER_LABELS[modifier] }
	end

	ids:Dropdown({
		id = "idModifier",
		label = L["Modifier"],
		description = L["With None they always show."],
		path = Options.ID_MODIFIER_PATH,
		default = Settings:Default(Options.ID_MODIFIER_PATH),
		depends = SWITCH,
		options = modifiers,
	})

	local idLines = page:Section("tooltipDetailIDLines", nil, { columns = 2 })

	for _, key in ipairs(Options.ID_KEYS) do
		local line = ID_LINES[key]

		if line then
			Choice(idLines, line.id, line.label, line.description, Options.ID_PATHS[key])
		end
	end

	if AUI.can.upgrades then
		self:DeclareUpgrades(page)
	end
end

---The Items page's upgrade line.
---@param page table
function SettingsTooltip:DeclareUpgrades(page)
	local Settings, Options = AUI.Settings, AUI.TooltipOptions
	local line = page:Section("tooltipUpgradeLine", L["Upgrades"])

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
	self:DeclareGeneral(window)
	self:DeclareUnits(window)
	self:DeclareItems(window)
end
