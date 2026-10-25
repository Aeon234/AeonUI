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
---@field worldMapMarkers boolean the world map takes data providers and AeonUI has marker data for this world (Forever)
---@field mythicPlus boolean players have a Mythic+ rating (Retail)
---@field auraCasterNames boolean the client can name an aura's caster in its tooltip (`tooltipShowAuraCasterNames`)
---@field surnames boolean player names carry a surname instead of a realm (Forever)
---@field expansions boolean items name the expansion they come from (Retail)
---@field auraSpellIDs boolean the client can draw aura spell IDs in their tooltips (`tooltipShowAuraSpellIDs`)
---@field macroItems boolean a macro's item can be read from its name (`GetMacroItem`)
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
	can.worldMapMarkers = WorldMapFrame ~= nil and WorldMapFrame.AddDataProvider ~= nil
		and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
	can.mythicPlus = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and C_PlayerInfo ~= nil
		and C_PlayerInfo.GetPlayerMythicPlusRatingSummary ~= nil and C_ChallengeMode ~= nil
	can.auraCasterNames = C_CVar.GetCVar("tooltipShowAuraCasterNames") ~= nil
	can.surnames = WOW_PROJECT_ID == WOW_PROJECT_CAMELOT and Constants.CharacterNameSeparatorConsts ~= nil
	can.expansions = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
	can.auraSpellIDs = C_CVar.GetCVar("tooltipShowAuraSpellIDs") ~= nil
	can.macroItems = GetMacroItem ~= nil and C_ActionBar ~= nil and C_ActionBar.GetActionText ~= nil

	self.resolved = true

	return can
end
