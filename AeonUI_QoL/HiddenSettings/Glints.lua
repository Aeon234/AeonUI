local AUI = select(2, ...)

local Options = AUI.HiddenSettingsOptions

local FRAME_NAME = "AeonUILootSparkle"
local TEXTURE = "Interface\\Cooldown\\star4"
local COUNT = 7
local SIZE = 34
local SPREAD = 46 -- the radius of the flattened disc the glints appear in
local OFFSET_Y = -45 -- from the nameplate down to the object
local FADE_IN = 0.35
local BLEND_TIME = 0.30
local MAX_ELAPSED = 0.1 -- a frame freeze moves the glints no further than this

local random, sin, cos, sqrt, pi = math.random, math.sin, math.cos, math.sqrt, math.pi

---@class AUILootSparkleGlint
---@field texture Texture
---@field x number
---@field y number
---@field life number seconds from appearing to fading out
---@field scale number
---@field angle number
---@field turn number radians a second
---@field age number seconds; negative while waiting to appear

---The glints under the interaction target's nameplate: one frame, `AeonUILootSparkle`, created on first use and moved
---from plate to plate, animated only while shown. Each glint appears somewhere in a flattened disc, grows, fades and
---drifts up; far is dimmer and calmer, ready full, locked gray and slow, blended over `BLEND_TIME`.
---@class AUILootSparkleGlints
---@field frame Frame?
---@field glints AUILootSparkleGlint[]
---@field anchor Frame? the plate the frame hangs on
---@field shown string the state drawn
---@field pending string? the state waiting to be drawn
---@field since number? when it started waiting
---@field appear number 0 to 1
---@field ready number 0 to 1
---@field locked number 0 to 1
local Glints = {
	glints = {},
	shown = "far",
	appear = 0,
	ready = 0,
	locked = 0,
}
AUI.LootSparkleGlints = Glints

---Places a glint somewhere new, after a short dark pause unless `now`.
---@param glint AUILootSparkleGlint
---@param now boolean?
local function Respawn(glint, now)
	local angle, reach = random() * 2 * pi, sqrt(random())

	glint.x, glint.y = cos(angle) * reach * SPREAD, sin(angle) * reach * SPREAD * 0.75
	glint.life = 0.6 + 0.8 * random()
	glint.scale = 0.5 + 0.7 * random()
	glint.angle = random() * 2 * pi
	glint.turn = (random() - 0.5) * 2
	glint.age = now and 0 or -0.6 * random()
end

---@param value number
---@param target number
---@param step number
---@return number
local function Approach(value, target, step)
	if value < target then
		return math.min(value + step, target)
	end

	return math.max(value - step, target)
end

---@param frame Frame
---@param elapsed number
local function Animate(frame, elapsed)
	elapsed = math.min(elapsed, MAX_ELAPSED)
	Glints.appear = Approach(Glints.appear, 1, elapsed / FADE_IN)
	Glints.ready = Approach(Glints.ready, Glints.shown == "ready" and 1 or 0, elapsed / BLEND_TIME)
	Glints.locked = Approach(Glints.locked, Glints.shown == "locked" and 1 or 0, elapsed / BLEND_TIME)

	local alpha, speed, r, g, b = Options.Blend(Glints.appear, Glints.ready, Glints.locked)

	for _, glint in ipairs(Glints.glints) do
		glint.age = glint.age + elapsed * speed

		if glint.age >= glint.life then
			Respawn(glint)
		end

		local age = math.max(glint.age, 0)
		local shine = glint.age > 0 and sin(pi * glint.age / glint.life) or 0
		local size = math.max(SIZE * glint.scale * (0.35 + 0.65 * shine), 0.01)
		local texture = glint.texture

		texture:ClearAllPoints()
		texture:SetPoint("CENTER", frame, "CENTER", glint.x, glint.y + 10 * age)
		texture:SetSize(size, size)
		texture:SetRotation(glint.angle + glint.turn * age)
		texture:SetVertexColor(r, g, b, math.min(alpha * shine, 1))
	end
end

---@return Frame frame
function Glints:Frame()
	if self.frame then
		return self.frame
	end

	local frame = CreateFrame("Frame", FRAME_NAME)

	frame:SetSize(1, 1)
	frame:Hide()

	for index = 1, COUNT do
		local texture = frame:CreateTexture(nil, "OVERLAY")

		texture:SetTexture(TEXTURE)
		texture:SetBlendMode("ADD")
		texture:SetVertexColor(1, 1, 1, 0)
		texture:SetSnapToPixelGrid(false)
		texture:SetTexelSnappingBias(0)
		self.glints[index] = { texture = texture } --[[@as AUILootSparkleGlint]]
	end

	frame:SetScript("OnUpdate", Animate)
	self.frame = frame

	return frame
end

---@return Frame? plate the plate the glints hang on
function Glints:Anchor()
	return self.anchor
end

---Hangs the glints under `plate`, below its content so its text stays readable, starting in `state` at once.
---@param plate Frame
---@param state string
function Glints:Attach(plate, state)
	local frame = self:Frame()
	local level = AUI:Readable(plate:GetFrameLevel())

	frame:SetParent(plate)

	if type(level) == "number" then
		frame:SetFrameLevel(math.max(level - 1, 0))
	end

	frame:ClearAllPoints()
	frame:SetPoint("CENTER", plate, "CENTER", 0, OFFSET_Y)
	frame:SetIgnoreParentAlpha(true)
	self.anchor = plate
	self.shown, self.pending, self.since = state, nil, nil
	self.ready = state == "ready" and 1 or 0
	self.locked = state == "locked" and 1 or 0
	self.appear = 0

	for _, glint in ipairs(self.glints) do
		Respawn(glint)
	end

	frame:Show()
end

---Moves to `state` once it has held long enough; becoming ready restarts every glint at once.
---@param state string
---@param now number
function Glints:Propose(state, now)
	local before = self.shown

	self.shown, self.pending, self.since = Options.Propose(self.shown, self.pending, self.since, state, now)

	if self.shown == "ready" and before ~= "ready" then
		for _, glint in ipairs(self.glints) do
			Respawn(glint, true)
		end
	end
end

function Glints:Release()
	if not self.anchor or not self.frame then
		return
	end

	self.frame:Hide()
	self.frame:ClearAllPoints()
	self.frame:SetParent(nil)
	self.anchor = nil
end
