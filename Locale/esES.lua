if GetLocale() ~= "esES" then
	return
end

local L = select(2, ...).L

-- Chat messages (Core)
-- L["AeonUI is off for this session, so its settings can't open."] = "AeonUI is off for this session, so its settings can't open."
-- L["your character could not be identified, so AeonUI is off for this session."] = "your character could not be identified, so AeonUI is off for this session."
-- L["saved settings failed to load, so AeonUI is off for this session."] = "saved settings failed to load, so AeonUI is off for this session."
-- L["saved settings come from a newer version of AeonUI, so this version is using default settings and leaves them unchanged."] = "saved settings come from a newer version of AeonUI, so this version is using default settings and leaves them unchanged."
-- L["saved settings are damaged, so AeonUI is using default settings and leaves them unchanged until you reset them."] = "saved settings are damaged, so AeonUI is using default settings and leaves them unchanged until you reset them."
-- L["the active profile can't be used, so AeonUI is showing default settings until you choose another profile."] = "the active profile can't be used, so AeonUI is showing default settings until you choose another profile."

-- Profile names (Profile)
-- L["A profile needs a name."] = "A profile needs a name."
-- L["A profile name can be %d letters at most."] = "A profile name can be %d letters at most."
-- L["That name belongs to the default profile."] = "That name belongs to the default profile."
-- L["A profile with that name already exists."] = "A profile with that name already exists."

-- Profile strings (Profile)
-- L["This is not an AeonUI profile string, or it was cut short."] = "This is not an AeonUI profile string, or it was cut short."
-- L["This profile string was made by a newer version of AeonUI."] = "This profile string was made by a newer version of AeonUI."
-- L["This profile string holds settings AeonUI can't use."] = "This profile string holds settings AeonUI can't use."

-- Settings window categories (Settings)
-- L["Profiles"] = "Profiles"
-- L["Recovery"] = "Recovery"

-- Profiles page (Settings)
-- L["AeonUI profile \"%s\"."] = "AeonUI profile \"%s\"."
-- L["It holds %d settings this version doesn't use; they are kept."] = "It holds %d settings this version doesn't use; they are kept."
-- L["Damaged Profiles"] = "Damaged Profiles"
-- L["The active profile can't be used, so default settings are shown. Choose another profile or delete it."] = "The active profile can't be used, so default settings are shown. Choose another profile or delete it."
-- L["These profiles can't be used. They are kept unchanged until you delete them."] = "These profiles can't be used. They are kept unchanged until you delete them."
-- L["Delete the damaged profile \"%s\"? Characters using it switch to another profile."] = "Delete the damaged profile \"%s\"? Characters using it switch to another profile."
-- L["Create another profile first."] = "Create another profile first."

-- Recovery page (Settings)
-- L["Saved Settings"] = "Saved Settings"
-- L["Your saved settings are damaged. AeonUI shows default settings and leaves them unchanged until you reset them."] = "Your saved settings are damaged. AeonUI shows default settings and leaves them unchanged until you reset them."
-- L["Your saved settings come from a newer version of AeonUI. This version shows default settings and leaves them unchanged."] = "Your saved settings come from a newer version of AeonUI. This version shows default settings and leaves them unchanged."
-- L["Diagnostic Export"] = "Diagnostic Export"
-- L["Diagnostic Export (Incomplete)"] = "Diagnostic Export (Incomplete)"
-- L["The saved settings as text, to keep or to share when reporting the problem. It is not a profile string."] = "The saved settings as text, to keep or to share when reporting the problem. It is not a profile string."
-- L["Show"] = "Show"
-- L["Reset Saved Settings"] = "Reset Saved Settings"
-- L["Erase every AeonUI profile and setting on this account and start again with defaults."] = "Erase every AeonUI profile and setting on this account and start again with defaults."
-- L["Erase every AeonUI profile and setting on this account? This cannot be undone."] = "Erase every AeonUI profile and setting on this account? This cannot be undone."
-- L["Type %s to erase every AeonUI profile and setting on this account."] = "Type %s to erase every AeonUI profile and setting on this account."
