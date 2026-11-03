local AUI = select(2, ...)

local Schema = AUI.Schema

---Where the bar and its label sit on one kind of row, as offsets from the row's bottom left corner.
---@class AUITravelersLogRowGeometry
---@field left number the row's text starts here
---@field bottom number
---@field height number the bar's
---@field width number the row's text column, which the bar and its label share

---The Traveler's Log settings and their frame-free rules: which activities show progress, how far along an activity
---is, its label, which activities are hidden and each sort's order.
---@class AUITravelersLogOptions
---@field ENABLED_PATH string the page's switch
---@field BARS_PATH string rows draw a bar
---@field TEXT_PATH string a `travelersLogText` choice
---@field TEXT_CHOICES string[] the Text choices, in the order the page lists them
---@field SORT_PATH string a `travelersLogSort` choice
---@field SORTS string[] the sorts, in the order the dropdown lists them
---@field HIDE_COMPLETED_PATH string
---@field HIDE_EXPIRED_PATH string
---@field HIDE_UNAVAILABLE_PATH string
---@field FULL_ROW AUITravelersLogRowGeometry
---@field CHILD_ROW AUITravelersLogRowGeometry a superseding activity's row, nested under its parent
---@field LABEL_WIDTH number the room kept for the longest label
---@field LABEL_GAP number between the bar and its label
---@field FILL_COLOR { r: number, g: number, b: number }
---@field TROUGH_ALPHA number
---@field LABEL_COLOR { r: number, g: number, b: number }
---@field LABEL_EMPTY_COLOR { r: number, g: number, b: number } the label at no progress
local Options = {
	ENABLED_PATH = "travelersLog.enabled",
	BARS_PATH = "travelersLog.bars",
	TEXT_PATH = "travelersLog.text",
	TEXT_CHOICES = { "COUNT", "PERCENT", "NONE" },
	SORT_PATH = "travelersLog.sort",
	SORTS = { "DEFAULT", "POINTS_HIGH", "POINTS_LOW", "CLOSEST", "TIME", "NAME" },
	HIDE_COMPLETED_PATH = "travelersLog.hideCompleted",
	HIDE_EXPIRED_PATH = "travelersLog.hideExpired",
	HIDE_UNAVAILABLE_PATH = "travelersLog.hideUnavailable",
	FULL_ROW = { left = 36, bottom = 9, height = 5, width = 370 },
	CHILD_ROW = { left = 40, bottom = 5, height = 3, width = 350 },
	LABEL_WIDTH = 62,
	LABEL_GAP = 6,
	FILL_COLOR = { r = 0.92, g = 0.72, b = 0.2 },
	TROUGH_ALPHA = 0.38,
	LABEL_COLOR = { r = 0.95, g = 0.93, b = 0.87 },
	LABEL_EMPTY_COLOR = { r = 0.72, g = 0.67, b = 0.58 },
}
AUI.TravelersLogOptions = Options

Schema:Choices("travelersLogText", Options.TEXT_CHOICES)
Schema:Choices("travelersLogSort", Options.SORTS)

Schema:Boolean(Options.ENABLED_PATH, false)
Schema:Boolean(Options.BARS_PATH, true)
Schema:Choice(Options.TEXT_PATH, "travelersLogText", "COUNT")
Schema:Choice(Options.SORT_PATH, "travelersLogSort", "DEFAULT")
Schema:Boolean(Options.HIDE_COMPLETED_PATH, true)
Schema:Boolean(Options.HIDE_EXPIRED_PATH, true)
Schema:Boolean(Options.HIDE_UNAVAILABLE_PATH, false)

---@param number string digits, possibly with group separators
---@return number
local function ToNumber(number)
	return tonumber((number:gsub("%D", ""))) --[[@as number]]
end

---The first `current / required` in a requirement's text. Spaces around the slash are allowed; a number holds none, so
---a following number stays out of it.
---@param text string
---@return number? current
---@return number? required
function Options:ParseFraction(text)
	local current, required = text:match("(%d[%d.,]*)%s*/%s*(%d[%d.,]*)")

	if not current then
		return nil
	end

	return ToNumber(current), ToNumber(required)
end

---Whether an activity's row can show progress: it can still be worked on and the client lets the player do so.
---@param activity table a `PerksActivityInfo`, with the `restricted` field Blizzard's list adds
---@param now number the server's time
---@return boolean
function Options:Shows(activity, now)
	if activity.restricted or activity.completed then
		return false
	end

	return not (activity.eventEndTime and now > activity.eventEndTime)
end

---Whether the settings hide an activity. A restricted list stays as Blizzard built it. A tracked activity that is not
---finished stays, so the objective tracker's links to it keep working.
---@param activity table a `PerksActivityInfo`, with the `restricted` field Blizzard's list adds
---@param now number the server's time
---@param hide { completed: boolean, expired: boolean, unavailable: boolean }
---@return boolean
function Options:IsHidden(activity, now, hide)
	if activity.restricted then
		return false
	end

	if activity.completed then
		return hide.completed
	end

	if activity.tracked then
		return false
	end

	if hide.expired and activity.eventEndTime and now > activity.eventEndTime then
		return true
	end

	return hide.unavailable and (not activity.areAllConditionsMet
		or (activity.eventStartTime ~= nil and now < activity.eventStartTime))
end

---How far along an activity is. One requirement gives its own count. Several give how many are done, with the ratio
---the mean of each one's progress. One with no count, or none at all, gives nothing.
---@param activity table a `PerksActivityInfo`
---@return number? ratio 0 to 1
---@return number? current
---@return number? required
function Options:Progress(activity)
	local requirements = activity.requirementsList
	local count = #requirements

	if count == 0 then
		return nil
	end

	if count == 1 then
		local requirement = requirements[1]
		local current, required = self:ParseFraction(requirement.requirementText)

		if not current or required == 0 then
			return nil
		end

		current = requirement.completed and required or math.min(current, required)

		return current / required, current, required
	end

	local sum, done = 0, 0

	for _, requirement in ipairs(requirements) do
		if requirement.completed then
			sum, done = sum + 1, done + 1
		else
			local current, required = self:ParseFraction(requirement.requirementText)

			if current and required > 0 then
				sum = sum + math.min(current / required, 1)
			end
		end
	end

	return sum / count, done, count
end

---The label for a Text choice, nil for none. A percentage rounds down, so 100% means finished.
---@param choice string a `TEXT_CHOICES` entry
---@param ratio number
---@param current number
---@param required number
---@return string?
function Options:Label(choice, ratio, current, required)
	if choice == "COUNT" then
		return BreakUpLargeNumbers(current) .. "/" .. BreakUpLargeNumbers(required)
	elseif choice == "PERCENT" then
		return ("%d%%"):format(math.floor(ratio * 100))
	end

	return nil
end

---Most points first, then by name.
---@param a table
---@param b table
---@return boolean
local function ByPoints(a, b)
	if a.points ~= b.points then
		return a.points > b.points
	end

	if a.name ~= b.name then
		return a.name < b.name
	end

	return a.ID < b.ID
end

---Time Remaining's groups: running events, activities with no event, events yet to begin, then expired ones.
---@param activity table
---@param now number
---@return number
local function TimeGroup(activity, now)
	if not activity.eventEndTime then
		return 2
	elseif now > activity.eventEndTime then
		return 4
	elseif activity.eventStartTime and now < activity.eventStartTime then
		return 3
	end

	return 1
end

---Each sort's order for two activities that are neither finished nor finishing. `now` and `ratio` are the comparator's.
local ORDERS = {
	POINTS_HIGH = ByPoints,
	POINTS_LOW = function(a, b)
		if a.points ~= b.points then
			return a.points < b.points
		end

		return ByPoints(a, b)
	end,
	CLOSEST = function(a, b, _, ratio)
		local aRatio, bRatio = ratio(a), ratio(b)

		if aRatio ~= bRatio then
			return aRatio > bRatio
		end

		return ByPoints(a, b)
	end,
	TIME = function(a, b, now)
		local aGroup, bGroup = TimeGroup(a, now), TimeGroup(b, now)

		if aGroup ~= bGroup then
			return aGroup < bGroup
		end

		if aGroup == 1 and a.eventEndTime ~= b.eventEndTime then
			return a.eventEndTime < b.eventEndTime
		elseif aGroup == 3 and a.eventStartTime ~= b.eventStartTime then
			return (a.eventStartTime or 0) < (b.eventStartTime or 0)
		elseif aGroup == 4 and a.eventEndTime ~= b.eventEndTime then
			return a.eventEndTime > b.eventEndTime
		end

		return ByPoints(a, b)
	end,
	NAME = function(a, b)
		if a.name ~= b.name then
			return a.name < b.name
		end

		return ByPoints(a, b)
	end,
}

---A tree-node comparator for a sort, nil for Blizzard's own order. In every sort a completion still animating comes
---first, as Blizzard scrolls to the top to show it, and finished activities come last. Each activity's progress is
---worked out once per comparator.
---@param sort string a `SORTS` entry
---@param now number the server's time
---@param isPending fun(activityID: number): any whether the log is showing that activity's completion
---@return (fun(a: table?, b: table?): boolean)?
function Options:Comparator(sort, now, isPending)
	local order = ORDERS[sort]

	if not order then
		return nil
	end

	local ratios = {}

	local function Ratio(activity)
		local ratio = ratios[activity.ID]

		if not ratio then
			ratio = self:Progress(activity) or 0
			ratios[activity.ID] = ratio
		end

		return ratio
	end

	return function(aNode, bNode)
		if not aNode or not bNode then
			return aNode ~= nil
		end

		local a, b = aNode:GetData(), bNode:GetData()
		local aPending, bPending = not not isPending(a.ID), not not isPending(b.ID)

		if aPending ~= bPending then
			return aPending
		elseif aPending then
			return ByPoints(a, b)
		end

		if a.completed ~= b.completed then
			return b.completed
		elseif a.completed then
			return ByPoints(a, b)
		end

		return order(a, b, now, Ratio)
	end
end
