local AUI = select(2, ...)

local L = AUI.L

-- The approached objects' rows, in `Options.SPARKLE_TYPES` order.
local SPARKLE_ROWS = {
	{ kind = "ore", id = "hiddenSettingsOre", label = L["Ore"] },
	{ kind = "herbs", id = "hiddenSettingsHerbs", label = L["Herbs"] },
	{ kind = "questObjects", id = "hiddenSettingsQuestObjects", label = L["Quest Objects"] },
	{ kind = "corpses", id = "hiddenSettingsCorpses", label = L["Corpses with Loot"] },
	{ kind = "chests", id = "hiddenSettingsChests", label = L["Chests"] },
	{ kind = "bobber", id = "hiddenSettingsBobber", label = L["Fishing Bobber"] },
}

---The Hidden Settings page, under the Quality of Life header: the Loot Sparkles card, with Quest Items where the
---client has the loot sparkle and the approached objects where it has soft targeting's nameplates (Forever). Its
---settings are account-wide and take effect at once.
---@class AUISettingsHiddenSettings
local SettingsHiddenSettings = {}
AUI.SettingsHiddenSettings = SettingsHiddenSettings

---@return boolean
function SettingsHiddenSettings:IsAvailable()
	return AUI.can.lootSparkle == true or AUI.can.approachSparkles == true
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

	local card = page:Section("hiddenSettingsLootSparkles", L["Loot Sparkles"])

	if AUI.can.lootSparkle then
		card:Checkbox({
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

	if not AUI.can.approachSparkles then
		return
	end

	for _, row in ipairs(SPARKLE_ROWS) do
		card:Checkbox({
			id = row.id,
			label = row.label,
			default = false,
			get = function()
				return HiddenSettings:IsSparkle(row.kind)
			end,
			set = function(value)
				HiddenSettings:SetSparkle(row.kind, value)
			end,
		})
	end

	card:Note(
		L["Approached objects use the game's soft targeting: while one of them is on, the Interact Key reaches all around you."]
	)
end
