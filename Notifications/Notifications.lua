local AUI = select(2, ...)

local Options = AUI.NotificationOptions

---@class AUINotificationLine : FontString
---@field key string? the notice shown, or nil while pooled
---@field slot string?
---@field sample boolean? an edit-mode or preview sample, kept apart from live notices
---@field timer table?
---@field fadeIn AnimationGroup
---@field fadeOut AnimationGroup

---The Notifications module: one stack of short text lines at a place set in edit mode. A timed notice fades in, holds
---for the duration and fades out; another stays until its condition ends. Notices sharing a slot replace each other,
---and the stack keeps the slots' order. Lines come from a pool. The feeders (combat, pet, character, potion) decide
---what shows; this object draws it.
---@class AUINotifications
---@field active boolean started this session
---@field frame Frame? the named stack, created the first time a notice or sample shows
---@field lines AUINotificationLine[] shown lines
---@field pool AUINotificationLine[] released lines
local Notifications = {
	active = false,
	lines = {},
	pool = {},
}
AUI.Notifications = Notifications

---@return Frame frame the stack, created on first call
function Notifications:Frame()
	if self.frame then
		return self.frame
	end

	local frame = CreateFrame("Frame", "AeonUINotifications", UIParent)

	frame:SetSize(1, 1)
	frame:SetFrameStrata("HIGH")
	frame:EnableMouse(false)
	self.frame = frame
	self:Place()

	return frame
end

---@return { point: string, x: number, y: number } position
function Notifications:DefaultPosition()
	return Options:DefaultPosition(UIParent:GetHeight())
end

---Puts the stack at its saved place, or its default one; edit mode places it too once it is registered.
function Notifications:Place()
	local frame = self.frame

	if not frame then
		return
	end

	local position = AUI.Profile:Get(Options.POSITION_PATH) or self:DefaultPosition()

	frame:ClearAllPoints()
	frame:SetPoint(position.point, UIParent, position.point, position.x, position.y)
end

---@param line FontString
function Notifications:Style(line)
	local Profile, Media = AUI.Profile, AUI.Media

	line:SetFont(Media:Font(Profile:Get(Options.FONT_PATH)), Profile:Get(Options.SIZE_PATH),
		Media:FontFlags(Profile:Get(Options.OUTLINE_PATH)))
end

---@return AUINotificationLine line
function Notifications:Acquire()
	local line = table.remove(self.pool)

	if line then
		return line
	end

	line = self:Frame():CreateFontString(nil, "OVERLAY") --[[@as AUINotificationLine]]

	line.fadeIn = line:CreateAnimationGroup()

	local appear = line.fadeIn:CreateAnimation("Alpha")

	appear:SetFromAlpha(0)
	appear:SetToAlpha(1)
	appear:SetDuration(Options.FADE_IN)

	line.fadeOut = line:CreateAnimationGroup()

	local vanish = line.fadeOut:CreateAnimation("Alpha")

	vanish:SetFromAlpha(1)
	vanish:SetToAlpha(0)
	vanish:SetDuration(Options.FADE_OUT)
	line.fadeOut:SetScript("OnFinished", function()
		self:Release(line)
	end)

	return line
end

---Returns a line to the pool: its timer cancelled, its fades stopped, hidden, unanchored, empty and without a key.
---@param line AUINotificationLine
function Notifications:Release(line)
	if line.timer then
		line.timer:Cancel()
		line.timer = nil
	end

	line.fadeIn:Stop()
	line.fadeOut:Stop()
	line:Hide()
	line:ClearAllPoints()
	line:SetAlpha(1)
	line:SetText("")
	line.key, line.slot, line.sample = nil, nil, nil

	for index, shown in ipairs(self.lines) do
		if shown == line then
			table.remove(self.lines, index)
			break
		end
	end

	self.pool[#self.pool + 1] = line
	self:Layout()
end

---Stacks the shown lines down from the stack's top in their slots' order, samples after live notices of the same
---slot, and sizes the stack to them.
function Notifications:Layout()
	local frame = self.frame

	if not frame then
		return
	end

	table.sort(self.lines, function(a, b)
		local orderA, orderB = Options:SlotOrder(a.slot or ""), Options:SlotOrder(b.slot or "")

		if orderA ~= orderB then
			return orderA < orderB
		end

		return not a.sample and b.sample == true
	end)

	local previous
	local width, height = 0, 0

	for index, line in ipairs(self.lines) do
		line:ClearAllPoints()

		if previous then
			line:SetPoint("TOP", previous, "BOTTOM", 0, -Options.LINE_GAP)
		else
			line:SetPoint("TOP", frame, "TOP")
		end

		width = math.max(width, line:GetStringWidth())
		height = height + line:GetStringHeight() + (index > 1 and Options.LINE_GAP or 0)
		previous = line
	end

	frame:SetSize(math.max(math.ceil(width), 1), math.max(math.ceil(height), 1))
end

---@param slot string
---@param sample boolean?
---@return AUINotificationLine? line the line shown in the slot
function Notifications:Find(slot, sample)
	for _, line in ipairs(self.lines) do
		if line.slot == slot and (line.sample == true) == (sample == true) then
			return line
		end
	end
end

---Shows a notice in its slot, replacing what the slot showed. A timed notice fades out after the duration; another
---stays until it is dismissed. A notice already showing is updated in place without fading in again.
---@param key string
---@param text string? the text; the notice's own when nil
---@param options { sample: boolean?, fade: boolean? }? `fade = false` shows it without fading in
---@return AUINotificationLine line
function Notifications:Show(key, text, options)
	options = options or {}

	local notice = Options:Notice(key)
	local line = self:Find(notice.slot, options.sample)
	local again = line ~= nil and line.key == key and not line.fadeOut:IsPlaying()

	if line then
		if line.timer then
			line.timer:Cancel()
			line.timer = nil
		end

		line.fadeOut:Stop()
	else
		line = self:Acquire()
		line.slot, line.sample = notice.slot, options.sample
		self.lines[#self.lines + 1] = line
	end

	local color = Options:Color(key)

	line.key = key
	self:Style(line)
	line:SetText(text or Options:Text(key))
	line:SetTextColor(color.r, color.g, color.b)
	line:Show()

	if not again then
		line.fadeIn:Stop()
		line:SetAlpha(1)

		if options.fade ~= false then
			line.fadeIn:Play()
		end
	end

	self:Layout()

	if notice.timed and not options.sample then
		line.timer = C_Timer.NewTimer(AUI.Profile:Get(Options.DURATION_PATH), function()
			line.timer = nil
			line.fadeOut:Play()
		end)
	end

	return line
end

---Dismisses a notice if it shows.
---@param key string
function Notifications:Dismiss(key)
	for _, line in ipairs(self.lines) do
		if line.key == key and not line.sample then
			self:Release(line)

			return
		end
	end
end

---@param sample boolean? true dismisses the samples, false or nil the live notices
function Notifications:Clear(sample)
	for index = #self.lines, 1, -1 do
		local line = self.lines[index]

		if (line.sample == true) == (sample == true) then
			self:Release(line)
		end
	end
end

---@return string[] keys the notices turned on, or Entering and Leaving Combat when none is
function Notifications:SampleKeys()
	local keys = {}
	local slots = {}

	for _, notice in ipairs(Options.NOTICES) do
		if Options:On(notice.key) and not slots[notice.slot] then
			keys[#keys + 1] = notice.key
			slots[notice.slot] = true
		end
	end

	if #keys == 0 then
		keys = { "enter" }
	end

	return keys
end

---@param key string
---@return string text a sample's text
function Notifications:SampleText(key)
	if key == "durability" then
		return Options:DurabilityText(key, AUI.Profile:Get(Options.DURABILITY_PATH) - 1)
	end

	return Options:Text(key)
end

---Shows a sample of each notice turned on while edit mode is open, so the stack has its size while it is placed.
---@param shown boolean
function Notifications:Sample(shown)
	self:Clear(true)

	if shown then
		for _, key in ipairs(self:SampleKeys()) do
			self:Show(key, self:SampleText(key), { sample = true, fade = false })
		end
	end
end

---Restyles every shown line, and lets each feeder follow its notices' settings.
function Notifications:Apply()
	for _, line in ipairs(self.lines) do
		if line.key then
			local color = Options:Color(line.key)

			self:Style(line)
			line:SetTextColor(color.r, color.g, color.b)

			if line.sample or Options:Notice(line.key).slot ~= "durability" then
				line:SetText(line.sample and self:SampleText(line.key) or Options:Text(line.key))
			end
		end
	end

	self:Layout()
	self:Place()
	AUI.CombatNotices:Apply()
	AUI.PetNotices:Apply()
	AUI.CharacterNotices:Apply()
	AUI.PotionNotice:Apply()
end

---@param path string? the changed setting; nil when the whole profile changed
function Notifications:OnProfileChanged(path)
	if path == nil or path:sub(1, 14) == "notifications." then
		AUI.Events:Coalesce("notificationsApply", function()
			Notifications:Apply()
		end)
	end
end

function Notifications:Start()
	if self.active then
		return
	end

	self.active = true
	AUI.Callbacks:Register("Profile", self, self.OnProfileChanged)
	self:Apply()
end
