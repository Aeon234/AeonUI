local AUI = select(2, ...)

local L = AUI.L

-- The word the player types to confirm erasing the saved data.
local CONFIRM_WORD = "RESET"

local EXPORT_POPUP = "AEONUI_DIAGNOSTIC_EXPORT"
local RESET_POPUP = "AEONUI_RESET_SAVED_SETTINGS"

---The Recovery page, the window's only page while the saved data cannot be used: what happened, a diagnostic export
---of the data, and an explicit reset that reloads the interface on the new store.
---@class AUISettingsRecovery
local Recovery = {}
AUI.SettingsRecovery = Recovery

StaticPopupDialogs[EXPORT_POPUP] = {
	text = "%s",
	button1 = CLOSE,
	hasEditBox = true,
	editBoxWidth = 350,
	maxLetters = 0,
	OnShow = function(dialog, data)
		local editBox = dialog:GetEditBox()

		editBox:SetText(data.text)
		editBox:HighlightText()
		editBox:SetFocus()
	end,
	EditBoxOnTextChanged = function(editBox, data)
		if editBox:GetText() ~= data.text then
			editBox:SetText(data.text)
			editBox:HighlightText()
		end
	end,
	EditBoxOnEscapePressed = StaticPopup_StandardEditBoxOnEscapePressed,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

StaticPopupDialogs[RESET_POPUP] = {
	text = "%s",
	button1 = RESET,
	button2 = CANCEL,
	hasEditBox = true,
	maxLetters = 16,
	OnShow = function(dialog)
		dialog:GetButton1():Disable()
		dialog:GetEditBox():SetFocus()
	end,
	EditBoxOnTextChanged = function(editBox)
		StaticPopup_StandardConfirmationTextHandler(editBox, CONFIRM_WORD)
	end,
	-- Enter accepts only once the word matches, as the Reset button does.
	EditBoxOnEnterPressed = function(editBox)
		local dialog = editBox:GetParent()

		if dialog:GetButton1():IsEnabled() then
			StaticPopup_OnClick(dialog, 1)
		end
	end,
	EditBoxOnEscapePressed = StaticPopup_StandardEditBoxOnEscapePressed,
	OnAccept = function()
		Recovery:Reset()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

function Recovery:ShowExport()
	local text, complete = AUI.Profile:RawExport()
	local title = complete and L["Diagnostic Export"] or L["Diagnostic Export (Incomplete)"]

	StaticPopup_Show(EXPORT_POPUP, title, nil, { text = text or "" })
end

---Replaces the saved data with a new store, then reloads the interface so every page is declared on it.
function Recovery:Reset()
	local ok, problem = AUI.Profile:ResetStore()

	if not ok then
		AUI:Warn(tostring(problem))

		return
	end

	ReloadUI()
end

---@param window table
function Recovery:Declare(window)
	local profile = AUI.Profile
	local page = window:Page("recovery", {
		title = L["Recovery"],
		description = AUI:Branded(L["AeonUI's saved settings can't be used, so its other pages are unavailable."]),
	})

	if not page then
		return
	end

	local section = page:Section("recovery", L["Saved Settings"])

	section:Note(profile.newer
		and AUI:Branded(L["Your saved settings come from a newer version of AeonUI. This version shows default settings and leaves them unchanged."])
		or AUI:Branded(L["Your saved settings are damaged. AeonUI shows default settings and leaves them unchanged until you reset them."]),
		tostring(profile.problem or ""))
	section:Button({
		id = "export",
		label = L["Diagnostic Export"],
		description = L["The saved settings as text, to keep or to share when reporting the problem. It is not a profile string."],
		verb = L["Show"],
		run = function()
			Recovery:ShowExport()
		end,
	})
	section:Button({
		id = "reset",
		label = L["Reset Saved Settings"],
		description = AUI:Branded(L["Erase every AeonUI profile and setting on this account and start again with defaults."]),
		verb = RESET,
		confirm = AUI:Branded(L["Erase every AeonUI profile and setting on this account? This cannot be undone."]),
		run = function()
			StaticPopup_Show(RESET_POPUP, AUI:Branded(L["Type %s to erase every AeonUI profile and setting on this account."]):format(CONFIRM_WORD))
		end,
	})
end
