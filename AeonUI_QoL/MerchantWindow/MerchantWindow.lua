local AUI = select(2, ...)

local L = AUI.L
local Options = AUI.MerchantWindowOptions

-- Addons that resize the merchant window themselves; while one is loaded, AeonUI leaves the window to it.
local MANAGERS = { "Krowi_ExtendedVendorUI" }
-- Blizzard's merchant tab slots, and the widest a price may draw (MerchantFrame.lua's MAX_MONEY_DISPLAY_WIDTH).
local BLIZZARD_SLOTS = 10
local MAX_MONEY_WIDTH = 120
-- Named, so Blizzard's money and alternate currency helpers find each slot's parts through `$parent` names.
local SLOT_PREFIX = "AeonUIMerchantItem"
-- Blizzard's tints for a slot: sold out or a known heirloom (dimmed), not usable (red), and as it is.
local GRAY, WHITE = { 0.5, 0.5, 0.5 }, { 1, 1, 1 }
local DIM_RED, RED, ICON_RED = { 0.5, 0, 0 }, { 1, 0, 0 }, { 0.9, 0, 0 }

---A slot made from Blizzard's `MerchantItemTemplate`.
---@class AUIMerchantItem: Frame
---@field Name FontString
---@field ItemButton AUIMerchantItemButton

---@class AUIMerchantItemButton: ItemButton
---@field IconQuestTexture Texture

---The Merchant Window module: the merchant tab shows a grid of AeonUI's own slots, of the chosen rows and columns in
---the chosen order, in place of Blizzard's ten, and the window grows or shrinks to fit. Each slot is filled as
---Blizzard fills its own, after Blizzard's update. Blizzard's page buttons, page text and page number stay in use,
---corrected for the grid's page size, and Blizzard's bottom section is kept at its own width against the window's
---left edge (`AUI.MerchantBottomBar`). The buyback tab keeps Blizzard's slots, size and bottom section. Show All Items
---sets the merchant's filter to all items each time the window opens, after Blizzard resets it to the class's. Nothing is protected here, so
---combat does not matter.
---@class AUIMerchantWindow
---@field active boolean started this session
---@field hooked boolean Blizzard's merchant updates are hooked
---@field extended boolean the merchant tab shows AeonUI's grid
---@field slots AUIMerchantItem[] AeonUI's slots, created as the grid first needs them
---@field own table<Button, boolean> the slots' item buttons
local MerchantWindow = {
	active = false,
	hooked = false,
	extended = false,
	slots = {},
	own = {},
}
AUI.MerchantWindow = MerchantWindow

---@return string? manager the loaded addon that resizes the merchant window
function MerchantWindow.Manager()
	for _, name in ipairs(MANAGERS) do
		if C_AddOns.IsAddOnLoaded(name) then
			return name
		end
	end
end

---@return string? reason the setting is disabled, naming the addon that resizes the window
function MerchantWindow:Blocked()
	local manager = self.Manager()

	if manager then
		return L["%s resizes the merchant window."]:format(C_AddOns.GetAddOnMetadata(manager, "Title") or manager)
	end
end

---@return boolean
function MerchantWindow:IsWanted()
	return AUI.can.merchantWindow == true and AUI.Profile:Get(Options.ENABLED_PATH) == true and not self.Manager()
end

---@param number number a slot on the page, from 1
---@return AUIMerchantItem slot
function MerchantWindow:Slot(number)
	local slot = self.slots[number]

	if not slot then
		slot = CreateFrame("Frame", SLOT_PREFIX .. number, MerchantFrame, "MerchantItemTemplate") --[[@as AUIMerchantItem]]
		slot:Hide()
		self.slots[number] = slot
		self.own[slot.ItemButton] = true
	end

	return slot
end

---Blizzard's `MerchantFrame_UpdateAltCurrency`, for one of AeonUI's slots: each cost item or currency, and their width.
---@param slot AUIMerchantItem
---@param index number the merchant's item
---@param canAfford boolean?
---@return number width
local function UpdateAltCurrency(slot, index, canAfford)
	local frameName = slot:GetName() .. "AltCurrencyFrame"
	local used, width = 0, 0

	if GetMerchantItemCostInfo(index) > 0 then
		for cost = 1, MAX_ITEM_COST do
			local texture, value, link = GetMerchantItemCostItem(index, cost)

			if texture then
				used = used + 1

				local button = _G[frameName .. "Item" .. used]

				button.index, button.item, button.itemLink = index, cost, link
				AltCurrencyFrame_Update(frameName .. "Item" .. used, texture, value, canAfford)
				width = width + button:GetWidth() + (used > 1 and 4 or 0)
				button:Show()
			end
		end
	end

	for cost = used + 1, MAX_ITEM_COST do
		_G[frameName .. "Item" .. cost]:Hide()
	end

	return width
end

---Colors a slot's name frame, slot and icon, as Blizzard marks an item sold out or one the player cannot use.
---@param slot AUIMerchantItem
---@param name number[] the name frame's color
---@param back number[] the slot's color
---@param icon number[] the icon's color
local function Tint(slot, name, back, icon)
	local button = slot.ItemButton

	SetItemButtonNameFrameVertexColor(slot, name[1], name[2], name[3])
	SetItemButtonSlotVertexColor(slot, back[1], back[2], back[3])
	SetItemButtonTextureVertexColor(button, icon[1], icon[2], icon[3])
	SetItemButtonNormalTextureVertexColor(button, icon[1], icon[2], icon[3])
end

---Shows the slot empty, as Blizzard shows a slot past the merchant's last item.
---@param slot AUIMerchantItem
local function Clear(slot)
	local button = slot.ItemButton
	local name = slot:GetName()

	button.price, button.hasItem, button.name = nil, nil, nil
	button:Hide()
	SetItemButtonNameFrameVertexColor(slot, 0.5, 0.5, 0.5)
	SetItemButtonSlotVertexColor(slot, 0.4, 0.4, 0.4)
	slot.Name:SetText("")
	_G[name .. "MoneyFrame"]:Hide()
	_G[name .. "AltCurrencyFrame"]:Hide()
end

---Fills one of AeonUI's slots with a merchant item, as Blizzard's `MerchantFrame_UpdateMerchantInfo` fills its own.
---@param slot AUIMerchantItem
---@param index number the merchant's item
local function Fill(slot, index)
	local info = C_MerchantFrame.GetItemInfo(index)

	if not info then
		Clear(slot)

		return
	end

	if info.currencyID then
		info.name, info.texture, info.numAvailable = CurrencyContainerUtil.GetCurrencyContainerInfo(info.currencyID,
			info.numAvailable, info.name, info.texture, nil)
	end

	local name = slot:GetName()
	local button = slot.ItemButton
	local money = _G[name .. "MoneyFrame"]
	local altCurrency = _G[name .. "AltCurrencyFrame"]
	local canAfford = CanAffordMerchantItem(index)
	local link = GetMerchantItemLink(index)
	local price = info.price or 0

	slot.Name:SetText(info.name)
	SetItemButtonCount(button, info.stackCount)
	SetItemButtonStock(button, info.numAvailable)
	SetItemButtonTexture(button, info.texture)
	button.name, button.link, button.texture = info.name, link, info.texture

	if info.hasExtendedCost and price <= 0 then
		button.price, button.extendedCost = nil, true
		UpdateAltCurrency(slot, index, canAfford)
		altCurrency:ClearAllPoints()
		altCurrency:SetPoint("BOTTOMLEFT", name .. "NameFrame", "BOTTOMLEFT", 0, 31)
		money:Hide()
		altCurrency:Show()
	else
		local altWidth = 0

		button.price, button.extendedCost = price, info.hasExtendedCost and true or nil

		if info.hasExtendedCost then
			altWidth = UpdateAltCurrency(slot, index, canAfford)
		end

		MoneyFrame_SetMaxDisplayWidth(money, MAX_MONEY_WIDTH - altWidth)
		MoneyFrame_Update(money:GetName(), price)
		SetMoneyFrameColor(money:GetName(), canAfford == false and "gray" or nil)

		if info.hasExtendedCost then
			altCurrency:ClearAllPoints()
			altCurrency:SetPoint("LEFT", money:GetName(), "RIGHT", -14, 0)
			altCurrency:Show()
		else
			altCurrency:Hide()
		end

		money:Show()
	end

	if info.isQuestStartItem then
		button.IconQuestTexture:SetTexture(TEXTURE_ITEM_QUEST_BANG)
		button.IconQuestTexture:Show()
	else
		button.IconQuestTexture:Hide()
	end

	MerchantFrameItem_UpdateQuality(slot, link)

	local itemID = GetMerchantItemID(index)
	local isHeirloom = itemID and C_Heirloom.IsItemHeirloom(itemID)
	local isKnownHeirloom = isHeirloom and C_Heirloom.PlayerHasHeirloom(itemID)
	local tintRed = not info.isPurchasable or (not info.isUsable and not isHeirloom)

	button.showNonrefundablePrompt = not C_MerchantFrame.IsMerchantItemRefundable(index)
	button.hasItem = true
	button:SetID(index)
	button:Show()
	SetItemButtonDesaturated(button, isKnownHeirloom)

	if info.numAvailable == 0 or isKnownHeirloom then
		local color = tintRed and DIM_RED or GRAY

		Tint(slot, color, color, color)
	elseif tintRed then
		Tint(slot, RED, RED, ICON_RED)
	else
		Tint(slot, GRAY, WHITE, WHITE)
	end
end

---@return Button? owner the AeonUI item button whose quantity window is open
function MerchantWindow:SplitOwner()
	local owner = StackSplitFrame and StackSplitFrame:IsShown() and StackSplitFrame.owner

	return owner and self.own[owner] and owner or nil
end

---@param shown boolean Blizzard's merchant tab slots show
local function ShowBlizzardSlots(shown)
	for number = 1, BLIZZARD_SLOTS do
		_G["MerchantItem" .. number]:SetShown(shown)
	end
end

---Corrects Blizzard's page controls for the grid's pages: the page text, the buttons' states, and on Forever's
---gamepad interface its page-turn indicators in their place.
---@param page number
---@param pages number
local function UpdatePaging(page, pages)
	local paged = pages > 1
	local gamepad = MerchantPageTurnIndicatorLeft ~= nil and InputUtil ~= nil and InputUtil.IsGamepadUIEnabled ~= nil
		and InputUtil.IsGamepadUIEnabled()

	MerchantPageText:SetFormattedText(MERCHANT_PAGE_NUMBER, page, pages)
	MerchantPageText:SetShown(paged)
	MerchantPrevPageButton:SetEnabled(page > 1)
	MerchantNextPageButton:SetEnabled(page < pages)
	MerchantPrevPageButton:SetShown(paged and not gamepad)
	MerchantNextPageButton:SetShown(paged and not gamepad)

	if MerchantPageTurnIndicatorLeft then
		MerchantPageTurnIndicatorLeft:SetShown(paged and gamepad)
		MerchantPageTurnIndicatorLeft:SetEnabled(page > 1)
		MerchantPageTurnIndicatorRight:SetShown(paged and gamepad)
		MerchantPageTurnIndicatorRight:SetEnabled(page < pages)
	end
end

---Sizes the window and places its bottom section: the grid's size, Blizzard's section kept at the left, on the
---merchant tab while extended; otherwise Blizzard's.
---@param rows number?
---@param columns number?
local function Layout(rows, columns)
	if rows and columns then
		MerchantFrame:SetSize(Options:WindowSize(rows, columns))
		AUI.MerchantBottomBar:Pin()
	else
		MerchantFrame:SetSize(Options.WINDOW_WIDTH, Options.WINDOW_HEIGHT)
		AUI.MerchantBottomBar:Restore()
	end
end

---Draws the merchant tab's grid after Blizzard's update: the page, kept within the grid's pages, each slot filled or
---empty, the page controls and the window's size.
function MerchantWindow:Draw()
	if not self.extended or MerchantFrame.selectedTab ~= 1 then
		return
	end

	local Profile = AUI.Profile
	local rows, columns = Profile:Get(Options.ROWS_PATH), Profile:Get(Options.COLUMNS_PATH)
	local order = Profile:Get(Options.ORDER_PATH)
	local perPage = rows * columns
	local count = GetMerchantNumItems()
	local pages = Options:Pages(count, perPage)
	local page = Options:ClampPage(MerchantFrame.page, pages)
	-- A quantity window stays only while its slot keeps its item.
	local splitOwner = self:SplitOwner()
	local splitIndex = splitOwner and splitOwner:GetID()

	if page ~= MerchantFrame.page then
		MerchantFrame.page = page
	end

	ShowBlizzardSlots(false)

	for number = 1, perPage do
		local slot = self:Slot(number)
		local row, column = Options:Cell(number, rows, columns, order)

		slot:ClearAllPoints()
		slot:SetPoint("TOPLEFT", MerchantFrame, "TOPLEFT", Options:Offset(row, column))

		local index = (page - 1) * perPage + number

		if index <= count then
			Fill(slot, index)
		else
			Clear(slot)
		end

		slot:Show()
	end

	for number = perPage + 1, #self.slots do
		self.slots[number]:Hide()
	end

	if splitOwner and splitOwner:GetID() ~= splitIndex then
		StackSplitCancelButton_OnClick()
	end

	UpdatePaging(page, pages)
	Layout(rows, columns)
end

---The buyback tab: Blizzard's slots and size.
function MerchantWindow:DrawBuyback()
	if not self.extended then
		return
	end

	for _, slot in ipairs(self.slots) do
		slot:Hide()
	end

	ShowBlizzardSlots(true)
	Layout()
end

---Redraws the grid's item names and borders once item data arrives, as Blizzard does for its own slots.
function MerchantWindow:UpdateQuality()
	if not self.extended or MerchantFrame.selectedTab ~= 1 then
		return
	end

	for _, slot in ipairs(self.slots) do
		local button = slot.ItemButton

		if slot:IsShown() and button.hasItem then
			MerchantFrameItem_UpdateQuality(slot, GetMerchantItemLink(button:GetID()))
		end
	end
end

function MerchantWindow:Hook()
	if self.hooked then
		return
	end

	self.hooked = true
	hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function()
		MerchantWindow:Draw()
	end)
	hooksecurefunc("MerchantFrame_UpdateBuybackInfo", function()
		MerchantWindow:DrawBuyback()
	end)
	hooksecurefunc("MerchantFrame_UpdateItemQualityBorders", function()
		MerchantWindow:UpdateQuality()
	end)
	-- Blizzard places the junk button again whenever the player's money changes.
	hooksecurefunc("MerchantFrame_UpdateRepairButtons", function()
		if MerchantWindow.extended and MerchantFrame.selectedTab == 1 then
			AUI.MerchantBottomBar:PlaceJunk(true)
		end
	end)
end

---Gives the merchant tab AeonUI's grid or Blizzard's slots back, and redraws an open window.
function MerchantWindow:Apply()
	local wanted = self:IsWanted()

	if wanted == self.extended and not wanted then
		return
	end

	if wanted then
		self:Hook()
	elseif self.extended then
		for _, slot in ipairs(self.slots) do
			slot:Hide()
		end

		ShowBlizzardSlots(true)
		Layout()
		MerchantFrame.page = 1
	end

	self.extended = wanted

	if MerchantFrame:IsShown() then
		MerchantFrame_Update()
	end
end

---@param path string? the changed setting; nil when the whole profile changed
function MerchantWindow:OnProfileChanged(path)
	if path == nil or path:sub(1, 15) == "merchantWindow." then
		AUI.Events:Coalesce("merchantWindowApply", function()
			MerchantWindow:Apply()
		end)
	end
end

---@return boolean wanted the merchant's filter is set to all items as the window opens
function MerchantWindow:ShowsAll()
	local rules = C_GameRules and Enum.GameRule and Enum.GameRule.MerchantFilterDisabled
	local filterHidden = rules ~= nil and C_GameRules.IsGameRuleActive(Enum.GameRule.MerchantFilterDisabled)

	return AUI.can.merchantFilter == true and AUI.Profile:Get(Options.SHOW_ALL_PATH) == true and not self.Manager()
		and not filterHidden
end

---Runs after Blizzard's `MerchantFrame_OnShow`, which resets the filter to the class's items and draws the window.
function MerchantWindow:OnShow()
	if self:ShowsAll() and GetMerchantFilter() ~= LE_LOOT_FILTER_ALL then
		SetMerchantFilter(LE_LOOT_FILTER_ALL)
		MerchantFrame.page = 1
		MerchantFrame_Update()
	end
end

function MerchantWindow:Start()
	if self.active or not AUI.can.merchantWindow then
		return
	end

	self.active = true
	AUI.Callbacks:Register("Profile", self, self.OnProfileChanged)
	MerchantFrame:HookScript("OnShow", function()
		MerchantWindow:OnShow()
	end)
	self:Apply()
end
