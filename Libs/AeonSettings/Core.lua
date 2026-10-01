-- Library entry point. Loaded by the host addon's TOC; `...` supplies the host addon's name and table.
local ADDON_NAME, ns = ...

---@class AeonSettings
---@field VERSION string Semantic version. Release tags are "v" .. VERSION.
---@field ADDON string Host addon name, which is also its folder name.
---@field MEDIA string Path to this copy's media folder.
---@field fonts table<string, string> Font file paths keyed by token (`body`, `header`).
local AS = {}
ns.AeonSettings = AS

AS.VERSION = "0.1.0"
AS.ADDON = ADDON_NAME
AS.MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Libs\\AeonSettings\\Media\\"

local EXPRESSWAY = AS.MEDIA .. "Fonts\\Expressway.ttf"
local GILROY_BOLD = AS.MEDIA .. "Fonts\\GilroyBold.ttf"

-- Locales that use STANDARD_TEXT_FONT, the client's locale-specific font, in place of the bundled fonts.
local NATIVE_FONT_LOCALES = { koKR = true, ruRU = true, zhCN = true, zhTW = true }

if NATIVE_FONT_LOCALES[GetLocale()] then
	AS.fonts = { body = STANDARD_TEXT_FONT, header = STANDARD_TEXT_FONT }
else
	AS.fonts = { body = EXPRESSWAY, header = GILROY_BOLD }
end

local xpcall, CallErrorHandler = xpcall, CallErrorHandler

local function HostResults(fallback, ok, ...)
	if ok then
		return ...
	end

	return fallback
end

---Calls a function the host addon supplied. An error is reported through `geterrorhandler()` and does not
---propagate; the call then returns `fallback` in place of the function's results.
---@param fallback any
---@param fn function
---@param ... any arguments passed to `fn`
---@return any ... every result of `fn`, or `fallback` when it raised an error
function AS:CallHost(fallback, fn, ...)
	return HostResults(fallback, xpcall(fn, CallErrorHandler, ...))
end

-- LibSharedMedia-3.0 must load before this file. Registration is a no-op if the name is already taken or,
-- with the western mask, on koKR, ruRU, zhCN and zhTW clients.
local LSM = LibStub("LibSharedMedia-3.0")
LSM:Register(LSM.MediaType.FONT, "Expressway", EXPRESSWAY, LSM.LOCALE_BIT_western)
LSM:Register(LSM.MediaType.FONT, "Gilroy Bold", GILROY_BOLD, LSM.LOCALE_BIT_western)
