local AUI = select(2, ...)

-- Deepest nesting accepted in profile data, including fields this version does not know.
local MAX_DEPTH = 32

---One setting a profile can hold: its type, default and bounds.
---@class AUISchemaField
---@field path string dot-separated path inside a profile's config
---@field kind "boolean"|"number"|"choice"|"string"|"color"
---@field default any the factory value; nil for an optional field, which then follows a shared setting
---@field min number?
---@field max number?
---@field integer boolean? a number must be whole
---@field options table<string, true>? the values a choice accepts
---@field maxLength integer? the longest string accepted
---@field optional boolean? absence is meaningful: the setting follows a shared one

---Every setting a profile can hold. A profile's config is validated against these fields; keys outside them are
---dormant data from another version and are kept as they are, provided they are plain data.
---@class AUISchema
---@field VERSION integer the profile config schema version
---@field TEXT_SLOTS integer text slots on the player and target frames
---@field fields table<string, AUISchemaField>
---@field order string[] field paths in declaration order
---@field branches table<string, true> every path that is a table on the way to a field
---@field choices table<string, string[]> each choice list in display order
local Schema = {
	VERSION = 1,
	TEXT_SLOTS = 4,
	fields = {},
	order = {},
	branches = {},
	choices = {
		content = {
			"none", "name", "level", "levelName", "health", "healthPercent", "healthAndPercent", "missingHealth",
			"absorb", "healAbsorb", "power", "powerPercent",
		},
		separator = { "bar", "dash", "slash", "space", "parentheses", "brackets", "bullet" },
		anchor = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" },
		placement = { "inside", "edge", "outside" },
		outline = { "NONE", "OUTLINE", "THICKOUTLINE" },
		colorMode = { "custom", "class", "power", "difficulty" },
		nameFormat = { "first", "full" },
		precision = { "default", "decimal" },
	},
}
AUI.Schema = Schema

---@param path string
---@param spec table the field's kind, default and bounds
local function Field(path, spec)
	spec.path = path
	Schema.fields[path] = spec
	Schema.order[#Schema.order + 1] = path

	local branch = path:match("^(.*)%.[^.]+$")

	while branch do
		Schema.branches[branch] = true
		branch = branch:match("^(.*)%.[^.]+$")
	end
end

---@param path string
---@param default boolean
local function Boolean(path, default)
	Field(path, { kind = "boolean", default = default })
end

---@param path string
---@param default number? nil makes the field optional
---@param min number
---@param max number
---@param integer boolean?
local function Number(path, default, min, max, integer)
	Field(path, { kind = "number", default = default, min = min, max = max, integer = integer, optional = default == nil })
end

---@param path string
---@param list string a choice list in `Schema.choices`
---@param default string? nil makes the field optional
local function Choice(path, list, default)
	local options = {}

	for _, value in ipairs(Schema.choices[list]) do
		options[value] = true
	end

	Field(path, { kind = "choice", default = default, options = options, optional = default == nil })
end

---@param path string
---@param default string? nil makes the field optional
---@param maxLength integer
local function String(path, default, maxLength)
	Field(path, { kind = "string", default = default, maxLength = maxLength, optional = default == nil })
end

---@param path string
---@param default table? `{ r, g, b }`; nil makes the field optional
local function Color(path, default)
	Field(path, { kind = "color", default = default, optional = default == nil })
end

-- How numbers are shown on every frame; each frame can override these below.
Choice("numbers.precision", "precision", "default")
Number("numbers.percentDecimals", 0, 0, 1, true)

---@class AUITextSlotDefault
---@field content string
---@field separator string?
---@field anchor string
---@field placement string
---@field x number?
---@field colorMode string?

---@param base string the frame's text path, ending in a dot
---@param index integer
---@param slot AUITextSlotDefault?
local function TextSlot(base, index, slot)
	local path = base .. "slots." .. index .. "."

	slot = slot or { content = "none", anchor = "CENTER", placement = "inside" }

	Choice(path .. "content", "content", slot.content)
	Choice(path .. "separator", "separator", slot.separator or "dash")
	Choice(path .. "anchor", "anchor", slot.anchor)
	Choice(path .. "placement", "placement", slot.placement)
	Number(path .. "x", slot.x or 0, -200, 200)
	Number(path .. "y", 0, -200, 200)
	Number(path .. "width", 100, 20, 200, true)
	Choice(path .. "colorMode", "colorMode", slot.colorMode or "custom")
	String(path .. "font", nil, 64)
	Number(path .. "size", nil, 6, 48, true)
	Choice(path .. "outline", "outline", nil)
	Color(path .. "color", nil)
end

---@param unit string
---@param x number
---@param reverse boolean
---@param slots AUITextSlotDefault[]
local function UnitFrameFields(unit, x, reverse, slots)
	local base = "frames." .. unit .. "."

	Boolean(base .. "enabled", true)
	Number(base .. "width", 270, 80, 600)
	Number(base .. "height", 36, 16, 120)
	Number(base .. "x", x, -3000, 3000)
	Number(base .. "y", -200, -3000, 3000)
	Boolean(base .. "reverse", reverse)

	Choice(base .. "numbers.precision", "precision", nil)
	Number(base .. "numbers.percentDecimals", nil, 0, 1, true)

	local text = base .. "text."

	String(text .. "font", "Expressway", 64)
	Number(text .. "size", 12, 6, 48, true)
	Choice(text .. "outline", "outline", "OUTLINE")
	Color(text .. "color", { r = 1, g = 1, b = 1 })
	Number(text .. "status", 1, 0, Schema.TEXT_SLOTS, true)
	Choice(text .. "nameFormat", "nameFormat", "first")

	for index = 1, Schema.TEXT_SLOTS do
		TextSlot(text, index, slots[index])
	end
end

UnitFrameFields("player", -330, false, {
	{ content = "healthAndPercent", anchor = "TOPRIGHT", placement = "edge", x = -4 },
})
UnitFrameFields("target", 330, true, {
	{ content = "healthAndPercent", anchor = "TOPLEFT", placement = "edge", x = 4 },
	{ content = "levelName", separator = "space", anchor = "TOPRIGHT", placement = "edge", x = -4, colorMode = "class" },
	{ content = "power", anchor = "BOTTOMLEFT", placement = "inside", x = 4, colorMode = "power" },
})

Boolean("frames.playerPower.enabled", true)
Number("frames.playerPower.width", 360, 80, 600)
Number("frames.playerPower.height", 12, 4, 40)
Number("frames.playerPower.x", 0, -3000, 3000)
Number("frames.playerPower.y", -184, -3000, 3000)
Boolean("frames.playerPower.showText", true)

---@param path string
---@return AUISchemaField?
function Schema:Field(path)
	return self.fields[path]
end

---@param value any
---@return boolean
local function IsFinite(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

---@param value any
---@return boolean
local function IsColor(value)
	if type(value) ~= "table" then
		return false
	end

	for key, channel in pairs(value) do
		if (key ~= "r" and key ~= "g" and key ~= "b") or not IsFinite(channel) or channel < 0 or channel > 1 then
			return false
		end
	end

	return value.r ~= nil and value.g ~= nil and value.b ~= nil
end

---@param path string
---@param value any nil clears an optional field
---@return boolean ok
---@return string? problem why the value does not fit the field
function Schema:CheckValue(path, value)
	local field = self.fields[path]

	if not field then
		return false, ("%s is not a setting"):format(path)
	end

	if value == nil then
		if field.optional then
			return true
		end

		return false, ("%s needs a value"):format(path)
	end

	local kind = field.kind

	if kind == "number" then
		if not IsFinite(value) then
			return false, ("%s must be a finite number"):format(path)
		end

		local min, max = field.min, field.max
		local below = min ~= nil and value < min
		local above = max ~= nil and value > max

		if below or above then
			return false, ("%s must be between %s and %s"):format(path, tostring(min), tostring(max))
		end

		if field.integer and value ~= math.floor(value) then
			return false, ("%s must be a whole number"):format(path)
		end
	elseif kind == "choice" then
		if type(value) ~= "string" or not field.options[value] then
			return false, ("%s is not one of its choices"):format(path)
		end
	elseif kind == "string" then
		if type(value) ~= "string" or value == "" or #value > (field.maxLength or 0) then
			return false, ("%s must be a short text"):format(path)
		end
	elseif kind == "color" then
		if not IsColor(value) then
			return false, ("%s must be a color"):format(path)
		end
	elseif type(value) ~= kind then
		return false, ("%s must be a %s"):format(path, kind)
	end

	return true
end

---Whether a value is plain saved data: booleans, strings, finite numbers and tables of them, keyed by strings or
---positive integers, without shared tables and no deeper than the nesting limit.
---@param value any
---@param depth integer?
---@param seen table<table, true>?
---@return boolean plain
function Schema:IsPlain(value, depth, seen)
	local kind = type(value)

	if kind == "boolean" or kind == "string" then
		return true
	end

	if kind == "number" then
		return IsFinite(value)
	end

	if kind ~= "table" then
		return false
	end

	depth = depth or 1
	seen = seen or {}

	if depth > MAX_DEPTH or seen[value] or getmetatable(value) ~= nil then
		return false
	end

	seen[value] = true

	for key, child in pairs(value) do
		local keyKind = type(key)
		local validKey = keyKind == "string" or (keyKind == "number" and key >= 1 and key == math.floor(key))

		if not validKey or not self:IsPlain(child, depth + 1, seen) then
			return false
		end
	end

	return true
end

---@param config table
---@param path string
---@return any value the stored value, or nil when a step on the way is absent
local function Lookup(config, path)
	local node = config

	for key in path:gmatch("[^.]+") do
		if type(node) ~= "table" then
			return nil
		end

		node = node[key]
	end

	return node
end

---Checks a profile config: every field that is present fits its definition, every branch that is present is a table,
---and everything is plain data.
---@param config any
---@return boolean ok
---@return string? problem the first problem found
function Schema:ValidateConfig(config)
	if type(config) ~= "table" then
		return false, "config is not a table"
	end

	if not self:IsPlain(config) then
		return false, "config holds something other than plain data"
	end

	for branch in pairs(self.branches) do
		local node = Lookup(config, branch)

		if node ~= nil and type(node) ~= "table" then
			return false, ("%s must be a table"):format(branch)
		end
	end

	for _, path in ipairs(self.order) do
		local value = Lookup(config, path)

		if value ~= nil then
			local ok, problem = self:CheckValue(path, value)

			if not ok then
				return false, problem
			end
		end
	end

	return true
end

---@param config table
---@param path string
---@return any value the stored value, or the field's default when the config does not hold one; a table value is
---the stored or default table itself, which callers must not change
function Schema:Read(config, path)
	local value = Lookup(config, path)

	if value == nil then
		local field = self.fields[path]

		return field and field.default
	end

	return value
end

---Writes a value at a path, creating the tables on the way.
---@param config table
---@param path string
---@param value any
function Schema:Write(config, path, value)
	local keys = {}

	for key in path:gmatch("[^.]+") do
		keys[#keys + 1] = key
	end

	local node = config

	for index = 1, #keys - 1 do
		local key = keys[index]
		local child = node[key]

		if type(child) ~= "table" then
			child = {}
			node[key] = child
		end

		node = child
	end

	node[keys[#keys]] = value
end

---Removes everything stored at a path.
---@param config table
---@param path string
function Schema:Clear(config, path)
	local parentPath, key = path:match("^(.*)%.([^.]+)$")
	local parent = parentPath and Lookup(config, parentPath) or config

	if type(parent) == "table" then
		parent[key or path] = nil
	end
end

---@param config table
---@param path string
local function WriteDefault(config, path)
	local default = Schema.fields[path].default

	if default ~= nil then
		Schema:Write(config, path, AUI:CopyTable(default))
	end
end

---@return table config a new config holding every field's default
function Schema:Defaults()
	local config = {}

	for _, path in ipairs(self.order) do
		WriteDefault(config, path)
	end

	return config
end

---Restores the defaults inside a scope, removing everything else stored there, dormant data included.
---@param config table
---@param scope string? a branch or field path; the whole config when nil
function Schema:ResetScope(config, scope)
	if not scope then
		for key in pairs(config) do
			config[key] = nil
		end
	else
		self:Clear(config, scope)
	end

	for _, path in ipairs(self.order) do
		if not scope or path == scope or path:sub(1, #scope + 1) == scope .. "." then
			WriteDefault(config, path)
		end
	end
end

---Counts the stored values this version does not know: each unknown key counts once, whatever it holds.
---@param config table
---@param prefix string? the path of `config` inside the whole config
---@return integer count
function Schema:CountDormant(config, prefix)
	local count = 0

	for key, value in pairs(config) do
		local path = prefix and (prefix .. "." .. tostring(key)) or tostring(key)

		if self.branches[path] and type(value) == "table" then
			count = count + self:CountDormant(value, path)
		elseif not self.fields[path] then
			count = count + 1
		end
	end

	return count
end

---@param scope string
---@return boolean known whether the scope names a field or a branch
function Schema:IsScope(scope)
	return self.fields[scope] ~= nil or self.branches[scope] ~= nil
end
