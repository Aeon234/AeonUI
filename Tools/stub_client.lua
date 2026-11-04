-- A stand-in for the game client in the offline checks. Loaded with
-- `assert(loadfile(root .. "Tools/stub_client.lua"))({ project = "retail" })` or `"forever"`, it installs the client's
-- globals and returns the controls a check uses.
--
-- Widgets follow the client's types. A method is added when addon code calls it, after checking it against both clones,
-- and sits on the type the API documentation names, so calling a method a type lacks fails as it does in game. A read of
-- a missing field gives nil, which capability guards rely on.
--
-- A check reads a widget's state from these fields, which its setters keep:
--   shown, points, width, height, alpha, scale, level, parent, template, scripts, mouse,
--   mouseMotion, mouseClick                                                               every frame or texture
--   kind, clipsChildren, alphaBoolean                                                     frames
--   file, atlas, color, vertex, coords, desaturated, blend                                textures
--   text, font, textColor, justifyH, wordWrap                                             font strings
--   value, min, max, statusColor, reverseFill, statusTexture                              status bars
--   backdrop                                                                              frames with BackdropTemplate
--   plays, playing                                                                        animation groups
--   reverse, drawEdge, drawSwipe, hideNumbers                                             cooldowns
--   enabled, flowAnchor, flowGrowth, flowLineSize, auraGroups                             aura containers
--   cancelButtons, tooltipAnchor, durationCooldown, icon, countText, durationText, dispelTextures  aura buttons
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
---@field combat boolean what `InCombatLockdown` answers
local client = {
	checks = 0,
	calls = 0,
	framesMade = 0,
	texturesMade = 0,
	combat = false,
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

---Sets what `InCombatLockdown` answers. Fires no events: a check fires them itself, in the order under test.
---@param on boolean
function client:SetCombat(on)
	self.combat = on
end

---@return boolean combat
function InCombatLockdown()
	return client.combat
end

local SECRET = {}

---@return table secret an opaque value `issecretvalue` recognizes
function client.Secret()
	return setmetatable({}, SECRET)
end

---@param value any
---@return boolean secret
function issecretvalue(value)
	return type(value) == "table" and getmetatable(value) == SECRET
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

local Animation = Type(nil, {
	SetDuration = function(self, duration)
		self.duration = duration
	end,
	SetFlipBookRows = function(self, rows)
		self.rows = rows
	end,
	SetFlipBookColumns = function(self, columns)
		self.columns = columns
	end,
	SetFlipBookFrames = function(self, frames)
		self.frames = frames
	end,
	SetFlipBookFrameWidth = function(self, width)
		self.frameWidth = width
	end,
	SetFlipBookFrameHeight = function(self, height)
		self.frameHeight = height
	end,
})

-- `CreateAnimation` builds only the animation kinds addon code asks for.
local ANIMATION_KINDS = { FlipBook = true }

local AnimationGroup = Type(nil, {
	CreateAnimation = function(self, kind)
		assert(ANIMATION_KINDS[kind], "stub_client: no animation kind " .. tostring(kind))

		return setmetatable({ group = self, kind = kind }, Animation)
	end,
	SetLooping = function(self, looping)
		self.looping = looping
	end,
	Play = function(self)
		self.plays, self.playing = self.plays + 1, true
	end,
	Stop = function(self)
		self.playing = false
	end,
})

local ScriptRegion = Type(nil, {
	CreateAnimationGroup = function(self)
		return setmetatable({ owner = self, plays = 0 }, AnimationGroup)
	end,
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
	IsVisible = function(self)
		local region = self

		while region do
			if not region.shown then
				return false
			end

			region = region.parent
		end

		return true
	end,
	EnableMouse = State(function(self, enabled)
		self.mouse = enabled
	end),
	SetMouseMotionEnabled = State(function(self, enabled)
		self.mouseMotion = enabled
	end),
	SetMouseClickEnabled = State(function(self, enabled)
		self.mouseClick = enabled
	end),
	SetParent = State(function(self, parent)
		self.parent = parent
	end),
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
	GetWidth = function(self)
		return self.width or 0
	end,
	GetHeight = function(self)
		return self.height or 0
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
	SetAtlas = State(function(self, atlas)
		self.atlas = atlas
	end),
	SetBlendMode = State(function(self, blend)
		self.blend = blend
	end),
})

local FontString = Type(Region, {
	SetFont = State(function(self, ...)
		self.font = { ... }
	end),
	SetText = State(function(self, text)
		self.text = text
	end),
	SetTextColor = State(function(self, ...)
		self.textColor = { ... }
	end),
	SetJustifyH = State(function(self, justify)
		self.justifyH = justify
	end),
	SetWordWrap = State(function(self, wrap)
		self.wordWrap = wrap
	end),
})

local Frame = Type(ScriptRegion, {
	SetAlpha = SetAlpha,
	SetAlphaFromBoolean = State(function(self, ...)
		self.alphaBoolean = { ... }
	end),
	SetClipsChildren = State(function(self, clips)
		self.clipsChildren = clips
	end),
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
	CreateFontString = function(self, _, _, template)
		return setmetatable({ parent = self, template = template, shown = true, points = {}, scripts = {} }, FontString)
	end,
})

local Button = Type(Frame, {})

local Cooldown = Type(Frame, {
	SetReverse = State(function(self, reverse)
		self.reverse = reverse
	end),
	SetDrawEdge = State(function(self, drawEdge)
		self.drawEdge = drawEdge
	end),
	SetDrawSwipe = State(function(self, drawSwipe)
		self.drawSwipe = drawSwipe
	end),
	SetHideCountdownNumbers = State(function(self, hide)
		self.hideNumbers = hide
	end),
})

local AuraContainer = Type(Frame, {
	SetEnabled = State(function(self, enabled)
		self.enabled = enabled
	end),
	SetFlowLayoutAnchorPoint = State(function(self, anchor)
		self.flowAnchor = anchor
	end),
	SetFlowLayoutGrowthDirection = State(function(self, ...)
		self.flowGrowth = { ... }
	end),
	SetFlowLayoutMaximumLineSize = State(function(self, size)
		self.flowLineSize = size
	end),
})

local AuraButton = Type(Button, {
	SetCancelAuraButtons = State(function(self, buttons)
		self.cancelButtons = buttons
	end),
	SetTooltipAnchorPoint = State(function(self, ...)
		self.tooltipAnchor = { ... }
	end),
})

---A setter for one field of an aura group, kept per group in `auraGroups`.
---@param field string
---@return function method
local function AuraGroupField(field)
	return State(function(self, group, value)
		self.auraGroups = self.auraGroups or {}
		self.auraGroups[group] = self.auraGroups[group] or {}
		self.auraGroups[group][field] = value
	end)
end

local PlayerModel = Type(Frame, {
	SetUnit = State(function(self, unit)
		self.modelUnit = unit
	end),
})

local StatusBar = Type(Frame, {
	SetMinMaxValues = State(function(self, min, max)
		self.min, self.max = min, max
	end),
	GetMinMaxValues = function(self)
		return self.min or 0, self.max or 0
	end,
	SetValue = State(function(self, value)
		self.value = value
	end),
	GetValue = function(self)
		return self.value or 0
	end,
	SetStatusBarColor = State(function(self, ...)
		self.statusColor = { ... }
	end),
	SetReverseFill = State(function(self, reverse)
		self.reverseFill = reverse
	end),
	SetStatusBarTexture = State(function(self, asset)
		self.statusTexture = self.statusTexture or self:CreateTexture()
		self.statusTexture.file = asset
	end),
	GetStatusBarTexture = function(self)
		self.statusTexture = self.statusTexture or self:CreateTexture()

		return self.statusTexture
	end,
})

-- The frame types `CreateFrame` knows, and what each XML template adds to a frame.
local FRAME_TYPES = {
	Frame = Frame,
	Button = Button,
	StatusBar = StatusBar,
	Cooldown = Cooldown,
	PlayerModel = PlayerModel,
	AuraContainer = AuraContainer,
	AuraButton = AuraButton,
}
local TEMPLATES = {
	CooldownFrameTemplate = {},
	CustomAuraContainerTemplate = {
		SetAuraGroupFilterString = AuraGroupField("filter"),
		SetAuraGroupCandidateFilters = AuraGroupField("candidates"),
		SetAuraGroupMaxFrameCount = AuraGroupField("limit"),
		SetAuraGroupLayout = AuraGroupField("layout"),
		SetAuraGroupSortMethod = State(function(self, group, method, direction)
			self.auraGroups = self.auraGroups or {}
			self.auraGroups[group] = self.auraGroups[group] or {}
			self.auraGroups[group].sortMethod, self.auraGroups[group].sortDirection = method, direction
		end),
	},
	CustomAuraButtonTemplate = {
		SetDurationCooldown = State(function(self, cooldown)
			self.durationCooldown = cooldown
		end),
		SetIcon = State(function(self, texture)
			self.icon = texture
		end),
		SetApplicationCount = State(function(self, fontString)
			self.countText = fontString
		end),
		SetDurationText = State(function(self, fontString)
			self.durationText = fontString
		end),
		AddDispelTypeTexture = State(function(self, texture, options)
			self.dispelTextures = self.dispelTextures or {}
			self.dispelTextures[#self.dispelTextures + 1] = { texture = texture, options = options }
		end),
	},
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
		kind = kind,
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

UIParent = CreateFrame("Frame", "UIParent")
client.framesMade = 0

return client
