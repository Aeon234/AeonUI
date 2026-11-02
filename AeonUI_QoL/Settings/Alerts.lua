local AUI = select(2, ...)

local L = AUI.L

-- Each Sound Alerts group's label.
local SOUND_LABELS = {
	queuePops = L["Queue Pops"],
	readyChecks = L["Ready and Role Checks"],
	whispers = L["Whispers"],
	partyInvites = L["Party Invites"],
	bossEmotes = L["Boss Emotes"],
}

---The Alerts page, under the Quality of Life header: the Sound Alerts card, one checkbox per group, and the Group
---Finder card. Changes take effect at once.
---@class AUISettingsAlerts
local SettingsAlerts = {}
AUI.SettingsAlerts = SettingsAlerts

---@param page table
function SettingsAlerts:DeclareSound(page)
	local Options = AUI.AlertOptions
	local card = page:Section("alertsSound", L["Sound Alerts"], { columns = 2 })

	for _, group in ipairs(Options.SOUND_GROUPS) do
		local path = Options.SoundPath(group)

		card:Checkbox({
			id = group,
			label = SOUND_LABELS[group],
			path = path,
			default = AUI.Settings:Default(path),
		})
	end

	card:Note(L["Also plays on the Master channel, so you hear them with sound effects off."])
end

---@param window table
function SettingsAlerts:Declare(window)
	local page = window:Page("alerts", {
		title = L["Alerts"],
		under = "qualityOfLifeHeader",
		icon = AUI.Media.sidebar.alerts,
		iconTint = true,
	})

	if not page then
		return
	end

	self:DeclareSound(page)

	if AUI.can.premadeJoined then
		local path = AUI.AlertOptions.PREMADE_JOINED_PATH
		local card = page:Section("alertsGroupFinder", L["Group Finder"])

		card:Checkbox({
			id = "premadeJoined",
			label = L["Joined Group in Chat"],
			path = path,
			default = AUI.Settings:Default(path),
		})
	end
end

AUI.Modules:Register({
	group = "qualityOfLife",
	page = SettingsAlerts,
	start = function()
		AUI.Alerts:Start()
	end,
})
