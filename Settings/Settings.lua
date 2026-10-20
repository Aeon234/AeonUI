local AUI = select(2, ...)

local L = AUI.L
local AS = AUI.AeonSettings --[[@as table]]

local FRAME_NAME = "AeonUISettings"

---The settings window, built on the AeonSettings library. Its pages follow the profile owner's mode: Recovery
---alone while the saved data cannot be used, otherwise Profiles.
---@class AUISettings
---@field window table?
---@field recovery boolean? the window shows the Recovery page
local Settings = {}
AUI.Settings = Settings

---@return table[] categories
function Settings:Categories()
	if AUI.Profile.mode == "recovery" then
		return {
			{ id = "recovery", title = L["Recovery"], pages = { AUI.SettingsRecovery:Page() } },
		}
	end

	return {
		{ id = "profiles", title = L["Profiles"], pages = { AUI.SettingsProfiles:Page() } },
	}
end

function Settings:Create()
	if self.window then
		return
	end

	local window = AS:CreateWindow({
		name = FRAME_NAME,
		title = AUI.title,
		version = AUI.version,
		contentWidth = 980,
	})

	self.window = window
	self.recovery = AUI.Profile.mode == "recovery"
	window:SetCategories(self:Categories())

	AUI.Callbacks:Register("Profile", self, self.OnProfileChanged)
end

---Rebuilds the window after a change made outside it: a profile switch, import, reset or copy. Single settings
---saved from the window refresh themselves.
---@param path string?
function Settings:OnProfileChanged(path)
	if path then
		return
	end

	local window = self.window --[[@as table]]
	local recovery = AUI.Profile.mode == "recovery"

	if recovery ~= self.recovery then
		self.recovery = recovery
		window:SetCategories(self:Categories())
	end

	if self:IsOpen() then
		window:RefreshPage()
	end
end

---@return boolean
function Settings:IsOpen()
	return self.window ~= nil and self.window:IsShown()
end

---@param page string? a page id
function Settings:Open(page)
	self:Create()

	local window = self.window --[[@as table]]

	window:Open(page)
end

function Settings:Close()
	if self.window then
		self.window:Close()
	end
end

function Settings:Toggle()
	if self:IsOpen() then
		self:Close()

		return
	end

	self:Open()
end
