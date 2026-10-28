local AUI = select(2, ...)

local L = AUI.L
local lib = LibStub("LibAeonSettings-1.0")

local ADDON_NAME = ...
local FRAME_NAME = "AeonUISettings"

---The settings window, built on LibAeonSettings. It is registered and its pages declared the first time it is asked
---for, once saved data is ready. Its pages follow the profile owner's mode at that moment: Recovery alone while the
---saved data cannot be used, otherwise General, the feature pages and Profiles.
---@class AUISettings
---@field window table?
local Settings = {}
AUI.Settings = Settings

---@param window table
local function DeclareSidebar(window)
	if AUI.Profile.mode == "recovery" then
		AUI.SettingsRecovery:Declare(window)

		return
	end

	AUI.SettingsGeneral:Declare(window)
	window:Header("mapsHeader", L["Maps"])
	AUI.SettingsMinimap:Declare(window)

	if AUI.SettingsWorldMap:IsAvailable() then
		AUI.SettingsWorldMap:Declare(window)
	end

	AUI.SettingsTooltip:Declare(window)
	AUI.SettingsAutomation:Declare(window)

	if AUI.SettingsPlayerMenu:IsAvailable() then
		AUI.SettingsPlayerMenu:Declare(window)
	end

	if AUI.SettingsInput:IsAvailable() then
		AUI.SettingsInput:Declare(window)
	end
	window:Divider()
	AUI.SettingsProfiles:Declare(window)
end

---@return table window the library's settings window, registered and declared on first use
function Settings:Window()
	if self.window then
		return self.window
	end

	local window = lib:Settings(ADDON_NAME, {
		title = AUI.brand,
		version = AUI.version,
		frameName = FRAME_NAME,
		store = function()
			return AUI.Profile.config
		end,
		write = function(path, value)
			return AUI.Profile:Set(path, value)
		end,
		account = function()
			return AUI.Profile:Global()
		end,
	}) --[[@as table]]

	self.window = window
	DeclareSidebar(window)

	-- A page shows each time the window opens, and the window reports closing however it hides, Escape included.
	-- CallbackHandler embeds RegisterCallback in the library.
	for _, event in ipairs({ "OnPageShown", "OnClose" }) do
		(lib --[[@as table]]).RegisterCallback(self, event, function(_, addonName)
			if addonName == ADDON_NAME then
				Settings:UpdatePreview()
			end
		end)
	end

	return window
end

---The minimap shows its samples while the window is open on one of its pages, so each setting is seen on the minimap
---itself.
function Settings:UpdatePreview()
	local window = self.window
	local on = window ~= nil and window:IsShown() and AUI.SettingsMinimap.pageIDs[window.page] == true

	AUI.MinimapElements:SetPreview(on, "settings")
end

---@param path string
---@return any value the setting's default, copied when it is a table
function Settings:Default(path)
	local field = AUI.Schema:Field(path)

	return field and AUI:CopyTable(field.default)
end

---@return boolean
function Settings:IsOpen()
	return self.window ~= nil and self.window:IsShown()
end

---Opens the window; the library refuses in combat and keeps the page and scroll position for the session.
---@param page string? a page id; the last page shown when nil or unknown
function Settings:Open(page)
	local window = self:Window()

	if page and window.pages[page] then
		window:SelectPage(page)
	end

	window:Open()
end

function Settings:Close()
	if self.window then
		self.window:Close()
	end
end

function Settings:Toggle()
	if self:IsOpen() then
		self:Close()
	else
		self:Open()
	end
end

---Redraws the shown page, for changes made outside the window.
function Settings:Refresh()
	if self:IsOpen() then
		local window = self.window --[[@as table]]

		window:Refresh()
	end
end

AUI.Callbacks:Register("Profile", Settings, function(_, path)
	if path == nil then
		Settings:Refresh()
	end
end)
