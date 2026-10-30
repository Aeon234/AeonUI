local AUI = select(2, ...)

local Options = AUI.DeleteCheapestItemOptions
local Prices = AUI.DeleteCheapestItemPrices

---Reads the general-purpose bags into candidates for the list. Profession bags are skipped: emptying one of their
---slots makes no room for ordinary loot.
---@class AUIDeleteCheapestItemBags
local Bags = {}
AUI.DeleteCheapestItemBags = Bags

---@param bag integer
---@param slot integer
---@param info ContainerItemInfo
---@param auction boolean auction prices are wanted
---@return AUIDeleteCheapestItemCandidate item
function Bags:Candidate(bag, slot, info, auction)
	local name, _, _, _, _, _, _, _, _, _, sellPrice, classID = C_Item.GetItemInfo(info.hyperlink)
	local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
	local cached = name ~= nil and sellPrice ~= nil

	return {
		bag = bag,
		slot = slot,
		itemID = info.itemID,
		link = info.hyperlink,
		name = name,
		quality = info.quality or 0,
		count = info.stackCount,
		vendor = cached and (info.hasNoValue and 0 or sellPrice) or nil,
		auction = cached and auction and Prices:Auction(info.hyperlink) or nil,
		bound = info.isBound,
		locked = info.isLocked,
		quest = classID == Enum.ItemClass.Questitem or quest.isQuestItem or quest.questID ~= nil,
	}
end

---@param auction boolean auction prices are wanted
---@return AUIDeleteCheapestItemCandidate[] items in bag and slot order
---@return integer free free slots in general-purpose bags
function Bags:Scan(auction)
	local items, bags = {}, {}

	for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
		local free, family = C_Container.GetContainerNumFreeSlots(bag)

		bags[#bags + 1] = { free = free, family = family }

		if family == 0 then
			for slot = 1, C_Container.GetContainerNumSlots(bag) do
				local info = C_Container.GetContainerItemInfo(bag, slot)

				if info then
					items[#items + 1] = self:Candidate(bag, slot, info, auction)
				end
			end
		end
	end

	return items, Options.FreeSlots(bags)
end

---The list's rows by the profile's rules, with the free slots.
---@param ignored table<integer, true>? item IDs never suggested
---@return AUIDeleteCheapestItemEntry[] entries
---@return integer free
---@return integer uncached
function Bags:List(ignored)
	local rules = Options:Rules()
	local items, free = self:Scan(rules.price ~= "VENDOR")
	local entries, uncached = Options.Build(items, rules, ignored)

	return entries, free, uncached
end
