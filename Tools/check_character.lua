-- Checks AeonUI_Character outside the game: the settings fields' defaults, enchantable slots, each class's main stat,
-- the durability colors, the equipped average, money text, the extended layout with and without the model and gauges,
-- each slot's item against stubbed item APIs and the gear summary, the extended frame on a stand-in character frame
-- (each tab, Blizzard's right pane toggle, the model, combat, off, the Gamepad style, on again), the dressed slots
-- (outline, item level, name and enchant, empty slots, gauges, a held item, a fade, and their restore),
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
GREEN_FONT_COLOR = { name = "green", r = 0, g = 1, b = 0 }
YELLOW_FONT_COLOR = { name = "yellow", r = 1, g = 1, b = 0 }
RED_FONT_COLOR = { name = "red", r = 1, g = 0, b = 0 }
ENCHANTED_TOOLTIP_LINE = "Enchanted: %s"
NORMAL_FONT_COLOR = { name = "gold" }
function UnitPVPName(unit)
	assert(unit == "player")

	return "Baraque Pecheloin"
end

local gamepad = false
InputUtil = { IsGamepadUIEnabled = function()
	return gamepad
end }

-- Blizzard's character frame as Forever builds it: the sizes, the left pane, the slot buttons and their anchors, the
-- model, the level line, and the methods the feature hooks.
CHARACTER_FRAME_WIDTH, CHARACTER_FRAME_COLLAPSED_WIDTH, CHARACTER_FRAME_HEIGHT = 631, 398, 484
CharacterFrame = CreateFrame("Frame", "CharacterFrame")
CharacterFrame:Hide()
CharacterFrame.activeSubframe = "PaperDollFrame"
CharacterFrame.LeftPaneHost = CreateFrame("Frame", "CharacterFrameLeftPaneHost", CharacterFrame)
CharacterFrame.LeftPaneHost:SetWidth(398)
function CharacterFrame:IsRightPaneCollapsed()
	return self.rightPaneCollapsed == true
end
function CharacterFrame:UpdateSize()
	local width = self:IsRightPaneCollapsed() and CHARACTER_FRAME_COLLAPSED_WIDTH or CHARACTER_FRAME_WIDTH
	self:SetSize(width, CHARACTER_FRAME_HEIGHT)
end
function CharacterFrame:SetTitle(title)
	self.title = title
end
function CharacterFrame:SetTitleColor(color)
	self.titleColor = color
end
function CharacterFrame:UpdateTitle()
	self:SetTitleColor({ name = "white" })
	self:SetTitle(UnitPVPName("player"))
end
PaperDollFrame = CreateFrame("Frame", "PaperDollFrame", CharacterFrame)
PaperDollFrame.TopBackgroundStripHost = CreateFrame("Frame", nil, PaperDollFrame)
PaperDollLevelInfo = CreateFrame("Frame", "PaperDollLevelInfo", PaperDollFrame)
PaperDollLevelInfo:SetPoint("CENTER", PaperDollFrame.TopBackgroundStripHost, "CENTER", 0, -2)
CharacterModelScene = CreateFrame("Frame", "CharacterModelScene", PaperDollFrame)
CharacterModelScene:SetPoint("TOPLEFT", PaperDollFrame.TopBackgroundStripHost, "BOTTOMLEFT")
CharacterModelScene:SetPoint("BOTTOMRIGHT", CharacterFrame.LeftPaneHost, "BOTTOMRIGHT")
for _, key in ipairs({ "BackgroundTopLeft", "BackgroundTopRight", "BackgroundBotLeft", "BackgroundBotRight" }) do
	CharacterModelScene[key] = CharacterModelScene:CreateTexture()
	CharacterModelScene[key]:SetPoint("TOPLEFT", CharacterModelScene, "TOPLEFT", 1, -1)
end
CharacterModelScene.BackgroundOverlay = CharacterModelScene:CreateTexture()
CharacterModelScene.BackgroundOverlay:SetAllPoints()

local SLOT_BUTTONS = {
	[1] = "CharacterHeadSlot", [2] = "CharacterNeckSlot", [3] = "CharacterShoulderSlot", [4] = "CharacterShirtSlot",
	[5] = "CharacterChestSlot", [6] = "CharacterWaistSlot", [7] = "CharacterLegsSlot", [8] = "CharacterFeetSlot",
	[9] = "CharacterWristSlot", [10] = "CharacterHandsSlot", [11] = "CharacterFinger0Slot",
	[12] = "CharacterFinger1Slot", [13] = "CharacterTrinket0Slot", [14] = "CharacterTrinket1Slot",
	[15] = "CharacterBackSlot", [16] = "CharacterMainHandSlot", [17] = "CharacterSecondaryHandSlot",
	[18] = "CharacterRangedSlot", [19] = "CharacterTabardSlot", [0] = "CharacterAmmoSlot",
}
for slot, name in pairs(SLOT_BUTTONS) do
	local button = CreateFrame("Button", name, PaperDollFrame)
	button:SetSize(40, 40)
	button:SetPoint("TOPLEFT", CharacterFrame.LeftPaneHost, "TOPLEFT", slot, -60 - slot)
	button:SetID(slot)
	button.icon = button:CreateTexture()
	button.icon:SetTexCoord(0, 1, 0, 1)
	button.IconBorder = button:CreateTexture()
	if slot == 0 then
		button.slotFrame = button:CreateTexture()
		button.slotFrame:SetAtlas("UI-Character-Info-GearSlotSmall")
	else
		button.BorderFrame = CreateFrame("Frame", nil, button)
	end
	_G[name:sub(10):upper()] = name:sub(10, -5)
end
-- Blizzard's update: the icon untinted, as for an empty or unbroken item.
function PaperDollItemSlotButton_Update(button)
	button.icon:SetVertexColor(1, 1, 1)
	button.icon:SetTexCoord(0, 1, 0, 1)
end
ITEM_QUALITY_COLORS = { [2] = { r = 0.1, g = 1, b = 0 }, [3] = { r = 0, g = 0.44, b = 0.87 } }
local holding, fits = false, {}
function CursorHasItem()
	return holding
end
C_PaperDollInfo = { CursorCanGoInSlot = function(slot)
	return fits[slot] == true
end }
CharacterAmmoSlot:SetSize(27, 27)
Enum = { TooltipDataLineType = { ItemEnchantmentPermanent = 15 } }

-- Equipped items by slot: link, quality, item level, equip location, durability and tooltip data (nil while the item
-- is not cached).
local worn = {}
local function Link(id, name, enchant)
	return ("|cff0070dd|Hitem:%d:%s::::::::40:1:::::::|h[%s]|h|r"):format(id, enchant or "", name)
end
function GetInventoryItemLink(unit, slot)
	assert(unit == "player")

	return worn[slot] and worn[slot].link
end
function GetInventoryItemTexture(unit, slot)
	assert(unit == "player")

	return worn[slot] and (worn[slot].texture or 134400)
end
function GetInventoryItemQuality(_, slot)
	return worn[slot] and worn[slot].quality
end
function GetInventoryItemDurability(slot)
	local item = worn[slot]

	if item and item.maximum then
		return item.current, item.maximum
	end
end
local function ByLink(link)
	for _, item in pairs(worn) do
		if item.link == link then
			return item
		end
	end
end
C_Item = {
	GetDetailedItemLevelInfo = function(link)
		local item = ByLink(link)

		return item and item.level
	end,
	GetItemInfoInstant = function(link)
		local item = ByLink(link)

		return 1, "Armor", "Plate", item and item.equipLoc
	end,
}
C_TooltipInfo = { GetInventoryItem = function(unit, slot)
	assert(unit == "player")

	return worn[slot] and worn[slot].tooltip
end }
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
	"AeonUI_Character/Character/Gear.lua", "AeonUI_Character/Character/Slots.lua", "AeonUI_Character/Character/Frame.lua",
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
Equal("the model centered, under the top strip, down to the weapon row", ("%s %s %s %s"):format(
	shown.model.x, shown.model.y, shown.model.width, shown.model.height), "67 36 500 382")

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
Equal("no model column", hidden.model, nil)

Equal("gauges widen each column", Layout:Compute({ model = true, gauges = true }).leftWidth, 652)

-- Gear --------------------------------------------------------------------------------------------------------

local Gear = AUI.CharacterGear
local LINE = Enum.TooltipDataLineType.ItemEnchantmentPermanent

worn[1] = { link = Link(101, "Helm of the Bulwark"), quality = 3, level = 41, equipLoc = "INVTYPE_HEAD", current = 45,
	maximum = 45, tooltip = { lines = { { type = 0, leftText = "Helm of the Bulwark" } }, repairCost = 0 } }
worn[5] = { link = Link(105, "Breastplate of the Vanguard"), quality = 3, level = 42, equipLoc = "INVTYPE_CHEST",
	current = 30, maximum = 45, tooltip = { lines = { { type = LINE, leftText = "Enchanted: +4 All Stats" } },
	repairCost = 85 } }
worn[9] = { link = Link(109, "Engraved Bracers", "1883"), quality = 2, level = 35, equipLoc = "INVTYPE_WRIST",
	current = 0, maximum = 45, tooltip = { lines = {}, repairCost = 300 } }
worn[10] = { link = Link(110, "Polar Gauntlets"), quality = 2, level = 37, equipLoc = "INVTYPE_HAND",
	current = client.Secret(), maximum = 35, tooltip = { lines = {} } }
worn[7] = { link = Link(107, "Legguards of the Marsh"), quality = 3, equipLoc = "INVTYPE_LEGS" }

local helm = Gear:Read(1)
Equal("the name from the link", helm.name, "Helm of the Bulwark")
Equal("its quality", helm.quality, 3)
Equal("its item level", helm.itemLevel, 41)
Equal("its equip location", helm.equipLoc, "INVTYPE_HEAD")
Equal("the head takes no enchant", helm.enchantable, false)
Equal("and has none", helm.enchant, nil)
Equal("full durability", ("%s/%s"):format(helm.current, helm.maximum), "45/45")

local chest = Gear:Read(5)
Equal("the enchant's effect", chest.enchant, "+4 All Stats")
Equal("the chest takes one", chest.enchantable, true)
Equal("its repair cost", chest.repair, 85)

Equal("an enchant known only from the link", Gear:Read(9).enchant, "Enchanted")
Equal("an empty slot", Gear:Read(4), nil)
Equal("secret durability left out", Gear:Read(10).current, nil)
Equal("no enchant on the hands", Gear:Read(10).enchant, nil)

local legs = Gear:Read(7)
Equal("an uncached item keeps its name", legs.name, "Legguards of the Marsh")
Equal("and its quality", legs.quality, 3)
Equal("but no item level yet", legs.itemLevel, nil)
Equal("nor a repair cost", legs.repair, 0)

local summary = Gear:Summary()
Equal("enchanted", summary.enchanted, 2)
Equal("of the enchantable items worn", summary.enchantable, 3)
Equal("the lowest durability", summary.lowest, 0)
Equal("the broken bracers damaged", summary.damaged[9], true)
Equal("the worn chest damaged", summary.damaged[5], true)
Equal("the full helm not", summary.damaged[1], nil)
Equal("the secret gauntlets not counted", summary.damaged[10], nil)
Equal("the repair costs added", summary.repair, 385)
Equal("the item levels by slot", ("%s %s"):format(tostring(summary.levels[1]), tostring(summary.levels[7])), "41 nil")

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
Equal("under Windows", pageInfo.under, "windowsHeader")
Equal("its switch", pageInfo.switch.path, Options.ENABLED_PATH)
Equal("its switch's default", pageInfo.switch.default, true)
Equal("its switch's label", pageInfo.switch.label, "Enhance Character")
Equal("available on Forever", AUI.SettingsCharacter:IsAvailable(), true)
Equal("the module's group", declared.group, "windows")

-- A client without the feature: nothing hooked or created -------------------------------------------------

AUI.can.characterPanel = false
Equal("not available without it", AUI.SettingsCharacter:IsAvailable(), false)

local framesBefore = #client.frames
declared.start()
Equal("started", AUI.Character.active, true)
Equal("not on without the feature", AUI.Character:IsOn(), false)
Equal("nothing created", #client.frames, framesBefore)

-- Extended frame ----------------------------------------------------------------------------------------------

local function Set(path, value)
	values[path] = value
	AUI.Callbacks:Fire("Profile", path)
	client:RunTimers()
end

local function Size()
	return ("%sx%s"):format(rawget(CharacterFrame, "width"), rawget(CharacterFrame, "height"))
end

local function Anchor(button)
	local point, relative, relativePoint, x, y = button:GetPoint(1)

	return ("%s %s %s %s %s"):format(point, relative == CharacterFrame.LeftPaneHost and "pane" or tostring(relative),
		relativePoint, x, y)
end

local scene = CharacterModelScene
local topLeft, botRight = rawget(scene, "BackgroundTopLeft"), rawget(scene, "BackgroundBotRight")

-- Whether the model scene and its race backdrop are anchored as Blizzard anchors them.
local function NativeModel()
	return select(2, scene:GetPoint(1)) == PaperDollFrame.TopBackgroundStripHost and scene:GetNumPoints() == 2
		and select(2, topLeft:GetPoint(1)) == scene
		and select(2, botRight:GetPoint(1)) == scene
		and select(2, scene.BackgroundOverlay:GetPoint(1)) == scene
end

local function Native()
	return NativeModel() and Size() == "631x484" and rawget(CharacterFrame.LeftPaneHost, "width") == 398 and Anchor(CharacterHeadSlot)
		== "TOPLEFT pane TOPLEFT 1 -61" and Anchor(CharacterHandsSlot) == "TOPLEFT pane TOPLEFT 10 -70"
		and rawget(CharacterAmmoSlot, "width") == 27 and CharacterModelScene:IsShown() and #rawget(CharacterHeadSlot, "points") == 1
		and select(5, PaperDollLevelInfo:GetPoint(1)) == -2
end

local Window = AUI.CharacterFrame
client.hooks = 0
AUI.can.characterPanel = true
values[Options.ENABLED_PATH] = nil
Set(Options.ENABLED_PATH, true)
Equal("the frame's methods and the slot update hooked once the feature is on", client.hooks, 3)

CharacterFrame:Show()
CharacterFrame:UpdateSize()
Equal("widened with the model", Size(), "867x504")
Equal("the left pane widened", rawget(CharacterFrame.LeftPaneHost, "width"), 634)
Equal("the head placed", Anchor(CharacterHeadSlot), "TOPLEFT pane TOPLEFT 24 -40")
Equal("one anchor each", #rawget(CharacterHeadSlot, "points"), 1)
Equal("the hands from the right", Anchor(CharacterHandsSlot), "TOPRIGHT pane TOPRIGHT -20 -40")
Equal("the main hand in the weapon row", Anchor(CharacterMainHandSlot), "TOPLEFT pane TOPLEFT 24.5 -418")
Equal("the ammo slot full size", ("%sx%s"):format(rawget(CharacterAmmoSlot, "width"), rawget(CharacterAmmoSlot, "height")), "40x40")
Equal("is extended", Window:IsExtended(), true)
Equal("the model centered", Anchor(scene), "TOPLEFT pane TOPLEFT 67 -36")
Equal("one anchor", scene:GetNumPoints(), 1)
Equal("its size", ("%sx%s"):format(rawget(scene, "width"), rawget(scene, "height")), "500x382")
local backdrop = select(2, topLeft:GetPoint(1))
Equal("the race backdrop kept on the whole pane", backdrop ~= scene and select(2, backdrop:GetPoint(1)),
	PaperDollFrame.TopBackgroundStripHost)
Equal("each corner keeps its offsets", select(4, botRight:GetPoint(1)), 1)
Equal("the overlay too", select(2, scene.BackgroundOverlay:GetPoint(1)), backdrop)

CharacterFrame:UpdateTitle()
Equal("the title names the panel", CharacterFrame.title, "Character")
Equal("in gold", CharacterFrame.titleColor.name, "gold")
Equal("the name moved into the pane", Window.nameText:GetText(), "Baraque Pecheloin")
Equal("and shown", Window.nameText:IsShown(), true)
Equal("the level line moved below it", select(5, PaperDollLevelInfo:GetPoint(1)), -11)

CharacterFrame.rightPaneCollapsed = true
CharacterFrame:UpdateSize()
Equal("Blizzard's toggle collapses to the left pane", Size(), "634x504")
CharacterFrame.rightPaneCollapsed = false
CharacterFrame:UpdateSize()
Equal("and expands to both panes", Size(), "867x504")

Set(Options.SHOW_MODEL_PATH, false)
Equal("narrowed without the model", Size(), "673x550")
Equal("the model hidden", CharacterModelScene:IsShown(), false)
Equal("the off hand continues the right column", Anchor(CharacterSecondaryHandSlot), "TOPRIGHT pane TOPRIGHT -20 -418")
Set(Options.SHOW_MODEL_PATH, true)
Equal("the model back", CharacterModelScene:IsShown(), true)
Equal("widened again", Size(), "867x504")

client:SetCombat(true)
CharacterFrame:UpdateSize()
Equal("in combat too, since none of these frames is protected", Size(), "867x504")
client:SetCombat(false)

CharacterFrame.activeSubframe = "ReputationFrame"
CharacterFrame:UpdateSize()
Equal("another tab gets Blizzard's frame back", Native(), true)
CharacterFrame:UpdateTitle()
Equal("and Blizzard's title", CharacterFrame.title, "Baraque Pecheloin")
Equal("the name in the pane hidden", Window.nameText:IsShown(), false)
CharacterFrame.activeSubframe = "PaperDollFrame"
CharacterFrame:UpdateSize()
Equal("the Character tab widens again", Size(), "867x504")

Set(Options.ENABLED_PATH, false)
Equal("turned off with the panel open, everything is Blizzard's", Native(), true)
Equal("Blizzard's title back", CharacterFrame.title, "Baraque Pecheloin")
Equal("not extended", Window:IsExtended(), false)

gamepad = true
Set(Options.ENABLED_PATH, true)
Equal("nothing changed under the Gamepad style", Native(), true)
gamepad = false
Set(Options.ENABLED_PATH, true)
Equal("on again", Size(), "867x504")
Equal("hooks installed once", client.hooks, 3)

CharacterFrame:Hide()
Set(Options.ENABLED_PATH, false)
Equal("a closed panel restored too", Native(), true)
Set(Options.ENABLED_PATH, true)
Equal("a closed panel is left until it opens", Native(), true)

-- Slots ---------------------------------------------------------------------------------------------------

local Slots = AUI.CharacterSlots
local TEXTURES = "Interface\\AddOns\\AeonUI\\Media\\Textures\\"

local function Part(button, key)
	return Slots.parts[button] and Slots.parts[button][key]
end

local function Color(region)
	return table.concat(region.vertex or region.textColor or {}, " ")
end

local function Shown(region)
	return region ~= nil and region:IsShown()
end

CharacterFrame:Show()
CharacterFrame:UpdateSize()
Equal("the slots painted as the panel widens", Shown(Part(CharacterHeadSlot, "outline")), true)

do
local helm, chest, wrists, shirt = CharacterHeadSlot, CharacterChestSlot, CharacterWristSlot, CharacterShirtSlot
PaperDollItemSlotButton_Update(helm)
Equal("a filled slot's outline, 2 units", Part(helm, "outline"):GetTexture(), TEXTURES .. "QualityOutline2")
Equal("in its quality's color", Color(Part(helm, "outline")), "0 0.44 0.87")
Equal("its shadow", Part(helm, "shadow"):GetTexture() .. " " .. tostring(Part(helm, "shadow"):IsShown()),
	TEXTURES .. "QualityShadow true")
Equal("its inner shade", Part(helm, "shade"):GetTexture() .. " " .. tostring(Part(helm, "shade"):IsShown()),
	TEXTURES .. "IconShade true")
Equal("the icon cropped", table.concat({ helm.icon:GetTexCoord() }, " "), "0.08 0.92 0.08 0.92")
Equal("Blizzard's border and slot frame clear", helm.IconBorder:GetAlpha() .. " " .. helm.BorderFrame:GetAlpha(), "0 0")
Equal("the item level on the icon", Part(helm, "level"):GetText(), "41")
Equal("the name", Part(helm, "name"):GetText(), "Helm of the Bulwark")
Equal("in its quality's color", Color(Part(helm, "name")), "0 0.44 0.87")
Equal("the name beside the icon, text toward the middle", Part(helm, "name").justifyH, "LEFT")
Equal("no enchant line on the head", Shown(Part(helm, "enchant")), false)

PaperDollItemSlotButton_Update(chest)
Equal("the chest's enchant", Part(chest, "enchant"):GetText(), "+4 All Stats")
Equal("in green", Color(Part(chest, "enchant")), "0 1 0")
PaperDollItemSlotButton_Update(CharacterHandsSlot)
Equal("the hands' text left of the icon", Part(CharacterHandsSlot, "name").justifyH, "RIGHT")
Equal("enchantable and bare", Part(CharacterHandsSlot, "enchant"):GetText(), "No Enchant")
Equal("in red", Color(Part(CharacterHandsSlot, "enchant")), "1 0 0")

PaperDollItemSlotButton_Update(shirt)
Equal("an empty slot keeps Blizzard's frame shape", Part(shirt, "outline"):GetTexture(),
	"Interface\\Common\\WhiteIconFrame")
Equal("in dark gray", Color(Part(shirt, "outline")), "0.23 0.23 0.24")
Equal("its icon a dark well", Color(shirt.icon) .. " " .. shirt.icon:GetAlpha(), "0 0 0 0.55")
Equal("its slot's name", Part(shirt, "name"):GetText(), "Shirt")
Equal("in gray", Color(Part(shirt, "name")), "0.5 0.5 0.5")
Equal("no shadow, shade, level or enchant", tostring(Shown(Part(shirt, "shadow"))) .. tostring(Shown(Part(shirt,
	"shade"))) .. tostring(Shown(Part(shirt, "level"))) .. tostring(Shown(Part(shirt, "enchant"))), "falsefalsefalsefalse")
worn[0] = { texture = 132382, quality = 1 }
local ammo = CharacterAmmoSlot
PaperDollItemSlotButton_Update(ammo)
Equal("the ammo slot has no text", Shown(Part(ammo, "name")), false)
Equal("ammo, worn without a link, is a filled slot", Part(ammo, "outline"):GetTexture() .. " " .. ammo.icon:GetAlpha(),
	TEXTURES .. "QualityOutline2 1")
Equal("in white for a quality without a color", Color(Part(ammo, "outline")), "1 1 1")
Equal("its small slot frame cleared", rawget(ammo, "slotFrame"):GetAlpha(), 0)

Set(Options.QUALITY_BORDER_PATH, "THICK")
Equal("Thick, 3 units", Part(helm, "outline"):GetTexture(), TEXTURES .. "QualityOutline3")
Set(Options.ITEM_LEVEL_PATH, false)
Equal("no item level when off", Shown(Part(helm, "level")), false)
Set(Options.ENCHANTS_PATH, false)
Equal("no enchant line when off", Shown(Part(chest, "enchant")), false)
Equal("no gauge by default", Shown(Part(chest, "gauge")), false)
Set(Options.GAUGES_PATH, true)
Equal("the chest's gauge, two thirds full", Shown(Part(chest, "gauge")) and Part(chest, "fill").height, 40 * (30 / 45))
Equal("in green", Color(Part(chest, "fill")), "0 1 0")
Equal("the broken wrists' gauge empty, in red", Part(wrists, "fill").height .. " " .. Color(Part(wrists, "fill")), "0 1 0 0")
Equal("none for the empty shirt", Shown(Part(shirt, "gauge")), false)
Set(Options.GAUGES_PATH, false)
Set(Options.ENCHANTS_PATH, true)
Set(Options.ITEM_LEVEL_PATH, true)
Set(Options.QUALITY_BORDER_PATH, "NORMAL")

holding, fits = true, { [11] = true, [12] = true }
client:Fire("CURSOR_CHANGED")
client:RunTimers()
Equal("holding a ring, the finger slots stay", CharacterFinger0Slot:GetAlpha() .. " " .. CharacterFinger1Slot:GetAlpha(),
	"1 1")
Equal("the rest dim", helm:GetAlpha(), 0.55)
holding, fits = false, {}
client:Fire("CURSOR_CHANGED")
client:RunTimers()
Equal("put down, all back", helm:GetAlpha(), 1)

Slots:SetFade(function(slot)
	return slot == 9
end, 0.3)
Equal("a fade keeps the slots it names", wrists:GetAlpha() .. " " .. helm:GetAlpha(), "1 0.3")
Slots:SetFade(nil)
Equal("and clears", helm:GetAlpha(), 1)

CharacterFrame.activeSubframe = "ReputationFrame"
CharacterFrame:UpdateSize()
Equal("another tab restores the slots", tostring(Shown(Part(helm, "overlay"))) .. " " .. table.concat({
	helm.icon:GetTexCoord() }, " ") .. " " .. helm.IconBorder:GetAlpha() .. " " .. helm.BorderFrame:GetAlpha(),
	"false 0 1 0 1 1 1")
Equal("the empty well undone", Color(shirt.icon) .. " " .. shirt.icon:GetAlpha(), "1 1 1 1")
Equal("the ammo slot's frame back", rawget(CharacterAmmoSlot, "slotFrame"):GetAlpha(), 1)
PaperDollItemSlotButton_Update(helm)
Equal("Blizzard's updates leave other tabs alone", Shown(Part(helm, "overlay")), false)
CharacterFrame.activeSubframe = "PaperDollFrame"
CharacterFrame:UpdateSize()
Set(Options.ENABLED_PATH, false)
Equal("off restores them too", Shown(Part(helm, "overlay")), false)
Equal("and stops following the cursor", AUI.Callbacks:Count("event:CURSOR_CHANGED"), 0)
end

Equal("no Lua error in the run", errors[1], nil)

io.stdout:write(("check_character: %d checks passed\n"):format(client.checks))
