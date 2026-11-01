local AUI = select(2, ...)

local L = AUI.L

local Options = AUI.MenuOptions

-- The right-click menus of a player: unit frames, party and raid members, and names in chat.
local MENUS = { "MENU_UNIT_PLAYER", "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_FRIEND" }

---Guild Invite in a player's right-click menu, where `AUI.can.guildInvite` holds, while you may invite and they are not
---in your guild. A unit's guild is read from the unit; a name from chat is checked against your guild's roster, kept
---by full name while the setting is on.
---@class AUIGuildInvite
---@field members table<string, true> your guild's members by name and realm
---@field listening boolean following the guild roster
local GuildInvite = {
	members = {},
	listening = false,
}
AUI.GuildInvite = GuildInvite

---@return boolean
function GuildInvite:IsOn()
	return AUI.can.guildInvite == true and Options:Get(Options.GUILD_INVITE_PATH) == true
end

---Follows the guild roster while the setting is on.
function GuildInvite:Apply()
	local on = self:IsOn()

	if on == self.listening then
		return
	end

	self.listening = on

	if on then
		AUI.Events:Register("GUILD_ROSTER_UPDATE", self, self.UpdateRoster)
		self:UpdateRoster()
	else
		AUI.Events:Unregister("GUILD_ROSTER_UPDATE", self)
		self.members = {}
	end
end

function GuildInvite:UpdateRoster()
	self.members = {}

	for index = 1, GetNumGuildMembers() do
		local name = GetGuildRosterInfo(index)

		if name then
			self.members[name] = true
		end
	end
end

---@param name string a player's name, with or without a realm
---@param realm string? their realm, when the name has none
---@return string fullName the name with a realm, as the guild roster writes it
local function FullName(name, realm)
	if name:find("-", 1, true) then
		return name
	end

	return name .. "-" .. ((realm and realm ~= "") and realm or GetNormalizedRealmName())
end

---@param contextData table the menu's context: `unit`, or `name` and `server`
---@return string? fullName the player to invite, or nil when the menu is not for another player you may invite
function GuildInvite:Target(contextData)
	local unit, name, realm = contextData.unit, contextData.name, contextData.server

	if unit then
		-- A secret answer counts against the invite.
		if AUI:Readable(UnitIsPlayer(unit), false) ~= true or AUI:Readable(UnitIsUnit(unit, "player"), true) ~= false
			or AUI:Readable(UnitIsFriend("player", unit), false) ~= true then
			return nil
		end

		local guild = GetGuildInfo(unit)

		if issecretvalue(guild) or guild ~= nil then
			return nil
		end

		name, realm = AUI:Readable(GetUnitName(unit, true)), nil
	else
		name, realm = AUI:Readable(name), AUI:Readable(realm)
	end

	if type(name) ~= "string" or name == "" then
		return nil
	end

	local fullName = FullName(name, realm)

	return not self.members[fullName] and fullName or nil
end

---@param rootDescription table
---@param contextData table?
function GuildInvite:AddButton(rootDescription, contextData)
	if not self:IsOn() or not contextData or not CanGuildInvite() then
		return
	end

	local fullName = self:Target(contextData)

	if fullName then
		rootDescription:CreateButton(L["Guild Invite"], function()
			C_GuildInfo.Invite(fullName)
		end)
	end
end

---Adds the button to the player menus, once. The callbacks do nothing while the setting is off.
function GuildInvite:Hook()
	for _, tag in ipairs(MENUS) do
		Menu.ModifyMenu(tag, function(_, rootDescription, contextData)
			self:AddButton(rootDescription, contextData)
		end)
	end
end
