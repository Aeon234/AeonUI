-- A stand-in for the game client in the offline checks. Loaded with
-- `assert(loadfile(root .. "Tools/stub_client.lua"))({ project = "retail" })` or `"forever"`, it installs the client's
-- globals and returns the controls a check uses.
--
-- Widgets follow the client's types. A method is added when addon code calls it, after checking it against both clones,
-- and sits on the type the API documentation names, so calling a method a type lacks fails as it does in game. A read of
-- a missing field gives nil, which capability guards rely on.
--
-- A check reads a widget's state from these fields, which its setters keep:
--   shown, points, width, height, alpha, scale, level, parent, template, scripts          every frame or texture
--   file, color, vertex, coords, desaturated                                              textures
--   backdrop                                                                              frames with BackdropTemplate
-- `points` holds each anchor's SetPoint arguments, one entry per anchor. Size reads 0 until set, as an unsized frame's
-- does. `left`, `right`, `top` and `bottom` are a check's fixtures: the screen edges read nil until it sets them.

local options = ...
local project = assert(options and options.project, "stub_client: no project")

assert(project == "retail" or project == "forever", "stub_client: unknown project")

---@class AUIStubClient
---@field checks integer the assertions made so far
---@field calls integer state-changing widget calls made; a check may reset it
---@field framesMade integer frames created; a check may reset it
---@field texturesMade integer textures created; a check may reset it
local client = {
	checks = 0,
	calls = 0,
	framesMade = 0,
	texturesMade = 0,
}

---Fails the check at once when a value differs from the one expected.
---@param label string
---@param got any
---@param want any
function client.Equal(label, got, want)
	client.checks = client.checks + 1

	if got ~= want then
		io.stderr:write(("FAIL: %s: expected %s, got %s\n"):format(label, tostring(want), tostring(got)))
		os.exit(1)
	end
end

---A method that changes a widget's state, counted in `client.calls`.
---@param body function?
---@return function method
local function State(body)
	return function(self, ...)
		client.calls = client.calls + 1

		if body then
			return body(self, ...)
		end
	end
end

---A widget type: its own methods, then those of the type it derives from.
---@param base table?
---@param methods table
---@return table type
local function Type(base, methods)
	methods.__index = methods

	return setmetatable(methods, base)
end

---@param self table
---@param anchor string
---@param ... any the rest of the anchor's SetPoint arguments
local function SetAnchor(self, anchor, ...)
	for index, entry in ipairs(self.points) do
		if entry[1] == anchor then
			self.points[index] = { anchor, ... }

			return
		end
	end

	self.points[#self.points + 1] = { anchor, ... }
end

local ScriptRegion = Type(nil, {
	SetPoint = State(function(self, ...)
		SetAnchor(self, ...)
	end),
	SetAllPoints = State(function(self, relative)
		self.points = {}
		SetAnchor(self, "TOPLEFT", relative or self.parent, "TOPLEFT")
		SetAnchor(self, "BOTTOMRIGHT", relative or self.parent, "BOTTOMRIGHT")
	end),
	ClearAllPoints = State(function(self)
		self.points = {}
	end),
	SetShown = State(function(self, shown)
		self.shown = not not shown
	end),
	Show = State(function(self)
		self.shown = true
	end),
	Hide = State(function(self)
		self.shown = false
	end),
	IsShown = function(self)
		return self.shown
	end,
	SetSize = State(function(self, width, height)
		self.width, self.height = width, height
	end),
	SetWidth = State(function(self, width)
		self.width = width
	end),
	SetHeight = State(function(self, height)
		self.height = height
	end),
	GetSize = function(self)
		return self.width or 0, self.height or 0
	end,
	GetLeft = function(self)
		return self.left
	end,
	GetRight = function(self)
		return self.right
	end,
	GetTop = function(self)
		return self.top
	end,
	GetBottom = function(self)
		return self.bottom
	end,
	SetScript = State(function(self, name, script)
		self.scripts[name] = script
	end),
})

local SetAlpha = State(function(self, alpha)
	self.alpha = alpha
end)
local SetScale = State(function(self, scale)
	self.scale = scale
end)

local Region = Type(ScriptRegion, {
	SetAlpha = SetAlpha,
	SetScale = SetScale,
	SetDrawLayer = State(),
	SetVertexColor = State(function(self, ...)
		self.vertex = { ... }
	end),
})

local Texture = Type(Region, {
	SetSnapToPixelGrid = State(),
	SetTexelSnappingBias = State(),
	SetTexture = State(function(self, file)
		self.file = file
	end),
	SetColorTexture = State(function(self, ...)
		self.color = { ... }
	end),
	SetTexCoord = State(function(self, ...)
		self.coords = { ... }
	end),
	GetTexCoord = function(self)
		return unpack(self.coords)
	end,
	SetDesaturated = State(function(self, desaturated)
		self.desaturated = desaturated
	end),
	SetHorizTile = State(),
	SetVertTile = State(),
	SetAtlas = State(),
	SetBlendMode = State(),
})

local Frame = Type(ScriptRegion, {
	SetAlpha = SetAlpha,
	SetScale = SetScale,
	SetFrameLevel = State(function(self, level)
		self.level = level
	end),
	GetFrameLevel = function(self)
		return self.level
	end,
	CreateTexture = function(self)
		client.texturesMade = client.texturesMade + 1

		return setmetatable({ parent = self, shown = true, points = {}, scripts = {} }, Texture)
	end,
})

-- The frame types `CreateFrame` knows, and what each XML template adds to a frame.
local FRAME_TYPES = { Frame = Frame }
local TEMPLATES = {
	BackdropTemplate = {
		SetBackdrop = State(function(self, backdrop)
			self.backdrop = backdrop
		end),
		SetBackdropBorderColor = State(),
	},
}

---@param kind string
---@param name string?
---@param parent table?
---@param template string?
---@return table frame
function CreateFrame(kind, name, parent, template)
	local frameType = assert(FRAME_TYPES[kind], "stub_client: no frame type " .. tostring(kind))
	local frame = setmetatable({
		parent = parent,
		template = template,
		shown = true,
		points = {},
		scripts = {},
		level = parent and parent.level + 1 or 1,
	}, frameType)

	client.framesMade = client.framesMade + 1

	if template then
		for method, body in pairs(assert(TEMPLATES[template], "stub_client: no template " .. template)) do
			frame[method] = body
		end
	end

	if name then
		_G[name] = frame
	end

	return frame
end

---@param object table
---@param ... table the mixins
---@return table object
function Mixin(object, ...)
	for index = 1, select("#", ...) do
		for key, value in pairs((select(index, ...))) do
			object[key] = value
		end
	end

	return object
end

WOW_PROJECT_MAINLINE = 1
WOW_PROJECT_CAMELOT = project == "forever" and 18 or nil
WOW_PROJECT_ID = project == "forever" and WOW_PROJECT_CAMELOT or WOW_PROJECT_MAINLINE

return client
