-- A stand-in for the game client in the offline checks. Loaded with
-- `assert(loadfile(root .. "Tools/stub_client.lua"))({ project = "retail" })` or `"forever"`, it installs the client's
-- globals and returns the controls a check uses.
--
-- Widgets follow the client's types. A method is added when addon code calls it, after checking it against both clones,
-- and sits on the type the API documentation names, so calling a method a type lacks fails as it does in game. A read of
-- a missing field gives nil, which capability guards rely on.
--
-- A check reads a widget's state from these fields, which its setters keep:
--   shown, points, width, height, alpha, alphaBoolean, scale, level, parent, template, scripts,
--   mouse, mouseMotion, mouseClick                                                        every frame or texture
--   kind, name, clipsChildren, strata, buffered, bufferCalls, attributes, events          frames
--   file, atlas, color, vertex, coords, desaturated, blend, gradient                      textures
--   text, font, textColor, justifyH, wordWrap, shadowColor, shadowOffset                  font strings
--   value, min, max, statusColor, reverseFill, statusTexture, timer, interpolation,
--   direction, snapped                                                                    status bars
--   backdrop                                                                              frames with BackdropTemplate
--   plays, playing, scripts, animation                                                    animation groups
--   reverse, drawEdge, drawSwipe, hideNumbers                                             cooldowns
--   enabled, flowAnchor, flowGrowth, flowLineSize, auraGroups                             aura containers
--   cancelButtons, tooltipAnchor, durationCooldown, icon, countText, durationText, dispelTextures  aura buttons
-- `points` holds each anchor's SetPoint arguments, one entry per anchor. Size reads 0 until set, as an unsized frame's
-- does. `left`, `right`, `top` and `bottom` are a check's fixtures: the screen edges read nil until it sets them.
--
-- Time is virtual. `client.now` is what `GetTime` answers; `client.timers` holds what `C_Timer` has pending, and an entry
-- from `NewTimer` carries `seconds`, `cancelled` and `Cancel`.

local options = ...
local project = assert(options and options.project, "stub_client: no project")

assert(project == "retail" or project == "forever", "stub_client: unknown project")

---@class AUIStubClient
---@field checks integer the assertions made so far
---@field calls integer state-changing widget calls made; a check may reset it
---@field framesMade integer frames created; a check may reset it
---@field texturesMade integer textures created; a check may reset it
---@field combat boolean what `InCombatLockdown` answers
---@field frames table[] every frame created, in order
---@field now number what `GetTime` answers
---@field timers table[] what `C_Timer` has pending, in order
local client = {
	checks = 0,
	calls = 0,
	framesMade = 0,
	texturesMade = 0,
	combat = false,
	frames = {},
	now = 0,
	timers = {},
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

---Delivers an event to every frame registered for it, through its `OnEvent` script.
---@param event string
---@param ... any the event's payload
function client:Fire(event, ...)
	for _, frame in ipairs(self.frames) do
		if frame.events[event] and frame.scripts.OnEvent then
			frame.scripts.OnEvent(frame, event, ...)
		end
	end
end

---@param timer table
local function RunTimer(timer)
	if not timer.cancelled then
		timer.callback(timer)
	end
end

---Moves the clock on and runs what falls due, in order. A timer a callback starts waits for the next call.
---@param seconds number
function client:Advance(seconds)
	local pending = self.timers

	self.now = self.now + seconds
	self.timers = {}

	for _, timer in ipairs(pending) do
		if timer.due <= self.now then
			RunTimer(timer)
		else
			self.timers[#self.timers + 1] = timer
		end
	end
end

---Runs everything pending once, whatever its delay, without moving the clock.
function client:RunTimers()
	local pending = self.timers

	self.timers = {}

	for _, timer in ipairs(pending) do
		RunTimer(timer)
	end
end

---@return number now
function GetTime()
	return client.now
end

---@param seconds number
---@param callback function
---@return table timer
local function AddTimer(seconds, callback)
	local timer = { seconds = seconds, due = client.now + seconds, callback = callback }

	client.timers[#client.timers + 1] = timer

	return timer
end

C_Timer = {
	After = function(seconds, callback)
		AddTimer(seconds, callback)
	end,
	NewTimer = function(seconds, callback)
		local timer = AddTimer(seconds, callback)

		timer.Cancel = function(self)
			self.cancelled = true
		end

		return timer
	end,
}

---Sets what `InCombatLockdown` answers. Fires no events: a check fires them itself, in the order under test.
---@param on boolean
function client:SetCombat(on)
	self.combat = on
end

---@return boolean combat
function InCombatLockdown()
	return client.combat
end

-- Secret values: opaque, raising an error on comparison or arithmetic, secret through concatenation and formatting.
local SECRET = {}

local function Forbidden()
	error("operation on a secret value", 2)
end

SECRET.__lt, SECRET.__le, SECRET.__add, SECRET.__sub, SECRET.__mul, SECRET.__div = Forbidden, Forbidden, Forbidden,
	Forbidden, Forbidden, Forbidden

---@return table secret an opaque value `issecretvalue` recognizes
function client.Secret()
	return setmetatable({}, SECRET)
end

SECRET.__concat = client.Secret

---@param value any
---@return boolean secret
function issecretvalue(value)
	return type(value) == "table" and getmetatable(value) == SECRET
end

-- The client's xpcall forwards extra arguments to the function, as Lua 5.2 does; Lua 5.1's does not.
local luaXpcall = xpcall

function xpcall(fn, handler, ...)
	local count, args = select("#", ...), { ... }

	return luaXpcall(function()
		return fn(unpack(args, 1, count))
	end, handler)
end

---@param object table
---@param method string
---@param hook function
function hooksecurefunc(object, method, hook)
	local original = object[method]

	object[method] = function(...)
		local results = { original(...) }

		hook(...)

		return unpack(results)
	end
end

local luaFormat = string.format

function string.format(pattern, ...)
	for index = 1, select("#", ...) do
		if issecretvalue((select(index, ...))) then
			return client.Secret()
		end
	end

	return luaFormat(pattern, ...)
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
	SetFromAlpha = function(self, alpha)
		self.fromAlpha = alpha
	end,
	SetToAlpha = function(self, alpha)
		self.toAlpha = alpha
	end,
})

-- `CreateAnimation` builds only the animation kinds addon code asks for.
local ANIMATION_KINDS = { FlipBook = true, Alpha = true }

local AnimationGroup = Type(nil, {
	CreateAnimation = function(self, kind)
		assert(ANIMATION_KINDS[kind], "stub_client: no animation kind " .. tostring(kind))

		self.animation = setmetatable({ group = self, kind = kind }, Animation)

		return self.animation
	end,
	SetLooping = function(self, looping)
		self.looping = looping
	end,
	SetScript = function(self, name, script)
		self.scripts[name] = script
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
		return setmetatable({ owner = self, plays = 0, scripts = {} }, AnimationGroup)
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
	GetScript = function(self, name)
		return self.scripts[name]
	end,
	GetParent = function(self)
		return self.parent
	end,
})

local SetAlpha = State(function(self, alpha)
	self.alpha = alpha
end)
-- The flag may be secret, which Lua cannot test: only an ordinary one moves `alpha`.
local SetAlphaFromBoolean = State(function(self, flag, shown, hidden)
	self.alphaBoolean = { flag, shown, hidden }

	if not issecretvalue(flag) then
		self.alpha = flag and shown or hidden
	end
end)
local GetEffectiveScale = function()
	return 1
end
local GetAlpha = function(self)
	return self.alpha or 1
end
local SetScale = State(function(self, scale)
	self.scale = scale
end)

local Region = Type(ScriptRegion, {
	SetAlpha = SetAlpha,
	SetAlphaFromBoolean = SetAlphaFromBoolean,
	GetAlpha = GetAlpha,
	GetEffectiveScale = GetEffectiveScale,
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
	SetGradient = State(function(self, ...)
		self.gradient = { ... }
	end),
})

local FontString = Type(Region, {
	SetFont = State(function(self, ...)
		self.font = { ... }
	end),
	SetText = State(function(self, text)
		assert(self.font, "FontString:SetText(): Font not set")
		self.text = text
	end),
	SetFormattedText = State(function(self, pattern, ...)
		self.text = pattern:format(...)
	end),
	SetShadowColor = State(function(self, ...)
		self.shadowColor = { ... }
	end),
	SetShadowOffset = State(function(self, ...)
		self.shadowOffset = { ... }
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
	SetAlphaFromBoolean = SetAlphaFromBoolean,
	GetAlpha = GetAlpha,
	GetEffectiveScale = GetEffectiveScale,
	RegisterEvent = State(function(self, event)
		self.events[event] = true
	end),
	UnregisterEvent = State(function(self, event)
		self.events[event] = nil
	end),
	SetFrameStrata = State(function(self, strata)
		self.strata = strata
	end),
	SetIsFrameBuffer = State(function(self, buffered)
		self.buffered = buffered
		self.bufferCalls = (self.bufferCalls or 0) + 1
	end),
	SetAttribute = State(function(self, name, value)
		self.attributes = self.attributes or {}
		self.attributes[name] = value
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

		return setmetatable({ parent = self, shown = true, alpha = 1, points = {}, scripts = {} }, Texture)
	end,
	CreateFontString = function(self, _, _, template)
		return setmetatable({
			parent = self,
			template = template,
			font = template and { template } or nil,
			alpha = 1,
			shown = true,
			points = {},
			scripts = {},
		}, FontString)
	end,
})

local Button = Type(Frame, {
	RegisterForClicks = State(function(self, ...)
		self.clicks = { ... }
	end),
})

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
		self.min, self.max, self.timer = min, max, nil
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
	SetTimerDuration = State(function(self, duration, interpolation, direction)
		self.timer, self.interpolation, self.direction, self.snapped = duration, interpolation, direction, false
	end),
	SetToTargetValue = State(function(self)
		self.snapped = true
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
		name = name,
		parent = parent,
		template = template,
		events = {},
		alpha = 1,
		shown = true,
		points = {},
		scripts = {},
		level = parent and parent.level + 1 or 1,
	}, frameType)

	client.framesMade = client.framesMade + 1
	client.frames[#client.frames + 1] = frame

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
