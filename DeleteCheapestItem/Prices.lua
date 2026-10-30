local AUI = select(2, ...)

-- The caller name Auctionator's API asks for.
local CALLER = "AeonUI"

-- TSM's market value, its price source key.
local TSM_SOURCE = "dbmarket"

---Auction prices from Auctionator or TradeSkillMaster, whichever is loaded, Auctionator first. Each addon is looked up
---when a price is asked for, so one loaded after AeonUI is still found.
---@class AUIDeleteCheapestItemPrices
local Prices = {}
AUI.DeleteCheapestItemPrices = Prices

---@return "AUCTIONATOR"|"TSM"|nil source the auction addon prices come from
function Prices:Source()
	local auctionator = _G.Auctionator
	local api = auctionator and auctionator.API and auctionator.API.v1

	if api and api.GetAuctionPriceByItemLink then
		return "AUCTIONATOR"
	end

	local tsm = _G.TSM_API

	if tsm and tsm.GetCustomPriceValue and tsm.ToItemString then
		return "TSM"
	end

	return nil
end

---@param link string
---@return number? price copper one item fetches at auction; nil when no auction addon knows it
function Prices:Auction(link)
	local source = self:Source()
	local ok, price

	if source == "AUCTIONATOR" then
		ok, price = pcall(_G.Auctionator.API.v1.GetAuctionPriceByItemLink, CALLER, link)
	elseif source == "TSM" then
		local tsm = _G.TSM_API
		local converted, itemString = pcall(tsm.ToItemString, link)

		if converted and type(itemString) == "string" then
			ok, price = pcall(tsm.GetCustomPriceValue, TSM_SOURCE, itemString)
		end
	end

	if ok and type(price) == "number" and price > 0 then
		return price
	end

	return nil
end
