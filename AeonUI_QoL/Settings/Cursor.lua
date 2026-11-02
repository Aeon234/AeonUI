local AUI = select(2, ...)

local L = AUI.L

local PREVIEW_HEIGHT = 140
-- How long the sample's swipes take, in seconds; each starts again when it ends.
local GCD_SAMPLE, CAST_SAMPLE = 1.5, 2.5

local THICKNESS_LABELS = {
	THIN = L["Thin"],
	NORMAL = L["Normal"],
	THICK = L["Thick"],
}

local SHOW_LABELS = {
	ALWAYS = ALWAYS,
	COMBAT = L["In Combat"],
	INSTANCES = L["In Instances"],
}

local IDLE, GCD, CASTING = L["Idle"], L["Global Cooldown"], L["Casting"]

---The Cursor page, under the Quality of Life header: the module's switch, a sample ring as its preview, and the Ring,
---Swipes and Visibility cards.
---@class AUISettingsCursor
local SettingsCursor = {}
AUI.SettingsCursor = SettingsCursor

---@param values string[]
---@param labels table<string, string>
---@return table[] options
local function ChoiceOptions(values, labels)
	local options = {}

	for index, value in ipairs(values) do
		options[index] = { value = value, text = labels[value] }
	end

	return options
end

---A ring at its size and color, its swipes running in turn with the Global Cooldown and Casting states.
---@class AUICursorPreview
---@field ring AUICursorRingFrame?
---@field key string? the state and swipe settings the running swipe was started for
---@field running boolean
local CursorPreview = {
	running = false,
}

---@return boolean
local function GCDOn()
	return AUI.Profile:Get(AUI.CursorOptions.GCD_PATH) == true
end

---@return boolean
local function CastsOn()
	return AUI.can.castSwipe == true and AUI.Profile:Get(AUI.CursorOptions.CASTS_PATH) == true
end

---@param canvas Frame
function CursorPreview:Create(canvas)
	local ring = AUI.CursorRing:Build(canvas)

	ring:SetPoint("CENTER")
	ring.gcd:SetScript("OnCooldownDone", function()
		self:Repeat(ring.gcd, GCD_SAMPLE)
	end)
	ring.cast:SetScript("OnCooldownDone", function()
		self:Repeat(ring.cast, CAST_SAMPLE)
	end)
	self.ring = ring
end

---Starts a swipe again once it has ended, while the sample runs.
---@param cooldown Cooldown
---@param seconds number
function CursorPreview:Repeat(cooldown, seconds)
	if self.running then
		cooldown:SetCooldown(GetTime(), seconds)
	end
end

---@param state string
function CursorPreview:Start(state)
	local ring = self.ring --[[@as AUICursorRingFrame]]

	ring.gcd:Clear()
	ring.cast:Clear()

	if state == GCD and GCDOn() then
		ring.gcd:SetCooldown(GetTime(), GCD_SAMPLE)
	elseif state == CASTING and ring.casting then
		ring.cast:SetReverse(true)
		ring.cast:SetCooldown(GetTime(), CAST_SAMPLE)
	end
end

---@param state string
---@param preview table
---@return number width
---@return number height
function CursorPreview:Refresh(state, preview)
	local ring = self.ring --[[@as AUICursorRingFrame]]
	local size = AUI.Profile:Get(AUI.CursorOptions.SIZE_PATH)
	local key = ("%s:%s:%s"):format(state, tostring(GCDOn()), tostring(CastsOn()))

	ring.casting = state == CASTING and CastsOn()
	AUI.CursorRing:Style(ring)

	if not self.running or key ~= self.key then
		self.running, self.key = true, key
		self:Start(state)
	end

	preview:Part(ring, "size")

	if ring.dot:IsShown() then
		preview:Part(ring.dot, "dot")
	end

	if state == GCD then
		preview:Part(ring.gcd, "gcd")
	elseif state == CASTING then
		preview:Part(ring.cast, "casts")
	end

	return size, size
end

function CursorPreview:Stop()
	local ring = self.ring

	self.running = false

	if ring then
		ring.gcd:Clear()
		ring.cast:Clear()
	end
end

---@param section table
---@param id string
---@param label string
---@param path string
local function Checkbox(section, id, label, path)
	section:Checkbox({ id = id, label = label, path = path, default = AUI.Settings:Default(path) })
end

---@param page table
function SettingsCursor:DeclareRing(page)
	local Settings, Options = AUI.Settings, AUI.CursorOptions
	local card = page:Section("cursorRing", L["Ring"])

	card:Slider({
		id = "size",
		label = L["Size"],
		path = Options.SIZE_PATH,
		default = Settings:Default(Options.SIZE_PATH),
		min = Options.MIN_SIZE,
		max = Options.MAX_SIZE,
		step = 1,
	})
	card:Dropdown({
		id = "thickness",
		label = L["Thickness"],
		path = Options.THICKNESS_PATH,
		default = Settings:Default(Options.THICKNESS_PATH),
		options = ChoiceOptions(Options.THICKNESSES, THICKNESS_LABELS),
	})
	card:Color({
		id = "color",
		label = COLOR,
		path = Options.COLOR_PATH,
		default = Settings:Default(Options.COLOR_PATH),
		classColor = {
			id = "classColor",
			label = L["Class Color"],
			path = Options.CLASS_COLOR_PATH,
			default = Settings:Default(Options.CLASS_COLOR_PATH),
		},
	})
	card:Slider({
		id = "opacity",
		label = OPACITY,
		path = Options.OPACITY_PATH,
		default = Settings:Default(Options.OPACITY_PATH),
		min = 10,
		max = 100,
		step = 5,
		format = "percent",
	})
	Checkbox(card, "dot", L["Center Dot"], Options.DOT_PATH)
end

---@param page table
function SettingsCursor:DeclareSwipes(page)
	local Options = AUI.CursorOptions
	local card = page:Section("cursorSwipes", L["Swipes"])

	Checkbox(card, "gcd", L["Global Cooldown"], Options.GCD_PATH)

	if AUI.can.castSwipe then
		Checkbox(card, "casts", L["Casts"], Options.CASTS_PATH)
	end
end

---@param page table
function SettingsCursor:DeclareVisibility(page)
	local Settings, Options = AUI.Settings, AUI.CursorOptions
	local card = page:Section("cursorVisibility", L["Visibility"])

	card:Dropdown({
		id = "show",
		label = L["Show"],
		path = Options.SHOW_PATH,
		default = Settings:Default(Options.SHOW_PATH),
		options = ChoiceOptions(Options.SHOW_CHOICES, SHOW_LABELS),
	})
	Checkbox(card, "hideTurning", L["Hide While Turning the Camera"], Options.HIDE_TURNING_PATH)
end

---@return boolean
function SettingsCursor:IsAvailable()
	return AUI.can.cursorRing == true
end

---@param window table
function SettingsCursor:Declare(window)
	local Settings, Options = AUI.Settings, AUI.CursorOptions
	local page = window:Page("cursor", {
		title = L["Cursor"],
		under = "qualityOfLifeHeader",
		icon = AUI.Media.sidebar.cursor,
		iconTint = true,
		switch = {
			path = Options.ENABLED_PATH,
			default = Settings:Default(Options.ENABLED_PATH),
			label = L["Show Cursor Ring"],
		},
	})

	if not page then
		return
	end

	page:Preview({
		height = PREVIEW_HEIGHT,
		states = function()
			return AUI.can.castSwipe and { IDLE, GCD, CASTING } or { IDLE, GCD }
		end,
		create = function(canvas)
			CursorPreview:Create(canvas)
		end,
		refresh = function(_, state, preview)
			return CursorPreview:Refresh(state or IDLE, preview)
		end,
		stop = function()
			CursorPreview:Stop()
		end,
	})

	self:DeclareRing(page)
	self:DeclareSwipes(page)
	self:DeclareVisibility(page)
end

AUI.Modules:Register({
	group = "qualityOfLife",
	page = SettingsCursor,
	start = function()
		AUI.CursorRing:Start()
	end,
})
