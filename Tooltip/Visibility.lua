local AUI = select(2, ...)

local Options, Format = AUI.TooltipOptions, AUI.TooltipFormat

-- The events that change whether a mode hides the tooltip, by mode.
local STATE_EVENTS = {
	OUT_OF_COMBAT = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" },
	OUT_OF_BOSS_COMBAT = { "ENCOUNTER_START", "ENCOUNTER_END" },
}

---When `GameTooltip` may be seen: always, out of combat, out of boss encounters or never, with a key that shows it
---while held. A hidden tooltip is not hidden at all: it stays shown inside a hidden frame, so Blizzard's own hover
---code keeps building and refreshing it and the key only has to take it out again. Hiding it instead would make
---showing it rebuild it from addon code, which fails on secret values in combat, and its alpha is the client's to
---fade. Item comparisons are other tooltips, so while `GameTooltip` is kept hidden they are turned off and cleared.
---@class AUITooltipVisibility
---@field hooked boolean
---@field host Frame? the hidden frame a hidden tooltip is kept in
---@field parent table? the tooltip's parent before it was kept hidden
---@field parked boolean `GameTooltip` is kept in the hidden frame
---@field clearing boolean a comparison clear waits for the next frame
---@field watched string? the mode whose state events are registered
local Visibility = {
	hooked = false,
	parked = false,
	clearing = false,
}
AUI.TooltipVisibility = Visibility

---@return boolean held the show key is chosen and held
function Visibility:Peeking()
	local key = AUI.Profile:Get(Options.PEEK_PATH)

	if key == "SHIFT" then
		return IsShiftKeyDown()
	elseif key == "CTRL" then
		return IsControlKeyDown()
	elseif key == "ALT" then
		return IsAltKeyDown()
	end

	return false
end

---@return string mode the show mode in force; "ALWAYS" while the module is off
function Visibility:Mode()
	return AUI.Tooltip:IsEnabled() and AUI.Profile:Get(Options.SHOW_MODE_PATH) or "ALWAYS"
end

---@return boolean hidden the show mode hides `GameTooltip` now and its key is not held
function Visibility:Hidden()
	local mode = self:Mode()

	if mode == "ALWAYS" or self:Peeking() then
		return false
	elseif mode == "NEVER" then
		return true
	elseif mode == "OUT_OF_COMBAT" then
		return InCombatLockdown()
	elseif mode == "OUT_OF_BOSS_COMBAT" then
		return AUI:Readable(C_InstanceEncounter.IsEncounterInProgress()) == true
	end

	return false
end

---Clears the shown comparisons on the next frame, outside the tooltip code that showed them.
function Visibility:ClearComparisons()
	if self.clearing or not self.parked then
		return
	end

	self.clearing = true
	C_Timer.After(0, function()
		Visibility.clearing = false

		if Visibility.parked then
			pcall(TooltipComparisonManager.Clear, TooltipComparisonManager, GameTooltip)
		end
	end)
end

---@param tooltip table `GameTooltip`
function Visibility:Park(tooltip)
	if not self.parked then
		local host = self.host

		if not host then
			host = CreateFrame("Frame", "AeonUITooltipHost", UIParent)
			host:Hide()
			self.host = host
		end

		local parent = tooltip:GetParent()

		self.parked = true
		self.parent = parent ~= host and parent or nil
		tooltip:SetParent(host)
	end

	-- Blizzard clears this on hide, which an item tooltip's rebuild can do, so it is set on every park.
	pcall(GameTooltip_SuppressAutomaticCompareItem, tooltip)
	self:ClearComparisons()
end

---@param tooltip table `GameTooltip`
function Visibility:Unpark(tooltip)
	if not self.parked then
		return
	end

	self.parked = false
	tooltip:SetParent(self.parent or UIParent)
	-- A new parent can lower its strata; a tooltip carrying secret unit data reads its strata back secret, so it is
	-- set, never read.
	tooltip:SetFrameStrata("TOOLTIP")
end

---@param tooltip table
function Visibility:Update(tooltip)
	if tooltip ~= GameTooltip or tooltip:IsForbidden() then
		return
	end

	if self:Hidden() then
		self:Park(tooltip)
	else
		self:Unpark(tooltip)
	end
end

---Follows the show key: down takes a kept tooltip out, up puts it back while the mode still hides it.
---@param key string
---@param down number 1 while pressed
function Visibility:OnModifier(key, down)
	local tooltip = GameTooltip

	if not Format:IsModifierKey(AUI.Profile:Get(Options.PEEK_PATH), key) or self:Mode() == "ALWAYS"
		or tooltip:IsForbidden() or not tooltip:IsShown() then
		return
	end

	if down == 1 then
		self:Unpark(tooltip)
	elseif self:Hidden() then
		self:Park(tooltip)
	end
end

---Registers the events that change what the mode in force hides, and only those.
function Visibility:Watch()
	local mode = self:Mode()

	if mode == self.watched then
		return
	end

	for _, event in ipairs(STATE_EVENTS[self.watched or ""] or {}) do
		AUI.Events:Unregister(event, self)
	end

	self.watched = mode

	for _, event in ipairs(STATE_EVENTS[mode] or {}) do
		AUI.Events:Register(event, self, function()
			-- A tooltip the mode now shows stays kept until its owner shows it again, so stale text never returns.
			if GameTooltip:IsShown() and Visibility:Hidden() then
				Visibility:Park(GameTooltip)
			end
		end)
	end
end

---@param on boolean the module is on
function Visibility:Apply(on)
	self:Watch()

	if (not on or self:Mode() == "ALWAYS") and GameTooltip then
		self:Unpark(GameTooltip)
	end
end

---Installs the visibility hooks once; they do nothing while the mode is Always or the module is off.
function Visibility:Hook()
	if self.hooked or not GameTooltip or not GameTooltip_SetDefaultAnchor then
		return
	end

	self.hooked = true

	hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip)
		Visibility:Update(tooltip)
	end)
	-- Every tooltip build starts with SetOwner, which covers the tooltips owners anchor themselves.
	hooksecurefunc(GameTooltip, "SetOwner", function(tooltip)
		Visibility:Unpark(tooltip)

		if Visibility:Mode() ~= "ALWAYS" then
			Visibility:Update(tooltip)
		end
	end)
	-- Item data can hide and show the tooltip again without another SetOwner.
	GameTooltip:HookScript("OnShow", function(tooltip)
		if Visibility.parked or Visibility:Mode() ~= "ALWAYS" then
			Visibility:Update(tooltip)
		end
	end)
	TooltipDataProcessor.AddTooltipPreCall(Enum.TooltipDataType.Item, function(tooltip)
		if tooltip == GameTooltip and Visibility.parked then
			pcall(GameTooltip_SuppressAutomaticCompareItem, tooltip)
		end
	end)

	for _, comparison in ipairs({ ShoppingTooltip1, ShoppingTooltip2 }) do
		comparison:HookScript("OnShow", function()
			Visibility:ClearComparisons()
		end)
	end

	AUI.Events:Register("MODIFIER_STATE_CHANGED", self, function(_, _, key, down)
		Visibility:OnModifier(key, down)
	end)
end
