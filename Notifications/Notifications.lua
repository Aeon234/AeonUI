local AUI = select(2, ...)

local Options = AUI.NotificationOptions

---@class AUINotificationLine : FontString
---@field key string? the notice shown, or nil while pooled
---@field slot string?
---@field sample boolean? an edit-mode or preview sample, kept apart from live notices
---@field timer table?
---@field fade boolean? the stack owns the line's opacity; false while a feeder sets it
---@field leaving boolean? fading out, no longer holding room in the stack
---@field travel number? units above its place the line starts from when it first shows
---@field y number? the line's offset below the stack's top, nil until first placed
---@field velocity number
---@field target number the offset the line moves to
---@field alpha number the line's opacity while the stack owns it
---@field alphaVelocity number
---@field alphaTarget number

---The Notifications module: one stack of short text lines at a place set in edit mode. A notice slides down into its
---place as it fades in and leaves the way it came, while the lines below move to close or open its room. Every
---motion is a critically damped spring that starts from where the line is, so a notice shown again while it leaves
---turns back without a jump. A timed notice holds for the duration; another stays until its condition ends. A notice
---replacing another in its slot cross-fades with it in place. Lines come from a pool. The feeders (combat, pet,
---character, potion) decide what shows; this object draws it.
---@class AUINotifications
---@field active boolean started this session
---@field frame Frame? the named stack, created the first time a notice or sample shows
---@field lines AUINotificationLine[] shown lines, leaving ones included
---@field pool AUINotificationLine[] released lines
---@field moving boolean the stack's OnUpdate runs
---@field step fun(frame: Frame, elapsed: number)?
local Notifications = {
	active = false,
	lines = {},
	pool = {},
	moving = false,
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
	self.step = function(_, elapsed)
		self:Step(elapsed)
	end
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
	return table.remove(self.pool) or self:Frame():CreateFontString(nil, "OVERLAY") --[[@as AUINotificationLine]]
end

---Returns a line to the pool at once: its timer cancelled, hidden, unanchored, empty and without a key or motion.
---@param line AUINotificationLine
function Notifications:Release(line)
	if line.timer then
		line.timer:Cancel()
		line.timer = nil
	end

	line:Hide()
	line:ClearAllPoints()
	line:SetAlpha(1)
	line:SetText("")
	line.key, line.slot, line.sample, line.fade, line.leaving, line.travel, line.y = nil, nil, nil, nil, nil, nil, nil

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
	line.target = (line.y or 0) - (inPlace and 0 or Options.TRAVEL)
	line.alphaTarget = 0
	self:Layout()
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

			line.target = height

			if snap or not line.y then
				line.y, line.velocity = height - (snap and 0 or line.travel or 0), 0
			end

			width = math.max(width, line:GetStringWidth())
			height = height + line:GetStringHeight()
		end
	end

	frame:SetSize(math.max(math.ceil(width), 1), math.max(math.ceil(height), 1))
	self:Step(0)
end

---Moves each line and its opacity one frame along their springs, releases a leaving line once it is clear, and runs
---the stack's OnUpdate only while something is still moving.
---@param elapsed number seconds since the last frame
function Notifications:Step(elapsed)
	local frame = self.frame

	if not frame then
		return
	end

	local moving, cleared = false, nil

	for _, line in ipairs(self.lines) do
		local settled, faded = true, true

		line.y, line.velocity, settled = Options:Spring(line.y or line.target, line.velocity, line.target, Options.MOVE_RESPONSE,
			elapsed, Options.REST_DISTANCE)
		line:SetPoint("TOP", frame, "TOP", 0, -line.y)

		if line.fade then
			local response = line.alphaTarget > line.alpha and Options.FADE_IN or Options.FADE_OUT

			line.alpha, line.alphaVelocity, faded = Options:Spring(line.alpha, line.alphaVelocity, line.alphaTarget,
				response, elapsed, Options.REST_ALPHA)
			line:SetAlpha(math.min(math.max(line.alpha, 0), 1))
		end

		if line.leaving and faded then
			cleared = cleared or {}
			cleared[#cleared + 1] = line
		elseif not (settled and faded) then
			moving = true
		end
	end

	if moving ~= self.moving then
		self.moving = moving
		frame:SetScript("OnUpdate", moving and self.step or nil)
	end

	if cleared then
		for _, line in ipairs(cleared) do
			self:Release(line)
		end
	end
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
		line.alpha, line.alphaVelocity = 0, 0
		self.lines[#self.lines + 1] = line
	end

	local color = Options:Color(key)

	line.key = key
	line.fade = options.fade ~= false
	line.alphaTarget = 1
	self:Style(line)
	line:SetText(text or Options:Text(key))
	line:SetTextColor(color.r, color.g, color.b)
	line:Show()

	if not line.fade then
		line.alpha, line.alphaVelocity, line.travel = 1, 0, 0
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
