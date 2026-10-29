local AUI = select(2, ...)

local LSM = LibStub("LibSharedMedia-3.0")

-- The flat look every AeonUI bar uses: a plain bar texture recolored to solid white, then tinted.
local FLAT_BASE = "Interface\\TargetingFrame\\UI-StatusBar"

---Fonts and textures through LibSharedMedia, with the client's fonts as the fallback.
---@class AUIMedia
---@field FLAT string the texture choice meaning AeonUI's flat fill
---@field STRIPED string LibSharedMedia's name for AeonUI's thin stripes
---@field SHIELD string LibSharedMedia's name for Blizzard's shield fill
---@field TOOLTIP_BAR string LibSharedMedia's name for the fill of Blizzard's tooltip health bar
---@field files table<string, string> the files of the bar textures AeonUI registers, by name
---@field sidebar table<string, string> the settings sidebar's page icons, white line glyphs, by page id
local Media = {
	FLAT = "flat",
	STRIPED = "AeonUI Thin Stripes",
	SHIELD = "Blizzard Shield",
	TOOLTIP_BAR = "Blizzard Tooltip",
	files = {
		["AeonUI Thin Stripes"] = "Interface\\AddOns\\AeonUI\\Media\\Textures\\ThinStripes.png",
		["Blizzard Shield"] = "Interface\\RaidFrame\\Shield-Fill",
		["Blizzard Tooltip"] = "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill",
	},
	sidebar = {
		minimap = "Interface\\AddOns\\AeonUI\\Media\\Textures\\SidebarMinimap.tga",
		worldMap = "Interface\\AddOns\\AeonUI\\Media\\Textures\\SidebarWorldMap.tga",
		tooltipGeneral = "Interface\\AddOns\\AeonUI\\Media\\Textures\\SidebarTooltipGeneral.tga",
		tooltipUnits = "Interface\\AddOns\\AeonUI\\Media\\Textures\\SidebarTooltipUnits.tga",
		tooltipItems = "Interface\\AddOns\\AeonUI\\Media\\Textures\\SidebarTooltipItems.tga",
		automation = "Interface\\AddOns\\AeonUI\\Media\\Textures\\SidebarAutomation.tga",
		playerMenu = "Interface\\AddOns\\AeonUI\\Media\\Textures\\SidebarPlayerMenu.tga",
		input = "Interface\\AddOns\\AeonUI\\Media\\Textures\\SidebarInput.tga",
		alerts = "Interface\\AddOns\\AeonUI\\Media\\Textures\\SidebarAlerts.tga",
		interface = "Interface\\AddOns\\AeonUI\\Media\\Textures\\SidebarInterface.tga",
		screenText = "Interface\\AddOns\\AeonUI\\Media\\Textures\\SidebarScreenText.tga",
		cursor = "Interface\\AddOns\\AeonUI\\Media\\Textures\\SidebarCursor.tga",
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

for name, file in pairs(Media.files) do
	LSM:Register(LSM.MediaType.STATUSBAR, name, file)
end

---@param name string a LibSharedMedia font name
---@return string path the font, or the client's standard font when the name is not registered for this locale
function Media:Font(name)
	return LSM:Fetch(LSM.MediaType.FONT, name, true) or STANDARD_TEXT_FONT
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
