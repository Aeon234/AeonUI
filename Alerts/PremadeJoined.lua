local AUI = select(2, ...)

local Options = AUI.AlertOptions

---Joined Group in Chat: when the player joins a premade group, prints Blizzard's "Joined" and the group's activity,
---linked to its Adventure Guide page at the group's difficulty. The listing is read only where nothing in it is
---secret; otherwise nothing is printed.
---@class AUIPremadeJoined
---@field following boolean `LFG_LIST_JOINED_GROUP` is registered
local PremadeJoined = {
	following = false,
}
AUI.PremadeJoined = PremadeJoined

---@param value any
---@return boolean readable a number or string Lua may read
local function Readable(value)
	return not issecretvalue(value) and (type(value) == "number" or type(value) == "string")
end

---@param value any
---@return boolean readable a table Lua may index
local function ReadableTable(value)
	return not issecretvalue(value) and type(value) == "table" and canaccesstable(value)
end

---@param searchResultID any
---@return string? text the group's activity, linked to the Adventure Guide when it has a page; nil when any part of
---the listing cannot be read
function PremadeJoined.Describe(searchResultID)
	if not Readable(searchResultID) then
		return nil
	end

	local result = C_LFGList.GetSearchResultInfo(searchResultID)

	if not ReadableTable(result) or not ReadableTable(result.activityIDs) then
		return nil
	end

	local activityID = result.activityIDs[1]

	if not Readable(activityID) then
		return nil
	end

	local activity = C_LFGList.GetActivityInfoTable(activityID)

	if not ReadableTable(activity) or not Readable(activity.fullName) then
		return nil
	end

	local mapID, difficultyID = activity.mapID, activity.difficultyID
	local instanceID = Readable(mapID) and mapID ~= 0 and C_EncounterJournal.GetInstanceForGameMap(mapID) or nil

	if not Readable(instanceID) or not Readable(difficultyID) then
		instanceID = nil
	end

	return Options:JoinedText(activity.fullName, instanceID, difficultyID)
end

---@param _ string
---@param searchResultID any
function PremadeJoined:OnJoined(_, searchResultID)
	local text = self.Describe(searchResultID)

	if text then
		AUI:Print("%s %s", LFG_LIST_APP_INVITE_ACCEPTED, text)
	end
end

function PremadeJoined:Apply()
	local wanted = AUI.can.premadeJoined == true and AUI.Profile:Get(Options.PREMADE_JOINED_PATH) == true

	if wanted == self.following then
		return
	end

	self.following = wanted

	if wanted then
		AUI.Events:Register("LFG_LIST_JOINED_GROUP", self, self.OnJoined)
	else
		AUI.Events:Unregister("LFG_LIST_JOINED_GROUP", self)
	end
end
