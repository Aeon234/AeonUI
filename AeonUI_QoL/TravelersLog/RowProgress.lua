local AUI = select(2, ...)

local lib = LibStub("LibAeonSettings-1.0")

local Options = AUI.TravelersLogOptions

local BAR_TEXTURE = "Interface\\Buttons\\WHITE8X8"

---A row's progress: the bar, its trough and its label. A row keeps one for the life of its pooled frame.
---@class AUITravelersLogBar : StatusBar
---@field trough Texture
---@field label FontString
---@field spring table the fill's
---@field activityID number? the activity last drawn, until the log closes
local BarMixin = {}

---@param geometry AUITravelersLogRowGeometry
function BarMixin:Build(geometry)
	local fill = Options.FILL_COLOR

	PixelUtil.SetSize(self, geometry.width - Options.LABEL_WIDTH - Options.LABEL_GAP, geometry.height)
	self:SetPoint("BOTTOMLEFT", self:GetParent(), "BOTTOMLEFT", geometry.left, geometry.bottom)
	self:SetStatusBarTexture(BAR_TEXTURE)
	self:SetStatusBarColor(fill.r, fill.g, fill.b)
	self:SetMinMaxValues(0, 1)

	self.trough = self:CreateTexture(nil, "BACKGROUND")
	self.trough:SetAllPoints(self)
	self.trough:SetColorTexture(0, 0, 0, Options.TROUGH_ALPHA)

	self.label = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	self.label:SetPoint("LEFT", self, "RIGHT", Options.LABEL_GAP, 0)

	self.spring = lib:CreateSpring(0, function(value)
		self:SetValue(value)
	end)
end

---Moves the fill when the same activity gains progress, and sets it otherwise. `from` is where this activity was last
---drawn this time the log is open, nil on its first drawing.
---@param activityID number
---@param ratio number
---@param from number?
function BarMixin:SetProgress(activityID, ratio, from)
	if self.activityID ~= activityID then
		self.activityID = activityID
		self.spring:Jump(from or ratio)
	end

	if ratio > self.spring.value then
		self.spring:To(ratio)
	elseif ratio ~= self.spring.target then
		self.spring:Jump(ratio)
	end
end

---@param text string?
---@param ratio number
---@param bars boolean the bar and its trough show
function BarMixin:SetLook(text, ratio, bars)
	local color = ratio > 0 and Options.LABEL_COLOR or Options.LABEL_EMPTY_COLOR

	self.label:SetText(text or "")
	self.label:SetTextColor(color.r, color.g, color.b)
	self.trough:SetShown(bars)
	self:GetStatusBarTexture():SetShown(bars)
	self:Show()
end

---Draws progress on the Traveler's Log's rows, each time Blizzard's list initializes a row.
---@class AUITravelersLogRows
---@field hooked boolean the list's row callback and the log's hide are hooked
---@field seen table<number, number> each activity's last drawn ratio, until the log closes
local Rows = {
	hooked = false,
	seen = {},
}
AUI.TravelersLogRows = Rows

---@return table? frame the Traveler's Log's frame
local function LogFrame()
	return EncounterJournal and EncounterJournal.MonthlyActivitiesFrame
end

---@param row table a pooled row
---@param activity table
---@return AUITravelersLogBar
local function RowBar(row, activity)
	local bar = row.aeonUIProgress

	if not bar then
		bar = Mixin(CreateFrame("StatusBar", nil, row), BarMixin)
		bar:Build(activity.isChild and Options.CHILD_ROW or Options.FULL_ROW)
		row.aeonUIProgress = bar
	end

	return bar
end

---@param row table a pooled row
---@param node table its tree node
function Rows:Draw(row, node)
	local bar = row.aeonUIProgress
	local activity = node:GetData()
	local ratio, current, required

	if AUI.TravelersLog:IsOn() and Options:Shows(activity, GetServerTime()) then
		ratio, current, required = Options:Progress(activity)
	end

	local Profile = AUI.Profile
	local bars = Profile:Get(Options.BARS_PATH) == true
	local text = ratio and Options:Label(Profile:Get(Options.TEXT_PATH), ratio, current, required)

	if not ratio or not (bars or text) then
		if bar then
			bar:Hide()
		end

		return
	end

	bar = RowBar(row, activity)
	bar:SetProgress(activity.ID, ratio, self.seen[activity.ID])
	bar:SetLook(text, ratio, bars)
	self.seen[activity.ID] = ratio
end

---Draws every row on screen, after a setting changes.
function Rows:Refresh()
	local frame = LogFrame()

	if frame and self.hooked then
		frame.ScrollBox:ForEachFrame(function(row, node)
			self:Draw(row, node)
		end)
	end
end

---Forgets what was drawn, so opening the log again sets each fill rather than moving it.
function Rows:OnLogHidden()
	self.seen = {}

	LogFrame().ScrollBox:ForEachFrame(function(row)
		if row.aeonUIProgress then
			row.aeonUIProgress.activityID = nil
		end
	end)
end

---Hooks the log once Blizzard's addon has loaded.
function Rows:Hook()
	local frame = LogFrame()

	if self.hooked or not frame then
		return
	end

	self.hooked = true
	ScrollUtil.AddInitializedFrameCallback(frame.ScrollBox, function(_, row, node)
		self:Draw(row, node)
	end, self, false)
	frame:HookScript("OnHide", function()
		self:OnLogHidden()
	end)
end
