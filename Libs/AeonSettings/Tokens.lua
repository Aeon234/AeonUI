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
		sectionTitle = { 0.96, 0.91, 0.82 },
		speakerIcon = { 0.85, 0.85, 0.85 },
		flash = { 1, 0.82, 0 },
	},
	alpha = {
		inactive = 0.5,
		hover = 0.2,
		off = 0.4,
		bandOdd = 0,
		bandEven = 0.18,
		divider = 0.12,
		rowHover = 0.05,
	},
	font = {
		bodySize = 14,
		headerSize = 16,
		tagSize = 12,
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
		sectionGap = 6,
		rowInset = 20,
		labelToControl = 12,
		sliderToBox = 8,
		speakerGap = 4,
		tagGap = 4,
		headerBarToTitle = 8,
	},
	size = {
		row = 36,
		categoryColumn = 192,
		categoryColumnX = 22,
		windowButton = 32,
		closeButton = 120,
		listIcon = 16,
		slider = 168,
		numberBox = 44,
		valueControl = 220,
		sectionHeader = 28,
		speaker = 24,
		speakerIcon = 20,
		useShared = 16,
		headerBar = 2,
	},
	motion = {
		slide = 0.20,
		press = 0.95,
		reject = { amplitude = 3, cycles = 3, duration = 0.25 },
		fadeOut = 0.5,
		statusHold = 4,
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
