local AUI = select(2, ...)

local L = AUI.L

---The General page: settings that belong to the addon as a whole rather than one feature.
---@class AUISettingsGeneral
local General = {}
AUI.SettingsGeneral = General

---@param window table
function General:Declare(window)
	local page = window:Page("general", {
		title = GENERAL,
	})

	if not page then
		return
	end

	local access = page:Section("access", L["Access"])

	access:Checkbox({
		id = "minimapButton",
		label = L["Show Minimap Button"],
		description = L["Left-click opens settings."],
		get = function()
			return not AUI.Broker:Hidden()
		end,
		set = function(value)
			AUI.Broker:SetHidden(not value)
		end,
	})
	access:Note(L["/aui and the addon compartment open settings too."])
end
