-- Development commands for the maps. Not packaged.
local AUI = select(2, ...)

---@param frame table
---@return string text a frame's center, size and scale in screen pixels' units
local function Rect(frame)
	local x, y = frame:GetCenter()
	local scale = frame:GetEffectiveScale()

	return ("center %.1f, %.1f  size %.1f x %.1f  scale %.3f"):format((x or 0) * scale, (y or 0) * scale,
		frame:GetWidth() * scale, frame:GetHeight() * scale, scale)
end

---Prints where the Minimap module's frame and Blizzard's map are on screen, and the map's clamping.
local function MapReport()
	local module = AUI.Minimap

	if not module.active then
		AUI:Print("map: the Minimap module is not active this session.")

		return
	end

	local left, right, top, bottom = Minimap:GetClampRectInsets()

	AUI:Print("map: screen %.0f x %.0f", GetPhysicalScreenSize())
	AUI:Print("holder: %s", Rect(module.holder --[[@as Frame]]))
	AUI:Print("Minimap: %s", Rect(Minimap))
	AUI:Print("clamped %s, clamp insets %.1f %.1f %.1f %.1f, mask %s", tostring(Minimap:IsClampedToScreen()), left,
		right, top, bottom, tostring(module.mask):match("[^\\]+$") or "?")
end

---Places a minimap row element.
---@param line string `<element> <top1|top2|bottom1|bottom2|hidden> [order]`, lowercased
local function PlaceElement(line)
	local key, row, order = line:match("^(%S+)%s+(%S+)%s*(%d*)$")
	local element = key and AUI.MinimapElements.byKey[key]

	if not element then
		local keys = {}

		for _, known in ipairs(AUI.MinimapElements.list) do
			keys[#keys + 1] = known.key
		end

		AUI:Print("usage: /aui dev row <%s> <top1|top2|bottom1|bottom2|hidden> [order]", table.concat(keys, "|"))

		return
	end

	local elements = AUI.MinimapElements

	if not tContains(elements.LISTS, row:upper()) then
		AUI:Print("row: %s is not a row", row)

		return
	end

	local layout = elements:Move(elements:Layout(), key, row:upper(), tonumber(order))
	local ok, problem = AUI.Profile:Set(elements.LAYOUT_PATH, layout)

	AUI:Print("row: %s %s", key, ok and "placed" or tostring(problem))
end

---Prints the player's position as a world map marker row, ready to paste into WorldMap/Data.lua under its map.
---@param note string anything typed after the command, printed beside the row
local function Mark(note)
	local mapID = C_Map.GetBestMapForUnit("player")
	local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")

	if not position then
		AUI:Print("mark: no map position here (inside an instance, or no map)")

		return
	end

	local x, y = position:GetXY()
	local info = C_Map.GetMapInfo(mapID)

	AUI:Print("mark: [%d] = { -- %s", mapID, info and info.name or "?")
	AUI:Print("  { %.1f, %.1f },%s", x * 100, y * 100, note ~= "" and (" -- " .. note) or "")
end

local Dev = AUI.Dev

Dev:Register("map", MapReport)
Dev:Register("row", PlaceElement)
Dev:Register("mark", Mark)
Dev:Register("preview", function()
	local elements = AUI.MinimapElements

	elements:SetPreview(not elements.previewers.dev, "dev")
	AUI:Print("preview: %s", elements.previewers.dev and "on" or "off")
end)
Dev:Register("minimap", function(rest)
	(Dev.MinimapProbe --[[@as AUIMinimapProbe]]):Command(rest)
end)
Dev:Register("worldmap", function(rest)
	(Dev.WorldMapProbe --[[@as AUIWorldMapProbe]]):Command(rest)
end)
