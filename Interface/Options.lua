local AUI = select(2, ...)

local Schema = AUI.Schema

---The Interface page's profile settings: the extra action button's art and the Blizzard frames AeonUI hides.
---@class AUIInterfaceOptions
---@field CLICK_THROUGH_PATH string the art around the extra action, zone ability and alternate power bar lets clicks pass
---@field HIDE_ART_PATH string the art around the extra action and zone ability buttons is hidden
---@field HELP_TIPS_PATH string Blizzard's help tips are closed at every login
---@field BOSS_BANNER_PATH string the boss banner is not shown
---@field VAULT_OVERLAY_PATH string the Great Vault's cover is not shown away from the vault (Retail)
local Options = {
	CLICK_THROUGH_PATH = "interface.extraActionButton.clickThrough",
	HIDE_ART_PATH = "interface.extraActionButton.hideArt",
	HELP_TIPS_PATH = "interface.hide.helpTips",
	BOSS_BANNER_PATH = "interface.hide.bossBanner",
	VAULT_OVERLAY_PATH = "interface.hide.vaultOverlay",
}
AUI.InterfaceOptions = Options

Schema:Boolean(Options.CLICK_THROUGH_PATH, false)
Schema:Boolean(Options.HIDE_ART_PATH, false)
Schema:Boolean(Options.HELP_TIPS_PATH, false)
Schema:Boolean(Options.BOSS_BANNER_PATH, false)
Schema:Boolean(Options.VAULT_OVERLAY_PATH, false)

---@param path string one of the paths above
---@return boolean on
function Options:On(path)
	return AUI.Profile:Get(path) == true
end
