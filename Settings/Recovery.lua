local AUI = select(2, ...)

local L = AUI.L
local AS = AUI.AeonSettings --[[@as table]]
local Pages = AUI.SettingsPages

-- The word the player types to confirm erasing the saved data.
local CONFIRM_WORD = "RESET"

---The Recovery page, shown in place of the other pages while the saved data cannot be used: what happened, a
---diagnostic export of the data, and an explicit reset.
---@class AUISettingsRecovery
local Recovery = {}
AUI.SettingsRecovery = Recovery

function Recovery:ShowExport()
	local text, complete = AUI.Profile:RawExport()

	AS:ProfileDialogFrame():Open("export", {
		title = complete and L["Diagnostic Export"] or L["Diagnostic Export (Incomplete)"],
		text = text or "",
	})
end

function Recovery:AskReset()
	AS:ProfileDialogFrame():Open("name", {
		title = L["Reset Saved Settings"],
		message = L["Type %s to erase every AeonUI profile and setting on this account."]:format(CONFIRM_WORD),
		verb = RESET,
		validate = function(text)
			if text ~= CONFIRM_WORD then
				return ""
			end
		end,
		accept = function()
			local ok, problem = AUI.Profile:ResetStore()

			if not ok then
				AUI:Warn(tostring(problem))
			end
		end,
	})
end

---@return table[] elements
local function Build()
	local profile = AUI.Profile

	return {
		Pages.Section("recovery", L["Saved Settings"]),
		{
			kind = "note",
			id = "explanation",
			text = profile.newer
					and L["Your saved settings come from a newer version of AeonUI. This version shows default settings and leaves them unchanged."]
				or L["Your saved settings are damaged. AeonUI shows default settings and leaves them unchanged until you reset them."],
		},
		{ kind = "note", id = "problem", text = tostring(profile.problem or ""), small = true },
		Pages.Row({
			id = "export",
			control = "action",
			label = L["Diagnostic Export"],
			description = L["The saved settings as text, to keep or to share when reporting the problem. It is not a profile string."],
			verb = L["Show"],
			set = function()
				Recovery:ShowExport()

				return true
			end,
		}),
		Pages.Row({
			id = "reset",
			control = "action",
			label = L["Reset Saved Settings"],
			description = L["Erase every AeonUI profile and setting on this account and start again with defaults."],
			verb = RESET,
			confirm = L["Erase every AeonUI profile and setting on this account? This cannot be undone."],
			set = function()
				Recovery:AskReset()

				return true
			end,
		}),
	}
end

---@return table page
function Recovery:Page()
	return { id = "recovery", title = L["Recovery"], Build = Build }
end
