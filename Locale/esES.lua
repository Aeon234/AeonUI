if GetLocale() ~= "esES" then
	return
end

local L = select(2, ...).L

-- Chat messages (Core)
-- L["the settings window is not available yet."] = "the settings window is not available yet."
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
