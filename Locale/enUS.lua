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

-- Chat messages (Automation)
L["Sold 1 junk item for %s."] = "Sold 1 junk item for %s."
L["Sold %d junk items for %s."] = "Sold %d junk items for %s."
L["Repaired for %s."] = "Repaired for %s."
L["Repaired for %s from guild funds."] = "Repaired for %s from guild funds."
L["Not enough money to repair (%s)."] = "Not enough money to repair (%s)."
L["Not enough guild funds to repair (%s)."] = "Not enough guild funds to repair (%s)."
L["Nothing in the current expansion, so all expansions were searched."] =
	"Nothing in the current expansion, so all expansions were searched."

-- Chat messages (Macros)
L["General macros are full, so %s could not be made. Delete one and it will be added."] =
	"General macros are full, so %s could not be made. Delete one and it will be added."
L["%s was made, but the game could not find it by name, so it won't be made again until you reload."] =
	"%s was made, but the game could not find it by name, so it won't be made again until you reload."
L["Macros can't be picked up in combat."] = "Macros can't be picked up in combat."
L["Make room in General macros first."] = "Make room in General macros first."

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

-- Key bindings (Core)
L["Eject All Passengers"] = "Eject All Passengers"

-- Page titles (Settings)
L["Profiles"] = "Profiles"
L["Recovery"] = "Recovery"
L["Unit Frames"] = "Unit Frames"
L["Maps"] = "Maps"
L["Quality of Life"] = "Quality of Life"
L["Automation"] = "Automation"
L["Player Menu"] = "Player Menu"
L["Input"] = "Input"
L["Alerts"] = "Alerts"
L["Interface"] = "Interface"
L["Screen Text"] = "Screen Text"
L["Cursor"] = "Cursor"
L["Notifications"] = "Notifications"
L["Raid Markers"] = "Raid Markers"
L["Merchant Window"] = "Merchant Window"
L["Hidden Settings"] = "Hidden Settings"

-- Shared settings labels (Settings)
L["Herbs"] = "Herbs"
L["Auctionator, TSM or Oribos Exchange provides auction prices."] =
	"Auctionator, TSM or Oribos Exchange provides auction prices."
L["Access"] = "Access"
L["Text"] = "Text"
L["Open"] = "Open"
L["Font"] = "Font"
L["Outline"] = "Outline"
L["Font Scale"] = "Font Scale"
L["Height"] = "Height"
L["X Offset"] = "X Offset"
L["Y Offset"] = "Y Offset"
L["Scale"] = "Scale"
L["Crafting Orders"] = "Crafting Orders"
L["Modifier"] = "Modifier"
L["Not Managed"] = "Not Managed"
L["Always On"] = "Always On"
L["Always Off"] = "Always Off"
L["Shift"] = "Shift"
L["Ctrl"] = "Ctrl"
L["Alt"] = "Alt"
L["Visibility"] = "Visibility"
L["Show"] = "Show"
L["Size"] = "Size"
L["Border"] = "Border"
L["Border Style"] = "Border Style"
L["Forever Minimal"] = "Forever Minimal"
L["Forever"] = "Forever"
L["Slate"] = "Slate"
L["Thin Line"] = "Thin Line"
L["Border Color"] = "Border Color"
L["Needs a border style."] = "Needs a border style."
L["Forever keeps its own colors."] = "Forever keeps its own colors."
L["Border Thickness"] = "Border Thickness"
L["Casting"] = "Casting"
L["Class Color"] = "Class Color"
L["Texture"] = "Texture"
L["Horizontal"] = "Horizontal"
L["Vertical"] = "Vertical"
L["Left"] = "Left"
L["Right"] = "Right"
L["Bar"] = "Bar"
L["Tooltip"] = "Tooltip"
L["Blizzard"] = "Blizzard"
L["Square"] = "Square"
L["White"] = "White"
L["Width"] = "Width"

-- General page (Settings)
L["Show Minimap Button"] = "Show Minimap Button"
L["Left-click opens settings."] = "Left-click opens settings."
L["Goes below the game's own minimum. Turning it off needs a reload."] =
	"Goes below the game's own minimum. Turning it off needs a reload."
L["%s manages the UI scale."] = "%s manages the UI scale."
L["Pixel Perfect"] = "Pixel Perfect"
L["One interface unit per pixel on this screen."] = "One interface unit per pixel on this screen."
L["Pixel Perfect For"] = "Pixel Perfect For"
L["Game Menu Scale"] = "Game Menu Scale"

-- Release Spirit confirmation popup (Interface)
L["Do you want to release your spirit?"] = "Do you want to release your spirit?"

-- Automation page (Settings)
L["Sell Junk"] = "Sell Junk"
L["Report Sales"] = "Report Sales"
L["One chat line per visit."] = "One chat line per visit."
L["Auto Repair"] = "Auto Repair"
L["Funds"] = "Funds"
L["Guild First falls back to your money; Guild Only doesn't."] =
	"Guild First falls back to your money; Guild Only doesn't."
L["Personal"] = "Personal"
L["Guild First"] = "Guild First"
L["Guild Only"] = "Guild Only"
L["Remember Recipient"] = "Remember Recipient"
L["Hold Shift as a merchant opens to skip both."] = "Hold Shift as a merchant opens to skip both."
L["Money Subject"] = "Money Subject"
L["Fills an empty subject with Money when you send gold."] = "Fills an empty subject with Money when you send gold."
L["Auction House"] = "Auction House"
L["An Auction House search that finds nothing tries every expansion."] =
	"An Auction House search that finds nothing tries every expansion."
L["Game Settings"] = "Game Settings"
L["Auto Loot"] = "Auto Loot"
L["Weather"] = "Weather"
L["Blocks"] = "Blocks"
L["Block Trades"] = "Block Trades"
L["Block Guild Invites"] = "Block Guild Invites"
L["Block Channel Invites"] = "Block Channel Invites"
L["Block Duels"] = "Block Duels"
L["Includes duels to the death."] = "Includes duels to the death."
L["Blocked"] = "Blocked"

-- Delete Cheapest Item page (Settings)
L["Suggest Items to Delete"] = "Suggest Items to Delete"
L["Open Automatically"] = "Open Automatically"
L["Loot Doesn't Fit"] = "Loot Doesn't Fit"
L["Loot With Few Free Slots"] = "Loot With Few Free Slots"
L["Purchase Doesn't Fit"] = "Purchase Doesn't Fit"
L["Quest Rewards Don't Fit"] = "Quest Rewards Don't Fit"
L["List"] = "List"
L["Highest Quality"] = "Highest Quality"
L["Price"] = "Price"
L["Higher"] = "Higher"
L["Leave Out Soulbound Items"] = "Leave Out Soulbound Items"
L["Leave Out Worthless Items"] = "Leave Out Worthless Items"
L["Open Window"] = "Open Window"
L["Or type /aui dci."] = "Or type /aui dci."
L["Ignored Items"] = "Ignored Items"
L["Right-click an item in the window to stop suggesting it."] =
	"Right-click an item in the window to stop suggesting it."

-- Merchant Window page (Settings)
L["Item Grid"] = "Item Grid"
L["Extend Merchant Window"] = "Extend Merchant Window"
L["%s resizes the merchant window."] = "%s resizes the merchant window."
L["Fill Order"] = "Fill Order"
L["Rows First"] = "Rows First"
L["Columns First"] = "Columns First"
L["Show All Items"] = "Show All Items"

-- Hidden Settings page (Settings)
L["Loot Sparkles"] = "Loot Sparkles"
L["Ore"] = "Ore"
L["Quest Objects"] = "Quest Objects"
L["Corpses with Loot"] = "Corpses with Loot"
L["Chests"] = "Chests"
L["Fishing Bobber"] = "Fishing Bobber"
L["Approached objects use the game's soft targeting: while one of them is on, the Interact Key reaches all around you."] =
	"Approached objects use the game's soft targeting: while one of them is on, the Interact Key reaches all around you."
-- Space-separated words a chest's name starts or ends with, in this language (HiddenSettings/Target.lua).
L["chest strongbox lockbox coffer footlocker trunk"] = "chest strongbox lockbox coffer footlocker trunk"
L["The sparkle stays until the game restarts. /reload is not enough."] =
	"The sparkle stays until the game restarts. /reload is not enough."

-- Macros page (Settings)
L["Food"] = "Food"
L["Food Macro"] = "Food Macro"
L["Your best food and drink, kept current as %s."] = "Your best food and drink, kept current as %s."
L["Food Only"] = "Food Only"
L["Leaves the drink to %s."] = "Leaves the drink to %s."
L["Mana Potion in Combat"] = "Mana Potion in Combat"
L["Place on a Bar"] = "Place on a Bar"
L["Pick Up"] = "Pick Up"
L["Drink"] = "Drink"
L["Drink Macro"] = "Drink Macro"
L["Your best drink, kept current as %s."] = "Your best drink, kept current as %s."
L["Health Macro"] = "Health Macro"
L["Your best healthstone and healing potions, kept current as %s."] =
	"Your best healthstone and healing potions, kept current as %s."
L["Bandage"] = "Bandage"
L["Bandage Macro"] = "Bandage Macro"
L["Your best bandage, on yourself, kept current as %s."] = "Your best bandage, on yourself, kept current as %s."

-- Player Menu page (Settings)
L["Guild Invite"] = "Guild Invite"

-- Player menus (Menus; the title also names its card on the Player Menu page)
L["External Links"] = "External Links"
L["Press Ctrl+C to copy."] = "Press Ctrl+C to copy."

-- Input page (Settings)
L["Cast on Key Down"] = "Cast on Key Down"
L["In Combat Only"] = "In Combat Only"
L["Focus Keybind"] = "Focus Keybind"
L["Focus on Click"] = "Focus on Click"
L["Mouse Button"] = "Mouse Button"
L["Ctrl + Shift"] = "Ctrl + Shift"
L["Alt + Shift"] = "Alt + Shift"
L["Alt + Ctrl"] = "Alt + Ctrl"
L["Left Button"] = "Left Button"
L["Right Button"] = "Right Button"
L["Middle Button"] = "Middle Button"
L["Button 4"] = "Button 4"
L["Button 5"] = "Button 5"
L["World Clicks"] = "World Clicks"
L["Empty ground clears focus."] = "Empty ground clears focus."
L["Mark Focus"] = "Mark Focus"
L["Never replaces an existing marker."] = "Never replaces an existing marker."
L["Marker"] = "Marker"
L["Clique handles unit frames; bind Focus there."] = "Clique handles unit frames; bind Focus there."
L["Short Key Labels"] = "Short Key Labels"
L["Shows Shift + Mouse Button 4 as %s."] = "Shows Shift + Mouse Button 4 as %s."

-- Action button key labels (Input): modifier codes for Shift, Ctrl, Alt and Command, then key codes for mouse
-- buttons (M4), middle mouse, mouse wheel up and down, number pad keys (N5), Space, Page Up, Page Down, Backspace,
-- Insert, Delete, Home, End and Tab. Keep each to a few letters.
L["S"] = "S"
L["C"] = "C"
L["A"] = "A"
L["Cmd"] = "Cmd"
L["M%s"] = "M%s"
L["MM"] = "MM"
L["WU"] = "WU"
L["WD"] = "WD"
L["N%s"] = "N%s"
L["SP"] = "SP"
L["PU"] = "PU"
L["PD"] = "PD"
L["BS"] = "BS"
L["INS"] = "INS"
L["DEL"] = "DEL"
L["HM"] = "HM"
L["END"] = "END"
L["TAB"] = "TAB"

-- Alerts page (Settings)
L["Sound Alerts"] = "Sound Alerts"
L["Queue Pops"] = "Queue Pops"
L["Ready and Role Checks"] = "Ready and Role Checks"
L["Whispers"] = "Whispers"
L["Party Invites"] = "Party Invites"
L["Boss Emotes"] = "Boss Emotes"
L["Also plays on the Master channel, so you hear them with sound effects off."] = "Also plays on the Master channel, so you hear them with sound effects off."
L["Group Finder"] = "Group Finder"
L["Joined Group in Chat"] = "Joined Group in Chat"

-- Interface page (Settings)
L["Extra Action Button"] = "Extra Action Button"
L["Click-Through Art"] = "Click-Through Art"
L["Hide Art"] = "Hide Art"
L["Help Tips"] = "Help Tips"
L["Turning it off doesn't bring them back."] = "Turning it off doesn't bring them back."
L["Boss Banner"] = "Boss Banner"
L["Great Vault Overlay"] = "Great Vault Overlay"
L["The cover shown when you open it away from the vault."] = "The cover shown when you open it away from the vault."
L["Pop-ups"] = "Pop-ups"
L["Skip Accept Countdowns"] = "Skip Accept Countdowns"
L["Great Vault and item upgrade pop-ups."] = "Great Vault and item upgrade pop-ups."
L["Hold to Skip"] = "Hold to Skip"
L["No Key"] = "No Key"
L["Auto Confirm Bind on Pickup"] = "Auto Confirm Bind on Pickup"
L["Easy Item Destroy"] = "Easy Item Destroy"
L["No need to type \"%s\" to destroy an item."] = "No need to type \"%s\" to destroy an item."
L["Click-Through Toasts"] = "Click-Through Toasts"
L["Level-up and new-zone banners; clicking no longer opens their details."] = "Level-up and new-zone banners; clicking no longer opens their details."
L["Confirm Release Spirit"] = "Confirm Release Spirit"
L["Release Spirit stays disabled until you answer Yes."] = "Release Spirit stays disabled until you answer Yes."
L["Trading Post"] = "Trading Post"
L["Disable Combat Previews"] = "Disable Combat Previews"
L["Each item's preview starts without its combat animation."] = "Each item's preview starts without its combat animation."

-- Screen Text page (Settings)
L["Style Screen Text"] = "Style Screen Text"
L["All Text"] = "All Text"
L["Errors and Objectives"] = "Errors and Objectives"
L["Subzone"] = "Subzone"
L["PvP Status"] = "PvP Status"

-- Cursor page (Settings)
L["Show Cursor Ring"] = "Show Cursor Ring"
L["Ring"] = "Ring"
L["Thickness"] = "Thickness"
L["Thin"] = "Thin"
L["Normal"] = "Normal"
L["Thick"] = "Thick"
L["Center Dot"] = "Center Dot"
L["Swipes"] = "Swipes"
L["Global Cooldown"] = "Global Cooldown"
L["Casts"] = "Casts"
L["In Combat"] = "In Combat"
L["In Instances"] = "In Instances"
L["Hide While Turning the Camera"] = "Hide While Turning the Camera"
L["Idle"] = "Idle"

-- Notifications page and its notices (Settings, Notifications)
L["Entering Combat"] = "Entering Combat"
L["Leaving Combat"] = "Leaving Combat"
L["Potion Ready"] = "Potion Ready"
L["Pet Missing"] = "Pet Missing"
L["Pet Passive"] = "Pet Passive"
L["Pet Low Health"] = "Pet Low Health"
L["Unspent Talent Points"] = "Unspent Talent Points"
L["Low Durability"] = "Low Durability"
L["In combat or in instances."] = "In combat or in instances."
L["Out of combat."] = "Out of combat."
L["Duration"] = "Duration"
L["Show Below"] = "Show Below"
L["+Combat"] = "+Combat"
L["-Combat"] = "-Combat"
L["Low Health"] = "Low Health"
L["Not Tracking"] = "Not Tracking"
L["Outside instances."] = "Outside instances."
L["Remind About"] = "Remind About"
L["Beasts"] = "Beasts"
L["Humanoids"] = "Humanoids"
L["Undead"] = "Undead"
L["Hidden"] = "Hidden"
L["Elementals"] = "Elementals"
L["Demons"] = "Demons"
L["Giants"] = "Giants"
L["Dragonkin"] = "Dragonkin"
L["Treasure"] = "Treasure"
L["Minerals"] = "Minerals"

-- Raid Markers page (Settings)
L["Show Bar"] = "Show Bar"
L["In Group"] = "In Group"
L["In Group or With a Target"] = "In Group or With a Target"
L["Show On Mouseover"] = "Show On Mouseover"
L["Tooltips"] = "Tooltips"
L["Button Feedback"] = "Button Feedback"
L["Highlight Border"] = "Highlight Border"
L["Grow on Hover"] = "Grow on Hover"
L["Shrink on Press"] = "Shrink on Press"
L["Buttons"] = "Buttons"
L["Countdown Seconds"] = "Countdown Seconds"
L["Layout"] = "Layout"
L["Orientation"] = "Orientation"
L["Button Size"] = "Button Size"
L["Spacing"] = "Spacing"
L["Needs a Forever or Slate border style."] = "Needs a Forever or Slate border style."
L["World Marker Cycle"] = "World Marker Cycle"
L["Bind Place Next World Marker and Clear World Markers under AeonUI."] = "Bind Place Next World Marker and Clear World Markers under AeonUI."
L["World Marker Order"] = "World Marker Order"

-- Raid Markers Bar: edit mode, tooltips and key bindings (Markers)
L["Raid Markers Bar"] = "Raid Markers Bar"
L["Click"] = "Click"
L["Right-Click"] = "Right-Click"
L["Shift-Click"] = "Shift-Click"
L["Mark or unmark your target"] = "Mark or unmark your target"
L["Place or remove the world marker"] = "Place or remove the world marker"
L["Clear your target's marker"] = "Clear your target's marker"
L["Clear every raid target"] = "Clear every raid target"
L["Clear every world marker"] = "Clear every world marker"
L["Start a ready check"] = "Start a ready check"
L["Start a role check"] = "Start a role check"
L["Turn combat logging on or off"] = "Turn combat logging on or off"
L["Start a %d-second pull countdown"] = "Start a %d-second pull countdown"
L["Cancel the countdown"] = "Cancel the countdown"
L["Place Next World Marker"] = "Place Next World Marker"
L["Clear World Markers"] = "Clear World Markers"

-- Shared by the world map marker tooltips (World Map) and the Delete Cheapest Item rows (DeleteCheapestItem)
L["Vendor"] = "Vendor"

-- Shared by the Delete Cheapest Item rows (DeleteCheapestItem) and the item tooltips' auction price line on a
-- client without realms (Tooltip)
L["Auction"] = "Auction"

-- Delete Cheapest Item window, key binding and messages (DeleteCheapestItem)
L["Delete Cheapest Item"] = "Delete Cheapest Item"
L["Delete Cheapest Item is off. Turn it on in AeonUI's settings."] =
	"Delete Cheapest Item is off. Turn it on in AeonUI's settings."
L["Bags Full"] = "Bags Full"
L["Space"] = "Space"
L["1 free slot"] = "1 free slot"
L["%d free slots"] = "%d free slots"
L["Looting %s · %s"] = "Looting %s · %s"
L["Sell the cheapest to make room."] = "Sell the cheapest to make room."
L["%d stacks"] = "%d stacks"
L["More than the loot"] = "More than the loot"
L["Delete %s"] = "Delete %s"
L["Nothing to suggest. Ignored items and items above %s aren't listed."] =
	"Nothing to suggest. Ignored items and items above %s aren't listed."
L["Confirm"] = "Confirm"
L["Sell"] = "Sell"
L["Sell %s"] = "Sell %s"
L["Delete %s, then loot %s"] = "Delete %s, then loot %s"
L["Never Suggest"] = "Never Suggest"
L["Link in Chat"] = "Link in Chat"
L["Won't suggest %s."] = "Won't suggest %s."
L["Undo"] = "Undo"

-- Profiles page (Settings)
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
L["Reset Saved Settings"] = "Reset Saved Settings"
L["Erase every AeonUI profile and setting on this account and start again with defaults."] =
	"Erase every AeonUI profile and setting on this account and start again with defaults."
L["Erase every AeonUI profile and setting on this account? This cannot be undone."] =
	"Erase every AeonUI profile and setting on this account? This cannot be undone."
L["Type %s to erase every AeonUI profile and setting on this account."] =
	"Type %s to erase every AeonUI profile and setting on this account."

-- Shared by the world map and other features
L["Azuregos"] = "Azuregos"
L["Dungeon"] = "Dungeon"
L["Raid"] = "Raid"
L["Innkeeper"] = "Innkeeper"
L["Mailbox"] = "Mailbox"
L["Banker"] = "Banker"
L["Auctioneer"] = "Auctioneer"
L["Reagents"] = "Reagents"
L["Ammunition"] = "Ammunition"
