local AUI = select(2, ...)

local L = AUI.L
local Markers = AUI.WorldMapMarkers

-- What each wing or entrance key in the marker data is called after the instance's name.
local WING_LABELS = {
	main = L["Main Entrance"],
	back = L["Back Entrance"],
	sewer = L["Sewer Tunnel"],
	gate = L["Main Gate"],
	service = L["Service Entrance"],
	north = L["North"],
	east = L["East"],
	west = L["West"],
	graveyard = L["Graveyard"],
	library = L["Library"],
	armory = L["Armory"],
	cathedral = L["Cathedral"],
	upper = L["Upper"],
	lower = L["Lower"],
}

-- How near a dungeon entrance Blizzard lists must be to a marker, in map fractions, to be taken as the same place.
local ENTRANCE_DISTANCE = 0.05
-- How near the user waypoint must be to a marker to count as set on it.
local WAYPOINT_DISTANCE = 0.005

---The World Map module: puts the markers on Blizzard's world map through a data provider, and takes the provider off
---again while the markers are switched off. Nothing of Blizzard's map is hooked or changed.
---@class AUIWorldMap
---@field active boolean the module started this session
---@field attached boolean the provider is on the world map
---@field revision integer counts the applied marker settings; the provider redraws when it changes
---@field size number the markers' size setting as a factor
---@field shown table<string, boolean> the categories turned on
---@field otherFaction boolean the other faction's markers show too
---@field faction string? the player's faction, read when the module starts
---@field race number? the player's race ID, read when the module starts
---@field class string? the player's class token, read when the module starts
---@field capitalsOnly boolean vendors and trainers show on capitals' maps only
---@field mapTypes table<number, integer|false> each map's `Enum.UIMapType`, false when the map is unknown
---@field rects table<string, number[]|false> where one map lies on another, false when it does not
---@field groups table<number, AUIWorldMapGroup[]> each map's pins for the current revision
---@field groupsRevision integer the revision `groups` was built for
---@field passthroughPending boolean pins made in combat wait for it to end to pass the right button through
---@field flashFrom number? after a transport click, the map it was clicked on: the pins leading back there flash
---@field journal table<AUIWorldMapMarker, number|false> each instance marker's journal instance, false when none
local WorldMap = {
	active = false,
	attached = false,
	revision = 0,
	size = 1,
	shown = {},
	otherFaction = false,
	capitalsOnly = true,
	mapTypes = {},
	rects = {},
	groups = {},
	groupsRevision = -1,
	passthroughPending = false,
	journal = {},
}
AUI.WorldMap = WorldMap

---@return boolean
function WorldMap:IsEnabled()
	return AUI.Profile:Get(Markers.ENABLED_PATH) == true
end

---@param mapID number
---@return integer? mapType
function WorldMap:MapType(mapID)
	local mapType = self.mapTypes[mapID]

	if mapType == nil then
		local info = C_Map.GetMapInfo(mapID)

		mapType = info and info.mapType or false
		self.mapTypes[mapID] = mapType
	end

	return mapType or nil
end

---@param from number
---@param to number
---@return number[]? rect where `from` lies on `to`, `{ minX, maxX, minY, maxY }`, cached; nil when it does not
function WorldMap:RectOn(from, to)
	local key = from .. ":" .. to
	local rect = self.rects[key]

	if rect == nil then
		local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(from, to)

		rect = (minX and maxX > minX and maxY > minY) and { minX, maxX, minY, maxY } or false
		self.rects[key] = rect
	end

	return rect or nil
end

---@param from number
---@param to number
---@return number? minX
---@return number? maxX
---@return number? minY
---@return number? maxY
function WorldMap:Rect(from, to)
	local rect = self:RectOn(from, to)

	if rect then
		return rect[1], rect[2], rect[3], rect[4]
	end
end

---Points each exit's arrow toward the zone it leads to, both zones placed on the shown zone's continent.
---@param mapID number the shown map
---@param groups AUIWorldMapGroup[]
function WorldMap:RotateExits(mapID, groups)
	local info = C_Map.GetMapInfo(mapID)
	local continent = info and info.parentMapID

	if not continent or continent == 0 then
		return
	end

	local zone = self:RectOn(mapID, continent)

	if not zone then
		return
	end

	for _, group in ipairs(groups) do
		local marker = group.markers[1]

		if group.category.exit and marker.to then
			local destination = self:RectOn(marker.to[1][1], continent)

			if destination then
				group.rotation = Markers:ExitRotation(group.x, group.y, zone, destination)
			end
		end
	end
end

---@param mapID number
---@return AUIWorldMapGroup[] groups the map's pins, worked out once per map and settings revision
function WorldMap:Groups(mapID)
	if self.groupsRevision ~= self.revision then
		self.groups = {}
		self.groupsRevision = self.revision
	end

	local groups = self.groups[mapID]

	if groups then
		return groups
	end

	local mapType = self:MapType(mapID)

	groups = mapType and Markers:Groups({
		mapID = mapID,
		mapType = mapType,
		shown = self.shown,
		faction = self.faction,
		otherFaction = self.otherFaction,
		race = self.race,
		class = self.class,
		capitalsOnly = self.capitalsOnly,
		rect = function(from)
			return WorldMap:Rect(from, mapID)
		end,
	}) or {}
	self:RotateExits(mapID, groups)
	self.groups[mapID] = groups

	return groups
end

---@param marker AUIWorldMapMarker
---@return string name the place's name in the client's language: an instance's own, with its wing; otherwise the
---English name's translation, or the category's kind
function WorldMap:MarkerName(marker)
	local name = marker.instance and GetRealZoneText(marker.instance)

	if not name or name == "" then
		local category = Markers.byKey[marker.category]

		name = L[marker.name or category.name or category.label]
	end

	if not name or name == "" then
		return UNKNOWN
	end

	local wing = marker.wing and WING_LABELS[marker.wing]

	return wing and ("%s (%s)"):format(name, wing) or name
end

---@param stop number[] `{ uiMapID, areaID? }`
---@return string name the stop's area, or else its map, in the client's language
function WorldMap:StopName(stop)
	local area = stop[2] and C_Map.GetAreaInfo(stop[2])

	if area and area ~= "" then
		return area
	end

	local info = C_Map.GetMapInfo(stop[1])

	return info and info.name or UNKNOWN
end

---The journal instance Blizzard lists for an instance marker's entrance: the entrance with the instance's name on the
---marker's map, or else the nearest one close enough. Worked out once per marker.
---@param marker AUIWorldMapMarker
---@return number? journalInstanceID
function WorldMap:JournalInstance(marker)
	local found = self.journal[marker]

	if found == nil then
		found = false

		local name = marker.instance and GetRealZoneText(marker.instance)
		local nearest = ENTRANCE_DISTANCE

		for _, entrance in ipairs(C_EncounterJournal.GetDungeonEntrancesForMap(marker.map) or {}) do
			local x, y = entrance.position:GetXY()
			local distance = math.max(math.abs(x - marker.x), math.abs(y - marker.y))

			if name and name ~= "" and entrance.name == name then
				found = entrance.journalInstanceID

				break
			elseif distance <= nearest then
				found, nearest = entrance.journalInstanceID, distance
			end
		end

		self.journal[marker] = found
	end

	return found or nil
end

---@return boolean available the client's journal can open
function WorldMap:CanOpenJournal()
	return EncounterJournal_LoadUI ~= nil and not GameRulesUtil.EJIsDisabled()
end

---@param journalInstanceID number
function WorldMap:OpenJournal(journalInstanceID)
	EncounterJournal_LoadUI()

	if EncounterJournal_OpenJournal then
		EncounterJournal_OpenJournal(nil, journalInstanceID)
	end
end

---@param marker AUIWorldMapMarker
---@return boolean set the user waypoint is on the marker
function WorldMap:HasWaypoint(marker)
	local point = C_Map.HasUserWaypoint() and C_Map.GetUserWaypoint()

	if not point or point.uiMapID ~= marker.map then
		return false
	end

	local x, y = point.position:GetXY()

	return math.abs(x - marker.x) <= WAYPOINT_DISTANCE and math.abs(y - marker.y) <= WAYPOINT_DISTANCE
end

---Sets the user waypoint on a marker and tracks it, or clears it when it is already there.
---@param marker AUIWorldMapMarker
function WorldMap:ToggleWaypoint(marker)
	if self:HasWaypoint(marker) then
		C_Map.ClearUserWaypoint()

		return
	end

	if C_Map.CanSetUserWaypointOnMap(marker.map) then
		C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(marker.map, marker.x, marker.y))
		C_SuperTrack.SetSuperTrackedUserWaypoint(true)
	end
end

---Shows a transport's destination on the map. The pins leading back to the map it was clicked on flash; a stop on the
---same map flashes its own pin.
---@param stop number[]
---@param from AeonUIWorldMapPinMixin the clicked pin
function WorldMap:Travel(stop, from)
	local here = WorldMapFrame:GetMapID()

	if stop[1] == here then
		AUI.WorldMapProvider:EachPin(function(pin)
			if pin ~= from and pin.group and Markers:LeadsTo(pin.group, here) then
				pin:Flash()
			end
		end)

		return
	end

	self.flashFrom = here
	WorldMapFrame:SetMapID(stop[1])
end

---Flashes the pins that lead back to the map a transport was clicked on, once the destination's pins are drawn.
function WorldMap:FlashReturn()
	local from = self.flashFrom

	if not from then
		return
	end

	self.flashFrom = nil
	AUI.WorldMapProvider:EachPin(function(pin)
		if pin.group and Markers:LeadsTo(pin.group, from) then
			pin:Flash()
		end
	end)
end

---@param pin AeonUIWorldMapPinMixin
---@param stops number[][]
function WorldMap:ChooseStop(pin, stops)
	MenuUtil.CreateContextMenu(pin, function(_, root)
		for _, stop in ipairs(stops) do
			root:CreateButton(WorldMap:StopName(stop), function()
				WorldMap:Travel(stop, pin)
			end)
		end
	end)
end

---Forgets the learned spots among a group's markers.
---@param group AUIWorldMapGroup
---@return boolean forgot the group held a learned spot
function WorldMap:ForgetLearned(group)
	if not Markers:HasLearned(group) then
		return false
	end

	for _, marker in ipairs(group.markers) do
		if marker.learned then
			AUI.WorldMapSpots:Forget(marker)
		end
	end

	GameTooltip:Hide()
	self:Redraw()

	return true
end

---A click on a pin: Shift toggles the waypoint on its first marker; a transport shows its first destination on the
---left button and its second on the right, or offers a menu for more; an instance opens its dungeon map, or else the
---journal; any other pin toggles the waypoint on the left button. A pin holding a learned spot keeps the right button:
---Ctrl forgets the spot, and otherwise it zooms out as the map would.
---@param pin AeonUIWorldMapPinMixin
---@param button string
function WorldMap:Click(pin, button)
	local group = pin.group --[[@as AUIWorldMapGroup]]
	local marker = group.markers[1]

	if IsShiftKeyDown() then
		self:ToggleWaypoint(marker)

		return
	end

	if group.category.transport then
		local stops = Markers:Destinations(group)

		if #stops > 2 then
			self:ChooseStop(pin, stops)
		elseif button == "RightButton" then
			if stops[2] then
				self:Travel(stops[2], pin)
			else
				WorldMapFrame:NavigateToParentMap()
			end
		elseif stops[1] then
			self:Travel(stops[1], pin)
		end

		return
	end

	if button == "RightButton" then
		if not (IsControlKeyDown() and self:ForgetLearned(group)) then
			WorldMapFrame:NavigateToParentMap()
		end

		return
	end

	if button ~= "LeftButton" then
		return
	end

	if not group.category.instance then
		self:ToggleWaypoint(marker)

		return
	end

	if AUI.WorldMapDungeon:CanOpen(marker.instance) then
		AUI.WorldMapDungeon:Open(marker.instance --[[@as number]], self:MarkerName(marker), marker.wing)

		return
	end

	local journal = self:CanOpenJournal() and self:JournalInstance(marker)

	if journal then
		self:OpenJournal(journal)
	end
end

---@param levels number[] `{ min, max }`
---@return table color the range's color against the player's level, as Blizzard's map labels color zones
function WorldMap:LevelColor(levels)
	local level = AUI:Readable(UnitLevel("player"), 0)

	if level < levels[1] then
		return GetQuestDifficultyColor(levels[1])
	elseif level > levels[2] then
		return GetQuestDifficultyColor(levels[2] - 2)
	end

	return QuestDifficultyColors.difficult
end

---Adds a line to `GameTooltip` in the level range's color. `QuestDifficultyColors` entries are plain `{ r, g, b }`
---tables, which `GameTooltip_AddColoredLine` cannot take.
---@param text string
---@param levels number[] `{ min, max }`
function WorldMap:AddLevelLine(text, levels)
	local color = self:LevelColor(levels)

	GameTooltip:AddLine(text, color.r, color.g, color.b, true)
end

---Adds one marker's lines: its name, kind, level range, faction and destinations.
---@param marker AUIWorldMapMarker
---@param first boolean the marker heads the tooltip
function WorldMap:AddMarkerLines(marker, first)
	local category = Markers.byKey[marker.category]
	local name = self:MarkerName(marker)

	if first then
		GameTooltip_SetTitle(GameTooltip, name)
	else
		GameTooltip_AddBlankLineToTooltip(GameTooltip)
		GameTooltip_AddNormalLine(GameTooltip, name)
	end

	-- A transport's name is its kind, as is an unnamed town marker's; a transport's destinations follow.
	local unnamed = not marker.name and not marker.instance and not category.name

	if not category.transport and not unnamed then
		local kind = marker.players and L["Raid, %d players"]:format(marker.players) or L[Markers:Label(marker)]

		GameTooltip_AddHighlightLine(GameTooltip, kind)
	end

	local levels = marker.levels

	if levels then
		local text = levels[1] == levels[2] and L["Level %d"]:format(levels[1])
			or L["Level %d-%d"]:format(levels[1], levels[2])

		self:AddLevelLine(text, levels)
	end

	if marker.faction then
		local alliance = marker.faction == "Alliance"

		GameTooltip_AddColoredLine(GameTooltip, alliance and FACTION_ALLIANCE or FACTION_HORDE,
			PLAYER_FACTION_COLORS[alliance and 1 or 0])
	end

	for _, stop in ipairs(marker.to or {}) do
		GameTooltip_AddHighlightLine(GameTooltip, L["To %s"]:format(self:StopName(stop)))
	end

	local racial = category.howTo and C_Spell.GetSpellName(category.racial --[[@as number]])

	if racial then
		GameTooltip_AddNormalLine(GameTooltip, L[category.howTo]:format(racial,
			C_Spell.GetSpellName(category.buff --[[@as number]]) or ""), true)
	end

	if marker.learned then
		GameTooltip_AddNormalLine(GameTooltip, L["Found by you"])
	end
end

---Adds what clicking the pin does.
---@param group AUIWorldMapGroup
function WorldMap:AddHints(group)
	local marker = group.markers[1]
	local hints = {}

	if group.category.transport then
		local stops = Markers:Destinations(group)

		if #stops > 2 then
			hints[#hints + 1] = L["Click: choose a destination"]
		else
			if stops[1] then
				hints[#hints + 1] = L["Left-click: show %s"]:format(self:StopName(stops[1]))
			end

			if stops[2] then
				hints[#hints + 1] = L["Right-click: show %s"]:format(self:StopName(stops[2]))
			end
		end
	elseif group.category.instance and AUI.WorldMapDungeon:CanOpen(marker.instance) then
		hints[#hints + 1] = L["Left-click: %s"]:format(L["Dungeon Map"])
	elseif group.category.instance and self:CanOpenJournal() and self:JournalInstance(marker) then
		hints[#hints + 1] = L["Left-click: %s"]:format(ENCOUNTER_JOURNAL)
	end

	if C_Map.CanSetUserWaypointOnMap(marker.map) then
		local set = self:HasWaypoint(marker)

		if group.category.transport or group.category.instance then
			hints[#hints + 1] = set and L["Shift-click: remove the waypoint"] or L["Shift-click: set a waypoint"]
		else
			hints[#hints + 1] = set and L["Left-click: remove the waypoint"] or L["Left-click: set a waypoint"]
		end
	end

	if Markers:HasLearned(group) then
		hints[#hints + 1] = L["Ctrl-right-click: forget this spot"]
	end

	if #hints > 0 then
		GameTooltip_AddBlankLineToTooltip(GameTooltip)
	end

	for _, hint in ipairs(hints) do
		GameTooltip_AddInstructionLine(GameTooltip, hint)
	end
end

---@param a Frame
---@param b Frame
---@return boolean touching the two pins overlap on screen
local function Touching(a, b)
	local ax, ay = a:GetCenter()
	local bx, by = b:GetCenter()

	if not (ax and ay and bx and by) then
		return false
	end

	local scaleA, scaleB = a:GetEffectiveScale(), b:GetEffectiveScale()
	local reach = (a:GetWidth() * scaleA + b:GetWidth() * scaleB) / 2

	return math.abs(ax * scaleA - bx * scaleB) < reach and math.abs(ay * scaleA - by * scaleB) < reach
end

---Shows the tooltip for a pin and every pin touching it on screen, with the hovered pin's click hints.
---@param pin AeonUIWorldMapPinMixin
function WorldMap:ShowTooltip(pin)
	local group = pin.group --[[@as AUIWorldMapGroup]]
	local first = true

	local function Add(shown)
		for _, marker in ipairs(shown.markers) do
			self:AddMarkerLines(marker, first)
			first = false
		end
	end

	GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
	Add(group)
	AUI.WorldMapProvider:EachPin(function(other)
		if other ~= pin and other.group and Touching(pin, other) then
			Add(other.group)
		end
	end)
	self:AddHints(group)
	GameTooltip:Show()
end

---Gives pins made in combat their right-button passthrough once combat ends.
function WorldMap:DeferPassthrough()
	if self.passthroughPending then
		return
	end

	self.passthroughPending = true
	AUI.Events:Register("PLAYER_REGEN_ENABLED", self, self.OnCombatEnded)
end

function WorldMap:OnCombatEnded()
	AUI.Events:Unregister("PLAYER_REGEN_ENABLED", self)
	self.passthroughPending = false

	AUI.WorldMapProvider:EachPin(function(pin)
		pin:SetPassthrough()
	end)
end

---Applies marker changes once per frame, however many arrive.
---@param path string?
function WorldMap:OnProfileChanged(path)
	if path ~= nil and path:sub(1, 9) ~= "worldMap." then
		return
	end

	AUI.Events:Coalesce("worldMapApply", function()
		WorldMap:Apply()
	end)
end

---Applies the World Map's settings: the markers, then the map options.
function WorldMap:Apply()
	self:ApplyMarkers()
	AUI.WorldMapUnexplored:Apply()
	AUI.WorldMapLevels:Apply()
	AUI.WorldMapDungeon:Apply()
end

---Reads the marker settings, then puts the provider on the map and redraws, or takes it off.
function WorldMap:ApplyMarkers()
	local Profile = AUI.Profile
	local provider = AUI.WorldMapProvider

	if not self:IsEnabled() then
		if self.attached then
			self.attached = false
			WorldMapFrame:RemoveDataProvider(provider)
		end

		AUI.WorldMapMinimap:Apply(false)
		AUI.WorldMapSpots:Apply(nil, self.shown)

		return
	end

	if not Markers:IsIndexed() then
		local rows = AUI.WorldMapData()

		for key, list in pairs(AUI.WorldMapTownData()) do
			rows[key] = list
		end

		Markers:Index(rows)
	end

	AUI.WorldMapSpots:Load()

	self.size = Profile:Get(Markers.SCALE_PATH) / 100
	self.otherFaction = Profile:Get(Markers.OTHER_FACTION_PATH) == true
	self.capitalsOnly = Profile:Get(Markers.CAPITALS_PATH) == true

	for _, category in ipairs(Markers.CATEGORIES) do
		self.shown[category.key] = Profile:Get(Markers:CategoryPath(category.key)) == true
	end

	self.revision = self.revision + 1

	if not self.attached then
		self.attached = true
		WorldMapFrame:AddDataProvider(provider)
	end

	if WorldMapFrame:IsShown() then
		provider:RefreshAllData()
	end

	AUI.WorldMapMinimap:Apply(true)
	AUI.WorldMapSpots:Apply(self.race, self.shown)
end

---Redraws the markers after the index changed outside a settings change.
function WorldMap:Redraw()
	self.revision = self.revision + 1

	if self.attached and WorldMapFrame:IsShown() then
		AUI.WorldMapProvider:RefreshAllData()
	end
end

---Starts the module at login on a client with marker data.
function WorldMap:Start()
	if self.active or not AUI.can.worldMapMarkers then
		return
	end

	self.active = true
	self.faction = AUI:Readable(UnitFactionGroup("player"))
	self.race = AUI:Readable(select(3, UnitRace("player")))
	self.class = AUI:Readable(select(2, UnitClass("player")))
	AUI.Callbacks:Register("Profile", self, self.OnProfileChanged)
	self:Apply()
end
