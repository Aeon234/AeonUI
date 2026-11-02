local AUI = select(2, ...)

local L = AUI.L

-- AeonUI's section in Blizzard's Key Bindings, named by each binding's category in Bindings.xml, and the names of the
-- bindings whose Lua runs there.
BINDING_HEADER_AEONUI = AUI.brand
BINDING_NAME_AEONUI_RELOAD = RELOADUI
BINDING_NAME_AEONUI_EJECT = L["Eject All Passengers"]

---AeonUI's key bindings: Reload UI and Eject All Passengers here, the World Marker Cycle's in the Raid Markers module.
---@class AUIBindings
local Bindings = {}
AUI.Bindings = Bindings

---Opens Blizzard's Key Bindings at AeonUI's section.
function Bindings:Open()
	Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID, BINDING_HEADER_AEONUI)
end
