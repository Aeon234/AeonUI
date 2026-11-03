local AUI = select(2, ...)

local TEXTURES = "Interface\\AddOns\\" .. AUI.name .. "\\Media\\Textures\\"

-- Each Forever style is a UI-HUD-ActionBar-Frame export as it is, its own dark middle being the background, 110 texels
-- square. Corners are `across` texels wide and `down` texels tall. Forever's top and bottom carry worn detail out to
-- texel 44, which stretching would smear, so its corners are 48 wide like the atlas; its sides are cut 20 in, past the
-- chamfer (texel 18). Forever Minimal's band is plain past texel 18, so it is cut 20 both ways and its edges and middle
-- are drawn from a strip one texel long through the art's middle, stretched. Their band runs texels 6 to 9 from the
-- outer edge, and the content's edge meets its inner shadow 10.5 texels in; at each corner the band crosses the
-- diagonal from x + y = 22 to 30, so a square owner's corners lie under the chamfer.
-- Slate is Advanced Mythic Tracker's control frame, 128 texels square with 32-texel corners: a soft outer shadow at
-- texels 13 and 14, the band at 15 to 18 (a black outline, two gray texels, a dark inner line), its inner shadow to
-- 19.5, then a dark gray middle; at each corner the band crosses the diagonal at x + y = 36 to 42. Its band copy is the
-- tracker's ring, the same edge with the middle cleared.
---@class AUIBorderArt
---@field file string the art with its own dark middle
---@field band string the same art with its middle cleared, drawn above content
---@field size integer the file's width and height, in texels
---@field across integer corner width, in texels
---@field down integer corner height, in texels
---@field bandStart integer the band's first texel from the art's outer edge, which `PlaceArt` puts on a whole pixel
---@field outset number texels the art reaches outside the owner, so the owner's edge meets the band's inner shadow
---@field tinted boolean? Border Color tints a gray copy of it
---@field strip boolean? its edges and middle are drawn from a one-texel strip through its middle
---@field white boolean? its band is white, so it is always tinted, Border Color included at the art's own color

---@type table<string, AUIBorderArt>
local ART = {
	FOREVER_MINIMAL = { file = TEXTURES .. "ForeverMinimal.tga", band = TEXTURES .. "ForeverMinimalBand.tga", size = 110,
		tinted = true, strip = true, across = 20, down = 20, bandStart = 6, outset = 10.5 },
	FOREVER_MINIMAL_SHADED = { file = TEXTURES .. "ForeverMinimalShaded.tga",
		band = TEXTURES .. "ForeverMinimalShaded.tga", size = 110, tinted = true, white = true, strip = true, across = 20,
		down = 20, bandStart = 6, outset = 10.5 },
	FOREVER = { file = TEXTURES .. "Forever.tga", band = TEXTURES .. "ForeverBand.tga", size = 110, across = 48,
		down = 20, bandStart = 6, outset = 10.5 },
	SLATE = { file = TEXTURES .. "Slate.tga", band = TEXTURES .. "SlateBand.tga", size = 128, tinted = true, strip = true,
		across = 32, down = 32, bandStart = 15, outset = 19.5 },
}
-- The atlas's own scale, half a UI unit per texel (110 texels at 55 units): Border Thickness is a percentage of it, so
-- at 100 % the band (texels 6 to 9) is 2 units, as Blizzard draws it. An owner too small for two corners at the chosen
-- scale draws the art smaller (`ArtScale`).
local ART_SCALE = 0.5
-- The band's width in texels, the same in every art.
local BAND_WIDTH = 4
-- The art's nine pieces by row and column (1 top or left, 2 middle, 3 bottom or right), in creation order: the four
-- corners, the top and bottom edges, the left and right edges, the middle.
local PIECES = {
	{ 1, 1 }, { 1, 3 }, { 3, 1 }, { 3, 3 }, { 1, 2 }, { 3, 2 }, { 2, 1 }, { 2, 3 }, { 2, 2 },
}

-- Blizzard's metal window frame, used directly, at the size Blizzard draws it on its windows (times Border Thickness).
-- The plain sides come from the bottom corners and edge, mirrored for the top.
local METAL = {
	cornerLeft = "UI-Frame-Metal-CornerBottomLeft",
	cornerRight = "UI-Frame-Metal-CornerBottomRight",
	edgeHorizontal = "_UI-Frame-Metal-EdgeBottom",
	edgeLeft = "!UI-Frame-Metal-EdgeLeft",
	edgeRight = "!UI-Frame-Metal-EdgeRight",
}
-- How far the frame reaches past the content on each side, in the atlases' own units, so the content's edge meets the
-- inner edge of each band's art, its soft inner shadow included, and nothing of the frame covers the content. Measured
-- on Forever's art: in the 95 x 100 bottom corners the cores run 12.5 to 18.5 from the left, 3 to 8.5 from the right and
-- 7 to 13.5 from the bottom, and the edges' inner shadows reach 3 more at the sides and 2.5 at the bottom. Retail's
-- follows the offsets Blizzard's own layouts differ by between the clients
-- (Blizzard_SharedXML/Camelot/NineSliceLayoutOverrides.lua).
local METAL_REACH = {
	forever = { left = 21.5, right = 11.5, top = 16, bottom = 16 },
	retail = { left = 21.5, right = 13.5, top = 11, bottom = 11 },
}
-- The metal frame's title bar, for a side with information rows: the top corners and top edge cut into three slices
-- from the outer edge (fractions of their height): the outer band, the dark strip that holds the rows and stretches to
-- their height, and the band under the strip with the sides below it. Each slice's own height, in atlas units, and the
-- band under the strip, which also divides two rows. Measured on Forever's art (190 pixels for 95 units).
local TITLE = {
	cornerLeft = "UI-Frame-Metal-CornerTopLeft",
	cornerRight = "UI-Frame-Metal-CornerTopRight",
	edge = "_UI-Frame-Metal-EdgeTop",
	slices = { { 0, 36 / 190 }, { 36 / 190, 73 / 190 }, { 73 / 190, 1 } },
	heights = { 18, 18.5, 58.5 },
	band = { 73 / 190, 82 / 190 },
	bandHeight = 4.5,
}
-- The map's edge meets the inner edge of the band under the strip, its shadow included, this far from the strip.
local TITLE_SEPARATOR = 6
-- The divider between cells in a metal row: the side band cut from the left edge, with its soft shadows (pixels 22 to
-- 40 of 190 across), 9 atlas units wide and tiled down the row's height, so it joins the bands above and below.
local CELL_DIVIDER = { atlas = "!UI-Frame-Metal-EdgeLeft", left = 22 / 190, right = 40 / 190, width = 9 }
-- The Forever styles whose band also divides cells, drawn from a straight stretch of the band's left side: Forever's
-- bevel, light outside and dark inside, matches the light-over-dark separators cut from its top edge.
local BAND_DIVIDERS = { FOREVER_MINIMAL = true, FOREVER = true, SLATE = true }

-- A backdrop edge's size at 100% Border Thickness, and how far it reaches outside the owner, as a share of its size.
local EDGE_SIZE = 16
local EDGE_OUTSET = 0.25
-- How strongly `SetLit` adds a second copy of the art over itself.
local LIT_ALPHA = 0.4

-- Forever Minimal's own band color: at it, the art is drawn as it is.
local ART_COLOR = { r = 132 / 255, g = 105 / 255, b = 82 / 255 }
local SAME = 0.002

---@alias AUIBorderStyle "METAL" | "FOREVER_MINIMAL" | "FOREVER_MINIMAL_SHADED" | "FOREVER" | "SLATE" | "THIN_LINE" | "NONE" | "EDGE"

---@alias AUITextures Texture[]

---@class AUIColor
---@field r number
---@field g number
---@field b number
---@field a number?

---@class AUIBorderLook
---@field style AUIBorderStyle
---@field color AUIColor the band or line color
---@field background AUIColor the owner's fill under Metal, Thin Line and None; the Forever styles bring their own
---@field thickness number? the Metal, Forever and edge styles' size, in percent of Blizzard's
---@field edgeFile string? the backdrop edge file the "EDGE" style draws
---@field top AUIBorderSide? information rows along the owner's top edge, inside it
---@field bottom AUIBorderSide? information rows along its bottom edge

---Information rows along one edge of the owner. The space between them and the rest of the owner, and between two
---rows, is `Border:Gaps` for the style.
---@class AUIBorderSide
---@field height number the rows and the divider between them, from the owner's edge
---@field divider number? where the divider between two rows starts, from the owner's edge

---A frame's border and background. The metal frame and the thin lines are drawn on `over`, which the owner raises above
---its content. The Forever styles' art is drawn either on the owner itself, behind its children, with its own dark
---middle as the background, or, for content that should run under the band, on `over` with its middle cleared. Only
---`over` and the background exist from the start; a style's pieces are made the first time it is applied, and kept.
---@class AUIBorder
---@field owner Frame
---@field overContent boolean the Forever art is drawn above the content, band only
---@field over Frame
---@field background Texture
---@field frameLevel integer? the level `SetFrameLevel` last set
---@field pieces Texture[]? the Forever art in nine pieces: four corners at a fixed size, the edges and middle between
---@field art AUIBorderArt? the Forever art drawn
---@field artScale number? its scale, UI units per texel
---@field thickness number the Metal and Forever styles' size, in percent
---@field metal Frame? the metal frame's pieces
---@field metalCorner { width: number, height: number }? the metal corner atlas's size
---@field metalPieces Texture[]?
---@field metalParts AUIBorderMetal?
---@field style AUIBorderStyle?
---@field top AUIBorderSide?
---@field bottom AUIBorderSide?
---@field rules table<string, table<string, Texture>> per side that has needed them, the Forever band or thin line under
---the rows (`separator`) and between two rows (`divider`)
---@field rowBackgrounds table<string, Texture> per side that has needed one, the Forever art's dark middle behind the rows
---@field lines Texture[]?
local BorderMixin = {}

---@class AUIBorderFactory
---@field STYLES AUIBorderStyle[] in display order
---@field ART_COLOR AUIColor
---@field ART table<string, AUIBorderArt> the Forever styles' art, by style
local Border = {
	STYLES = { "METAL", "FOREVER_MINIMAL", "FOREVER", "SLATE", "THIN_LINE", "NONE" },
	ART_COLOR = ART_COLOR,
	ART = ART,
}
AUI.Border = Border

---@param texelsAcross integer the corner's size along one axis, in texels
---@param outset number texels the art reaches outside the owner
---@param size number the owner's size along that axis
---@param scale number UI units per texel
---@return number scale the scale, or smaller when the owner is too small for two corners at it
function Border:FitScale(texelsAcross, outset, size, scale)
	-- The art spans the owner plus its outset at both edges and must hold two corners: size + 2 * outset * scale >=
	-- 2 * corner * scale.
	if texelsAcross > outset and size > 0 then
		return math.min(scale, size / (2 * texelsAcross - 2 * outset))
	end

	return scale
end

---@param style AUIBorderStyle
---@param thickness number percent
---@return number? width the style's own divider between cells in a row, in the owner's units; nil when the row draws
---a plain line
function Border:CellDividerWidth(style, thickness)
	if style == "METAL" then
		return CELL_DIVIDER.width * thickness / 100
	elseif BAND_DIVIDERS[style] then
		return BAND_WIDTH * ART_SCALE * thickness / 100
	end

	return nil
end

---@param style AUIBorderStyle
---@param thickness number percent
---@param pixel number one screen pixel in the owner's units
---@return number separator the space between a side's information rows and the rest of the owner
---@return number divider the space between two rows on one side
function Border:Gaps(style, thickness, pixel)
	local scale = thickness / 100

	if style == "METAL" then
		return TITLE_SEPARATOR * scale, TITLE.bandHeight * scale
	elseif ART[style] then
		local band = BAND_WIDTH * ART_SCALE * scale

		return band, band
	elseif style == "THIN_LINE" then
		return pixel, pixel
	end

	return 0, 0
end

---A piece of the metal frame, set up as Blizzard's NineSlice does: texture coordinates and tiling first, then the
---atlas. The coordinates are fractions of the atlas, top to bottom; a top greater than the bottom flips it.
---@param parent Frame
---@param atlas string
---@param top number
---@param bottom number
---@param sized boolean? sized to the atlas
---@return Texture
---@return number width the atlas's width
local function MetalPiece(parent, atlas, top, bottom, sized)
	local texture = parent:CreateTexture(nil, "BORDER")
	local info = C_Texture.GetAtlasInfo(atlas)

	texture:SetTexCoord(0, 1, top, bottom)
	texture:SetHorizTile(info ~= nil and info.tilesHorizontally)
	texture:SetVertTile(info ~= nil and info.tilesVertically)

	if info then
		texture:SetAtlas(atlas, sized == true)
	end

	return texture, info and info.width or 0
end

---@class AUIBorderTitle
---@field left Texture[] three slices from the frame's outer edge in
---@field right Texture[]
---@field edge Texture[]
---@field all Texture[]

---The title bar for one side: the top corners and top edge in three slices each, from the frame's outer edge in.
---@param metal Frame
---@param bottom boolean the side below the content, drawn flipped
---@return AUIBorderTitle
local function CreateTitle(metal, bottom)
	local set = { left = {}, right = {}, edge = {}, all = {} }
	local outer, inner = bottom and "BOTTOM" or "TOP", bottom and "TOP" or "BOTTOM"

	for index, slice in ipairs(TITLE.slices) do
		local first, last = slice[1], slice[2]

		if bottom then
			first, last = last, first
		end

		local left, leftWidth = MetalPiece(metal, TITLE.cornerLeft, first, last)
		local right, rightWidth = MetalPiece(metal, TITLE.cornerRight, first, last)
		local edge = MetalPiece(metal, TITLE.edge, first, last)

		left:SetSize(leftWidth, TITLE.heights[index])
		right:SetSize(rightWidth, TITLE.heights[index])

		if index == 1 then
			left:SetPoint(outer .. "LEFT")
			right:SetPoint(outer .. "RIGHT")
		else
			left:SetPoint(outer .. "LEFT", set.left[index - 1], inner .. "LEFT")
			right:SetPoint(outer .. "RIGHT", set.right[index - 1], inner .. "RIGHT")
		end

		edge:SetPoint("TOPLEFT", left, "TOPRIGHT")
		edge:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
		set.left[index], set.right[index], set.edge[index] = left, right, edge
		table.insert(set.all, left)
		table.insert(set.all, right)
		table.insert(set.all, edge)
	end

	return set
end

---The band under the title bar's strip, across the frame, drawn between two rows on one side.
---@param metal Frame
---@param bottom boolean
---@return Texture[] pieces left, middle and right
local function CreateDivider(metal, bottom)
	local first, last = TITLE.band[1], TITLE.band[2]

	if bottom then
		first, last = last, first
	end

	local pieces = {}

	for index, atlas in ipairs({ TITLE.cornerLeft, TITLE.edge, TITLE.cornerRight }) do
		local piece, width = MetalPiece(metal, atlas, first, last)

		piece:SetDrawLayer("BORDER", 1)
		piece:SetSize(width, TITLE.bandHeight)
		pieces[index] = piece
	end

	pieces[2]:SetPoint("TOPLEFT", pieces[1], "TOPRIGHT")
	pieces[2]:SetPoint("BOTTOMRIGHT", pieces[3], "BOTTOMLEFT")

	return pieces
end

---@class AUIBorderMetal
---@field plain table<string, Texture[]> per side, the plain frame's corners and edge: left, right, edge
---@field left Texture
---@field right Texture
---@field titles table<string, AUIBorderTitle> per side
---@field dividers table<string, Texture[]> per side

---@param over Frame
---@return Frame metal
---@return Texture[] pieces
---@return AUIBorderMetal parts
local function CreateMetal(over)
	local metal = CreateFrame("Frame", nil, over)

	local topLeft = MetalPiece(metal, METAL.cornerLeft, 1, 0, true)
	local topRight = MetalPiece(metal, METAL.cornerRight, 1, 0, true)
	local bottomLeft = MetalPiece(metal, METAL.cornerLeft, 0, 1, true)
	local bottomRight = MetalPiece(metal, METAL.cornerRight, 0, 1, true)
	local top = MetalPiece(metal, METAL.edgeHorizontal, 1, 0, true)
	local bottom = MetalPiece(metal, METAL.edgeHorizontal, 0, 1, true)
	local left = MetalPiece(metal, METAL.edgeLeft, 0, 1, true)
	local right = MetalPiece(metal, METAL.edgeRight, 0, 1, true)

	topLeft:SetPoint("TOPLEFT")
	topRight:SetPoint("TOPRIGHT")
	bottomLeft:SetPoint("BOTTOMLEFT")
	bottomRight:SetPoint("BOTTOMRIGHT")
	top:SetPoint("TOPLEFT", topLeft, "TOPRIGHT")
	top:SetPoint("TOPRIGHT", topRight, "TOPLEFT")
	bottom:SetPoint("BOTTOMLEFT", bottomLeft, "BOTTOMRIGHT")
	bottom:SetPoint("BOTTOMRIGHT", bottomRight, "BOTTOMLEFT")

	local parts = {
		plain = { top = { topLeft, topRight, top }, bottom = { bottomLeft, bottomRight, bottom } },
		left = left,
		right = right,
		titles = { top = CreateTitle(metal, false), bottom = CreateTitle(metal, true) },
		dividers = { top = CreateDivider(metal, false), bottom = CreateDivider(metal, true) },
	}
	local pieces = { topLeft, topRight, bottomLeft, bottomRight, top, bottom, left, right }

	for _, title in pairs(parts.titles) do
		for _, piece in ipairs(title.all) do
			pieces[#pieces + 1] = piece
		end
	end

	for _, divider in pairs(parts.dividers) do
		for _, piece in ipairs(divider) do
			pieces[#pieces + 1] = piece
		end
	end

	return metal, pieces, parts
end

---Makes the Forever art's nine pieces. `PlaceArt` places and sizes the corners; each edge and the middle are anchored
---between corners once, so they follow them.
---@param parent Frame
---@return Texture[]
local function CreateArtPieces(parent)
	local pieces = {}

	for index, cell in ipairs(PIECES) do
		local piece = parent:CreateTexture(nil, "BORDER")

		piece:SetSnapToPixelGrid(false)
		piece:SetTexelSnappingBias(0)
		piece.row, piece.column = cell[1], cell[2]
		pieces[index] = piece
	end

	local topLeft, topRight, bottomLeft, bottomRight = pieces[1], pieces[2], pieces[3], pieces[4]

	pieces[5]:SetPoint("TOPLEFT", topLeft, "TOPRIGHT")
	pieces[5]:SetPoint("BOTTOMRIGHT", topRight, "BOTTOMLEFT")
	pieces[6]:SetPoint("TOPLEFT", bottomLeft, "TOPRIGHT")
	pieces[6]:SetPoint("BOTTOMRIGHT", bottomRight, "BOTTOMLEFT")
	pieces[7]:SetPoint("TOPLEFT", topLeft, "BOTTOMLEFT")
	pieces[7]:SetPoint("BOTTOMRIGHT", bottomLeft, "TOPRIGHT")
	pieces[8]:SetPoint("TOPLEFT", topRight, "BOTTOMLEFT")
	pieces[8]:SetPoint("BOTTOMRIGHT", bottomRight, "TOPRIGHT")
	pieces[9]:SetPoint("TOPLEFT", topLeft, "BOTTOMRIGHT")
	pieces[9]:SetPoint("BOTTOMRIGHT", bottomRight, "TOPLEFT")

	return pieces
end

---@param over Frame
---@return table<string, Texture> rules the band or line under one side's rows and between two of them
local function CreateRules(over)
	local rules = {}

	for _, name in ipairs({ "separator", "divider" }) do
		local rule = over:CreateTexture(nil, "BORDER", nil, -1)

		rule:SetSnapToPixelGrid(false)
		rule:SetTexelSnappingBias(0)
		rule:Hide()
		rules[name] = rule
	end

	return rules
end

---@param over Frame
---@return Texture[] lines top, bottom, left and right
local function CreateLines(over)
	local lines = {}

	for index, points in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
		{ "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
		local line = over:CreateTexture(nil, "BORDER")

		line:SetColorTexture(1, 1, 1, 1)
		line:SetSnapToPixelGrid(false)
		line:SetTexelSnappingBias(0)
		line:SetPoint(points[1])
		line:SetPoint(points[2])
		line.horizontal = index <= 2
		lines[index] = line
	end

	return lines
end

---@param owner Frame the bordered frame; its size is the content's
---@param overContent boolean? draw the Forever art above the content, band only, so the content runs under the band
---@return AUIBorder
function Border:Create(owner, overContent)
	local border = Mixin({ owner = owner, overContent = overContent == true, thickness = 100, rules = {},
		rowBackgrounds = {} }, BorderMixin)
	local over = CreateFrame("Frame", nil, owner)

	over:SetAllPoints()
	border.over = over

	border.background = owner:CreateTexture(nil, "BACKGROUND")
	border.background:SetAllPoints()

	over:SetScript("OnSizeChanged", function()
		border:Layout()
	end)

	return border
end

---Places what the current style draws and depends on the owner's size or position: the Forever art, the metal frame's
---scale or the thin lines' pixel width. Called when the owner is resized and after it is moved.
function BorderMixin:Layout()
	local width, height = self.owner:GetSize()
	local art = self.art

	if art then
		local scale = ART_SCALE * self.thickness / 100

		scale = Border:FitScale(art.across, art.outset, width, scale)
		scale = Border:FitScale(art.down, art.outset, height, scale)
		self.artScale = scale
		self:PlaceArt()
	end

	if self.style == "METAL" then
		local reach = AUI.can.foreverArt and METAL_REACH.forever or METAL_REACH.retail
		local metal, top, bottom, corner = self.metal --[[@as Frame]], self.top, self.bottom, self.metalCorner
		local scale = self.thickness / 100

		-- A frame too small for two of the metal corners at this scale draws them smaller, as the Forever art does.
		if corner and not (top or bottom) then
			scale = Border:FitScale(corner.width, (reach.left + reach.right) / 2, width, scale)
			scale = Border:FitScale(corner.height, (reach.top + reach.bottom) / 2, height, scale)
		end

		metal:SetScale(scale)
		metal:ClearAllPoints()
		metal:SetPoint("TOPLEFT", self.owner, "TOPLEFT", -reach.left, top and TITLE.heights[1] or reach.top)
		metal:SetPoint("BOTTOMRIGHT", self.owner, "BOTTOMRIGHT", reach.right, -(bottom and TITLE.heights[1] or reach.bottom))
		self:LayoutMetal(scale)
	end

	local pixel = AUI:Pixel(self.owner)

	self:LayoutRows(pixel)

	if self.style == "THIN_LINE" then
		for _, line in ipairs(self.lines) do
			if line.horizontal then
				line:SetHeight(pixel)
			else
				line:SetWidth(pixel)
			end
		end
	end
end

---Shows the plain frame or the title bar on each side and anchors the sides' edges between them.
---@param scale number the metal frame's scale
function BorderMixin:LayoutMetal(scale)
	local parts = self.metalParts --[[@as AUIBorderMetal]]

	for _, side in ipairs({ "top", "bottom" }) do
		local rows, title, divider = self[side], parts.titles[side], parts.dividers[side]

		for _, piece in ipairs(parts.plain[side]) do
			piece:SetShown(rows == nil)
		end

		for _, piece in ipairs(title.all) do
			piece:SetShown(rows ~= nil)
		end

		for _, piece in ipairs(divider) do
			piece:SetShown(rows ~= nil and rows.divider ~= nil)
		end

		if rows then
			title.left[2]:SetHeight(rows.height / scale)
			title.right[2]:SetHeight(rows.height / scale)
		end

		if rows and rows.divider then
			local outer = side == "top" and "TOP" or "BOTTOM"
			local offset = (TITLE.heights[1] + rows.divider / scale) * (side == "top" and -1 or 1)

			divider[1]:ClearAllPoints()
			divider[1]:SetPoint(outer .. "LEFT", self.metal, outer .. "LEFT", 0, offset)
			divider[3]:ClearAllPoints()
			divider[3]:SetPoint(outer .. "RIGHT", self.metal, outer .. "RIGHT", 0, offset)
		end
	end

	local top = self.top and parts.titles.top or nil
	local bottom = self.bottom and parts.titles.bottom or nil

	parts.left:ClearAllPoints()
	parts.left:SetPoint("TOPLEFT", top and top.left[3] or parts.plain.top[1], "BOTTOMLEFT")
	parts.left:SetPoint("BOTTOMLEFT", bottom and bottom.left[3] or parts.plain.bottom[1], "TOPLEFT")
	parts.right:ClearAllPoints()
	parts.right:SetPoint("TOPRIGHT", top and top.right[3] or parts.plain.top[2], "BOTTOMRIGHT")
	parts.right:SetPoint("BOTTOMRIGHT", bottom and bottom.right[3] or parts.plain.bottom[2], "TOPRIGHT")
end

---Places what information rows add under the Forever and Thin Line styles: the band or line between the rows and the
---rest of the owner and between two rows, and, for the Forever styles, the art's dark middle behind the rows, with the
---background color kept to the rest of the owner.
---@param pixel number
function BorderMixin:LayoutRows(pixel)
	local owner, art = self.owner, self.art
	local separator, dividerGap = Border:Gaps(self.style or "NONE", self.thickness, pixel)
	local ruled = art ~= nil or self.style == "THIN_LINE"
	-- The Forever band reaches under the side bands, past the sub-texel gap between them and the owner's edge.
	local extend = art and (self.artScale or ART_SCALE) or 0

	for _, side in ipairs({ "top", "bottom" }) do
		local rows, rules, background = self[side], self.rules[side], self.rowBackgrounds[side]
		local outer = side == "top" and "TOP" or "BOTTOM"
		local direction = side == "top" and -1 or 1

		local function Place(region, offset, size, reach)
			region:ClearAllPoints()
			region:SetPoint(outer .. "LEFT", owner, outer .. "LEFT", -reach, direction * offset)
			region:SetPoint(outer .. "RIGHT", owner, outer .. "RIGHT", reach, direction * offset)
			region:SetHeight(size)
		end

		if rules then
			rules.separator:SetShown(ruled and rows ~= nil)
			rules.divider:SetShown(ruled and rows ~= nil and rows.divider ~= nil)

			if rows then
				Place(rules.separator, rows.height, separator, extend)

				if rows.divider then
					Place(rules.divider, rows.divider, dividerGap, extend)
				end
			end
		end

		if background then
			background:SetShown(art ~= nil and rows ~= nil)

			if rows then
				Place(background, 0, rows.height, 0)
			end
		end
	end

	local top, bottom = self.top, self.bottom

	self.background:ClearAllPoints()
	self.background:SetPoint("TOPLEFT", owner, "TOPLEFT", 0, art and top and -(top.height + separator) or 0)
	self.background:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", 0, art and bottom and bottom.height + separator or 0)
end

---Places the Forever art's corners around the owner: each its texels times the art's scale, the art's outside where
---its band's outer edge falls on a whole screen pixel, about the outset from the owner's edge.
function BorderMixin:PlaceArt()
	local owner, art = self.owner, self.art --[[@as AUIBorderArt]]
	local scale = self.artScale or ART_SCALE
	local outset = art.outset * scale
	local pixel = AUI:Pixel(owner)
	local left, right, top, bottom = owner:GetLeft(), owner:GetRight(), owner:GetTop(), owner:GetBottom()

	-- How far each side of the art reaches past the owner's edge, in the owner's units.
	local reach = { left = outset, right = outset, top = outset, bottom = outset }

	if left and right and top and bottom and pixel > 0 then
		local inset = art.bandStart * scale
		local band = outset - inset

		local function Snap(position)
			return math.floor(position / pixel + 0.5) * pixel
		end

		reach.left = left - (Snap(left - band) - inset)
		reach.right = Snap(right + band) + inset - right
		reach.top = Snap(top + band) + inset - top
		reach.bottom = bottom - (Snap(bottom - band) - inset)
	end

	local width, height = art.across * scale, art.down * scale

	for index = 1, 4 do
		local piece = (self.pieces --[[@as AUITextures]])[index]
		local onLeft, onTop = piece.column == 1, piece.row == 1
		local point = (onTop and "TOP" or "BOTTOM") .. (onLeft and "LEFT" or "RIGHT")

		piece:ClearAllPoints()
		piece:SetPoint(point, owner, point, onLeft and -reach.left or reach.right, onTop and reach.top or -reach.bottom)
		piece:SetSize(width, height)
	end
end

---Sets each piece's part of the art: the corners, and the edges and middle from between them or, for art uniform along
---its edges, from a strip one texel long through its middle.
function BorderMixin:SetArtCoords()
	local art = self.art --[[@as AUIBorderArt]]
	local size = art.size

	local function Bounds(corner)
		local middle = art.strip and { size / 2 - 0.5, size / 2 + 0.5 } or { corner, size - corner }

		return { { 0, corner }, middle, { size - corner, size } }
	end

	local columns, rows = Bounds(art.across), Bounds(art.down)

	for _, piece in ipairs(self.pieces) do
		local column, row = columns[piece.column], rows[piece.row]

		piece:SetTexCoord(column[1] / size, column[2] / size, row[1] / size, row[2] / size)
	end
end

---Puts the metal frame, the Forever band and the thin lines on one frame level, above the owner's content. No style
---draws on both `over` and the metal frame, so they share it.
---@param level integer
function BorderMixin:SetFrameLevel(level)
	self.frameLevel = level
	self.over:SetFrameLevel(level)

	if self.metal then
		self.metal:SetFrameLevel(level)
	end

	if self.edge then
		self.edge:SetFrameLevel(level + 1)
	end
end

---@param color AUIColor
---@return number r
---@return number g
---@return number b
---@return number a
local function Unpack(color)
	return color.r or 1, color.g or 1, color.b or 1, color.a or 1
end

---@param color AUIColor
---@return boolean
local function IsArtColor(color)
	return math.abs((color.r or 1) - ART_COLOR.r) <= SAME and math.abs((color.g or 1) - ART_COLOR.g) <= SAME
		and math.abs((color.b or 1) - ART_COLOR.b) <= SAME
end

---Colors a set of textures: a gray copy takes a chosen color cleanly, where multiplying the colored art would muddy it;
---at the art's own color, or when `tintable` is false, they are drawn as made.
---@param textures Texture[]
---@param color AUIColor
---@param tintable boolean
local function Tint(textures, color, tintable, always)
	local tint = tintable and (always or not IsArtColor(color))

	for _, texture in ipairs(textures) do
		texture:SetDesaturated(tint)

		if tint then
			texture:SetVertexColor(Unpack(color))
		else
			texture:SetVertexColor(1, 1, 1, 1)
		end
	end
end

---Draws a texture as the style's divider between cells in a row. Returns false, leaving the texture alone, when the
---style has none and the row draws a plain line.
---@param texture Texture
---@param style AUIBorderStyle
---@param color AUIColor
---@return boolean drawn
function Border:StyleCellDivider(texture, style, color)
	local art = ART[style]

	if art and BAND_DIVIDERS[style] then
		local size = art.size

		texture:SetTexture(art.band)
		texture:SetTexCoord(art.bandStart / size, (art.bandStart + BAND_WIDTH) / size, (size / 2 - 0.5) / size,
			(size / 2 + 0.5) / size)
		texture:SetHorizTile(false)
		texture:SetVertTile(false)
		Tint({ texture }, color, art.tinted == true)

		return true
	end

	if style ~= "METAL" then
		return false
	end

	local info = C_Texture.GetAtlasInfo(CELL_DIVIDER.atlas)

	texture:SetTexCoord(CELL_DIVIDER.left, CELL_DIVIDER.right, 0, 1)
	texture:SetHorizTile(false)
	texture:SetVertTile(info ~= nil and info.tilesVertically)

	if info then
		texture:SetAtlas(CELL_DIVIDER.atlas)
	end

	Tint({ texture }, color, true)

	return true
end

---Textures the rows' bands, lines and backgrounds for the style: the Forever band from a straight stretch of its top
---edge and the dark middle from the art's center, or a plain color for Thin Line.
---@param art AUIBorderArt?
---@param color AUIColor
function BorderMixin:ApplyRows(art, color)
	local rules = {}

	for _, side in ipairs({ "top", "bottom" }) do
		if self[side] and (art or self.style == "THIN_LINE") and not self.rules[side] then
			self.rules[side] = CreateRules(self.over)
		end

		if self[side] and art and not self.rowBackgrounds[side] then
			self.rowBackgrounds[side] = self.owner:CreateTexture(nil, "BACKGROUND", nil, 1)
		end

		for _, rule in pairs(self.rules[side] or {}) do
			rules[#rules + 1] = rule
		end
	end

	if art then
		local size = art.size
		local first, last = (size / 2 - 0.5) / size, (size / 2 + 0.5) / size

		for _, rule in ipairs(rules) do
			rule:SetTexture(art.band)
			rule:SetTexCoord(first, last, art.bandStart / size, (art.bandStart + BAND_WIDTH) / size)
		end

		Tint(rules, color, art.tinted == true)

		for _, background in pairs(self.rowBackgrounds) do
			background:SetTexture(art.file)
			background:SetTexCoord(first, last, first, last)
		end
	else
		for _, rule in ipairs(rules) do
			rule:SetColorTexture(1, 1, 1, 1)
			rule:SetDesaturated(false)
			rule:SetVertexColor(Unpack(color))
		end
	end
end

---@param look AUIBorderLook
function BorderMixin:Apply(look)
	local art = ART[look.style]
	local metal = look.style == "METAL"

	self.art = art
	self.style = look.style
	self.thickness = look.thickness or 100
	self.top, self.bottom = look.top, look.bottom
	self.color = look.color

	-- The Forever styles bring their own middle; the background color fills the owner's rectangle under the others.
	-- Above the content the art has no middle, and the content covers the owner.
	self.background:SetColorTexture(Unpack(look.background))
	self.background:SetShown(art == nil or self.overContent)

	if art and not self.pieces then
		self.pieces = CreateArtPieces(self.overContent and self.over or self.owner)
	end

	for _, piece in ipairs(self.pieces or {}) do
		piece:SetShown(art ~= nil)

		if art then
			piece:SetTexture(self.overContent and art.band or art.file)
		end
	end

	if art then
		Tint(self.pieces --[[@as AUITextures]], look.color, art.tinted == true, art.white)
		self:SetArtCoords()
	end

	if metal and not self.metal then
		self.metal, self.metalPieces, self.metalParts = CreateMetal(self.over)
		self.metalCorner = C_Texture.GetAtlasInfo(METAL.cornerLeft)

		if self.frameLevel then
			self.metal:SetFrameLevel(self.frameLevel)
		end
	end

	if self.metal then
		self.metal:SetShown(metal)
	end

	if metal then
		Tint(self.metalPieces --[[@as AUITextures]], look.color, true)
	end

	local thin = look.style == "THIN_LINE"

	if thin and not self.lines then
		self.lines = CreateLines(self.over)
	end

	if self.lines then
		local r, g, b, a = Unpack(look.color)

		for _, line in ipairs(self.lines) do
			line:SetVertexColor(r, g, b, a)
			line:SetShown(thin)
		end
	end

	self:ApplyEdge(look)
	self:ApplyRows(art, look.color)
	self:SetLit(false)

	self:Layout()
end

---Draws the "EDGE" style, a backdrop edge around the owner, in a frame made the first time it is needed.
---@param look AUIBorderLook
function BorderMixin:ApplyEdge(look)
	local edge = self.edge
	local shown = look.style == "EDGE" and look.edgeFile ~= nil

	if shown and not edge then
		edge = CreateFrame("Frame", nil, self.over, "BackdropTemplate")
		edge:SetFrameLevel(self.over:GetFrameLevel() + 1)
		self.edge = edge
	end

	if not edge then
		return
	end

	edge:SetShown(shown)

	if shown then
		local size = EDGE_SIZE * self.thickness / 100
		local outset = size * EDGE_OUTSET

		edge:ClearAllPoints()
		edge:SetPoint("TOPLEFT", self.owner, "TOPLEFT", -outset, outset)
		edge:SetPoint("BOTTOMRIGHT", self.owner, "BOTTOMRIGHT", outset, -outset)
		edge:SetBackdrop({ edgeFile = look.edgeFile, edgeSize = size })
		edge:SetBackdropBorderColor(Unpack(look.color))
	end
end

---Changes the color the style draws in, until the next `Apply`, without laying anything out.
---@param color AUIColor
function BorderMixin:SetColor(color)
	local art = self.art

	self.color = color

	if art then
		Tint(self.pieces --[[@as AUITextures]], color, art.tinted == true, art.white)
	end

	if self.style == "METAL" then
		Tint(self.metalPieces --[[@as AUITextures]], color, true)
	end

	local r, g, b, a = Unpack(color)

	if self.style == "THIN_LINE" then
		for _, line in ipairs(self.lines) do
			line:SetVertexColor(r, g, b, a)
		end
	end

	if self.edge and self.edge:IsShown() then
		self.edge:SetBackdropBorderColor(r, g, b, a)
	end
end

---Lightens art that cannot simply be tinted lighter by adding a second copy over itself, which keeps its hue and shading where a tint
---would multiply them darker. The copy is made the first time it is needed. Other styles have no art to light.
---@param lit boolean
function BorderMixin:SetLit(lit)
	local art = self.art
	local glow = self.glow

	if not lit or not art then
		if glow then
			for _, piece in ipairs(glow) do
				piece:Hide()
			end
		end

		return
	end

	if not glow then
		glow = {}

		local parent = self.overContent and self.over or self.owner

		for index, piece in ipairs(self.pieces) do
			local copy = parent:CreateTexture(nil, "BORDER", nil, 1)

			copy:SetAllPoints(piece)
			copy:SetBlendMode("ADD")
			copy:SetAlpha(LIT_ALPHA)
			copy:SetSnapToPixelGrid(false)
			copy:SetTexelSnappingBias(0)
			glow[index] = copy
		end

		self.glow = glow
	end

	for index, copy in ipairs(glow) do
		copy:SetTexture(self.overContent and art.band or art.file)
		copy:SetTexCoord((self.pieces --[[@as AUITextures]])[index]:GetTexCoord())
		copy:Show()
	end

	Tint(glow, self.color, art.tinted == true)
end
