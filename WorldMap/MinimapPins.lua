local AUI = select(2, ...)

local Markers = AUI.WorldMapMarkers

local PIN_SIZE = 14
local MOVE_INTERVAL = 0.05
-- The most pins the minimap holds at once, the nearest first.
local MAX_PINS = 20
-- How far around the player markers are gathered, against the minimap's view radius, and how far the player may move
-- from where they were gathered before they are gathered again.
local GATHER_REACH = 2
local GATHER_STEP = 0.5
local MOVE_EVENTS = { "PLAYER_STARTED_MOVING", "PLAYER_CONTROL_LOST" }
local STOP_EVENTS = { "PLAYER_STOPPED_MOVING", "PLAYER_CONTROL_GAINED" }
local GATHER_EVENTS = { "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD", "MINIMAP_UPDATE_ZOOM" }

---@class AUIWorldMapMinimapPin: Frame
---@field icon Texture
---@field marker AUIWorldMapMarker? the marker shown, while acquired

---@class AUIWorldPosition
---@field north number the world position's first coordinate, which runs north
---@field west number its second, which runs west
---@field continent number

---Mailboxes, spirit healers and docks near the player, as pins on the minimap. The nearest markers are gathered from a
---wider circle and kept until the player has moved some way, and the pins are placed again only while the player moves
---(or the minimap turns with the player); nothing runs while the player stands still on a north-up minimap.
---@class AUIWorldMapMinimap
---@field active boolean the layer is on
---@field pool table? the pins, made on first use
---@field candidates AUIWorldMapMarker[]? the markers of the groups switched on, with a world position
---@field world table<AUIWorldMapMarker, AUIWorldPosition|false> each marker's world position, false where it has none
---@field near AUIWorldMapMarker[] the markers gathered around the player, nearest first
---@field pins table<AUIWorldMapMarker, AUIWorldMapMinimapPin> the pin showing each gathered marker
---@field gatheredAt AUIWorldPosition? where the player stood when the markers were gathered
---@field ticker table? the updates while moving
local Layer = {
	active = false,
	world = {},
	near = {},
	pins = {},
}
AUI.WorldMapMinimap = Layer

---@param _ table
---@param pin AUIWorldMapMinimapPin
local function ResetPin(_, pin)
	pin:Hide()
	pin:ClearAllPoints()
	pin.marker = nil
end

---@param pin AUIWorldMapMinimapPin
local function OnEnter(pin)
	if pin.marker then
		GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
		AUI.WorldMap:AddMarkerLines(pin.marker, true)
		GameTooltip:Show()
	end
end

---@param pin AUIWorldMapMinimapPin
local function InitPin(pin)
	pin:SetSize(PIN_SIZE, PIN_SIZE)
	pin.icon = pin:CreateTexture(nil, "ARTWORK")
	pin.icon:SetAllPoints()
	pin:SetMouseMotionEnabled(true)
	pin:SetMouseClickEnabled(false)
	pin:SetScript("OnEnter", OnEnter)
	pin:SetScript("OnLeave", GameTooltip_Hide)
end

---@return table pool
function Layer:Pool()
	if not self.pool then
		self.pool = CreateFramePool("Frame", Minimap, nil, ResetPin, false, InitPin)
	end

	return self.pool
end

---@param marker AUIWorldMapMarker
---@return AUIWorldPosition? position the marker's world position, worked out once
function Layer:WorldPosition(marker)
	local position = self.world[marker]

	if position == nil then
		local continent, world = C_Map.GetWorldPosFromMapPos(marker.map, CreateVector2D(marker.x, marker.y))

		position = continent and world and { north = world.x, west = world.y, continent = continent } or false
		self.world[marker] = position
	end

	return position or nil
end

-- Reused on every placement while moving, so the ticker makes no garbage.
local here = { north = 0, west = 0, continent = 0 }
local rectangle = { halfWidth = 0, halfHeight = 0 }
local round = { radius = 0 }

---@return AUIWorldPosition? player the player's world position, nil where the game gives none (instances); the same
---table on every call
local function PlayerPosition()
	local north, west, _, continent = UnitPosition("player")

	north, west, continent = AUI:Readable(north), AUI:Readable(west), AUI:Readable(continent)

	if type(north) ~= "number" or type(west) ~= "number" or type(continent) ~= "number" then
		return nil
	end

	here.north, here.west, here.continent = north, west, continent

	return here
end

---Collects the markers of the minimap groups switched on that the player's faction and race see.
function Layer:Collect()
	local Profile, module = AUI.Profile, AUI.WorldMap
	local shown = {}

	for _, entry in ipairs(Markers.MINIMAP) do
		if Profile:Get(Markers:MinimapPath(entry.key)) then
			for _, key in ipairs(entry.categories) do
				shown[key] = true
			end
		end
	end

	---@type AUIWorldMapFilter
	local query = {
		shown = shown,
		faction = module.faction,
		otherFaction = module.otherFaction,
		race = module.race,
		class = module.class,
	}
	local candidates = {}

	for _, markers in pairs(Markers.byMap or {}) do
		for _, marker in ipairs(markers) do
			if shown[marker.category] and Markers:IsShown(marker, query) and self:WorldPosition(marker) then
				candidates[#candidates + 1] = marker
			end
		end
	end

	self.candidates = candidates
end

---Gathers the nearest candidates within reach of the player and gives each a pin.
---@param player AUIWorldPosition
function Layer:Gather(player)
	local reach = C_Minimap.GetViewRadius() * GATHER_REACH
	local found, distances = {}, {}

	for _, marker in ipairs(self.candidates or {}) do
		local position = self:WorldPosition(marker) --[[@as AUIWorldPosition]]

		if position.continent == player.continent then
			local north, west = position.north - player.north, position.west - player.west
			local distance = north * north + west * west

			if distance <= reach * reach then
				found[#found + 1] = marker
				distances[marker] = distance
			end
		end
	end

	table.sort(found, function(a, b)
		return distances[a] < distances[b]
	end)

	local pool = self:Pool()

	pool:ReleaseAll()
	self.pins = {}
	self.near = {}

	for index = 1, math.min(#found, MAX_PINS) do
		local marker = found[index]
		local pin = pool:Acquire() --[[@as AUIWorldMapMinimapPin]]
		local atlas, file = Markers:MarkerIcon(Markers.byKey[marker.category], marker)

		if atlas then
			pin.icon:SetAtlas(atlas)
		else
			pin.icon:SetTexture(file)
		end

		pin.marker = marker
		pin:SetFrameLevel(Minimap:GetFrameLevel() + 5)
		self.near[index] = marker
		self.pins[marker] = pin
	end

	self.gatheredAt = { north = player.north, west = player.west, continent = player.continent }
end

---@return AUIMinimapShape shape the visible minimap less half a pin; the same table on every call
---@return number? facing the player's facing when the minimap turns with the player
function Layer:Shape()
	local margin = PIN_SIZE / 2
	local map = AUI.Minimap
	local geometry = map.active and map.geometry

	if geometry then
		rectangle.halfWidth, rectangle.halfHeight = geometry.width / 2 - margin, geometry.height / 2 - margin

		return rectangle
	end

	local facing = C_CVar.GetCVarBool("rotateMinimap") and AUI:Readable(GetPlayerFacing()) or nil

	round.radius = Minimap:GetWidth() / 2 - margin

	return round, facing
end

---Places the gathered pins around the player, gathering again once the player has moved far enough.
function Layer:Update()
	if not self.active then
		return
	end

	local player = PlayerPosition()
	local radius = C_Minimap.GetViewRadius()

	if not player or not radius or radius <= 0 then
		self:Pool():ReleaseAll()
		self.pins, self.near, self.gatheredAt = {}, {}, nil

		return
	end

	local last = self.gatheredAt

	if not last or last.continent ~= player.continent
		or (last.north - player.north) ^ 2 + (last.west - player.west) ^ 2 > (radius * GATHER_STEP) ^ 2 then
		self:Gather(player)
	end

	local shape, facing = self:Shape()
	local scale = Minimap:GetWidth() / 2 / radius

	for _, marker in ipairs(self.near) do
		local position = self:WorldPosition(marker) --[[@as AUIWorldPosition]]
		local pin = self.pins[marker]
		local right, up = Markers:MinimapOffset(position.north - player.north, position.west - player.west, facing)
		local x, y = right * scale, up * scale

		if Markers:OnMinimap(x, y, shape) then
			pin:SetPoint("CENTER", Minimap, "CENTER", x, y)
			pin:Show()
		else
			pin:Hide()
		end
	end

	-- A turning minimap moves the pins whenever the player turns, which no event reports.
	if facing and not self.ticker then
		self:StartMoving()
	end
end

function Layer:StartMoving()
	if not self.ticker then
		self.ticker = C_Timer.NewTicker(MOVE_INTERVAL, function()
			Layer:Update()
		end)
	end
end

function Layer:StopMoving()
	if self.ticker then
		self.ticker:Cancel()
		self.ticker = nil
	end

	self:Update()
end

---Gathers again from scratch, as after a zone change or a zoom.
function Layer:Regather()
	self.gatheredAt = nil
	self:Update()
end

---@param events string[]
---@param handler fun(self: AUIWorldMapMinimap)
---@param active boolean
local function RegisterEvents(events, handler, active)
	for _, event in ipairs(events) do
		if active then
			AUI.Events:Register(event, Layer, handler)
		else
			AUI.Events:Unregister(event, Layer)
		end
	end
end

---Turns the layer on or off from the settings, and collects the markers again after a change.
---@param enabled boolean the markers are on
function Layer:Apply(enabled)
	local any = false

	for _, entry in ipairs(Markers.MINIMAP) do
		any = any or AUI.Profile:Get(Markers:MinimapPath(entry.key)) == true
	end

	local active = enabled and any and Markers:IsIndexed()

	if active ~= self.active then
		self.active = active
		RegisterEvents(MOVE_EVENTS, self.StartMoving, active)
		RegisterEvents(STOP_EVENTS, self.StopMoving, active)
		RegisterEvents(GATHER_EVENTS, self.Regather, active)
	end

	if self.ticker then
		self.ticker:Cancel()
		self.ticker = nil
	end

	if not active then
		if self.pool then
			self.pool:ReleaseAll()
		end

		self.pins, self.near, self.gatheredAt = {}, {}, nil

		return
	end

	self:Collect()
	self:Regather()

	if IsPlayerMoving() then
		self:StartMoving()
	end
end
