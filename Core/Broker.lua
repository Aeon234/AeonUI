local AUI = select(2, ...)

local L = AUI.L

local ICON = "Interface\\Icons\\INV_Misc_Gear_01"

---The minimap button and the addon compartment entry, both from one LibDataBroker launcher. LibDBIcon keeps the
---button's state (hidden, position) in `global.minimapButton` and writes it in place.
---@class AUIBroker
---@field icon table? LibDBIcon, once the button is registered
---@field state table the table LibDBIcon reads and writes
local Broker = {
	state = { hide = false },
}
AUI.Broker = Broker

local function OnClick()
	AUI:OpenSettings()
end

---@param tooltip GameTooltip
local function OnTooltipShow(tooltip)
	tooltip:AddLine(AUI.brand)
	tooltip:AddLine(L["Click: open settings"], 1, 1, 1)
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
		icon = ICON,
		OnClick = OnClick,
		OnTooltipShow = OnTooltipShow,
	})

	if not launcher then
		return
	end

	icon:Register(AUI.name, launcher, self.state)

	if AUI.can.compartment then
		icon:AddButtonToCompartment(AUI.name)
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
