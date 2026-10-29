local AUI = select(2, ...)

---The Interface page's module: the extra action button's art, help tips, the Blizzard frames AeonUI hides, and the
---pop-ups and toasts. Changes take effect at once, the extra action button's out of combat, and a profile change
---applies the new profile's choices. UI Scale and Game Menu Scale, in the same folder, start on their own.
---@class AUIInterface
---@field active boolean started this session
local Interface = {
	active = false,
}
AUI.Interface = Interface

---@param path string? the changed setting; nil when the whole profile changed
function Interface:OnProfileChanged(path)
	if path == nil or path:sub(1, 10) == "interface." then
		AUI.Events:Coalesce("interfaceApply", function()
			Interface:Apply()
		end)
	end
end

function Interface:Apply()
	if AUI.can.extraActionButton then
		AUI.ExtraActionButton:Apply()
	end

	AUI.HelpTips:Apply()
	AUI.HideFrames:Apply()
	AUI.BlizzardPopups:Apply()
	AUI.ReleaseProtection:Apply()
end

function Interface:Start()
	if self.active then
		return
	end

	self.active = true
	AUI.Callbacks:Register("Profile", self, self.OnProfileChanged)
	self:Apply()
end
