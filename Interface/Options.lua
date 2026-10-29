local AUI = select(2, ...)

local Schema = AUI.Schema

---The Interface page's profile settings: the extra action button's art, the Blizzard frames AeonUI hides, and how
---Blizzard's pop-ups and toasts behave.
---@class AUIInterfaceOptions
---@field CLICK_THROUGH_PATH string the art around the extra action, zone ability and alternate power bar lets clicks pass
---@field HIDE_ART_PATH string the art around the extra action and zone ability buttons is hidden
---@field HELP_TIPS_PATH string Blizzard's help tips are closed at every login
---@field BOSS_BANNER_PATH string the boss banner is not shown
---@field VAULT_OVERLAY_PATH string the Great Vault's cover is not shown away from the vault (Retail)
---@field SKIP_COUNTDOWN_PATH string the Great Vault and item upgrade pop-ups can be accepted during their countdown
---@field SKIP_KEY_PATH string a `skipKey` choice: the key held to skip, or none
---@field CONFIRM_BIND_PATH string items that bind on pickup are looted without asking
---@field TOAST_CLICK_THROUGH_PATH string event toasts let clicks through to the world
---@field RELEASE_PROTECTION_PATH string Release Spirit waits for a confirmation on death
---@field SKIP_KEYS string[] the Hold to Skip choices, in the order the page lists them
local Options = {
	CLICK_THROUGH_PATH = "interface.extraActionButton.clickThrough",
	HIDE_ART_PATH = "interface.extraActionButton.hideArt",
	HELP_TIPS_PATH = "interface.hide.helpTips",
	BOSS_BANNER_PATH = "interface.hide.bossBanner",
	VAULT_OVERLAY_PATH = "interface.hide.vaultOverlay",
	SKIP_COUNTDOWN_PATH = "interface.popups.skipCountdown",
	SKIP_KEY_PATH = "interface.popups.skipKey",
	CONFIRM_BIND_PATH = "interface.popups.confirmBind",
	TOAST_CLICK_THROUGH_PATH = "interface.popups.toastClickThrough",
	RELEASE_PROTECTION_PATH = "interface.popups.releaseProtection",
	SKIP_KEYS = { "NONE", "SHIFT", "CTRL", "ALT" },
}
AUI.InterfaceOptions = Options

Schema:Choices("skipKey", Options.SKIP_KEYS)

Schema:Boolean(Options.CLICK_THROUGH_PATH, false)
Schema:Boolean(Options.HIDE_ART_PATH, false)
Schema:Boolean(Options.HELP_TIPS_PATH, false)
Schema:Boolean(Options.BOSS_BANNER_PATH, false)
Schema:Boolean(Options.VAULT_OVERLAY_PATH, false)
Schema:Boolean(Options.SKIP_COUNTDOWN_PATH, false)
Schema:Choice(Options.SKIP_KEY_PATH, "skipKey", "NONE")
Schema:Boolean(Options.CONFIRM_BIND_PATH, false)
Schema:Boolean(Options.TOAST_CLICK_THROUGH_PATH, false)
Schema:Boolean(Options.RELEASE_PROTECTION_PATH, false)

---@param path string one of the paths above
---@return any value
function Options:Get(path)
	return AUI.Profile:Get(path)
end

---@param path string one of the paths above
---@return boolean on
function Options:On(path)
	return AUI.Profile:Get(path) == true
end
