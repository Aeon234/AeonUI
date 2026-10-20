-- Checks Media/Media.lua outside the game: the font flags for every outline choice, the Slug variants included, and
-- the bar textures AeonUI registers.
-- Run from any directory with Lua 5.1: lua Tools/check_media.lua

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

UNKNOWN = "Unknown"
SlashCmdList = {}
C_AddOns = {
	GetAddOnMetadata = function() end,
}
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"

local registered = {}
local LSM = {
	MediaType = { FONT = "font", STATUSBAR = "statusbar" },
	Register = function(_, kind, name, file)
		registered[kind .. ":" .. name] = file
	end,
	Fetch = function() end,
}

function LibStub()
	return LSM
end

local AUI = {}
assert(loadfile(root .. "Core/Core.lua"))("AeonUI", AUI)
assert(loadfile(root .. "Media/Media.lua"))("AeonUI", AUI)

local Media = AUI.Media

-- Harness -------------------------------------------------------------------------------------------------

local checks = 0

local function Equal(name, actual, expected)
	checks = checks + 1
	if actual ~= expected then
		io.stderr:write(("FAIL: %s: expected %s, got %s\n"):format(name, tostring(expected), tostring(actual)))
		os.exit(1)
	end
end

-- Font flags ----------------------------------------------------------------------------------------------

Equal("stripes registered", registered["statusbar:AeonUI Thin Stripes"] ~= nil, true)
Equal("Blizzard shield registered", registered["statusbar:Blizzard Shield"], "Interface\\RaidFrame\\Shield-Fill")

Equal("no outline", Media:FontFlags("NONE"), "")
Equal("outline", Media:FontFlags("OUTLINE"), "OUTLINE")
Equal("thick outline", Media:FontFlags("THICKOUTLINE"), "THICKOUTLINE")
Equal("Slug", Media:FontFlags("SLUG"), "SLUG")
Equal("Slug Outline", Media:FontFlags("SLUG_OUTLINE"), "SLUG, OUTLINE")
Equal("Slug Thick Outline", Media:FontFlags("SLUG_THICKOUTLINE"), "SLUG, THICKOUTLINE")
Equal("unknown choice draws plain", Media:FontFlags("SHADOW"), "")

print(("check_media: %d checks passed"):format(checks))
