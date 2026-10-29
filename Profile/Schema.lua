local AUI = select(2, ...)

-- Deepest nesting accepted in profile data, including fields this version does not know.
local MAX_DEPTH = 32

-- The points a stored position may name: a frame's point, placed at the same point of the screen.
local POINTS = {
	TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true, RIGHT = true, BOTTOMLEFT = true,
	BOTTOM = true, BOTTOMRIGHT = true,
}

---One setting a profile can hold: its type, default and bounds.
---@class AUISchemaField
---@field path string dot-separated path inside a profile's config
---@field kind "boolean"|"number"|"choice"|"string"|"color"|"position"|"lists"|"order"
---@field default any the factory value; nil for an optional field, which then follows a shared setting
---@field min number?
---@field max number?
---@field integer boolean? a number must be whole
---@field options table<string, true>? the values a choice or an order accepts, or the list names a lists field accepts
---@field maxLength integer? the longest string accepted
---@field allowEmpty boolean? a string may be empty
---@field optional boolean? absence is meaningful: the setting follows a shared one
---@field shared string? the setting an optional field reads while it holds no value of its own

---Every setting a profile can hold. Each feature declares its fields at load, before the profile owner initializes. A
---profile's config is validated against these fields; keys outside them are dormant data from another version and are
---kept as they are, provided they are plain data.
---@class AUISchema
---@field VERSION integer the profile config schema version
---@field fields table<string, AUISchemaField>
---@field order string[] field paths in declaration order
---@field branches table<string, true> every path that is a table on the way to a field
---@field choices table<string, string[]> each choice list in display order
local Schema = {
	VERSION = 1,
	fields = {},
	order = {},
	branches = {},
	choices = {},
}
AUI.Schema = Schema

---@param path string
---@param spec table the field's kind, default and bounds
local function Field(path, spec)
	assert(not Schema.fields[path], path)

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
function Schema:Boolean(path, default)
	Field(path, { kind = "boolean", default = default })
end

---@param path string
---@param default number? nil makes the field optional
---@param min number
---@param max number
---@param integer boolean?
function Schema:Number(path, default, min, max, integer)
	Field(path, { kind = "number", default = default, min = min, max = max, integer = integer, optional = default == nil })
end

---Declares a choice list, in display order, for choice fields to name.
---@param name string
---@param list string[]
function Schema:Choices(name, list)
	assert(not self.choices[name], name)

	self.choices[name] = list
end

---@param path string
---@param list string a choice list in `Schema.choices`
---@param default string? nil makes the field optional
function Schema:Choice(path, list, default)
	local options = {}

	for _, value in ipairs(assert(self.choices[list], list)) do
		options[value] = true
	end

	Field(path, { kind = "choice", default = default, options = options, optional = default == nil })
end

---@param path string
---@param default string? nil makes the field optional; an empty default lets the text be empty
---@param maxLength integer
function Schema:String(path, default, maxLength)
	Field(path, {
		kind = "string",
		default = default,
		maxLength = maxLength,
		optional = default == nil,
		allowEmpty = default == "",
	})
end

---@param path string
---@param default table? `{ r, g, b, a? }`; nil makes the field optional
function Schema:Color(path, default)
	Field(path, { kind = "color", default = default, optional = default == nil })
end

---A frame's position, `{ point, x, y }`: optional, so that absence means the frame's default place.
---@param path string
function Schema:Position(path)
	Field(path, { kind = "position", optional = true })
end

---Named lists of short texts, `{ [name] = { text, ... } }`, each text in one list at most: optional, so that absence
---means the feature's own default arrangement.
---@param path string
---@param names string[] the list names accepted
---@param maxLength integer the longest text accepted
function Schema:Lists(path, names, maxLength)
	local options = {}

	for _, name in ipairs(names) do
		options[name] = true
	end

	Field(path, { kind = "lists", options = options, maxLength = maxLength, optional = true })
end

---An order of a choice list's values, each at most once; a value it leaves out takes its place in the default.
---@param path string
---@param list string a choice list in `Schema.choices`
---@param default string[]
function Schema:Order(path, list, default)
	local options = {}

	for _, value in ipairs(assert(self.choices[list], list)) do
		options[value] = true
	end

	Field(path, { kind = "order", default = default, options = options })
end

---A setting that follows a shared one until it holds its own value: optional, with the shared field's kind and
---bounds.
---@param path string
---@param shared string the shared field, declared first
function Schema:Inherit(path, shared)
	local source = assert(self.fields[shared], shared)

	Field(path, {
		kind = source.kind,
		min = source.min,
		max = source.max,
		integer = source.integer,
		options = source.options,
		maxLength = source.maxLength,
		allowEmpty = source.allowEmpty,
		optional = true,
		shared = shared,
	})
end

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
local function IsPosition(value)
	if type(value) ~= "table" then
		return false
	end

	for key in pairs(value) do
		if key ~= "point" and key ~= "x" and key ~= "y" then
			return false
		end
	end

	return POINTS[value.point] == true and IsFinite(value.x) and IsFinite(value.y)
end

---@param value any
---@return boolean
local function IsColor(value)
	if type(value) ~= "table" then
		return false
	end

	for key, channel in pairs(value) do
		local known = key == "r" or key == "g" or key == "b" or key == "a"

		if not known or not IsFinite(channel) or channel < 0 or channel > 1 then
			return false
		end
	end

	return value.r ~= nil and value.g ~= nil and value.b ~= nil
end

---@param value any
---@param field AUISchemaField a lists field
---@return boolean
local function IsLists(value, field)
	if type(value) ~= "table" then
		return false
	end

	local seen, options, maxLength = {}, field.options or {}, field.maxLength or 0

	for name, list in pairs(value) do
		if not options[name] or type(list) ~= "table" then
			return false
		end

		local count = 0

		for _ in pairs(list) do
			count = count + 1
		end

		for index = 1, count do
			local text = list[index]

			if type(text) ~= "string" or text == "" or #text > maxLength or seen[text] then
				return false
			end

			seen[text] = true
		end
	end

	return true
end

---@param value any
---@param field AUISchemaField an order field
---@return boolean
local function IsOrder(value, field)
	if type(value) ~= "table" then
		return false
	end

	local count, seen, options = 0, {}, field.options or {}

	for _ in pairs(value) do
		count = count + 1
	end

	for index = 1, count do
		local item = value[index]

		if type(item) ~= "string" or not options[item] or seen[item] then
			return false
		end

		seen[item] = true
	end

	return true
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
		if type(value) ~= "string" or (value == "" and not field.allowEmpty) or #value > (field.maxLength or 0) then
			return false, ("%s must be a short text"):format(path)
		end
	elseif kind == "color" then
		if not IsColor(value) then
			return false, ("%s must be a color"):format(path)
		end
	elseif kind == "position" then
		if not IsPosition(value) then
			return false, ("%s must be a position"):format(path)
		end
	elseif kind == "lists" then
		if not IsLists(value, field) then
			return false, ("%s must be named lists of short texts, each text once"):format(path)
		end
	elseif kind == "order" then
		if not IsOrder(value, field) then
			return false, ("%s must be an order of its choices, each once"):format(path)
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

---@param config table
---@param path string
---@return any value what the config stores at the path, without falling back to a default
function Schema:Lookup(config, path)
	return Lookup(config, path)
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

		if field and field.shared then
			return self:Read(config, field.shared)
		end

		return field and field.default
	end

	return value
end

---@param config table
---@param path string
---@return boolean custom the setting follows a shared one and holds its own value
function Schema:IsCustom(config, path)
	local field = self.fields[path]

	return field ~= nil and field.shared ~= nil and Lookup(config, path) ~= nil
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
