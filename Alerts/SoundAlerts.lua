local AUI = select(2, ...)

local Options = AUI.AlertOptions

-- Events read for their payload: a battleground queue's status, a premade group application's, and boss emotes.
local PAYLOAD_EVENTS = {
	"UPDATE_BATTLEFIELD_STATUS",
	"LFG_LIST_APPLICATION_STATUS_UPDATED",
	"RAID_BOSS_EMOTE",
	"RAID_BOSS_WHISPER",
}

---Plays Blizzard's own alert sounds on the Master channel as well as the sound effects channel, where Blizzard plays
---them, for each group that is on. Follows the events only while some group is on.
---@class AUISoundAlerts
---@field active boolean the events are followed
---@field battlefields table<number, string> each battleground queue's last status, so a pop sounds once
local SoundAlerts = {
	active = false,
	battlefields = {},
}
AUI.SoundAlerts = SoundAlerts

---Plays a sound kit by name on the Master channel, if its group is on.
---@param group string
---@param sound string a `SOUNDKIT` key
---@return boolean played
function SoundAlerts:Alert(group, sound)
	local kit = SOUNDKIT and SOUNDKIT[sound]

	if not kit or Options:Get(Options.SoundPath(group)) ~= true then
		return false
	end

	PlaySound(kit, Options.CHANNEL, true)

	return true
end

---@param event string
---@param ... any the event's payload
function SoundAlerts:OnEvent(event, ...)
	local alert = Options.ALERTS[event]

	if alert then
		self:Alert(alert.group, alert.sound)
	elseif event == "UPDATE_BATTLEFIELD_STATUS" then
		local index = ...
		local status = index and GetBattlefieldStatus(index)

		if Options.BattlefieldPopped(self.battlefields[index], status) then
			self:Alert("queuePops", "PVP_THROUGH_QUEUE")
		end

		if index then
			self.battlefields[index] = status
		end
	elseif event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
		local _, newStatus = ...

		if AUI:Readable(newStatus, nil) == "invited" then
			self:Alert("queuePops", "IG_PLAYER_INVITE")
		end
	else
		-- Blizzard sounds a boss emote only when the event asks for it; so does this.
		local _, _, _, warn = ...

		if AUI:Readable(warn, false) == true then
			self:Alert("bossEmotes", event == "RAID_BOSS_EMOTE" and "RAID_BOSS_EMOTE_WARNING"
				or "UI_RAID_BOSS_WHISPER_WARNING")
		end
	end
end

---Follows the events while some group is on.
function SoundAlerts:Apply()
	local wanted = Options:AnySound()

	if wanted == self.active then
		return
	end

	self.active = wanted

	for event in pairs(Options.ALERTS) do
		self:Follow(event, wanted)
	end

	for _, event in ipairs(PAYLOAD_EVENTS) do
		self:Follow(event, wanted)
	end

	if not wanted then
		self.battlefields = {}
	end
end

---@param event string
---@param follow boolean
function SoundAlerts:Follow(event, follow)
	if follow then
		AUI.Events:Register(event, self, function(_, ...)
			self:OnEvent(...)
		end)
	else
		AUI.Events:Unregister(event, self)
	end
end
