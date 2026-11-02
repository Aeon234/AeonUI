local AUI = select(2, ...)

local Schema = AUI.Schema
local Elements = AUI.MinimapElements

Schema:Choices("minimapZoneColor", { "PVP", "GOLD" })
Schema:Choice("minimap.zone.color", "minimapZoneColor", "PVP")
Schema:Boolean("minimap.clock.twentyFour", true)
Schema:Boolean("minimap.clock.localTime", true)
Schema:Boolean("minimap.clock.dayNight", true)
Schema:Number("minimap.clock.iconSize", 14, 8, 32, true)
Schema:Number("minimap.coordinates.precision", 1, 0, 2, true)

local ZONE_EVENTS = { "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }
-- Blizzard's minimap zone colors by PvP status (Blizzard_Minimap/Mainline/Minimap.lua, Minimap_Update), and the line
-- its zone tooltip adds for each.
local PVP_COLORS = {
	sanctuary = { r = 0.41, g = 0.8, b = 0.94 },
	arena = { r = 1, g = 0.1, b = 0.1 },
	friendly = { r = 0.1, g = 1, b = 0.1 },
	hostile = { r = 1, g = 0.1, b = 0.1 },
	contested = { r = 1, g = 0.7, b = 0 },
	combat = { r = 1, g = 0.1, b = 0.1 },
}
local PVP_LINES = {
	sanctuary = "SANCTUARY_TERRITORY",
	arena = "FREE_FOR_ALL_TERRITORY",
	friendly = "FACTION_CONTROLLED_TERRITORY",
	hostile = "FACTION_CONTROLLED_TERRITORY",
	contested = "CONTESTED_TERRITORY",
	combat = "COMBAT_ZONE",
}
-- The day and night icons (Tools/day-night-icons.py). Forever reports day and night itself; Retail's day runs from
-- the dawn to the dusk its GameTime.lua still names, in minutes after midnight on the realm's clock.
local TEXTURES = "Interface\\AddOns\\" .. AUI.name .. "\\Media\\Textures\\"
local DAY_ICON, NIGHT_ICON = TEXTURES .. "Sun.tga", TEXTURES .. "Moon.tga"
local DAWN, DUSK = 5 * 60 + 30, 21 * 60
-- Seconds between realm-time checks, which do not line up with the local minute, and between coordinate updates
-- while the player moves.
local REALM_INTERVAL = 5
local COORDINATE_INTERVAL = 0.1
local ICON_GAP = 3
-- The preview's coordinates where the map has no position for the player.
local SAMPLE_COORDINATES = { x = 45.67, y = 62.34 }

---A row element showing one line of text in its text settings (`Elements:DeclareText`), with Blizzard's text shadow.
---@class AUIMinimapTextElement: AUIMinimapElement
---@field colored boolean? takes the text color; false for an element with colors of its own
---@field offsetY number? how far the text is raised from the row's middle, lowered below 0
---@field frameType string? the cell's frame type; "Button" for a clickable element
---@field text FontString?
---@field value string? the text shown
---@field width number? its width when last measured, nil while it shows nothing

local TextElementMixin = { kind = "text" } --[[@as AUIMinimapTextElement]]

---@param parent Frame
function TextElementMixin:Build(parent)
	local frame = CreateFrame(self.frameType or "Frame", nil, parent)
	local text = frame:CreateFontString(nil, "OVERLAY")

	text:SetFontObject(GameFontNormal)
	text:SetPoint("LEFT")
	text:SetPoint("RIGHT")
	text:SetJustifyH("LEFT")
	text:SetWordWrap(false)
	frame:Hide()

	self.frame, self.text = frame, text
end

function TextElementMixin:Style()
	self.offsetY = Elements:StyleText(self.key, self.text --[[@as FontString]], self.colored)
	self:PlaceText(0)
end

---Anchors the text across the cell, raised or lowered by its Y Offset.
---@param left number where the text starts, from the cell's left edge
function TextElementMixin:PlaceText(left)
	local text = self.text --[[@as FontString]]
	local y = self.offsetY or 0

	text:ClearAllPoints()
	text:SetPoint("LEFT", left, y)
	text:SetPoint("RIGHT", 0, y)
end

---@return boolean
function TextElementMixin:IsShown()
	return self.active == true and self.value ~= nil and self.value ~= ""
end

---@return number
function TextElementMixin:Width()
	return math.ceil((self.text --[[@as FontString]]):GetUnboundedStringWidth())
end

---Shows a text. The rows are arranged again only when the element's width changes or it appears or disappears; a
---change within the same width touches nothing else.
---@param value string?
function TextElementMixin:SetText(value)
	if value == self.value then
		return
	end

	self.value = value
	;(self.text --[[@as FontString]]):SetText(value)

	local width = self:IsShown() and self:Width() or nil

	if width ~= self.width then
		self.width = width
		Elements:Changed()
	end
end

---Shows a tooltip beside the element, filled by `fill`, while the mouse is over it.
---@param fill fun(tooltip: GameTooltip)
function TextElementMixin:SetTooltip(fill)
	local frame = self.frame --[[@as Frame]]

	frame:EnableMouse(true)
	frame:SetScript("OnEnter", function(owner)
		GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
		fill(GameTooltip)
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function()
		GameTooltip_Hide()
	end)
end

---@param events string[]
---@param owner table
---@param handler fun(owner: table, event: string, ...: any)
---@param active boolean
local function RegisterEvents(events, owner, handler, active)
	for _, event in ipairs(events) do
		if active then
			AUI.Events:Register(event, owner, handler)
		else
			AUI.Events:Unregister(event, owner)
		end
	end
end

---The minimap's zone text: the subzone when there is one, as Blizzard's minimap shows it, colored by PvP status or in
---gold. Its tooltip is Blizzard's zone tooltip; a click opens the world map.
---@class AUIMinimapZone: AUIMinimapTextElement
local Zone = Mixin({
	key = "zone",
	flexible = true,
	frameType = "Button",
}, TextElementMixin)

---@param pvpType string?
---@return AUIColor color the zone's color for a PvP status, Blizzard's gold when it has none
function Zone:Color(pvpType)
	return PVP_COLORS[pvpType or ""] or { r = NORMAL_FONT_COLOR.r, g = NORMAL_FONT_COLOR.g, b = NORMAL_FONT_COLOR.b }
end

---@param parent Frame
function Zone:Build(parent)
	TextElementMixin.Build(self, parent)

	local frame = self.frame --[[@as Button]]

	frame:RegisterForClicks("LeftButtonUp")
	frame:SetScript("OnClick", function()
		if not Zone:WorldMapDisabled() then
			ToggleWorldMap()
		end
	end)
	self:SetTooltip(function(tooltip)
		Zone:FillTooltip(tooltip)
	end)
end

---@return boolean
function Zone:WorldMapDisabled()
	return C_GameRules ~= nil and C_GameRules.IsGameRuleActive(Enum.GameRule.WorldMapDisabled) == true
end

---The zone, then the subzone and the PvP status line in the status's color, then the world map's binding.
---@param tooltip GameTooltip
function Zone:FillTooltip(tooltip)
	local pvpType, _, factionName = C_PvP.GetZonePVPInfo()
	local zoneName, subzoneName = GetZoneText(), GetSubZoneText()
	local color = self:Color(pvpType)
	local line = PVP_LINES[pvpType or ""]

	if subzoneName == zoneName then
		subzoneName = ""
	end

	tooltip:AddLine(zoneName, 1, 1, 1)

	-- Blizzard adds no lines for a friendly or hostile zone without a faction name.
	if (pvpType ~= "friendly" and pvpType ~= "hostile") or (factionName and factionName ~= "") then
		tooltip:AddLine(subzoneName, color.r, color.g, color.b)

		if line then
			tooltip:AddLine(_G[line]:format(factionName or ""), color.r, color.g, color.b)
		end
	end

	if not self:WorldMapDisabled() then
		tooltip:AddLine(MicroButtonTooltipText(WORLDMAP_BUTTON, "TOGGLEWORLDMAP"))
	end
end

---@param active boolean
function Zone:SetActive(active)
	RegisterEvents(ZONE_EVENTS, self, self.Update, active)

	if active then
		self:Update()
	end
end

function Zone:Style()
	TextElementMixin.Style(self)
	self:Update()
end

function Zone:Update()
	local color = self:Color(AUI.Profile:Get("minimap.zone.color") == "PVP" and C_PvP.GetZonePVPInfo() or nil)

	;(self.text --[[@as FontString]]):SetTextColor(color.r, color.g, color.b)
	self:SetText(GetMinimapZoneText())
end

---The time, local or the realm's, 24-hour or 12-hour, with a sun or moon before it for day or night. Its tooltip
---is Blizzard's time tooltip, with both times.
---@class AUIMinimapClock: AUIMinimapTextElement
---@field timer table? the timer for the next update
---@field icon Texture?
---@field day boolean? the indicator shows day
local Clock = Mixin({
	key = "clock",
	colored = true,
}, TextElementMixin)

---@param hour integer
---@param minute integer
---@param twentyFour boolean
---@return string
function Clock:Format(hour, minute, twentyFour)
	if twentyFour then
		return TIMEMANAGER_TICKER_24HOUR:format(hour, minute)
	end

	local twelve = hour % 12

	return (hour >= 12 and TIME_TWELVEHOURPM or TIME_TWELVEHOURAM):format(twelve == 0 and 12 or twelve, minute)
end

---@param hour integer the realm's
---@param minute integer
---@return boolean day Retail's day, from its dawn and dusk
function Clock:IsDay(hour, minute)
	local time = hour * 60 + minute

	return time >= DAWN and time < DUSK
end

---@param parent Frame
function Clock:Build(parent)
	TextElementMixin.Build(self, parent)

	local icon = (self.frame --[[@as Frame]]):CreateTexture(nil, "ARTWORK")

	icon:SetPoint("LEFT")
	icon:Hide()
	self.icon = icon

	self:SetTooltip(function()
		GameTime_UpdateTooltip()
	end)
end

function Clock:Style()
	TextElementMixin.Style(self)

	local icon = self.icon --[[@as Texture]]
	local size = AUI.Profile:Get("minimap.clock.iconSize")
	local shown = AUI.Profile:Get("minimap.clock.dayNight") == true

	icon:SetSize(size, size)
	icon:SetShown(shown)
	self:PlaceText(shown and size + ICON_GAP or 0)

	if self.active then
		self:Tick()
	end
end

---@return number
function Clock:Width()
	local icon = self.icon --[[@as Texture]]

	return TextElementMixin.Width(self) + (icon:IsShown() and icon:GetWidth() + ICON_GAP or 0)
end

---@param active boolean
function Clock:SetActive(active)
	if AUI.can.dielCycle then
		RegisterEvents({ "DIEL_CYCLE_CHANGED" }, self, self.UpdateDay, active)
	end

	if active then
		self:Tick()
	elseif self.timer then
		self.timer:Cancel()
		self.timer = nil
	end
end

---Shows the sun by day and the moon by night: Forever's own day and night, or Retail's from the realm's time.
function Clock:UpdateDay()
	local day

	if AUI.can.dielCycle then
		day = C_DateAndTime.IsDayTime()
	else
		day = self:IsDay(GetGameTime())
	end

	if day ~= self.day then
		self.day = day
		;(self.icon --[[@as Texture]]):SetTexture(day and DAY_ICON or NIGHT_ICON)
	end
end

---Shows the time and sets the next update: the start of the next local minute, or a few seconds later for the
---realm's time.
function Clock:Tick()
	if self.timer then
		self.timer:Cancel()
	end

	local Profile = AUI.Profile
	local localTime = Profile:Get("minimap.clock.localTime")
	local hour, minute

	if localTime then
		hour, minute = tonumber(date("%H")) or 0, tonumber(date("%M")) or 0
	else
		hour, minute = GetGameTime()
	end

	self:SetText(self:Format(hour, minute, Profile:Get("minimap.clock.twentyFour")))
	self:UpdateDay()
	self.timer = C_Timer.NewTimer(localTime and 60 - (tonumber(date("%S")) or 0) or REALM_INTERVAL, function()
		self.timer = nil
		self:Tick()
	end)
end

---A map's extent in world coordinates: its top-left corner and its size, as `C_Map.GetWorldPosFromMapPos` gives them.
---@class AUIMapRect
---@field x number
---@field y number
---@field width number
---@field height number

---The player's map coordinates, updated while the player moves (or is moved, as on a flight path). Hidden where the
---game gives no world position for the player, as in instances.
---
---The position is the player's world position placed in the map's world extent, which is asked for once per map and
---kept: no table is made per update, unlike `C_Map.GetPlayerMapPosition`, which returns a new vector each call (the
---method ls: Minimap credits to elcius). The text is rebuilt only when the rounded numbers change.
---@class AUIMinimapCoordinates: AUIMinimapTextElement
---@field ticker table? the updates while moving
---@field precision integer? decimals, from the setting
---@field shownX integer? the shown numbers, rounded to the precision and scaled to whole numbers
---@field shownY integer?
local Coordinates = Mixin({
	key = "coordinates",
	colored = true,
}, TextElementMixin)
local mapRects = {} ---@type table<number, AUIMapRect | false>

---@param worldX number the world position's first coordinate, which runs north
---@param worldY number its second, which runs west
---@param rect AUIMapRect
---@return number? x percent across the map, nil for a map with no extent
---@return number? y percent down it
function Coordinates:MapPercent(worldX, worldY, rect)
	if rect.width == 0 or rect.height == 0 then
		return nil, nil
	end

	return (worldY - rect.y) / rect.height * 100, (worldX - rect.x) / rect.width * 100
end

---@param mapID number
---@return AUIMapRect | false rect the map's world extent, false for a map without one
function Coordinates:MapRect(mapID)
	local rect = mapRects[mapID]

	if rect == nil then
		local _, topLeft = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(0, 0))
		local _, bottomRight = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(1, 1))

		rect = topLeft ~= nil and bottomRight ~= nil and {
			x = topLeft.x,
			y = topLeft.y,
			width = bottomRight.x - topLeft.x,
			height = bottomRight.y - topLeft.y,
		} or false
		mapRects[mapID] = rect
	end

	return rect
end

---@return number? x percent across the player's map, nil where there is no position
---@return number? y
function Coordinates:Position()
	local worldX, worldY = UnitPosition("player")

	worldX, worldY = AUI:Readable(worldX), AUI:Readable(worldY)

	if type(worldX) ~= "number" or type(worldY) ~= "number" then
		return nil, nil
	end

	local mapID = C_Map.GetBestMapForUnit("player")
	local rect = mapID and self:MapRect(mapID)

	if not rect then
		return nil, nil
	end

	return self:MapPercent(worldX, worldY, rect)
end

---@param x number percent across the map
---@param y number percent down it
---@param precision integer decimals
---@return string
function Coordinates:Format(x, y, precision)
	local number = "%." .. precision .. "f"

	return (number .. ", " .. number):format(x, y)
end

---The width of the text with every digit a zero, so it does not shift as the numbers change.
---@return number
function Coordinates:Width()
	local text = self.text --[[@as FontString]]

	return math.ceil(text:GetUnboundedStringWidthForText(((self.value or ""):gsub("%d", "0"))))
end

---@param active boolean
function Coordinates:SetActive(active)
	RegisterEvents(ZONE_EVENTS, self, self.Update, active)
	RegisterEvents({ "PLAYER_STARTED_MOVING", "PLAYER_CONTROL_LOST" }, self, self.StartMoving, active)
	RegisterEvents({ "PLAYER_STOPPED_MOVING", "PLAYER_CONTROL_GAINED" }, self, self.StopMoving, active)

	if active then
		self:Update()

		if IsPlayerMoving() then
			self:StartMoving()
		end
	else
		self:StopMoving()
	end
end

function Coordinates:Style()
	TextElementMixin.Style(self)
	self.precision = AUI.Profile:Get("minimap.coordinates.precision")
	self.shownX, self.shownY, self.width = nil, nil, nil

	if self.active then
		self.value = nil
		self:Update()
	end
end

function Coordinates:StartMoving()
	if not self.ticker then
		self.ticker = C_Timer.NewTicker(COORDINATE_INTERVAL, function()
			self:Update()
		end)
	end
end

function Coordinates:StopMoving()
	if self.ticker then
		self.ticker:Cancel()
		self.ticker = nil
	end

	if self.active then
		self:Update()
	end
end

function Coordinates:Update()
	local precision = self.precision or 1
	local x, y = self:Position()

	if not x and Elements.preview then
		x, y = SAMPLE_COORDINATES.x, SAMPLE_COORDINATES.y
	end

	if not x or not y then
		self.shownX, self.shownY = nil, nil
		self:SetText(nil)

		return
	end

	local scale = 10 ^ precision
	local shownX, shownY = math.floor(x * scale + 0.5), math.floor(y * scale + 0.5)

	if shownX ~= self.shownX or shownY ~= self.shownY then
		self.shownX, self.shownY = shownX, shownY
		self:SetText(self:Format(shownX / scale, shownY / scale, precision))
	end
end

Elements:DeclareText("zone")
Elements:DeclareText("clock", true)
Elements:DeclareText("coordinates", true)
Elements:Register(Zone, "TOP1", 1)
Elements:Register(Clock, "TOP1", 3)
Elements:Register(Coordinates, "TOP2", 4)
