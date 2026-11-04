-- Checks MerchantWindow/ outside the game: the grid's cells in each fill order, slot places, the window's size, pages
-- and the page kept in range, then the module against a stubbed merchant window: nothing hooked while off, the grid
-- drawn after Blizzard's update with each slot filled or empty as Blizzard fills its own, the page controls corrected
-- (Forever's gamepad indicators too), Blizzard's bottom section kept at the left (money, currencies, the junk button
-- without repairs, the last item sold, the next page button at the right), a quantity window closed when its slot
-- changes item, item quality redrawn, the buyback tab and turning off giving Blizzard's slots, size and anchors back,
-- Show All Items setting the filter as the window opens, and standing down for Krowi's Extended Vendor UI.
-- Run from any directory with Lua 5.1: lua Tools/check_merchantwindow.lua
-- Loads the real files against the shared stub client. Exits non-zero on the first failed check.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"
local client = assert(loadfile(root .. "Tools/stub_client.lua"))({ project = "retail" })
local Equal = client.Equal

-- Environment ---------------------------------------------------------------------------------------------

SlashCmdList = {}
MAX_ITEM_COST = 3
MERCHANT_PAGE_NUMBER = "Page %s of %s"
TEXTURE_ITEM_QUEST_BANG = "bang"

local loaded = {}
C_AddOns = {
	GetAddOnMetadata = function(name, field)
		if name == "Krowi_ExtendedVendorUI" and field == "Title" then
			return "Krowi's Extended Vendor UI"
		end

		return field == "Version" and "dev" or "AeonUI"
	end,
	IsAddOnLoaded = function(name)
		return loaded[name] == true
	end,
}

function CallErrorHandler(message)
	error(message, 0)
end

local MakeFrame = CreateFrame

---A slot from MerchantItemTemplate: its named parts, as the template's `$parent` names make them.
local function MerchantItem(name)
	local slot = MakeFrame("Frame", name, MerchantFrame)

	slot.Name = slot:CreateFontString(nil, "BACKGROUND", "GameFontNormalSmall")
	slot.ItemButton = MakeFrame("Button", name .. "ItemButton", slot)
	slot.ItemButton.IconQuestTexture = slot.ItemButton:CreateTexture()
	slot.ItemButton.IconQuestTexture:Hide()
	MakeFrame("Frame", name .. "MoneyFrame", slot):Hide()
	MakeFrame("Frame", name .. "AltCurrencyFrame", slot):Hide()

	for cost = 1, MAX_ITEM_COST do
		local item = MakeFrame("Button", name .. "AltCurrencyFrameItem" .. cost, slot)

		item:SetWidth(10)
		item:Hide()
	end

	return slot
end

local created = {}
function CreateFrame(kind, name, parent, template)
	if template == "MerchantItemTemplate" then
		assert(kind == "Frame" and parent == MerchantFrame, "slots are frames on the merchant window")
		created[#created + 1] = name

		return MerchantItem(name)
	end

	return MakeFrame(kind, name, parent, template)
end

---A named part of the merchant window.
local function Part(kind, name, shown)
	local part = MakeFrame(kind, name, MerchantFrame)

	if shown == false then
		part:Hide()
	end

	return part
end

MerchantFrame = MakeFrame("Frame", "MerchantFrame", UIParent)
MerchantFrame:Hide()
MerchantFrame.selectedTab, MerchantFrame.page = 1, 1
MerchantFrame:SetSize(336, 444)
for number = 1, 12 do
	MerchantItem("MerchantItem" .. number)
end
MerchantPageText = MerchantFrame:CreateFontString(nil, "BORDER", "GameFontNormal")
MerchantPageText:Hide()
MerchantFrameBottomLeftBorder = MerchantFrame:CreateTexture()
local MerchantPrevPageButton = Part("Button", "MerchantPrevPageButton", false)
local MerchantNextPageButton = Part("Button", "MerchantNextPageButton", false)
local MerchantMoneyInset = Part("Frame", "MerchantMoneyInset")
local MerchantMoneyBg = Part("Frame", "MerchantMoneyBg")
local MerchantMoneyFrame = Part("Frame", "MerchantMoneyFrame")
local MerchantToken1 = Part("Button", "MerchantToken1")
local MerchantBuyBackItem = Part("Frame", "MerchantBuyBackItem")
local MerchantRepairAllButton = Part("Button", "MerchantRepairAllButton")
local MerchantRepairItemButton = Part("Button", "MerchantRepairItemButton")
local MerchantGuildBankRepairButton = Part("Button", "MerchantGuildBankRepairButton", false)
local MerchantSellAllJunkButton = Part("Button", "MerchantSellAllJunkButton")
local canRepair, canGuildRepair = true, false
function CanMerchantRepair()
	return canRepair
end
function CanGuildBankRepair()
	return canGuildRepair
end

-- The merchant's items, by index.
local items = {}
local costs = {}
local heirlooms = {}
local currencies = {}
C_MerchantFrame = {
	GetItemInfo = function(index)
		return items[index]
	end,
	IsMerchantItemRefundable = function()
		return true
	end,
	GetMerchantCurrencies = function()
		return currencies
	end,
}

-- The merchant's filter, as Blizzard's show resets it: the class's items.
LE_LOOT_FILTER_CLASS, LE_LOOT_FILTER_ALL = 1, 5
local filter, filterHidden = LE_LOOT_FILTER_CLASS, false
function GetMerchantFilter()
	return filter
end
function SetMerchantFilter(value)
	filter = value
end
Enum = { GameRule = { MerchantFilterDisabled = 7 } }
C_GameRules = { IsGameRuleActive = function(rule)
	return rule == 7 and filterHidden
end }
-- The grid reads this once a draw.
local draws = 0
function GetMerchantNumItems()
	draws = draws + 1

	return #items
end
function CanAffordMerchantItem(index)
	return items[index].afford ~= false
end
function GetMerchantItemLink(index)
	return "link" .. index
end
function GetMerchantItemID(index)
	return 1000 + index
end
function GetMerchantItemCostInfo(index)
	return costs[index] and #costs[index] or 0
end
function GetMerchantItemCostItem(index, cost)
	local item = costs[index] and costs[index][cost]
	if item then
		return item.texture, item.value, item.link
	end
end
C_Heirloom = {
	IsItemHeirloom = function(id)
		return heirlooms[id] ~= nil
	end,
	PlayerHasHeirloom = function(id)
		return heirlooms[id] == true
	end,
}
CurrencyContainerUtil = {
	GetCurrencyContainerInfo = function(_, amount, name, texture)
		return name .. " (container)", texture, amount
	end,
}

function SetItemButtonCount(button, count) button.count = count end
function SetItemButtonStock(button, stock) button.stock = stock end
function SetItemButtonTexture(button, texture) button.icon = texture end
function SetItemButtonDesaturated(button, value) button.desaturated = value and true or false end
function SetItemButtonNameFrameVertexColor(slot, r, g, b) slot.nameColor = ("%g %g %g"):format(r, g, b) end
function SetItemButtonSlotVertexColor(slot, r, g, b) slot.slotColor = ("%g %g %g"):format(r, g, b) end
function SetItemButtonTextureVertexColor(button, r, g, b) button.iconColor = ("%g %g %g"):format(r, g, b) end
function SetItemButtonNormalTextureVertexColor(button, r, g, b) button.normalColor = ("%g %g %g"):format(r, g, b) end
function MoneyFrame_SetMaxDisplayWidth(frame, width) frame.maxWidth = width end
function MoneyFrame_Update(name, price) _G[name].price = price end
function SetMoneyFrameColor(name, color) _G[name].color = color end
function AltCurrencyFrame_Update(name, texture, value) _G[name].cost = texture .. "x" .. value end
local qualities = {}
function MerchantFrameItem_UpdateQuality(slot, link)
	qualities[#qualities + 1] = slot:GetName() .. "=" .. tostring(link)
end

StackSplitFrame = MakeFrame("Frame", "StackSplitFrame", UIParent)
StackSplitFrame:Hide()
local splitCancels = 0
function StackSplitCancelButton_OnClick()
	splitCancels = splitCancels + 1
	StackSplitFrame:Hide()
end

-- Blizzard's update: its tab's draw function.
local updates = 0
function MerchantFrame_UpdateMerchantInfo()
	-- Blizzard shows its page controls past ten items and hides its buyback slots.
	local paged = #items > 10
	MerchantPageText:SetShown(paged)
	MerchantPrevPageButton:SetShown(paged)
	MerchantNextPageButton:SetShown(paged)
	MerchantItem11:Hide()
	MerchantItem12:Hide()
	MerchantFrame_UpdateRepairButtons()
	MerchantBuyBackItem:Show()
	MerchantFrameBottomLeftBorder:Show()
end
-- Blizzard anchors the buttons again without clearing them first.
function MerchantFrame_UpdateRepairButtons()
	if canRepair then
		MerchantRepairAllButton:SetPoint("BOTTOMRIGHT", MerchantFrame, "BOTTOMLEFT", 118, 33)
		MerchantRepairItemButton:SetPoint("RIGHT", MerchantRepairAllButton, "LEFT", -8, 0)
		MerchantSellAllJunkButton:SetPoint("RIGHT", MerchantRepairAllButton, "LEFT", 80, 0)
	else
		MerchantSellAllJunkButton:SetPoint("BOTTOMRIGHT", MerchantFrame, "BOTTOMRIGHT", -148, 33)
	end
	MerchantGuildBankRepairButton:SetShown(canGuildRepair)
end
function MerchantFrame_UpdateBuybackInfo()
	MerchantItem11:Show()
	MerchantItem12:Show()
	MerchantRepairAllButton:Hide()
	MerchantRepairItemButton:Hide()
	MerchantBuyBackItem:Hide()
	MerchantFrameBottomLeftBorder:Hide()
end
function MerchantFrame_UpdateItemQualityBorders() end
function MerchantFrame_Update()
	updates = updates + 1
	if MerchantFrame.selectedTab == 1 then
		MerchantFrame_UpdateMerchantInfo()
	else
		MerchantFrame_UpdateBuybackInfo()
	end
end

local UPDATES = { "MerchantFrame_UpdateMerchantInfo", "MerchantFrame_UpdateBuybackInfo",
	"MerchantFrame_UpdateItemQualityBorders" }
local stock = {}
for _, name in ipairs(UPDATES) do
	stock[name] = _G[name]
end

---@return number hooked how many of Blizzard's three updates a hook has replaced
local function HookedUpdates()
	local hooked = 0

	for _, name in ipairs(UPDATES) do
		if _G[name] ~= stock[name] then
			hooked = hooked + 1
		end
	end

	return hooked
end

-- Addon table ---------------------------------------------------------------------------------------------

local AUI = {}
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
assert(loadfile(root .. "AeonUI/Core/Core.lua"))("AeonUI", AUI)
AUI.can = { merchantWindow = true }

for _, file in ipairs({ "AeonUI/Core/Callbacks.lua", "AeonUI/Core/Events.lua", "AeonUI/Profile/Schema.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local values = {}
AUI.Profile = {
	Get = function(_, path)
		local value = values[path]
		local field = AUI.Schema:Field(path)

		if value == nil then
			value = field and field.default
		end

		return value
	end,
}

local function Set(path, value)
	values[path] = value
	AUI.Callbacks:Fire("Profile", path)
	client:RunTimers()
end

for _, file in ipairs({ "AeonUI_QoL/MerchantWindow/Options.lua", "AeonUI_QoL/MerchantWindow/BottomBar.lua", "AeonUI_QoL/MerchantWindow/MerchantWindow.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local Options, MerchantWindow = AUI.MerchantWindowOptions, AUI.MerchantWindow

-- Helpers -------------------------------------------------------------------------------------------------

local function Cell(slot, rows, columns, order)
	local row, column = Options:Cell(slot, rows, columns, order)

	return row .. "," .. column
end

local function Size(frame)
	return frame.width .. "x" .. frame.height
end

local function Point(region)
	return table.concat(region.points[1], " ", 1, 1) .. " " .. table.concat(
		{ tostring(region.points[1][#region.points[1] - 1]), tostring(region.points[1][#region.points[1]]) }, " ")
end

---@return string anchor the region's anchor at `point`: the point, what it is relative to, and its offsets
local function PointOf(region, point)
	for _, anchor in ipairs(region.points) do
		if anchor[1] == point then
			local relative = "parent"

			if #anchor == 5 then
				local to = anchor[2]
				local name = to == MerchantFrame and "frame" or tostring(to and to.name)

				relative = name .. "." .. anchor[3]
			end

			return ("%s %s %s %s"):format(point, relative, tostring(anchor[#anchor - 1]), tostring(anchor[#anchor]))
		end
	end

	return "none"
end

local function Blizzard(shown)
	for number = 1, 10 do
		if _G["MerchantItem" .. number].shown ~= shown then
			return false
		end
	end

	return true
end

---Gives the merchant `count` plain items.
local function Stock(count)
	items = {}
	for index = 1, count do
		items[index] = { name = "Item " .. index, texture = index, stackCount = 1, numAvailable = -1, price = 100 * index,
			isPurchasable = true, isUsable = true }
	end
end

-- Arithmetic ----------------------------------------------------------------------------------------------

Equal("off by default", AUI.Schema:Field(Options.ENABLED_PATH).default, false)
Equal("5 rows by default", AUI.Schema:Field(Options.ROWS_PATH).default, 5)
Equal("5 columns by default", AUI.Schema:Field(Options.COLUMNS_PATH).default, 5)
Equal("rows first by default", AUI.Schema:Field(Options.ORDER_PATH).default, "ROWS")
Equal("rows' range", AUI.Schema:Field(Options.ROWS_PATH).min .. "-" .. AUI.Schema:Field(Options.ROWS_PATH).max, "1-10")
Equal("columns' range", AUI.Schema:Field(Options.COLUMNS_PATH).min .. "-"
	.. AUI.Schema:Field(Options.COLUMNS_PATH).max, "2-8")
Equal("whole rows", AUI.Schema:Field(Options.ROWS_PATH).integer, true)

Equal("rows first: across", Cell(2, 3, 4, "ROWS"), "1,2")
Equal("rows first: then down", Cell(5, 3, 4, "ROWS"), "2,1")
Equal("rows first: the last cell", Cell(12, 3, 4, "ROWS"), "3,4")
Equal("columns first: down", Cell(2, 3, 4, "COLUMNS"), "2,1")
Equal("columns first: then across", Cell(4, 3, 4, "COLUMNS"), "1,2")
Equal("columns first: the last cell", Cell(12, 3, 4, "COLUMNS"), "3,4")
Equal("an unknown order fills rows first", Cell(2, 3, 4, "DIAGONAL"), "1,2")

local x, y = Options:Offset(1, 1)
Equal("the first slot sits where Blizzard's does", x .. "," .. y, "11,-69")
x, y = Options:Offset(3, 2)
Equal("each column a slot and a gap across, each row a slot and a gap down", x .. "," .. y, "176,-173")

local width, height = Options:WindowSize(5, 2)
Equal("Blizzard's grid keeps Blizzard's window", width .. "x" .. height, "336x444")
width, height = Options:WindowSize(5, 5)
Equal("the default grid", width .. "x" .. height, "831x444")
width, height = Options:WindowSize(10, 8)
Equal("the largest grid", width .. "x" .. height, "1326x704")
width, height = Options:WindowSize(1, 2)
Equal("one row shrinks the window", width .. "x" .. height, "336x236")
Equal("Show All Items on by default", AUI.Schema:Field(Options.SHOW_ALL_PATH).default, true)

Equal("no items is one page", Options:Pages(0, 25), 1)
Equal("a full page", Options:Pages(25, 25), 1)
Equal("one past a page", Options:Pages(26, 25), 2)
Equal("a page in range", Options:ClampPage(2, 3), 2)
Equal("past the last page", Options:ClampPage(9, 3), 3)
Equal("before the first page", Options:ClampPage(0, 3), 1)
Equal("not a number", Options:ClampPage(nil, 3), 1)

-- Module --------------------------------------------------------------------------------------------------

MerchantWindow:Start()
Equal("off: nothing hooked", client.hooks, 0)
Equal("off: not extended", MerchantWindow.extended, false)

Stock(23)
MerchantFrame:Show()
MerchantFrame_Update()
Equal("off: Blizzard's slots stay", Blizzard(true), true)
Equal("off: no slots made", #created, 0)

Set(Options.ENABLED_PATH, true)
Equal("on: Blizzard's three updates hooked", HookedUpdates(), 3)
Equal("on: an open window redraws", updates, 2)
Equal("the default grid's slots", #created, 25)
Equal("slots are named for Blizzard's helpers", created[1], "AeonUIMerchantItem1")
Equal("Blizzard's slots hidden", Blizzard(false), true)
Equal("the window fits the grid", Size(MerchantFrame), "831x444")
Equal("rows first: the second slot beside the first", Point(AeonUIMerchantItem2), "TOPLEFT 176 -69")
Equal("the first item", AeonUIMerchantItem1.Name.text .. " " .. AeonUIMerchantItem1.ItemButton:GetID(), "Item 1 1")
Equal("the item's price", AeonUIMerchantItem3MoneyFrame.price .. " " .. tostring(AeonUIMerchantItem3MoneyFrame.shown),
	"300 true")
Equal("a usable item is drawn as it is", AeonUIMerchantItem1.slotColor .. "/" .. AeonUIMerchantItem1.ItemButton.iconColor,
	"1 1 1/1 1 1")
Equal("past the last item: empty", tostring(AeonUIMerchantItem24.ItemButton.shown) .. " "
	.. tostring(AeonUIMerchantItem24.ItemButton.hasItem) .. " " .. AeonUIMerchantItem24.slotColor, "false nil 0.4 0.4 0.4")
Equal("23 items on one page: no page controls", tostring(MerchantPageText.shown) .. " "
	.. tostring(MerchantNextPageButton.shown), "false false")
Equal("Blizzard's bottom art left as Blizzard has it", tostring(MerchantFrameBottomLeftBorder.shown) .. " "
	.. #MerchantFrameBottomLeftBorder.points, "true 0")
Equal("the money well at Blizzard's place from the left", PointOf(MerchantMoneyInset, "TOPLEFT") .. ", "
	.. PointOf(MerchantMoneyInset, "BOTTOMRIGHT"), "TOPLEFT frame.BOTTOMLEFT 165 27, BOTTOMRIGHT frame.BOTTOMLEFT 331 4")
Equal("its border too", PointOf(MerchantMoneyBg, "TOPRIGHT") .. ", " .. PointOf(MerchantMoneyBg, "BOTTOMLEFT"),
	"TOPRIGHT frame.BOTTOMLEFT 329 25, BOTTOMLEFT frame.BOTTOMLEFT 170 6")
Equal("the money in it", PointOf(MerchantMoneyFrame, "BOTTOMRIGHT"), "BOTTOMRIGHT frame.BOTTOMLEFT 332 8")
Equal("the first currency in it", PointOf(MerchantToken1, "BOTTOMRIGHT"), "BOTTOMRIGHT frame.BOTTOMLEFT 320 8")
Equal("the last item sold where Blizzard's window has it", PointOf(MerchantBuyBackItem, "TOPLEFT"),
	"TOPLEFT frame.BOTTOMLEFT 206 70")
Equal("the next page button at the right edge", PointOf(MerchantNextPageButton, "CENTER"),
	"CENTER frame.BOTTOMRIGHT -26 96")
Equal("the repair buttons left to Blizzard", PointOf(MerchantRepairAllButton, "BOTTOMRIGHT"),
	"BOTTOMRIGHT frame.BOTTOMLEFT 118 33")
currencies = { 1 }
MerchantFrame_Update()
Equal("with currencies, the money sits left of them", PointOf(MerchantMoneyFrame, "BOTTOMRIGHT"),
	"BOTTOMRIGHT frame.BOTTOMLEFT 167 8")
currencies = {}
canRepair = false
MerchantFrame_Update()
Equal("without repairs, the junk button where Blizzard's window has it", #MerchantSellAllJunkButton.points .. " "
	.. PointOf(MerchantSellAllJunkButton, "BOTTOMRIGHT"), "1 BOTTOMRIGHT frame.BOTTOMLEFT 188 33")
MerchantFrame_UpdateRepairButtons()
Equal("and again after Blizzard's repair update", #MerchantSellAllJunkButton.points, 1)
canRepair = true
MerchantSellAllJunkButton:ClearAllPoints()
MerchantFrame_Update()

Set(Options.ORDER_PATH, "COLUMNS")
Equal("columns first: the second slot under the first", Point(AeonUIMerchantItem2), "TOPLEFT 11 -121")
Set(Options.ORDER_PATH, "ROWS")

-- Paging: 2 x 2 is four a page, so 23 items are six pages.
Set(Options.ROWS_PATH, 2)
Set(Options.COLUMNS_PATH, 2)
Equal("slots past the page hidden", tostring(AeonUIMerchantItem5.shown) .. " " .. tostring(AeonUIMerchantItem4.shown),
	"false true")
Equal("the page text counts the grid's pages", MerchantPageText.text, "Page 1 of 6")
Equal("page controls shown", tostring(MerchantPageText.shown) .. " " .. tostring(MerchantPrevPageButton.shown) .. " "
	.. tostring(MerchantNextPageButton.shown), "true true true")
Equal("first page: previous off, next on", tostring(MerchantPrevPageButton.enabled) .. " "
	.. tostring(MerchantNextPageButton.enabled), "false true")
Equal("the window shrinks with the grid", Size(MerchantFrame), "336x288")

Stock(6)
MerchantFrame_Update()
Equal("six items still page at four a page, where Blizzard shows none", tostring(MerchantPageText.shown) .. " "
	.. MerchantPageText.text, "true Page 1 of 2")
Stock(23)

MerchantFrame.page = 9
MerchantFrame_Update()
Equal("a page past the last is brought back", MerchantFrame.page, 6)
Equal("the last page's items", AeonUIMerchantItem1.ItemButton:GetID() .. " " .. AeonUIMerchantItem3.ItemButton:GetID(),
	"21 23")
Equal("the last page's empty slot", tostring(AeonUIMerchantItem4.ItemButton.hasItem), "nil")
Equal("last page: previous on, next off", tostring(MerchantPrevPageButton.enabled) .. " "
	.. tostring(MerchantNextPageButton.enabled), "true false")

-- A quantity window stays only while its slot keeps its item.
StackSplitFrame:Show()
StackSplitFrame.owner = AeonUIMerchantItem1.ItemButton
MerchantFrame_Update()
Equal("same item: the quantity window stays", splitCancels, 0)
MerchantFrame.page = 1
MerchantFrame_Update()
Equal("another item: the quantity window closes", splitCancels, 1)
StackSplitFrame:Show()
StackSplitFrame.owner = MerchantItem1ItemButton
MerchantFrame.page = 2
MerchantFrame_Update()
Equal("Blizzard's own quantity windows are left to Blizzard", splitCancels, 1)
StackSplitFrame:Hide()
MerchantFrame.page = 1

-- How Blizzard fills a slot.
items[1] = { name = "Token", texture = 1, stackCount = 1, numAvailable = -1, price = 0, hasExtendedCost = true,
	isPurchasable = true, isUsable = true }
costs[1] = { { texture = "badge", value = 5, link = "badgeLink" } }
items[2] = { name = "Both", texture = 2, stackCount = 1, numAvailable = -1, price = 50, hasExtendedCost = true,
	isPurchasable = true, isUsable = true, afford = false }
costs[2] = { { texture = "mark", value = 2 }, { texture = "seal", value = 3 } }
items[3] = { name = "Sword", texture = 3, stackCount = 1, numAvailable = 0, price = 10, isPurchasable = true,
	isUsable = false, isQuestStartItem = true }
items[4] = { name = "Crest", texture = 4, stackCount = 1, numAvailable = -1, price = 10, isPurchasable = true,
	isUsable = true, currencyID = 7 }
heirlooms[1003] = true
MerchantFrame_Update()
Equal("cost items alone: no money", tostring(AeonUIMerchantItem1MoneyFrame.shown) .. " "
	.. tostring(AeonUIMerchantItem1AltCurrencyFrame.shown) .. " " .. AeonUIMerchantItem1AltCurrencyFrameItem1.cost,
	"false true badgex5")
Equal("a cost item's link", AeonUIMerchantItem1AltCurrencyFrameItem1.itemLink, "badgeLink")
Equal("unused cost buttons hidden", tostring(AeonUIMerchantItem1AltCurrencyFrameItem2.shown), "false")
Equal("money and cost items", tostring(AeonUIMerchantItem2MoneyFrame.shown) .. " "
	.. tostring(AeonUIMerchantItem2AltCurrencyFrame.shown) .. " " .. AeonUIMerchantItem2AltCurrencyFrameItem2.cost,
	"true true sealx3")
Equal("the price leaves room for the cost items", AeonUIMerchantItem2MoneyFrame.maxWidth, 120 - 24)
Equal("an unaffordable price is gray", AeonUIMerchantItem2MoneyFrame.color, "gray")
Equal("a quest item's mark", tostring(AeonUIMerchantItem3.ItemButton.IconQuestTexture.shown) .. " "
	.. tostring(AeonUIMerchantItem3.ItemButton.IconQuestTexture.file), "true bang")
Equal("a known heirloom, sold out, desaturated and dimmed", tostring(AeonUIMerchantItem3.ItemButton.desaturated) .. " "
	.. AeonUIMerchantItem3.slotColor, "true 0.5 0.5 0.5")
Equal("a currency's container name", AeonUIMerchantItem4.Name.text, "Crest (container)")
items[3].numAvailable, heirlooms[1003] = -1, nil
MerchantFrame_Update()
Equal("not usable: red", AeonUIMerchantItem3.slotColor .. "/" .. AeonUIMerchantItem3.ItemButton.iconColor,
	"1 0 0/0.9 0 0")
items[3].numAvailable = 0
MerchantFrame_Update()
Equal("not usable and sold out: dim red", AeonUIMerchantItem3.nameColor, "0.5 0 0")
Stock(23)
costs = {}

-- Item data arriving.
qualities = {}
MerchantFrame_UpdateItemQualityBorders()
Equal("item quality redrawn for each shown item", table.concat(qualities, " "),
	"AeonUIMerchantItem1=link1 AeonUIMerchantItem2=link2 AeonUIMerchantItem3=link3 AeonUIMerchantItem4=link4")

-- Forever's gamepad interface pages with its indicators.
local MerchantPageTurnIndicatorLeft = Part("Button", "MerchantPageTurnIndicatorLeft", false)
local MerchantPageTurnIndicatorRight = Part("Button", "MerchantPageTurnIndicatorRight", false)
InputUtil = { IsGamepadUIEnabled = function()
	return true
end }
MerchantFrame_Update()
Equal("gamepad: indicators in place of the buttons", tostring(MerchantPageTurnIndicatorLeft.shown) .. " "
	.. tostring(MerchantPrevPageButton.shown) .. " " .. tostring(MerchantPageTurnIndicatorLeft.enabled) .. " "
	.. tostring(MerchantPageTurnIndicatorRight.enabled), "true false false true")
InputUtil = nil
MerchantFrame_Update()
Equal("mouse: buttons, no indicators", tostring(MerchantPageTurnIndicatorLeft.shown) .. " "
	.. tostring(MerchantPrevPageButton.shown), "false true")

-- Buyback.
MerchantFrame.selectedTab = 2
MerchantFrame_Update()
Equal("buyback: Blizzard's slots", Blizzard(true), true)
Equal("buyback: AeonUI's slots hidden", tostring(AeonUIMerchantItem1.shown), "false")
Equal("buyback: Blizzard's size", Size(MerchantFrame), "336x444")
Equal("buyback: the next page button back in place", PointOf(MerchantNextPageButton, "CENTER"),
	"CENTER frame.BOTTOMLEFT 310 96")
Equal("buyback: Blizzard's money well", PointOf(MerchantMoneyInset, "TOPLEFT") .. ", "
	.. PointOf(MerchantMoneyInset, "BOTTOMRIGHT") .. ", " .. PointOf(MerchantMoneyBg, "BOTTOMLEFT"),
	"TOPLEFT frame.BOTTOMRIGHT -171 27, BOTTOMRIGHT frame.BOTTOMRIGHT -5 4, BOTTOMLEFT frame.BOTTOMRIGHT -166 6")
Equal("buyback: Blizzard's money and currency", PointOf(MerchantMoneyFrame, "BOTTOMRIGHT") .. ", "
	.. PointOf(MerchantToken1, "BOTTOMRIGHT"), "BOTTOMRIGHT frame.BOTTOMRIGHT -4 8, BOTTOMRIGHT frame.BOTTOMRIGHT -16 8")
Equal("buyback: the last item sold back under the grid", PointOf(MerchantBuyBackItem, "TOPLEFT"),
	"TOPLEFT MerchantItem10.BOTTOMLEFT 30 -53")
canRepair = false
MerchantFrame_Update()
Equal("buyback without repairs: junk at Blizzard's right", PointOf(MerchantSellAllJunkButton, "BOTTOMRIGHT"),
	"BOTTOMRIGHT frame.BOTTOMRIGHT -148 33")
canRepair = true
MerchantFrame.selectedTab = 1
MerchantFrame_Update()
Equal("back on the merchant tab: the grid", tostring(AeonUIMerchantItem1.shown) .. " " .. tostring(Blizzard(false)),
	"true true")

-- Turned off.
MerchantFrame.page = 3
local before = updates
Set(Options.ENABLED_PATH, false)
Equal("off: an open window redraws", updates, before + 1)
Equal("off: Blizzard's slots back", Blizzard(true), true)
Equal("off: AeonUI's slots hidden", tostring(AeonUIMerchantItem1.shown), "false")
Equal("off: Blizzard's size", Size(MerchantFrame), "336x444")
Equal("off: back to the first page", MerchantFrame.page, 1)
MerchantFrame_Update()
Equal("off: the hooks draw nothing", tostring(AeonUIMerchantItem1.shown), "false")
Set(Options.ENABLED_PATH, true)
draws = 0
MerchantFrame_UpdateMerchantInfo()
Equal("on again: hooked once", draws, 1)
Equal("on again: the grid", tostring(AeonUIMerchantItem1.shown), "true")

-- Krowi's Extended Vendor UI resizes the window itself.
loaded.Krowi_ExtendedVendorUI = true
Equal("stands down for Krowi's", MerchantWindow:IsWanted(), false)
Equal("names it", MerchantWindow:Blocked(), "Krowi's Extended Vendor UI resizes the merchant window.")
MerchantWindow:Apply()
Equal("stood down: Blizzard's slots back", Blizzard(true), true)
loaded.Krowi_ExtendedVendorUI = nil
Equal("nothing blocks it otherwise", MerchantWindow:Blocked(), nil)

-- Show All Items: after Blizzard's show resets the filter to the class's items.
local onShow = MerchantFrame.scripts.OnShow
Equal("hooked to the window's show once started", type(onShow), "function")
AUI.can.merchantFilter = true
MerchantFrame.page = 3
before = updates
onShow(MerchantFrame)
Equal("the filter set to all items, back on the first page, redrawn", filter .. " " .. MerchantFrame.page .. " "
	.. updates - before, "5 1 1")
before = updates
onShow(MerchantFrame)
Equal("already all items: no redraw", updates - before, 0)
local function OpensOnAll()
	filter = LE_LOOT_FILTER_CLASS
	onShow(MerchantFrame)

	return filter == LE_LOOT_FILTER_ALL
end
Set(Options.SHOW_ALL_PATH, false)
Equal("off: the class's items left", OpensOnAll(), false)
Set(Options.SHOW_ALL_PATH, true)
filterHidden = true
Equal("the client hides the filter: left alone", OpensOnAll(), false)
filterHidden = false
loaded.Krowi_ExtendedVendorUI = true
Equal("stands down for Krowi's", OpensOnAll(), false)
loaded.Krowi_ExtendedVendorUI = nil
AUI.can.merchantFilter = false
Equal("without the filter functions: left alone", OpensOnAll(), false)
AUI.can.merchantFilter = true
Equal("otherwise all items", OpensOnAll(), true)

-- A client without the merchant window's functions.
MerchantWindow.active = false
AUI.can.merchantWindow = false
Equal("unavailable: not wanted", MerchantWindow:IsWanted(), false)

io.stdout:write(("check_merchantwindow: %d checks passed\n"):format(client.checks))
