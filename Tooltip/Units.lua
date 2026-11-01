local AUI = select(2, ...)

local Options, Format = AUI.TooltipOptions, AUI.TooltipFormat
local L = AUI.L

local CASTER_NAMES_CVAR = "tooltipShowAuraCasterNames"
-- How long a player's mount is kept, so the tooltip's refreshes do not scan their auras again.
local MOUNT_TTL = 3
local MAX_AURAS = 255
local ICON_SIZE = 14
-- The Units preview's made-up values: a guild, its rank, a rating and a mount (Brown Horse), and how many levels the
-- sample creature is above the player.
local SAMPLE = { guild = "AeonUI", rating = 2500, mount = 6, creatureLevels = 2 }

---@param classFile string?
---@return AUITooltipColor?
local function ClassColor(classFile)
	return classFile and C_ClassColor.GetClassColor(classFile) or nil
end

---@param unit string
---@return AUITooltipColor?
local function ReactionColor(unit)
	local reaction = AUI:Readable(UnitReaction(unit, "player"))

	return reaction and FACTION_BAR_COLORS[reaction] or nil
end

---@param guid string
---@return string? unit a token for the unit with that GUID, or nil when none can be read
local function Token(guid)
	local unit = AUI:Readable(UnitTokenFromGUID(guid))

	if unit then
		return unit
	end

	if AUI:Readable(UnitGUID("mouseover")) == guid then
		return "mouseover"
	end

	return nil
end

---@param tooltip GameTooltip
---@param label string
---@param value string
---@param color AUITooltipColor
local function AddLine(tooltip, label, value, color)
	local gold = NORMAL_FONT_COLOR

	tooltip:AddDoubleLine(label, value, gold.r, gold.g, gold.b, color.r, color.g, color.b)
end

---What `GameTooltip` shows for a unit: the name in its class or selection color with or without titles, the guild
---line and rank, the level in its difficulty color, grayed owner and corpse lines, battle-pet names in their reaction
---color, and the Target, Mythic+ Rating and Mount lines; the health bar takes the name's color. Lines are edited
---after Blizzard has built them, through each line's `lineIndex`, and a secret value leaves a line as Blizzard drew
---it. Also owns the `tooltipShowAuraCasterNames` CVar while the module is on.
---@class AUITooltipUnits
---@field hooked boolean
---@field levelPattern string? matches Blizzard's level line when the client does not tag it
---@field barColored boolean the health bar is kept in `barColor` until the tooltip clears
---@field barColor AUITooltipColor
---@field selection AUITooltipColor a minion's selection color, reused
---@field mount { guid: string?, time: number, text: string? } the last player's mount line value
local Units = {
	hooked = false,
	barColored = false,
	barColor = { r = 1, g = 1, b = 1 },
	selection = { r = 1, g = 1, b = 1 },
	mount = { time = 0 },
}
AUI.TooltipUnits = Units

---@param unit string?
---@param classFile string? the class of a player
---@param pet boolean the unit is a battle pet
---@return AUITooltipColor? color nil to keep Blizzard's
function Units:NameColor(unit, classFile, pet)
	if classFile then
		return ClassColor(classFile)
	end

	if not unit then
		return nil
	end

	if AUI:Readable(UnitTreatAsPlayerForDisplay(unit)) == true then
		local _, token = UnitClass(unit)

		return ClassColor(AUI:Readable(token))
	elseif pet then
		return Options:Get(Options.MUTED_LINES_PATH) == true and ReactionColor(unit) or nil
	elseif AUI:Readable(UnitIsMinion(unit)) == true then
		local r, g, b = UnitSelectionColor(unit, true)

		r, g, b = AUI:Readable(r), AUI:Readable(g), AUI:Readable(b)

		if r and g and b then
			local selection = self.selection

			selection.r, selection.g, selection.b = r, g, b

			return selection
		end
	end

	return nil
end

---@param left FontString
---@param text string Blizzard's name line
---@param guid string
---@param player boolean
---@param color AUITooltipColor?
function Units:Name(left, text, guid, player, color)
	if player then
		local name, second = UnitNameFromGUID(guid)

		name, second = AUI:Readable(name), AUI:Readable(second)

		if type(name) == "string" then
			local separator = AUI.can.surnames and Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR

			if Options:Get(Options.TITLES_PATH) ~= true then
				left:SetText(Format:FullName(name, second, separator or nil))
			elseif not separator and type(second) == "string" and second ~= "" and not text:find(second, 1, true) then
				left:SetText(text .. "-" .. second)
			end
		end
	end

	if color then
		left:SetTextColor(color.r, color.g, color.b)
	end
end

---@param left FontString
---@param text string Blizzard's level line
---@param unit string
---@param player boolean
function Units:Level(left, text, unit, player)
	local level = AUI:Readable(UnitEffectiveLevel(unit))

	if type(level) ~= "number" then
		return
	end

	local color, mark

	if player and AUI:Readable(UnitIsFriend(unit, "player")) == true then
		color = Format.FRIENDLY_LEVEL
	else
		color = GetDifficultyColor(AUI:Readable(C_PlayerInfo.GetContentDifficultyCreatureForPlayer(unit)))

		if not player then
			mark = Format:Mark(AUI:Readable(UnitClassification(unit)), L["Rare"], BOSS)
		end
	end

	local line = Format:Level(text, level, color, mark)

	if line then
		left:SetText(line)
	end
end

---@param left FontString
---@param text string Blizzard's guild line
---@param unit string
---@param rank string?
function Units:Guild(left, text, unit, rank)
	local color = AUI:Readable(UnitIsInMyGuild(unit)) == true and Format.OWN_GUILD or Format.GUILD

	left:SetText(Format:Guild(text, Options:Get(Options.GUILD_RANK_PATH) == true and rank or nil))
	left:SetTextColor(color.r, color.g, color.b)
end

---@param tooltip GameTooltip
---@param unit string
function Units:AddTarget(tooltip, unit)
	local target = unit .. "target"

	if not C_Secrets or AUI:Readable(C_Secrets.ShouldUnitIdentityBeSecret(target), true) ~= false
		or AUI:Readable(UnitExists(target)) ~= true then
		return
	end

	local value, color

	if AUI:Readable(UnitIsUnit(target, "player")) == true then
		value, color = YOU, Format.YOU
	else
		value = AUI:Readable(UnitName(target))

		if type(value) ~= "string" then
			return
		end

		if AUI:Readable(UnitIsPlayer(target)) == true then
			local _, classFile = UnitClass(target)

			color = ClassColor(AUI:Readable(classFile))
		else
			color = ReactionColor(target)
		end
	end

	AddLine(tooltip, TARGET, value, color or Format.VALUE)
end

---@param tooltip GameTooltip
---@param unit string
function Units:AddRating(tooltip, unit)
	local summary = AUI:Readable(C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit))
	local score = summary and AUI:Readable(summary.currentSeasonScore)

	if type(score) ~= "number" or score <= 0 then
		return
	end

	AddLine(tooltip, DUNGEON_SCORE, tostring(math.floor(score)), C_ChallengeMode.GetDungeonScoreRarityColor(score)
		or Format.VALUE)
end

---@param unit string
---@return string? text the mount a player rides, marked by whether the player has it; nil while not mounted or while
---auras cannot be read
function Units:FindMount(unit)
	if InCombatLockdown() or not C_Secrets or AUI:Readable(C_Secrets.ShouldAurasBeSecret(), true) ~= false then
		return nil
	end

	for index = 1, MAX_AURAS do
		local aura = C_UnitAuras.GetAuraDataByIndex(unit, index, "HELPFUL")

		if not aura then
			break
		end

		local spellID = AUI:Readable(aura.spellId)
		local mountID = spellID and C_MountJournal.GetMountFromSpell(spellID)

		if mountID and not issecretvalue(mountID) and mountID > 0 then
			local name, _, _, _, _, _, _, _, _, _, collected = C_MountJournal.GetMountInfoByID(mountID)

			name = AUI:Readable(name)

			if type(name) == "string" and name ~= "" then
				if collected == true then
					return name .. " " .. CreateAtlasMarkup("common-icon-checkmark", ICON_SIZE, ICON_SIZE)
				elseif collected == false then
					return name .. " " .. CreateAtlasMarkup("common-icon-redx", ICON_SIZE, ICON_SIZE)
				end

				return name
			end
		end
	end

	return nil
end

---@param tooltip GameTooltip
---@param guid string
---@param unit string
function Units:AddMount(tooltip, guid, unit)
	local cache = self.mount
	local now = GetTime()

	if cache.guid ~= guid or now - cache.time >= MOUNT_TTL then
		cache.guid, cache.time, cache.text = guid, now, self:FindMount(unit)
	end

	if cache.text then
		AddLine(tooltip, MOUNT, cache.text, Format.VALUE)
	end
end

---Edits Blizzard's lines and adds AeonUI's, after Blizzard's own unit rules have run and before the tooltip sizes
---itself.
---@param tooltip GameTooltip
---@param data table the tooltip's data, its lines carrying the `lineIndex` each was drawn at
function Units:OnTooltip(tooltip, data)
	if tooltip ~= GameTooltip or tooltip:IsForbidden() or not AUI.Tooltip:IsEnabled() or not data.lines then
		return
	end

	local guid = AUI:Readable(data.guid)

	if type(guid) ~= "string" then
		return
	end

	local LineType = Enum.TooltipDataLineType
	local unit = Token(guid)
	local _, classFile = GetPlayerInfoByGUID(guid)

	classFile = AUI:Readable(classFile)

	local player = classFile ~= nil
	local pet = unit ~= nil and AUI:Readable(UnitIsBattlePet(unit)) == true
	local muted = Options:Get(Options.MUTED_LINES_PATH) == true
	local levels = unit ~= nil and Options:Get(Options.LEVEL_COLOR_PATH) == true
	local nameColor = self:NameColor(unit, classFile, pet)
	local guild, rank, petName, nameLine

	if player and unit then
		guild, rank = GetGuildInfo(unit)
		guild, rank = AUI:Readable(guild), AUI:Readable(rank)
	end

	if pet and muted and unit then
		petName = AUI:Readable(UnitName(unit))
	end

	for _, line in ipairs(data.lines) do
		local left = line.lineIndex and _G["GameTooltipTextLeft" .. line.lineIndex] --[[@as FontString?]]
		local text = AUI:Readable(line.leftText)

		if left and type(text) == "string" then
			local kind = line.type

			if kind == LineType.UnitName and not nameLine then
				nameLine = left
				self:Name(left, text, guid, player, nameColor)
			elseif kind == LineType.UnitOwner then
				if muted then
					left:SetTextColor(Format.MUTED.r, Format.MUTED.g, Format.MUTED.b)
				end
			elseif kind == LineType.None and guild and text:find(guild, 1, true) then
				guild = nil
				self:Guild(left, text, unit --[[@as string]], rank)
			elseif kind == LineType.UnitLevel or (kind == LineType.None and self.levelPattern
				and text:find(self.levelPattern)) then
				if levels then
					levels = false
					self:Level(left, text, unit --[[@as string]], player)
				end
			elseif kind == LineType.None and muted and text == CORPSE then
				left:SetTextColor(Format.MUTED.r, Format.MUTED.g, Format.MUTED.b)
			elseif kind == LineType.None and petName and text == petName and nameColor then
				left:SetTextColor(nameColor.r, nameColor.g, nameColor.b)
			end
		end
	end

	if unit then
		if Options:Get(Options.TARGET_PATH) == true then
			self:AddTarget(tooltip, unit)
		end

		if player and AUI.can.mythicPlus and Options:Get(Options.RATING_PATH) == true then
			self:AddRating(tooltip, unit)
		end

		if player and Options:Get(Options.MOUNT_PATH) == true then
			self:AddMount(tooltip, guid, unit)
		end

		if player then
			AUI.TooltipInspect:AddLines(tooltip, guid, unit)
		end
	end

	if nameLine then
		self:ColorBar(nameLine)
	end
end

---Gives the health bar the name line's color, kept until the tooltip clears.
---@param nameLine FontString
function Units:ColorBar(nameLine)
	local bar = GameTooltipStatusBar
	local r, g, b = nameLine:GetTextColor()

	r, g, b = AUI:Readable(r), AUI:Readable(g), AUI:Readable(b)

	if not bar or not r or not g or not b then
		return
	end

	local color = self.barColor

	color.r, color.g, color.b = r, g, b
	self.barColored = true
	bar:SetStatusBarColor(r, g, b)
end

---@param tooltip GameTooltip
---@param text string
---@param color AUITooltipColor
local function AddText(tooltip, text, color)
	tooltip:AddLine(text, color.r, color.g, color.b)
end

---@param text string the level line as Blizzard draws it
---@param level number
---@param color AUITooltipColor? the level's color; nil while levels are not colored
---@param mark string?
---@return string
local function SampleLevel(text, level, color, mark)
	return color and Format:Level(text, level, color, mark) or text
end

---Fills the Units preview's three sample tooltips with every line the settings choose, drawn as on a real tooltip: a
---player (the character's own name, class, race, level, item level and specialization, with a made-up title, guild,
---rating and mount), an elite creature targeting the player, and the player's pet.
---@param player GameTooltip
---@param creature GameTooltip
---@param pet GameTooltip
function Units:Sample(player, creature, pet)
	local white = HIGHLIGHT_FONT_COLOR
	local name = AUI:Readable(UnitName("player"))
	local className, classFile = UnitClass("player")
	local race = AUI:Readable(UnitRace("player"))
	local level = AUI:Readable(UnitLevel("player"))
	local levels = Options:Get(Options.LEVEL_COLOR_PATH) == true
	-- Both are client strings no Lua file of the Forever client names, so a missing one leaves the bare value.
	local levelText, ownerText = TOOLTIP_UNIT_LEVEL or "%s", UNITNAME_TITLE_PET or "%s"

	name = type(name) == "string" and name or UNKNOWN
	level = type(level) == "number" and level or 1

	player:ClearLines()
	AddText(player, Options:Get(Options.TITLES_PATH) == true and L["%s the Patient"]:format(name) or name,
		ClassColor(AUI:Readable(classFile)) or white)
	AddText(player, Format:Guild(SAMPLE.guild, Options:Get(Options.GUILD_RANK_PATH) == true and OFFICER or nil),
		Format.GUILD)
	AddText(player, SampleLevel(levelText:format(level) .. " " .. (race or "") .. " "
		.. (AUI:Readable(className) or ""), level, levels and Format.FRIENDLY_LEVEL or nil), white)

	if AUI.can.mythicPlus and Options:Get(Options.RATING_PATH) == true then
		AddLine(player, DUNGEON_SCORE, tostring(SAMPLE.rating),
			C_ChallengeMode.GetDungeonScoreRarityColor(SAMPLE.rating) or Format.VALUE)
	end

	if Options:Get(Options.MOUNT_PATH) == true then
		local mount = AUI:Readable(C_MountJournal.GetMountInfoByID(SAMPLE.mount))

		if type(mount) == "string" and mount ~= "" then
			AddLine(player, MOUNT, mount .. " " .. CreateAtlasMarkup("common-icon-checkmark", ICON_SIZE, ICON_SIZE),
				Format.VALUE)
		end
	end

	local Inspect = AUI.TooltipInspect
	local itemLevel, specID = Inspect:Own()

	Inspect:AddValues(player, Options:Get(Options.ITEM_LEVEL_PATH) == true,
		AUI.can.specializations == true and Options:Get(Options.SPECIALIZATION_PATH) == true, itemLevel, specID)

	local creatureLevel = level + SAMPLE.creatureLevels

	creature:ClearLines()
	AddText(creature, L["Gnoll Brute"], FACTION_BAR_COLORS[2])
	AddText(creature, SampleLevel(levelText:format(creatureLevel) .. " (" .. ELITE .. ")", creatureLevel,
		levels and GetCreatureDifficultyColor(creatureLevel) or nil, Format:Mark("elite", L["Rare"], BOSS)), white)

	if Options:Get(Options.TARGET_PATH) == true then
		AddLine(creature, TARGET, YOU, Format.YOU)
	end

	pet:ClearLines()
	AddText(pet, L["Wolf"], GREEN_FONT_COLOR)
	AddText(pet, ownerText:format(name), Options:Get(Options.MUTED_LINES_PATH) == true and Format.MUTED
		or white)
	AddText(pet, SampleLevel(levelText:format(level), level,
		levels and GetCreatureDifficultyColor(level) or nil), white)
end

---Writes the aura caster names setting to its CVar while the module is on; the module off leaves the CVar as it is.
---@param on boolean the module is on
function Units:Apply(on)
	if not on then
		self.barColored = false
	end

	if not on or not AUI.can.auraCasterNames then
		return
	end

	local value = Options:Get(Options.AURA_CASTERS_PATH) == true and "1" or "0"

	if C_CVar.GetCVar(CASTER_NAMES_CVAR) ~= value then
		C_CVar.SetCVar(CASTER_NAMES_CVAR, value)
	end
end

---Installs the unit post-call and the health bar's recolor once; they do nothing while the module is off.
function Units:Hook()
	if self.hooked or not TooltipDataProcessor or not GameTooltip then
		return
	end

	self.hooked = true
	self.levelPattern = TOOLTIP_UNIT_LEVEL and Format:LevelPattern(TOOLTIP_UNIT_LEVEL) or nil

	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
		Units:OnTooltip(tooltip, data)
	end)
	GameTooltip:HookScript("OnTooltipCleared", function()
		Units.barColored = false
	end)

	local bar = GameTooltipStatusBar

	-- Blizzard's own handler turns the bar green on every change; this runs after it.
	if bar then
		bar:HookScript("OnValueChanged", function(changedBar)
			if Units.barColored then
				local color = Units.barColor

				changedBar:SetStatusBarColor(color.r, color.g, color.b)
			end
		end)
	end
end
