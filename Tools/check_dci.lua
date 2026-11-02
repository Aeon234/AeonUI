-- Checks DeleteCheapestItem/ outside the game: the settings' defaults, which bag items are left out and why, what an
-- item is worth by each price choice, identical stacks shown once, the order, when a delete asks first, free slots,
-- money in coins, the ignore list, auction prices from Auctionator or TradeSkillMaster, the bag scan, the window's
-- side and row keys, the actions (the ignore list's store, delete, sell, the loot taken after the bags settle), and
-- the openers (loot, merchant, quest rewards, closing by hand).
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
assert(loadfile(root .. "AeonUI/Core/Core.lua"))("AeonUI", AUI)

for _, file in ipairs({ "AeonUI/Core/Callbacks.lua", "AeonUI/Core/Events.lua", "AeonUI/Profile/Schema.lua" }) do
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

assert(loadfile(root .. "AeonUI_QoL/DeleteCheapestItem/Options.lua"))("AeonUI", AUI)

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
		bag = 0, slot = nextSlot, itemID = 1000 + nextSlot, link = "item:" .. (1000 + nextSlot), icon = 0, name = "Item",
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

assert(loadfile(root .. "AeonUI/Core/AuctionPrices.lua"))("AeonUI", AUI)

local Prices = AUI.AuctionPrices
local auctionCalls = 0

Equal("no auction addon", Prices:HasSource(), false)
Equal("no auction price", Prices:Auction("item:1", 1), nil)

_G.TSM_API = {
	ToItemString = function(link)
		return link ~= "item:bad" and ("i:" .. link:match("%d+")) or nil
	end,
	GetCustomPriceValue = function(source, itemString)
		auctionCalls = auctionCalls + 1

		return source == "DBMinBuyout" and ({ ["i:1"] = 250, ["i:2"] = 0 })[itemString]
			or source == "DBRegionMarketAvg" and ({ ["i:3"] = 300 })[itemString] or nil
	end,
}
Equal("TSM", table.concat(Prices:Sources(), ","), "TSM")
Equal("TSM's lowest buyout on the realm", Prices:Auction("item:1", 1), 250)
Equal("TSM: no price of 0", Prices:Auction("item:2", 2), nil)
Equal("TSM: the region's price without the realm's", Prices:Auction("item:3", 3), 300)
Equal("TSM: unknown item", Prices:Auction("item:4", 4), nil)
Equal("TSM: no item string", Prices:Auction("item:bad", 5), nil)

_G.Auctionator = { API = { v1 = { GetAuctionPriceByItemLink = function(caller, link)
	assert(caller == "AeonUI", "the caller name")
	auctionCalls = auctionCalls + 1

	if link == "item:9" then
		error("Auctionator failed")
	end

	return link == "item:1" and 400 or nil
end } } }
Equal("Auctionator first", table.concat(Prices:Sources(), ","), "AUCTIONATOR,TSM")
Equal("Auctionator's price on a tie with TSM", Prices:Auction("item:1", 1), 400)
Equal("an auction addon's error is no price", Prices:Auction("item:9", 9), nil)
Equal("the newest of each source's quotes", Prices.Newest({ { price = 1, age = 2, rank = 1 },
	{ price = 2, age = 1, rank = 3 }, { price = 3, age = 1, rank = 2 } }), 3)

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

assert(loadfile(root .. "AeonUI_QoL/DeleteCheapestItem/Bags.lua"))("AeonUI", AUI)

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

-- Placement -----------------------------------------------------------------------------------------------

Equal("the right side when it fits", Options.Side(100, 400, 280, 4, 0, 1920), "RIGHT")
Equal("exactly fitting on the right", Options.Side(100, 400, 280, 4, 0, 684), "RIGHT")
Equal("the left side when the right is short", Options.Side(1400, 1700, 280, 4, 0, 1920), "LEFT")
Equal("exactly fitting on the left", Options.Side(284, 1700, 280, 4, 0, 1920), "LEFT")
Equal("the right when neither side fits", Options.Side(200, 1700, 280, 4, 0, 1920), "RIGHT")

local keyed = { link = "item:1", count = 20, bag = 0, slot = 3 }

Equal("a row's key", Options.RowKey(keyed), "item:1#20#0#3")
Equal("another stack size is another row", Options.RowKey({ link = "item:1", count = 5, bag = 0, slot = 3 }) ~=
	Options.RowKey(keyed), true)

-- Actions -------------------------------------------------------------------------------------------------

local global
AUI.Profile.Global = function()
	return global
end

local cursor, calls = nil, {}

local function Call(name, ...)
	calls[#calls + 1] = table.concat({ name, ... }, " ")
end

function CursorHasItem()
	return cursor ~= nil
end

function GetCursorInfo()
	if cursor then
		return "item", cursor
	end
end

function ClearCursor()
	Call("ClearCursor")
	cursor = nil
end

function DeleteCursorItem()
	Call("DeleteCursorItem", cursor)
	cursor = nil
end

C_Container.PickupContainerItem = function(bag, slot)
	Call("Pickup", bag, slot)
	cursor = contents[bag .. ":" .. slot] and contents[bag .. ":" .. slot].itemID
end
C_Container.UseContainerItem = function(bag, slot)
	Call("Use", bag, slot)
end

local lootItems = {}

function GetNumLootItems()
	return #lootItems
end

function LootSlotHasItem(slot)
	return lootItems[slot] == true
end

function LootSlot(slot)
	Call("LootSlot", slot)
end

assert(loadfile(root .. "AeonUI_QoL/DeleteCheapestItem/Actions.lua"))("AeonUI", AUI)

local Actions = AUI.DeleteCheapestItemActions

Equal("no ignore list without saved data", Actions:Ignored(), nil)
Actions:SetIgnored(1, true)
global = { deleteCheapestItemIgnored = "damaged" }
Equal("a damaged ignore list starts again", next(Actions:Ignored()), nil)
Actions:SetIgnored(42, true)
Equal("ignored, account-wide", global.deleteCheapestItemIgnored[42], true)
Actions:SetIgnored(42, false)
Equal("no longer ignored", global.deleteCheapestItemIgnored[42], nil)

---@return table entry a row standing for the given stacks of item 1 (a single Bone)
local function Row(slots)
	return { itemID = 1, link = "item:1", count = 1, slots = slots }
end

local function Calls()
	local text = table.concat(calls, ", ")

	calls = {}

	return text
end

cursor = 99
local done, problem = Actions:Delete(Row({ { bag = 0, slot = 1 } }))
Equal("never deletes while the cursor holds something", tostring(done) .. " " .. tostring(problem), "false cursor")
Equal("the cursor is left alone", Calls(), "")
cursor = nil

done, problem = Actions:Delete(Row({ { bag = 0, slot = 2 } }))
Equal("a slot holding something else is refused", tostring(done) .. " " .. tostring(problem), "false changed")
Equal("nothing picked up", Calls(), "")

contents["0:1"].isLocked = true
done, problem = Actions:Delete(Row({ { bag = 0, slot = 1 } }))
Equal("a locked slot is refused", tostring(problem), "changed")
contents["0:1"].isLocked = false

contents["3:1"] = { itemID = 1, hyperlink = "item:1", quality = 0, stackCount = 1, isBound = false, isLocked = false }
done = Actions:Delete(Row({ { bag = 0, slot = 2 }, { bag = 3, slot = 1 } }), 2)
Equal("an identical stack still in place is deleted", tostring(done), "true")
Equal("picked up, then deleted", Calls(), "Pickup 3 1, DeleteCursorItem 1")
Equal("the loot slot waits for the bags", Actions.pending.loot, 2)

lootItems = { true, true }
Actions:OnBagsSettled()
Equal("the loot is taken once the bags settle", Calls(), "LootSlot 2")
Equal("once", Actions.pending, nil)
Actions:OnBagsSettled()
Equal("nothing more to take", Calls(), "")

Actions:Delete(Row({ { bag = 0, slot = 1 } }), 2)
Calls()
lootItems = { true, false }
Actions:OnBagsSettled()
Equal("an emptied loot slot is not taken", Calls(), "")
Actions:Delete(Row({ { bag = 0, slot = 1 } }), 3)
Calls()
Actions:OnBagsSettled()
Equal("a closed loot window's slot is not taken", Calls(), "")

local swapped = Row({ { bag = 0, slot = 2 } })
swapped.link, swapped.count, swapped.itemID = "item:2", 5, 3
done, problem = Actions:Delete(swapped)
Equal("the cursor holding another item is refused", tostring(problem), "pickup")
Equal("and cleared", Calls(), "Pickup 0 2, ClearCursor")

local deletes = DeleteCursorItem

DeleteCursorItem = function()
	Call("DeleteCursorItem", cursor)
end
Actions:Delete(Row({ { bag = 0, slot = 1 } }))
DeleteCursorItem = deletes
Equal("an item still on the cursor after the delete is cleared", Calls(), "Pickup 0 1, DeleteCursorItem 1, ClearCursor")

done = Actions:Sell(Row({ { bag = 0, slot = 1 } }))
Equal("sold", tostring(done), "true")
Equal("from its slot", Calls(), "Use 0 1")
done, problem = Actions:Sell(Row({ { bag = 0, slot = 4 } }))
Equal("a moved stack is not sold", tostring(done) .. " " .. tostring(problem), "false changed")

-- Openers -------------------------------------------------------------------------------------------------

Equal("one slot for a choice, one per reward", Options.QuestSlotsNeeded(3, 1, 0), 2)
Equal("rewards without a choice", Options.QuestSlotsNeeded(0, 2, 0), 2)
Equal("items handed in free slots", Options.QuestSlotsNeeded(1, 1, 1), 1)
Equal("never below none", Options.QuestSlotsNeeded(0, 0, 3), 0)

ERR_INV_FULL = "Inventory is full."
Enum.LootSlotType = { None = 0, Item = 1, Money = 2, Currency = 3 }

local SECRET = {}

function issecretvalue(value)
	return value == SECRET
end

local function Shown(shown)
	return { shown = shown, IsShown = function(self)
		return self.shown
	end }
end

LootFrame, MerchantFrame, QuestFrame = Shown(false), Shown(false), Shown(false)

-- Loot slot 1 holds money, 2 three Cloth, 3 a Bone.
local loot = {
	{ kind = 2 },
	{ kind = 1, name = "Cloth", quantity = 3, quality = 1, link = "item:2" },
	{ kind = 1, name = "Bone", quantity = 1, quality = 0, link = "item:1" },
}

function GetNumLootItems()
	return #loot
end

function LootSlotHasItem(slot)
	return loot[slot] ~= nil and not loot[slot].taken
end

function GetLootSlotType(slot)
	return loot[slot] and loot[slot].kind or 0
end

function GetLootSlotInfo(slot)
	local item = loot[slot]

	return 0, item.name, item.quantity, nil, item.quality
end

function GetLootSlotLink(slot)
	return loot[slot] and loot[slot].link
end

local questChoices, questRewards, questItems = 0, 0, 0

function GetNumQuestChoices()
	return questChoices
end

function GetNumQuestRewards()
	return questRewards
end

function GetNumQuestItems()
	return questItems
end

-- The window as the openers see it: what it was asked to open, and whether it is shown.
local opened = {}
local window = { context = nil, shown = false }

function window:Open(context)
	self.context, self.shown = context, true
	opened[#opened + 1] = context.kind .. ":" .. tostring(context.lootSlot)
end

function window:Close()
	self.shown = false
	opened[#opened + 1] = "close"
end

function window:IsShown()
	return self.shown
end

AUI.DeleteCheapestItemWindow = window
assert(loadfile(root .. "AeonUI_QoL/DeleteCheapestItem/Openers.lua"))("AeonUI", AUI)

local Openers = AUI.DeleteCheapestItemOpeners

local function Opened()
	local text = table.concat(opened, ", ")

	opened = {}

	return text
end

local incoming = Bags:Incoming(2)

Equal("loot: money is not incoming", Bags:Incoming(1), nil)
Equal("loot: the incoming item", incoming.name .. " " .. incoming.quality, "Cloth 1")
Equal("loot: its worth for the stack", incoming.value, 6)
Equal("loot: worth by the price choice", Bags:Incoming(3).value, 380)

Openers:OnEvent("UI_ERROR_MESSAGE", 1, "Something else")
Openers:OnEvent("UI_ERROR_MESSAGE", 1, SECRET)
Equal("other errors and secret ones open nothing", Opened(), "")

Openers:OnEvent("UI_ERROR_MESSAGE", 1, ERR_INV_FULL)
Equal("the error with no loot or merchant window waits for loot", Openers.waitingForLoot, true)
LootFrame.shown = true
Openers:OnEvent("LOOT_OPENED", false, false)
Equal("the loot window opens it, for the first item", Opened(), "LOOT:2")
Equal("no longer waiting", Openers.waitingForLoot, false)
Equal("the incoming item is the slot's", window.context.incoming.name, "Cloth")

LootFrame.selectedSlot = 3
Openers:OnEvent("UI_ERROR_MESSAGE", 1, ERR_INV_FULL)
Equal("the error while looting: the clicked slot", Opened(), "LOOT:3")

loot[3].taken = true
Openers:OnEvent("LOOT_SLOT_CLEARED", 3)
Equal("its slot looted: the next item", Opened(), "LOOT:2")
Openers:OnEvent("LOOT_SLOT_CLEARED", 1)
Equal("another slot looted: nothing", Opened(), "")
loot[2].taken = true
Openers:OnEvent("LOOT_SLOT_CLEARED", 2)
Equal("no item left: nothing incoming", window.context.incoming, nil)
Opened()

Openers:Dismissed(window.context)
loot[2].taken, loot[3].taken = false, false
Openers:OnEvent("UI_ERROR_MESSAGE", 1, ERR_INV_FULL)
Equal("closed by hand: stays closed while the loot is open", Opened(), "")
Openers:OnEvent("LOOT_CLOSED")
Equal("the loot window closing closes it", Opened(), "close")
Openers:OnEvent("UI_ERROR_MESSAGE", 1, ERR_INV_FULL)
Equal("the next loot opens it again", Opened(), "LOOT:3")
LootFrame.selectedSlot = nil

Openers:OnEvent("LOOT_CLOSED")
Opened()
Set(Options.OPEN_FREE_SLOTS_PATH, 1)
Openers:OnEvent("LOOT_OPENED", false, false)
Equal("free slots at the threshold open it", Opened(), "LOOT:2")
Openers:OnEvent("LOOT_CLOSED")
Opened()
Set(Options.OPEN_FREE_SLOTS_PATH, nil)
Openers:OnEvent("LOOT_OPENED", false, false)
Equal("no threshold: opening loot alone opens nothing", Opened(), "")

Set(Options.OPEN_BAGS_FULL_PATH, false)
Openers:OnEvent("UI_ERROR_MESSAGE", 1, ERR_INV_FULL)
Equal("bags-full opening turned off", Opened(), "")
Set(Options.OPEN_BAGS_FULL_PATH, nil)
LootFrame.shown = false
Openers:OnEvent("LOOT_CLOSED")
Opened()

MerchantFrame.shown = true
Openers:OnEvent("UI_ERROR_MESSAGE", 1, ERR_INV_FULL)
Equal("a purchase that does not fit opens it beside the merchant", Opened(), "MERCHANT:nil")
Set(Options.OPEN_MERCHANT_PATH, false)
Openers:OnEvent("UI_ERROR_MESSAGE", 1, ERR_INV_FULL)
Equal("merchant opening turned off", Opened(), "")
Set(Options.OPEN_MERCHANT_PATH, nil)
Openers:OnEvent("MERCHANT_CLOSED")
Equal("the merchant closing closes it", Opened(), "close")
MerchantFrame.shown = false

questChoices, questRewards, questItems = 2, 0, 0
Openers:OnEvent("QUEST_COMPLETE")
Equal("a reward that fits opens nothing", Opened(), "")
questRewards = 1
Openers:OnEvent("QUEST_COMPLETE")
Equal("rewards needing more slots than are free open it", Opened(), "QUEST:nil")
Openers:OnEvent("QUEST_FINISHED")
Equal("the quest window closing closes it", Opened(), "close")
questItems = 1
Openers:OnEvent("QUEST_PROGRESS")
Openers:OnEvent("QUEST_COMPLETE")
Equal("items handed in make room", Opened(), "")
Openers:OnEvent("QUEST_FINISHED")
Opened()
Equal("the handed-in count is forgotten", Openers.handedIn, 0)

window.context = { kind = "HAND" }
Openers:Dismissed(window.context)
Equal("closing a window opened by hand dismisses nothing", next(Openers.dismissed), nil)

io.stdout:write(("check_dci: %d checks passed\n"):format(checks))
