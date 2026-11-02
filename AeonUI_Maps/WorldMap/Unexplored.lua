local AUI = select(2, ...)

local Options = AUI.WorldMapOptions

local TEMPLATE = "AeonUIWorldMapUnexploredPinTemplate"

---The one pin drawing a map's unexplored areas: the area art, desaturated and darkened, across the whole map. It takes
---no mouse input.
---@class AeonUIWorldMapUnexploredPinMixin
---@field textures table the pin's texture pool, made when first acquired
AeonUIWorldMapUnexploredPinMixin = CreateFromMixins(MapCanvasPinMixin)

local Pin = AeonUIWorldMapUnexploredPinMixin

function Pin:OnAcquired()
	if not self.textures then
		self:SetIgnoreGlobalPinScale(true)
		self:UseFrameLevelType("PIN_FRAME_LEVEL_MAP_EXPLORATION")
		self.textures = CreateTexturePool(self, "ARTWORK", 0)
	end
end

-- The pin never takes the mouse; this keeps the protected passthrough call out of AcquirePin.
function Pin:CheckMouseButtonPassthrough() end

function Pin:OnCanvasSizeChanged()
	local map = self:GetMap()

	if map then
		self:SetSize(map:DenormalizeHorizontalSize(1), map:DenormalizeVerticalSize(1))
	end
end

function Pin:Clear()
	self.textures:ReleaseAll()
end

---@param areas number[][] the areas to draw
---@param tileWidth number the map art's tile size
---@param tileHeight number
---@param shade number the textures' brightness, 0 to 1
function Pin:Draw(areas, tileWidth, tileHeight, shade)
	self:Clear()
	self:OnCanvasSizeChanged()

	for _, area in ipairs(areas) do
		for _, tile in ipairs(Options:Tiles(area, tileWidth, tileHeight)) do
			local texture = self.textures:Acquire()

			texture:SetSize(tile.width, tile.height)
			texture:SetTexCoord(0, tile.right, 0, tile.bottom)
			texture:SetPoint("TOPLEFT", tile.x, -tile.y)
			texture:SetTexture(tile.file, nil, nil, "TRILINEAR")
			texture:SetDesaturated(true)
			texture:SetVertexColor(shade, shade, shade)
			texture:Show()
		end
	end
end

---The unexplored areas' data provider on Blizzard's world map, on the map only while the option is on. It redraws on
---every showing, map change and exploration while the map is open; the areas are not passed to the canvas's maskable
---textures, which Blizzard's secure code walks.
---@class AUIWorldMapUnexplored : MapCanvasDataProviderMixin
---@field attached boolean the provider is on the world map
---@field shade number the areas' brightness from the darkness setting
---@field data table<number, number[][]>? each map art's area rows, loaded on first use
---@field pin AeonUIWorldMapUnexploredPinMixin? the pin, while the provider is on the map
local Unexplored = CreateFromMixins(MapCanvasDataProviderMixin)
Unexplored.attached = false
Unexplored.shade = 0.5
AUI.WorldMapUnexplored = Unexplored

---@param map table
function Unexplored:OnAdded(map)
	MapCanvasDataProviderMixin.OnAdded(self, map)
	local pin = map:AcquirePin(TEMPLATE)

	pin:SetPosition(0.5, 0.5)
	self.pin = pin
end

---@param map table
function Unexplored:OnRemoved(map)
	map:RemoveAllPinsByTemplate(TEMPLATE)
	self.pin = nil
	MapCanvasDataProviderMixin.OnRemoved(self, map)
end

function Unexplored:OnShow()
	AUI.Events:Register("MAP_EXPLORATION_UPDATED", self, self.RefreshAllData)
end

function Unexplored:OnHide()
	AUI.Events:Unregister("MAP_EXPLORATION_UPDATED", self)
end

function Unexplored:RemoveAllData()
	if self.pin then
		self.pin:Clear()
	end
end

function Unexplored:OnGlobalAlphaChanged()
	if self.pin then
		self.pin:SetAlpha(self:GetMap():GetGlobalAlpha())
	end
end

---@param mapID number
---@return number[][]? areas the map's areas the player has not explored, nil when there is no data for its art
function Unexplored:Areas(mapID)
	self.data = self.data or AUI.WorldMapExplorationData()

	local art = C_Map.GetMapArtID(mapID)
	local areas = art and self.data[art]

	if not areas then
		return nil
	end

	local explored = {}

	for _, info in ipairs(C_MapExplorationInfo.GetExploredMapTextures(mapID) or {}) do
		local file = info.fileDataIDs[1]

		if file then
			explored[file] = true
		end
	end

	return Options:Unexplored(areas, explored)
end

function Unexplored:RefreshAllData()
	local pin = self.pin

	if not pin then
		return
	end

	local map = self:GetMap()
	local mapID = map:GetMapID()
	local areas = mapID and self:Areas(mapID)
	local layers = areas and C_Map.GetMapArtLayers(mapID)
	local layer = layers and layers[1]

	if not layer then
		pin:Clear()

		return
	end

	pin:Draw(areas, layer.tileWidth, layer.tileHeight, self.shade)
	pin:SetAlpha(map:GetGlobalAlpha())
end

---Reads the option and its darkness, then puts the provider on the map and redraws, or takes it off.
function Unexplored:Apply()
	local Profile = AUI.Profile
	local enabled = Profile:Get(Options.UNEXPLORED_PATH) == true

	self.shade = 1 - Profile:Get(Options.DARKNESS_PATH) / 100

	if enabled ~= self.attached then
		self.attached = enabled

		if enabled then
			WorldMapFrame:AddDataProvider(self)

			if WorldMapFrame:IsShown() then
				self:OnShow()
			end
		else
			self:OnHide()
			WorldMapFrame:RemoveDataProvider(self)
		end
	end

	if enabled and WorldMapFrame:IsShown() then
		self:RefreshAllData()
	end
end
