local AUI = select(2, ...)

local Options = AUI.NotificationOptions

local LAST_BAG = 4

---Potion Ready: once a potion the player used is off cooldown again, while a potion is still in the bags. The bags'
---potions are known by their use spell; a cast of one starts the watch, the cooldown is read when the client reports
---it, and a timer waits out the rest. A cooldown that cannot be read waits for the next report.
---@class AUIPotionNotice
---@field following boolean the events are registered
---@field potions table<number, number> each bag potion's use spell to its item
---@field watched number? the item whose cooldown is watched
---@field started boolean the watched cooldown has been seen running
---@field timer table?
local PotionNotice = {
	following = false,
	potions = {},
	started = false,
}
AUI.PotionNotice = PotionNotice

---Finds the potions in the bags and their use spells.
function PotionNotice:Scan()
	local potions = {}
	local consumable, potion = Enum.ItemClass.Consumable, Enum.ItemConsumableSubclass.Potion

	for bag = 0, NUM_BAG_SLOTS or LAST_BAG do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local itemID = C_Container.GetContainerItemID(bag, slot)

			if itemID then
				local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)

				if classID == consumable and subclassID == potion then
					local _, spellID = C_Item.GetItemSpell(itemID)

					if spellID then
						potions[spellID] = itemID
					end
				end
			end
		end
	end

	self.potions = potions
end

---@return boolean any a potion is in the bags
function PotionNotice:HasPotion()
	return next(self.potions) ~= nil
end

function PotionNotice:StopWatch()
	if self.timer then
		self.timer:Cancel()
		self.timer = nil
	end

	self.watched, self.started = nil, false
end

---Reads the watched potion's cooldown: running, it waits out the rest; over after running, it shows the notice.
function PotionNotice:Check()
	local itemID = self.watched

	if not itemID then
		return
	end

	local start, duration, enable = C_Container.GetItemCooldown(itemID)

	if issecretvalue(start) or issecretvalue(duration) or issecretvalue(enable) or not start then
		return
	end

	local state, remaining = Options:PotionCooldown(start, duration, enable, GetTime())

	if state == "running" then
		self.started = true

		if self.timer then
			self.timer:Cancel()
		end

		self.timer = C_Timer.NewTimer(remaining or 0, function()
			self.timer = nil
			PotionNotice:Check()
		end)
	elseif state == "over" and self.started then
		self:StopWatch()

		if Options:On("potion") and self:HasPotion() then
			AUI.Notifications:Show("potion")
		end
	end
end

---@param _ string
---@param unit string
---@param ... any the cast's GUID and its spell
function PotionNotice:OnCast(_, unit, ...)
	local _, spellID = ...

	if unit ~= "player" or issecretvalue(spellID) then
		return
	end

	local itemID = self.potions[spellID]

	if itemID then
		self:StopWatch()
		self.watched = itemID
	end
end

---@param event string
function PotionNotice:OnEvent(event)
	if event == "BAG_UPDATE_DELAYED" or event == "PLAYER_ENTERING_WORLD" then
		AUI.Events:Coalesce("potionScan", function()
			PotionNotice:Scan()
		end)
	else
		self:Check()
	end
end

function PotionNotice:Apply()
	local wanted = AUI.can.potionNotice == true and Options:On("potion")

	if wanted == self.following then
		return
	end

	self.following = wanted

	if wanted then
		self:Scan()

		for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD", "BAG_UPDATE_COOLDOWN",
			"PLAYER_REGEN_ENABLED" }) do
			AUI.Events:Register(event, self, self.OnEvent)
		end

		AUI.Events:Register("UNIT_SPELLCAST_SUCCEEDED", self, self.OnCast)
	else
		AUI.Events:UnregisterAll(self)
		AUI.Events:Cancel("potionScan")
		self:StopWatch()
		AUI.Notifications:Dismiss("potion")
	end
end
