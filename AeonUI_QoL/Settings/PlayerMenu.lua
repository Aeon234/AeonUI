local AUI = select(2, ...)

local L = AUI.L

---The Player Menu page, under the Quality of Life header: what AeonUI adds to a player's right-click menu, in cards
---named as the menu shows them. Changes take effect the next time a menu opens.
---@class AUISettingsPlayerMenu
local SettingsPlayerMenu = {}
AUI.SettingsPlayerMenu = SettingsPlayerMenu

---@return boolean
function SettingsPlayerMenu:IsAvailable()
	return AUI.can.playerMenus == true
end

---@param section table
---@param id string
---@param label string
---@param path string
local function Checkbox(section, id, label, path)
	section:Checkbox({
		id = id,
		label = label,
		path = path,
		default = AUI.Settings:Default(path),
	})
end

---@param page table
function SettingsPlayerMenu:DeclareGuild(page)
	local Options = AUI.MenuOptions
	local guild = page:Section("playerMenuGuild", GUILD)

	Checkbox(guild, "guildInvite", L["Guild Invite"], Options.GUILD_INVITE_PATH)
end

---@param page table
function SettingsPlayerMenu:DeclareLinks(page)
	local sites = {}

	for _, site in ipairs(AUI.MenuOptions.SITES) do
		if AUI.can[site.can] then
			sites[#sites + 1] = site
		end
	end

	if #sites == 0 then
		return
	end

	local links = page:Section("playerMenuLinks", L["External Links"], #sites > 1 and { columns = 2 } or nil)

	for _, site in ipairs(sites) do
		Checkbox(links, site.key .. "Link", site.label, site.path)
	end
end

---@param window table
function SettingsPlayerMenu:Declare(window)
	local page = window:Page("playerMenu", {
		title = L["Player Menu"],
		under = "qualityOfLifeHeader",
		icon = AUI.Media.sidebar.playerMenu,
		iconTint = true,
	})

	if not page then
		return
	end

	if AUI.can.guildInvite then
		self:DeclareGuild(page)
	end

	self:DeclareLinks(page)
end

AUI.Modules:Register({
	group = "qualityOfLife",
	page = SettingsPlayerMenu,
	start = function()
		AUI.Menus:Start()
	end,
})
