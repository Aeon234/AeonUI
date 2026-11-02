local AUI = select(2, ...)

local Options = AUI.DeleteCheapestItemOptions
local Bags = AUI.DeleteCheapestItemBags
local Window = AUI.DeleteCheapestItemWindow

local EVENTS = {
	"UI_ERROR_MESSAGE", "LOOT_OPENED", "LOOT_CLOSED", "LOOT_SLOT_CLEARED", "MERCHANT_CLOSED", "QUEST_PROGRESS",
	"QUEST_COMPLETE", "QUEST_FINISHED",
}

---Opens the window beside the window it helps: loot that does not fit (the inventory-full error, or free slots at the
---threshold as loot opens), a purchase that does not fit at a merchant, and quest rewards that need more slots than
---are free. Closing it by hand keeps it closed until that loot, merchant or quest window closes.
---@class AUIDeleteCheapestItemOpeners
---@field following boolean the events are followed
---@field waitingForLoot boolean the inventory-full error arrived before the loot window; it opens with the window
---@field handedIn integer items the open quest takes, as its progress showed them
---@field dismissed table<string, true> contexts closed by hand, by kind, until their window closes
local Openers = {
	following = false,
	waitingForLoot = false,
	handedIn = 0,
	dismissed = {},
}
AUI.DeleteCheapestItemOpeners = Openers

---@param path string
---@return boolean on
local function On(path)
	return Options:Get(path) == true
end

---@return integer? slot the loot slot to make room for: the one last clicked while it holds an item, else the first
local function LootSlotToTake()
	local selected = LootFrame.selectedSlot

	if selected and Bags:Incoming(selected) then
		return selected
	end

	for slot = 1, GetNumLootItems() do
		if Bags:Incoming(slot) then
			return slot
		end
	end

	return nil
end

---Opens the window beside the loot window, making room for its next item, unless it was closed by hand.
function Openers:OpenLoot()
	if self.dismissed.LOOT or not LootFrame:IsShown() then
		return
	end

	local slot = LootSlotToTake()

	Window:Open({ kind = "LOOT", opener = LootFrame, incoming = slot and Bags:Incoming(slot), lootSlot = slot })
end

---@param kind string
local function CloseFor(kind)
	local context = Window.context

	if context and context.kind == kind then
		Window:Close()
	end
end

---@param event string
---@param ... any
function Openers:OnEvent(event, ...)
	if event == "UI_ERROR_MESSAGE" then
		local _, message = ...

		if AUI:Readable(message) ~= ERR_INV_FULL then
			return
		end

		if LootFrame:IsShown() then
			if On(Options.OPEN_BAGS_FULL_PATH) then
				self:OpenLoot()
			end
		elseif MerchantFrame:IsShown() then
			if On(Options.OPEN_MERCHANT_PATH) and not self.dismissed.MERCHANT then
				Window:Open({ kind = "MERCHANT", opener = MerchantFrame })
			end
		elseif On(Options.OPEN_BAGS_FULL_PATH) then
			self.waitingForLoot = true
		end
	elseif event == "LOOT_OPENED" then
		-- The loot window shows from its own handler of this event; look once it has.
		AUI.Events:Coalesce("dciLootOpened", function()
			local waiting = self.waitingForLoot

			self.waitingForLoot = false

			if waiting or Options.LowOnSpace(Bags:FreeSlots(), Options:Get(Options.OPEN_FREE_SLOTS_PATH)) then
				self:OpenLoot()
			end
		end)
	elseif event == "LOOT_SLOT_CLEARED" then
		local slot = ...
		local context = Window.context

		if Window:IsShown() and context and context.kind == "LOOT" and context.lootSlot == slot then
			self:OpenLoot()
		end
	elseif event == "LOOT_CLOSED" then
		self.waitingForLoot = false
		self.dismissed.LOOT = nil
		CloseFor("LOOT")
	elseif event == "MERCHANT_CLOSED" then
		self.dismissed.MERCHANT = nil
		CloseFor("MERCHANT")
	elseif event == "QUEST_PROGRESS" then
		self.handedIn = GetNumQuestItems() or 0
	elseif event == "QUEST_COMPLETE" then
		-- The quest window shows its rewards from its own handler of this event; look once it has.
		AUI.Events:Coalesce("dciQuestComplete", function()
			local needed = Options.QuestSlotsNeeded(GetNumQuestChoices() or 0, GetNumQuestRewards() or 0,
				self.handedIn)

			if On(Options.OPEN_QUEST_PATH) and not self.dismissed.QUEST and needed > Bags:FreeSlots() then
				Window:Open({ kind = "QUEST", opener = QuestFrame })
			end
		end)
	elseif event == "QUEST_FINISHED" then
		self.handedIn = 0
		self.dismissed.QUEST = nil
		CloseFor("QUEST")
	end
end

---Records a window closed by hand, so its opener leaves it closed until its own window closes.
---@param context AUIDeleteCheapestItemContext?
function Openers:Dismissed(context)
	if context and context.kind ~= "HAND" then
		self.dismissed[context.kind] = true
	end
end

---@param on boolean
function Openers:Follow(on)
	if on == self.following then
		return
	end

	self.following = on

	for _, event in ipairs(EVENTS) do
		if on then
			AUI.Events:Register(event, self, self.OnEvent)
		else
			AUI.Events:Unregister(event, self)
		end
	end

	if not on then
		self.waitingForLoot = false
		self.handedIn = 0
		self.dismissed = {}
	end
end
