local AUI = select(2, ...)

local TEMPLATE = "AeonUIWorldMapPinTemplate"

---The markers' data provider on Blizzard's world map. Blizzard asks it to refresh on every showing and map change; it
---rebuilds its pins only when the map or a marker setting changed since it last drew them, and leaves zooming to the
---pins' own scaling.
---@class AUIWorldMapProvider : MapCanvasDataProviderMixin
---@field TEMPLATE string the pin template
---@field drawn string? the map and settings revision the pins were last drawn for
local Provider = CreateFromMixins(MapCanvasDataProviderMixin)
Provider.TEMPLATE = TEMPLATE
AUI.WorldMapProvider = Provider

function Provider:RemoveAllData()
	self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
	self.drawn = nil
end

function Provider:RefreshAllData()
	local map = self:GetMap()
	local mapID = map:GetMapID()
	local module = AUI.WorldMap
	local key = mapID and (mapID .. ":" .. module.revision)

	if key == self.drawn then
		return
	end

	map:RemoveAllPinsByTemplate(TEMPLATE)
	self.drawn = key

	if not mapID then
		return
	end

	for _, group in ipairs(module:Groups(mapID)) do
		map:AcquirePin(TEMPLATE, group, module.size * group.scale)
	end
end
