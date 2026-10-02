-- Checks Media/Media.lua outside the game: font flags with and without the Slug setting and client support, and
-- the support probe running once.
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

-- Whether the stand-in client accepts the SLUG flag, and how often it was asked.
local slugAccepted, probes = true, 0

function CreateFrame()
	return {
		CreateFontString = function()
			return {
				SetFont = function(_, _, _, flags)
					probes = probes + 1
					if flags:find("SLUG") and not slugAccepted then
						error("unknown font flag")
					end
				end,
			}
		end,
	}
end

local AUI = {}
assert(loadfile(root .. "Core/Core.lua"))("AeonUI", AUI)
assert(loadfile(root .. "Profile/Schema.lua"))("AeonUI", AUI)
assert(loadfile(root .. "Media/Media.lua"))("AeonUI", AUI)

local Media, Schema = AUI.Media, AUI.Schema

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
Equal("no profile yet: outline only", Media:FontFlags("OUTLINE"), "OUTLINE")

AUI.Profile = { config = Schema:Defaults() }
Equal("Slug on by default", Schema:Read(AUI.Profile.config, "text.slug"), true)
Equal("outline with Slug", Media:FontFlags("OUTLINE"), "OUTLINE,SLUG")
Equal("thick outline with Slug", Media:FontFlags("THICKOUTLINE"), "THICKOUTLINE,SLUG")
Equal("Slug alone", Media:FontFlags("NONE"), "SLUG")
Equal("probed once", probes, 1)
Media:FontFlags("OUTLINE")
Equal("probe remembered", probes, 1)

Schema:Write(AUI.Profile.config, "text.slug", false)
Equal("setting off: outline only", Media:FontFlags("OUTLINE"), "OUTLINE")
Equal("setting off: no flags", Media:FontFlags("NONE"), "")

Schema:Write(AUI.Profile.config, "text.slug", true)
Media.slug, slugAccepted = nil, false
Equal("client without Slug: outline only", Media:FontFlags("OUTLINE"), "OUTLINE")
Equal("client without Slug remembered", Media.slug, false)

print(("check_media: %d checks passed"):format(checks))
