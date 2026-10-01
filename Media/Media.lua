local AUI = select(2, ...)

local LSM = LibStub("LibSharedMedia-3.0")

-- The flat look every AeonUI bar uses: a plain bar texture recolored to solid white, then tinted.
local FLAT_BASE = "Interface\\TargetingFrame\\UI-StatusBar"

---Fonts and textures through LibSharedMedia, with the client's fonts as the fallback.
---@class AUIMedia
---@field FLAT string the texture choice meaning AeonUI's flat fill
---@field STRIPED string LibSharedMedia's name for AeonUI's thin stripes
---@field SHIELD string LibSharedMedia's name for Blizzard's shield fill
---@field files table<string, string> the files of the bar textures AeonUI registers, by name
local Media = {
	FLAT = "flat",
	STRIPED = "AeonUI Thin Stripes",
	SHIELD = "Blizzard Shield",
	files = {
		["AeonUI Thin Stripes"] = "Interface\\AddOns\\AeonUI\\Media\\Textures\\ThinStripes.png",
		["Blizzard Shield"] = "Interface\\RaidFrame\\Shield-Fill",
	},
}
AUI.Media = Media

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
	return outline == "NONE" and "" or outline
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
