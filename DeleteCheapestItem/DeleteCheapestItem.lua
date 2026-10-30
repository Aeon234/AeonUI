local AUI = select(2, ...)

local L = AUI.L
local Options = AUI.DeleteCheapestItemOptions
local Window = AUI.DeleteCheapestItemWindow
local Actions = AUI.DeleteCheapestItemActions
local Openers = AUI.DeleteCheapestItemOpeners

-- The hidden button the key binding clicks (Bindings.xml).
local TOGGLE_BUTTON = "AeonUIDeleteCheapestItemToggle"

_G["BINDING_NAME_CLICK " .. TOGGLE_BUTTON .. ":LeftButton"] = L["Delete Cheapest Item"]

-- Events that change the list while the window is shown.
local LIST_EVENTS = { "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED" }

---The Delete Cheapest Item module: the window, opened by hand with `/aui dci` or the key binding and by its openers
---(loot, merchant, quest rewards). Nothing runs while the feature is off, and the list follows the bags only while
---the window is shown.
---@class AUIDeleteCheapestItem
---@field active boolean started this session
---@field following boolean the list's events are followed
local DeleteCheapestItem = {
	active = false,
	following = false,
}
AUI.DeleteCheapestItem = DeleteCheapestItem

---@return boolean on
function DeleteCheapestItem:IsOn()
	return AUI.can.deleteCheapestItem == true and Options:Get(Options.ENABLED_PATH) == true
end

---@param event string
function DeleteCheapestItem:OnListChanged(event)
	if event == "BAG_UPDATE_DELAYED" then
		Actions:OnBagsSettled()
	end

	AUI.Events:Coalesce("dciRefresh", function()
		Window:Refresh()
	end)
end

---@param shown boolean
function DeleteCheapestItem:Follow(shown)
	if shown == self.following then
		return
	end

	self.following = shown

	for _, event in ipairs(LIST_EVENTS) do
		if shown then
			AUI.Events:Register(event, self, self.OnListChanged)
		else
			AUI.Events:Unregister(event, self)
		end
	end
end

---Opens the window beside the open bags, or at the screen's left edge, or closes it when it is open.
function DeleteCheapestItem:Toggle()
	if not self.active then
		return
	end

	if not self:IsOn() then
		AUI:Print(L["Delete Cheapest Item is off. Turn it on in AeonUI's settings."])

		return
	end

	if Window:IsShown() then
		Window:Close()

		return
	end

	Window:Open({ kind = "HAND", opener = Window:OpenBags() })
end

function DeleteCheapestItem:Apply()
	local on = self:IsOn()

	Openers:Follow(on)

	if not on then
		Window:Close()

		return
	end

	Window:Refresh()
end

---@param path string? the changed setting; nil when the whole profile changed
function DeleteCheapestItem:OnProfileChanged(path)
	if path == nil or path:sub(1, 19) == "deleteCheapestItem." then
		AUI.Events:Coalesce("dciApply", function()
			DeleteCheapestItem:Apply()
		end)
	end
end

function DeleteCheapestItem:Start()
	if self.active then
		return
	end

	self.active = true
	Window.onShown = function(shown, byCode)
		self:Follow(shown)

		if not shown and not byCode then
			Openers:Dismissed(Window.context)
		end
	end
	AUI.Callbacks:Register("Profile", self, self.OnProfileChanged)
	self:Apply()
end

local toggle = CreateFrame("Button", TOGGLE_BUTTON, UIParent)

toggle:SetScript("OnClick", function()
	DeleteCheapestItem:Toggle()
end)
