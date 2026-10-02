local AUI = select(2, ...)

local L = AUI.L
local AS = AUI.AeonSettings --[[@as table]]

local FRAME_NAME = "AeonUISettings"

-- Words `/aui <word>` accepts for a page.
local ALIASES = {
	globals = "globals",
	player = "player",
	target = "target",
	tot = "targettarget",
	focus = "focus",
	boss = "boss",
	power = "playerPower",
	resource = "classPower",
	profiles = "profiles",
}

---The settings window, built on the AeonSettings library. Its pages follow the profile owner's mode: Recovery
---alone while the saved data cannot be used, otherwise the unit-frame pages and Profiles.
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
		{ id = "unitFrames", title = L["Unit Frames"], pages = AUI.SettingsPages:UnitFramePages() },
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

---@param page string? a page id or an alias for one
function Settings:Open(page)
	self:Create()

	local window = self.window --[[@as table]]

	window:Open(page and (ALIASES[page] or page) or nil)
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
