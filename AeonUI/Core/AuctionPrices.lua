local AUI = select(2, ...)

-- The caller name Auctionator's API asks for.
local CALLER = "AeonUI"
-- TradeSkillMaster's price sources: the realm's lowest buyout in its latest data, and the region's market average.
local TSM_REALM, TSM_REGION = "DBMinBuyout", "DBRegionMarketAvg"
local SECONDS_PER_DAY = 86400

---Auction prices from Auctionator, TradeSkillMaster and Oribos Exchange, whichever are loaded, each looked up when a
---price is asked for, so an addon loaded after AeonUI is still found, and each called through `pcall`. Each addon
---gives a quote with its age in days; the newest quote wins, and on a tie the earlier source in `SOURCES`:
---Auctionator (the player's own scans), TradeSkillMaster (its data has no age and counts as today's), Oribos Exchange.
---@class AUIAuctionPrices
---@field SOURCES string[]
local AuctionPrices = {
	SOURCES = { "AUCTIONATOR", "TSM", "ORIBOS" },
}
AUI.AuctionPrices = AuctionPrices

---@class AUIAuctionQuote
---@field price number copper for one item
---@field age number days since the price was seen
---@field rank number the source's place in `SOURCES`

---@return table? api Auctionator's API, when loaded
local function Auctionator()
	local auctionator = _G.Auctionator
	local api = auctionator and auctionator.API and auctionator.API.v1

	return api and api.GetAuctionPriceByItemLink and api or nil
end

---@return table? api TradeSkillMaster's API, when loaded
local function TSM()
	local api = _G.TSM_API

	return api and api.GetCustomPriceValue and api.ToItemString and api or nil
end

---@return function? market Oribos Exchange's price lookup, when loaded
local function Oribos()
	local market = _G.OEMarketInfo

	return type(market) == "function" and market or nil
end

---@return string[] sources the loaded sources, in `SOURCES` order
function AuctionPrices:Sources()
	local loaded = { AUCTIONATOR = Auctionator() ~= nil, TSM = TSM() ~= nil, ORIBOS = Oribos() ~= nil }
	local sources = {}

	for _, source in ipairs(self.SOURCES) do
		if loaded[source] then
			sources[#sources + 1] = source
		end
	end

	return sources
end

---@return boolean any an auction addon is loaded
function AuctionPrices:HasSource()
	return #self:Sources() > 0
end

---@param value any
---@return number? price a positive number, or nil
local function Price(value)
	return type(value) == "number" and value > 0 and value or nil
end

---Adds a quote when the price is positive.
---@param quotes AUIAuctionQuote[]
---@param price any
---@param age any days; anything but a number counts as today
---@param rank number
local function Quote(quotes, price, age, rank)
	price = Price(price)

	if price then
		quotes[#quotes + 1] = { price = price, age = type(age) == "number" and age or 0, rank = rank }
	end
end

---@param quotes AUIAuctionQuote[]
---@return number? price the newest quote's price, the earlier source's on a tie
function AuctionPrices.Newest(quotes)
	local best

	for _, quote in ipairs(quotes) do
		if not best or quote.age < best.age or (quote.age == best.age and quote.rank < best.rank) then
			best = quote
		end
	end

	return best and best.price or nil
end

---@param link string
---@param itemID number? read from the link when nil
---@return AUIAuctionQuote[] realm the realm's quotes
---@return AUIAuctionQuote[] region the region's quotes
function AuctionPrices:Quotes(link, itemID)
	local realm, region = {}, {}
	local auctionator, tsm, oribos = Auctionator(), TSM(), Oribos()

	if auctionator then
		local ok, price = pcall(auctionator.GetAuctionPriceByItemLink, CALLER, link)
		local aged, age = false, nil

		if ok and Price(price) and auctionator.GetAuctionAgeByItemLink then
			aged, age = pcall(auctionator.GetAuctionAgeByItemLink, CALLER, link)
		end

		if ok then
			Quote(realm, price, aged and age or nil, 1)
		end
	end

	if tsm then
		local converted, itemString = pcall(tsm.ToItemString, link)

		if converted and type(itemString) == "string" then
			local ok, price = pcall(tsm.GetCustomPriceValue, TSM_REALM, itemString)

			if ok then
				Quote(realm, price, 0, 2)
			end

			ok, price = pcall(tsm.GetCustomPriceValue, TSM_REGION, itemString)

			if ok then
				Quote(region, price, 0, 2)
			end
		end
	end

	if oribos then
		itemID = itemID or C_Item.GetItemInfoInstant(link)
	end

	if oribos and itemID then
		local info = {}
		local ok = pcall(oribos, itemID, info)
		local age = type(info.age) == "number" and info.age / SECONDS_PER_DAY or nil

		if ok then
			Quote(realm, info.market, age, 3)
			Quote(region, info.region, age, 3)
		end
	end

	return realm, region
end

---@param link string
---@param itemID number?
---@param commodity boolean the item sells region-wide, so a realm quote is a region price
---@return number? realm the realm's price for one item
---@return number? region the region's price for one item
function AuctionPrices:Lookup(link, itemID, commodity)
	local realm, region = self:Quotes(link, itemID)

	if commodity then
		for _, quote in ipairs(realm) do
			region[#region + 1] = quote
		end

		realm = {}
	end

	return self.Newest(realm), self.Newest(region)
end

---@param link string
---@param itemID number?
---@return number? price one item's auction price: the realm's, or the region's without one
function AuctionPrices:Auction(link, itemID)
	local realm, region = self:Lookup(link, itemID, false)

	return realm or region
end
