local AUI = select(2, ...)

local L = AUI.L
local Options = AUI.MarkerOptions

-- The World Marker Cycle's key bindings' names in AeonUI's section of Blizzard's Key Bindings (Bindings.xml).
_G["BINDING_NAME_CLICK " .. Options.PLACE_BUTTON .. ":LeftButton"] = L["Place Next World Marker"]
_G["BINDING_NAME_CLICK " .. Options.CLEAR_BUTTON .. ":LeftButton"] = L["Clear World Markers"]

---The Raid Markers module: the Raid Markers Bar and the world marker cycle. Changes take effect at once, out of
---combat, and a profile change applies the new profile's choices.
---@class AUIMarkers
---@field active boolean started this session
local Markers = {
	active = false,
}
AUI.Markers = Markers

---@param path string? the changed setting; nil when the whole profile changed
function Markers:OnProfileChanged(path)
	if path == nil or path:sub(1, 8) == "markers." then
		AUI.Events:Coalesce("markersApply", function()
			Markers:Apply()
		end)
	end
end

function Markers:Apply()
	if AUI.can.raidMarkers then
		AUI.MarkerBar:Apply()
	end

	if AUI.can.worldMarkers then
		AUI.MarkerCycler:Apply()
	end
end

function Markers:Start()
	if self.active then
		return
	end

	self.active = true
	AUI.Callbacks:Register("Profile", self, self.OnProfileChanged)
	self:Apply()
end
