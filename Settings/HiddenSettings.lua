local AUI = select(2, ...)

local L = AUI.L

---The Hidden Settings page, under the Quality of Life header: the Loot Sparkles card, with Quest Items where the
---client has the loot sparkle. Its settings are account-wide and take effect at once.
---@class AUISettingsHiddenSettings
local SettingsHiddenSettings = {}
AUI.SettingsHiddenSettings = SettingsHiddenSettings

---@return boolean
function SettingsHiddenSettings:IsAvailable()
	return AUI.can.lootSparkle == true
end

---@param window table
function SettingsHiddenSettings:Declare(window)
	local HiddenSettings = AUI.HiddenSettings
	local page = window:Page("hiddenSettings", {
		title = L["Hidden Settings"],
		under = "qualityOfLifeHeader",
		icon = AUI.Media.sidebar.hiddenSettings,
		iconTint = true,
	})

	if not page then
		return
	end

	page:Section("hiddenSettingsLootSparkles", L["Loot Sparkles"]):Checkbox({
		id = "hiddenSettingsQuestItems",
		label = BAG_FILTER_QUEST_ITEMS,
		description = L["The sparkle stays until the game restarts. /reload is not enough."],
		default = false,
		get = function()
			return HiddenSettings:IsQuestItems()
		end,
		set = function(value)
			HiddenSettings:SetQuestItems(value)
		end,
	})
end
