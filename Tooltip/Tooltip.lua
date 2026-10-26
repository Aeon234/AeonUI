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
	return AUI.Profile:Get(Options.ENABLED_PATH) == true
end

---@param path string? the changed setting; nil when the whole profile changed
function Tooltip:OnProfileChanged(path)
	if path ~= nil and path:sub(1, 8) ~= "tooltip." then
		return
	end

	AUI.Events:Coalesce("tooltipApply", function()
		Tooltip:Apply()
	end)
end

function Tooltip:Apply()
	local on = self:IsEnabled()

	AUI.TooltipAppearance:Apply(on)
	AUI.TooltipUnits:Apply(on)
	AUI.TooltipDetails:Apply(on)
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
	-- The client settles its session CVars after login, over a write made before.
	AUI.Events:Register("PLAYER_ENTERING_WORLD", self, function()
		Tooltip:Apply()
	end)
	self:Apply()
end
