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
---@field abbreviationConfig boolean number abbreviation can take custom breakpoints
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
---@field macroNames boolean Blizzard's action button bars can be listed (`ActionButtonUtil.ActionBarButtonNames`)
---@field keyLabels boolean action buttons' key labels can be read back from their bindings (`IsBindingForGamePad`)
---@field extraActionButton boolean the extra action button's frame exists (`ExtraActionBarFrame`)
---@field helpTips boolean help tips are marked seen in a console variable's bits (`closedInfoFramesAccountWide`)
---@field lootSparkle boolean quest items can sparkle with the outline off (`outlineModeShowLootEffectWhenDisabled`)
---@field approachSparkles boolean approached objects can glint under the soft target's nameplate (Forever)
---@field bossBanner boolean the boss banner exists (`BossBanner`)
---@field vaultOverlay boolean the Great Vault covers itself away from the vault (Retail)
---@field skipCountdown boolean static pop-ups count down through `StaticPopup_OnUpdate`
---@field confirmBind boolean a bind-on-pickup loot slot can be confirmed (`ConfirmLootSlot`)
---@field tradingPost boolean the Trading Post's attack animation toggle can be followed (Retail)
---@field easyDestroy boolean the destroy pop-up that asks for the confirmation word can be found when shown
---@field clickThroughToasts boolean event toasts are shown by `EventToastManagerFrame`
---@field releaseProtection boolean the death dialog updates through `StaticPopupDialogs.DEATH.OnUpdate`
---@field screenText boolean the error frame and the zone, subzone and territory lines exist, with their font objects
---@field cursorRing boolean the cursor's place and the global cooldown's duration object can be read
---@field castSwipe boolean the player's casts and channels give duration objects
---@field castBar boolean status bars run timers from duration objects and duration text bindings write the time
---@field empoweredCasts boolean the client has empowered spells (Retail)
---@field petBattles boolean the client has pet battles
---@field castTarget boolean the client names a cast's target
---@field premadeJoined boolean a joined group's listing and its Adventure Guide instance can be read
---@field petNotices boolean the pet's stance and the character's spells can be read
---@field petHealthNotice boolean the pet's health can be drawn through a curve
---@field talentNotice boolean unspent talent points can be read
---@field durabilityNotice boolean equipped items' durability can be read
---@field lowHealthNotice boolean the player's health can be drawn through a curve
---@field trackingNotice boolean the minimap's trackings and the player's shapeshift form can be read
---@field potionNotice boolean the bags' potions, their use spells and their cooldown can be read
---@field movementAlert boolean spell cooldowns give duration objects for text bindings and curves (Retail)
---@field raidMarkers boolean a bar of secure marker buttons can follow a visibility driver and start a role check
---@field worldMarkers boolean the client has world markers (`IsRaidMarkerSystemEnabled`)
---@field secureSnippets boolean wrapped secure scripts run (Retail)
---@field merchantWindow boolean the merchant window's update functions and item helpers can be hooked and called
---@field commodities boolean stackable items sell region-wide at the auction house (Retail)
---@field merchantFilter boolean the merchant's item filter can be read and set to all items
---@field deleteCheapestItem boolean bag items' quest status and sell prices can be read, and the cursor's item deleted
---@field macros boolean account macros can be made, read and edited, and bag items' use spells and cooldowns read
---@field manaPotions boolean mana potions belong in the food and drink macros (Forever)
---@field recuperate boolean every character has Recuperate, the self-heal out of combat (Retail)
---@field bandages boolean bandages need a First Aid rank that can be read (Forever)
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
	can.abbreviationConfig = CreateAbbreviateConfig ~= nil
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
	can.macroNames = ActionButtonUtil ~= nil and ActionButtonUtil.ActionBarButtonNames ~= nil
	can.keyLabels = ActionButtonUtil ~= nil and ActionButtonUtil.ActionBarButtonNames ~= nil and GetBindingKey ~= nil
		and IsBindingForGamePad ~= nil
	can.extraActionButton = ExtraActionBarFrame ~= nil
	can.helpTips = C_CVar.SetCVarBitfield ~= nil and C_CVar.GetCVarInfo("closedInfoFramesAccountWide") ~= nil
	can.lootSparkle = C_CVar.GetCVarInfo("outlineModeShowLootEffectWhenDisabled") ~= nil
	can.approachSparkles = WOW_PROJECT_ID == WOW_PROJECT_CAMELOT and SetUnitCursorTexture ~= nil
		and UnitIsGameObject ~= nil and C_NamePlate ~= nil and C_NamePlate.GetNamePlateForUnit ~= nil
		and C_Timer.NewTicker ~= nil and C_CVar.GetCVarInfo("SoftTargetInteract") ~= nil
	can.bossBanner = BossBanner ~= nil and BossBanner.UnregisterEvent ~= nil
	can.vaultOverlay = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and C_WeeklyRewards ~= nil
	can.skipCountdown = StaticPopup_OnUpdate ~= nil and StaticPopupDialogs ~= nil
	can.confirmBind = ConfirmLootSlot ~= nil and StaticPopup_Hide ~= nil
	can.tradingPost = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and C_PerksProgram ~= nil
		and C_PerksProgram.IsAttackAnimToggleEnabled ~= nil
	can.easyDestroy = StaticPopup_FindVisible ~= nil and DELETE_ITEM_CONFIRM_STRING ~= nil and StaticPopupDialogs ~= nil
		and StaticPopupDialogs.DELETE_GOOD_ITEM ~= nil
	can.clickThroughToasts = EventToastManagerFrame ~= nil and EventToastManagerFrame.DisplayToast ~= nil
	can.releaseProtection = StaticPopupDialogs ~= nil and StaticPopupDialogs.DEATH ~= nil
		and StaticPopupDialogs.DEATH.OnUpdate ~= nil and StaticPopup_FindVisible ~= nil and StaticPopup_Show ~= nil
	can.screenText = UIErrorsFrame ~= nil and ErrorFont ~= nil and ZoneTextString ~= nil and ZoneTextFont ~= nil
		and SubZoneTextString ~= nil and SubZoneTextFont ~= nil and PVPInfoTextString ~= nil
		and PVPArenaTextString ~= nil and PVPInfoTextFont ~= nil
	can.cursorRing = GetCursorPosition ~= nil and C_Spell ~= nil and C_Spell.GetSpellCooldownDuration ~= nil
	can.castSwipe = UnitCastingDuration ~= nil and UnitChannelDuration ~= nil
	can.castBar = UnitCastingInfo ~= nil and UnitChannelInfo ~= nil and can.castSwipe and C_DurationUtil ~= nil
		and C_DurationUtil.CreateDurationTextBinding ~= nil and C_StringUtil ~= nil
		and C_StringUtil.CreateNumericRuleFormatter ~= nil and Enum.StatusBarTimerDirection ~= nil
		and Enum.StatusBarInterpolation ~= nil and Enum.DurationTextBindingProperty ~= nil
	can.empoweredCasts = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
	can.petBattles = C_PetBattles ~= nil and C_PetBattles.IsInBattle ~= nil
	can.castTarget = UnitShouldDisplaySpellTargetName ~= nil and UnitSpellTargetName ~= nil
		and UnitSpellTargetClass ~= nil and GetClassColor ~= nil
	can.premadeJoined = C_LFGList ~= nil and C_LFGList.GetSearchResultInfo ~= nil
		and C_LFGList.GetActivityInfoTable ~= nil and C_EncounterJournal ~= nil
		and C_EncounterJournal.GetInstanceForGameMap ~= nil and canaccesstable ~= nil
	can.petNotices = GetPetActionInfo ~= nil and C_SpellBook ~= nil and C_SpellBook.IsSpellKnown ~= nil
	can.petHealthNotice = UnitHealthPercent ~= nil and C_CurveUtil ~= nil and C_CurveUtil.CreateCurve ~= nil
		and Enum.LuaCurveType ~= nil
	can.talentNotice = C_ClassTalents ~= nil and C_ClassTalents.HasUnspentTalentPoints ~= nil
	can.durabilityNotice = GetInventoryItemDurability ~= nil
	can.lowHealthNotice = can.petHealthNotice
	can.trackingNotice = C_Minimap ~= nil and C_Minimap.GetNumTrackingTypes ~= nil and C_Minimap.GetTrackingInfo ~= nil
		and GetShapeshiftFormID ~= nil
	can.potionNotice = C_Container ~= nil and C_Container.GetItemCooldown ~= nil
		and C_Container.GetContainerItemID ~= nil and C_Item ~= nil and C_Item.GetItemSpell ~= nil
		and C_Item.GetItemInfoInstant ~= nil and Enum.ItemConsumableSubclass ~= nil
	can.movementAlert = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and can.specializations and can.petHealthNotice
		and C_Spell ~= nil and C_Spell.GetSpellCooldown ~= nil and C_Spell.GetSpellCharges ~= nil
		and C_Spell.GetSpellCooldownDuration ~= nil and C_Spell.GetSpellChargeDuration ~= nil
		and C_Spell.GetOverrideSpell ~= nil and C_Spell.GetSpellName ~= nil and C_SpellBook ~= nil
		and C_SpellBook.IsSpellKnown ~= nil
		and C_DurationUtil ~= nil and C_DurationUtil.CreateDurationTextBinding ~= nil and C_StringUtil ~= nil
		and C_StringUtil.CreateNumericRuleFormatter ~= nil and Enum.DurationTextBindingProperty ~= nil
	can.raidMarkers = RegisterStateDriver ~= nil and UnregisterStateDriver ~= nil and InitiateRolePoll ~= nil
		and IsEveryoneAssistant ~= nil and C_AddOns ~= nil and C_AddOns.IsAddOnLoaded ~= nil
	can.worldMarkers = IsRaidMarkerSystemEnabled ~= nil and IsRaidMarkerSystemEnabled() == true
		and IsRaidMarkerActive ~= nil
	-- Forever lacks the restricted environment's compiler, so wrapped scripts never run there.
	can.secureSnippets = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and SecureHandlerWrapScript ~= nil
		and SecureHandlerSetFrameRef ~= nil
	can.deleteCheapestItem = C_Container ~= nil and C_Container.GetContainerItemQuestInfo ~= nil
		and C_Container.PickupContainerItem ~= nil and C_Item ~= nil and C_Item.GetItemInfo ~= nil
		and DeleteCursorItem ~= nil and Enum.ItemClass ~= nil and Enum.ItemClass.Questitem ~= nil
	can.merchantWindow = MerchantFrame ~= nil and MerchantFrame_UpdateMerchantInfo ~= nil
		and MerchantFrame_UpdateBuybackInfo ~= nil and MerchantFrame_UpdateItemQualityBorders ~= nil
		and MerchantFrameItem_UpdateQuality ~= nil and C_MerchantFrame ~= nil and C_MerchantFrame.GetItemInfo ~= nil
		and C_MerchantFrame.IsMerchantItemRefundable ~= nil and AltCurrencyFrame_Update ~= nil
		and CurrencyContainerUtil ~= nil and StackSplitCancelButton_OnClick ~= nil
		and MerchantFrame_UpdateRepairButtons ~= nil and CanMerchantRepair ~= nil and MerchantMoneyInset ~= nil
		and MerchantMoneyBg ~= nil and MerchantMoneyFrame ~= nil and MerchantBuyBackItem ~= nil
		and C_MerchantFrame.GetMerchantCurrencies ~= nil
	can.commodities = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and C_AuctionHouse ~= nil
	can.merchantFilter = can.merchantWindow and SetMerchantFilter ~= nil and GetMerchantFilter ~= nil
		and LE_LOOT_FILTER_ALL ~= nil
	can.macros = CreateMacro ~= nil and EditMacro ~= nil and DeleteMacro ~= nil and GetMacroInfo ~= nil
		and GetMacroIndexByName ~= nil and GetNumMacros ~= nil and PickupMacro ~= nil and Constants.MacroConsts ~= nil
		and C_Item ~= nil and C_Item.GetItemSpell ~= nil and C_Item.GetItemCooldown ~= nil and C_Spell ~= nil
		and C_Spell.GetSpellName ~= nil and C_Container ~= nil and C_Container.GetContainerItemID ~= nil
	can.manaPotions = WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
	can.recuperate = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
	can.bandages = WOW_PROJECT_ID == WOW_PROJECT_CAMELOT and C_SkillInfo ~= nil
		and C_SkillInfo.GetSkillLineInfoByID ~= nil

	self.resolved = true

	return can
end
