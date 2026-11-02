local AUI = select(2, ...)

local Options = AUI.InterfaceOptions

-- Frames whose own area catches clicks around the extra action, zone ability and alternate power bar.
local CLICK_FRAMES = { "ExtraActionBarFrame", "ExtraAbilityContainer", "ZoneAbilityFrame", "PlayerPowerBarAlt" }

---@return Region[] art the decorative frames around the extra action and zone ability buttons that exist
local function ArtRegions()
	local regions = {}

	if ExtraActionButton1 and ExtraActionButton1.style then
		regions[#regions + 1] = ExtraActionButton1.style
	end

	if ZoneAbilityFrame and ZoneAbilityFrame.Style then
		regions[#regions + 1] = ZoneAbilityFrame.Style
	end

	return regions
end

---Lets clicks pass through the art around the extra action, zone ability and alternate power bar, and hides the art
---around the extra action and zone ability buttons; the buttons themselves keep working. These frames hold secure
---buttons, so every change waits until combat ends. Turning a setting off puts each frame's own mouse handling or art
---back.
---@class AUIExtraActionButton
---@field mouse table<string, boolean> each changed frame's mouse handling before it was changed
---@field pending boolean an apply is waiting for combat to end
---@field artHidden boolean the art is hidden by this feature
---@field following boolean entering the world re-applies
local ExtraActionButton = {
	mouse = {},
	pending = false,
	artHidden = false,
	following = false,
}
AUI.ExtraActionButton = ExtraActionButton

---Brings every frame in line with the settings. In combat it waits for combat to end.
function ExtraActionButton:Apply()
	if InCombatLockdown() then
		if not self.pending then
			self.pending = true
			AUI.Events:Register("PLAYER_REGEN_ENABLED", self, self.OnCombatEnded)
		end

		return
	end

	self.pending = false

	local clickThrough = Options:On(Options.CLICK_THROUGH_PATH)
	local hideArt = Options:On(Options.HIDE_ART_PATH)

	for _, name in ipairs(CLICK_FRAMES) do
		local frame = _G[name]

		if frame and frame.EnableMouse and frame.IsMouseEnabled then
			if clickThrough then
				if self.mouse[name] == nil then
					self.mouse[name] = frame:IsMouseEnabled()
				end

				frame:EnableMouse(false)
			elseif self.mouse[name] ~= nil then
				frame:EnableMouse(self.mouse[name])
				self.mouse[name] = nil
			end
		end
	end

	if hideArt or self.artHidden then
		for _, region in ipairs(ArtRegions()) do
			region:SetAlpha(hideArt and 0 or 1)
		end

		self.artHidden = hideArt
	end

	self:Follow(clickThrough or hideArt)
end

---@param follow boolean
function ExtraActionButton:Follow(follow)
	if follow == self.following then
		return
	end

	self.following = follow

	if follow then
		AUI.Events:Register("PLAYER_ENTERING_WORLD", self, self.Apply)
	else
		AUI.Events:Unregister("PLAYER_ENTERING_WORLD", self)
	end
end

function ExtraActionButton:OnCombatEnded()
	AUI.Events:Unregister("PLAYER_REGEN_ENABLED", self)

	if self.pending then
		self:Apply()
	end
end
