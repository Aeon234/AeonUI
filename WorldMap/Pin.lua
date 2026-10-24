local AUI = select(2, ...)

---A marker pin on Blizzard's world map: one group of markers at one spot, drawn with its first category's icon at a
---constant size on screen whatever the map's zoom. Pooled by the map canvas per template: the plain template passes
---the right button through to the map, so a right click zooms out; the transport template keeps it for a second
---destination.
---@class AeonUIWorldMapPinMixin
---@field Icon Texture
---@field Pulse AnimationGroup draws the eye to the pin after a transport click
---@field handlesRightButton boolean? set by the transport template
---@field group AUIWorldMapGroup? the markers the pin shows, while acquired
---@field passthroughSet boolean? the right button passes through to the map
AeonUIWorldMapPinMixin = CreateFromMixins(MapCanvasPinMixin)

local Pin = AeonUIWorldMapPinMixin

function Pin:OnLoad()
	self:UseFrameLevelType("PIN_FRAME_LEVEL_DUNGEON_ENTRANCE")
end

---@param group AUIWorldMapGroup
---@param size number the pin's size against its template: the markers' setting times the map type's size
function Pin:OnAcquired(group, size)
	self.group = group

	local atlas, file = AUI.WorldMapMarkers:Icon(group)

	if atlas then
		self.Icon:SetAtlas(atlas)
	else
		self.Icon:SetTexture(file)
		self.Icon:SetTexCoord(0, 1, 0, 1)
	end

	self:SetScalingLimits(1, size, size)
	self:SetPosition(group.x, group.y)
	self:ApplyCurrentScale()
end

function Pin:OnReleased()
	MapCanvasPinMixin.OnReleased(self)
	self.Pulse:Stop()
	self.group = nil
end

---Replaces Blizzard's call on every acquire, which reaches the protected `SetPassThroughButtons` and is blocked in
---combat: the passthrough is set once per pin, and a pin made in combat gets it when combat ends.
function Pin:CheckMouseButtonPassthrough()
	if self.passthroughSet or self.handlesRightButton then
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
	if not self.passthroughSet and not self.handlesRightButton then
		self.passthroughSet = true
		self:SetPassThroughButtons("RightButton")
	end
end

function Pin:Flash()
	self.Pulse:Restart()
end

function Pin:OnMouseEnter()
	if self.group then
		AUI.WorldMap:ShowTooltip(self)
	end
end

function Pin:OnMouseLeave()
	GameTooltip:Hide()
end

---@param button string
function Pin:OnMouseClickAction(button)
	if self.group then
		AUI.WorldMap:Click(self, button)
	end
end
