local AUI = select(2, ...)

local Options = AUI.CursorOptions

local GCD_SPELL = 61304
-- The ring's opacity, as a share of its own, while a cast sweeps around it.
local CASTING_DIM = 0.35
local STATE_EVENTS = {
	"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_STARTED_LOOKING", "PLAYER_STOPPED_LOOKING",
	"PLAYER_STARTED_TURNING", "PLAYER_STOPPED_TURNING", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
}
local CAST_EVENTS = {
	"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_FAILED",
	"UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE",
	"UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_UPDATE",
	"UNIT_SPELLCAST_EMPOWER_STOP",
}

---@class AUICursorRingFrame : Frame
---@field ring Texture
---@field dot Texture
---@field gcd Cooldown the global cooldown, filling a ring inside the ring
---@field cast Cooldown a cast or channel, sweeping around the ring itself
---@field casting boolean a cast or channel sweeps
---@field x number? the last place it was put, in `UIParent` units
---@field y number?

---A ring that follows the cursor, with a center dot, the global cooldown filling a ring inside it and casts sweeping
---around it. Both swipes are drawn from duration objects, so no secret value is read. The ring moves in an
---`OnUpdate` that runs only while it shows, and is placed only when the cursor has moved.
---@class AUICursorRing
---@field active boolean started this session
---@field following boolean the events are registered
---@field frame AUICursorRingFrame?
---@field inCombat boolean
---@field inInstance boolean
---@field looking boolean the camera is turned with the right mouse button
---@field turning boolean the camera is turned with the left mouse button
local CursorRing = {
	active = false,
	following = false,
	inCombat = false,
	inInstance = false,
	looking = false,
	turning = false,
}
AUI.CursorRing = CursorRing

---@param cooldown Cooldown
---@param reverse boolean
local function SetupSwipe(cooldown, reverse)
	cooldown:SetDrawSwipe(true)
	cooldown:SetDrawEdge(false)
	cooldown:SetDrawBling(false)
	cooldown:SetHideCountdownNumbers(true)
	cooldown:SetUseCircularEdge(true)
	cooldown:SetReverse(reverse)
end

---Builds a ring with its dot and swipes, unplaced; the settings page's preview builds one the same way.
---@param parent Frame
---@param name string? a global name, for the root frame only
---@return AUICursorRingFrame frame
function CursorRing:Build(parent, name)
	local frame = CreateFrame("Frame", name, parent) --[[@as AUICursorRingFrame]]

	frame.ring = frame:CreateTexture(nil, "ARTWORK")
	frame.ring:SetAllPoints()

	frame.dot = frame:CreateTexture(nil, "OVERLAY")
	frame.dot:SetPoint("CENTER")
	frame.dot:SetTexture(Options.DOT_TEXTURE)

	frame.gcd = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate") --[[@as Cooldown]]
	frame.gcd:ClearAllPoints()
	frame.gcd:SetPoint("CENTER")
	SetupSwipe(frame.gcd, true)

	frame.cast = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate") --[[@as Cooldown]]
	frame.cast:ClearAllPoints()
	frame.cast:SetAllPoints()
	SetupSwipe(frame.cast, true)
	frame.cast:SetScript("OnCooldownDone", function()
		self:EndCast(frame)
	end)

	frame.casting = false

	return frame
end

---@return number r
---@return number g
---@return number b
function CursorRing:Color()
	local Profile = AUI.Profile

	if Profile:Get(Options.CLASS_COLOR_PATH) then
		local _, class = UnitClass("player")
		local color = class and C_ClassColor.GetClassColor(class)

		if color then
			return color:GetRGB()
		end
	end

	local color = Profile:Get(Options.COLOR_PATH)

	return color.r, color.g, color.b
end

---Sizes, textures and colors a ring to the settings.
---@param frame AUICursorRingFrame
function CursorRing:Style(frame)
	local Profile = AUI.Profile
	local size = Profile:Get(Options.SIZE_PATH)
	local thickness = Profile:Get(Options.THICKNESS_PATH)
	local texture = Options:RingTexture(thickness)
	local swipe = size * Options:SwipeScale(thickness)
	local dot = Options:DotSize(size)
	local alpha = Profile:Get(Options.OPACITY_PATH) / 100
	local r, g, b = self:Color()

	frame:SetSize(size, size)
	frame.ring:SetTexture(texture)
	frame.ring:SetVertexColor(r, g, b, frame.casting and alpha * CASTING_DIM or alpha)
	frame.dot:SetSize(dot, dot)
	frame.dot:SetVertexColor(r, g, b, alpha)
	frame.dot:SetShown(Profile:Get(Options.DOT_PATH) == true)
	frame.gcd:SetSize(swipe, swipe)
	frame.gcd:SetSwipeTexture(texture, r, g, b, 1)
	frame.cast:SetSwipeTexture(texture, r, g, b, 1)
end

---Starts a cast's sweep on a ring and dims the ring under it.
---@param frame AUICursorRingFrame
---@param reverse boolean true fills the ring as the cast runs; false empties it, as a channel does
function CursorRing:BeginCast(frame, reverse)
	frame.cast:SetReverse(reverse)
	frame.casting = true
	self:Style(frame)
end

---Ends a ring's cast sweep and gives the ring its opacity back.
---@param frame AUICursorRingFrame
function CursorRing:EndCast(frame)
	if not frame.casting then
		return
	end

	frame.casting = false
	frame.cast:Clear()
	self:Style(frame)
end

---Places the ring at the cursor, when the cursor has moved.
---@param frame AUICursorRingFrame
local function Follow(frame)
	local cursorX, cursorY = GetCursorPosition()
	local x, y = Options:Position(cursorX, cursorY, UIParent:GetEffectiveScale())

	if x == frame.x and y == frame.y then
		return
	end

	frame.x, frame.y = x, y
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
end

function CursorRing:CreateFrame()
	if self.frame then
		return
	end

	local frame = self:Build(UIParent, "AeonUICursorRing")

	frame:SetFrameStrata("TOOLTIP")
	frame:EnableMouse(false)
	frame:Hide()
	frame:SetScript("OnUpdate", Follow)
	self.frame = frame
end

---@return boolean on the page's switch is on where the client can draw the ring
function CursorRing:IsOn()
	return AUI.can.cursorRing == true and AUI.Profile:Get(Options.ENABLED_PATH) == true
end

---@return boolean shown the ring should show now
function CursorRing:Wanted()
	local Profile = AUI.Profile

	return self:IsOn() and Options:Visible(Profile:Get(Options.SHOW_PATH), self.inCombat, self.inInstance,
		self.looking or self.turning, Profile:Get(Options.HIDE_TURNING_PATH) == true)
end

---Shows or hides the ring; a ring about to show is placed at the cursor first, so it never shows where it was.
function CursorRing:Refresh()
	local frame = self.frame

	if not frame then
		return
	end

	self:Style(frame)

	if self:Wanted() then
		if not frame:IsShown() then
			frame.x, frame.y = nil, nil
			Follow(frame)
			frame:Show()
			self:UpdateGCD()
			self:UpdateCast()
		end
	else
		frame:Hide()
	end
end

---Starts or clears the global cooldown's swipe from its duration object.
function CursorRing:UpdateGCD()
	local frame = self.frame

	if not frame or not frame:IsShown() then
		return
	end

	if not AUI.Profile:Get(Options.GCD_PATH) then
		frame.gcd:Clear()

		return
	end

	local duration = C_Spell.GetSpellCooldownDuration(GCD_SPELL)

	if issecretvalue(duration) or duration then
		frame.gcd:SetCooldownFromDurationObject(duration)
	end
end

---Starts the sweep of the player's cast, empowered cast or channel from its duration object, or ends it when there
---is none.
function CursorRing:UpdateCast()
	local frame = self.frame

	if not frame or not frame:IsShown() then
		return
	end

	if AUI.can.castSwipe and AUI.Profile:Get(Options.CASTS_PATH) then
		local duration = UnitCastingDuration("player")

		if issecretvalue(duration) or duration then
			frame.cast:SetCooldownFromDurationObject(duration)
			self:BeginCast(frame, true)

			return
		end

		duration = UnitEmpoweredChannelDuration and UnitEmpoweredChannelDuration("player")

		if issecretvalue(duration) or duration then
			frame.cast:SetCooldownFromDurationObject(duration)
			self:BeginCast(frame, true)

			return
		end

		duration = UnitChannelDuration("player")

		if issecretvalue(duration) or duration then
			frame.cast:SetCooldownFromDurationObject(duration)
			self:BeginCast(frame, false)

			return
		end
	end

	self:EndCast(frame)
end

---@param event string
function CursorRing:OnStateEvent(event)
	if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
		self.inCombat = event == "PLAYER_REGEN_DISABLED"
	elseif event == "PLAYER_STARTED_LOOKING" or event == "PLAYER_STOPPED_LOOKING" then
		self.looking = event == "PLAYER_STARTED_LOOKING"
	elseif event == "PLAYER_STARTED_TURNING" or event == "PLAYER_STOPPED_TURNING" then
		self.turning = event == "PLAYER_STARTED_TURNING"
	else
		self.inInstance = IsInInstance() == true
	end

	self:Refresh()
end

---@param _ string
---@param unit string
function CursorRing:OnCastEvent(_, unit)
	if unit == "player" then
		self:UpdateCast()
	end
end

---Follows the events while the switch is on, and hides the ring and stops following them while it is off.
function CursorRing:Apply()
	local on = self:IsOn()

	if on ~= self.following then
		self.following = on

		if on then
			self:CreateFrame()
			self.inCombat = InCombatLockdown()
			self.inInstance = IsInInstance() == true
			self.looking, self.turning = false, false

			for _, event in ipairs(STATE_EVENTS) do
				AUI.Events:Register(event, self, self.OnStateEvent)
			end

			AUI.Events:Register("SPELL_UPDATE_COOLDOWN", self, self.UpdateGCD)

			for _, event in ipairs(CAST_EVENTS) do
				AUI.Events:Register(event, self, self.OnCastEvent)
			end
		else
			AUI.Events:UnregisterAll(self)

			if self.frame then
				self.frame.gcd:Clear()
				self:EndCast(self.frame)
			end
		end
	end

	self:Refresh()

	if on then
		self:UpdateGCD()
		self:UpdateCast()
	end
end

---@param path string? the changed setting; nil when the whole profile changed
function CursorRing:OnProfileChanged(path)
	if path == nil or path:sub(1, 7) == "cursor." then
		AUI.Events:Coalesce("cursorApply", function()
			CursorRing:Apply()
		end)
	end
end

function CursorRing:Start()
	if self.active then
		return
	end

	self.active = true
	AUI.Callbacks:Register("Profile", self, self.OnProfileChanged)
	self:Apply()
end
