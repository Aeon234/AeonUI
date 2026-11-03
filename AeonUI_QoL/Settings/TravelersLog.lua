local AUI = select(2, ...)

local L = AUI.L

local TEXT_LABELS = {
	COUNT = L["Count"],
	PERCENT = L["Percent"],
	NONE = NONE,
}

---The Traveler's Log page, under the Quality of Life header, on clients that have the log: the module's switch and the
---Row Progress card.
---@class AUISettingsTravelersLog
local SettingsTravelersLog = {}
AUI.SettingsTravelersLog = SettingsTravelersLog

---@return boolean
function SettingsTravelersLog:IsAvailable()
	return AUI.can.travelersLog == true
end

---@param window table
function SettingsTravelersLog:Declare(window)
	local Settings, Options = AUI.Settings, AUI.TravelersLogOptions
	local page = window:Page("travelersLog", {
		title = MONTHLY_ACTIVITIES_TAB,
		under = "qualityOfLifeHeader",
		icon = AUI.Media.sidebar.travelersLog,
		iconTint = true,
		switch = {
			path = Options.ENABLED_PATH,
			default = Settings:Default(Options.ENABLED_PATH),
			label = L["Enhance %s"]:format(MONTHLY_ACTIVITIES_TAB),
		},
	})

	if not page then
		return
	end

	local card = page:Section("travelersLogRows", L["Row Progress"])
	local choices = {}

	for index, choice in ipairs(Options.TEXT_CHOICES) do
		choices[index] = { value = choice, text = TEXT_LABELS[choice] }
	end

	card:Checkbox({
		id = "bars",
		label = L["Show Progress Bars"],
		path = Options.BARS_PATH,
		default = Settings:Default(Options.BARS_PATH),
	})
	card:Dropdown({
		id = "text",
		label = L["Text"],
		path = Options.TEXT_PATH,
		default = Settings:Default(Options.TEXT_PATH),
		options = choices,
	})
end

AUI.Modules:Register({
	group = "qualityOfLife",
	page = SettingsTravelersLog,
	start = function()
		AUI.TravelersLog:Start()
	end,
})
