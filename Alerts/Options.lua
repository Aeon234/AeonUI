local AUI = select(2, ...)

local Schema = AUI.Schema

---The Alerts settings and the frame-free rules behind Sound Alerts: the group and sound kit each event plays.
---@class AUIAlertOptions
---@field SOUND_GROUPS string[] the Sound Alerts groups, in the order the page lists them
---@field ALERTS table<string, AUISoundAlert> the events whose alert needs no look at their payload
---@field CHANNEL string the channel each alert plays on, beside Blizzard's own on the sound effects channel
local Options = {
	SOUND_GROUPS = { "queuePops", "readyChecks", "whispers", "partyInvites", "bossEmotes" },
	CHANNEL = "Master",
	ALERTS = {
		LFG_PROPOSAL_SHOW = { group = "queuePops", sound = "READY_CHECK" },
		PET_BATTLE_QUEUE_PROPOSE_MATCH = { group = "queuePops", sound = "UI_PET_BATTLES_PVP_THROUGH_QUEUE" },
		READY_CHECK = { group = "readyChecks", sound = "READY_CHECK" },
		ROLE_POLL_BEGIN = { group = "readyChecks", sound = "READY_CHECK" },
		LFG_ROLE_CHECK_SHOW = { group = "readyChecks", sound = "READY_CHECK" },
		CHAT_MSG_WHISPER = { group = "whispers", sound = "TELL_MESSAGE" },
		CHAT_MSG_BN_WHISPER = { group = "whispers", sound = "TELL_MESSAGE" },
		PARTY_INVITE_REQUEST = { group = "partyInvites", sound = "IG_PLAYER_INVITE" },
	},
}
AUI.AlertOptions = Options

---An alert sounded by an event: its group and the `SOUNDKIT` key Blizzard plays for it.
---@class AUISoundAlert
---@field group string
---@field sound string

---@param group string one of `SOUND_GROUPS`
---@return string path the group is sounded on the Master channel
function Options.SoundPath(group)
	return "alerts.sound." .. group
end

for _, group in ipairs(Options.SOUND_GROUPS) do
	Schema:Boolean(Options.SoundPath(group), false)
end

---@param path string
---@return any value
function Options:Get(path)
	return AUI.Profile:Get(path)
end

---@return boolean any some group is on
function Options:AnySound()
	for _, group in ipairs(self.SOUND_GROUPS) do
		if self:Get(self.SoundPath(group)) == true then
			return true
		end
	end

	return false
end

---Whether a battleground queue's status change is its pop: a move to `confirm`, once.
---@param previous string? the queue's last status
---@param status string? its status now
---@return boolean
function Options.BattlefieldPopped(previous, status)
	return status == "confirm" and previous ~= "confirm"
end
