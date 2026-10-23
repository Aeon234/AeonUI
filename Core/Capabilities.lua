local AUI = select(2, ...)

---@class AUICapabilities
---@field resolved boolean
local Capabilities = {
	resolved = false,
}
AUI.Capabilities = Capabilities

---@class AUICapabilityFlags
---@field compartment boolean the addon compartment entry point
---@field minimapConfig boolean the minimap cluster re-applies its own mask when rotation changes (Forever)
---@field foreverArt boolean the client draws Forever's art for shared atlases, which places some differently
---@field dielCycle boolean the client reports day and night itself (`C_DateAndTime.IsDayTime`, Forever)
---@field craftingOrders boolean the minimap shows personal crafting orders (Retail)
AUI.can = {}

---The only place a client difference is detected. Runs once at login.
---@return AUICapabilityFlags
function Capabilities:Resolve()
	local can = AUI.can

	can.compartment = AddonCompartmentFrame ~= nil
	can.minimapConfig = MinimapCluster ~= nil and MinimapCluster.UpdateMinimapConfig ~= nil
	can.foreverArt = WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
	can.dielCycle = C_DateAndTime ~= nil and C_DateAndTime.IsDayTime ~= nil
	can.craftingOrders = MinimapCluster ~= nil and MinimapCluster.IndicatorFrame ~= nil
		and MinimapCluster.IndicatorFrame.CraftingOrderFrame ~= nil and C_CraftingOrders ~= nil

	self.resolved = true

	return can
end
