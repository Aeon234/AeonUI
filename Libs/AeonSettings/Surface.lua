-- Section surface: the section panel art drawn across page-list elements, one slice per element.
local _, ns = ...
local AS = ns.AeonSettings
local tokens = AS.tokens

local HEADER_TOP_PADDING = 2 -- surface top edge to the header's title area
local HEADER_TOGGLE_LIFT = 2

---Where a section-style header places its title and its right-side controls: the title area's vertical
---center below the element's top edge, and how far the plus/minus and similar controls sit above that line.
---@return number titleCenter
---@return number toggleLift
function AS:HeaderLayout()
	return tokens.space.sectionGap + HEADER_TOP_PADDING + tokens.size.sectionHeader / 2, HEADER_TOGGLE_LIFT
end

local FILE_WIDTH, FILE_HEIGHT = 1024, 256
local ART_WIDTH = 1024
local SIDE = 20 -- side piece width in art pixels
local BORDER_SCALE = 0.4 -- side, top and bottom border pieces are drawn at this scale
local TOP_BORDER_TOP, TOP_BORDER_BOTTOM = 0, 16
local HEADER_BAND_TOP, HEADER_BAND_BOTTOM = 16, 48
local GOLD_LINE_TOP, GOLD_LINE_BOTTOM = 48, 52
local BODY_TOP, BODY_BOTTOM = 52, 180
local BOTTOM_BORDER_TOP, BOTTOM_BORDER_BOTTOM = 180, 196
local BANDS = 3
local DRAW_LAYER, DRAW_SUBLEVEL = "BACKGROUND", -8

---@alias AeonSettingsSurfaceShape "NONE" | "ROW" | "LAST_ROW" | "HEADER" | "CLOSED_HEADER" | "BODY"

---@class AeonSettingsSurface
---@field frame Frame
---@field pieces Texture[][] bands of three textures: left, middle, right
local Surface = {}
Surface.__index = Surface

---@param frame Frame element the surface is drawn on
---@return AeonSettingsSurface
function AS:CreateSurface(frame)
	local surface = setmetatable({ frame = frame, pieces = {} }, Surface)
	local file = AS.MEDIA .. "SectionHeader\\Surface.png"

	for band = 1, BANDS do
		local pieces = {}
		for piece = 1, 3 do
			local texture = frame:CreateTexture(nil, DRAW_LAYER, nil, DRAW_SUBLEVEL)
			texture:SetTexture(file)
			texture:Hide()
			pieces[piece] = texture
		end
		surface.pieces[band] = pieces
	end

	return surface
end

---Draws one horizontal band of the art, from art row `top` to `bottom` (reversed rows flip it vertically),
---`height` UI units tall and `y` below the frame's top.
---@param band integer
---@param top number
---@param bottom number
---@param y number
---@param height number
function Surface:DrawBand(band, top, bottom, y, height)
	local frame = self.frame
	local pieces = self.pieces[band]
	local left, middle, right = pieces[1], pieces[2], pieces[3]
	local v1, v2 = top / FILE_HEIGHT, bottom / FILE_HEIGHT
	local side = SIDE * BORDER_SCALE

	left:SetTexCoord(0, SIDE / FILE_WIDTH, v1, v2)
	middle:SetTexCoord(SIDE / FILE_WIDTH, (ART_WIDTH - SIDE) / FILE_WIDTH, v1, v2)
	right:SetTexCoord((ART_WIDTH - SIDE) / FILE_WIDTH, ART_WIDTH / FILE_WIDTH, v1, v2)

	for _, texture in ipairs(pieces) do
		texture:ClearAllPoints()
		texture:SetHeight(height)
		texture:Show()
	end
	left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -y)
	left:SetWidth(side)
	right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -y)
	right:SetWidth(side)
	middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
	middle:SetPoint("TOPRIGHT", right, "TOPLEFT")
end

---Hides bands from `first` to the last.
---@param first integer
function Surface:HideBands(first)
	for band = first, BANDS do
		for _, texture in ipairs(self.pieces[band]) do
			texture:Hide()
		end
	end
end

---Draws the slice for a shape. Rows take a body strip, the section's last row closes with the bottom border;
---a header leaves the section gap above its top border, then the header band and gold line; a closed header
---ends with the top border mirrored; a body closes with the bottom border above which it stretches the whole
---body art, or, when shorter than the art, takes a centered strip of it.
---@param shape AeonSettingsSurfaceShape
---@param height number? the slice's height; defaults to one row
function Surface:SetShape(shape, height)
	height = height or tokens.size.row
	local middle = (BODY_TOP + BODY_BOTTOM) / 2
	local topBorder = (TOP_BORDER_BOTTOM - TOP_BORDER_TOP) * BORDER_SCALE

	if shape == "ROW" then
		self:DrawBand(1, middle - height / 2, middle + height / 2, 0, height)
		self:HideBands(2)
	elseif shape == "LAST_ROW" then
		local border = (BOTTOM_BORDER_BOTTOM - BOTTOM_BORDER_TOP) * BORDER_SCALE
		local body = height - border
		self:DrawBand(1, middle - height / 2, middle - height / 2 + body, 0, body)
		self:DrawBand(2, BOTTOM_BORDER_TOP, BOTTOM_BORDER_BOTTOM, body, border)
		self:HideBands(3)
	elseif shape == "HEADER" then
		local gap = tokens.space.sectionGap
		local line = (GOLD_LINE_BOTTOM - GOLD_LINE_TOP) * BORDER_SCALE
		local band = height - gap - topBorder - line
		self:DrawBand(1, TOP_BORDER_TOP, TOP_BORDER_BOTTOM, gap, topBorder)
		self:DrawBand(2, HEADER_BAND_TOP, HEADER_BAND_BOTTOM, gap + topBorder, band)
		self:DrawBand(3, GOLD_LINE_TOP, GOLD_LINE_BOTTOM, gap + topBorder + band, line)
	elseif shape == "CLOSED_HEADER" then
		local gap = tokens.space.sectionGap
		local band = height - gap - topBorder * 2
		self:DrawBand(1, TOP_BORDER_TOP, TOP_BORDER_BOTTOM, gap, topBorder)
		self:DrawBand(2, HEADER_BAND_TOP, HEADER_BAND_BOTTOM, gap + topBorder, band)
		self:DrawBand(3, TOP_BORDER_BOTTOM, TOP_BORDER_TOP, gap + topBorder + band, topBorder)
	elseif shape == "BODY" then
		local border = (BOTTOM_BORDER_BOTTOM - BOTTOM_BORDER_TOP) * BORDER_SCALE
		local body = height - border
		local art = BODY_BOTTOM - BODY_TOP
		if body < art then
			self:DrawBand(1, middle - body / 2, middle + body / 2, 0, body)
		else
			self:DrawBand(1, BODY_TOP, BODY_BOTTOM, 0, body)
		end
		self:DrawBand(2, BOTTOM_BORDER_TOP, BOTTOM_BORDER_BOTTOM, body, border)
		self:HideBands(3)
	else
		self:HideBands(1)
	end
end
