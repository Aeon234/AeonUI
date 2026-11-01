local AUI = select(2, ...)

local L = AUI.L
local lib = LibStub("LibAeonSettings-1.0")

local PREVIEW_HEIGHT = 120

-- Each notice's label, and its second line where it states a constraint.
local LABELS = {
	enter = L["Entering Combat"],
	leave = L["Leaving Combat"],
	lowHealth = L["Low Health"],
	potion = L["Potion Ready"],
	petMissing = L["Pet Missing"],
	petPassive = L["Pet Passive"],
	petHealth = L["Pet Low Health"],
	talents = L["Unspent Talent Points"],
	durability = L["Low Durability"],
	tracking = TRACKING,
}
local LINES = {
	petMissing = L["In combat or in instances."],
	petPassive = L["In combat or in instances."],
	petHealth = L["In combat or in instances."],
	talents = L["Out of combat."],
	durability = L["Out of combat."],
	tracking = L["Outside instances."],
}

---The Notifications page, under the Quality of Life header: a sample of the notices turned on as its preview, the Text
---card, and the Combat, Pet and Character cards, each notice a checkbox with its text and color in a Text row that
---opens in place. Changes take effect at once.
---@class AUISettingsNotifications
local SettingsNotifications = {}
AUI.SettingsNotifications = SettingsNotifications

---Each notice turned on, one per slot, in the stack's style and colors; each line finds its notice's row.
---@class AUINotificationsPreview
---@field texts FontString[]
local NotificationsPreview = {
	texts = {},
}

---@param canvas Frame
---@param preview table
---@return number width
---@return number height
function NotificationsPreview:Refresh(canvas, preview)
	local Notifications, Options = AUI.Notifications, AUI.NotificationOptions
	local keys = Notifications:SampleKeys()
	local width, height = 0, 0
	local previous

	for index, text in ipairs(self.texts) do
		text:SetShown(index <= #keys)
	end

	for index, key in ipairs(keys) do
		local text = self.texts[index]

		if not text then
			text = canvas:CreateFontString(nil, "OVERLAY")
			self.texts[index] = text
		end

		local color = Options:Color(key)

		Notifications:Style(text)
		text:SetText(Notifications:SampleText(key))
		text:SetTextColor(color.r, color.g, color.b)
		text:ClearAllPoints()

		if previous then
			text:SetPoint("TOP", previous, "BOTTOM", 0, -Options.LINE_GAP)
		else
			text:SetPoint("TOP", canvas, "TOP")
		end

		width = math.max(width, math.ceil(text:GetUnboundedStringWidth()))
		height = height + math.ceil(text:GetStringHeight()) + (index > 1 and Options.LINE_GAP or 0)
		previous = text
		preview:Part(text, key, { text = true })
	end

	return width, height
end

---@param section table
---@param key string a notice
---@param extra fun(section: table, details: string)? adds the notice's own settings inside its Text row
local function DeclareNotice(section, key, extra)
	local Settings, Options = AUI.Settings, AUI.NotificationOptions
	local enabled, text, color = Options:Path(key, "enabled"), Options:Path(key, "text"), Options:Path(key, "color")
	local details = key .. "Text"

	section:Checkbox({
		id = key,
		label = LABELS[key],
		description = LINES[key],
		path = enabled,
		default = Settings:Default(enabled),
	})
	section:Details({
		id = details,
		label = L["Text"],
		depends = key,
		summary = function()
			return Options:Text(key)
		end,
	})
	section:TextInput({
		id = key .. "_text",
		label = L["Text"],
		path = text,
		default = Settings:Default(text),
		details = details,
		allowEmpty = true,
		maxLetters = 40,
	})
	section:Color({
		id = key .. "_color",
		label = COLOR,
		path = color,
		default = Settings:Default(color),
		details = details,
		resettable = true,
	})

	if extra then
		extra(section, details)
	end
end

---@param path string
---@param min number
---@param max number
---@return fun(section: table, details: string) extra a Below slider inside a notice's Text row
local function Below(path, min, max)
	return function(section, details)
		section:Slider({
			id = details .. "_below",
			label = L["Show Below"],
			path = path,
			default = AUI.Settings:Default(path),
			details = details,
			min = min,
			max = max,
			step = 5,
			format = "percent",
		})
	end
end

---@return fun(section: table, details: string) extra the trackings Tracking reminds about, inside its Text row: the
---character's class's and race's, and the professions'
local function RemindAbout()
	return function(section, details)
		local Options = AUI.NotificationOptions
		local _, class = UnitClass("player")
		local _, race = UnitRace("player")
		local options, default = {}, {}

		for index, tracking in ipairs(Options:TrackingsFor(class, race)) do
			options[index] = { value = tracking.key, text = tracking.label }
			default[tracking.key] = AUI.Settings:Default(Options.TRACKING_PATH .. "." .. tracking.key)
		end

		section:Dropdown({
			id = details .. "_remind",
			label = L["Remind About"],
			path = Options.TRACKING_PATH,
			default = default,
			details = details,
			multiple = true,
			options = options,
		})
	end
end

---@param page table
function SettingsNotifications:DeclareText(page)
	local Settings, Options = AUI.Settings, AUI.NotificationOptions
	local card = page:Section("notificationsStyle", L["Text"])

	card:Dropdown({
		id = "font",
		label = L["Font"],
		path = Options.FONT_PATH,
		default = Settings:Default(Options.FONT_PATH),
		picker = "font",
	})
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
		id = "outline",
		label = L["Outline"],
		path = Options.OUTLINE_PATH,
		default = Settings:Default(Options.OUTLINE_PATH),
		options = lib.OUTLINES,
	})
end

---@param page table
function SettingsNotifications:DeclareCombat(page)
	local Settings, Options = AUI.Settings, AUI.NotificationOptions
	local card = page:Section("notificationsCombat", COMBAT)

	DeclareNotice(card, "enter")
	DeclareNotice(card, "leave")

	if AUI.can.lowHealthNotice then
		DeclareNotice(card, "lowHealth", Below(Options.LOW_HEALTH_PATH, 5, 90))
	end

	if AUI.can.potionNotice then
		DeclareNotice(card, "potion")
	end

	card:Slider({
		id = "duration",
		label = L["Duration"],
		path = Options.DURATION_PATH,
		default = Settings:Default(Options.DURATION_PATH),
		min = 1,
		max = 10,
		step = 1,
	})
end

---@param page table
function SettingsNotifications:DeclarePet(page)
	if not AUI.can.petNotices then
		return
	end

	local card = page:Section("notificationsPet", PET)

	DeclareNotice(card, "petMissing")
	DeclareNotice(card, "petPassive")

	if AUI.can.petHealthNotice then
		DeclareNotice(card, "petHealth", Below(AUI.NotificationOptions.PET_HEALTH_PATH, 5, 90))
	end
end

---@param page table
function SettingsNotifications:DeclareCharacter(page)
	local can = AUI.can

	if not (can.talentNotice or can.durabilityNotice or can.trackingNotice) then
		return
	end

	local card = page:Section("notificationsCharacter", CHARACTER)

	if can.talentNotice then
		DeclareNotice(card, "talents")
	end

	if can.durabilityNotice then
		DeclareNotice(card, "durability", Below(AUI.NotificationOptions.DURABILITY_PATH, 10, 90))
	end

	if can.trackingNotice then
		DeclareNotice(card, "tracking", RemindAbout())
	end
end

---@param window table
function SettingsNotifications:Declare(window)
	local page = window:Page("notifications", {
		title = L["Notifications"],
		under = "qualityOfLifeHeader",
		icon = AUI.Media.sidebar.notifications,
		iconTint = true,
	})

	if not page then
		return
	end

	page:Preview({
		height = PREVIEW_HEIGHT,
		refresh = function(canvas, _, preview)
			return NotificationsPreview:Refresh(canvas, preview)
		end,
	})

	self:DeclareText(page)
	self:DeclareCombat(page)
	self:DeclarePet(page)
	self:DeclareCharacter(page)
end
