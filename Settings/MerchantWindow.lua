local AUI = select(2, ...)

local L = AUI.L

-- Blizzard's Edit Mode labels, translated for a grid's rows and columns.
local ROWS_LABEL = HUD_EDIT_MODE_SETTING_ACTION_BAR_NUM_ROWS
local COLUMNS_LABEL = HUD_EDIT_MODE_SETTING_ACTION_BAR_NUM_COLUMNS
local ORDER_LABELS = {
	ROWS = L["Rows First"],
	COLUMNS = L["Columns First"],
}

---The Merchant Window page, under the Quality of Life header: the Item Grid card headed by its switch, with the rows,
---columns and fill order while it is on, and the Filter card's Show All Items. Changes take effect at once, in an
---open merchant window too.
---@class AUISettingsMerchantWindow
local SettingsMerchantWindow = {}
AUI.SettingsMerchantWindow = SettingsMerchantWindow

---@param card table
---@param id string
---@param label string
---@param path string
---@param min number
---@param max number
local function Count(card, id, label, path, min, max)
	card:Slider({
		id = id,
		label = label,
		path = path,
		default = AUI.Settings:Default(path),
		depends = "merchantWindowEnabled",
		min = min,
		max = max,
		step = 1,
	})
end

---@param window table
function SettingsMerchantWindow:Declare(window)
	local Settings, Options = AUI.Settings, AUI.MerchantWindowOptions
	local page = window:Page("merchantWindow", {
		title = L["Merchant Window"],
		under = "qualityOfLifeHeader",
		icon = AUI.Media.sidebar.merchantWindow,
		iconTint = true,
	})

	if not page then
		return
	end

	local card = page:Section("merchantWindowGrid", L["Item Grid"])
	local options = {}

	for index, value in ipairs(Options.ORDERS) do
		options[index] = { value = value, text = ORDER_LABELS[value] }
	end

	card:Toggle({
		id = "merchantWindowEnabled",
		label = L["Extend Merchant Window"],
		path = Options.ENABLED_PATH,
		default = Settings:Default(Options.ENABLED_PATH),
		blocked = function()
			return AUI.MerchantWindow:Blocked()
		end,
		keywords = table.concat({ ROWS_LABEL, COLUMNS_LABEL, L["Fill Order"] }, " "),
	})
	Count(card, "merchantWindowRows", ROWS_LABEL, Options.ROWS_PATH, Options.MIN_ROWS, Options.MAX_ROWS)
	Count(card, "merchantWindowColumns", COLUMNS_LABEL, Options.COLUMNS_PATH, Options.MIN_COLUMNS, Options.MAX_COLUMNS)
	card:Dropdown({
		id = "merchantWindowOrder",
		label = L["Fill Order"],
		path = Options.ORDER_PATH,
		default = Settings:Default(Options.ORDER_PATH),
		depends = "merchantWindowEnabled",
		options = options,
	})

	if AUI.can.merchantFilter then
		page:Section("merchantWindowFilter", FILTER):Checkbox({
			id = "merchantWindowShowAll",
			label = L["Show All Items"],
			path = Options.SHOW_ALL_PATH,
			default = Settings:Default(Options.SHOW_ALL_PATH),
			blocked = function()
				return AUI.MerchantWindow:Blocked()
			end,
		})
	end
end
