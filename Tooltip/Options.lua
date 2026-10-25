local AUI = select(2, ...)

local Schema = AUI.Schema

-- Blizzard's sizes for the tooltip's header and body text, and how much smaller its small text is than the body.
local HEADER_SIZE, BODY_SIZE, SMALL_STEP = 14, 12, 2
-- The smallest size the small text is given.
local SMALL_MIN = 6
-- Blizzard's health bar: its height, and where it sits under the tooltip's bottom edge.
local BAR_HEIGHT, BAR_INSET, BAR_GAP = 8, 2, 1
-- How far the strip sits inside the tooltip's border.
local STRIP_INSET = 3

---The tooltip's settings and the frame-free arithmetic behind them: the font sizes and where the health bar sits.
---@class AUITooltipOptions
---@field ENABLED_PATH string the module
---@field FONT_CUSTOM_PATH string the tooltip's text takes the font settings below instead of Blizzard's
---@field FONT_FACE_PATH string a LibSharedMedia font name
---@field FONT_HEADER_PATH string the first line's size
---@field FONT_BODY_PATH string every other line's size; the small text follows it
---@field FONT_OUTLINE_PATH string a `fontOutline` choice
---@field BAR_STYLE_PATH string a `tooltipBarStyle` choice
---@field BAR_TEXTURE_PATH string a LibSharedMedia bar texture name
---@field BAR_HEIGHT_PATH string the bar's height in Blizzard's place
---@field STRIP_HEIGHT_PATH string the strip's height
---@field BAR_STYLES string[]
---@field BLIZZARD_BAR_HEIGHT number the height Blizzard gives the bar
local Options = {
	ENABLED_PATH = "tooltip.enabled",
	FONT_CUSTOM_PATH = "tooltip.font.custom",
	FONT_FACE_PATH = "tooltip.font.face",
	FONT_HEADER_PATH = "tooltip.font.headerSize",
	FONT_BODY_PATH = "tooltip.font.bodySize",
	FONT_OUTLINE_PATH = "tooltip.font.outline",
	BAR_STYLE_PATH = "tooltip.healthBar.style",
	BAR_TEXTURE_PATH = "tooltip.healthBar.texture",
	BAR_HEIGHT_PATH = "tooltip.healthBar.height",
	STRIP_HEIGHT_PATH = "tooltip.healthBar.stripHeight",
	-- BLIZZARD: under the tooltip, where Blizzard puts it. STRIP: along the inside of its bottom edge.
	BAR_STYLES = { "BLIZZARD", "STRIP" },
	BLIZZARD_BAR_HEIGHT = BAR_HEIGHT,
}
AUI.TooltipOptions = Options

Schema:Choices("tooltipBarStyle", Options.BAR_STYLES)

Schema:Boolean(Options.ENABLED_PATH, true)
Schema:Boolean(Options.FONT_CUSTOM_PATH, false)
Schema:String(Options.FONT_FACE_PATH, "Friz Quadrata TT", 64)
Schema:Number(Options.FONT_HEADER_PATH, HEADER_SIZE, 8, 24, true)
Schema:Number(Options.FONT_BODY_PATH, BODY_SIZE, 8, 20, true)
Schema:Choice(Options.FONT_OUTLINE_PATH, "fontOutline", "NONE")
Schema:Choice(Options.BAR_STYLE_PATH, "tooltipBarStyle", "BLIZZARD")
Schema:String(Options.BAR_TEXTURE_PATH, AUI.Media.TOOLTIP_BAR, 64)
Schema:Number(Options.BAR_HEIGHT_PATH, BAR_HEIGHT, 2, 16, true)
Schema:Number(Options.STRIP_HEIGHT_PATH, 3, 1, 8, true)

---@param body number the body text's size
---@return number size the small text's size, as far below the body as Blizzard's is
function Options:SmallSize(body)
	return math.max(SMALL_MIN, body - SMALL_STEP)
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

---@param style string
---@param height number the bar's height in Blizzard's place
---@param stripHeight number
---@return number height the bar's height in that style
function Options:BarHeight(style, height, stripHeight)
	return style == "STRIP" and stripHeight or height
end
