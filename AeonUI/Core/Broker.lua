local AUI = select(2, ...)

local L = AUI.L

---The minimap button, from a LibDataBroker launcher, and the addon compartment entry. LibDBIcon keeps the button's
---state (hidden, position) in `global.minimapButton` and writes it in place. The entry is registered directly because
---LibDBIcon labels its entry with the launcher's name and finds the launcher by that label, which rules out color codes.
---@class AUIBroker
---@field icon table? LibDBIcon, once the button is registered
---@field state table the table LibDBIcon reads and writes
local Broker = {
	state = { hide = false },
}
AUI.Broker = Broker

---@param _ Frame
---@param button string the mouse button
local function OnClick(_, button)
	if button == "RightButton" then
		AUI:OpenEditMode()
	else
		AUI:ToggleSettings()
	end
end

---@param _ any the entry's data
---@param input table the menu's input, with the mouse button as `buttonName`
local function OnCompartmentClick(_, input)
	OnClick(nil, input.buttonName)
end

---@param tooltip GameTooltip
local function OnTooltipShow(tooltip)
	tooltip:AddLine(AUI.brand)
	tooltip:AddLine(L["Left-click: open settings"], 1, 1, 1)
	tooltip:AddLine(L["Right-click: open edit mode"], 1, 1, 1)
end

---@param button Button
local function OnCompartmentEnter(button)
	GameTooltip:SetOwner(button, "ANCHOR_LEFT")
	OnTooltipShow(GameTooltip)
	GameTooltip:Show()
end

local function OnCompartmentLeave()
	GameTooltip:Hide()
end

---Registers the launcher once saved data is loaded. In recovery the button keeps a state that is not saved, so the
---Recovery page stays reachable.
function Broker:Create()
	if self.icon then
		return
	end

	local global = AUI.Profile:Global()

	if global then
		global.minimapButton = type(global.minimapButton) == "table" and global.minimapButton or { hide = false }
		self.state = global.minimapButton
	end

	local broker = LibStub("LibDataBroker-1.1", true)
	local icon = LibStub("LibDBIcon-1.0", true)

	if not broker or not icon then
		return
	end

	local launcher = broker:NewDataObject(AUI.name, {
		type = "launcher",
		icon = AUI.Media.logo,
		OnClick = OnClick,
		OnTooltipShow = OnTooltipShow,
	})

	if not launcher then
		return
	end

	-- LibDBIcon adds its own compartment entry on registration while this saved flag is set.
	self.state.showInCompartment = nil
	icon:Register(AUI.name, launcher, self.state)

	if AUI.can.compartment then
		AddonCompartmentFrame:RegisterAddon({
			text = AUI.brand,
			icon = AUI.Media.logo,
			func = OnCompartmentClick,
			funcOnEnter = OnCompartmentEnter,
			funcOnLeave = OnCompartmentLeave,
		})
	end

	self.icon = icon
end

---@return boolean hidden
function Broker:Hidden()
	return self.state.hide == true
end

---@param hidden boolean
function Broker:SetHidden(hidden)
	self.state.hide = hidden

	if not self.icon then
		return
	end

	if hidden then
		self.icon:Hide(AUI.name)
	else
		self.icon:Show(AUI.name)
	end
end
