local AUI = select(2, ...)

local LSM = LibStub("LibSharedMedia-3.0")

local MEDIA = "Interface\\AddOns\\AeonUI\\Media\\"
-- The flat look every AeonUI bar uses: a plain bar texture recolored to solid white, then tinted.
local FLAT_BASE = "Interface\\TargetingFrame\\UI-StatusBar"
-- The client's role icons, the DEFAULT role style.
local ROLE_ATLASES = { TANK = "roleicon-tiny-tank", HEALER = "roleicon-tiny-healer", DAMAGER = "roleicon-tiny-dps" }

---@param folder string the style's folder under Media/Textures/Roles
---@param extension string
---@return table<string, string> files the style's icon for each role
local function RoleFiles(folder, extension)
	local base = MEDIA .. "Textures\\Roles\\" .. folder .. "\\"

	return {
		TANK = base .. "Tank." .. extension,
		HEALER = base .. "Healer." .. extension,
		DAMAGER = base .. "DPS." .. extension,
	}
end

---Fonts, textures and sounds through LibSharedMedia, with the client's fonts as the fallback, and the role icon
---styles.
---@class AUIMedia
---@field FLAT string the texture choice meaning AeonUI's flat fill
---@field STRIPED string LibSharedMedia's name for AeonUI's thin stripes
---@field SHIELD string LibSharedMedia's name for Blizzard's shield fill
---@field TOOLTIP_BAR string LibSharedMedia's name for the fill of Blizzard's tooltip health bar
---@field shared table<string, table<string, string>> the files AeonUI registers with LibSharedMedia, by media type,
---then by name
---@field ROLE_STYLES string[] the role icon styles, in the order a setting lists them; DEFAULT is the client's
---@field roles table<string, table<string, string>> each role icon style's files but DEFAULT's, by role
---@field sidebar table<string, string> the settings sidebar's page icons, white line glyphs, by page id
local Media = {
	FLAT = "flat",
	STRIPED = "AeonUI Thin Stripes",
	SHIELD = "Blizzard Shield",
	TOOLTIP_BAR = "Blizzard Tooltip",
	shared = {
		[LSM.MediaType.BORDER] = {
			["border thick 1 s16 o0"] = MEDIA .. "Borders\\BorderThick1S16O0.tga",
			["border thick 1 s16 o4"] = MEDIA .. "Borders\\BorderThick1S16O4.tga",
			["border thick 2 s16 o4"] = MEDIA .. "Borders\\BorderThick2S16O4.tga",
			["border thick 3 s16 o4"] = MEDIA .. "Borders\\BorderThick3S16O4.tga",
			["border thick 4 s16 o4"] = MEDIA .. "Borders\\BorderThick4S16O4.tga",
			["border thin 1 s16 o0"] = MEDIA .. "Borders\\BorderThin1S16O0.tga",
			["border thin 1 s16 o8"] = MEDIA .. "Borders\\BorderThin1S16O8.tga",
		},
		[LSM.MediaType.FONT] = {
			["Albertus Nova Bold"] = MEDIA .. "Fonts\\AlbertusNovaBold.ttf",
			["Avant Garde Gothic ITC"] = MEDIA .. "Fonts\\AvantGardeGothicITC.ttf",
			["Exo2 Bold"] = MEDIA .. "Fonts\\Exo2Bold.ttf",
			["Expressway"] = MEDIA .. "Fonts\\Expressway.ttf",
			["Figtree Bold"] = MEDIA .. "Fonts\\FigtreeBold.ttf",
			["Fira Sans Condensed Medium"] = MEDIA .. "Fonts\\FiraSansCondensedMedium.ttf",
			["Gilroy Bold"] = MEDIA .. "Fonts\\GilroyBold.ttf",
			["Gotham Narrow Ultra"] = MEDIA .. "Fonts\\GothamNarrowUltra.ttf",
			["Instrument Serif Regular"] = MEDIA .. "Fonts\\InstrumentSerifRegular.ttf",
			["ITC Avant Garde Pro Md"] = MEDIA .. "Fonts\\ITCAvantGardeProMd.ttf",
			["Lato Bold"] = MEDIA .. "Fonts\\LatoBold.ttf",
			["Roboto Condensed Black"] = MEDIA .. "Fonts\\RobotoCondensedBlack.ttf",
			["Roboto Condensed Bold"] = MEDIA .. "Fonts\\RobotoCondensedBold.ttf",
			["TeX Gyre Adventor Bold"] = MEDIA .. "Fonts\\TexGyreAdventorBold.otf",
		},
		[LSM.MediaType.SOUND] = {
			["Sylvanas Bloodlust"] = MEDIA .. "Sounds\\SylvanasBloodlust.ogg",
			["Whisper FX"] = MEDIA .. "Sounds\\WhisperFX.ogg",
		},
		[LSM.MediaType.STATUSBAR] = {
			["AeonUI Thin Stripes"] = MEDIA .. "Textures\\ThinStripes.png",
			["Blizzard Shield"] = "Interface\\RaidFrame\\Shield-Fill",
			["Blizzard Tooltip"] = "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill",
			["Absorblutely"] = MEDIA .. "Statusbars\\Absorblutely.tga",
			["Aeon"] = MEDIA .. "Statusbars\\Aeon.tga",
			["Aeon Alt"] = MEDIA .. "Statusbars\\AeonAlt.png",
			["Aeon Flat"] = MEDIA .. "Statusbars\\AeonFlat.tga",
			["Aeon Gradient"] = MEDIA .. "Statusbars\\AeonGradient.tga",
			["Aeon Shadow"] = MEDIA .. "Statusbars\\AeonShadow.tga",
			["Aeon Shadow Dark"] = MEDIA .. "Statusbars\\AeonShadowDark.tga",
			["Aeon Smooth"] = MEDIA .. "Statusbars\\AeonSmooth.tga",
			["Aeon Thin"] = MEDIA .. "Statusbars\\AeonThin.tga",
			["Atrocity"] = MEDIA .. "Statusbars\\Atrocity.tga",
			["Blizzard Gradient"] = MEDIA .. "Statusbars\\BlizzardGradient.tga",
			["Eltreum Norm"] = MEDIA .. "Statusbars\\EltreumNorm.tga",
			["GW2"] = MEDIA .. "Statusbars\\GW2.tga",
			["Kait"] = MEDIA .. "Statusbars\\Kait.tga",
			["Toxi Half"] = MEDIA .. "Statusbars\\ToxiHalf.tga",
		},
	},
	ROLE_STYLES = { "DEFAULT", "BLIZZARD", "COLOR", "ELVUI", "SQUARE", "WHITE" },
	roles = {
		BLIZZARD = RoleFiles("Blizzard", "tga"),
		COLOR = RoleFiles("Color", "tga"),
		ELVUI = RoleFiles("ElvUI", "tga"),
		SQUARE = RoleFiles("Square", "png"),
		WHITE = RoleFiles("White", "png"),
	},
	sidebar = {
		general = "Interface\\AddOns\\AeonUI\\Media\\Textures\\SidebarGeneral.tga",
		minimap = "Interface\\AddOns\\AeonUI\\Media\\Textures\\SidebarMinimap.tga",
		worldMap = "Interface\\AddOns\\AeonUI\\Media\\Textures\\SidebarWorldMap.tga",
		tooltipGeneral = "Interface\\AddOns\\AeonUI\\Media\\Textures\\SidebarTooltipGeneral.tga",
		tooltipUnits = "Interface\\AddOns\\AeonUI\\Media\\Textures\\SidebarTooltipUnits.tga",
		tooltipItems = "Interface\\AddOns\\AeonUI\\Media\\Textures\\SidebarTooltipItems.tga",
		automation = "Interface\\AddOns\\AeonUI\\Media\\Textures\\SidebarAutomation.tga",
		deleteCheapestItem = "Interface\\AddOns\\AeonUI\\Media\\Textures\\SidebarDeleteCheapestItem.tga",
		playerMenu = "Interface\\AddOns\\AeonUI\\Media\\Textures\\SidebarPlayerMenu.tga",
		input = "Interface\\AddOns\\AeonUI\\Media\\Textures\\SidebarInput.tga",
		alerts = "Interface\\AddOns\\AeonUI\\Media\\Textures\\SidebarAlerts.tga",
		interface = "Interface\\AddOns\\AeonUI\\Media\\Textures\\SidebarInterface.tga",
		screenText = "Interface\\AddOns\\AeonUI\\Media\\Textures\\SidebarScreenText.tga",
		cursor = "Interface\\AddOns\\AeonUI\\Media\\Textures\\SidebarCursor.tga",
		notifications = "Interface\\AddOns\\AeonUI\\Media\\Textures\\SidebarNotifications.tga",
		raidMarkers = "Interface\\AddOns\\AeonUI\\Media\\Textures\\SidebarRaidMarkers.tga",
		profiles = "Interface\\AddOns\\AeonUI\\Media\\Textures\\SidebarProfiles.tga",
	},
}
AUI.Media = Media

-- `SetFont` flags for each outline choice; the Slug choices use the client's Slug text renderer.
local OUTLINE_FLAGS = {
	NONE = "",
	OUTLINE = "OUTLINE",
	THICKOUTLINE = "THICKOUTLINE",
	SLUG = "SLUG",
	SLUG_OUTLINE = "SLUG, OUTLINE",
	SLUG_THICKOUTLINE = "SLUG, THICKOUTLINE",
}

for kind, files in pairs(Media.shared) do
	for name, file in pairs(files) do
		LSM:Register(kind, name, file)
	end
end

---@param name string a LibSharedMedia font name
---@return string path the font, or the client's standard font when the name is not registered for this locale
function Media:Font(name)
	return LSM:Fetch(LSM.MediaType.FONT, name, true) or STANDARD_TEXT_FONT
end

---@param style string a `ROLE_STYLES` choice; an unknown one is DEFAULT
---@param role string "TANK", "HEALER" or "DAMAGER"
---@param size number the icon's width and height
---@return string? markup the role's icon in that style as text markup, or nil for any other role
function Media:RoleMarkup(style, role, size)
	local files = self.roles[style]
	local file = files and files[role]

	if file then
		return ("|T%s:%d:%d|t"):format(file, size, size)
	end

	local atlas = ROLE_ATLASES[role]

	return atlas and CreateAtlasMarkup(atlas, size, size) or nil
end

---@param outline string a schema outline choice
---@return string flags `SetFont` flags
function Media:FontFlags(outline)
	return OUTLINE_FLAGS[outline] or ""
end

---Gives a status bar a texture choice: AeonUI's flat fill, or a LibSharedMedia bar texture.
---@param bar StatusBar
---@param choice string `Media.FLAT` or a LibSharedMedia bar texture name; an unknown name falls back to flat
function Media:SetBarTexture(bar, choice)
	local path = choice ~= self.FLAT and LSM:Fetch(LSM.MediaType.STATUSBAR, choice, true)

	if path then
		bar:SetStatusBarTexture(path)

		return
	end

	bar:SetStatusBarTexture(FLAT_BASE)
	bar:GetStatusBarTexture():SetColorTexture(1, 1, 1, 1)
end
