local AUI = select(2, ...)

local Schema = AUI.Schema

---The Alerts settings and their frame-free rules: the group and sound kit each Sound Alerts event plays, and the text
---Joined Group in Chat prints.
---@class AUIAlertOptions
---@field SOUND_GROUPS string[] the Sound Alerts groups, in the order the page lists them
---@field ALERTS table<string, AUISoundAlert> the events whose alert needs no look at their payload
---@field CHANNEL string the channel each alert plays on, beside Blizzard's own on the sound effects channel
---@field PREMADE_JOINED_PATH string joining a premade group prints its activity
local Options = {
	SOUND_GROUPS = { "queuePops", "readyChecks", "whispers", "partyInvites", "bossEmotes" },
	CHANNEL = "Master",
	PREMADE_JOINED_PATH = "alerts.premadeJoined",
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

Schema:Boolean(Options.PREMADE_JOINED_PATH, false)

-- An Adventure Guide link to an instance at a difficulty, in Blizzard's journal-link color.
local JOURNAL_LINK = "|cff66bbff|Hjournal:0:%d:%d|h[%s]|h|r"

---What Joined Group in Chat names: the activity, linked to its instance's Adventure Guide page when it has one.
---@param name string the activity's full name
---@param instanceID number? the Adventure Guide instance; nil or 0 when it has none
---@param difficultyID number? the group's difficulty, for the link
---@return string text
function Options:JoinedText(name, instanceID, difficultyID)
	if instanceID and instanceID ~= 0 then
		return JOURNAL_LINK:format(instanceID, difficultyID or 0, name)
	end

	return name
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
