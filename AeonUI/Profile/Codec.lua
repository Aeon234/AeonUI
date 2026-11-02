local AUI = select(2, ...)

local Schema = AUI.Schema

---@alias AUICodecProblem
---| "foreign" # not this kind of string, or cut short before its prefix ends
---| "newer" # made by a newer format
---| "damaged" # the prefix is right but the encoded data does not decode
---| "failed" # encoding failed

---Profile strings: CBOR, then Deflate, then Base64, behind a `<PREFIX>!<format>!` prefix. Every native stage runs
---protected and its result is checked before the next stage sees it. Length checks bound what reaches each stage;
---they do not bound allocations inside Blizzard's own decoding.
---@class AUICodec
---@field FORMAT integer
---@field PREFIX string profile strings
---@field RECOVERY_PREFIX string diagnostic exports of saved data that cannot be used, never accepted as a profile
---@field MAX_TEXT integer longest accepted string, in bytes
---@field MAX_COMPRESSED integer
---@field MAX_SERIALIZED integer
---@field MAX_OMITTED integer omitted paths a recovery export lists by name
local Codec = {
	FORMAT = 1,
	PREFIX = "AUI",
	RECOVERY_PREFIX = "AUI-RECOVERY",
	MAX_TEXT = 256 * 1024,
	MAX_COMPRESSED = 192 * 1024,
	MAX_SERIALIZED = 512 * 1024,
	MAX_OMITTED = 128,
}
AUI.Codec = Codec

-- Deepest nesting a recovery export copies.
local MAX_DEPTH = 32

---Runs one native stage protected and accepts only a result of the expected type.
---@param expected string
---@param fn function
---@param ... any
---@return any? result
local function Stage(expected, fn, ...)
	local ok, result = pcall(fn, ...)

	if ok and type(result) == expected then
		return result
	end
end

---@param prefix string
---@param payload table plain data
---@return string? text
---@return AUICodecProblem? problem
function Codec:Encode(prefix, payload)
	local util = C_EncodingUtil
	local serialized = Stage("string", util.SerializeCBOR, payload)

	if not serialized or #serialized > self.MAX_SERIALIZED then
		return nil, "failed"
	end

	local compressed = Stage("string", util.CompressString, serialized, Enum.CompressionMethod.Deflate)

	if not compressed or #compressed > self.MAX_COMPRESSED then
		return nil, "failed"
	end

	local encoded = Stage("string", util.EncodeBase64, compressed)

	if not encoded then
		return nil, "failed"
	end

	return ("%s!%d!%s"):format(prefix, self.FORMAT, encoded)
end

---@param prefix string
---@param text any pasted text; whitespace anywhere in it is ignored
---@return table? payload plain data
---@return AUICodecProblem? problem
function Codec:Decode(prefix, text)
	if type(text) ~= "string" or #text > self.MAX_TEXT then
		return nil, "foreign"
	end

	text = text:gsub("%s+", "")

	local format, body = text:match("^" .. prefix:gsub("%p", "%%%0") .. "!(%d+)!(.*)$")

	if not format then
		return nil, "foreign"
	end

	local version = tonumber(format) --[[@as number]]

	if version > self.FORMAT then
		return nil, "newer"
	end

	if version ~= self.FORMAT or body == "" or not body:match("^[%w+/]+=*$") then
		return nil, "damaged"
	end

	local util = C_EncodingUtil
	local compressed = Stage("string", util.DecodeBase64, body)

	if not compressed or #compressed > self.MAX_COMPRESSED then
		return nil, "damaged"
	end

	local serialized = Stage("string", util.DecompressString, compressed, Enum.CompressionMethod.Deflate)

	if not serialized or #serialized > self.MAX_SERIALIZED then
		return nil, "damaged"
	end

	local payload = Stage("table", util.DeserializeCBOR, serialized)

	if not payload or not Schema:IsPlain(payload) then
		return nil, "damaged"
	end

	return payload
end

---Copies what can be encoded of any value, listing the paths it leaves out.
---@param value any
---@param path string
---@param omitted string[]
---@param depth integer
---@return any copy nil when the value cannot be kept
function Codec:CopyPlain(value, path, omitted, depth)
	local kind = type(value)

	if kind == "table" and depth <= MAX_DEPTH and getmetatable(value) == nil then
		local copy = {}

		for key, child in pairs(value) do
			local keyKind = type(key)
			local childPath = path .. "." .. tostring(key)

			if keyKind == "string" or (keyKind == "number" and key >= 1 and key == math.floor(key)) then
				copy[key] = self:CopyPlain(child, childPath, omitted, depth + 1)
			else
				omitted[#omitted + 1] = childPath
			end
		end

		return copy
	end

	if Schema:IsPlain(value) and kind ~= "table" then
		return value
	end

	omitted[#omitted + 1] = path

	return nil
end

---Encodes saved data that cannot be used as a diagnostic export. What cannot be encoded is left out and listed.
---@param original any
---@param details table plain data describing the problem and the client
---@return string? text
---@return boolean complete whether nothing was left out
function Codec:EncodeRecovery(original, details)
	local omitted = {}
	local store = self:CopyPlain(original, "AeonUIDB", omitted, 1)
	local listed = {}

	for index = 1, math.min(#omitted, self.MAX_OMITTED) do
		listed[index] = omitted[index]
	end

	local payload = AUI:CopyTable(details)

	payload.store = store
	payload.omitted = listed
	payload.omittedCount = #omitted
	payload.complete = #omitted == 0

	return self:Encode(self.RECOVERY_PREFIX, payload), #omitted == 0
end
