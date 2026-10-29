local AUI = select(2, ...)

local Options = AUI.NotificationOptions
local lib = LibStub("LibAeonSettings-1.0")

---@class AUINotificationLine : FontString
---@field key string? the notice shown, or nil while pooled
---@field slot string?
---@field sample boolean? an edit-mode or preview sample, kept apart from live notices
---@field timer table?
---@field fade boolean? the stack owns the line's opacity; false while a feeder sets it
---@field leaving boolean? fading out, no longer holding room in the stack
---@field travel number? units above its place the line starts from when it first shows
---@field placed boolean? the line has a place in the stack
---@field offset table the spring moving the line's offset below the stack's top
---@field opacity table the spring fading the line while the stack owns its opacity

---The Notifications module: one stack of short text lines at a place set in edit mode. A notice slides down into its
---place as it fades in and leaves the way it came, while the lines below move to close or open its room. Every
---motion is one of the settings library's critically damped springs, which start from where the line is, so a notice
---shown again while it leaves turns back without a jump; with Reduce Motion on they jump. A timed notice holds for the
---duration; another stays until its condition ends. A notice replacing another in its slot cross-fades with it in
---place. Lines come from a pool. The feeders (combat, pet, character, potion) decide what shows; this object draws it.
---@class AUINotifications
---@field active boolean started this session
---@field frame Frame? the named stack, created the first time a notice or sample shows
---@field lines AUINotificationLine[] shown lines, leaving ones included
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

---@return AUINotificationLine line a pooled line, or a new one with its two springs
function Notifications:Acquire()
	local line = table.remove(self.pool)

	if line then
		return line
	end

	local frame = self:Frame()

	line = frame:CreateFontString(nil, "OVERLAY") --[[@as AUINotificationLine]]
	line.offset = lib:CreateSpring(0, function(offset)
		line:SetPoint("TOP", frame, "TOP", 0, -offset)
	end, { response = Options.MOVE_RESPONSE, epsilon = Options.REST_DISTANCE })
	line.opacity = lib:CreateSpring(0, function(alpha)
		if line.fade then
			line:SetAlpha(math.min(math.max(alpha, 0), 1))
		end
	end, {
		response = Options.FADE_IN,
		epsilon = Options.REST_ALPHA,
		onRest = function(alpha)
			if line.leaving and alpha <= 0 then
				self:Release(line)
			end
		end,
	})

	return line
end

---Returns a line to the pool at once: its timer cancelled, its springs stopped, hidden, unanchored, empty and without
---a key.
---@param line AUINotificationLine
function Notifications:Release(line)
	if line.timer then
		line.timer:Cancel()
		line.timer = nil
	end

	line.offset:Stop()
	line.opacity:Stop()
	line:Hide()
	line:ClearAllPoints()
	line:SetAlpha(1)
	line:SetText("")
	line.key, line.slot, line.sample, line.fade, line.leaving, line.travel, line.placed =
		nil, nil, nil, nil, nil, nil, nil

	for index, shown in ipairs(self.lines) do
		if shown == line then
			table.remove(self.lines, index)
			break
		end
	end

	self.pool[#self.pool + 1] = line
	self:Layout()
end

---Fades a line out as it moves up the way it came in, and gives its room to the lines below; a line whose opacity a
---feeder sets is released at once.
---@param line AUINotificationLine
---@param inPlace boolean? fades without moving, for a notice replaced in its slot
function Notifications:Leave(line, inPlace)
	if not line.fade then
		self:Release(line)

		return
	end

	if line.timer then
		line.timer:Cancel()
		line.timer = nil
	end

	line.leaving = true
	self:Layout()
	line.offset:To(line.offset.target - (inPlace and 0 or Options.TRAVEL))
	line.opacity.response = Options.FADE_OUT
	line.opacity:To(0)
end

---Gives each line still showing its place down from the stack's top, in their slots' order with samples after live
---notices of the same slot, sizes the stack to them, and sets the lines moving there. A new line starts its travel
---above its place.
---@param snap boolean? puts every line at its place without moving
function Notifications:Layout(snap)
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

	local width, height = 0, 0

	for _, line in ipairs(self.lines) do
		if not line.leaving then
			if height > 0 then
				height = height + Options.LINE_GAP
			end

			if snap then
				line.offset:Jump(height)
			else
				if not line.placed then
					line.offset:Jump(height - (line.travel or 0))
				end

				line.offset:To(height)
			end

			line.placed = true
			width = math.max(width, line:GetStringWidth())
			height = height + line:GetStringHeight()
		end
	end

	frame:SetSize(math.max(math.ceil(width), 1), math.max(math.ceil(height), 1))
end

---@param slot string
---@param sample boolean?
---@return AUINotificationLine? line the line showing in the slot, not one leaving it
function Notifications:Find(slot, sample)
	for _, line in ipairs(self.lines) do
		if line.slot == slot and not line.leaving and (line.sample == true) == (sample == true) then
			return line
		end
	end
end

---Shows a notice in its slot. A notice already showing is updated in place; one still leaving turns back from where
---it is; one replacing another notice in the slot cross-fades with it. A timed notice leaves after the duration;
---another stays until it is dismissed.
---@param key string
---@param text string? the text; the notice's own when nil
---@param options { sample: boolean?, fade: boolean? }? `fade = false` shows it at once and leaves its opacity to the
---caller
---@return AUINotificationLine line
function Notifications:Show(key, text, options)
	options = options or {}

	local notice = Options:Notice(key)
	local current, returning = self:Find(notice.slot, options.sample), nil

	for _, shown in ipairs(self.lines) do
		if shown.leaving and shown.key == key and (shown.sample == true) == (options.sample == true) then
			returning = shown
		end
	end

	local line, travel = current, Options.TRAVEL

	if current and current.key ~= key then
		self:Leave(current, true)
		line, travel = nil, 0
	end

	local new = false

	if line then
		if line.timer then
			line.timer:Cancel()
			line.timer = nil
		end
	elseif returning then
		line = returning
		line.leaving = nil
	else
		line = self:Acquire()
		line.slot, line.sample, line.travel = notice.slot, options.sample, travel
		self.lines[#self.lines + 1] = line
		new = true
	end

	local color = Options:Color(key)

	line.key = key
	line.fade = options.fade ~= false
	self:Style(line)
	line:SetText(text or Options:Text(key))
	line:SetTextColor(color.r, color.g, color.b)
	line:Show()

	if line.fade then
		if new then
			line.opacity:Jump(0)
		end

		line.opacity.response = Options.FADE_IN
		line.opacity:To(1)
	else
		line.travel = 0
		line.opacity:Jump(1)
		line:SetAlpha(1)
	end

	self:Layout()

	if notice.timed and not options.sample then
		line.timer = C_Timer.NewTimer(AUI.Profile:Get(Options.DURATION_PATH), function()
			line.timer = nil
			self:Leave(line)
		end)
	end

	return line
end

---Dismisses a notice if it shows.
---@param key string
function Notifications:Dismiss(key)
	for _, line in ipairs(self.lines) do
		if line.key == key and not line.sample and not line.leaving then
			self:Leave(line)

			return
		end
	end
end

---Removes lines at once, leaving ones included.
---@param sample boolean? true removes the samples, false or nil the live notices
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

		self:Layout(true)
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

	self:Layout(true)
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
