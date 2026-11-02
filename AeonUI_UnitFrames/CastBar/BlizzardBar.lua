local AUI = select(2, ...)

---Blizzard's player cast bar, parked in a hidden parent while AeonUI's bar is on and handed back when it is turned
---off. Reparenting waits while Edit Mode is open, since Blizzard lays the bar out there, and until combat ends. When
---something else reparents the bar while it is parked, it is parked again in the same frame, after that call returns.
---@class AUICastBarBlizzard
---@field parked boolean the bar should be in the hidden parent
---@field hooked boolean the reparent and Edit Mode hooks are installed
---@field waiting boolean waiting for combat to end
---@field hidden Frame? the hidden parent
---@field original Frame? the parent to hand the bar back to
---@field repark Frame? runs one deferred `Sync` from its `OnUpdate`, then hides
local BlizzardBar = {
	parked = false,
	hooked = false,
	waiting = false,
}
AUI.CastBarBlizzard = BlizzardBar

---@return boolean
local function EditModeOpen()
	return EditModeManagerFrame ~= nil and EditModeManagerFrame:IsShown()
end

---Hides or restores the bar's Edit Mode selection, so a parked bar cannot be picked in Edit Mode.
---@param bar table Blizzard's cast bar, with its Edit Mode `Selection`
---@param hidden boolean
local function HideSelection(bar, hidden)
	local selection = bar.Selection

	if not selection then
		return
	end

	selection:SetAlpha(hidden and 0 or 1)
	selection:EnableMouse(not hidden)
end

---Installs the hooks once: a reparent while parked schedules a park after Blizzard's call returns, Edit Mode closing
---applies the state it held back, and the selection stays hidden each time Edit Mode shows it.
---@param bar table Blizzard's cast bar, with its Edit Mode `Selection`
function BlizzardBar:Hook(bar)
	if self.hooked then
		return
	end

	self.hooked = true
	self.hidden = CreateFrame("Frame")
	self.hidden:Hide()

	local repark = CreateFrame("Frame")

	repark:Hide()
	repark:SetScript("OnUpdate", function(frame)
		frame:Hide()
		self:Sync()
	end)
	self.repark = repark

	hooksecurefunc(bar, "SetParent", function(_, parent)
		if parent ~= self.hidden then
			self.original = parent

			if self.parked then
				repark:Show()
			end
		end
	end)

	if bar.Selection then
		hooksecurefunc(bar.Selection, "Show", function(selection)
			-- Edit Mode shows selections in its own pass; nothing is written inside it.
			C_Timer.After(0, function()
				if self.parked then
					selection:SetAlpha(0)
					selection:EnableMouse(false)
				end
			end)
		end)
	end

	if EventRegistry then
		EventRegistry:RegisterCallback("EditMode.Exit", function()
			self:Sync()
		end, self)
	end
end

---Moves the bar to the parent the state asks for: the hidden parent while parked, otherwise back to the parent it was
---taken from, or `UIParent` when that parent is hidden.
function BlizzardBar:Sync()
	local bar = PlayerCastingBarFrame

	if not bar or not self.hidden or EditModeOpen() then
		return
	end

	if InCombatLockdown() then
		if not self.waiting then
			self.waiting = true
			AUI.Events:Register("PLAYER_REGEN_ENABLED", self, self.OnCombatEnded)
		end

		return
	end

	local parent = bar:GetParent()

	if self.parked then
		if parent ~= self.hidden then
			bar:SetParent(self.hidden)
		end
	elseif parent == self.hidden then
		local original = self.original

		bar:SetParent(original and original:IsVisible() and original or UIParent)
	end
end

function BlizzardBar:OnCombatEnded()
	AUI.Events:Unregister("PLAYER_REGEN_ENABLED", self)
	self.waiting = false
	self:Sync()
end

---@param parked boolean
function BlizzardBar:SetParked(parked)
	local bar = PlayerCastingBarFrame

	if not bar or parked == self.parked then
		return
	end

	if parked then
		self:Hook(bar)

		if bar:GetParent() ~= self.hidden then
			self.original = bar:GetParent()
		end
	end

	self.parked = parked
	HideSelection(bar, parked)
	self:Sync()
end
