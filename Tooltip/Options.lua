local AUI = select(2, ...)

local Schema = AUI.Schema

-- Blizzard's sizes for the tooltip's title, body and small text, which the font scale multiplies.
local SIZES = { header = 14, body = 12, small = 10 }
-- Blizzard's health bar: its height, and where it sits under the tooltip's bottom edge.
local BAR_HEIGHT, BAR_INSET, BAR_GAP = 8, 2, 1
-- How far the strip sits inside the tooltip's border, and the room kept above it besides its own height.
local STRIP_INSET, STRIP_GAP = 3, 1

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
