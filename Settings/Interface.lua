local AUI = select(2, ...)

local L = AUI.L

---The Interface page, under the Quality of Life header: the Extra Action Button card and the Hide card, each holding
---only what the client has. Changes take effect at once; the extra action button's wait for combat to end.
---@class AUISettingsInterface
local SettingsInterface = {}
AUI.SettingsInterface = SettingsInterface

---@return boolean
function SettingsInterface:IsAvailable()
	local can = AUI.can

	return can.extraActionButton == true or can.helpTips == true or can.bossBanner == true or can.vaultOverlay == true
end

---@param section table
---@param id string
---@param label string
---@param description string?
---@param path string
local function Checkbox(section, id, label, description, path)
	section:Checkbox({
		id = id,
		label = label,
		description = description,
		path = path,
		default = AUI.Settings:Default(path),
	})
end

---@param page table
function SettingsInterface:DeclareExtraActionButton(page)
	local Options = AUI.InterfaceOptions
	local card = page:Section("interfaceExtraActionButton", L["Extra Action Button"], { columns = 2 })

	Checkbox(card, "clickThroughArt", L["Click-Through Art"], nil, Options.CLICK_THROUGH_PATH)
	Checkbox(card, "hideArt", L["Hide Art"], nil, Options.HIDE_ART_PATH)
end

---@param page table
function SettingsInterface:DeclareHide(page)
	local Options = AUI.InterfaceOptions
	local can = AUI.can

	if not (can.helpTips or can.bossBanner or can.vaultOverlay) then
		return
	end

	local card = page:Section("interfaceHide", HIDE)

	if can.helpTips then
		Checkbox(card, "hideHelpTips", L["Help Tips"], L["Turning it off doesn't bring them back."],
			Options.HELP_TIPS_PATH)
	end

	if can.bossBanner then
		Checkbox(card, "hideBossBanner", L["Boss Banner"], nil, Options.BOSS_BANNER_PATH)
	end

	if can.vaultOverlay then
		Checkbox(card, "hideVaultOverlay", L["Great Vault Overlay"],
			L["The cover shown when you open it away from the vault."], Options.VAULT_OVERLAY_PATH)
	end
end

---@param window table
function SettingsInterface:Declare(window)
	local page = window:Page("interface", {
		title = L["Interface"],
		under = "qualityOfLifeHeader",
		icon = AUI.Media.sidebar.interface,
		iconTint = true,
	})

	if not page then
		return
	end

	if AUI.can.extraActionButton then
		self:DeclareExtraActionButton(page)
	end

	self:DeclareHide(page)
end
