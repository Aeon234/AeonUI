---@type string
local addonName = ...

---@class AUI
---@field name string
---@field title string
---@field version string
---@field L AUILocale
---@field Callbacks AUICallbacks
---@field Events AUIEvents
---@field oUF table the private oUF instance, set by Libs/oUF/init.lua
---@field AeonSettings table the vendored settings library, set by Libs/AeonSettings/Core.lua
---@field Settings table?
local AUI = select(2, ...)

AUI.name = addonName
AUI.title = C_AddOns.GetAddOnMetadata(addonName, "Title") or addonName
AUI.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or UNKNOWN

if AUI.version:find("@", 1, true) then
	AUI.version = "dev"
end

-- The suite accent (bronze) used for the addon name in chat.
local PREFIX = "|cff9e754aAeonUI|r: "
local WARN_PREFIX = "|cff9e754aAeonUI|r |cffff4d4dWarning|r: "

---@param message string
---@param ... any
function AUI:Print(message, ...)
	if select("#", ...) > 0 then
		message = message:format(...)
	end

	print(PREFIX .. message)
end

---@param message string
---@param ... any
function AUI:Warn(message, ...)
	if select("#", ...) > 0 then
		message = message:format(...)
	end

	print(WARN_PREFIX .. message)
end

---@param page string? page to open at
function AUI:OpenSettings(page)
	if self.Settings then
		self.Settings:Open(page)

		return
	end

	self:Warn(self.L["the settings window is not available yet."])
end

SLASH_AEONUI1 = "/aeonui"
SLASH_AEONUI2 = "/aui"

SlashCmdList.AEONUI = function(message)
	local command = (message or ""):lower():match("^%s*(%S*)")

	AUI:OpenSettings(command ~= "" and command or nil)
end
