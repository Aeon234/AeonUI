local AUI = select(2, ...)

local Schema = AUI.Schema

-- The Hearthstone, never suggested.
local HEARTHSTONES = { [6948] = true }

-- The share of a sale the auction house keeps.
local AUCTION_CUT = 0.05

local COPPER_PER_SILVER = 100
local COPPER_PER_GOLD = 10000

---What an item's worth is reckoned from.
---@class AUIDeleteCheapestItemPriced
---@field count integer the stack's size
---@field vendor number? copper one item sells for; nil while not cached
---@field auction number? copper one item fetches at auction, when an auction addon knows it

---A bag item as the scan reports it, before any rule applies.
---@class AUIDeleteCheapestItemCandidate : AUIDeleteCheapestItemPriced
---@field bag integer
---@field slot integer
---@field itemID integer
---@field link string
---@field icon number the item's icon file
---@field name string? nil while the item's info is not cached
---@field quality integer
---@field bound boolean
---@field locked boolean
---@field quest boolean a quest item or one that starts a quest

---A row of the list: one candidate, or identical stacks shown once.
---@class AUIDeleteCheapestItemEntry : AUIDeleteCheapestItemCandidate
---@field name string
---@field value number copper the stack is worth, by the price choice
---@field source "VENDOR"|"AUCTION" where the value comes from
---@field stacks integer how many identical stacks the row stands for
---@field slots { bag: integer, slot: integer }[] every identical stack's place, the first one's first

---The rules a list is built by, read from the profile.
---@class AUIDeleteCheapestItemRules
---@field maxQuality integer the highest quality listed
---@field hideBound boolean soulbound items are left out
---@field hideNoValue boolean items that sell for nothing are left out
---@field price "VENDOR"|"AUCTION"|"HIGHER" which price an item is worth

---The Delete Cheapest Item settings and their frame-free rules: which bag items are listed, what each is worth,
---identical stacks shown once, the order, when a delete asks first, free slots, money in coins, and the ignore list.
---@class AUIDeleteCheapestItemOptions
---@field ENABLED_PATH string the feature is on
---@field OPEN_BAGS_FULL_PATH string the window opens when loot does not fit
---@field OPEN_FREE_SLOTS_PATH string the window opens on loot while free slots are at most this; 0 turns it off
---@field OPEN_MERCHANT_PATH string the window opens beside a merchant when a purchase does not fit
---@field OPEN_QUEST_PATH string the window opens beside quest rewards that need more slots than are free
---@field MAX_QUALITY_PATH string a `dciQuality` choice
---@field HIDE_BOUND_PATH string
---@field HIDE_NO_VALUE_PATH string
---@field PRICE_PATH string a `dciPrice` choice
---@field QUALITIES string[] the quality choices, lowest first
---@field QUALITY table<string, integer> each quality choice's `Enum.ItemQuality` value
---@field PRICES string[]
---@field AUCTION_CUT number the share of a sale the auction house keeps, taken from every auction price
local Options = {
	ENABLED_PATH = "deleteCheapestItem.enabled",
	OPEN_BAGS_FULL_PATH = "deleteCheapestItem.open.bagsFull",
	OPEN_FREE_SLOTS_PATH = "deleteCheapestItem.open.freeSlots",
	OPEN_MERCHANT_PATH = "deleteCheapestItem.open.merchant",
	OPEN_QUEST_PATH = "deleteCheapestItem.open.questRewards",
	MAX_QUALITY_PATH = "deleteCheapestItem.maxQuality",
	HIDE_BOUND_PATH = "deleteCheapestItem.hideBound",
	HIDE_NO_VALUE_PATH = "deleteCheapestItem.hideNoValue",
	PRICE_PATH = "deleteCheapestItem.price",
	QUALITIES = { "POOR", "COMMON", "UNCOMMON", "RARE", "EPIC" },
	QUALITY = { POOR = 0, COMMON = 1, UNCOMMON = 2, RARE = 3, EPIC = 4 },
	-- HIGHER: the auction price when an auction addon knows one above the vendor price, otherwise the vendor price.
	PRICES = { "VENDOR", "AUCTION", "HIGHER" },
	AUCTION_CUT = AUCTION_CUT,
}
AUI.DeleteCheapestItemOptions = Options

Schema:Choices("dciQuality", Options.QUALITIES)
Schema:Choices("dciPrice", Options.PRICES)

Schema:Boolean(Options.ENABLED_PATH, false)
Schema:Boolean(Options.OPEN_BAGS_FULL_PATH, true)
Schema:Number(Options.OPEN_FREE_SLOTS_PATH, 0, 0, 20, true)
Schema:Boolean(Options.OPEN_MERCHANT_PATH, true)
Schema:Boolean(Options.OPEN_QUEST_PATH, true)
Schema:Choice(Options.MAX_QUALITY_PATH, "dciQuality", "UNCOMMON")
Schema:Boolean(Options.HIDE_BOUND_PATH, true)
Schema:Boolean(Options.HIDE_NO_VALUE_PATH, true)
Schema:Choice(Options.PRICE_PATH, "dciPrice", "HIGHER")

---@param path string one of the paths above
---@return any value
function Options:Get(path)
	return AUI.Profile:Get(path)
end

---@return AUIDeleteCheapestItemRules rules the profile's
function Options:Rules()
	return {
		maxQuality = self.QUALITY[self:Get(self.MAX_QUALITY_PATH)] or self.QUALITY.UNCOMMON,
		hideBound = self:Get(self.HIDE_BOUND_PATH),
		hideNoValue = self:Get(self.HIDE_NO_VALUE_PATH),
		price = self:Get(self.PRICE_PATH),
	}
end

---Why a candidate is left out of the list.
---@param item AUIDeleteCheapestItemCandidate
---@param rules AUIDeleteCheapestItemRules
---@param ignored table<integer, true>? item IDs the player chose never to see
---@return "uncached"|"locked"|"quest"|"hearthstone"|"ignored"|"quality"|"bound"|"noValue"|nil reason nil when listed
function Options.Excluded(item, rules, ignored)
	if not item.name or not item.vendor then
		return "uncached"
	end

	if item.locked then
		return "locked"
	end

	if item.quest then
		return "quest"
	end

	if HEARTHSTONES[item.itemID] then
		return "hearthstone"
	end

	if ignored and ignored[item.itemID] then
		return "ignored"
	end

	if item.quality > rules.maxQuality then
		return "quality"
	end

	if rules.hideBound and item.bound then
		return "bound"
	end

	if rules.hideNoValue and item.vendor <= 0 then
		return "noValue"
	end

	return nil
end

---What a stack is worth, by the price choice. An auction price stands only when an auction addon knows one, and loses
---the auction house's cut.
---@param item AUIDeleteCheapestItemPriced a candidate, or a loot slot's item
---@param rules AUIDeleteCheapestItemRules
---@return number value copper, whole
---@return "VENDOR"|"AUCTION" source
function Options.Price(item, rules)
	local vendor = (item.vendor or 0) * item.count
	local auction = item.auction

	if auction and rules.price ~= "VENDOR" then
		auction = math.floor(auction * item.count * (1 - AUCTION_CUT))

		if rules.price == "AUCTION" or auction > vendor then
			return auction, "AUCTION"
		end
	end

	return vendor, "VENDOR"
end

---@param a AUIDeleteCheapestItemEntry
---@param b AUIDeleteCheapestItemEntry
---@return boolean first a comes before b: cheaper, then lower quality, then by name, then by bag and slot
local function Before(a, b)
	if a.value ~= b.value then
		return a.value < b.value
	end

	if a.quality ~= b.quality then
		return a.quality < b.quality
	end

	if a.name ~= b.name then
		return a.name < b.name
	end

	if a.bag ~= b.bag then
		return a.bag < b.bag
	end

	return a.slot < b.slot
end

---The list's rows: the candidates the rules keep, priced, with identical stacks (the same link and stack size) shown
---once, cheapest first. Candidates are not changed.
---@param items AUIDeleteCheapestItemCandidate[] in bag and slot order
---@param rules AUIDeleteCheapestItemRules
---@param ignored table<integer, true>?
---@return AUIDeleteCheapestItemEntry[] entries
---@return integer uncached candidates left out because their info is not cached yet
function Options.Build(items, rules, ignored)
	---@type AUIDeleteCheapestItemEntry[]
	local entries = {}
	local byKey, uncached = {}, 0

	for _, item in ipairs(items) do
		local reason = Options.Excluded(item, rules, ignored)

		if reason == "uncached" then
			uncached = uncached + 1
		elseif not reason then
			local key = item.link .. "\0" .. item.count
			local entry = byKey[key]

			if entry then
				entry.stacks = entry.stacks + 1
				entry.slots[#entry.slots + 1] = { bag = item.bag, slot = item.slot }
			else
				entry = {} --[[@as AUIDeleteCheapestItemEntry]]

				for field, value in pairs(item) do
					entry[field] = value
				end

				entry.value, entry.source = Options.Price(item, rules)
				entry.stacks = 1
				entry.slots = { { bag = item.bag, slot = item.slot } }
				byKey[key] = entry
				entries[#entries + 1] = entry
			end
		end
	end

	table.sort(entries, Before)

	return entries, uncached
end

---A delete asks first only when the row is worth strictly more than what it makes room for.
---@param value number copper the row is worth
---@param incoming number? copper the incoming item is worth; nil when nothing is incoming
---@return boolean ask
function Options.NeedsConfirm(value, incoming)
	return incoming ~= nil and value > incoming
end

---Free slots in general-purpose bags; profession bags (any other family) do not count.
---@param bags { free: integer, family: integer? }[] each bag's free slots and family
---@return integer free
function Options.FreeSlots(bags)
	local free = 0

	for _, bag in ipairs(bags) do
		if bag.family == 0 then
			free = free + bag.free
		end
	end

	return free
end

---Whether loot should open the window for free slots alone, before the bags are full.
---@param free integer
---@param threshold integer 0 turns it off
---@return boolean open
function Options.LowOnSpace(free, threshold)
	return threshold > 0 and free <= threshold
end

---@param copper number
---@return integer gold
---@return integer silver
---@return integer copper
function Options.Coins(copper)
	copper = math.max(0, math.floor(copper))

	return math.floor(copper / COPPER_PER_GOLD), math.floor(copper % COPPER_PER_GOLD / COPPER_PER_SILVER),
		copper % COPPER_PER_SILVER
end

---Adds or removes an item ID in an ignore list.
---@param ignored table<integer, true>
---@param itemID integer
---@param ignore boolean
function Options.SetIgnored(ignored, itemID, ignore)
	ignored[itemID] = ignore or nil
end

---@param ignored table<integer, true>
---@return integer[] itemIDs ascending
function Options.IgnoredList(ignored)
	local list = {}

	for itemID in pairs(ignored) do
		list[#list + 1] = itemID
	end

	table.sort(list)

	return list
end

---Which side of its opener the window takes: the right when it fits on screen there, otherwise the left when it fits
---there, otherwise the right, where the screen's clamp keeps it visible. All values are in the window's coordinates.
---@param openerLeft number
---@param openerRight number
---@param width number the window's width
---@param gap number the space between the opener and the window
---@param screenLeft number
---@param screenRight number
---@return "RIGHT"|"LEFT" side
function Options.Side(openerLeft, openerRight, width, gap, screenLeft, screenRight)
	if openerRight + gap + width <= screenRight then
		return "RIGHT"
	end

	if openerLeft - gap - width >= screenLeft then
		return "LEFT"
	end

	return "RIGHT"
end

---The key that follows a row across list rebuilds: its item, stack size and first stack's place.
---@param entry AUIDeleteCheapestItemEntry
---@return string key
function Options.RowKey(entry)
	return ("%s#%d#%d#%d"):format(entry.link, entry.count, entry.bag, entry.slot)
end

---Bag slots a quest's rewards need: one for the chosen reward when there is a choice, one per other reward, less the
---slots the items handed in free. Rewards that would stack onto items already carried are not known, so none is
---assumed to.
---@param choices integer `GetNumQuestChoices()`
---@param rewards integer `GetNumQuestRewards()`
---@param handedIn integer `GetNumQuestItems()` as the quest's progress showed it
---@return integer needed
function Options.QuestSlotsNeeded(choices, rewards, handedIn)
	return math.max(0, (choices > 0 and 1 or 0) + rewards - handedIn)
end
