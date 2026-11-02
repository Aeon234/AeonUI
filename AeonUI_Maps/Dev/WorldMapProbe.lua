-- The W0 world map probe: reads what each client's world map already shows and tries the pin mechanism the World Map
-- module would use, so each open question can be answered in game. Development only; never packaged. Undo with /reload.
local AUI = select(2, ...)

local TEMPLATE = "AeonUIWorldMapProbePinTemplate"
local LIST_LIMIT = 12

-- Positions of the test pins, as fractions of the shown map.
local PIN_SPOTS = { { 0.45, 0.45 }, { 0.55, 0.45 }, { 0.5, 0.5 }, { 0.45, 0.55 }, { 0.55, 0.55 } }

-- Atlases `/aui dev worldmap atlases` reports: candidates for each marker category.
local CANDIDATE_ATLASES = {
	"Dungeon", "Raid", "vignettekillboss", "TaxiNode_Continent_Neutral", "FlightPath", "FlightMaster",
	"FlightMasterFerry", "Islands-AllianceBoat", "Islands-HordeBoat", "Vehicle-Air-Horde", "Vehicle-Air-Alliance",
	"vehicle-alliancecart", "MagePortalAlliance", "MagePortalHorde", "poi-hub", "poi-traveldirections-arrow",
	"worldquest-icon-dungeon", "worldquest-icon-raid", "Mailbox", "Innkeeper", "Banker", "Auctioneer", "Repair",
	"StableMaster", "Class", "Profession", "Reagents", "Food", "Ammunition", "poi-soulspiritghost",
	"house-reward-green-arrow-up", "Waypoint-MapPin-Tracked", "pvpqueue-sidebar-honorbar-background-alliance",
	"pvpqueue-sidebar-honorbar-background-horde", "QuestPortraitIcon-Alliance", "QuestPortraitIcon-Horde",
}

---@class AUIWorldMapProbe
---@field mode "off"|"plain"|"safe" the test pins: absent, with Blizzard's passthrough call, or with the no-op override
---@field provider table? the probe's data provider, added on first use
---@field counts table<string, integer> calls Blizzard made into the provider and its pins
---@field blocked string[] blocked or forbidden actions reported for this addon
---@field labelHooked boolean Blizzard's area label is hooked
---@field lastLabel string? the last area name the hook printed
---@field menuHooked boolean Blizzard's map filter menu is hooked
local Probe = {
	mode = "off",
	counts = {},
	blocked = {},
	labelHooked = false,
	menuHooked = false,
}
AUI.Dev.WorldMapProbe = Probe

---@param key string
function Probe:Count(key)
	self.counts[key] = (self.counts[key] or 0) + 1
end

---@return number? mapID the map the world map shows, or the player's map while it is closed
local function CurrentMap()
	if WorldMapFrame and WorldMapFrame:IsShown() then
		return WorldMapFrame:GetMapID()
	end

	return C_Map.GetBestMapForUnit("player")
end

---@param position table? a vector with GetXY
---@return string text the position as map percent
local function Spot(position)
	if not position then
		return "?"
	end

	local x, y = position:GetXY()

	return ("%.1f, %.1f"):format(x * 100, y * 100)
end

---@param title string
---@param list table?
---@param describe fun(entry: any): string
local function PrintList(title, list, describe)
	local entries = list or {}
	local count = #entries

	AUI:Print("%s: %d", title, count)

	for index = 1, math.min(count, LIST_LIMIT) do
		AUI:Print("  %s", describe(entries[index]))
	end

	if count > LIST_LIMIT then
		AUI:Print("  ... %d more", count - LIST_LIMIT)
	end
end

function Probe:Report()
	local version, build = GetBuildInfo()
	local mapID = CurrentMap()

	AUI:Print("world map probe: client %s.%s, map shown %s, pins %s", tostring(version), tostring(build),
		tostring(WorldMapFrame and WorldMapFrame:IsShown()), self.mode)

	if not mapID then
		AUI:Print("no map: open the world map or stand in a zone.")

		return
	end

	local info = C_Map.GetMapInfo(mapID)

	AUI:Print("map %d: %s, type %s, parent %s, art %s", mapID, info and info.name or "?",
		tostring(info and info.mapType), tostring(info and info.parentMapID), tostring(C_Map.GetMapArtID(mapID)))
	AUI:Print("showDungeonEntrancesOnMap %s, taxi nodes shown here %s, waypoint allowed %s, UiMapPoint %s",
		tostring(C_CVar.GetCVar("showDungeonEntrancesOnMap")), tostring(C_TaxiMap.ShouldMapShowTaxiNodes(mapID)),
		tostring(C_Map.CanSetUserWaypointOnMap(mapID)), tostring(UiMapPoint ~= nil))

	PrintList("dungeon entrances", C_EncounterJournal.GetDungeonEntrancesForMap(mapID), function(entry)
		return ("%s at %s, atlas %s, journal %s"):format(tostring(entry.name), Spot(entry.position),
			tostring(entry.atlasName), tostring(entry.journalInstanceID))
	end)

	PrintList("taxi nodes", C_TaxiMap.GetTaxiNodesForMap(mapID), function(entry)
		return ("%s at %s, state %s, kit %s, special %s"):format(tostring(entry.name), Spot(entry.position),
			tostring(entry.state), tostring(entry.textureKit), tostring(entry.useSpecialIcon))
	end)

	PrintList("area POIs", C_AreaPoiInfo.GetAreaPOIForMap(mapID), function(poiID)
		local poi = C_AreaPoiInfo.GetAreaPOIInfo(mapID, poiID)

		return ("%d %s at %s, atlas %s, links %s"):format(poiID, tostring(poi and poi.name),
			Spot(poi and poi.position), tostring(poi and poi.atlasName), tostring(poi and poi.linkedUiMapID))
	end)

	PrintList("explored areas", C_MapExplorationInfo.GetExploredMapTextures(mapID), function(entry)
		local files = entry.fileDataIDs or {}

		return ("%d x %d at %d, %d, %d files, first %s"):format(entry.textureWidth, entry.textureHeight,
			entry.offsetX, entry.offsetY, #files, tostring(files[1]))
	end)

	local low, high = C_Map.GetMapLevels(mapID)

	AUI:Print("levels: %s-%s", tostring(low), tostring(high))

	PrintList("child maps with levels", C_Map.GetMapChildrenInfo(mapID), function(child)
		local childLow, childHigh = C_Map.GetMapLevels(child.mapID)

		return ("%d %s, type %s, levels %s-%s"):format(child.mapID, tostring(child.name), tostring(child.mapType),
			tostring(childLow), tostring(childHigh))
	end)

	local _, raceFile, raceID = UnitRace("player")
	local gamepad = InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled()

	AUI:Print("race %s (%s), journal disabled %s, journal instance here %s, gamepad UI %s", tostring(raceFile),
		tostring(raceID), tostring(GameRulesUtil.EJIsDisabled()),
		tostring(C_EncounterJournal.GetInstanceForGameMap(mapID)), tostring(gamepad))

	local names = {}

	for name in pairs(self.counts) do
		names[#names + 1] = name
	end

	table.sort(names)

	for _, name in ipairs(names) do
		AUI:Print("  Blizzard called %s: %d", name, self.counts[name])
	end

	for _, line in ipairs(self.blocked) do
		AUI:Print("  |cffff4040blocked|r %s", line)
	end
end

---@class AeonUIWorldMapProbePinMixin
---@field index integer the pin's slot in PIN_SPOTS
---@field passthroughSet boolean? the right-button passthrough was set out of combat
AeonUIWorldMapProbePinMixin = CreateFromMixins(MapCanvasPinMixin)

local Pin = AeonUIWorldMapProbePinMixin

function Pin:OnLoad()
	self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
	self:SetSize(24, 24)
	self.Icon:SetAtlas("Dungeon")
end

---@param index integer
function Pin:OnAcquired(index)
	Probe:Count("OnAcquired")
	self.index = index
	self:SetPosition(PIN_SPOTS[index][1], PIN_SPOTS[index][2])
end

---With mode "safe", replaces Blizzard's per-acquire passthrough call, which reaches the protected
---`SetPassThroughButtons`, by one call per pin made out of combat.
function Pin:CheckMouseButtonPassthrough(...)
	if Probe.mode ~= "safe" then
		MapCanvasPinMixin.CheckMouseButtonPassthrough(self, ...)

		return
	end

	if not self.passthroughSet and not InCombatLockdown() then
		self.passthroughSet = true
		self:SetPassThroughButtons("RightButton")
	end
end

function Pin:OnMouseEnter()
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetText(("AeonUI probe pin %d (%s)"):format(self.index, Probe.mode))
	GameTooltip:AddLine(("combat %s, passthrough set %s"):format(tostring(InCombatLockdown()),
		tostring(self.passthroughSet or false)), 1, 1, 1)
	GameTooltip:Show()
end

function Pin:OnMouseLeave()
	GameTooltip:Hide()
end

---@param button string
function Pin:OnMouseClickAction(button)
	AUI:Print("probe pin %d clicked with %s", self.index, button)
end

local Provider = CreateFromMixins(MapCanvasDataProviderMixin)

function Provider:RemoveAllData()
	self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
end

function Provider:RefreshAllData()
	Probe:Count("RefreshAllData")
	self:RemoveAllData()

	if Probe.mode == "off" then
		return
	end

	for index = 1, #PIN_SPOTS do
		self:GetMap():AcquirePin(TEMPLATE, index)
	end
end

function Provider:OnMapChanged()
	Probe:Count("OnMapChanged")
	self:RefreshAllData()
end

function Provider:OnCanvasScaleChanged()
	Probe:Count("OnCanvasScaleChanged")
end

---@return table provider the probe's data provider, added to the world map on first use
function Probe:Provider()
	if self.provider then
		return self.provider
	end

	local provider = Provider

	WorldMapFrame:AddDataProvider(provider)

	AUI.Events:Register("ADDON_ACTION_BLOCKED", self, self.OnBlocked)
	AUI.Events:Register("ADDON_ACTION_FORBIDDEN", self, self.OnBlocked)

	self.provider = provider

	return provider
end

---@param event string
---@param addon string
---@param action string
function Probe:OnBlocked(event, addon, action)
	if addon == AUI.name then
		local line = ("%s %s (combat %s)"):format(event, tostring(action), tostring(InCombatLockdown()))

		self.blocked[#self.blocked + 1] = line
		AUI:Print("|cffff4040%s|r", line)
	end
end

---@param mode "off"|"plain"|"safe"
function Probe:SetPins(mode)
	self.mode = mode
	self:Provider():RefreshAllData()
	AUI:Print("probe pins %s, combat %s; open the map to see them", mode, tostring(InCombatLockdown()))
end

---@param clear boolean
function Probe:Waypoint(clear)
	if clear then
		C_Map.ClearUserWaypoint()
		AUI:Print("user waypoint cleared")

		return
	end

	local mapID = CurrentMap()

	if not mapID or not C_Map.CanSetUserWaypointOnMap(mapID) then
		AUI:Print("waypoint: map %s does not take a user waypoint", tostring(mapID))

		return
	end

	C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, 0.5, 0.5))
	C_SuperTrack.SetSuperTrackedUserWaypoint(true)
	AUI:Print("waypoint: set at the middle of map %d", mapID)
end

---@param journalInstanceID number?
function Probe:Journal(journalInstanceID)
	if not journalInstanceID then
		AUI:Print("usage: /aui dev worldmap journal <journalInstanceID>, as the report's entrances list it")

		return
	end

	if GameRulesUtil.EJIsDisabled() then
		AUI:Print("journal: disabled by this client's game rules")

		return
	end

	EncounterJournal_LoadUI()
	EncounterJournal_OpenJournal(nil, journalInstanceID)
	AUI:Print("journal: asked to open instance %d", journalInstanceID)
end

---Prints each new area name Blizzard's hover label shows, to see what it already adds (such as level ranges).
function Probe:HookLabel()
	if self.labelHooked then
		AUI:Print("label: already hooked")

		return
	end

	for provider in pairs(WorldMapFrame.dataProviders) do
		local label = provider.Label

		if label and label.SetLabel then
			hooksecurefunc(label, "SetLabel", function(_, _, name)
				if name and name ~= Probe.lastLabel then
					Probe.lastLabel = name
					AUI:Print("label: %s", name:gsub("|", "||"))
				end
			end)

			self.labelHooked = true
			AUI:Print("label: hooked; hover areas on the map")

			return
		end
	end

	AUI:Print("label: no area label provider found")
end

---Adds a title to Blizzard's map filter menu and reports when the menu opens.
function Probe:HookMenu()
	if self.menuHooked then
		AUI:Print("menu: already hooked")

		return
	end

	self.menuHooked = true

	Menu.ModifyMenu("MENU_WORLD_MAP_TRACKING", function(_, rootDescription)
		rootDescription:CreateTitle("AeonUI probe")
		AUI:Print("menu: the map filter menu opened, combat %s", tostring(InCombatLockdown()))
	end)

	AUI:Print("menu: hooked; open the map's filter menu")
end

local HELP = "world map probe: report, pins <plain|safe|off>, waypoint [clear], journal <id>, label, menu, atlases; "
	.. "/reload undoes it"

---@param line string
function Probe:Command(line)
	local command, value = line:match("^(%S*)%s*(%S*)")

	if command == "report" then
		self:Report()
	elseif command == "pins" and (value == "plain" or value == "safe" or value == "off") then
		self:SetPins(value)
	elseif command == "waypoint" then
		self:Waypoint(value == "clear")
	elseif command == "journal" then
		self:Journal(tonumber(value))
	elseif command == "label" then
		self:HookLabel()
	elseif command == "menu" then
		self:HookMenu()
	elseif command == "atlases" then
		AUI.Dev:Atlases(table.concat(CANDIDATE_ATLASES, " "))
	else
		AUI:Print(HELP)
	end
end
