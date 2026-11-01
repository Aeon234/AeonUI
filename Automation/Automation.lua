local AUI = select(2, ...)

---The Automation module: the merchant visit, the expansion filter, the send-mail helpers and the managed game
---settings. Each part has its own switches; changes take effect at once, and a profile change applies the new
---profile's choices.
---@class AUIAutomation
---@field active boolean started this session
local Automation = {
	active = false,
}
AUI.Automation = Automation

---@param path string? the changed setting; nil when the whole profile changed
function Automation:OnProfileChanged(path)
	if path ~= nil and path:sub(1, 11) ~= "automation." then
		return
	end

	AUI.Events:Coalesce("automationApply", function()
		Automation:Apply()
	end)
end

function Automation:Apply()
	AUI.Merchant:Apply()
	AUI.ExpansionFilter:Apply()
	AUI.Mail:Apply()
	AUI.GameSettings:Apply()
end

function Automation:Start()
	if self.active then
		return
	end

	self.active = true
	AUI.Callbacks:Register("Profile", self, self.OnProfileChanged)
	self:Apply()
end
