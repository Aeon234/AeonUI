local AUI = select(2, ...)

local Options = AUI.MarkerOptions

-- Steps to the next world marker of the cycle before each click, in the restricted environment.
local PLACE_SNIPPET = [[
	local count = self:GetAttribute("count") or 0

	if count == 0 then
		return false
	end

	local step = (self:GetAttribute("step") or 0) % count + 1

	self:SetAttribute("step", step)
	self:SetAttribute("macrotext", self:GetAttribute("macro" .. step))
]]
-- Starts the cycle over before each click of the clear button.
local CLEAR_SNIPPET = [[
	self:GetFrameRef("place"):SetAttribute("step", 0)
]]

---The world marker cycle: the Place Next World Marker and Clear World Markers key bindings click two named secure
---buttons. Place puts the cycle's next world marker at the cursor; Clear removes every world marker and starts the
---cycle over. Where secure snippets run (Retail) the cycle steps in combat too; elsewhere it steps out of combat, and in
---combat the key places the marker it reached again. The cycle's markers change out of combat only.
---@class AUIMarkerCycler
---@field place Button?
---@field clear Button?
---@field snippets boolean the cycle steps in the restricted environment
---@field pending boolean an apply waits for combat to end
local Cycler = {
	snippets = false,
	pending = false,
}
AUI.MarkerCycler = Cycler

---@param name string
---@return Button
local function SecureButton(name)
	local button = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")

	button:RegisterForClicks("AnyDown")
	button:SetAttribute("useOnKeyDown", true)
	button:SetAttribute("type", "macro")

	return button
end

---Creates both buttons once, so the bindings find them.
function Cycler:Create()
	if self.place then
		return
	end

	local place, clear = SecureButton(Options.PLACE_BUTTON), SecureButton(Options.CLEAR_BUTTON)

	clear:SetAttribute("macrotext", ("%s all"):format(SLASH_CLEAR_WORLD_MARKER1 or "/cwm"))
	self.place, self.clear = place, clear
	self.snippets = AUI.can.secureSnippets == true

	if self.snippets then
		SecureHandlerWrapScript(place, "PreClick", place, PLACE_SNIPPET)
		SecureHandlerSetFrameRef(clear, "place", place)
		SecureHandlerWrapScript(clear, "PreClick", clear, CLEAR_SNIPPET)
	else
		place:SetScript("PreClick", function()
			self:Step()
		end)
		clear:SetScript("PreClick", function()
			if not InCombatLockdown() then
				place:SetAttribute("step", 0)
			end
		end)
	end
end

---Without secure snippets: steps to the next marker out of combat, as the restricted snippet does in it.
function Cycler:Step()
	local place = self.place

	if not place or InCombatLockdown() then
		return
	end

	local count = place:GetAttribute("count") or 0

	if count == 0 then
		place:SetAttribute("macrotext", nil)

		return
	end

	local step = Options:NextStep(place:GetAttribute("step") or 0, count)

	place:SetAttribute("step", step)
	place:SetAttribute("macrotext", place:GetAttribute("macro" .. step))
end

---Gives the place button the cycle's markers and starts it over. In combat it waits for combat to end.
function Cycler:Apply()
	if InCombatLockdown() then
		if not self.pending then
			self.pending = true
			AUI.Events:Register("PLAYER_REGEN_ENABLED", self, self.OnCombatEnded)
		end

		return
	end

	self:Create()

	local place = self.place --[[@as Button]]
	local markers = Options:Cycle(Options:Get("markers.cycle.order"), function(name)
		return Options:Get("markers.cycle.show." .. name) == true
	end)

	for step = 1, #Options.NAMES do
		place:SetAttribute("macro" .. step, markers[step] and Options:CycleMacro(markers[step]) or nil)
	end

	place:SetAttribute("count", #markers)
	place:SetAttribute("step", 0)
	place:SetAttribute("macrotext", markers[1] and Options:CycleMacro(markers[1]) or nil)
end

function Cycler:OnCombatEnded()
	AUI.Events:Unregister("PLAYER_REGEN_ENABLED", self)
	self.pending = false
	self:Apply()
end

---@return string? key the first key bound to Place Next World Marker
---@return string? clearKey the first key bound to Clear World Markers
function Cycler:Keys()
	return GetBindingKey("CLICK " .. Options.PLACE_BUTTON .. ":LeftButton"),
		GetBindingKey("CLICK " .. Options.CLEAR_BUTTON .. ":LeftButton")
end
