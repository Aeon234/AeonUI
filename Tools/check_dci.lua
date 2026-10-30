-- Checks DeleteCheapestItem/ outside the game: the settings' defaults, which bag items are left out and why, what an
-- item is worth by each price choice, identical stacks shown once, the order, when a delete asks first, free slots,
-- money in coins, the ignore list, auction prices from Auctionator or TradeSkillMaster, and the bag scan.
-- Run from any directory with Lua 5.1: lua Tools/check_dci.lua
-- Loads the real files against stubbed globals. Exits non-zero on the first failed check.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

WOW_PROJECT_ID = 1
SlashCmdList = {}
StaticPopupDialogs = {}
C_AddOns = {
	GetAddOnMetadata = function(_, field)
		return field == "Version" and "dev" or "AeonUI"
	end,
}

function CallErrorHandler(message)
	error(message, 0)
end

-- WoW's xpcall forwards extra arguments to the function, as Lua 5.2 does; Lua 5.1's does not.
local luaXpcall = xpcall
function xpcall(fn, handler, ...)
	local count, args = select("#", ...), { ... }

	return luaXpcall(function()
		return fn(unpack(args, 1, count))
	end, handler)
end

C_Timer = { After = function(_, callback)
	callback()
end }

function CreateFrame()
	return { RegisterEvent = function() end, UnregisterEvent = function() end, SetScript = function() end }
end

-- Addon table ---------------------------------------------------------------------------------------------

local AUI = {}
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
assert(loadfile(root .. "Core/Core.lua"))("AeonUI", AUI)

for _, file in ipairs({ "Core/Callbacks.lua", "Core/Events.lua", "Profile/Schema.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

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

local function Set(path, value)
	assert(value == nil or AUI.Schema:CheckValue(path, value), "not a valid value for " .. path)
	values[path] = value
end

assert(loadfile(root .. "DeleteCheapestItem/Options.lua"))("AeonUI", AUI)

local Options = AUI.DeleteCheapestItemOptions

-- Harness -------------------------------------------------------------------------------------------------

local checks = 0

local function Equal(name, actual, expected)
	checks = checks + 1
	if actual ~= expected then
		io.stderr:write(("FAIL: %s: expected %s, got %s\n"):format(name, tostring(expected), tostring(actual)))
		os.exit(1)
	end
end

local nextSlot = 0

---@return AUIDeleteCheapestItemCandidate item a cached, sellable gray item in the next slot, with fields replaced
local function Item(fields)
	nextSlot = nextSlot + 1

	local item = {
		bag = 0, slot = nextSlot, itemID = 1000 + nextSlot, link = "item:" .. (1000 + nextSlot), name = "Item",
		quality = 0, count = 1, vendor = 10, bound = false, locked = false, quest = false,
	}

	for field, value in pairs(fields or {}) do
		item[field] = value
	end

	return item
end

local function Names(entries)
	local names = {}

	for index, entry in ipairs(entries) do
		names[index] = entry.name
	end

	return table.concat(names, ",")
end

-- Defaults ------------------------------------------------------------------------------------------------

local function Default(path)
	return AUI.Schema:Field(path).default
end

Equal("off by default", Default(Options.ENABLED_PATH), false)
Equal("opens when loot does not fit", Default(Options.OPEN_BAGS_FULL_PATH), true)
Equal("no free-slot threshold", Default(Options.OPEN_FREE_SLOTS_PATH), 0)
Equal("opens beside a merchant", Default(Options.OPEN_MERCHANT_PATH), true)
Equal("opens beside quest rewards", Default(Options.OPEN_QUEST_PATH), true)
Equal("up to Uncommon", Default(Options.MAX_QUALITY_PATH), "UNCOMMON")
Equal("soulbound left out", Default(Options.HIDE_BOUND_PATH), true)
Equal("worthless left out", Default(Options.HIDE_NO_VALUE_PATH), true)
Equal("the higher price", Default(Options.PRICE_PATH), "HIGHER")
Equal("no auction cut setting", AUI.Schema:Field("deleteCheapestItem.auctionCut"), nil)
Equal("the threshold is whole", AUI.Schema:CheckValue(Options.OPEN_FREE_SLOTS_PATH, 2.5), false)
Equal("the threshold has a ceiling", AUI.Schema:CheckValue(Options.OPEN_FREE_SLOTS_PATH, 21), false)
Equal("Rare is a quality choice", AUI.Schema:CheckValue(Options.MAX_QUALITY_PATH, "RARE"), true)
Equal("Legendary is not", AUI.Schema:CheckValue(Options.MAX_QUALITY_PATH, "LEGENDARY"), false)

local rules = Options:Rules()

Equal("rules: quality as a number", rules.maxQuality, 2)
Equal("rules: soulbound", rules.hideBound, true)
Equal("rules: price", rules.price, "HIGHER")

Set(Options.MAX_QUALITY_PATH, "POOR")
Equal("rules follow the profile", Options:Rules().maxQuality, 0)
Set(Options.MAX_QUALITY_PATH, nil)

-- Left out ------------------------------------------------------------------------------------------------

local ignored = {}

Equal("a gray item is listed", Options.Excluded(Item(), rules, ignored), nil)
Equal("no name yet", Options.Excluded(Item({ name = false }), rules, ignored), "uncached")
Equal("no price yet", Options.Excluded(Item({ vendor = false }), rules, ignored), "uncached")
Equal("locked", Options.Excluded(Item({ locked = true }), rules, ignored), "locked")
Equal("quest", Options.Excluded(Item({ quest = true }), rules, ignored), "quest")
Equal("the Hearthstone", Options.Excluded(Item({ itemID = 6948 }), rules, ignored), "hearthstone")
Equal("Uncommon is listed", Options.Excluded(Item({ quality = 2 }), rules, ignored), nil)
Equal("Rare is above the limit", Options.Excluded(Item({ quality = 3 }), rules, ignored), "quality")
Equal("soulbound", Options.Excluded(Item({ bound = true }), rules, ignored), "bound")
Equal("worthless", Options.Excluded(Item({ vendor = 0 }), rules, ignored), "noValue")

local relaxed = { maxQuality = 4, hideBound = false, hideNoValue = false, price = "VENDOR" }

Equal("soulbound kept when allowed", Options.Excluded(Item({ bound = true }), relaxed, ignored), nil)
Equal("worthless kept when allowed", Options.Excluded(Item({ vendor = 0 }), relaxed, ignored), nil)
Equal("a quest item never listed", Options.Excluded(Item({ quest = true }), relaxed, ignored), "quest")

local kept = Item()

Options.SetIgnored(ignored, kept.itemID, true)
Equal("ignored", Options.Excluded(kept, rules, ignored), "ignored")
Equal("without an ignore list", Options.Excluded(kept, rules, nil), nil)

-- Prices --------------------------------------------------------------------------------------------------

local function Price(item, price)
	local value, source = Options.Price(item, { price = price })

	return value .. " " .. source
end

local stack = Item({ count = 20, vendor = 5, auction = 100 })

Equal("vendor price for the stack", Price(stack, "VENDOR"), "100 VENDOR")
Equal("auction price less the cut", Price(stack, "AUCTION"), "1900 AUCTION")
Equal("the higher is the auction's", Price(stack, "HIGHER"), "1900 AUCTION")

local cheapAuction = Item({ count = 2, vendor = 50, auction = 40 })

Equal("the higher is the vendor's", Price(cheapAuction, "HIGHER"), "100 VENDOR")
Equal("auction stands even when lower", Price(cheapAuction, "AUCTION"), "76 AUCTION")

local tie = Item({ count = 1, vendor = 95, auction = 100 })

Equal("a tie after the cut keeps the vendor's", Price(tie, "HIGHER"), "95 VENDOR")

local unknown = Item({ count = 3, vendor = 7 })

Equal("no auction price: vendor's", Price(unknown, "AUCTION"), "21 VENDOR")
Equal("no auction price: higher is vendor's", Price(unknown, "HIGHER"), "21 VENDOR")
Equal("whole copper", Price(Item({ count = 1, vendor = 0, auction = 3 }), "AUCTION"), "2 AUCTION")

-- The list ------------------------------------------------------------------------------------------------

local items = {
	Item({ name = "Linen", link = "item:2589", itemID = 2589, count = 20, vendor = 1 }),
	Item({ name = "Bone", vendor = 3 }),
	Item({ name = "Linen", link = "item:2589", itemID = 2589, count = 20, vendor = 1 }),
	Item({ name = "Linen", link = "item:2589", itemID = 2589, count = 5, vendor = 1 }),
	Item({ name = "Cloth", vendor = 5, quality = 1 }),
	Item({ name = "Bead", vendor = 5, quality = 0 }),
	Item({ name = "Waiting", vendor = false }),
	Item({ name = "Sword", vendor = 1, quality = 3 }),
	Item({ name = "Apple", vendor = 5, quality = 0 }),
}
local entries, uncached = Options.Build(items, rules, {})

Equal("cheapest first; ties by quality, then name", Names(entries), "Bone,Apple,Bead,Linen,Cloth,Linen")
Equal("uncached are counted", uncached, 1)
Equal("identical stacks shown once", entries[6].stacks, 2)
Equal("each stack's value, not the group's", entries[6].value, 20)
Equal("every identical stack's place", entries[6].slots[2].slot, items[3].slot)
Equal("the first stack is the row's", entries[6].slot, items[1].slot)
Equal("a different stack size is its own row", entries[4].count, 5)
Equal("a single stack", entries[1].stacks, 1)
Equal("the source is recorded", entries[1].source, "VENDOR")
Equal("candidates are not changed", rawget(items[1], "value"), nil)

local sameValue = { Item({ name = "Same", bag = 2, slot = 1 }), Item({ name = "Same", bag = 1, slot = 9 }) }

entries = Options.Build(sameValue, rules, {})
Equal("last tie: bag, then slot", entries[1].bag, 1)

entries = Options.Build({}, rules, {})
Equal("an empty list", #entries, 0)

-- Confirmation --------------------------------------------------------------------------------------------

Equal("worth more than the incoming item asks", Options.NeedsConfirm(101, 100), true)
Equal("worth the same does not", Options.NeedsConfirm(100, 100), false)
Equal("worth less does not", Options.NeedsConfirm(99, 100), false)
Equal("nothing incoming does not", Options.NeedsConfirm(1000000, nil), false)

-- Space ---------------------------------------------------------------------------------------------------

Equal("general bags only", Options.FreeSlots({ { free = 3, family = 0 }, { free = 8, family = 8 },
	{ free = 2, family = 0 }, { free = 1 } }), 5)
Equal("threshold off", Options.LowOnSpace(0, 0), false)
Equal("at the threshold", Options.LowOnSpace(2, 2), true)
Equal("above the threshold", Options.LowOnSpace(3, 2), false)

-- Coins ---------------------------------------------------------------------------------------------------

Equal("coins", table.concat({ Options.Coins(1234567) }, " "), "123 45 67")
Equal("copper only", table.concat({ Options.Coins(42) }, " "), "0 0 42")
Equal("fractions drop", table.concat({ Options.Coins(10099.9) }, " "), "1 0 99")
Equal("never negative", table.concat({ Options.Coins(-5) }, " "), "0 0 0")

-- Ignore list ---------------------------------------------------------------------------------------------

local list = {}

Options.SetIgnored(list, 30, true)
Options.SetIgnored(list, 4, true)
Options.SetIgnored(list, 17, true)
Options.SetIgnored(list, 30, false)
Equal("removed one at a time, the rest in order", table.concat(Options.IgnoredList(list), ","), "4,17")
Equal("a removed ID leaves no key", list[30], nil)

-- Auction prices ------------------------------------------------------------------------------------------

assert(loadfile(root .. "DeleteCheapestItem/Prices.lua"))("AeonUI", AUI)

local Prices = AUI.DeleteCheapestItemPrices
local auctionCalls = 0

Equal("no auction addon", Prices:Source(), nil)
Equal("no auction price", Prices:Auction("item:1"), nil)

_G.TSM_API = {
	ToItemString = function(link)
		return link ~= "item:bad" and ("i:" .. link:match("%d+")) or nil
	end,
	GetCustomPriceValue = function(source, itemString)
		assert(source == "dbmarket", "TSM's market value")
		auctionCalls = auctionCalls + 1

		return ({ ["i:1"] = 250, ["i:2"] = 0 })[itemString]
	end,
}
Equal("TSM", Prices:Source(), "TSM")
Equal("TSM's market value", Prices:Auction("item:1"), 250)
Equal("TSM: no price of 0", Prices:Auction("item:2"), nil)
Equal("TSM: unknown item", Prices:Auction("item:3"), nil)
Equal("TSM: no item string", Prices:Auction("item:bad"), nil)

_G.Auctionator = { API = { v1 = { GetAuctionPriceByItemLink = function(caller, link)
	assert(caller == "AeonUI", "the caller name")
	auctionCalls = auctionCalls + 1

	if link == "item:9" then
		error("Auctionator failed")
	end

	return link == "item:1" and 400 or nil
end } } }
Equal("Auctionator before TSM", Prices:Source(), "AUCTIONATOR")
Equal("Auctionator's price", Prices:Auction("item:1"), 400)
Equal("an auction addon's error is no price", Prices:Auction("item:9"), nil)

-- Bag scan ------------------------------------------------------------------------------------------------

BACKPACK_CONTAINER = 0
NUM_BAG_SLOTS = 4
Enum = { ItemClass = { Questitem = 12 } }

-- Bag 0 is the backpack, bag 1 a herb bag, bag 3 a general bag; bags 2 and 4 are empty sockets.
local bagFamilies = { [0] = 0, [1] = 32, [3] = 0 }
local bagSlots = { [0] = 4, [1] = 2, [3] = 2 }
local bagFree = { [0] = 1, [1] = 2, [2] = 0, [3] = 0, [4] = 0 }
local contents = {
	["0:1"] = { itemID = 1, hyperlink = "item:1", quality = 0, stackCount = 1, isBound = false, isLocked = false },
	["0:2"] = { itemID = 2, hyperlink = "item:2", quality = 1, stackCount = 5, isBound = false, isLocked = false },
	["0:4"] = { itemID = 4, hyperlink = "item:4", quality = 0, stackCount = 1, isBound = false, isLocked = false,
		hasNoValue = true },
	["1:1"] = { itemID = 5, hyperlink = "item:5", quality = 0, stackCount = 1, isBound = false, isLocked = false },
	["3:1"] = { itemID = 6, hyperlink = "item:6", quality = 0, stackCount = 1, isBound = false, isLocked = false },
	["3:2"] = { itemID = 7, hyperlink = "item:7", quality = 0, stackCount = 1, isBound = false, isLocked = false },
}
-- Name, sell price and class ID by link; item:7 is not cached.
local itemInfo = {
	["item:1"] = { "Bone", 3, 0 },
	["item:2"] = { "Cloth", 2, 7 },
	["item:4"] = { "Token", 50, 15 },
	["item:5"] = { "Herb", 9, 7 },
	["item:6"] = { "Note", 1, 12 },
}
local questInfo = { ["3:2"] = { isQuestItem = true, isActive = false } }

C_Container = {
	GetContainerNumFreeSlots = function(bag)
		return bagFree[bag], bagFamilies[bag]
	end,
	GetContainerNumSlots = function(bag)
		return bagSlots[bag] or 0
	end,
	GetContainerItemInfo = function(bag, slot)
		return contents[bag .. ":" .. slot]
	end,
	GetContainerItemQuestInfo = function(bag, slot)
		return questInfo[bag .. ":" .. slot] or { isQuestItem = false, isActive = false }
	end,
}
C_Item = {
	GetItemInfo = function(link)
		local info = itemInfo[link]

		if info then
			return info[1], link, 0, 1, 1, "", "", 20, "", 0, info[2], info[3]
		end
	end,
}

assert(loadfile(root .. "DeleteCheapestItem/Bags.lua"))("AeonUI", AUI)

local Bags = AUI.DeleteCheapestItemBags

auctionCalls = 0
local scanned, free = Bags:Scan(false)

Equal("general bags only: the backpack's and bag 3's items", #scanned, 5)
Equal("free slots in general bags", free, 1)
Equal("bag and slot order", scanned[1].bag .. ":" .. scanned[1].slot, "0:1")
Equal("the stack's count", scanned[2].count, 5)
Equal("the sell price", scanned[1].vendor, 3)
Equal("no auction lookups when not wanted", auctionCalls, 0)
Equal("no auction price when not wanted", scanned[1].auction, nil)
Equal("an item that sells for nothing", scanned[3].vendor, 0)
Equal("a quest item by class", scanned[4].quest, true)
Equal("a quest item by its quest info", scanned[5].quest, true)
Equal("not a quest item", scanned[1].quest, false)
Equal("uncached: no name", scanned[5].name, nil)
Equal("uncached: no price", scanned[5].vendor, nil)

scanned = Bags:Scan(true)
Equal("auction price when wanted", scanned[1].auction, 400)
Equal("no auction price for an uncached item", scanned[5].auction, nil)

auctionCalls = 0
Set(Options.PRICE_PATH, "VENDOR")
local rows, listFree, listUncached = Bags:List({})

Equal("the list: by the profile's rules", Names(rows), "Bone,Cloth")
Equal("the list: free slots", listFree, 1)
Equal("the list: uncached", listUncached, 1)
Equal("the list: vendor prices look up no auction", auctionCalls, 0)

Set(Options.PRICE_PATH, nil)
rows = Bags:List({ [1] = true })
Equal("the list: auction prices and the ignore list", Names(rows), "Cloth")
Equal("the list: no auction price keeps the vendor's", rows[1].source, "VENDOR")

io.stdout:write(("check_dci: %d checks passed\n"):format(checks))
