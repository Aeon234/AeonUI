-- Checks Profile/Codec.lua and the Profile owner's export, decode, import and recovery export outside the game:
-- prefixes, formats, every stage failing or returning the wrong type, length limits, payload validation, dormant
-- settings and name rules on import.
-- Run from any directory with Lua 5.1: lua Tools/check_codec.lua
-- C_EncodingUtil is a stand-in that transforms and reverses data; it proves the stage order and error handling,
-- not Blizzard's CBOR, Deflate or Base64. `/aui dev codec` runs the real ones in game.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

UNKNOWN = "Unknown"
SlashCmdList = {}
C_AddOns = {
	GetAddOnMetadata = function() end,
}

function CallErrorHandler(message)
	error(message, 0)
end

local luaXpcall = xpcall
function xpcall(fn, handler, ...)
	local count, args = select("#", ...), { ... }

	return luaXpcall(function()
		return fn(unpack(args, 1, count))
	end, handler)
end

function strcmputf8i(a, b)
	a, b = a:lower(), b:lower()

	return a == b and 0 or (a < b and -1 or 1)
end

function strlenutf8(text)
	local _, count = text:gsub("[^\128-\191]", "")

	return count
end

function GetBuildInfo()
	return "1.60.1", "70124", "Sep 30 2026", 16001
end

Enum = { CompressionMethod = { Deflate = 0, Zlib = 1, Gzip = 2 } }

-- The stand-in keeps each serialized payload aside and names it with a token; compression wraps the text in
-- markers; Base64 becomes hexadecimal, whose digits are all Base64 characters.
local stored = {}
local fault = {}
local methods = {}

local function Hex(text)
	return (text:gsub(".", function(char)
		return ("%02x"):format(char:byte())
	end))
end

C_EncodingUtil = {
	SerializeCBOR = function(value)
		if fault.serialize then
			return fault.serialize(value)
		end
		stored[#stored + 1] = value

		return "cbor:" .. #stored
	end,
	DeserializeCBOR = function(text)
		if fault.deserialize then
			return fault.deserialize(text)
		end
		local index = tonumber(text:match("^cbor:(%d+)$"))
		if not index then
			error("not CBOR")
		end

		-- A real decoder builds new tables; so does this one.
		local function Copy(value)
			if type(value) ~= "table" then
				return value
			end
			local copy = {}
			for key, child in pairs(value) do
				copy[key] = Copy(child)
			end

			return copy
		end

		return Copy(stored[index])
	end,
	CompressString = function(text, method)
		methods[#methods + 1] = method
		if fault.compress then
			return fault.compress(text)
		end

		return "<" .. text .. ">"
	end,
	DecompressString = function(text, method)
		methods[#methods + 1] = method
		local inner = text:match("^<(.*)>$")
		if not inner then
			error("not compressed")
		end

		return inner
	end,
	EncodeBase64 = function(text)
		return Hex(text)
	end,
	DecodeBase64 = function(text)
		if #text % 2 == 1 or text:find("[^%x]") then
			error("bad base64")
		end

		return (text:gsub("%x%x", function(pair)
			return string.char(tonumber(pair, 16))
		end))
	end,
}

local AUI = {}
assert(loadfile(root .. "Core/Core.lua"))("AeonUI", AUI)
AUI.L = setmetatable({}, { __index = function(_, key)
	return key
end })
for _, file in ipairs({ "Core/Callbacks.lua", "Profile/Schema.lua", "Profile/Store.lua", "Profile/Codec.lua",
	"Profile/Profile.lua" }) do
	assert(loadfile(root .. file))("AeonUI", AUI)
end

local Codec, Profile, Store = AUI.Codec, AUI.Profile, AUI.Store

function Profile:Save(data)
	AeonUIDB = data
end

-- Harness -------------------------------------------------------------------------------------------------

local checks = 0

local function Equal(name, actual, expected)
	checks = checks + 1
	if actual ~= expected then
		io.stderr:write(("FAIL: %s: expected %s, got %s\n"):format(name, tostring(expected), tostring(actual)))
		os.exit(1)
	end
end

local function Problem(name, text, expected)
	local payload, problem = Codec:Decode(Codec.PREFIX, text)
	Equal(name .. " decodes nothing", payload, nil)
	Equal(name .. " problem", problem, expected)
end

-- Codec ---------------------------------------------------------------------------------------------------

local payload = { addon = "AeonUI", nested = { x = 0, y = -7.5 }, list = { "a", false } }
local text = Codec:Encode(Codec.PREFIX, payload)
Equal("encode prefix", text:sub(1, 6), "AUI!1!")
Equal("compression method is explicit", methods[1], Enum.CompressionMethod.Deflate)
local decoded = Codec:Decode(Codec.PREFIX, text)
Equal("round trip", decoded.nested.y, -7.5)
Equal("round trip keeps false", decoded.list[2], false)
Equal("decompression method is explicit", methods[#methods], Enum.CompressionMethod.Deflate)
Equal("whitespace is ignored", Codec:Decode(Codec.PREFIX, "  " .. text:sub(1, 9) .. "\n\t" .. text:sub(10) .. " ").nested.x, 0)

local body = text:sub(7)
Problem("not a string", nil, "foreign")
Problem("another prefix", "LB!1!" .. body, "foreign")
Problem("a longer prefix", "AUIX!1!" .. body, "foreign")
Problem("the recovery prefix", Codec.RECOVERY_PREFIX .. "!1!" .. body, "foreign")
Problem("no format", "AUI!!" .. body, "foreign")
Problem("a newer format", "AUI!2!" .. body, "newer")
Problem("format zero", "AUI!0!" .. body, "damaged")
Problem("an empty body", "AUI!1!", "damaged")
Problem("non-Base64 characters", "AUI!1!" .. body:sub(1, 4) .. "*" .. body:sub(6), "damaged")
Problem("Base64 the decoder rejects", "AUI!1!" .. body:sub(2), "damaged")
Problem("not compressed", "AUI!1!" .. Hex("cbor:1"), "damaged")
Problem("not CBOR", "AUI!1!" .. Hex("<plain text>"), "damaged")
Problem("too long", "AUI!1!" .. ("a"):rep(Codec.MAX_TEXT), "foreign")

fault.deserialize = function()
	return "a string, not a table"
end
Problem("CBOR that is not a table", text, "damaged")
fault.deserialize = function()
	return nil
end
Problem("CBOR that is nothing", text, "damaged")
fault.deserialize = function()
	return { [true] = 1 }
end
Problem("CBOR with a boolean key", text, "damaged")
fault.deserialize = function()
	return { n = 0 / 0 }
end
Problem("CBOR with NaN", text, "damaged")
fault.deserialize = nil

local maxCompressed = Codec.MAX_COMPRESSED
Codec.MAX_COMPRESSED = 4
Problem("compressed data over the limit", text, "damaged")
Codec.MAX_COMPRESSED = maxCompressed

fault.serialize = function()
	error("cannot serialize")
end
local failed, problem = Codec:Encode(Codec.PREFIX, payload)
Equal("a serialize error fails encoding", failed, nil)
Equal("a serialize error problem", problem, "failed")
fault.serialize = nil
fault.compress = function()
	return nil
end
Equal("a missing compression result fails encoding", (Codec:Encode(Codec.PREFIX, payload)), nil)
fault.compress = nil

-- Profile export and import ---------------------------------------------------------------------------------

Profile:Initialize(nil, "Player-1")
Profile:Set("frames.player.width", 444)
Profile.root.profilesByID[Store.DEFAULT_ID].config.future = { kept = true }

local exported = Profile:Export(Store.DEFAULT_ID)
Equal("export is a profile string", exported:sub(1, 6), "AUI!1!")
Equal("a missing profile does not export", (Profile:Export("p00000099")), nil)

local import, reason = Profile:Decode(exported)
Equal("decode", reason, nil)
Equal("decode keeps the name", import.name, "Default")
Equal("decode keeps settings", import.config.frames.player.width, 444)
Equal("decode counts dormant settings", import.dormant, 1)
Equal("decode changes nothing", Store:CountProfiles(AeonUIDB), 1)

local ok, id = Profile:Import(import, "default")
Equal("import needs a free name", ok, false)
ok, id = Profile:Import(import, "Imported")
Equal("import", ok, true)
Equal("import gets a new ID", id, "p00000002")
Equal("import activates", Profile.activeID, id)
Equal("import keeps settings", Profile:Get("frames.player.width"), 444)
Equal("import keeps dormant settings", AeonUIDB.profilesByID[id].config.future.kept, true)
ok = Profile:Import(import, "IMPORTED")
Equal("import name collision", ok, false)

local function Wrap(fields)
	return Codec:Encode(Codec.PREFIX, fields)
end

local VERSION = AUI.Schema.VERSION
local valid = { addon = "AeonUI", version = VERSION, name = "N", profile = {} }
Equal("a minimal profile decodes", Profile:Decode(Wrap(valid)) ~= nil, true)
local function Refused(name, fields, expected)
	local result, why = Profile:Decode(Wrap(fields))
	Equal(name .. " is refused", result, nil)
	Equal(name .. " reason", why, expected)
end
local NOT_OURS = "This is not an AeonUI profile string, or it was cut short."
local NEWER = "This profile string was made by a newer version of AeonUI."
local UNUSABLE = "This profile string holds settings AeonUI can't use."
Refused("another addon's payload", { addon = "Levelbound", version = VERSION, name = "N", profile = {} }, NOT_OURS)
Refused("a newer profile schema", { addon = "AeonUI", version = VERSION + 1, name = "N", profile = {} }, NEWER)
Refused("no name", { addon = "AeonUI", version = VERSION, profile = {} }, UNUSABLE)
Refused("no profile", { addon = "AeonUI", version = VERSION, name = "N" }, UNUSABLE)
Refused("a bad setting", {
	addon = "AeonUI",
	version = VERSION,
	name = "N",
	profile = { frames = { player = { width = 1 } } },
}, UNUSABLE)
Refused("schema 0", { addon = "AeonUI", version = 0, name = "N", profile = {} }, UNUSABLE)
local upgraded = Profile:Decode(Wrap({
	addon = "AeonUI",
	version = 1,
	name = "Old",
	profile = { frames = { player = { text = { font = "Expressway", size = 15 } } } },
}))
Equal("a schema 1 string decodes", upgraded ~= nil, true)
Equal("a schema 1 default becomes Shared", upgraded and upgraded.config.frames.player.text.font, nil)
Equal("a schema 1 custom value stays", upgraded and upgraded.config.frames.player.text.size, 15)
local _, why = Profile:Decode("AUI!9!" .. body)
Equal("a newer format reason", why, NEWER)

-- Recovery export -----------------------------------------------------------------------------------------

local broken = { schemaVersion = 99, odd = { [true] = 1, keep = "yes" }, number = 1 / 0 }
Profile:Initialize(broken, "Player-1")
Equal("recovery mode", Profile.mode, "recovery")
local raw, complete = Profile:RawExport()
Equal("recovery export prefix", raw:sub(1, #Codec.RECOVERY_PREFIX + 1), Codec.RECOVERY_PREFIX .. "!")
Equal("recovery export reports omissions", complete, false)
local report = Codec:Decode(Codec.RECOVERY_PREFIX, raw)
Equal("recovery export keeps what it can", report.store.odd.keep, "yes")
Equal("recovery export lists omitted values", report.omittedCount, 2)
Equal("recovery export names the client", report.client, "1.60.1.70124")
Equal("recovery export carries the problem", type(report.problem), "string")
Equal("recovery export is not a profile string", (Profile:Decode(raw)), nil)
Equal("recovery export leaves the saved data alone", broken.number, 1 / 0)

io.stdout:write(("check_codec: %d checks passed\n"):format(checks))
