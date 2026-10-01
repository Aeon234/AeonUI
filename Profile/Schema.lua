local AUI = select(2, ...)

-- Deepest nesting accepted in profile data, including fields this version does not know.
local MAX_DEPTH = 32

---One setting a profile can hold: its type, default and bounds.
---@class AUISchemaField
---@field path string dot-separated path inside a profile's config
---@field kind "boolean"|"number"
---@field default boolean|number
---@field min number?
---@field max number?

---Every setting a profile can hold. A profile's config is validated against these fields; keys outside them are
---dormant data from another version and are kept as they are, provided they are plain data.
---@class AUISchema
---@field VERSION integer the profile config schema version
---@field fields table<string, AUISchemaField>
---@field order string[] field paths in declaration order
---@field branches table<string, true> every path that is a table on the way to a field
local Schema = {
	VERSION = 1,
	fields = {},
	order = {},
	branches = {},
}
AUI.Schema = Schema

---@param path string
---@param kind "boolean"|"number"
---@param default boolean|number
---@param min number?
---@param max number?
local function Field(path, kind, default, min, max)
	Schema.fields[path] = { path = path, kind = kind, default = default, min = min, max = max }
	Schema.order[#Schema.order + 1] = path

	local branch = path:match("^(.*)%.[^.]+$")

	while branch do
		Schema.branches[branch] = true
		branch = branch:match("^(.*)%.[^.]+$")
	end
end

---@param unit string
---@param x number
---@param reverse boolean
local function UnitFrameFields(unit, x, reverse)
	local base = "frames." .. unit .. "."

	Field(base .. "enabled", "boolean", true)
	Field(base .. "width", "number", 270, 80, 600)
	Field(base .. "height", "number", 36, 16, 120)
	Field(base .. "x", "number", x, -3000, 3000)
	Field(base .. "y", "number", -200, -3000, 3000)
	Field(base .. "reverse", "boolean", reverse)
end

UnitFrameFields("player", -330, false)
UnitFrameFields("target", 330, true)

Field("frames.playerPower.enabled", "boolean", true)
Field("frames.playerPower.width", "number", 360, 80, 600)
Field("frames.playerPower.height", "number", 12, 4, 40)
Field("frames.playerPower.x", "number", 0, -3000, 3000)
Field("frames.playerPower.y", "number", -184, -3000, 3000)
Field("frames.playerPower.showText", "boolean", true)

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

---@param path string
---@param value any
---@return boolean ok
---@return string? problem why the value does not fit the field
function Schema:CheckValue(path, value)
	local field = self.fields[path]

	if not field then
		return false, ("%s is not a setting"):format(path)
	end

	if field.kind == "number" then
		if not IsFinite(value) then
			return false, ("%s must be a finite number"):format(path)
		end

		if (field.min and value < field.min) or (field.max and value > field.max) then
			return false, ("%s must be between %s and %s"):format(path, tostring(field.min), tostring(field.max))
		end
	elseif type(value) ~= field.kind then
		return false, ("%s must be a %s"):format(path, field.kind)
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
---@return any value the stored value, or the field's default when the config does not hold one
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

---@return table config a new config holding every field's default
function Schema:Defaults()
	local config = {}

	for _, path in ipairs(self.order) do
		self:Write(config, path, self.fields[path].default)
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
			self:Write(config, path, self.fields[path].default)
		end
	end
end

---@param scope string
---@return boolean known whether the scope names a field or a branch
function Schema:IsScope(scope)
	return self.fields[scope] ~= nil or self.branches[scope] ~= nil
end
