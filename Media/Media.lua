local AUI = select(2, ...)

local LSM = LibStub("LibSharedMedia-3.0")

---Fonts and textures through LibSharedMedia, with the client's fonts as the fallback.
---@class AUIMedia
local Media = {}
AUI.Media = Media

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
