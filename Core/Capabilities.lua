local AUI = select(2, ...)

---@class AUICapabilities
---@field resolved boolean
local Capabilities = {
	resolved = false,
}
AUI.Capabilities = Capabilities

---@class AUICapabilityFlags
---@field compartment boolean the addon compartment entry point
---@field gameMenu boolean the game menu lays out pooled buttons from a template it names (`GameMenuFrame.buttonPool`)
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
---@field upgrades boolean items have upgrade tracks, shown on an "Upgrade Level" tooltip line (Retail)
---@field specializations boolean players have named specializations (Retail; Forever has one per class)
---@field rangedSlot boolean characters have a ranged slot (Forever)
---@field expansionFilter boolean the Auction House offers Current Expansion Only (Retail)
---@field mail boolean the send-mail form's fields and functions the Mail helpers hook
---@field autoDeclineGuildInvites boolean guild invites can be declined automatically
AUI.can = {}

---The only place a client difference is detected. Runs once at login.
---@return AUICapabilityFlags
function Capabilities:Resolve()
	local can = AUI.can

	can.compartment = AddonCompartmentFrame ~= nil
	can.gameMenu = GameMenuFrame ~= nil and GameMenuFrame.buttonPool ~= nil and GameMenuFrame.buttonTemplate ~= nil
		and GameMenuFrame.Layout ~= nil
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
	can.upgrades = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and C_ItemUpgrade ~= nil
		and C_ItemUpgrade.GetHighWatermarkForItem ~= nil and Enum.TooltipDataLineType.ItemUpgradeLevel ~= nil
		and ITEM_UPGRADE_TOOLTIP_FORMAT_STRING ~= nil
	can.specializations = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and C_SpecializationInfo ~= nil
		and GetSpecializationInfoByID ~= nil
	can.rangedSlot = CharacterRangedSlot ~= nil
	can.expansionFilter = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and Enum.AuctionHouseFilter ~= nil
		and Enum.AuctionHouseFilter.CurrentExpansionOnly ~= nil and C_AuctionHouse ~= nil
		and C_AuctionHouse.GetFilterGroups ~= nil
	can.mail = SendMailNameEditBox ~= nil and SendMailSubjectEditBox ~= nil and SendMailMoney ~= nil
		and SendMailFrame_SendMail ~= nil and SendMailFrame_Reset ~= nil and MoneyInputFrame_GetCopper ~= nil
	can.autoDeclineGuildInvites = GetAutoDeclineGuildInvites ~= nil and SetAutoDeclineGuildInvites ~= nil

	self.resolved = true

	return can
end
