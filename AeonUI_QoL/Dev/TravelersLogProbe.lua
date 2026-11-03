-- Development probe for the Traveler's Log. Not packaged.
local AUI = select(2, ...)

local CASE_SAMPLE = "Ärger ÉTÉ Кирилл"

---Saves what the client answers for this month's activities as lines of text in `AeonUIDB.global.devTravelersLog`, for
---reading from SavedVariables after a reload, and prints a summary. The lines keep the saved data shallow.
---@class AUITravelersLogProbe
local Probe = {}
AUI.Dev.TravelersLogProbe = Probe

---@param lines string[]
---@param activity table PerksActivityInfo
local function AddActivity(lines, activity)
	lines[#lines + 1] = ("A id=%d points=%d completed=%s inProgress=%s tracked=%s supersedes=%d priority=%d conditionsMet=%s"
		.. " start=%s end=%s event=%q name=%q"):format(activity.ID, activity.thresholdContributionAmount,
		tostring(activity.completed), tostring(activity.inProgress), tostring(activity.tracked), activity.supersedes,
		activity.uiPriority, tostring(activity.areAllConditionsMet), tostring(activity.eventStartTime),
		tostring(activity.eventEndTime), tostring(activity.eventName), activity.activityName)
	lines[#lines + 1] = ("  D %q"):format(activity.description)

	for _, tag in ipairs(activity.tagNames) do
		lines[#lines + 1] = ("  T %q"):format(tag)
	end

	for _, condition in ipairs(activity.conditions) do
		lines[#lines + 1] = ("  C met=%s %q"):format(tostring(condition.isMet), condition.text)
	end

	for _, requirement in ipairs(activity.requirementsList) do
		lines[#lines + 1] = ("  R done=%s %q"):format(tostring(requirement.completed), requirement.requirementText)
	end

	for _, criteria in ipairs(activity.criteriaList) do
		lines[#lines + 1] = ("  V id=%d required=%d"):format(criteria.criteriaID, criteria.requiredValue)
	end
end

---Saves the dump and prints its summary.
function Probe:Save()
	local global = AUI.Profile:Global()

	if not global then
		AUI:Print("travelerslog: no account data to save into.")

		return
	end

	local info = C_PerksActivities.GetPerksActivitiesInfo()
	local version, build = GetBuildInfo()
	local lines = {
		("build %s.%s locale %s available %s"):format(version, build, GetLocale(),
			tostring(C_PlayerInfo.IsTravelersLogAvailable())),
		("month %d %q seconds %d"):format(info.activePerksMonth, info.displayMonthName, info.secondsRemaining),
	}
	local activities = info.activities
	local counted, uncounted, several = 0, 0, 0

	table.sort(activities, function(a, b)
		return a.ID < b.ID
	end)

	for _, threshold in ipairs(info.thresholds) do
		lines[#lines + 1] = ("threshold %d required %d"):format(threshold.thresholdOrderIndex,
			threshold.requiredContributionAmount)
	end

	for _, activity in ipairs(activities) do
		AddActivity(lines, activity)

		if #activity.requirementsList > 1 then
			several = several + 1
		end

		for _, requirement in ipairs(activity.requirementsList) do
			if requirement.requirementText:find("%d%s*/%s*%d") then
				counted = counted + 1
			else
				uncounted = uncounted + 1
			end
		end
	end

	global.devTravelersLog = lines

	AUI:Print("travelerslog: %d activities, %d with several requirements; requirements %d with a fraction, %d without.",
		#activities, several, counted, uncounted)
	AUI:Print("travelerslog: lower %q, parse %q", CASE_SAMPLE:lower(), CaseAccentInsensitiveParse(CASE_SAMPLE))
	AUI:Print("travelerslog: saved %d lines; /reload writes them to SavedVariables.", #lines)
end

---@param rest string "clear" removes the dump; anything else saves it
function Probe:Command(rest)
	if rest == "clear" then
		local global = AUI.Profile:Global()

		if global then
			global.devTravelersLog = nil
		end

		AUI:Print("travelerslog: cleared; /reload writes that to SavedVariables.")

		return
	end

	self:Save()
end
