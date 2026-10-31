local AUI = select(2, ...)

local TEMPLATE = "AeonUIWorldMapPinTemplate"
local TRANSPORT_TEMPLATE = "AeonUIWorldMapTransportPinTemplate"
local LEARNED_TEMPLATE = "AeonUIWorldMapLearnedPinTemplate"

---The markers' data provider on Blizzard's world map. Blizzard asks it to refresh on every showing and map change; it
---rebuilds its pins only when the map or a marker setting changed since it last drew them, and leaves zooming to the
---pins' own scaling.
---@class AUIWorldMapProvider : MapCanvasDataProviderMixin
---@field TEMPLATES string[] the pin templates
---@field drawn string? the map and settings revision the pins were last drawn for
local Provider = CreateFromMixins(MapCanvasDataProviderMixin)
Provider.TEMPLATES = { TEMPLATE, TRANSPORT_TEMPLATE, LEARNED_TEMPLATE }
AUI.WorldMapProvider = Provider

function Provider:RemoveAllData()
	local map = self:GetMap()

	for _, template in ipairs(self.TEMPLATES) do
		map:RemoveAllPinsByTemplate(template)
	end

	self.drawn = nil
end

---Calls `work` with each of the provider's pins on the map.
---@param work fun(pin: AeonUIWorldMapPinMixin)
function Provider:EachPin(work)
	local map = self:GetMap()

	for _, template in ipairs(self.TEMPLATES) do
		for pin in map:EnumeratePinsByTemplate(template) do
			work(pin)
		end
	end
end

function Provider:RefreshAllData()
	local map = self:GetMap()
	local mapID = map:GetMapID()
	local module = AUI.WorldMap
	local key = mapID and (mapID .. ":" .. module.revision)

	if key == self.drawn then
		return
	end

	self:RemoveAllData()
	self.drawn = key

	if not mapID then
		return
	end

	local Markers = AUI.WorldMapMarkers

	for _, group in ipairs(module:Groups(mapID)) do
		local template = group.category.transport and TRANSPORT_TEMPLATE
			or Markers:HasLearned(group) and LEARNED_TEMPLATE or TEMPLATE

		map:AcquirePin(template, group, module.size * group.scale)
	end

	module:FlashReturn()
end
