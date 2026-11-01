local AUI = select(2, ...)

local Options = AUI.InputOptions

local FOCUS_BUTTON = "AeonUIFocusButton"

-- Blizzard's own single unit frames, looked up by name when applied; one a client lacks is skipped.
local BLIZZARD_FRAMES = { "PlayerFrame", "PetFrame", "TargetFrame", "FocusFrame" }

---@class AUIFocusAttributes
---@field type string the attribute key holding the action type
---@field value string the action type set
---@field macro string? the attribute key holding the macro text, when one was set

---Focuses a unit with a chosen modifier and mouse button: on unit frames (those in `ClickCastFrames` and Blizzard's
---own) through their secure attributes, and in the world through an override binding on a secure button. Mark Focus
---adds a raid marker to the new focus through a secure `raidtarget` button that marks only an unmarked unit. While
---Clique is loaded, unit frames are left to it. Every change to secure attributes or bindings waits until combat ends.
---@class AUIFocusShortcut
---@field frames table<Frame, AUIFocusAttributes> the unit frames this feature set attributes on
---@field compact table<Frame, true> Blizzard's compact unit frames seen so far
---@field pending boolean an apply is waiting for combat to end
---@field hooked boolean the compact unit frames are followed
---@field focusButton Button?
---@field markButton Button?
local FocusShortcut = {
	frames = {},
	compact = setmetatable({}, { __mode = "k" }),
	pending = false,
	hooked = false,
}
AUI.FocusShortcut = FocusShortcut

---@return boolean
function FocusShortcut.CliqueLoaded()
	return C_AddOns.IsAddOnLoaded("Clique") == true
end

---@return boolean
local function Enabled()
	return Options:Get(Options.FOCUS_PATH) == true
end

---@return boolean able the player may set raid markers: solo, in a party, or leading or assisting a raid
local function CanMark()
	if not IsInRaid() then
		return true
	end

	return AUI:Readable(UnitIsGroupLeader("player"), false) == true
		or AUI:Readable(UnitIsGroupAssistant("player"), false) == true
end

---@param frame any
---@return boolean
local function Usable(frame)
	return type(frame) == "table"
		and type(frame.SetAttribute) == "function"
		and not (frame.IsForbidden and frame:IsForbidden())
end

---@return table<Frame, true> frames every unit frame the shortcut covers
function FocusShortcut:Candidates()
	local frames = {}

	local function Add(frame)
		if Usable(frame) then
			frames[frame] = true
		end
	end

	if type(ClickCastFrames) == "table" then
		for frame, registered in pairs(ClickCastFrames) do
			if registered then
				Add(frame)
			end
		end
	end

	for _, name in ipairs(BLIZZARD_FRAMES) do
		Add(_G[name])
	end

	if TargetFrame then
		Add(TargetFrame.totFrame)
	end

	if FocusFrame then
		Add(FocusFrame.totFrame)
	end

	for index = 1, MAX_BOSS_FRAMES or 0 do
		Add(_G["Boss" .. index .. "TargetFrame"])
	end

	if PartyFrame then
		for index = 1, MAX_PARTY_MEMBERS or 0 do
			Add(PartyFrame["MemberFrame" .. index])
		end
	end

	for frame in pairs(self.compact) do
		Add(frame)
	end

	return frames
end

---Removes the attributes this feature set, leaving any another addon has since changed.
function FocusShortcut:ClearFrames()
	for frame, keys in pairs(self.frames) do
		if frame:GetAttribute(keys.type) == keys.value then
			frame:SetAttribute(keys.type, nil)
		end

		if keys.macro then
			frame:SetAttribute(keys.macro, nil)
		end
	end

	self.frames = {}
end

---@param frame Frame
function FocusShortcut:SetFrame(frame)
	local typeKey, macroKey = Options.AttributeKeys(Options:Get(Options.FOCUS_MODIFIER_PATH),
		Options:Get(Options.FOCUS_BUTTON_PATH))

	if Options:Get(Options.FOCUS_MARK_PATH) and CanMark() then
		frame:SetAttribute(typeKey, "macro")
		frame:SetAttribute(macroKey, Options.FRAME_MACRO)
		self.frames[frame] = { type = typeKey, value = "macro", macro = macroKey }
	else
		frame:SetAttribute(typeKey, "focus")
		self.frames[frame] = { type = typeKey, value = "focus" }
	end
end

function FocusShortcut:CreateButtons()
	if self.focusButton then
		return
	end

	local focusButton = CreateFrame("Button", FOCUS_BUTTON, UIParent, "SecureActionButtonTemplate")
	focusButton:RegisterForClicks("AnyDown")
	focusButton:SetAttribute("useOnKeyDown", true)
	focusButton:SetAttribute("type", "macro")
	self.focusButton = focusButton

	local markButton = CreateFrame("Button", Options.MARK_BUTTON, UIParent, "SecureActionButtonTemplate")
	markButton:RegisterForClicks("AnyUp")
	markButton:SetAttribute("useOnKeyDown", false)
	markButton:SetAttribute("type", "raidtarget")
	markButton:SetAttribute("action", "set-unmarked")
	markButton:SetAttribute("unit", "focus")
	self.markButton = markButton
end

---Follows Blizzard's compact unit frames (raid, party, arena) as they are set up. Hooked once.
function FocusShortcut:HookCompactFrames()
	if self.hooked or not CompactUnitFrame_SetUnit then
		return
	end

	self.hooked = true
	hooksecurefunc("CompactUnitFrame_SetUnit", function(frame, unit)
		if type(unit) == "string" and unit:find("^nameplate") then
			return
		end

		self.compact[frame] = true

		if Enabled() and not self.frames[frame] and not self.CliqueLoaded() and Usable(frame) then
			if InCombatLockdown() then
				self:Apply()
			else
				self:SetFrame(frame)
			end
		end
	end)
end

---Brings every attribute and binding in line with the settings, or removes them all while the feature is off.
---In combat it waits for combat to end.
function FocusShortcut:Apply()
	if InCombatLockdown() then
		if not self.pending then
			self.pending = true
			AUI.Events:Register("PLAYER_REGEN_ENABLED", self, self.OnCombatEnded)
		end

		return
	end

	self.pending = false
	self:ClearFrames()

	if self.focusButton then
		ClearOverrideBindings(self.focusButton)
	end

	if not Enabled() then
		self:Unfollow()

		return
	end

	self:Follow()
	self:CreateButtons()

	if not self.CliqueLoaded() then
		for frame in pairs(self:Candidates()) do
			self:SetFrame(frame)
		end
	end

	local focusButton, markButton = self.focusButton --[[@as Button]], self.markButton --[[@as Button]]
	local mark = Options:Get(Options.FOCUS_MARK_PATH) and CanMark()

	markButton:SetAttribute("marker", tonumber(Options:Get(Options.FOCUS_MARKER_PATH)))

	if Options:Get(Options.FOCUS_WORLD_PATH) then
		focusButton:SetAttribute("macrotext", Options.WorldMacro(mark == true))
		SetOverrideBindingClick(focusButton, true, Options.BindingKey(Options:Get(Options.FOCUS_MODIFIER_PATH),
			Options:Get(Options.FOCUS_BUTTON_PATH)), FOCUS_BUTTON)
	end
end

function FocusShortcut:ApplySoon()
	AUI.Events:Coalesce("focusShortcut", function()
		FocusShortcut:Apply()
	end)
end

---Re-applies as the group, its leader or the world changes, which can bring frames or change who may mark.
function FocusShortcut:Follow()
	self:HookCompactFrames()
	AUI.Events:Register("GROUP_ROSTER_UPDATE", self, self.ApplySoon)
	AUI.Events:Register("PARTY_LEADER_CHANGED", self, self.ApplySoon)
	AUI.Events:Register("PLAYER_ENTERING_WORLD", self, self.ApplySoon)
end

function FocusShortcut:Unfollow()
	AUI.Events:Cancel("focusShortcut")
	AUI.Events:Unregister("GROUP_ROSTER_UPDATE", self)
	AUI.Events:Unregister("PARTY_LEADER_CHANGED", self)
	AUI.Events:Unregister("PLAYER_ENTERING_WORLD", self)
end

function FocusShortcut:OnCombatEnded()
	AUI.Events:Unregister("PLAYER_REGEN_ENABLED", self)

	if self.pending then
		self:Apply()
	end
end
