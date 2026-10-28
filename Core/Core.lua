---@type string
local addonName = ...

---@class AUI
---@field name string
---@field title string
---@field version string
---@field brand string the addon name in blue and parchment, as an escape-coded string
---@field L AUILocale
---@field Callbacks AUICallbacks
---@field Events AUIEvents
---@field Schema AUISchema
---@field Store AUIStore
---@field Profile AUIProfile
---@field Settings AUISettings
---@field Broker AUIBroker
---@field GameMenu AUIGameMenu
---@field Border AUIBorderFactory
---@field Minimap AUIMinimap the Minimap module (not Blizzard's `Minimap` frame)
---@field WorldMap AUIWorldMap the World Map module (not Blizzard's `WorldMapFrame`)
---@field EditTargets AUIEditTargets
---@field Codec AUICodec
---@field Dev AUIDev? development self-tests, present only in unpackaged builds
---@field failed boolean? saved data or the character could not be loaded; AeonUI stays off for the session
local AUI = select(2, ...)

AUI.name = addonName
AUI.title = C_AddOns.GetAddOnMetadata(addonName, "Title") or addonName
AUI.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or UNKNOWN

if AUI.version:find("@", 1, true) then
	AUI.version = "dev"
end

-- The addon name in blue and parchment, used in chat, the game menu and the settings window title.
AUI.brand = "|cff00a3e3Aeon|r|cfff2e6c8UI|r"

local PREFIX = AUI.brand .. ": "
local WARN_PREFIX = AUI.brand .. " |cffff4d4dWarning|r: "

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

---Returns `value` unless it is a secret value, in which case returns `fallback`.
---@generic T
---@param value T
---@param fallback T?
---@return T? value the value itself when it can be read, otherwise the fallback
function AUI:Readable(value, fallback)
	if issecretvalue(value) then
		return fallback
	end

	return value
end

---@generic T
---@param source T
---@return T copy a deep copy; tables are rebuilt, everything else is returned as it is
function AUI:CopyTable(source)
	if type(source) ~= "table" then
		return source
	end

	local result = {}

	for key, value in pairs(source) do
		result[key] = self:CopyTable(value)
	end

	return result
end

---@param region Region? defaults to UIParent
---@return number pixel the size of one physical pixel in the region's units
function AUI:Pixel(region)
	return PixelUtil.GetPixelToUIUnitFactor() / (region or UIParent):GetEffectiveScale()
end

---@param page string? page to open at
function AUI:OpenSettings(page)
	if self.failed or self.Profile.characterID == "" then
		self:Warn(self.L["AeonUI is off for this session, so its settings can't open."])

		return
	end

	self.Settings:Open(page)
end

function AUI:PrintDiagnostics()
	local Profile = self.Profile

	self:Print("v%s  failed %s  mode %s", self.version, tostring(self.failed == true), Profile.mode)

	if Profile.problem then
		self:Print("problem: %s", Profile.problem)
	end

	if Profile.activeID then
		self:Print("active %s (%s)", Profile.activeID, tostring(Profile:Name(Profile.activeID)))
	end

	for _, entry in ipairs(Profile:List()) do
		self:Print(
			"  %s %s%s",
			entry.id,
			entry.name,
			entry.quarantined and ("  quarantined: " .. entry.quarantined) or ""
		)
	end
end

SLASH_AEONUI1 = "/aeonui"
SLASH_AEONUI2 = "/aui"

SlashCmdList.AEONUI = function(message)
	local command, rest = (message or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")

	if command == "dev" and AUI.Dev then
		AUI.Dev:Command(rest)

		return
	end

	if command == "debug" then
		AUI:PrintDiagnostics()

		return
	end

	AUI:OpenSettings(command ~= "" and command or nil)
end
