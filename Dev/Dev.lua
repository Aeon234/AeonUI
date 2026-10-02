-- Development self-tests run in game through the client's native APIs. Not packaged.
local AUI = select(2, ...)

local Codec = AUI.Codec

---@class AUIDev
---@field bossTest boolean? the boss frames show the player
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

---Shows the boss frames on the player, for placing them without an encounter, or returns them to their boss units.
---Changing a secure frame's unit is refused in combat.
function Dev:Bosses()
	local frames = AUI.Frames.objects.boss

	if not frames then
		AUI:Warn("the boss frames have not been created.")

		return
	end

	if InCombatLockdown() then
		AUI:Warn("boss test mode can only change out of combat.")

		return
	end

	self.bossTest = not self.bossTest

	for slot, frame in ipairs(frames) do
		frame:SetAttribute("unit", self.bossTest and "player" or ("boss" .. slot))
	end

	AUI:Print("boss test mode %s.", self.bossTest and "on: the boss frames show the player" or "off")
end

---@param command string
function Dev:Command(command)
	if command == "codec" then
		self:Codec()

		return
	end

	if command == "boss" then
		self:Bosses()

		return
	end

	AUI:Print("dev commands: codec, boss")
end
