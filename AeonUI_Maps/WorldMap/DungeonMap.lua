local AUI = select(2, ...)

local L = AUI.L
local Dungeons, Options = AUI.WorldMapDungeons, AUI.WorldMapOptions

-- A pin's size at the art's own scale, and its bounds on screen.
local PIN_SIZE, MIN_PIN, MAX_PIN = 24, 14, 32
local BOSS_ATLAS = "vignettekillboss"
local WAY_ATLAS = "poi-traveldirections-arrow"
local ENTRANCE_ATLAS = "Dungeon"
local EDGE = 10
-- How far above the map canvas's topmost pins the dungeon map sits.
local ABOVE_PINS = 10

---@class AUIDungeonMapPin: Button
---@field icon Texture
---@field pin AUIDungeonPin? what the pin shows, while acquired

---@class AUIDungeonMapFrame: Frame
---@field title FontString the instance's name
---@field hint FontString how to go back
---@field floors DropdownButton the floor menu, shown for more than one floor

---The dungeon map: the client's own floor art for an instance over Blizzard's world map, with its floors, bosses,
---ways between floors and entrance. It opens from a dungeon or raid marker, or as the map opens inside an instance
---Blizzard does not map; a right click, a map change or closing the map takes it away. Floors whose art the client
---lacks are left out, and an instance with none has no dungeon map. A map canvas data provider tells it when the map
---shows, hides and changes; nothing of Blizzard's map is hooked.
---@class AUIWorldMapDungeon : MapCanvasDataProviderMixin
---@field attached boolean the provider is on the world map
---@field markers boolean markers open dungeon maps
---@field instances boolean the map opens on one inside an instance
---@field data table<number, AUIDungeonMap>? each instance's map, loaded on first use
---@field available table<number, number[]|false> each instance's floors with art, false when none
---@field frame AUIDungeonMapFrame? the dungeon map, made on first use
---@field probe Texture? tests whether the client has a floor's art
---@field tiles Texture[] its tiles
---@field pool table? its pins
---@field map AUIDungeonMap? the instance shown
---@field floors number[] its floors with art
---@field floor integer the shown floor's place in `floors`
---@field mapID number? the world map's map when it opened; another map closes it
local Dungeon = CreateFromMixins(MapCanvasDataProviderMixin)
Dungeon.attached = false
Dungeon.markers = false
Dungeon.instances = false
Dungeon.available = {}
Dungeon.tiles = {}
Dungeon.floors = {}
Dungeon.floor = 1
AUI.WorldMapDungeon = Dungeon

---@param instanceID number
---@return AUIDungeonMap? map
---@return number[]? floors the floors whose art the client has, nil when it has none
function Dungeon:Find(instanceID)
	self.data = self.data or AUI.WorldMapDungeonData()

	local map = self.data[instanceID]

	if not map then
		return nil
	end

	local floors = self.available[instanceID]

	if floors == nil then
		local probe = self.probe or UIParent:CreateTexture()

		probe:Hide()
		self.probe = probe
		floors = {}

		for _, floor in ipairs(map.floors) do
			probe:SetTexture(Dungeons:TilePath(map, floor, 1))

			local file = probe:GetTextureFileID()

			if file and file > 0 then
				floors[#floors + 1] = floor
			end
		end

		floors = #floors > 0 and floors or false
		self.available[instanceID] = floors
	end

	return map, floors or nil
end

---@param instanceID number?
---@return boolean has the instance has a dungeon map a marker may open
function Dungeon:CanOpen(instanceID)
	return self.markers and instanceID ~= nil and select(2, self:Find(instanceID)) ~= nil
end

---@param map AUIDungeonMap
---@param floor number
---@param index integer the floor's place among those shown
---@return string name the floor's name in the client's language, or its place
local function FloorName(map, floor, index)
	local name = _G[Dungeons:FloorKey(map, floor)]

	return type(name) == "string" and name ~= "" and name or L["Floor %d"]:format(index)
end

---@param pin AUIDungeonMapPin
local function OnPinEnter(pin)
	local shown = pin.pin

	if not shown then
		return
	end

	GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")

	if shown.bosses then
		for index, boss in ipairs(shown.bosses) do
			if index == 1 then
				GameTooltip_SetTitle(GameTooltip, boss.boss)
			else
				GameTooltip_AddBlankLineToTooltip(GameTooltip)
				GameTooltip_AddNormalLine(GameTooltip, boss.boss)
			end

			if boss.title then
				GameTooltip_AddHighlightLine(GameTooltip, "<" .. boss.title .. ">")
			end

			if boss.level then
				GameTooltip_AddColoredLine(GameTooltip, L["Level %d"]:format(boss.level),
					AUI.WorldMap:LevelColor({ boss.level, boss.level }))
			end

			if boss.optional then
				GameTooltip_AddHighlightLine(GameTooltip, L["Optional"])
			end
		end
	elseif shown.floor then
		local map = Dungeon.map --[[@as AUIDungeonMap]]
		local index = Dungeons:FloorIndex(Dungeon.floors, shown.floor) or 1
		local name = FloorName(map, shown.floor, index)

		GameTooltip_SetTitle(GameTooltip, (shown.up and L["Up to %s"] or L["Down to %s"]):format(name))
		GameTooltip_AddInstructionLine(GameTooltip, L["Left-click: show %s"]:format(name))
	else
		GameTooltip_SetTitle(GameTooltip, L["Entrance"])
	end

	GameTooltip:Show()
end

---@param pin AUIDungeonMapPin
---@param button string
local function OnPinClick(pin, button)
	local shown = pin.pin

	if button == "RightButton" then
		Dungeon:Close()
	elseif shown and shown.floor then
		GameTooltip:Hide()
		Dungeon:SetFloor(Dungeons:FloorIndex(Dungeon.floors, shown.floor) or Dungeon.floor)
	end
end

---@param _ table
---@param pin AUIDungeonMapPin
local function ResetPin(_, pin)
	pin:Hide()
	pin:ClearAllPoints()
	pin.pin = nil
end

---@param pin AUIDungeonMapPin
local function InitPin(pin)
	pin.icon = pin:CreateTexture(nil, "ARTWORK")
	pin.icon:SetAllPoints()
	pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	pin:SetScript("OnEnter", OnPinEnter)
	pin:SetScript("OnLeave", GameTooltip_Hide)
	pin:SetScript("OnClick", OnPinClick)
end

---@param _ Frame
---@param button string
local function OnFrameMouseUp(_, button)
	if button == "RightButton" then
		Dungeon:Close()
	end
end

---@return AUIDungeonMapFrame frame the dungeon map, made on first use and hidden
function Dungeon:Frame()
	local frame = self.frame

	if frame then
		return frame
	end

	local picture = WorldMapFrame.ScrollContainer

	frame = CreateFrame("Frame", "AeonUIDungeonMap", WorldMapFrame) --[[@as AUIDungeonMapFrame]]
	frame:SetAllPoints(picture)
	frame:SetFrameLevel(WorldMapFrame:GetPinFrameLevelsManager():GetValidFrameLevel("PIN_FRAME_LEVEL_TOPMOST")
		+ ABOVE_PINS)
	frame:EnableMouse(true)
	frame:EnableMouseWheel(true)
	frame:SetScript("OnMouseWheel", function() end)
	frame:SetScript("OnMouseUp", OnFrameMouseUp)
	frame:SetScript("OnSizeChanged", function()
		Dungeon:Layout()
	end)
	frame:Hide()

	local background = frame:CreateTexture(nil, "BACKGROUND")

	background:SetAllPoints()
	background:SetColorTexture(0, 0, 0, 1)

	for index = 1, Dungeons.TILES do
		self.tiles[index] = frame:CreateTexture(nil, "ARTWORK")
	end

	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	frame.title:SetPoint("TOP", 0, -EDGE)

	frame.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.hint:SetPoint("BOTTOMRIGHT", -EDGE, EDGE)
	frame.hint:SetText(L["Right-click: back to the map"])

	frame.floors = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
	frame.floors:SetPoint("TOPLEFT", EDGE, -EDGE)
	frame.floors:SetWidth(180)

	self.pool = CreateFramePool("Button", frame, nil, ResetPin, false, InitPin)
	self.frame = frame

	return frame
end

---Places the tiles and pins to fill the frame, keeping the picture's shape.
function Dungeon:Layout()
	local frame, pool = self.frame, self.pool

	if not frame or not pool or not self.map then
		return
	end

	local width, height = frame:GetSize()

	if width <= 1 or height <= 1 then
		return
	end

	local scale, left, top = Dungeons:Fit(width, height)

	for index, texture in ipairs(self.tiles) do
		local tile = Dungeons:Tile(index)

		texture:ClearAllPoints()
		texture:SetPoint("TOPLEFT", left + tile.x * scale, -(top + tile.y * scale))
		texture:SetSize(tile.width * scale, tile.height * scale)
		texture:SetTexCoord(0, tile.right, 0, tile.bottom)
	end

	local size = math.max(MIN_PIN, math.min(MAX_PIN, PIN_SIZE * scale))

	for pin in pool:EnumerateActive() do
		local shown = pin.pin --[[@as AUIDungeonPin]]

		pin:SetSize(size, size)
		pin:ClearAllPoints()
		pin:SetPoint("CENTER", frame, "TOPLEFT", left + shown.x * Dungeons.WIDTH * scale,
			-(top + shown.y * Dungeons.HEIGHT * scale))
	end
end

---Shows another floor: its art, its pins and its name in the floor menu.
---@param index integer the floor's place in `floors`
function Dungeon:SetFloor(index)
	local map, frame, pool = self.map, self.frame, self.pool

	if not map or not frame or not pool then
		return
	end

	index = math.max(1, math.min(index, #self.floors))
	self.floor = index

	local floor = self.floors[index]

	for tile, texture in ipairs(self.tiles) do
		texture:SetTexture(Dungeons:TilePath(map, floor, tile))
	end

	pool:ReleaseAll()

	for _, shown in ipairs(Dungeons:Pins(map, floor, self.floors)) do
		local pin = pool:Acquire() --[[@as AUIDungeonMapPin]]

		pin.pin = shown
		pin.icon:SetAtlas(shown.bosses and BOSS_ATLAS or shown.floor and WAY_ATLAS or ENTRANCE_ATLAS)
		pin.icon:SetRotation(shown.floor and not shown.up and math.pi or 0)
		pin:SetFrameLevel(frame:GetFrameLevel() + 2)
		pin:Show()
	end

	frame.floors:GenerateMenu()
	self:Layout()
end

---@param instanceID number
---@param name string the instance's name for the title
---@param wing string? the wing of the marker it opens from
---@return boolean opened the instance has a dungeon map
function Dungeon:Open(instanceID, name, wing)
	local map, floors = self:Find(instanceID)

	if not map or not floors then
		return false
	end

	local frame = self:Frame()

	self.map, self.floors = map, floors
	self.mapID = WorldMapFrame:GetMapID()
	frame.title:SetText(name)
	frame.floors:SetShown(#floors > 1)
	frame.floors:SetupMenu(function(_, root)
		for index, floor in ipairs(Dungeon.floors) do
			root:CreateRadio(FloorName(map, floor, index), function()
				return Dungeon.floor == index
			end, function()
				Dungeon:SetFloor(index)
			end)
		end
	end)
	frame:Show()
	self:SetFloor(Dungeons:StartFloor(map, floors, wing))

	return true
end

function Dungeon:Close()
	if self.frame then
		self.frame:Hide()
	end

	if self.pool then
		self.pool:ReleaseAll()
	end

	self.map, self.mapID = nil, nil
end

---@return boolean shown the dungeon map is open
function Dungeon:IsShown()
	return self.frame ~= nil and self.frame:IsShown()
end

---Opens the instance's dungeon map as the world map opens inside it, unless Blizzard maps the instance itself.
function Dungeon:OnShow()
	if not self.instances or not IsInInstance() then
		return
	end

	local name, kind, _, _, _, _, _, instanceID = GetInstanceInfo()

	if kind ~= "party" and kind ~= "raid" then
		return
	end

	local best = C_Map.GetBestMapForUnit("player")

	if best and AUI.WorldMap:MapType(best) == Enum.UIMapType.Dungeon then
		return
	end

	self:Open(instanceID, name)
end

function Dungeon:OnHide()
	self:Close()
end

function Dungeon:OnMapChanged()
	if self:IsShown() and WorldMapFrame:GetMapID() ~= self.mapID then
		self:Close()
	end
end

function Dungeon:RemoveAllData() end

function Dungeon:RefreshAllData() end

---Reads the dungeon map options, putting the provider on the map while either is on.
function Dungeon:Apply()
	local Profile = AUI.Profile
	local enabled

	self.markers = Profile:Get(Options.DUNGEON_MARKERS_PATH) == true
	self.instances = Profile:Get(Options.DUNGEON_INSTANCES_PATH) == true
	enabled = self.markers or self.instances

	if enabled ~= self.attached then
		self.attached = enabled

		if enabled then
			WorldMapFrame:AddDataProvider(self)
		else
			self:Close()
			WorldMapFrame:RemoveDataProvider(self)
		end
	end
end
