local AUI = select(2, ...)

local L = AUI.L
local lib = LibStub("LibAeonSettings-1.0")

local PREVIEW_HEIGHT = 120

local ARRANGEMENT_LABELS = {
	DURATION_NAME = L["Time, Then Name"],
	NAME_DURATION = L["Name, Then Time"],
	DURATION = L["Time Only"],
}

---The Movement Alerts page, under the Quality of Life header, on clients that have the feature: the module's switch, a
---sample of the tracked spells' lines as its preview, and the Text, Visibility and Tracked Spells cards.
---@class AUISettingsMovementAlert
local SettingsMovementAlert = {}
AUI.SettingsMovementAlert = SettingsMovementAlert

---A line per tracked spell, stacked as the real lines are.
---@class AUIMovementAlertPreview
---@field texts FontString[]
local MovementAlertPreview = {
	texts = {},
}

---@param canvas Frame
---@param preview table
---@return number width
---@return number height
function MovementAlertPreview:Refresh(canvas, preview)
	local Alert, Options, Profile = AUI.MovementAlert, AUI.MovementAlertOptions, AUI.Profile
	local names = Alert:SampleNames()
	local arrangement = Profile:Get(Options.ARRANGEMENT_PATH)
	local decimal = Profile:Get(Options.DECIMAL_PATH) == true
	local size = Profile:Get(Options.SIZE_PATH)
	local lineHeight = Options:LineHeight(size)
	local width = 0

	for index, text in ipairs(self.texts) do
		text:SetShown(index <= #names)
	end

	for index, name in ipairs(names) do
		local text = self.texts[index]

		if not text then
			text = canvas:CreateFontString(nil, "OVERLAY")
			self.texts[index] = text
		end

		Alert:Style(text)
		text:SetText(Options:SampleText(arrangement, decimal, name))
		text:ClearAllPoints()
		text:SetPoint("CENTER", canvas, "BOTTOM", 0, Options:LineOffset(index, size) + lineHeight / 2)
		width = math.max(width, math.ceil(text:GetUnboundedStringWidth()))
		preview:Part(text, "font", { text = true })
	end

	return width, Options:LineOffset(#names, size) + lineHeight
end

---@param page table
function SettingsMovementAlert:DeclareText(page)
	local Settings, Options = AUI.Settings, AUI.MovementAlertOptions
	local card = page:Section("movementAlertText", L["Text"])
	local arrangements = {}

	for index, arrangement in ipairs(Options.ARRANGEMENTS) do
		arrangements[index] = { value = arrangement, text = ARRANGEMENT_LABELS[arrangement] }
	end

	card:Dropdown({
		id = "arrangement",
		label = L["Format"],
		path = Options.ARRANGEMENT_PATH,
		default = Settings:Default(Options.ARRANGEMENT_PATH),
		options = arrangements,
	})
	card:Checkbox({
		id = "decimal",
		label = L["Show Decimal"],
		path = Options.DECIMAL_PATH,
		default = Settings:Default(Options.DECIMAL_PATH),
	})
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
end

---@param page table
function SettingsMovementAlert:DeclareVisibility(page)
	local Options = AUI.MovementAlertOptions
	local card = page:Section("movementAlertVisibility", L["Visibility"])

	card:Checkbox({
		id = "combatOnly",
		label = L["Combat Only"],
		path = Options.COMBAT_ONLY_PATH,
		default = AUI.Settings:Default(Options.COMBAT_ONLY_PATH),
	})
end

---The character's class's abilities, each named as the character knows it.
---@param page table
function SettingsMovementAlert:DeclareSpells(page)
	local Options = AUI.MovementAlertOptions
	local card = page:Section("movementAlertSpells", L["Tracked Spells"], { columns = 2 })
	local _, class = UnitClass("player")

	for _, spell in ipairs(Options:ClassSpells(class)) do
		local name = AUI.MovementAlert:AbilityName(spell)

		if name then
			local path = Options:SpellPath(spell)

			card:Checkbox({
				id = "spell" .. spell.ids[1],
				label = name,
				path = path,
				default = AUI.Settings:Default(path),
			})
		end
	end
end

---@return boolean
function SettingsMovementAlert:IsAvailable()
	return AUI.can.movementAlert == true
end

---@param window table
function SettingsMovementAlert:Declare(window)
	local Settings, Options = AUI.Settings, AUI.MovementAlertOptions
	local page = window:Page("movementAlert", {
		title = L["Movement Alerts"],
		under = "qualityOfLifeHeader",
		icon = AUI.Media.sidebar.movementAlert,
		iconTint = true,
		switch = {
			path = Options.ENABLED_PATH,
			default = Settings:Default(Options.ENABLED_PATH),
			label = L["Show Movement Alerts"],
		},
	})

	if not page then
		return
	end

	page:Preview({
		height = PREVIEW_HEIGHT,
		refresh = function(canvas, _, preview)
			return MovementAlertPreview:Refresh(canvas, preview)
		end,
	})

	self:DeclareText(page)
	self:DeclareVisibility(page)
	self:DeclareSpells(page)
end

AUI.Modules:Register({
	group = "qualityOfLife",
	page = SettingsMovementAlert,
	start = function()
		AUI.MovementAlert:Start()
	end,
	editTargets = {
		{
			key = "movementAlert",
			path = "movementAlert.position",
			target = function()
				local Alert = AUI.MovementAlert

				if Alert.frame and Alert:IsOn() then
					return {
						label = L["Movement Alerts"],
						frame = Alert.frame,
						default = AUI.MovementAlertOptions:DefaultPosition(UIParent:GetHeight()),
						fixedEdge = "BOTTOM",
						sample = function(shown)
							Alert:Sample(shown)
						end,
						settings = { page = "movementAlert", section = "movementAlertText" },
					}
				end
			end,
		},
	},
})
