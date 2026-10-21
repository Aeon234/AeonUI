local AUI = select(2, ...)

local Schema = AUI.Schema
local Elements = AUI.MinimapElements

Schema:Number("minimap.rows.textSize", 12, 8, 24, true)
Schema:Number("minimap.zone.textSize", 13, 8, 24, true)

local ZONE_EVENTS = { "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }

---A row element showing one line of text in a Blizzard font at the size its setting gives.
---@class AUIMinimapTextElement: AUIMinimapElement
---@field fontObject string the Blizzard font object the text takes its face, color and shadow from
---@field sizePath string the text size setting
---@field text FontString?
---@field value string? the text shown

local TextElementMixin = { kind = "text" } --[[@as AUIMinimapTextElement]]

---@param parent Frame
function TextElementMixin:Build(parent)
	local frame = CreateFrame("Frame", nil, parent)
	local text = frame:CreateFontString(nil, "OVERLAY")

	text:SetFontObject(_G[self.fontObject])
	text:SetPoint("LEFT")
	text:SetPoint("RIGHT")
	text:SetJustifyH("LEFT")
	text:SetWordWrap(false)
	frame:Hide()

	self.frame, self.text = frame, text
end

function TextElementMixin:Style()
	local text = self.text --[[@as FontString]]
	local font, _, flags = _G[self.fontObject]:GetFont()

	text:SetFont(font, AUI.Profile:Get(self.sizePath), flags)
end

---@return boolean
function TextElementMixin:IsShown()
	return self.active == true and self.value ~= nil and self.value ~= ""
end

---@return number
function TextElementMixin:Width()
	return math.ceil((self.text --[[@as FontString]]):GetUnboundedStringWidth())
end

---@param value string?
function TextElementMixin:SetText(value)
	if value == self.value then
		return
	end

	self.value = value
	;(self.text --[[@as FontString]]):SetText(value)
	Elements:Changed()
end

---The minimap's zone text: the subzone when there is one, as Blizzard's minimap shows it.
---@class AUIMinimapZone: AUIMinimapTextElement
local Zone = Mixin({ key = "zone", flexible = true, fontObject = "GameFontNormal", sizePath = "minimap.zone.textSize" },
	TextElementMixin)

---@param active boolean
function Zone:SetActive(active)
	for _, event in ipairs(ZONE_EVENTS) do
		if active then
			AUI.Events:Register(event, self, self.Update)
		else
			AUI.Events:Unregister(event, self)
		end
	end

	if active then
		self:Update()
	end
end

function Zone:Update()
	self:SetText(GetMinimapZoneText())
end

---The local time, 24-hour, updated at the start of each minute while it is placed in a row.
---@class AUIMinimapClock: AUIMinimapTextElement
---@field timer table? the timer for the next minute
local Clock = Mixin({ key = "clock", fontObject = "GameFontHighlightSmall", sizePath = "minimap.rows.textSize" },
	TextElementMixin)

---@param active boolean
function Clock:SetActive(active)
	if self.timer then
		self.timer:Cancel()
		self.timer = nil
	end

	if active then
		self:Tick()
	end
end

function Clock:Tick()
	self:SetText(date("%H:%M") --[[@as string]])
	self.timer = C_Timer.NewTimer(60 - (tonumber(date("%S")) or 0), function()
		self.timer = nil
		self:Tick()
	end)
end

Elements:Register(Zone, "TOP1", 1)
Elements:Register(Clock, "TOP2", 2)
