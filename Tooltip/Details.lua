local AUI = select(2, ...)

local Options, Format = AUI.TooltipOptions, AUI.TooltipFormat
local L = AUI.L

local AURA_IDS_CVAR = "tooltipShowAuraSpellIDs"
-- The gem-socketing window's item text is a data tooltip inside that window.
local SOCKETING_TOOLTIP = "ItemSocketingDescription"
-- Blizzard events that show GameTooltip for a quest without quest tooltip data; each passes the quest ID second.
local QUEST_EVENTS = {
	"QuestMapLogTitleButton.OnEnter",
	"BonusObjectiveBlock.QuestRewardTooltipShown",
	"MapCanvas.QuestPin.OnEnter",
	"TaskPOI.TooltipShown",
}
-- The sample tooltip's values, for the lines of tooltips the settings preview cannot build.
local SAMPLE = { npc = 3100, age = 754, currency = 3008, mount = 6, quest = 86, macro = 8690 }

---@param value any
---@return number? id a readable number, or nil
local function ID(value)
	value = AUI:Readable(value)

	return type(value) == "number" and value or nil
end

---Adds detail lines to every data tooltip: an item's expansion, category and type, and maximum stack, and the IDs of
---items, spells, auras, icons, NPCs (with how long they have been spawned), currencies, mounts, quests and the spell or
---item a macro uses. Each line is a gold label with a white value, after an optional blank line; the ID lines can wait
---for a held modifier, and a change of that key rebuilds `GameTooltip` out of combat. The settings preview's tooltips
---always get every chosen line. Also owns the `tooltipShowAuraSpellIDs` CVar, which lets the client draw aura IDs
---itself while they are secret to addons.
---@class AUITooltipDetails
---@field hooked boolean
---@field auraIDsSet boolean AeonUI turned the aura spell ID CVar on, so aura tooltips get no ID line of their own
---@field labels string[] the lines being built, reused
---@field values string[]
---@field count number
---@field previews GameTooltip[]? the settings preview's tooltips
local Details = {
	hooked = false,
	auraIDsSet = false,
	labels = {},
	values = {},
	count = 0,
}
AUI.TooltipDetails = Details

---@param key string an `Options.ID_KEYS` entry
---@return boolean
function Details:Shows(key)
	return AUI.Profile:Get(Options.ID_PATHS[key]) == true
end

---@return boolean held the ID lines' modifier is held, or none is needed
function Details:Held()
	local modifier = AUI.Profile:Get(Options.ID_MODIFIER_PATH)

	if modifier == "SHIFT" then
		return IsShiftKeyDown()
	elseif modifier == "CTRL" then
		return IsControlKeyDown()
	elseif modifier == "ALT" then
		return IsAltKeyDown()
	end

	return true
end

---@param tooltip GameTooltip
---@return boolean
function Details:IsPreview(tooltip)
	for _, preview in ipairs(self.previews or {}) do
		if preview == tooltip then
			return true
		end
	end

	return false
end

---@param label string
---@param value string|number
function Details:Add(label, value)
	local count = self.count + 1

	self.labels[count], self.values[count] = label, tostring(value)
	self.count = count
end

---Adds the lines built since the count was reset.
---@param tooltip GameTooltip
function Details:Finish(tooltip)
	if self.count == 0 then
		return
	end

	if AUI.Profile:Get(Options.BLANK_LINE_PATH) == true then
		tooltip:AddLine(" ")
	end

	local label, value = NORMAL_FONT_COLOR, HIGHLIGHT_FONT_COLOR

	for index = 1, self.count do
		tooltip:AddDoubleLine(self.labels[index], self.values[index], label.r, label.g, label.b, value.r, value.g,
			value.b)
	end

	self.count = 0
end

---@param id number
---@param ids boolean the ID lines show
function Details:Item(id, ids)
	local Profile = AUI.Profile
	local _, _, _, _, _, itemType, subType, stack, _, _, _, _, _, _, expansion = C_Item.GetItemInfo(id)

	if AUI.can.expansions and Profile:Get(Options.EXPANSION_PATH) == true then
		local name = expansion and _G["EXPANSION_NAME" .. expansion]

		if type(name) == "string" then
			self:Add(EXPANSION_FILTER_TEXT, name)
		end
	end

	local kind = Profile:Get(Options.ITEM_TYPE_PATH) == true and Format:ItemType(itemType, subType)

	if kind then
		self:Add(TYPE, kind)
	end

	if Profile:Get(Options.MAX_STACK_PATH) == true and type(stack) == "number" and stack > 1 then
		self:Add(L["Max Stack"], stack)
	end

	if not ids then
		return
	end

	if self:Shows("item") then
		self:Add(L["Item ID"], id)
	end

	local icon = self:Shows("icon") and ID(C_Item.GetItemIconByID(id))

	if icon then
		self:Add(L["Icon ID"], icon)
	end
end

---@param id number
---@param aura boolean an aura's tooltip
function Details:Spell(id, aura)
	if self:Shows("spell") and not (aura and self.auraIDsSet) then
		self:Add(L["Spell ID"], id)
	end

	local icon = self:Shows("icon") and ID(C_Spell.GetSpellTexture(id))

	if icon then
		self:Add(L["Icon ID"], icon)
	end
end

---@param guid string
function Details:Creature(guid)
	local npcID = Format:NPCID(guid)

	if not npcID then
		return
	end

	if self:Shows("npc") then
		self:Add(L["NPC ID"], npcID)
	end

	local age = self:Shows("age") and Format:SpawnAge(guid, GetServerTime())

	if age then
		self:Add(L["Spawned"], L["%s ago"]:format(SecondsToTime(age, false, false, 2)))
	end
end

---@param id number
function Details:Mount(id)
	if self:Shows("mount") then
		self:Add(L["Mount ID"], id)
	end

	local _, spellID = C_MountJournal.GetMountInfoByID(id)

	spellID = ID(spellID)

	if spellID and self:Shows("spell") then
		self:Add(L["Spell ID"], spellID)
	end
end

---The spell a macro casts, as the client resolves its conditions, or the item it uses.
---@param tooltip GameTooltip
---@param data table
function Details:Macro(tooltip, data)
	if not self:Shows("macro") then
		return
	end

	local first = data.lines and data.lines[1]
	local spellID = first and ID(first.tooltipID)

	if spellID then
		self:Add(L["Spell ID"], spellID)

		return
	end

	local info = tooltip.processingInfo
	local action = info and info.getterName == "GetAction" and info.getterArgs and ID(info.getterArgs[1])
	local name = action and AUI.can.macroItems and AUI:Readable(C_ActionBar.GetActionText(action))

	if type(name) ~= "string" then
		return
	end

	local _, link = GetMacroItem(name)
	local itemID = link and ID(C_Item.GetItemIDForItemInfo(link))

	if itemID then
		self:Add(L["Item ID"], itemID)
	end
end

---@param tooltip GameTooltip
---@param kind string "item", "spell", "aura", "pet", "unit", "currency", "mount", "quest" or "macro"
---@param data table? the tooltip's data
function Details:OnTooltip(tooltip, kind, data)
	if not data or tooltip:IsForbidden() then
		return
	end

	local preview = self:IsPreview(tooltip)

	if not preview and (not AUI.Tooltip:IsEnabled() or tooltip:GetName() == SOCKETING_TOOLTIP) then
		return
	end

	local ids = preview or self:Held()
	local id = ID(data.id)

	self.count = 0

	if kind == "item" then
		if id then
			self:Item(id, ids)
		end
	elseif not ids then
		return
	elseif kind == "spell" or kind == "aura" or kind == "pet" then
		local first = kind == "pet" and data.lines and data.lines[1] or nil

		id = id or (first and ID(first.tooltipID))

		if id then
			self:Spell(id, kind == "aura")
		end
	elseif kind == "unit" then
		local guid = AUI:Readable(data.guid)

		if type(guid) == "string" then
			self:Creature(guid)
		end
	elseif kind == "currency" then
		if id and self:Shows("currency") then
			self:Add(L["Currency ID"], id)
		end
	elseif kind == "mount" then
		if id then
			self:Mount(id)
		end
	elseif kind == "quest" then
		if id and self:Shows("quest") then
			self:Add(L["Quest ID"], id)
		end
	elseif kind == "macro" then
		self:Macro(tooltip, data)
	end

	self:Finish(tooltip)
end

---Fills the settings preview's sample tooltip with the chosen lines of tooltips the preview cannot build (creatures,
---currencies, mounts, quests and macros), with sample values. A mount's Spell ID is left to the sample spell.
---@param tooltip GameTooltip owned and cleared
---@return boolean filled it has lines; with none it is left empty
function Details:Sample(tooltip)
	self.count = 0

	if self:Shows("npc") then
		self:Add(L["NPC ID"], SAMPLE.npc)
	end

	if self:Shows("age") then
		self:Add(L["Spawned"], L["%s ago"]:format(SecondsToTime(SAMPLE.age, false, false, 2)))
	end

	if self:Shows("currency") then
		self:Add(L["Currency ID"], SAMPLE.currency)
	end

	if self:Shows("mount") then
		self:Add(L["Mount ID"], SAMPLE.mount)
	end

	if self:Shows("quest") then
		self:Add(L["Quest ID"], SAMPLE.quest)
	end

	if self:Shows("macro") then
		self:Add(L["Spell ID"], SAMPLE.macro)
	end

	if self.count == 0 then
		return false
	end

	local title = HIGHLIGHT_FONT_COLOR

	tooltip:AddLine(L["Other Tooltips"], title.r, title.g, title.b)
	self:Finish(tooltip)

	return true
end

---The Quest ID on `GameTooltip` where Blizzard shows a quest without quest tooltip data.
---@param questID any
function Details:OnQuest(questID)
	local tooltip = GameTooltip

	questID = ID(questID)

	if not questID or tooltip:IsForbidden() or not tooltip:IsShown() or not AUI.Tooltip:IsEnabled()
		or tooltip:IsTooltipType(Enum.TooltipDataType.Quest) or not self:Shows("quest") or not self:Held() then
		return
	end

	self.count = 0
	self:Add(L["Quest ID"], questID)
	self:Finish(tooltip)
	tooltip:Show()
end

---Rebuilds `GameTooltip` when the ID lines' modifier goes down or up, so its lines follow the key. Never in combat,
---where a rebuild from addon code could spread taint into Blizzard's tooltip.
---@param key string
function Details:OnModifier(key)
	local tooltip = GameTooltip

	if InCombatLockdown() or not Format:IsModifierKey(AUI.Profile:Get(Options.ID_MODIFIER_PATH), key)
		or not AUI.Tooltip:IsEnabled() or tooltip:IsForbidden() or not tooltip:IsShown() then
		return
	end

	local data = tooltip:GetPrimaryTooltipData()

	if data and not issecretvalue(data.guid) then
		tooltip:RefreshData()
	end
end

---Turns the client's own aura IDs on while Spell IDs show with no modifier, and off again when AeonUI turned them on.
---@param on boolean the module is on
function Details:Apply(on)
	if not AUI.can.auraSpellIDs then
		return
	end

	local Profile = AUI.Profile
	local want = on and self:Shows("spell") and Profile:Get(Options.ID_MODIFIER_PATH) == "NONE"

	if want then
		self.auraIDsSet = true

		if C_CVar.GetCVar(AURA_IDS_CVAR) ~= "1" then
			C_CVar.SetCVar(AURA_IDS_CVAR, "1")
		end
	elseif self.auraIDsSet then
		self.auraIDsSet = false
		C_CVar.SetCVar(AURA_IDS_CVAR, "0")
	end
end

---Installs the post-calls, the quest callbacks and the modifier watch once; they do nothing while the module is off.
function Details:Hook()
	if self.hooked or not TooltipDataProcessor or not GameTooltip then
		return
	end

	self.hooked = true

	local types = Enum.TooltipDataType
	local kinds = {
		[types.Item] = "item",
		[types.Toy] = "item",
		[types.Spell] = "spell",
		[types.UnitAura] = "aura",
		[types.PetAction] = "pet",
		[types.Unit] = "unit",
		[types.Corpse] = "unit",
		[types.Currency] = "currency",
		[types.Mount] = "mount",
		[types.Quest] = "quest",
		[types.Macro] = "macro",
	}

	for dataType, kind in pairs(kinds) do
		TooltipDataProcessor.AddTooltipPostCall(dataType, function(tooltip, data)
			Details:OnTooltip(tooltip, kind, data)
		end)
	end

	for _, event in ipairs(QUEST_EVENTS) do
		EventRegistry:RegisterCallback(event, function(_, _, questID)
			Details:OnQuest(questID)
		end, self)
	end

	AUI.Events:Register("MODIFIER_STATE_CHANGED", self, function(_, _, key)
		Details:OnModifier(key)
	end)
end
