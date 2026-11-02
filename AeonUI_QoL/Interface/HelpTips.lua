local AUI = select(2, ...)

local Options = AUI.InterfaceOptions

local CHARACTER_FLAGS = "closedInfoFrames"
local ACCOUNT_FLAGS = "closedInfoFramesAccountWide"

---Closes Blizzard's help tips by marking every one seen, as closing it by hand does: the account-wide flags of
---`Enum.FrameTutorialAccount` and the character's flags, 1 to `NUM_LE_FRAME_TUTORIALS`. It runs at login and when
---turned on, so a tip a patch adds, or one Blizzard's Reset Tutorials reopened, is closed then too. Turning it off
---leaves the flags as they are.
---@class AUIHelpTips
local HelpTips = {}
AUI.HelpTips = HelpTips

---@return integer[] flags the account-wide help tips, in no particular order
function HelpTips.AccountFlags()
	local flags = {}

	for _, flag in pairs(Enum.FrameTutorialAccount or {}) do
		if type(flag) == "number" and flag >= 1 then
			flags[#flags + 1] = flag
		end
	end

	return flags
end

---@return integer count the character's help tips, or 0 where the client does not say how many there are
function HelpTips.CharacterCount()
	local count = NUM_LE_FRAME_TUTORIALS

	return type(count) == "number" and count or 0
end

function HelpTips:Apply()
	if not AUI.can.helpTips or not Options:On(Options.HELP_TIPS_PATH) then
		return
	end

	for _, flag in ipairs(self.AccountFlags()) do
		C_CVar.SetCVarBitfield(ACCOUNT_FLAGS, flag, true)
	end

	if C_CVar.GetCVarInfo(CHARACTER_FLAGS) ~= nil then
		for flag = 1, self.CharacterCount() do
			C_CVar.SetCVarBitfield(CHARACTER_FLAGS, flag, true)
		end
	end
end
