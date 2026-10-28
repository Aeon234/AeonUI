local AUI = select(2, ...)

local L = AUI.L

local RELOAD_POPUP = "AEONUI_UI_SCALE_RELOAD"

-- Addons that keep their own UI scale; while one is loaded, AeonUI leaves the scale to it.
local MANAGERS = { "ElvUI", "EllesmereUI" }

-- The scale slider's range, in percent. The lower bound keeps the 4K pixel-perfect scale (35.6%) in range.
local MIN_PERCENT, MAX_PERCENT = 30, 115

---Sets the whole interface's scale through `UIParent`, which reaches below Blizzard's 65% minimum, so pixel-perfect
---scales work on large screens. Nothing changes until the player picks a value; the saved value is then applied while
---the setting is on, and again when the client changes the scale or the display. Changes wait for combat to end, and
---for the mouse button to come up while a slider is dragged, since the settings window rescales with the interface.
---Restoring the game's own scale needs a reload, so turning the setting off offers one.
---The state is account-wide, in `global.uiScale`: `enabled` (absent means on) and `scale` in percent (absent until
---picked).
---@class AUIUIScale
---@field active boolean started this session
---@field applied boolean the scale was set this session, so turning off needs a reload
---@field pending string? what an apply waits for: "combat" or "mouse"
local UIScale = {
	active = false,
	applied = false,
	MIN_PERCENT = MIN_PERCENT,
	MAX_PERCENT = MAX_PERCENT,
	-- Screen heights the preset buttons compute pixel-perfect scales for, in the order the page lists them.
	PRESETS = {
		{ key = "1080p", height = 1080 },
		{ key = "1440p", height = 1440 },
		{ key = "4K", height = 2160 },
	},
}
AUI.UIScale = UIScale

StaticPopupDialogs[RELOAD_POPUP] = {
	text = L["%s is off. Its change stays until the interface reloads."],
	button1 = RELOADUI,
	button2 = L["Later"],
	OnAccept = function()
		ReloadUI()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

---@param height number the screen's height in physical pixels
---@return number percent the scale at which one interface unit is one pixel
function UIScale.PixelPerfect(height)
	return 768 / height * 100
end

---@param value any
---@return number? percent within the slider's range, or nil when `value` is not a number
function UIScale.Clamp(value)
	if type(value) ~= "number" or value ~= value then
		return nil
	end

	return math.min(math.max(value, MIN_PERCENT), MAX_PERCENT)
end

---@return string? manager the loaded addon that keeps its own UI scale
function UIScale.Manager()
	for _, name in ipairs(MANAGERS) do
		if C_AddOns.IsAddOnLoaded(name) then
			return name
		end
	end
end

---@return string? reason the controls are disabled, naming the addon that manages the scale
function UIScale:Blocked()
	local manager = self.Manager()

	if manager then
		return L["%s manages the UI scale."]:format(manager)
	end
end

---@return table? state `global.uiScale`, created on first use; nil while saved data cannot be used
local function State()
	local global = AUI.Profile:Global()

	if not global then
		return nil
	end

	if type(global.uiScale) ~= "table" then
		global.uiScale = {}
	end

	return global.uiScale
end

---@return boolean
function UIScale:IsEnabled()
	local state = State()

	return state ~= nil and state.enabled ~= false
end

---@return number? percent the saved scale; nil until the player picks one
function UIScale:Saved()
	local state = State()

	return state and self.Clamp(state.scale)
end

---@return number percent the saved scale, or the interface's current one while none is saved
function UIScale:Current()
	return self:Saved() or UIParent:GetScale() * 100
end

---@param enabled boolean
function UIScale:SetEnabled(enabled)
	local state = State()

	if not state then
		return
	end

	state.enabled = enabled

	if enabled then
		self:Apply()
	else
		self:Stop()
	end
end

---@param percent number
function UIScale:SetScale(percent)
	local state = State()
	local value = self.Clamp(percent)

	if not state or not value then
		return
	end

	state.scale = value
	self:Apply()
end

---Waits for `event`, once, then applies.
---@param reason string
---@param event string
function UIScale:Wait(reason, event)
	if self.pending == reason then
		return
	end

	if self.pending then
		AUI.Events:Unregister(self.pending == "combat" and "PLAYER_REGEN_ENABLED" or "GLOBAL_MOUSE_UP", self)
	end

	self.pending = reason
	AUI.Events:Register(event, self, self.OnWaitEnded)
end

function UIScale:OnWaitEnded(event)
	AUI.Events:Unregister(event, self)
	self.pending = nil
	self:Apply()
end

---Applies the saved scale now, or once combat ends or the mouse button comes up.
function UIScale:Apply()
	local percent = self:Saved()

	if not self.active or not percent or not self:IsEnabled() or self.Manager() then
		return
	end

	if InCombatLockdown() then
		self:Wait("combat", "PLAYER_REGEN_ENABLED")

		return
	end

	if IsMouseButtonDown("LeftButton") then
		self:Wait("mouse", "GLOBAL_MOUSE_UP")

		return
	end

	local scale = percent / 100

	if math.abs(UIParent:GetScale() - scale) > 0.0001 then
		UIParent:SetScale(scale)
	end

	self.applied = true
end

function UIScale:ApplySoon()
	AUI.Events:Coalesce("uiScale", function()
		UIScale:Apply()
	end)
end

---Cancels a waiting apply. A scale set this session stays until a reload, so one is offered.
function UIScale:Stop()
	AUI.Events:Cancel("uiScale")

	if self.pending then
		AUI.Events:Unregister(self.pending == "combat" and "PLAYER_REGEN_ENABLED" or "GLOBAL_MOUSE_UP", self)
		self.pending = nil
	end

	if self.applied then
		self.applied = false
		StaticPopup_Show(RELOAD_POPUP, UI_SCALE)
	end
end

---Follows the client's scale and display changes, which reset `UIParent`'s scale. Runs at login.
function UIScale:Start()
	if self.active then
		return
	end

	self.active = true
	AUI.Events:Register("UI_SCALE_CHANGED", self, self.ApplySoon)
	AUI.Events:Register("DISPLAY_SIZE_CHANGED", self, self.ApplySoon)
	self:Apply()
end
