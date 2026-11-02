local AUI = select(2, ...)

local L = AUI.L

local SKIP_KEY_LABELS = {
	NONE = L["No Key"],
	SHIFT = L["Shift"],
	CTRL = L["Ctrl"],
	ALT = L["Alt"],
}

---The Interface page, under the Quality of Life header: the Extra Action Button, Hide and Pop-ups cards, each holding
---only what the client has. Changes take effect at once; the extra action button's wait for combat to end.
---@class AUISettingsInterface
local SettingsInterface = {}
AUI.SettingsInterface = SettingsInterface

---@return boolean
function SettingsInterface:IsAvailable()
	local can = AUI.can

	return can.extraActionButton == true or can.helpTips == true or can.bossBanner == true or can.vaultOverlay == true
		or can.skipCountdown == true or can.confirmBind == true or can.easyDestroy == true
		or can.clickThroughToasts == true or can.releaseProtection == true or can.tradingPost == true
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

---@param page table
function SettingsInterface:DeclarePopups(page)
	local Options = AUI.InterfaceOptions
	local can = AUI.can

	if not (can.skipCountdown or can.confirmBind or can.easyDestroy or can.clickThroughToasts
		or can.releaseProtection) then
		return
	end

	local card = page:Section("interfacePopups", L["Pop-ups"])

	if can.skipCountdown then
		local keys = {}

		for index, key in ipairs(Options.SKIP_KEYS) do
			keys[index] = { value = key, text = SKIP_KEY_LABELS[key] }
		end

		Checkbox(card, "skipCountdown", L["Skip Accept Countdowns"], L["Great Vault and item upgrade pop-ups."],
			Options.SKIP_COUNTDOWN_PATH)
		card:Dropdown({
			id = "skipKey",
			label = L["Hold to Skip"],
			path = Options.SKIP_KEY_PATH,
			default = AUI.Settings:Default(Options.SKIP_KEY_PATH),
			depends = "skipCountdown",
			options = keys,
		})
	end

	if can.confirmBind then
		Checkbox(card, "confirmBind", L["Auto Confirm Bind on Pickup"], nil, Options.CONFIRM_BIND_PATH)
	end

	if can.easyDestroy then
		Checkbox(card, "easyDestroy", L["Easy Item Destroy"],
			L["No need to type \"%s\" to destroy an item."]:format(DELETE_ITEM_CONFIRM_STRING), Options.EASY_DESTROY_PATH)
	end

	if can.clickThroughToasts then
		Checkbox(card, "toastClickThrough", L["Click-Through Toasts"],
			L["Level-up and new-zone banners; clicking no longer opens their details."],
			Options.TOAST_CLICK_THROUGH_PATH)
	end

	if can.releaseProtection then
		Checkbox(card, "releaseProtection", L["Confirm Release Spirit"],
			L["Release Spirit stays disabled until you answer Yes."], Options.RELEASE_PROTECTION_PATH)
	end
end

---@param page table
function SettingsInterface:DeclareTradingPost(page)
	local card = page:Section("interfaceTradingPost", L["Trading Post"])

	Checkbox(card, "tradingPostCombat", L["Disable Combat Previews"],
		L["Each item's preview starts without its combat animation."], AUI.InterfaceOptions.TRADING_POST_COMBAT_PATH)
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
	self:DeclarePopups(page)

	if AUI.can.tradingPost then
		self:DeclareTradingPost(page)
	end
end

AUI.Modules:Register({
	group = "qualityOfLife",
	page = SettingsInterface,
	start = function()
		AUI.Interface:Start()
	end,
})
