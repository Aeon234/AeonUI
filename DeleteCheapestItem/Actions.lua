local AUI = select(2, ...)

local Options = AUI.DeleteCheapestItemOptions

-- The account-wide key in `AeonUIDB.global` holding the item IDs never suggested.
local IGNORED_KEY = "deleteCheapestItemIgnored"

---What a row's action does to the bags: delete or sell one of its stacks after checking the slot still holds it, then
---take the loot a delete made room for once the bags have settled. Also owns the ignore list.
---@class AUIDeleteCheapestItemActions
---@field pending { loot: integer? }? the delete waiting for the bags to settle
local Actions = {}
AUI.DeleteCheapestItemActions = Actions

---@return table<integer, true>? ignored the account-wide ignore list; nil while the saved data cannot be used
function Actions:Ignored()
	local global = AUI.Profile:Global()

	if not global then
		return nil
	end

	if type(global[IGNORED_KEY]) ~= "table" then
		global[IGNORED_KEY] = {}
	end

	return global[IGNORED_KEY]
end

---@param itemID integer
---@param ignore boolean
function Actions:SetIgnored(itemID, ignore)
	local ignored = self:Ignored()

	if ignored then
		Options.SetIgnored(ignored, itemID, ignore)
	end
end

---@param entry AUIDeleteCheapestItemEntry
---@return { bag: integer, slot: integer }? place the first of the row's stacks still holding what the row showed,
---unlocked
local function Find(entry)
	for _, place in ipairs(entry.slots) do
		local info = C_Container.GetContainerItemInfo(place.bag, place.slot)

		if info and info.hyperlink == entry.link and info.stackCount == entry.count and not info.isLocked then
			return place
		end
	end

	return nil
end

---Deletes one of the row's stacks. The cursor must be empty before the pickup and hold the row's item after it;
---anything left on it afterwards is cleared.
---@param entry AUIDeleteCheapestItemEntry
---@param lootSlot integer? the loot slot to take once the bags have settled
---@return boolean done
---@return "cursor"|"changed"|"pickup"|nil problem
function Actions:Delete(entry, lootSlot)
	if CursorHasItem() then
		return false, "cursor"
	end

	local place = Find(entry)

	if not place then
		return false, "changed"
	end

	C_Container.PickupContainerItem(place.bag, place.slot)

	local kind, itemID = GetCursorInfo()

	if kind ~= "item" or itemID ~= entry.itemID then
		ClearCursor()

		return false, "pickup"
	end

	DeleteCursorItem()

	if CursorHasItem() then
		ClearCursor()
	end

	self.pending = { loot = lootSlot }

	return true
end

---Sells one of the row's stacks to the open merchant.
---@param entry AUIDeleteCheapestItemEntry
---@return boolean done
---@return "changed"|nil problem
function Actions:Sell(entry)
	local place = Find(entry)

	if not place then
		return false, "changed"
	end

	C_Container.UseContainerItem(place.bag, place.slot)

	return true
end

---Takes the loot slot the last delete made room for, now that the bags have settled.
function Actions:OnBagsSettled()
	local pending = self.pending

	self.pending = nil

	if pending and pending.loot and pending.loot <= GetNumLootItems() and LootSlotHasItem(pending.loot) then
		LootSlot(pending.loot)
	end
end
