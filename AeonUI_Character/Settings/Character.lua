local AUI = select(2, ...)

local L = AUI.L

---The Character page, under the Windows header, on Forever: the module's switch, then the Equipment and Stats cards.
---@class AUISettingsCharacter
local SettingsCharacter = {}
AUI.SettingsCharacter = SettingsCharacter

---@return boolean
function SettingsCharacter:IsAvailable()
	return AUI.can.characterPanel == true
end

---@param window table
function SettingsCharacter:Declare(window)
	local Settings, Options = AUI.Settings, AUI.CharacterOptions

	local page = window:Page("character", {
		title = CHARACTER,
		under = "windowsHeader",
		switch = {
			path = Options.ENABLED_PATH,
			default = Settings:Default(Options.ENABLED_PATH),
			label = L["Enhance %s"]:format(CHARACTER),
		},
	})

	if not page then
		return
	end

	local function Checkbox(card, id, label, path)
		card:Checkbox({ id = id, label = label, path = path, default = Settings:Default(path) })
	end

	local equipment = page:Section("characterEquipment", L["Equipment"])

	Checkbox(equipment, "showModel", L["Show Character Model"], Options.SHOW_MODEL_PATH)
	Checkbox(equipment, "itemLevel", STAT_AVERAGE_ITEM_LEVEL, Options.ITEM_LEVEL_PATH)
	Checkbox(equipment, "enchants", ENCHANTS, Options.ENCHANTS_PATH)
	equipment:Dropdown({
		id = "qualityBorder",
		label = L["Quality Border"],
		path = Options.QUALITY_BORDER_PATH,
		default = Settings:Default(Options.QUALITY_BORDER_PATH),
		options = { { value = "NORMAL", text = L["Normal"] }, { value = "THICK", text = L["Thick"] } },
	})
	Checkbox(equipment, "durabilityGauges", L["Durability Gauges"], Options.GAUGES_PATH)

	local stats = page:Section("characterStats", L["Stats"])

	Checkbox(stats, "averageItemLevel", L["Average Item Level"], Options.AVERAGE_PATH)
	Checkbox(stats, "gearRows", L["Gear Summary"], Options.GEAR_ROWS_PATH)
	Checkbox(stats, "extraStats", L["Extra Stats"], Options.EXTRA_STATS_PATH)
	Checkbox(stats, "mainStat", L["Highlight Main Stat"], Options.MAIN_STAT_PATH)
end

AUI.Modules:Register({
	group = "windows",
	page = SettingsCharacter,
	start = function()
		AUI.Character:Start()
	end,
})
