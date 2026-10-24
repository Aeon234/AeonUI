local AUI = select(2, ...)

---A marker pin on Blizzard's world map: one group of markers at one spot, drawn with its first category's icon at a
---constant size on screen whatever the map's zoom. Pooled by the map canvas per template.
---@class AeonUIWorldMapPinMixin
---@field group AUIWorldMapGroup? the markers the pin shows, while acquired
---@field passthroughSet boolean? the right button passes through to the map, so a right click still zooms out
AeonUIWorldMapPinMixin = CreateFromMixins(MapCanvasPinMixin)

local Pin = AeonUIWorldMapPinMixin

function Pin:OnLoad()
	self:UseFrameLevelType("PIN_FRAME_LEVEL_DUNGEON_ENTRANCE")
end

---@param group AUIWorldMapGroup
---@param size number the pin's size against its template: the markers' setting times the map type's size
function Pin:OnAcquired(group, size)
	self.group = group
	self.Icon:SetAtlas(group.category.atlas)
	self:SetScalingLimits(1, size, size)
	self:SetPosition(group.x, group.y)
	self:ApplyCurrentScale()
end

function Pin:OnReleased()
	MapCanvasPinMixin.OnReleased(self)
	self.group = nil
end

---Replaces Blizzard's call on every acquire, which reaches the protected `SetPassThroughButtons` and is blocked in
---combat: the passthrough is set once per pin, and a pin made in combat gets it when combat ends.
function Pin:CheckMouseButtonPassthrough()
	if self.passthroughSet then
		return
	end

	if InCombatLockdown() then
		AUI.WorldMap:DeferPassthrough()

		return
	end

	self:SetPassthrough()
end

---Lets the right button through to the map. Out of combat only.
function Pin:SetPassthrough()
	if not self.passthroughSet then
		self.passthroughSet = true
		self:SetPassThroughButtons("RightButton")
	end
end

function Pin:OnMouseEnter()
	local group = self.group

	if not group then
		return
	end

	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

	for index, marker in ipairs(group.markers) do
		if index == 1 then
			GameTooltip:SetText(AUI.WorldMap:MarkerName(marker))
		else
			GameTooltip:AddLine(AUI.WorldMap:MarkerName(marker), 1, 1, 1)
		end
	end

	GameTooltip:Show()
end

function Pin:OnMouseLeave()
	GameTooltip:Hide()
end
