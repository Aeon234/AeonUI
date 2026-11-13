-- Checks AeonUI_Character outside the game: the settings fields' defaults, enchantable slots, each class's main stat,
-- the durability colors, the equipped average, money text, the extended layout with and without the model and gauges,
-- the page and its place, and nothing hooked or created on a client without the feature. Drawing and the real character
-- panel are not exercised.
-- Run from any directory with Lua 5.1: lua Tools/check_character.lua
-- Loads the real files against the shared stub client. Exits non-zero on the first failed check.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"
local client = assert(loadfile(root .. "Tools/stub_client.lua"))({ project = "forever" })
local Equal = client.Equal

-- Environment ---------------------------------------------------------------------------------------------

CHARACTER = "Character"
SlashCmdList = {}
GREEN_FONT_COLOR = { name = "green" }
YELLOW_FONT_COLOR = { name = "yellow" }
RED_FONT_COLOR = { name = "red" }
C_AddOns = { GetAddOnMetadata = function(_, field)
	return field == "Version" and "dev" or "AeonUI"
end }

local errors = {}
function CallErrorHandler(message)
	errors[#errors + 1] = message
end

-- Addon ---------------------------------------------------------------------------------------------------

local AUI = {}
assert(loadfile(root .. "AeonUI/Core/Core.lua"))("AeonUI", AUI)
AUI.can = { characterPanel = true }

for _, file in ipairs({ "AeonUI/Core/Callbacks.lua", "AeonUI/Core/Events.lua", "AeonUI/Profile/Schema.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })

local values = {}
AUI.Profile = {
	Get = function(_, path)
		local value = values[path]

		if value == nil then
			local field = AUI.Schema:Field(path)
			value = field and field.default
		end

		return value
	end,
}

for _, file in ipairs({ "AeonUI_Character/Character/Options.lua", "AeonUI_Character/Character/Layout.lua",
	"AeonUI_Character/Character/Character.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local Schema, Options, Layout = AUI.Schema, AUI.CharacterOptions, AUI.CharacterLayout

-- Settings ------------------------------------------------------------------------------------------------

local function Default(path)
	return Schema:Field(path).default
end

Equal("on by default", Default(Options.ENABLED_PATH), true)
Equal("the model shown", Default(Options.SHOW_MODEL_PATH), true)
Equal("item level on the icons", Default(Options.ITEM_LEVEL_PATH), true)
Equal("enchants", Default(Options.ENCHANTS_PATH), true)
Equal("a normal quality border", Default(Options.QUALITY_BORDER_PATH), "NORMAL")
Equal("two border choices", table.concat(Options.QUALITY_BORDERS, " "), "NORMAL THICK")
Equal("no durability gauges", Default(Options.GAUGES_PATH), false)
Equal("the average item level", Default(Options.AVERAGE_PATH), true)
Equal("the gear rows", Default(Options.GEAR_ROWS_PATH), true)
Equal("the extra stats", Default(Options.EXTRA_STATS_PATH), true)
Equal("the main stat's band", Default(Options.MAIN_STAT_PATH), true)
Equal("the paths' prefix", Options.ENABLED_PATH, "character.enabled")

-- Rules ---------------------------------------------------------------------------------------------------

Equal("a shield takes an enchant", Options:IsEnchantable(17, "INVTYPE_SHIELD"), true)
Equal("a held-in-off-hand item does", Options:IsEnchantable(17, "INVTYPE_HOLDABLE"), true)
Equal("an off-hand weapon does", Options:IsEnchantable(17, "INVTYPE_WEAPONOFFHAND"), true)
Equal("a main-hand-only weapon in the off hand does not", Options:IsEnchantable(17, "INVTYPE_WEAPONMAINHAND"), false)
Equal("an empty off hand does not", Options:IsEnchantable(17, nil), false)
Equal("the head does not", Options:IsEnchantable(1, "INVTYPE_HEAD"), false)
Equal("the wrists do", Options:IsEnchantable(9, "INVTYPE_WRIST"), true)
Equal("the main hand does", Options:IsEnchantable(16, "INVTYPE_2HWEAPON"), true)
Equal("the ranged slot does not", Options:IsEnchantable(18, "INVTYPE_RANGED"), false)

Equal("a warrior's main stat", Options:MainStat("WARRIOR"), "STRENGTH")
Equal("a rogue's", Options:MainStat("ROGUE"), "AGILITY")
Equal("a hunter's", Options:MainStat("HUNTER"), "AGILITY")
Equal("a mage's", Options:MainStat("MAGE"), "INTELLECT")
Equal("a warlock's", Options:MainStat("WARLOCK"), "INTELLECT")
Equal("a priest's", Options:MainStat("PRIEST"), "INTELLECT")
Equal("none for a druid", Options:MainStat("DRUID"), nil)
Equal("none for a paladin", Options:MainStat("PALADIN"), nil)
Equal("none for a shaman", Options:MainStat("SHAMAN"), nil)
Equal("none for an unknown class", Options:MainStat(nil), nil)

Equal("green from 60%", Options:GaugeColor(0.6).name, "green")
Equal("yellow below", Options:GaugeColor(0.59).name, "yellow")
Equal("yellow at 30%", Options:GaugeColor(0.3).name, "yellow")
Equal("red below 30%", Options:GaugeColor(0.29).name, "red")

local average, counted, slots = Options:EquippedAverage({ [1] = 20, [5] = 12, [4] = 1, [19] = 1 })
Equal("the equipped items' average", average, 16)
Equal("items counted, shirt and tabard left out", counted, 2)
Equal("out of the 17 gear slots", slots, 17)
Equal("no average with nothing worn", (Options:EquippedAverage({})), nil)
Equal("seventeen gear slots", #Options.GEAR_SLOTS, 17)

Equal("gold, silver and copper", Options:MoneyText(14207), "|cffffd7001g|r |cffc7c7cf42s|r |cffeda55f7c|r")
Equal("no gold", Options:MoneyText(507), "|cffc7c7cf5s|r |cffeda55f7c|r")
Equal("an empty middle kept", Options:MoneyText(10007), "|cffffd7001g|r |cffc7c7cf0s|r |cffeda55f7c|r")
Equal("nothing to pay", Options:MoneyText(0), "|cffeda55f0c|r")

-- Layout --------------------------------------------------------------------------------------------------

local shown = Layout:Compute({ model = true, gauges = false })
Equal("the left pane with the model", shown.leftWidth, 634)
Equal("the frame with the model", shown.width, 867)
Equal("its height", shown.height, 504)
Equal("the head", ("%s %s %s"):format(shown.slots[1].x, shown.slots[1].y, shown.slots[1].side), "24 40 LEFT")
Equal("the wrists, the eighth left row", shown.slots[9].y, 362)
Equal("the hands", ("%s %s %s"):format(shown.slots[10].x, shown.slots[10].y, shown.slots[10].side), "20 40 RIGHT")
Equal("a column's text", shown.slots[1].textWidth, 150)
Equal("the main hand", ("%s %s %s %s"):format(shown.slots[16].x, shown.slots[16].y, shown.slots[16].side,
	shown.slots[16].textWidth), "24.5 418 LEFT 133")
Equal("the off hand", shown.slots[17].x, 207.5)
Equal("the ranged slot", shown.slots[18].x, 390.5)
Equal("the ammo slot", ("%s %s %s"):format(shown.slots[Options.AMMO_SLOT].x, shown.slots[Options.AMMO_SLOT].y,
	shown.slots[Options.AMMO_SLOT].side), "573.5 418 LEFT")
Equal("the ammo slot has no text", shown.slots[Options.AMMO_SLOT].textWidth, 0)

local hidden = Layout:Compute({ model = false, gauges = false })
Equal("the left pane without the model", hidden.leftWidth, 440)
Equal("the frame without it", hidden.width, 673)
Equal("its height, 26 below the ranged slot as with the model", hidden.height, 550)
Equal("the main hand continues the left column", ("%s %s %s"):format(hidden.slots[16].x, hidden.slots[16].y,
	hidden.slots[16].side), "24 418 LEFT")
Equal("the off hand the right", ("%s %s %s"):format(hidden.slots[17].x, hidden.slots[17].y, hidden.slots[17].side),
	"20 418 RIGHT")
Equal("the ranged slot below the main hand", ("%s %s"):format(hidden.slots[18].x, hidden.slots[18].y), "24 464")
Equal("the ammo slot on the right", ("%s %s %s"):format(hidden.slots[Options.AMMO_SLOT].x,
	hidden.slots[Options.AMMO_SLOT].y, hidden.slots[Options.AMMO_SLOT].side), "20 464 RIGHT")
Equal("the weapons' full text", hidden.slots[18].textWidth, 150)

Equal("gauges widen each column", Layout:Compute({ model = true, gauges = true }).leftWidth, 652)

-- Settings page -------------------------------------------------------------------------------------------

AUI.Media = { sidebar = {} }
AUI.Settings = { Default = function(_, path)
	return Default(path)
end }

local declared
AUI.Modules = { Register = function(_, module)
	declared = module
end }
assert(loadfile(root .. "AeonUI_Character/Settings/Character.lua"))("AeonUI", AUI)

local page = { sections = {} }
local pageID, pageInfo
AUI.SettingsCharacter:Declare({ Page = function(_, id, info)
	pageID, pageInfo = id, info

	return page
end })

Equal("the page's ID", pageID, "character")
Equal("Blizzard's name for it", pageInfo.title, "Character")
Equal("under Quality of Life", pageInfo.under, "qualityOfLifeHeader")
Equal("its switch", pageInfo.switch.path, Options.ENABLED_PATH)
Equal("its switch's default", pageInfo.switch.default, true)
Equal("its switch's label", pageInfo.switch.label, "Enhance Character")
Equal("available on Forever", AUI.SettingsCharacter:IsAvailable(), true)
Equal("the module's group", declared.group, "qualityOfLife")

-- A client without the feature: nothing hooked or created -------------------------------------------------

AUI.can.characterPanel = false
Equal("not available without it", AUI.SettingsCharacter:IsAvailable(), false)

local framesBefore = #client.frames
declared.start()
Equal("started", AUI.Character.active, true)
Equal("not on without the feature", AUI.Character:IsOn(), false)
Equal("nothing created", #client.frames, framesBefore)

Equal("no Lua error in the run", errors[1], nil)

io.stdout:write(("check_character: %d checks passed\n"):format(client.checks))
