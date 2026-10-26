local AUI = select(2, ...)

local Schema = AUI.Schema

-- Blizzard's sizes for the tooltip's title, body and small text, which the font scale multiplies.
local SIZES = { header = 14, body = 12, small = 10 }
-- Blizzard's health bar: its height, and where it sits under the tooltip's bottom edge.
local BAR_HEIGHT, BAR_INSET, BAR_GAP = 8, 2, 1
-- How far the strip sits inside the tooltip's border, and the room kept above it besides its own height.
local STRIP_INSET, STRIP_GAP = 3, 1
-- The tooltip's corner that touches the cursor, for each place the tooltip can take around it.
local CURSOR_POINTS = {
	TOP = "BOTTOM", BOTTOM = "TOP", LEFT = "RIGHT", RIGHT = "LEFT", CENTER = "CENTER",
	TOPLEFT = "BOTTOMRIGHT", TOPRIGHT = "BOTTOMLEFT", BOTTOMLEFT = "TOPRIGHT", BOTTOMRIGHT = "TOPLEFT",
}

---The tooltip's settings and the frame-free arithmetic behind them: the font sizes and where the health bar sits.
---@class AUITooltipOptions
---@field ENABLED_PATH string the module
---@field FONT_CUSTOM_PATH string the tooltip's text takes the font face and outline below instead of Blizzard's
---@field FONT_FACE_PATH string a LibSharedMedia font name
---@field FONT_SCALE_PATH string Blizzard's text sizes, in percent
---@field FONT_OUTLINE_PATH string a `fontOutline` choice
---@field BAR_SHOWN_PATH string `GameTooltip`'s health bar shows
---@field BAR_STYLE_PATH string a `tooltipBarStyle` choice
---@field BAR_TEXTURE_PATH string a LibSharedMedia bar texture name
---@field BAR_HEIGHT_PATH string the bar's height, in either style
---@field TITLES_PATH string player titles stay on the name line
---@field GUILD_RANK_PATH string the guild line carries the player's rank
---@field LEVEL_COLOR_PATH string the level is drawn in its difficulty color with its classification mark
---@field MUTED_LINES_PATH string owner and corpse lines are grayed and battle-pet names take their reaction color
---@field TARGET_PATH string unit tooltips add whom the unit targets
---@field MOUNT_PATH string player tooltips add the player's mount
---@field RATING_PATH string player tooltips add the Mythic+ rating, where the client has one
---@field AURA_CASTERS_PATH string aura tooltips name who cast the aura, where the client offers it
---@field ITEM_LEVEL_PATH string player tooltips add the player's item level
---@field SPECIALIZATION_PATH string player tooltips add the player's specialization, where the client has them
---@field EXPANSION_PATH string item tooltips add the item's expansion, where the client has expansions
---@field ITEM_TYPE_PATH string item tooltips add the item's category and type
---@field MAX_STACK_PATH string item tooltips add how many stack in one slot
---@field BLANK_LINE_PATH string a blank line separates the tooltip from AeonUI's detail lines
---@field ID_MODIFIER_PATH string a `tooltipModifier` choice: the key that must be held for the ID lines
---@field ID_PATHS table<string, string> each ID line's setting, by its key in `ID_KEYS`
---@field ID_KEYS string[] the ID lines, in the order the page lists them
---@field MODIFIERS string[]
---@field UPGRADE_RANK_PATH string the upgrade line's track and rank take the track's color
---@field UPGRADE_RANGE_PATH string the upgrade line adds the track's item-level range
---@field UPGRADE_RANGE_COLOR_PATH string the range's color
---@field UPGRADE_CREST_PATH string the upgrade line adds the crest the next upgrade costs
---@field SHOW_MODE_PATH string a `tooltipShowMode` choice: when `GameTooltip` may be seen
---@field PEEK_PATH string a `tooltipModifier` choice: the key that shows a hidden tooltip while held
---@field CURSOR_PATH string default-anchored tooltips follow the cursor
---@field CURSOR_POINT_PATH string a `tooltipCursorPoint` choice: where the tooltip sits around the cursor
---@field CURSOR_X_PATH string the cursor tooltip's horizontal offset
---@field CURSOR_Y_PATH string its vertical offset
---@field GROWTH_PATH string a `tooltipGrowth` choice: which way a default-anchored tooltip grows
---@field POSITION_PATH string AeonUI's place for default-anchored tooltips; absent keeps Blizzard's
---@field SHOW_MODES string[]
---@field CURSOR_POINTS string[]
---@field GROWTHS string[]
---@field ANCHOR_WIDTH number the size of the box default-anchored tooltips are pinned inside
---@field ANCHOR_HEIGHT number
---@field BAR_STYLES string[]
---@field BLIZZARD_BAR_HEIGHT number the height Blizzard gives the bar
local Options = {
	ENABLED_PATH = "tooltip.enabled",
	FONT_CUSTOM_PATH = "tooltip.font.custom",
	FONT_FACE_PATH = "tooltip.font.face",
	FONT_SCALE_PATH = "tooltip.font.scale",
	FONT_OUTLINE_PATH = "tooltip.font.outline",
	BAR_SHOWN_PATH = "tooltip.healthBar.enabled",
	BAR_STYLE_PATH = "tooltip.healthBar.style",
	BAR_TEXTURE_PATH = "tooltip.healthBar.texture",
	BAR_HEIGHT_PATH = "tooltip.healthBar.height",
	TITLES_PATH = "tooltip.units.titles",
	GUILD_RANK_PATH = "tooltip.units.guildRank",
	LEVEL_COLOR_PATH = "tooltip.units.levelColor",
	MUTED_LINES_PATH = "tooltip.units.mutedLines",
	TARGET_PATH = "tooltip.units.target",
	MOUNT_PATH = "tooltip.units.mount",
	RATING_PATH = "tooltip.units.rating",
	AURA_CASTERS_PATH = "tooltip.units.auraCasters",
	ITEM_LEVEL_PATH = "tooltip.units.itemLevel",
	SPECIALIZATION_PATH = "tooltip.units.specialization",
	EXPANSION_PATH = "tooltip.details.expansion",
	ITEM_TYPE_PATH = "tooltip.details.itemType",
	MAX_STACK_PATH = "tooltip.details.maxStack",
	BLANK_LINE_PATH = "tooltip.details.blankLine",
	ID_MODIFIER_PATH = "tooltip.details.modifier",
	-- item: items and toys; spell: spells, auras, pet actions and a mount's spell; macro: the spell or item a macro
	-- uses; age: how long an NPC has been spawned.
	ID_KEYS = { "item", "spell", "icon", "npc", "age", "currency", "mount", "quest", "macro" },
	ID_PATHS = {},
	MODIFIERS = { "NONE", "SHIFT", "CTRL", "ALT" },
	UPGRADE_RANK_PATH = "tooltip.upgrades.rank",
	UPGRADE_RANGE_PATH = "tooltip.upgrades.range",
	UPGRADE_RANGE_COLOR_PATH = "tooltip.upgrades.rangeColor",
	UPGRADE_CREST_PATH = "tooltip.upgrades.crest",
	SHOW_MODE_PATH = "tooltip.visibility.mode",
	PEEK_PATH = "tooltip.visibility.peek",
	CURSOR_PATH = "tooltip.cursor.enabled",
	CURSOR_POINT_PATH = "tooltip.cursor.point",
	CURSOR_X_PATH = "tooltip.cursor.x",
	CURSOR_Y_PATH = "tooltip.cursor.y",
	GROWTH_PATH = "tooltip.growth",
	POSITION_PATH = "tooltip.position",
	SHOW_MODES = { "ALWAYS", "OUT_OF_COMBAT", "OUT_OF_BOSS_COMBAT", "NEVER" },
	CURSOR_POINTS = { "TOP", "BOTTOM", "LEFT", "RIGHT", "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", "CENTER" },
	GROWTHS = { "DEFAULT", "UP", "DOWN" },
	ANCHOR_WIDTH = 280,
	ANCHOR_HEIGHT = 165,
	-- BLIZZARD: under the tooltip, where Blizzard puts it. STRIP: along the inside of its bottom edge.
	BAR_STYLES = { "BLIZZARD", "STRIP" },
	BLIZZARD_BAR_HEIGHT = BAR_HEIGHT,
}
AUI.TooltipOptions = Options

Schema:Choices("tooltipBarStyle", Options.BAR_STYLES)

Schema:Boolean(Options.ENABLED_PATH, true)
Schema:Boolean(Options.FONT_CUSTOM_PATH, false)
Schema:String(Options.FONT_FACE_PATH, "Friz Quadrata TT", 64)
Schema:Number(Options.FONT_SCALE_PATH, 100, 70, 150, true)
Schema:Choice(Options.FONT_OUTLINE_PATH, "fontOutline", "SLUG")
Schema:Boolean(Options.BAR_SHOWN_PATH, false)
Schema:Choice(Options.BAR_STYLE_PATH, "tooltipBarStyle", "BLIZZARD")
Schema:String(Options.BAR_TEXTURE_PATH, AUI.Media.TOOLTIP_BAR, 64)
Schema:Number(Options.BAR_HEIGHT_PATH, BAR_HEIGHT, 1, 16, true)
Schema:Boolean(Options.TITLES_PATH, false)
Schema:Boolean(Options.GUILD_RANK_PATH, true)
Schema:Boolean(Options.LEVEL_COLOR_PATH, true)
Schema:Boolean(Options.MUTED_LINES_PATH, true)
Schema:Boolean(Options.TARGET_PATH, true)
Schema:Boolean(Options.MOUNT_PATH, true)
Schema:Boolean(Options.RATING_PATH, true)
Schema:Boolean(Options.AURA_CASTERS_PATH, true)
Schema:Boolean(Options.ITEM_LEVEL_PATH, true)
Schema:Boolean(Options.SPECIALIZATION_PATH, true)
Schema:Choices("tooltipModifier", Options.MODIFIERS)
Schema:Boolean(Options.EXPANSION_PATH, true)
Schema:Boolean(Options.ITEM_TYPE_PATH, true)
Schema:Boolean(Options.MAX_STACK_PATH, true)
Schema:Boolean(Options.BLANK_LINE_PATH, true)
Schema:Choice(Options.ID_MODIFIER_PATH, "tooltipModifier", "NONE")

Schema:Boolean(Options.UPGRADE_RANK_PATH, true)
Schema:Boolean(Options.UPGRADE_RANGE_PATH, true)
Schema:Color(Options.UPGRADE_RANGE_COLOR_PATH, { r = 1, g = 1, b = 1 })
Schema:Boolean(Options.UPGRADE_CREST_PATH, true)

Schema:Choices("tooltipShowMode", Options.SHOW_MODES)
Schema:Choices("tooltipCursorPoint", Options.CURSOR_POINTS)
Schema:Choices("tooltipGrowth", Options.GROWTHS)
Schema:Choice(Options.SHOW_MODE_PATH, "tooltipShowMode", "ALWAYS")
Schema:Choice(Options.PEEK_PATH, "tooltipModifier", "NONE")
Schema:Boolean(Options.CURSOR_PATH, false)
Schema:Choice(Options.CURSOR_POINT_PATH, "tooltipCursorPoint", "TOP")
Schema:Number(Options.CURSOR_X_PATH, 0, -200, 200, true)
Schema:Number(Options.CURSOR_Y_PATH, 0, -200, 200, true)
Schema:Choice(Options.GROWTH_PATH, "tooltipGrowth", "DEFAULT")
Schema:Position(Options.POSITION_PATH)

for _, key in ipairs(Options.ID_KEYS) do
	Options.ID_PATHS[key] = "tooltip.details.ids." .. key
	Schema:Boolean(Options.ID_PATHS[key], true)
end

---@param kind "header"|"body"|"small"
---@param scale number the font scale, in percent
---@return number size Blizzard's size for that text, scaled and rounded to the nearest whole size
function Options:FontSize(kind, scale)
	return math.floor(SIZES[kind] * scale / 100 + 0.5)
end

---@class AUITooltipBarPlace
---@field from string the bar's point
---@field to string the tooltip's point it is set on
---@field x number
---@field y number

---@param style string a `tooltipBarStyle` choice; an unknown one is Blizzard's
---@return AUITooltipBarPlace left
---@return AUITooltipBarPlace right
function Options:BarPlace(style)
	if style == "STRIP" then
		return { from = "BOTTOMLEFT", to = "BOTTOMLEFT", x = STRIP_INSET, y = STRIP_INSET },
			{ from = "BOTTOMRIGHT", to = "BOTTOMRIGHT", x = -STRIP_INSET, y = STRIP_INSET }
	end

	return { from = "TOPLEFT", to = "BOTTOMLEFT", x = BAR_INSET, y = -BAR_GAP },
		{ from = "TOPRIGHT", to = "BOTTOMRIGHT", x = -BAR_INSET, y = -BAR_GAP }
end

---@param height number the strip's height
---@return number padding the room a tooltip keeps below its last line so that no line reaches the strip
function Options:StripPadding(height)
	return height + STRIP_GAP
end

---@param place string a `tooltipCursorPoint` choice
---@return string point the tooltip's point set on the cursor
function Options:CursorPoint(place)
	return CURSOR_POINTS[place] or "BOTTOM"
end

---@param point string the corner a default-anchored tooltip is pinned by, such as "BOTTOMRIGHT"
---@param growth string a `tooltipGrowth` choice
---@return string point the same side, pinned at the top to grow down or at the bottom to grow up
function Options:GrowthPoint(point, growth)
	if growth ~= "UP" and growth ~= "DOWN" then
		return point
	end

	local side = point:match("LEFT") or point:match("RIGHT") or ""

	return (growth == "DOWN" and "TOP" or "BOTTOM") .. side
end

---@param centerX number the anchor box's center from the screen's center
---@param centerY number
---@param growth string a `tooltipGrowth` choice
---@return string corner the box's corner nearest the screen's nearest corner, so the tooltip grows into the screen;
---a growth choice sets its top or bottom
function Options:FixedCorner(centerX, centerY, growth)
	local vertical = centerY < 0 and "BOTTOM" or "TOP"

	if growth == "UP" then
		vertical = "BOTTOM"
	elseif growth == "DOWN" then
		vertical = "TOP"
	end

	return vertical .. (centerX < 0 and "LEFT" or "RIGHT")
end

---Where the anchor box sits so a tooltip pinned in it lands where Blizzard's container puts it.
---@param left number the container's left edge, in UIParent units
---@param bottom number
---@param width number
---@param height number
---@param screenWidth number UIParent's size
---@param screenHeight number
---@return { point: string, x: number, y: number } position the box's corner on the same corner of the screen
function Options:ContainerPosition(left, bottom, width, height, screenWidth, screenHeight)
	local right = left + width / 2 >= screenWidth / 2
	local top = bottom + height / 2 >= screenHeight / 2
	local x = right and (left + width - screenWidth) or left
	local y = top and (bottom + height - screenHeight) or bottom

	return { point = (top and "TOP" or "BOTTOM") .. (right and "RIGHT" or "LEFT"), x = x, y = y }
end

