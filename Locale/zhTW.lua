if GetLocale() ~= "zhTW" then
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

-- Unit frame status text (Frames)
-- L["Ghost"] = "Ghost"

-- Profile strings (Profile)
-- L["This is not an AeonUI profile string, or it was cut short."] = "This is not an AeonUI profile string, or it was cut short."
-- L["This profile string was made by a newer version of AeonUI."] = "This profile string was made by a newer version of AeonUI."
-- L["This profile string holds settings AeonUI can't use."] = "This profile string holds settings AeonUI can't use."

-- Settings window categories (Settings)
-- L["Unit Frames"] = "Unit Frames"
-- L["Profiles"] = "Profiles"
-- L["Recovery"] = "Recovery"

-- Settings strings on several unit-frame pages (Settings)
-- L["Layout"] = "Layout"
-- L["Width"] = "Width"
-- L["Height"] = "Height"
-- L["X Offset"] = "X Offset"
-- L["Y Offset"] = "Y Offset"
-- L["Numbers"] = "Numbers"
-- L["Abbreviation"] = "Abbreviation"
-- L["Percent Decimals"] = "Percent Decimals"
-- L["Blizzard Default"] = "Blizzard Default"
-- L["One Decimal"] = "One Decimal"
-- L["Font"] = "Font"
-- L["Size"] = "Size"
-- L["Outline"] = "Outline"
-- L["Thick Outline"] = "Thick Outline"
-- L["Power"] = "Power"
-- L["Player Power"] = "Player Power"

-- Globals page (Settings)
-- L["Globals"] = "Globals"
-- L["How large numbers are shortened, such as 588K or 588.4K."] = "How large numbers are shortened, such as 588K or 588.4K."

-- Player, Target, Target of Target and Focus pages (Settings)
-- L["Show Player Frame"] = "Show Player Frame"
-- L["Show Target Frame"] = "Show Target Frame"
-- L["Target of Target"] = "Target of Target"
-- L["Show Target of Target Frame"] = "Show Target of Target Frame"
-- L["Focus"] = "Focus"
-- L["Show Focus Frame"] = "Show Focus Frame"
-- L["Show Power Bar"] = "Show Power Bar"
-- L["A power bar under health. It adds to the frame's height."] = "A power bar under health. It adds to the frame's height."
-- L["Power Bar Height"] = "Power Bar Height"
-- L["Reverse Fill"] = "Reverse Fill"
-- L["Fill the bar from right to left."] = "Fill the bar from right to left."
-- L["Global (%s)"] = "Global (%s)"

-- Player Power page (Settings)
-- L["Show Player Power Bar"] = "Show Player Power Bar"

-- Text and Text Slots sections (Settings)
-- L["Text"] = "Text"
-- L["Status Text In"] = "Status Text In"
-- L["Status Line"] = "Status Line"
-- L["Show Offline, Ghost or Dead at the right of the bar when no text slot shows the status."] = "Show Offline, Ghost or Dead at the right of the bar when no text slot shows the status."
-- L["The slot that shows Offline, Ghost or Dead in place of health. Other health text hides meanwhile."] = "The slot that shows Offline, Ghost or Dead in place of health. Other health text hides meanwhile."
-- L["Text %d"] = "Text %d"
-- L["Name Format"] = "Name Format"
-- L["First Name"] = "First Name"
-- L["Full Name"] = "Full Name"
-- L["Text Slots"] = "Text Slots"
-- L["Use Text Style"] = "Use Text Style"
-- L["This slot uses the frame's text style."] = "This slot uses the frame's text style."
-- L["Copy Text From"] = "Copy Text From"
-- L["Copy"] = "Copy"
-- L["Replace this frame's text with the text of %s?"] = "Replace this frame's text with the text of %s?"
-- L["Slot"] = "Slot"
-- L["Text %d: %s"] = "Text %d: %s"
-- L["Content"] = "Content"
-- L["Level + Name"] = "Level + Name"
-- L["Health %"] = "Health %"
-- L["Health + %"] = "Health + %"
-- L["Missing Health"] = "Missing Health"
-- L["Absorb"] = "Absorb"
-- L["Heal Absorb"] = "Heal Absorb"
-- L["Power %"] = "Power %"
-- L["Separator"] = "Separator"
-- L["Space"] = "Space"
-- L["Anchor"] = "Anchor"
-- L["Top Left"] = "Top Left"
-- L["Top"] = "Top"
-- L["Top Right"] = "Top Right"
-- L["Left"] = "Left"
-- L["Center"] = "Center"
-- L["Right"] = "Right"
-- L["Bottom Left"] = "Bottom Left"
-- L["Bottom"] = "Bottom"
-- L["Bottom Right"] = "Bottom Right"
-- L["Placement"] = "Placement"
-- L["Inside"] = "Inside"
-- L["On Edge"] = "On Edge"
-- L["Outside"] = "Outside"
-- L["Color Mode"] = "Color Mode"
-- L["Class / Reaction"] = "Class / Reaction"
-- L["Level Difficulty"] = "Level Difficulty"
-- L["Custom for this slot."] = "Custom for this slot."
-- L["Apply to All Frames"] = "Apply to All Frames"
-- L["Apply"] = "Apply"
-- L["Copy this slot's settings to the same slot on every other frame."] = "Copy this slot's settings to the same slot on every other frame."
-- L["Copy the settings of Text %d to the same slot on every other frame?"] = "Copy the settings of Text %d to the same slot on every other frame?"

-- Previews (Settings)
-- L["Full"] = "Full"
-- L["Damaged"] = "Damaged"
-- L["Half"] = "Half"
-- L["Empty"] = "Empty"
-- L["Sample Target"] = "Sample Target"
-- L["Sample Focus"] = "Sample Focus"

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
