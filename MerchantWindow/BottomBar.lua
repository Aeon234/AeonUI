local AUI = select(2, ...)

local Options = AUI.MerchantWindowOptions

-- Blizzard's anchors for what this moves (MerchantFrame.xml, and MerchantFrame.lua's MerchantFrame_UpdateCurrencies
-- and MerchantFrame_UpdateRepairButtons), offsets from the window's bottom right corner unless named otherwise.
local MONEY_INSET_LEFT, MONEY_INSET_TOP, MONEY_INSET_RIGHT, MONEY_INSET_BOTTOM = -171, 27, -5, 4
local MONEY_BG_LEFT, MONEY_BG_BOTTOM, MONEY_BG_RIGHT, MONEY_BG_TOP = -166, 6, -7, 25
local MONEY_X, MONEY_X_WITH_CURRENCIES, MONEY_Y = -4, -169, 8
local TOKEN_X, TOKEN_Y = -16, 8
local JUNK_X, JUNK_Y = -148, 33
local NEXT_X, NEXT_Y = -26, 96
-- The last item sold, under `MerchantItem10`; and where that puts it from the bottom left corner of Blizzard's window.
local BUYBACK_X, BUYBACK_Y = 30, -53
local BUYBACK_LEFT, BUYBACK_TOP = 206, 70

---The merchant tab's bottom section while the window is extended: Blizzard's own, kept as Blizzard draws it at its
---own width, against the window's left edge, so a skin that styles Blizzard's parts still styles every one of them.
---The parts Blizzard places from the window's right edge or from the item grid are placed from its left edge at the
---same spot, and the next page button moves to the right edge. `Restore` puts back Blizzard's anchors.
---@class AUIMerchantBottomBar
local BottomBar = {}
AUI.MerchantBottomBar = BottomBar

---@param region Region
---@param point string
---@param x number from the right edge of Blizzard's window
---@param y number
---@param pinned boolean from the window's left edge at Blizzard's width, or from its right edge
local function SetPoint(region, point, x, y, pinned)
	if pinned then
		region:SetPoint(point, MerchantFrame, "BOTTOMLEFT", Options.WINDOW_WIDTH + x, y)
	else
		region:SetPoint(point, MerchantFrame, "BOTTOMRIGHT", x, y)
	end
end

---@return boolean currencies the merchant takes currencies, which moves the money to the currency well's left
local function HasCurrencies()
	return #C_MerchantFrame.GetMerchantCurrencies() > 0
end

---Places the money and currency wells, the money and the first currency.
---@param pinned boolean
local function PlaceMoney(pinned)
	local inset, bg, money = MerchantMoneyInset, MerchantMoneyBg, MerchantMoneyFrame

	inset:ClearAllPoints()
	SetPoint(inset, "TOPLEFT", MONEY_INSET_LEFT, MONEY_INSET_TOP, pinned)
	SetPoint(inset, "BOTTOMRIGHT", MONEY_INSET_RIGHT, MONEY_INSET_BOTTOM, pinned)
	bg:ClearAllPoints()
	SetPoint(bg, "TOPRIGHT", MONEY_BG_RIGHT, MONEY_BG_TOP, pinned)
	SetPoint(bg, "BOTTOMLEFT", MONEY_BG_LEFT, MONEY_BG_BOTTOM, pinned)
	money:ClearAllPoints()
	SetPoint(money, "BOTTOMRIGHT", HasCurrencies() and MONEY_X_WITH_CURRENCIES or MONEY_X, MONEY_Y, pinned)

	-- Blizzard creates the tokens as the first merchant with currencies opens; the others follow the first, or sit from
	-- the window's left edge.
	local token = _G["MerchantToken1"]

	if token then
		token:ClearAllPoints()
		SetPoint(token, "BOTTOMRIGHT", TOKEN_X, TOKEN_Y, pinned)
	end
end

---Places the junk button where Blizzard puts it while the merchant cannot repair: from the right edge. Otherwise it
---follows the repair buttons, which sit from the left edge. Blizzard places it again on each repair update.
---@param pinned boolean
function BottomBar:PlaceJunk(pinned)
	if CanMerchantRepair() then
		return
	end

	MerchantSellAllJunkButton:ClearAllPoints()
	SetPoint(MerchantSellAllJunkButton, "BOTTOMRIGHT", JUNK_X, JUNK_Y, pinned)
end

---Keeps Blizzard's bottom section against the window's left edge, and the next page button at its right edge.
function BottomBar:Pin()
	PlaceMoney(true)
	self:PlaceJunk(true)
	MerchantBuyBackItem:ClearAllPoints()
	MerchantBuyBackItem:SetPoint("TOPLEFT", MerchantFrame, "BOTTOMLEFT", BUYBACK_LEFT, BUYBACK_TOP)
	MerchantNextPageButton:ClearAllPoints()
	MerchantNextPageButton:SetPoint("CENTER", MerchantFrame, "BOTTOMRIGHT", NEXT_X, NEXT_Y)
end

---Gives every part Blizzard's anchors back.
function BottomBar:Restore()
	PlaceMoney(false)
	self:PlaceJunk(false)
	MerchantBuyBackItem:ClearAllPoints()
	MerchantBuyBackItem:SetPoint("TOPLEFT", MerchantItem10, "BOTTOMLEFT", BUYBACK_X, BUYBACK_Y)
	MerchantNextPageButton:ClearAllPoints()
	MerchantNextPageButton:SetPoint("CENTER", MerchantFrame, "BOTTOMLEFT", Options.WINDOW_WIDTH + NEXT_X, NEXT_Y)
end
