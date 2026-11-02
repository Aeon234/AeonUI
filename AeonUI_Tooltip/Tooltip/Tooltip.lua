local AUI = select(2, ...)

local Options = AUI.TooltipOptions

---The Tooltip module: what Blizzard's game tooltip shows and how it looks, with Blizzard's backdrop and border kept.
---Its settings take effect at once; switching it off puts back what it changed.
---@class AUITooltip
---@field active boolean the module started this session
local Tooltip = {
	active = false,
}
AUI.Tooltip = Tooltip

---@return boolean
function Tooltip:IsEnabled()
	return Options:Get(Options.ENABLED_PATH) == true
end

---@param path string? the changed setting; nil when the whole profile changed
function Tooltip:OnProfileChanged(path)
	if path ~= nil and path:sub(1, 8) ~= "tooltip." then
		return
	end

	Options:Forget()

	AUI.Events:Coalesce("tooltipApply", function()
		Tooltip:Apply()
	end)

	-- Riding the cursor takes the tooltip's mover out of edit mode, and a profile brings its own place.
	if (path == nil or path == Options.CURSOR_PATH) and AUI.EditTargets then
		AUI.EditTargets:Apply()
	end
end

function Tooltip:Apply()
	local on = self:IsEnabled()

	AUI.TooltipAppearance:Apply(on)
	AUI.TooltipUnits:Apply(on)
	AUI.TooltipDetails:Apply(on)
	AUI.TooltipAnchor:Apply(on)
	AUI.TooltipVisibility:Apply(on)
end

function Tooltip:Start()
	if self.active then
		return
	end

	self.active = true
	AUI.Callbacks:Register("Profile", self, self.OnProfileChanged)
	AUI.TooltipAppearance:Hook()
	AUI.TooltipUnits:Hook()
	AUI.TooltipDetails:Hook()
	AUI.TooltipUpgrades:Hook()
	AUI.TooltipInspect:Hook()
	AUI.TooltipAnchor:Hook()
	AUI.TooltipVisibility:Hook()
	-- The client settles its session CVars after login, over a write made before.
	AUI.Events:Register("PLAYER_ENTERING_WORLD", self, function()
		Tooltip:Apply()
	end)
	self:Apply()
end
