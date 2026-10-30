-- Development self-tests run in game through the client's native APIs. Not packaged.
local AUI = select(2, ...)

local Codec = AUI.Codec

---@class AUIDev
---@field MinimapProbe AUIMinimapProbe? the M0 minimap probe, from Dev/MinimapProbe.lua
---@field WorldMapProbe AUIWorldMapProbe? the W0 world map probe, from Dev/WorldMapProbe.lua
---@field DeleteCheapestItemProbe AUIDeleteCheapestItemProbe? the S0 Delete Cheapest Item probe, from
---Dev/DeleteCheapestItemProbe.lua
local Dev = {}
AUI.Dev = Dev

-- Values that stress CBOR and Deflate: zero, false, fractions, huge numbers, Unicode, arrays and nesting.
local FIXTURE = {
	zero = 0,
	disabled = false,
	fraction = 0.375,
	negative = -7.5,
	large = 1e100,
	unicode = "AeonUI — 雪 Ω",
	array = { "alpha", 0, false },
	nested = { offset = { x = 0, y = -7.5 } },
	dormant = { future = { kept = true } },
}

---@param a any
---@param b any
---@return boolean same whether both hold the same keys and values
local function Same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end

	for key, value in pairs(a) do
		if not Same(value, b[key]) then
			return false
		end
	end

	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end

	return true
end

---Runs every codec case against the real `C_EncodingUtil` and prints each result.
function Dev:Codec()
	local passed, failed = 0, 0

	local function Case(name, ok, detail)
		if ok then
			passed = passed + 1
			AUI:Print("|cff40ff40pass|r %s%s", name, detail and ("  (" .. detail .. ")") or "")
		else
			failed = failed + 1
			AUI:Print("|cffff4040FAIL|r %s%s", name, detail and ("  (" .. detail .. ")") or "")
		end
	end

	local text = Codec:Encode(Codec.PREFIX, FIXTURE)

	Case("fixture encodes", type(text) == "string", text and (#text .. " characters"))

	if not text then
		return
	end

	local body = text:match("^AUI!%d+!(.*)$") or ""

	Case("fixture round trip is exact", Same(Codec:Decode(Codec.PREFIX, text), FIXTURE))

	local wrapped = text:sub(1, 20) .. "\n  " .. text:sub(21)

	Case("line breaks in pasted text are ignored", Same(Codec:Decode(Codec.PREFIX, wrapped), FIXTURE))

	local _, problem = Codec:Decode(Codec.PREFIX, "LB!1!" .. body)

	Case("another addon's prefix is refused", problem == "foreign", problem)

	_, problem = Codec:Decode(Codec.PREFIX, "AUI!2!" .. body)
	Case("a newer format is refused", problem == "newer", problem)

	_, problem = Codec:Decode(Codec.PREFIX, "AUI!1!@@@@")
	Case("characters outside Base64 are refused", problem == "damaged", problem)

	local cut = text:sub(1, math.floor(#text / 2))
	local decoded

	decoded, problem = Codec:Decode(Codec.PREFIX, cut)
	Case("a string cut in half is refused", decoded == nil, problem)

	local middle = math.floor(#body / 2)
	local flipped = body:sub(middle, middle) == "A" and "B" or "A"

	decoded, problem = Codec:Decode(Codec.PREFIX, "AUI!1!" .. body:sub(1, middle - 1) .. flipped .. body:sub(middle + 1))
	Case(
		"a changed character never decodes to the original",
		not Same(decoded, FIXTURE),
		decoded and "decoded to other data; payload validation must refuse it" or problem
	)

	local plain = C_EncodingUtil.EncodeBase64("not compressed at all")

	_, problem = Codec:Decode(Codec.PREFIX, "AUI!1!" .. plain)
	Case("Base64 that is not Deflate data is refused", problem == "damaged", problem)

	local notCBOR = C_EncodingUtil.EncodeBase64(
		C_EncodingUtil.CompressString("hello world", Enum.CompressionMethod.Deflate)
	)

	_, problem = Codec:Decode(Codec.PREFIX, "AUI!1!" .. notCBOR)
	Case("Deflate data that is not a CBOR table is refused", problem == "damaged", problem)

	local Profile = AUI.Profile

	if Profile.root and Profile.activeID then
		local exported = Profile:Export(Profile.activeID)
		local import, reason = Profile:Decode(exported or "")

		Case(
			"the active profile exports and decodes",
			import ~= nil and Same(import.config, Profile.root.profilesByID[Profile.activeID].config),
			reason or (exported and (#exported .. " characters"))
		)
	end

	local raw = Profile:RawExport()
	local import = raw and Profile:Decode(raw)

	Case("a recovery export encodes and is not a profile string", raw ~= nil and import == nil)

	AUI:Print("codec: %d passed, %d failed", passed, failed)
end

-- The atlases `/aui dev atlas` reports when it is given no names: Blizzard's metal window frame.
local METAL_ATLASES = {
	"UI-Frame-Metal-CornerTopLeft", "UI-Frame-Metal-CornerTopRight", "UI-Frame-Metal-CornerTopRightDouble",
	"UI-Frame-Metal-CornerBottomLeft", "UI-Frame-Metal-CornerBottomRight", "_UI-Frame-Metal-EdgeTop",
	"_UI-Frame-Metal-EdgeBottom", "!UI-Frame-Metal-EdgeLeft", "!UI-Frame-Metal-EdgeRight",
}

---Prints each atlas's size in UI units, its file and its texture coordinates, read from the running client.
---@param line string atlas names separated by spaces; the metal frame's when empty. Names are lowercased by the slash
---command, which atlas lookups ignore.
function Dev:Atlases(line)
	local names = {}

	for name in line:gmatch("%S+") do
		names[#names + 1] = name
	end

	if #names == 0 then
		names = METAL_ATLASES
	end

	local version, build = GetBuildInfo()

	AUI:Print("atlases on %s.%s:", tostring(version), tostring(build))

	for _, name in ipairs(names) do
		local info = C_Texture.GetAtlasInfo(name)

		if info then
			AUI:Print("%s: %d x %d, file %s, x %.4f-%.4f, y %.4f-%.4f, tiles %s/%s", name, info.width, info.height,
				tostring(info.filename or info.file), info.leftTexCoord, info.rightTexCoord, info.topTexCoord,
				info.bottomTexCoord, tostring(info.tilesHorizontally), tostring(info.tilesVertically))
		else
			AUI:Print("%s: no such atlas", name)
		end
	end
end

---@param frame table
---@return string text a frame's center, size and scale in screen pixels' units
local function Rect(frame)
	local x, y = frame:GetCenter()
	local scale = frame:GetEffectiveScale()

	return ("center %.1f, %.1f  size %.1f x %.1f  scale %.3f"):format((x or 0) * scale, (y or 0) * scale,
		frame:GetWidth() * scale, frame:GetHeight() * scale, scale)
end

---Prints where the Minimap module's frame and Blizzard's map are on screen, and the map's clamping.
function Dev:MapReport()
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
function Dev:PlaceElement(line)
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
function Dev:Mark(note)
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

---@param line string the words after `/aui dev`, lowercased
function Dev:Command(line)
	local command, rest = line:match("^(%S*)%s*(.-)$")

	if command == "codec" then
		self:Codec()

		return
	end

	if command == "map" then
		self:MapReport()

		return
	end

	if command == "atlas" then
		self:Atlases(rest)

		return
	end

	if command == "preview" then
		local elements = AUI.MinimapElements

		elements:SetPreview(not elements.previewers.dev, "dev")
		AUI:Print("preview: %s", elements.previewers.dev and "on" or "off")

		return
	end

	if command == "row" then
		self:PlaceElement(rest)

		return
	end

	if command == "minimap" and self.MinimapProbe then
		self.MinimapProbe:Command(rest)

		return
	end

	if command == "mark" then
		self:Mark(rest)

		return
	end

	if command == "worldmap" and self.WorldMapProbe then
		self.WorldMapProbe:Command(rest)

		return
	end

	if command == "dci" and self.DeleteCheapestItemProbe then
		self.DeleteCheapestItemProbe:Command(rest)

		return
	end

	AUI:Print("dev commands: codec, map, atlas [names], row, preview, minimap, worldmap, dci, mark [note]")
end
