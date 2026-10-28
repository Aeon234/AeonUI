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
---@field playerMenus boolean right-click menus can be added to (`Menu.ModifyMenu`)
---@field guildInvite boolean a player can be invited to your guild by name
---@field battleNetFriends boolean a Battle.net friend's game account can be read
---@field groupFinderMenus boolean the premade group finder can name an applicant and a listing's leader
---@field raiderIOLinks boolean Raider.IO lists this client's characters (Retail)
---@field warcraftLogsLinks boolean Warcraft Logs lists this client's characters (Retail)
---@field clickDown boolean action buttons can act on key down (`ActionButtonUseKeyDown`)
---@field focusShortcut boolean a mouse button can be bound to a secure button (`SetOverrideBindingClick`)
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
	can.playerMenus = Menu ~= nil and Menu.ModifyMenu ~= nil
	can.guildInvite = C_GuildInfo ~= nil and C_GuildInfo.Invite ~= nil and CanGuildInvite ~= nil
	can.battleNetFriends = C_BattleNet ~= nil and C_BattleNet.GetAccountInfoByID ~= nil and BNET_CLIENT_WOW ~= nil
	can.groupFinderMenus = C_LFGList ~= nil and C_LFGList.GetApplicantMemberInfo ~= nil
		and C_LFGList.GetSearchResultInfo ~= nil
	-- The sites list Retail characters by realm; Forever has no realms. Its support turns on here when a site adds it.
	can.raiderIOLinks = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
	can.warcraftLogsLinks = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
	can.clickDown = C_CVar.GetCVarInfo("ActionButtonUseKeyDown") ~= nil
	can.focusShortcut = SetOverrideBindingClick ~= nil and ClearOverrideBindings ~= nil and C_AddOns ~= nil
		and C_AddOns.IsAddOnLoaded ~= nil

	self.resolved = true

	return can
end
