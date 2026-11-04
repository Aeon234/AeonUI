-- Checks AUI.Border outside the game: what each style builds and when, pieces kept and hidden across style changes,
-- levels, rows, and the widget calls a color change makes.
-- Run from any directory with Lua 5.1: lua Tools/check_border.lua
-- Loads the real file against strict widget stubs, which fail on a method the widget type lacks. It proves the logic,
-- not the drawing.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

local checks = 0

local function Equal(name, actual, expected)
	checks = checks + 1
	if actual ~= expected then
		io.stderr:write(("FAIL: %s: expected %s, got %s\n"):format(name, tostring(expected), tostring(actual)))
		os.exit(1)
	end
end

-- Environment ---------------------------------------------------------------------------------------------

local counts = { frames = 0, textures = 0, calls = 0 }

-- Records a method's call, so a check can count the widget calls an operation makes.
local function Method(body)
	return function(self, ...)
		counts.calls = counts.calls + 1
		if body then
			return body(self, ...)
		end
	end
end

local Region = {
	SetPoint = Method(function(self)
		self.anchored = true
	end),
	SetAllPoints = Method(function(self)
		self.anchored = true
	end),
	ClearAllPoints = Method(function(self)
		self.anchored = false
	end),
	SetShown = Method(function(self, shown)
		self.shown = shown == true
	end),
	Show = Method(function(self)
		self.shown = true
	end),
	Hide = Method(function(self)
		self.shown = false
	end),
	IsShown = function(self)
		return self.shown
	end,
	SetSize = Method(),
	SetWidth = Method(function(self, width)
		self.width = width
	end),
	SetHeight = Method(function(self, height)
		self.height = height
	end),
}

local Texture = setmetatable({
	SetSnapToPixelGrid = Method(),
	SetTexelSnappingBias = Method(),
	SetTexture = Method(function(self, file)
		self.file = file
	end),
	SetColorTexture = Method(),
	SetTexCoord = Method(function(self, ...)
		self.coords = { ... }
	end),
	GetTexCoord = function(self)
		return unpack(self.coords)
	end,
	SetDesaturated = Method(function(self, desaturated)
		self.desaturated = desaturated
	end),
	SetVertexColor = Method(function(self, r)
		self.red = r
	end),
	SetHorizTile = Method(),
	SetVertTile = Method(),
	SetAtlas = Method(),
	SetDrawLayer = Method(),
	SetBlendMode = Method(),
	SetAlpha = Method(),
}, { __index = Region })
Texture.__index = function(_, key)
	return Texture[key] or error("a texture has no " .. tostring(key))
end

local Frame = setmetatable({
	SetFrameLevel = Method(function(self, level)
		self.level = level
	end),
	GetFrameLevel = function(self)
		return self.level
	end,
	SetScale = Method(function(self, scale)
		self.scale = scale
	end),
	SetScript = Method(function(self, name, script)
		self.scripts[name] = script
	end),
	GetSize = function(self)
		return self.frameWidth, self.frameHeight
	end,
	GetLeft = function()
		return 100
	end,
	GetRight = function()
		return 300
	end,
	GetTop = function()
		return 300
	end,
	GetBottom = function()
		return 260
	end,
	SetBackdrop = Method(function(self, backdrop)
		self.backdrop = backdrop
	end),
	SetBackdropBorderColor = Method(),
	CreateTexture = function(self)
		counts.textures = counts.textures + 1

		return setmetatable({ parent = self, shown = true }, Texture)
	end,
}, { __index = Region })
Frame.__index = function(_, key)
	return Frame[key] or error("a frame has no " .. tostring(key))
end

function CreateFrame(_, _, parent, template)
	counts.frames = counts.frames + 1

	return setmetatable({ parent = parent, template = template, shown = true, scripts = {}, level = 1, frameWidth = 200,
		frameHeight = 40 }, Frame)
end

function Mixin(object, ...)
	for index = 1, select("#", ...) do
		for key, value in pairs((select(index, ...))) do
			object[key] = value
		end
	end

	return object
end

C_Texture = {
	GetAtlasInfo = function()
		return { width = 95, height = 100, tilesHorizontally = false, tilesVertically = false }
	end,
}

local AUI = {
	name = "AeonUI",
	can = {},
	Pixel = function()
		return 0.5
	end,
}

assert(loadfile(root .. "AeonUI/UI/Border.lua"))("AeonUI", AUI)

local Border = AUI.Border
local GRAY = { r = 0.5, g = 0.5, b = 0.5, a = 1 }
local CLEAR = { r = 0, g = 0, b = 0, a = 0 }

local function Look(style, extra)
	local look = { style = style, color = GRAY, background = CLEAR }

	for key, value in pairs(extra or {}) do
		look[key] = value
	end

	return look
end

---@return table border
---@return integer frames made since the owner
---@return integer textures made
local function Fresh(overContent)
	local owner = CreateFrame("Frame")

	counts.frames, counts.textures = 0, 0

	return Border:Create(owner, overContent)
end

local function AllHidden(textures)
	for _, texture in ipairs(textures) do
		if texture.shown then
			return false
		end
	end

	return true
end

-- Nothing up front ----------------------------------------------------------------------------------------

local border = Fresh(true)
Equal("a new border makes one frame", counts.frames, 1)
Equal("and its background", counts.textures, 1)
Equal("no art", border.pieces, nil)
Equal("no metal", border.metal, nil)
Equal("no lines", border.lines, nil)
Equal("no rules", next(border.rules), nil)
Equal("no row backgrounds", next(border.rowBackgrounds), nil)
border.over.scripts.OnSizeChanged()
Equal("a resize before any style makes nothing", counts.textures, 1)

border:Apply(Look("NONE"))
Equal("None makes nothing", counts.textures, 1)

-- Art ------------------------------------------------------------------------------------------------------

border = Fresh(true)
border:Apply(Look("FOREVER_MINIMAL_SHADED"))
Equal("the art makes its nine pieces", counts.textures, 10)
Equal("and no other frame", counts.frames, 1)
Equal("no metal beside it", border.metal, nil)
Equal("no lines beside it", border.lines, nil)
Equal("no rules without rows", next(border.rules), nil)
Equal("above the content on over", border.pieces[1].parent, border.over)
Equal("in its band art", border.pieces[1].file, border.pieces[9].file)

counts.calls = 0
border:SetColor({ r = 0.7, g = 0.7, b = 0.7 })
Equal("a color change touches only the art", counts.calls, 18)
Equal("and colors it", border.pieces[1].red, 0.7)

local colored = Fresh(true)

colored:Apply(Look("FOREVER"))
colored:SetColor({ r = 0.7 })
Equal("art with its own colors keeps them", colored.pieces[1].desaturated, false)
colored:SetColor({ r = 0.7 }, true)
Equal("unless the color is forced", colored.pieces[1].desaturated, true)
Equal("in that color", colored.pieces[1].red, 0.7)
colored:SetColor({ r = 0.2 })
Equal("and it comes back", colored.pieces[1].desaturated, false)

local behind = Fresh(false)
behind:Apply(Look("FOREVER"))
Equal("behind the content on the owner", behind.pieces[1].parent, behind.owner)

-- Metal ----------------------------------------------------------------------------------------------------

border = Fresh(true)
border:SetFrameLevel(7)
border:Apply(Look("METAL"))
Equal("Metal makes its pieces", counts.textures, 33)
Equal("and its frame", counts.frames, 2)
Equal("at the level already asked for", border.metal.level, 7)
Equal("placed", border.metal.anchored, true)
Equal("scaled", border.metal.scale ~= nil, true)
Equal("no art beside it", border.pieces, nil)

border:SetFrameLevel(9)
Equal("a later level reaches it", border.metal.level, 9)

local metal = border.metal
local scale = metal.scale
border:Apply(Look("FOREVER_MINIMAL_SHADED"))
Equal("switching away hides it", metal.shown, false)
Equal("and keeps it", border.metal, metal)
metal.scale = "untouched"
border:Layout()
Equal("a hidden metal frame is not laid out", metal.scale, "untouched")
counts.calls = 0
border:SetColor(GRAY)
Equal("nor colored", counts.calls, 18)

local made = counts.textures
border:Apply(Look("METAL"))
Equal("switching back shows it", metal.shown, true)
Equal("makes nothing new", counts.textures, made)
Equal("and lays it out again", metal.scale, scale)
Equal("the art hides", AllHidden(border.pieces), true)
counts.calls = 0
border:SetColor(GRAY)
Equal("a color change reaches the metal pieces", counts.calls > 18, true)

-- Thin Line ------------------------------------------------------------------------------------------------

border = Fresh(true)
border:Apply(Look("THIN_LINE"))
Equal("Thin Line makes four lines", counts.textures, 5)
Equal("shown", border.lines[1].shown, true)
Equal("one pixel tall", border.lines[1].height, 0.5)
Equal("one pixel wide", border.lines[3].width, 0.5)
border:SetColor({ r = 0.2 })
Equal("a color change colors them", border.lines[1].red, 0.2)

local lines = border.lines
border:Apply(Look("NONE"))
Equal("switching away hides them", AllHidden(lines), true)
lines[1].height = "untouched"
border:Layout()
Equal("hidden lines are not laid out", lines[1].height, "untouched")
lines[1].red = "untouched"
border:SetColor(GRAY)
Equal("nor colored by a color change", lines[1].red, "untouched")

-- Rows -----------------------------------------------------------------------------------------------------

local ROWS = { height = 20, divider = 10 }

border = Fresh(true)
border:Apply(Look("FOREVER", { top = ROWS }))
Equal("rows under art make that side's rules", border.rules.top ~= nil and border.rules.bottom == nil, true)
Equal("and its background", border.rowBackgrounds.top ~= nil and border.rowBackgrounds.bottom == nil, true)
Equal("the separator shows", border.rules.top.separator.shown, true)
Equal("the divider shows", border.rules.top.divider.shown, true)
Equal("the background shows", border.rowBackgrounds.top.shown, true)
Equal("the background takes the art's middle", border.rowBackgrounds.top.file, border.pieces[1] and
	Border.ART.FOREVER.file)

local top = border.rules.top
border:Apply(Look("FOREVER", { top = { height = 20 } }))
Equal("one row hides the divider", top.divider.shown, false)
Equal("and keeps the separator", top.separator.shown, true)

border:Apply(Look("FOREVER"))
Equal("no rows hides the rules", top.separator.shown, false)
Equal("and the background", border.rowBackgrounds.top.shown, false)

border:Apply(Look("METAL", { top = ROWS }))
Equal("Metal's own title bar leaves them hidden", top.separator.shown, false)
Equal("and the background too", border.rowBackgrounds.top.shown, false)

local plain = Fresh(true)
plain:Apply(Look("METAL", { bottom = ROWS }))
Equal("rows under Metal make no rules", plain.rules.bottom, nil)
Equal("and no background", plain.rowBackgrounds.bottom, nil)
Equal("the title bar is shown instead", plain.metalParts.titles.bottom.left[1].shown, true)

plain = Fresh(true)
plain:Apply(Look("NONE", { top = ROWS }))
Equal("rows under None make nothing", counts.textures, 1)

plain = Fresh(true)
plain:Apply(Look("THIN_LINE", { top = ROWS }))
Equal("rows under Thin Line make rules", plain.rules.top ~= nil, true)
Equal("and no background", plain.rowBackgrounds.top, nil)

-- Edge and lit art -----------------------------------------------------------------------------------------

border = Fresh(true)
border:Apply(Look("EDGE", { edgeFile = "edge file" }))
Equal("an edge makes one frame more", counts.frames, 2)
Equal("from the backdrop template", border.edge.template, "BackdropTemplate")
Equal("and no pieces", counts.textures, 1)
border:Apply(Look("NONE"))
Equal("switching away hides it", border.edge.shown, false)

border = Fresh(true)
border:Apply(Look("FOREVER"))
Equal("no lit copy until it is asked for", border.glow, nil)
border:SetLit(true)
Equal("the lit copy makes nine more", counts.textures, 19)
border:Apply(Look("NONE"))
Equal("switching away hides it", AllHidden(border.glow), true)
border:SetLit(true)
Equal("a style with no art lights nothing", AllHidden(border.glow), true)

-- Shadows ----------------------------------------------------------------------------------------------------

local added = {}
local library = {
	AddShadow = function(_, owner, options)
		local shadow = added[owner] or { Show = function(self) self.shown = true end,
			Hide = function(self) self.shown = false end }

		shadow.options, shadow.calls = options, (shadow.calls or 0) + 1
		added[owner] = shadow

		return shadow
	end,
}

function LibStub(name)
	assert(name == "LibAeonSettings-1.0")

	return library
end

local SHADOW = { size = 4, color = Border.SHADOW_COLOR }

-- Never enabled: nothing is made, for any style.
for _, style in ipairs({ "METAL", "FOREVER_MINIMAL", "FOREVER", "SLATE", "THIN_LINE", "NONE" }) do
	border = Fresh(true)
	border:Apply(Look(style))
	Equal(style .. " off makes no shadow pieces", border.shadowPieces, nil)
	Equal(style .. " off asks the library for nothing", border.square, nil)
	Equal(style .. " off makes no holder", border.shadowHost, nil)
	border:SetShadowShown(false)
end

-- A style with art of its own draws its glow, on, off and on again, reusing its pieces.
for style, file in pairs({ FOREVER = "ForeverShadow-4.tga", FOREVER_MINIMAL = "ForeverMinimalShadow-4.tga",
	FOREVER_MINIMAL_SHADED = "ForeverMinimalShadow-4.tga" }) do
	border = Fresh(true)
	border:Apply(Look(style, { shadow = SHADOW }))
	Equal(style .. " makes eight pieces", #border.shadowPieces, 8)
	Equal(style .. " draws its own file", border.shadowPieces[1].file:match("[^\\]+$"), file)
	Equal(style .. " needs no square shadow", border.square, nil)
	local first = border.shadowPieces[1]
	border:Apply(Look(style))
	Equal(style .. " off hides it", AllHidden(border.shadowPieces), true)
	border:Apply(Look(style, { shadow = SHADOW }))
	Equal(style .. " on again reuses it", border.shadowPieces[1], first)
	Equal(style .. " on again shows it", first.shown, true)
end

-- A size takes the nearest built file.
border = Fresh(true)
border:Apply(Look("FOREVER", { shadow = { size = 7, color = Border.SHADOW_COLOR } }))
Equal("size 7 takes a built file", border.shadowSize, 6)
border:Apply(Look("FOREVER", { shadow = { size = 10, color = Border.SHADOW_COLOR } }))
Equal("the largest", border.shadowSize, 10)

-- The other styles use the library's square shadow, below the owner, out to the band.
border = Fresh(true)
border:Apply(Look("THIN_LINE", { shadow = SHADOW }))
Equal("Thin Line has a square shadow", border.square.shown, true)
Equal("one level under its owner", border.shadowHost.level, border.owner:GetFrameLevel() - 1)
border:SetShadowShown(false)
Equal("hiding it hides its holder", border.shadowHost.shown, false)
border:Apply(Look("THIN_LINE", { shadow = SHADOW }))
Equal("and a new look leaves it hidden", border.shadowHost.shown, false)
border:SetShadowShown(true)
Equal("showing it shows its holder", border.shadowHost.shown, true)
Equal("reaching nothing past the owner", border.square.options.extend.left, 0)
border:Layout()
local calls = border.square.calls
border:Layout()
Equal("laying out unchanged redraws nothing", border.square.calls, calls)
border:Apply(Look("THIN_LINE"))
Equal("off hides it", border.square.shown, false)
border:Apply(Look("THIN_LINE", { shadow = SHADOW }))
Equal("on again shows it", border.square.shown, true)

border = Fresh(true)
border:Apply(Look("SLATE", { shadow = SHADOW }))
Equal("Slate reaches to its band", border.square.options.extend.top, 2.25)

border = Fresh(true)
border:Apply(Look("METAL", { shadow = SHADOW }))
Equal("Metal reaches to its band, at its scale", border.square.options.extend.left, 9 * border.metalScale)
border:Apply(Look("METAL", { shadow = SHADOW, top = ROWS }))
Equal("past a title bar on a side with rows", border.square.options.extend.top, 11)
Equal("and the plain band on the other", border.square.options.extend.bottom, 9)

-- Switching between the two kinds leaves one drawn.
border = Fresh(true)
border:Apply(Look("THIN_LINE", { shadow = SHADOW }))
border:Apply(Look("FOREVER", { shadow = SHADOW }))
Equal("switching to art hides the square shadow", border.square.shown, false)
Equal("and draws the art's", border.shadowPieces[1].shown, true)
border:Apply(Look("THIN_LINE", { shadow = SHADOW }))
Equal("switching back hides the art's", AllHidden(border.shadowPieces), true)
Equal("and shows the square one", border.square.shown, true)

io.stdout:write(("check_border: %d checks passed\n"):format(checks))
