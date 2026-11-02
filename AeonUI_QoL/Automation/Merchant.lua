local AUI = select(2, ...)

local L = AUI.L

local Options = AUI.AutomationOptions

-- After the last money or bag change, how long a sale must stay quiet before it counts as finished, in seconds.
local SETTLE = 0.5
-- The longest a sale may take before the visit moves on to the repair, in seconds.
local TIMEOUT = 3

---One merchant visit: sells junk, waits for the sale to settle, then repairs, so the junk money can pay for the repair
---and the two reports never mix. Holding Shift as the merchant opens skips both. Junk is what Blizzard's Sell All Junk
---sells; without that API, poor-quality items that have a sell price, slot by slot.
---@class AUIMerchant
---@field visit integer increases with every merchant opened; work from an older visit is dropped
---@field open boolean a merchant is open
---@field listening boolean
---@field selling boolean a sale is waiting to settle
---@field saleVisit integer the visit the sale belongs to
---@field moneyBefore number
---@field junkBefore integer
---@field settleTimer table?
---@field timeoutTimer table?
local Merchant = {
	visit = 0,
	open = false,
	listening = false,
	selling = false,
	saleVisit = 0,
	moneyBefore = 0,
	junkBefore = 0,
}
AUI.Merchant = Merchant

---@return boolean
local function HasSellAllJunk()
	return C_MerchantFrame ~= nil and C_MerchantFrame.SellAllJunkItems ~= nil
		and C_MerchantFrame.GetNumJunkItems ~= nil and C_MerchantFrame.IsSellAllJunkEnabled ~= nil
end

---The bag slots the fallback sells: poor quality and worth something.
---@param includeLocked boolean? also count slots already locked by a sale in progress
---@return { bag: integer, slot: integer }[] slots
function Merchant:FallbackSlots(includeLocked)
	local slots = {}
	local poor = Enum.ItemQuality.Poor

	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)

			if info and info.quality == poor and not info.hasNoValue and (includeLocked or not info.isLocked) then
				slots[#slots + 1] = { bag = bag, slot = slot }
			end
		end
	end

	return slots
end

---@return integer count junk items still in the bags
function Merchant:JunkLeft()
	if HasSellAllJunk() then
		return C_MerchantFrame.GetNumJunkItems()
	end

	return #self:FallbackSlots(true)
end

---Listens for merchants while selling or repairing is on.
function Merchant:Apply()
	local wanted = Options:Get(Options.SELL_JUNK_PATH) == true or Options:Get(Options.REPAIR_PATH) == true

	if not wanted and self.selling then
		self:StopSale()
	end

	if wanted == self.listening then
		return
	end

	self.listening = wanted

	if wanted then
		AUI.Events:Register("MERCHANT_SHOW", self, self.OnShow)
		AUI.Events:Register("MERCHANT_CLOSED", self, self.OnClosed)
	else
		AUI.Events:Unregister("MERCHANT_SHOW", self)
		AUI.Events:Unregister("MERCHANT_CLOSED", self)
		self.open = false
	end
end

function Merchant:OnShow()
	self.visit = self.visit + 1
	self.open = true

	if IsShiftKeyDown() then
		return
	end

	if Options:Get(Options.SELL_JUNK_PATH) == true and self:StartSale() then
		return
	end

	self:AfterSale(self.visit)
end

function Merchant:OnClosed()
	self.open = false

	if self.selling then
		self:FinishSale()
	end
end

---Starts the sale; false when there is nothing to sell.
---@return boolean started
function Merchant:StartSale()
	local count

	if HasSellAllJunk() then
		if not C_MerchantFrame.IsSellAllJunkEnabled() then
			return false
		end

		count = C_MerchantFrame.GetNumJunkItems()
	else
		count = #self:FallbackSlots()
	end

	if count == 0 then
		return false
	end

	self.selling = true
	self.saleVisit = self.visit
	self.junkBefore = count
	self.moneyBefore = GetMoney()

	AUI.Events:Register("PLAYER_MONEY", self, self.OnSaleChanged)
	AUI.Events:Register("BAG_UPDATE_DELAYED", self, self.OnSaleChanged)
	self:RestartSettle()
	self.timeoutTimer = C_Timer.NewTimer(TIMEOUT, function()
		self:FinishSale()
	end)

	if HasSellAllJunk() then
		C_MerchantFrame.SellAllJunkItems()
	else
		for _, entry in ipairs(self:FallbackSlots()) do
			C_Container.UseContainerItem(entry.bag, entry.slot)
		end
	end

	return true
end

function Merchant:RestartSettle()
	if self.settleTimer then
		self.settleTimer:Cancel()
	end

	self.settleTimer = C_Timer.NewTimer(SETTLE, function()
		self:FinishSale()
	end)
end

---The sale is over once no junk is left and the money has arrived; until then it waits for the money to settle.
function Merchant:OnSaleChanged()
	if self:JunkLeft() == 0 and GetMoney() ~= self.moneyBefore then
		self:FinishSale()
	else
		self:RestartSettle()
	end
end

---Ends the sale's waiting without reporting or continuing the visit.
function Merchant:StopSale()
	self.selling = false

	AUI.Events:Unregister("PLAYER_MONEY", self)
	AUI.Events:Unregister("BAG_UPDATE_DELAYED", self)

	if self.settleTimer then
		self.settleTimer:Cancel()
		self.settleTimer = nil
	end

	if self.timeoutTimer then
		self.timeoutTimer:Cancel()
		self.timeoutTimer = nil
	end
end

---Ends the sale, reports what it earned and continues the visit.
function Merchant:FinishSale()
	if not self.selling then
		return
	end

	local earned = GetMoney() - self.moneyBefore
	local sold = self.junkBefore - self:JunkLeft()

	self:StopSale()

	if Options:Get(Options.REPORT_SALES_PATH) == true and earned > 0 and sold > 0 then
		AUI:Print(self.SaleReport(sold, GetMoneyString(earned, true)))
	end

	self:AfterSale(self.saleVisit)
end

---@param sold integer
---@param money string the earnings, formatted
---@return string message
function Merchant.SaleReport(sold, money)
	if sold == 1 then
		return L["Sold 1 junk item for %s."]:format(money)
	end

	return L["Sold %d junk items for %s."]:format(sold, money)
end

---@param visit integer
function Merchant:AfterSale(visit)
	if visit ~= self.visit or not self.open or Options:Get(Options.REPAIR_PATH) ~= true then
		return
	end

	self:Repair()
end

function Merchant:Repair()
	if not CanMerchantRepair() then
		return
	end

	local cost, canRepair = GetRepairAllCost()

	if not canRepair or not cost or cost <= 0 then
		return
	end

	local canGuild = CanGuildBankRepair ~= nil and CanGuildBankRepair() == true
	local guildFunds = canGuild and Options.GuildFunds(GetGuildBankWithdrawMoney(), GetGuildBankMoney()) or 0
	local source, shortage = Options.ChooseFunds(Options:Get(Options.REPAIR_FUNDS_PATH), cost, canGuild, guildFunds,
		GetMoney())
	local price = GetMoneyString(cost, true)

	if source == "guild" then
		RepairAllItems(true)
		AUI:Print(L["Repaired for %s from guild funds."], price)
	elseif source == "personal" then
		RepairAllItems()
		AUI:Print(L["Repaired for %s."], price)
	elseif shortage == "guild" then
		AUI:Print(L["Not enough guild funds to repair (%s)."], price)
	else
		AUI:Print(L["Not enough money to repair (%s)."], price)
	end
end
