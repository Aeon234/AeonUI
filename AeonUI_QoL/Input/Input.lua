local AUI = select(2, ...)

---The Input module: Click Down, Focus Shortcut, the key labels and macro names. Changes take effect at once, out of combat for
---Focus Shortcut, and a profile change applies the new profile's choices.
---@class AUIInput
---@field active boolean started this session
local Input = {
	active = false,
}
AUI.Input = Input

---@param path string? the changed setting; nil when the whole profile changed
function Input:OnProfileChanged(path)
	if path == nil or path:sub(1, 6) == "input." then
		AUI.Events:Coalesce("inputApply", function()
			Input:Apply()
		end)
	end
end

function Input:Apply()
	AUI.ClickDown:Apply()

	if AUI.can.focusShortcut then
		AUI.FocusShortcut:Apply()
	end

	AUI.KeyLabels:Apply()
	AUI.MacroNames:Apply()
end

function Input:Start()
	if self.active then
		return
	end

	self.active = true
	AUI.Callbacks:Register("Profile", self, self.OnProfileChanged)
	self:Apply()
end
