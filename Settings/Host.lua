local AUI = select(2, ...)

local L = AUI.L

-- The newest declaration contract this host draws: the shape of a hosted addon's pages and the handle it gets back.
local CONTRACT = 1

-- Hosted page ids are the guest's own, prefixed with its folder name and this separator.
local SEPARATOR = ":"

---@class AUIHostRegistration
---@field contract integer
---@field addon string the guest's folder name
---@field title string its header's title
---@field icon (string|number)? its header's icon
---@field pages table[] its pages in display order, as it hands them to its own window
---@field onAttached fun(handle: AUIHostHandle)?

---Shows a hosted addon's settings pages in AeonUI's window, under one header after AeonUI's own categories. The guest
---keeps its logic and saved data; the host only draws its pages and routes its window calls.
---@class AUISettingsHost
---@field guest AUIHostRegistration?
---@field pages table[]? the guest's pages with namespaced ids
---@field warned boolean the newer-contract notice has been printed this session
local Host = {
	warned = false,
}
AUI.SettingsHost = Host

---@param addon string
---@param pageID string
---@return string
function Host.Namespace(addon, pageID)
	return addon .. SEPARATOR .. pageID
end

---@return boolean
function Host:CanOpen()
	return not AUI.failed and AUI.Profile.characterID ~= ""
end

---@param registration any
---@return string? problem why the registration's shape is unusable
local function Problem(registration)
	if type(registration) ~= "table" then
		return "registration is not a table"
	elseif type(registration.contract) ~= "number" then
		return "contract is not a number"
	elseif type(registration.addon) ~= "string" or registration.addon == "" then
		return "addon is not a name"
	elseif type(registration.title) ~= "string" then
		return "title is not a string"
	elseif type(registration.pages) ~= "table" or #registration.pages == 0 then
		return "pages is empty"
	end

	for _, page in ipairs(registration.pages) do
		if type(page) ~= "table" or type(page.id) ~= "string" or type(page.Build) ~= "function" then
			return "a page lacks an id or Build"
		end
	end
end

---Copies the guest's pages with their ids prefixed, so they cannot collide with AeonUI's.
---@param registration AUIHostRegistration
---@return table[] pages
local function NamespacedPages(registration)
	local pages = {}

	for index, page in ipairs(registration.pages) do
		local copy = {}

		for key, value in pairs(page) do
			copy[key] = value
		end

		copy.id = Host.Namespace(registration.addon, page.id)
		pages[index] = copy
	end

	return pages
end

---@param registration any
---@return boolean accepted
---@return string? reason when refused
function Host:Register(registration)
	local problem = Problem(registration)

	if problem then
		return false, problem
	end

	if self.guest then
		return false, "another addon is already hosted"
	end

	if registration.contract > CONTRACT then
		if not self.warned then
			self.warned = true
			AUI:Print(L["%s needs a newer version of AeonUI to show its settings here, so it keeps its own window."],
				registration.title)
		end

		return false, "contract " .. registration.contract .. " is newer than " .. CONTRACT
	end

	self.guest = registration
	self.pages = NamespacedPages(registration)
	AUI.Settings:OnHostChanged()

	if registration.onAttached then
		AUI.AeonSettings:CallHost(nil, registration.onAttached, self:Handle(registration.addon))
	end

	return true
end

---@return table? category the hosted header, or nil while nothing is hosted
function Host:Category()
	local guest = self.guest

	if not guest then
		return nil
	end

	return { id = "hosted" .. SEPARATOR .. guest.addon, title = guest.title, icon = guest.icon, pages = self.pages }
end

---@class AUIHostHandle
---The window calls a hosted addon makes outside its declarations. Page ids are the guest's own.

---@param addon string
---@return AUIHostHandle
function Host:Handle(addon)
	local Settings = AUI.Settings
	local AS = AUI.AeonSettings

	local function Window()
		return Settings.window
	end

	return {
		---@return boolean opened false when AeonUI is off for the session and cannot show its window
		Open = function(_, pageID)
			if not Host:CanOpen() then
				return false
			end

			Settings:Open(pageID and Host.Namespace(addon, pageID) or nil)

			return true
		end,
		Close = function()
			Settings:Close()
		end,
		IsOpen = function()
			return Settings:IsOpen()
		end,
		RefreshPage = function()
			if Settings:IsOpen() then
				Window():RefreshPage()
			end
		end,
		ShowStatus = function(_, text)
			if Settings:IsOpen() then
				Window():ShowStatus(text)
			end
		end,
		SetPreviewChosen = function(_, key)
			if Window() then
				Window():SetPreviewChosen(key)
			end
		end,
		SetReloadPending = function(_, key, pending)
			Settings:Create()
			Window():SetReloadPending(addon .. SEPARATOR .. key, pending)
		end,
		TextCursor = function(_, settingID)
			return AS:TextCursor(settingID)
		end,
		SetTextCursor = function(_, settingID, position)
			AS:SetTextCursor(settingID, position)
		end,
	}
end

---The one deliberate global through which a suite addon finds its host. Not a public interface.
AeonUIHost = {
	Register = function(_, registration)
		return Host:Register(registration)
	end,
}
