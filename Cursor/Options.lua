local AUI = select(2, ...)

local Schema = AUI.Schema

local TEXTURES = "Interface\\AddOns\\AeonUI\\Media\\Textures\\"
-- The ring textures' band: its center and each thickness's half width, in texture pixels, as Tools/cursor-ring.py
-- draws them on a 256-pixel square.
local BAND_CENTER = 128 * 0.65
local HALF_WIDTHS = { THIN = 9, NORMAL = 16, THICK = 26 }
local TEXTURE_NAMES = { THIN = "Thin", NORMAL = "Normal", THICK = "Thick" }

---The cursor ring's profile settings and its frame-free arithmetic: the textures, where the global cooldown swipe sits
---inside the ring, the ring's place in `UIParent` units, and when it shows.
---@class AUICursorOptions
---@field ENABLED_PATH string the page's switch
---@field SIZE_PATH string the ring's width and height
---@field THICKNESS_PATH string a `cursorThickness` choice
---@field COLOR_PATH string the color of the ring, dot and swipes
---@field CLASS_COLOR_PATH string the player's class color instead of `COLOR_PATH`
---@field OPACITY_PATH string the ring and dot's opacity, a percentage
---@field DOT_PATH string the center dot shows
---@field GCD_PATH string the global cooldown fills a ring inside the ring
---@field CASTS_PATH string casts and channels sweep around the ring
---@field SHOW_PATH string a `cursorShow` choice: when the ring shows
---@field HIDE_TURNING_PATH string the ring hides while the camera is turned with the mouse
---@field THICKNESSES string[] the Thickness choices, in the order the page lists them
---@field SHOW_CHOICES string[] the Show choices, in the order the page lists them
---@field MIN_SIZE number
---@field MAX_SIZE number
---@field DOT_TEXTURE string
local Options = {
	ENABLED_PATH = "cursor.enabled",
	SIZE_PATH = "cursor.size",
	THICKNESS_PATH = "cursor.thickness",
	COLOR_PATH = "cursor.color",
	CLASS_COLOR_PATH = "cursor.classColor",
	OPACITY_PATH = "cursor.opacity",
	DOT_PATH = "cursor.dot",
	GCD_PATH = "cursor.gcd",
	CASTS_PATH = "cursor.casts",
	SHOW_PATH = "cursor.show",
	HIDE_TURNING_PATH = "cursor.hideTurning",
	THICKNESSES = { "THIN", "NORMAL", "THICK" },
	SHOW_CHOICES = { "ALWAYS", "COMBAT", "INSTANCES" },
	MIN_SIZE = 16,
	MAX_SIZE = 128,
	DOT_TEXTURE = TEXTURES .. "CursorDot.tga",
}
AUI.CursorOptions = Options

Schema:Choices("cursorThickness", Options.THICKNESSES)
Schema:Choices("cursorShow", Options.SHOW_CHOICES)

Schema:Boolean(Options.ENABLED_PATH, false)
Schema:Number(Options.SIZE_PATH, 56, Options.MIN_SIZE, Options.MAX_SIZE, true)
Schema:Choice(Options.THICKNESS_PATH, "cursorThickness", "NORMAL")
Schema:Color(Options.COLOR_PATH, { r = 1, g = 1, b = 1 })
Schema:Boolean(Options.CLASS_COLOR_PATH, false)
Schema:Number(Options.OPACITY_PATH, 100, 10, 100, true)
Schema:Boolean(Options.DOT_PATH, true)
Schema:Boolean(Options.GCD_PATH, true)
Schema:Boolean(Options.CASTS_PATH, true)
Schema:Choice(Options.SHOW_PATH, "cursorShow", "ALWAYS")
Schema:Boolean(Options.HIDE_TURNING_PATH, true)

---@param thickness string a `cursorThickness` choice
---@return string path the ring texture for it; Normal's for an unknown choice
function Options:RingTexture(thickness)
	return TEXTURES .. "CursorRing" .. (TEXTURE_NAMES[thickness] or TEXTURE_NAMES.NORMAL) .. ".tga"
end

---The global cooldown swipe's size as a share of the ring's, so its band's outer edge meets the ring band's inner
---edge.
---@param thickness string a `cursorThickness` choice
---@return number scale
function Options:SwipeScale(thickness)
	local half = HALF_WIDTHS[thickness] or HALF_WIDTHS.NORMAL

	return (BAND_CENTER - half) / (BAND_CENTER + half)
end

---The center dot's size for a ring of `size`.
---@param size number
---@return number
function Options:DotSize(size)
	return math.max(4, math.floor(size / 9 + 0.5))
end

---The cursor's place in `UIParent` units, rounded to whole units.
---@param x number `GetCursorPosition`'s x, in screen pixels
---@param y number
---@param scale number `UIParent`'s effective scale
---@return number x
---@return number y
function Options:Position(x, y, scale)
	return math.floor(x / scale + 0.5), math.floor(y / scale + 0.5)
end

---@param show string a `cursorShow` choice
---@param inCombat boolean
---@param inInstance boolean
---@param turning boolean the camera is turned with the mouse, which hides the cursor
---@param hideTurning boolean the ring hides while it is
---@return boolean shown
function Options:Visible(show, inCombat, inInstance, turning, hideTurning)
	if hideTurning and turning then
		return false
	end

	if show == "COMBAT" then
		return inCombat
	elseif show == "INSTANCES" then
		return inInstance
	end

	return true
end
