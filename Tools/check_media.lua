-- Checks Media/Media.lua outside the game: the font flags for every outline choice, the Slug variants included, the
-- media AeonUI registers and that each of its files ships, and the role icon styles.
-- Run from any directory with Lua 5.1: lua Tools/check_media.lua

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

UNKNOWN = "Unknown"
SlashCmdList = {}
C_AddOns = {
	GetAddOnMetadata = function() end,
}
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
function CreateAtlasMarkup(atlas, width, height) return ("|A:%s:%d:%d|a"):format(atlas, width, height) end

local registered = {}
local LSM = {
	MediaType = { BORDER = "border", FONT = "font", SOUND = "sound", STATUSBAR = "statusbar" },
	Register = function(_, kind, name, file)
		registered[kind .. ":" .. name] = file
	end,
	Fetch = function() end,
}

function LibStub()
	return LSM
end

local AUI = {}
assert(loadfile(root .. "AeonUI/Core/Core.lua"))("AeonUI", AUI)
assert(loadfile(root .. "AeonUI/Media/Media.lua"))("AeonUI", AUI)

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

-- Registered media --------------------------------------------------------------------------------------

---@param path string a game path under Interface\AddOns\AeonUI
---@return boolean exists the file is in the working tree
local function Ships(path)
	local relative = path:match("^Interface\\AddOns\\AeonUI\\(.+)$")
	local file = relative and io.open(root .. "AeonUI/" .. relative:gsub("\\", "/"), "rb")

	if file then
		file:close()
	end

	return file ~= nil
end

local counts = {}

for kind, files in pairs(Media.shared) do
	counts[kind] = 0

	for name, file in pairs(files) do
		counts[kind] = counts[kind] + 1
		Equal(kind .. " " .. name .. " registered", registered[kind .. ":" .. name], file)

		if file:find("^Interface\\AddOns\\AeonUI\\") then
			Equal(kind .. " " .. name .. " ships", Ships(file), true)
		end
	end
end

Equal("seven borders", counts.border, 7)
Equal("fourteen fonts", counts.font, 14)
Equal("two sounds", counts.sound, 2)
Equal("AeonUI's three bar textures and fifteen more", counts.statusbar, 18)
Equal("AeonCore's names are kept", registered["font:Expressway"],
	"Interface\\AddOns\\AeonUI\\Media\\Fonts\\Expressway.ttf")

-- Role icons ----------------------------------------------------------------------------------------------

Equal("six styles, the client's first", Media.ROLE_STYLES[1] .. " " .. #Media.ROLE_STYLES, "DEFAULT 6")

for _, style in ipairs(Media.ROLE_STYLES) do
	for _, role in ipairs({ "TANK", "HEALER", "DAMAGER" }) do
		local file = Media.roles[style] and Media.roles[style][role]

		if file then
			Equal(style .. " " .. role .. " ships", Ships(file), true)
		end

		Equal(style .. " " .. role .. " has an icon", Media:RoleMarkup(style, role, 14) ~= nil, true)
	end
end

Equal("the client's style is its atlas", Media:RoleMarkup("DEFAULT", "HEALER", 14), "|A:roleicon-tiny-healer:14:14|a")
Equal("a style's file at the asked size", Media:RoleMarkup("WHITE", "TANK", 12),
	"|TInterface\\AddOns\\AeonUI\\Media\\Textures\\Roles\\White\\Tank.png:12:12|t")
Equal("an unknown style is the client's", Media:RoleMarkup("ROUND", "DAMAGER", 14), "|A:roleicon-tiny-dps:14:14|a")
Equal("no icon for no role", Media:RoleMarkup("WHITE", "NONE", 14), nil)

-- Font flags ----------------------------------------------------------------------------------------------

Equal("stripes registered", registered["statusbar:AeonUI Thin Stripes"] ~= nil, true)
Equal("Blizzard shield registered", registered["statusbar:Blizzard Shield"], "Interface\\RaidFrame\\Shield-Fill")
Equal("Blizzard tooltip fill registered", registered["statusbar:Blizzard Tooltip"],
	"Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")

Equal("no outline", Media:FontFlags("NONE"), "")
Equal("outline", Media:FontFlags("OUTLINE"), "OUTLINE")
Equal("thick outline", Media:FontFlags("THICKOUTLINE"), "THICKOUTLINE")
Equal("Slug", Media:FontFlags("SLUG"), "SLUG")
Equal("Slug Outline", Media:FontFlags("SLUG_OUTLINE"), "SLUG, OUTLINE")
Equal("Slug Thick Outline", Media:FontFlags("SLUG_THICKOUTLINE"), "SLUG, THICKOUTLINE")
Equal("unknown choice draws plain", Media:FontFlags("SHADOW"), "")

print(("check_media: %d checks passed"):format(checks))
