local AUI = select(2, ...)

---@param _ table
---@param key string
---@return string
local function FallBackToKey(_, key)
	return key
end

---@class AUILocale : table<string, string>
local L = setmetatable({}, { __index = FallBackToKey })
AUI.L = L

-- Chat messages (Core)
L["AeonUI is off for this session, so its settings can't open."] =
	"AeonUI is off for this session, so its settings can't open."
L["your character could not be identified, so AeonUI is off for this session."] =
	"your character could not be identified, so AeonUI is off for this session."
L["saved settings failed to load, so AeonUI is off for this session."] =
	"saved settings failed to load, so AeonUI is off for this session."
L["saved settings come from a newer version of AeonUI, so this version is using default settings and leaves them unchanged."] =
	"saved settings come from a newer version of AeonUI, so this version is using default settings and leaves them unchanged."
L["saved settings are damaged, so AeonUI is using default settings and leaves them unchanged until you reset them."] =
	"saved settings are damaged, so AeonUI is using default settings and leaves them unchanged until you reset them."
L["the active profile can't be used, so AeonUI is showing default settings until you choose another profile."] =
	"the active profile can't be used, so AeonUI is showing default settings until you choose another profile."

-- Profile names (Profile)
L["A profile needs a name."] = "A profile needs a name."
L["A profile name can be %d letters at most."] = "A profile name can be %d letters at most."
L["That name belongs to the default profile."] = "That name belongs to the default profile."
L["A profile with that name already exists."] = "A profile with that name already exists."

-- Profile strings (Profile)
L["This is not an AeonUI profile string, or it was cut short."] =
	"This is not an AeonUI profile string, or it was cut short."
L["This profile string was made by a newer version of AeonUI."] =
	"This profile string was made by a newer version of AeonUI."
L["This profile string holds settings AeonUI can't use."] = "This profile string holds settings AeonUI can't use."

-- Minimap button tooltip (Core)
L["Click: open settings"] = "Click: open settings"

-- Page titles (Settings)
L["Profiles"] = "Profiles"
L["Recovery"] = "Recovery"

-- General page (Settings)
L["Settings for AeonUI as a whole. Each feature has its own page."] =
	"Settings for AeonUI as a whole. Each feature has its own page."
L["Access"] = "Access"
L["Show Minimap Button"] = "Show Minimap Button"
L["Left-click opens settings."] = "Left-click opens settings."
L["/aui and the addon compartment open settings too."] = "/aui and the addon compartment open settings too."

-- Minimap page (Settings)
L["A rectangular minimap with information rows, a border and zoom. Move it in Edit Mode."] =
	"A rectangular minimap with information rows, a border and zoom. Move it in Edit Mode."
L["Map"] = "Map"
L["Turning the minimap on or off takes effect after a /reload. While it is off, Blizzard's minimap is left as it is."] =
	"Turning the minimap on or off takes effect after a /reload. While it is off, Blizzard's minimap is left as it is."
L["Width"] = "Width"
L["Height"] = "Height"
L["Kept within 3:2 of the width either way."] = "Kept within 3:2 of the width either way."
L["Scale"] = "Scale"
L["The map stays north up while AeonUI's minimap is on, whatever the Rotate Minimap option says."] =
	"The map stays north up while AeonUI's minimap is on, whatever the Rotate Minimap option says."
L["Border"] = "Border"
L["Border Style"] = "Border Style"
L["Metal"] = "Metal"
L["Forever Minimal"] = "Forever Minimal"
L["Forever"] = "Forever"
L["Thin Line"] = "Thin Line"
L["Border Color"] = "Border Color"
L["Needs a border style."] = "Needs a border style."
L["Forever keeps its own colors."] = "Forever keeps its own colors."
L["Border Thickness"] = "Border Thickness"
L["Compared with Blizzard's own frames. A map too small for the corners draws them smaller."] =
	"Compared with Blizzard's own frames. A map too small for the corners draws them smaller."
L["Needs a Metal or Forever border style."] = "Needs a Metal or Forever border style."
L["Shows behind the map's information rows."] = "Shows behind the map's information rows."
L["Rows"] = "Rows"
L["Row Height"] = "Row Height"
L["Every row's height. Buttons are square at it."] = "Every row's height. Buttons are square at it."
L["Text Size"] = "Text Size"
L["Zone Text Size"] = "Zone Text Size"
L["Fading"] = "Fading"
L["Fade Until Mouseover"] = "Fade Until Mouseover"
L["Mouseover Opacity"] = "Mouseover Opacity"
L["How visible the minimap stays while the mouse is away."] =
	"How visible the minimap stays while the mouse is away."
L["Needs Fade Until Mouseover."] = "Needs Fade Until Mouseover."
L["Fade in Combat"] = "Fade in Combat"
L["Combat Opacity"] = "Combat Opacity"
L["How visible the minimap stays in combat. The mouse brings it back."] =
	"How visible the minimap stays in combat. The mouse brings it back."
L["Needs Fade in Combat."] = "Needs Fade in Combat."
L["Zoom"] = "Zoom"
L["Zoom with Mouse Wheel"] = "Zoom with Mouse Wheel"
L["Reset Zoom After"] = "Reset Zoom After"
L["Returns to the widest view this long after the last zoom."] =
	"Returns to the widest view this long after the last zoom."
L["Never"] = "Never"
L["%d s"] = "%d s"

-- Profiles page (Settings)
L["Keep different setups of AeonUI, and share them as text."] =
	"Keep different setups of AeonUI, and share them as text."
L["AeonUI profile \"%s\"."] = "AeonUI profile \"%s\"."
L["It holds %d settings this version doesn't use; they are kept."] =
	"It holds %d settings this version doesn't use; they are kept."
L["Damaged Profiles"] = "Damaged Profiles"
L["The active profile can't be used, so default settings are shown. Choose another profile or delete it."] =
	"The active profile can't be used, so default settings are shown. Choose another profile or delete it."
L["These profiles can't be used. They are kept unchanged until you delete them."] =
	"These profiles can't be used. They are kept unchanged until you delete them."
L["Delete the damaged profile \"%s\"? Characters using it switch to another profile."] =
	"Delete the damaged profile \"%s\"? Characters using it switch to another profile."
L["Create another profile first."] = "Create another profile first."

-- Recovery page (Settings)
L["AeonUI's saved settings can't be used, so its other pages are unavailable."] =
	"AeonUI's saved settings can't be used, so its other pages are unavailable."
L["Saved Settings"] = "Saved Settings"
L["Your saved settings are damaged. AeonUI shows default settings and leaves them unchanged until you reset them."] =
	"Your saved settings are damaged. AeonUI shows default settings and leaves them unchanged until you reset them."
L["Your saved settings come from a newer version of AeonUI. This version shows default settings and leaves them unchanged."] =
	"Your saved settings come from a newer version of AeonUI. This version shows default settings and leaves them unchanged."
L["Diagnostic Export"] = "Diagnostic Export"
L["Diagnostic Export (Incomplete)"] = "Diagnostic Export (Incomplete)"
L["The saved settings as text, to keep or to share when reporting the problem. It is not a profile string."] =
	"The saved settings as text, to keep or to share when reporting the problem. It is not a profile string."
L["Show"] = "Show"
L["Reset Saved Settings"] = "Reset Saved Settings"
L["Erase every AeonUI profile and setting on this account and start again with defaults."] =
	"Erase every AeonUI profile and setting on this account and start again with defaults."
L["Erase every AeonUI profile and setting on this account? This cannot be undone."] =
	"Erase every AeonUI profile and setting on this account? This cannot be undone."
L["Type %s to erase every AeonUI profile and setting on this account."] =
	"Type %s to erase every AeonUI profile and setting on this account."
