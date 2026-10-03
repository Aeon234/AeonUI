-- Shared design values: colors, alphas, spacing, sizes and motion.
local _, ns = ...
local AS = ns.AeonSettings

---@class AeonSettingsTokens
AS.tokens = {
	color = {
		accent = { 0.620, 0.459, 0.290 },
		neutral = { 0.6, 0.6, 0.6 },
		text = { 1, 1, 1 },
		error = { 1, 0.25, 0.25 },
		notice = { 1, 0.82, 0 },
		sectionTitle = { 1, 0.918, 0.761 },
		speakerIcon = { 0.85, 0.85, 0.85 },
		flash = { 1, 0.82, 0 },
		contentFill = { 0, 0, 0, 0.45 },
		divider = { 73 / 255, 62 / 255, 61 / 255 },
	},
	alpha = {
		inactive = 0.5,
		hover = 0.2,
		off = 0.4,
		bandOdd = 0.05,
		bandEven = 0.28,
		divider = 0.12,
		rowHover = 0.06,
		guide = 0.15,
		dividerSoft = 0.4,
		sectionLine = 0.3,
		description = 0.65,
	},
	font = {
		bodySize = 14,
		headerSize = 16,
		titleSize = 32,
		descriptionSize = 14,
		sectionSize = 16,
		tabSize = 15,
		hintSize = 11,
		categoryHeaderSize = 16,
		categoryPageSize = 15,
		shadowOffset = { 1, -1 },
	},
	space = {
		gap = 8,
		hover = 4,
		innerFrameX = 17,
		innerFrameY = 64,
		innerBottom = 44,
		columnGap = 10,
		bottomBand = 9,
		listIconGap = 6,
		sectionGap = 20,
		rowInset = 20,
		labelToControl = 12,
		sliderToBox = 8,
		speakerGap = 4,
		tagGap = 4,
		indent = 16,
		guide = 6,
		dotToLabel = 6,
		pageGap = 2,
	},
	size = {
		row = 50,
		windowRow = 36,
		categoryColumn = 216,
		categoryColumnX = 22,
		categoryHeader = 28,
		categoryPage = 22,
		windowButton = 32,
		closeButton = 120,
		listIcon = 16,
		slider = 168,
		numberBox = 44,
		valueControl = 220,
		sectionHeader = 40,
		speaker = 24,
		speakerIcon = 20,
		useShared = 16,
		inheritDot = 6,
		swatch = 30,
	},
	motion = {
		slide = 0.20,
		press = 0.95,
		reject = { amplitude = 3, cycles = 3, duration = 0.25 },
		fadeOut = 0.5,
		statusHold = 4,
		find = { speed = 12, snap = 0.3, flashAt = 6, hold = 3, fade = 0.6 },
	},
}

---Applies `font.body` or `font.header` to a font string, with the shared shadow.
---@param fontString FontString
---@param token "body" | "header"
---@param size number? overrides the token's size
function AS:SetFont(fontString, token, size)
	local font = self.tokens.font
	fontString:SetFont(self.fonts[token], size or (token == "header" and font.headerSize or font.bodySize), "")
	fontString:SetShadowColor(0, 0, 0, 1)
	fontString:SetShadowOffset(font.shadowOffset[1], font.shadowOffset[2])
end
