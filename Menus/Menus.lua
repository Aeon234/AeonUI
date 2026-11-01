local AUI = select(2, ...)

---The player menus module: Guild Invite and the External Links in a player's right-click menu, where the client builds
---its menus with `Menu.ModifyMenu` (`AUI.can.playerMenus`). The menus are hooked once at login; each entry follows its
---setting each time a menu opens.
---@class AUIMenus
---@field active boolean started this session
local Menus = {
	active = false,
}
AUI.Menus = Menus

---@param path string? the changed setting; nil when the whole profile changed
function Menus:OnProfileChanged(path)
	if path == nil or path:sub(1, 6) == "menus." then
		AUI.GuildInvite:Apply()
	end
end

function Menus:Start()
	if self.active or not AUI.can.playerMenus then
		return
	end

	self.active = true
	AUI.Callbacks:Register("Profile", self, self.OnProfileChanged)

	if AUI.can.guildInvite then
		AUI.GuildInvite:Hook()
		AUI.GuildInvite:Apply()
	end

	AUI.PlayerLinks:Hook()
end
