local AUI = select(2, ...)

local L = AUI.L

local Options = AUI.MenuOptions

local COPY_POPUP = "AEONUI_COPY_LINK"

-- Menus whose context names a player: by unit, or by name and realm.
local PLAYER_MENUS = {
	"MENU_UNIT_SELF", "MENU_UNIT_PLAYER", "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_ENEMY_PLAYER",
	"MENU_UNIT_FRIEND", "MENU_UNIT_FRIEND_OFFLINE", "MENU_UNIT_GUILD", "MENU_UNIT_GUILD_OFFLINE",
	"MENU_UNIT_COMMUNITIES_GUILD_MEMBER", "MENU_UNIT_COMMUNITIES_WOW_MEMBER", "MENU_UNIT_CHAT_ROSTER",
}
-- Battle.net friends' menus, whose context names the friend's account.
local BATTLE_NET_MENUS = { "MENU_UNIT_BN_FRIEND", "MENU_UNIT_BN_FRIEND_OFFLINE" }
-- The premade group finder's menus, which carry no context: the owner frame names the applicant or the listing.
local APPLICANT_MENU = "MENU_LFG_FRAME_MEMBER_APPLY"
local LISTING_MENU = "MENU_LFG_FRAME_SEARCH_ENTRY"

StaticPopupDialogs[COPY_POPUP] = {
	text = "%s",
	button1 = CLOSE,
	hasEditBox = true,
	editBoxWidth = 350,
	maxLetters = 0,
	OnShow = function(dialog, data)
		local editBox = dialog:GetEditBox()

		editBox:SetText(data.url)
		editBox:HighlightText()
		editBox:SetFocus()
	end,
	EditBoxOnTextChanged = function(editBox, data)
		if editBox:GetText() ~= data.url then
			editBox:SetText(data.url)
			editBox:HighlightText()
		end
	end,
	EditBoxOnEnterPressed = function(editBox)
		editBox:GetParent():Hide()
	end,
	EditBoxOnEscapePressed = StaticPopup_StandardEditBoxOnEscapePressed,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

---External Links in a player's right-click menu: a divider, the title and a button per site the client and the
---profile allow, each showing the character's page in a box to copy, since an addon cannot open a browser or write
---the clipboard.
---@class AUIPlayerLinks
local PlayerLinks = {}
AUI.PlayerLinks = PlayerLinks

---@return AUIMenuSite[] sites the sites to offer now
function PlayerLinks:Sites()
	local sites = {}

	for _, site in ipairs(Options.SITES) do
		if AUI.can[site.can] and Options:Get(site.path) == true then
			sites[#sites + 1] = site
		end
	end

	return sites
end

---@param site AUIMenuSite
---@param url string
function PlayerLinks:ShowCopy(site, url)
	StaticPopup_Show(COPY_POPUP, ("%s\n%s"):format(site.label, L["Press Ctrl+C to copy."]), nil, { url = url })
end

---Adds the External Links to a menu for one character.
---@param rootDescription table
---@param name string
---@param realm string
---@param region string
function PlayerLinks:Add(rootDescription, name, realm, region)
	local buttons = {}

	for _, site in ipairs(self:Sites()) do
		local url = site.Url(region, realm, name)

		if url then
			buttons[#buttons + 1] = { site = site, url = url }
		end
	end

	if #buttons == 0 then
		return
	end

	rootDescription:CreateDivider()
	rootDescription:CreateTitle(L["External Links"])

	for _, button in ipairs(buttons) do
		rootDescription:CreateButton(button.site.label, function()
			self:ShowCopy(button.site, button.url)
		end)
	end
end

---@param contextData table? a unit menu's context: `unit`, or `name` and `server`
---@return string? name
---@return string? realm
function PlayerLinks.FromContext(contextData)
	if not contextData then
		return nil
	end

	local ownRealm = AUI:Readable(GetNormalizedRealmName())
	local unit = contextData.unit

	if unit then
		local name, realm = UnitName(unit)

		name, realm = AUI:Readable(name), AUI:Readable(realm)

		if type(name) == "string" and name ~= "" and AUI:Readable(UnitIsPlayer(unit), false) == true then
			return name, (type(realm) == "string" and realm ~= "") and realm or ownRealm
		end
	end

	local name = AUI:Readable(contextData.name)

	if type(name) ~= "string" or name == "" or type(ownRealm) ~= "string" then
		return nil
	end

	return Options.SplitName(name, AUI:Readable(contextData.server), ownRealm)
end

---@param _ table owner
---@param rootDescription table
---@param contextData table?
function PlayerLinks:OnPlayerMenu(_, rootDescription, contextData)
	local name, realm = self.FromContext(contextData)

	if name and realm then
		self:Add(rootDescription, name, realm, Options.Region(GetCurrentRegion()))
	end
end

---A Battle.net friend playing a character on this client.
---@param _ table owner
---@param rootDescription table
---@param contextData table?
function PlayerLinks:OnBattleNetMenu(_, rootDescription, contextData)
	local account = contextData and contextData.bnetIDAccount
	local info = account and C_BattleNet.GetAccountInfoByID(account)
	local game = info and info.gameAccountInfo

	if not game or game.clientProgram ~= BNET_CLIENT_WOW or game.wowProjectID ~= WOW_PROJECT_ID then
		return
	end

	local name, realm = game.characterName, game.realmName

	if type(name) == "string" and name ~= "" and type(realm) == "string" and realm ~= "" then
		self:Add(rootDescription, name, realm, Options.Region(game.regionID))
	end
end

---@param fullName any a name from the group finder, with "-Realm" when it is another realm's
---@param rootDescription table
function PlayerLinks:AddFullName(fullName, rootDescription)
	local ownRealm = AUI:Readable(GetNormalizedRealmName())

	fullName = AUI:Readable(fullName)

	if type(fullName) ~= "string" or fullName == "" or type(ownRealm) ~= "string" then
		return
	end

	local name, realm = Options.SplitName(fullName, nil, ownRealm)

	if name and realm then
		self:Add(rootDescription, name, realm, Options.Region(GetCurrentRegion()))
	end
end

---An applicant to your group: the owner is the member's row, its parent the application.
---@param owner table
---@param rootDescription table
function PlayerLinks:OnApplicantMenu(owner, rootDescription)
	local parent = owner and owner.GetParent and owner:GetParent()
	local applicantID, memberIndex = parent and parent.applicantID, owner and owner.memberIdx

	if applicantID and memberIndex then
		self:AddFullName(C_LFGList.GetApplicantMemberInfo(applicantID, memberIndex), rootDescription)
	end
end

---A group's listing: the owner is the listing's row; its leader is the character linked.
---@param owner table
---@param rootDescription table
function PlayerLinks:OnListingMenu(owner, rootDescription)
	local resultID = owner and owner.resultID
	local info = resultID and C_LFGList.GetSearchResultInfo(resultID)

	if info then
		self:AddFullName(info.leaderName, rootDescription)
	end
end

---Adds the links to every player menu, once. The callbacks do nothing while no site is offered.
function PlayerLinks:Hook()
	local function Each(tags, method)
		for _, tag in ipairs(tags) do
			Menu.ModifyMenu(tag, function(owner, rootDescription, contextData)
				method(self, owner, rootDescription, contextData)
			end)
		end
	end

	Each(PLAYER_MENUS, self.OnPlayerMenu)

	if AUI.can.battleNetFriends then
		Each(BATTLE_NET_MENUS, self.OnBattleNetMenu)
	end

	if AUI.can.groupFinderMenus then
		Each({ APPLICANT_MENU }, self.OnApplicantMenu)
		Each({ LISTING_MENU }, self.OnListingMenu)
	end
end
