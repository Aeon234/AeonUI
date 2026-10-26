local AUI = select(2, ...)

local Options, Format = AUI.TooltipOptions, AUI.TooltipFormat
local L = AUI.L

---Rewrites an item tooltip's "Upgrade Level" line: the rank in its track's color, the track's item-level range, and
---on the right the crest the next upgrade costs, with a hint when the item is below the character's or account's high
---watermark and so upgrades at a discount. Tracks come from `AUI.TooltipUpgradeSeasons`; without data for the item's
---track the rank still takes the item's quality color. The post-call is installed once, where the client has upgrade
---tracks, and does nothing while the module is off.
---@class AUITooltipUpgrades
---@field hooked boolean
---@field season AUIUpgradeTrack[]? the running season's tracks
---@field capture string? the pattern capturing the label, track, rank and ranks from the upgrade line
local Upgrades = {
	hooked = false,
}
AUI.TooltipUpgrades = Upgrades

---@param seasons table<integer, AUIUpgradeTrack[]>
---@param version integer the client's interface version
---@return AUIUpgradeTrack[]? tracks the season with the largest key not above the version
function Upgrades.SeasonFor(seasons, version)
	local best

	for key in pairs(seasons) do
		if key <= version and (not best or key > best) then
			best = key
		end
	end

	return best and seasons[best] or nil
end

---Finds the track an item is on from its item level and rank. Tracks overlap in item level and their ranks are not
---evenly spaced, so the track whose expected item level for the rank is closest, within one rank's step, wins.
---@param tracks AUIUpgradeTrack[]
---@param itemLevel number
---@param rank integer
---@param ranks integer
---@return AUIUpgradeTrack?
function Upgrades.FindTrack(tracks, itemLevel, rank, ranks)
	local best, bestDistance

	for _, track in ipairs(tracks) do
		if track.ranks == ranks and itemLevel >= track.minLevel and itemLevel <= track.maxLevel then
			local step = (track.maxLevel - track.minLevel) / (track.ranks - 1)
			local distance = math.abs(itemLevel - (track.minLevel + (rank - 1) * step))

			if distance <= step and (not bestDistance or distance < bestDistance) then
				best, bestDistance = track, distance
			end
		end
	end

	return best
end

---@param format string `ITEM_UPGRADE_TOOLTIP_FORMAT_STRING`, such as "Upgrade Level: %s %d/%d"
---@return string pattern capturing the label, the track, the rank and the ranks
function Upgrades.CapturePattern(format)
	local prefix = format:match("^(.-)%%s") or ""
	local escaped = prefix:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")

	return "^(" .. escaped .. ")(.-) (%d+)/(%d+)$"
end

---@param quality integer
---@param text string
---@return string
local function InQuality(quality, text)
	local r, g, b = C_Item.GetItemQualityColor(quality)

	return Format:Wrap(text, { r = r, g = g, b = b })
end

---@param track string the track's name, as the tooltip gives it
---@param data AUIUpgradeTrack
---@return string text the crest's icon and name in the track's color
function Upgrades:Crest(track, data)
	local info = data.crest and C_CurrencyInfo.GetCurrencyInfo(data.crest)
	local name = info and AUI:Readable(info.name)
	local icon = info and AUI:Readable(info.iconFileID)

	if type(name) ~= "string" or name == "" then
		return InQuality(data.quality, L["%s Crest"]:format(track))
	end

	return (type(icon) == "number" and ("|T%d:0|t "):format(icon) or "") .. InQuality(data.quality, name)
end

---@class AUIUpgradeParts
---@field label string the line's text before the track, such as "Upgrade Level: "
---@field track string
---@field rank integer
---@field ranks integer
---@field itemLevel number
---@field quality integer the item's quality
---@field watermark number the higher of the character's and account's high watermarks for the item's slot
---@field data AUIUpgradeTrack? the item's track in the season data

---Builds the rewritten left text and the crest text for one upgrade line.
---@param parts AUIUpgradeParts
---@return string left
---@return string? right the crest, when shown
function Upgrades:Texts(parts)
	local Profile = AUI.Profile
	local data = parts.data
	local rank = ("%s %d/%d"):format(parts.track, parts.rank, parts.ranks)
	local left = parts.label .. (Profile:Get(Options.UPGRADE_RANK_PATH) == true
		and InQuality(data and data.quality or parts.quality, rank) or rank)

	if data and Profile:Get(Options.UPGRADE_RANGE_PATH) == true then
		left = left .. " " .. Format:Wrap(("(%d-%d)"):format(data.minLevel, data.maxLevel),
			Profile:Get(Options.UPGRADE_RANGE_COLOR_PATH))
	end

	if not data or Profile:Get(Options.UPGRADE_CREST_PATH) ~= true or parts.rank >= parts.ranks then
		return left, nil
	end

	local right = self:Crest(parts.track, data)

	if parts.itemLevel < parts.watermark then
		right = right .. " " .. L["(discounted)"]
	end

	return left, right
end

---@param data table an item tooltip's data
---@return string? link
local function ItemLink(data)
	local guid = AUI:Readable(data.guid)

	if guid then
		return AUI:Readable(C_Item.GetItemLinkByGUID(guid))
	end

	return AUI:Readable(data.hyperlink)
end

---@param tooltip GameTooltip
---@param data table? the tooltip's data
function Upgrades:OnTooltip(tooltip, data)
	if not self.capture or not data or not data.lines or tooltip:IsForbidden() or not AUI.Tooltip:IsEnabled() then
		return
	end

	local name = tooltip:GetName()
	local link = name and ItemLink(data)

	if not link then
		return
	end

	for _, line in ipairs(data.lines) do
		if line.type == Enum.TooltipDataLineType.ItemUpgradeLevel then
			local left = line.lineIndex and _G[name .. "TextLeft" .. line.lineIndex] --[[@as FontString?]]
			local text = AUI:Readable(line.leftText)
			local label, track, rank, ranks

			if type(text) == "string" then
				label, track, rank, ranks = text:match(self.capture)
			end

			rank, ranks = tonumber(rank), tonumber(ranks)

			local itemLevel = C_Item.GetDetailedItemLevelInfo(link)

			if not left or not label or not track or not rank or not ranks or type(itemLevel) ~= "number" then
				return
			end

			local _, _, quality = C_Item.GetItemInfo(link)
			local character, account = C_ItemUpgrade.GetHighWatermarkForItem(link)
			local newLeft, newRight = self:Texts({
				label = label,
				track = track,
				rank = rank,
				ranks = ranks,
				itemLevel = itemLevel,
				quality = quality or 1,
				watermark = math.max(character or 0, account or 0),
				data = self.season and self.FindTrack(self.season, itemLevel, rank, ranks) or nil,
			})

			left:SetText(newLeft)

			local right = _G[name .. "TextRight" .. line.lineIndex] --[[@as FontString?]]

			if newRight and right then
				right:SetText(newRight)
				right:Show()
			end

			return
		end
	end
end

---Installs the item post-call once, where the client has upgrade tracks.
function Upgrades:Hook()
	if self.hooked or not AUI.can.upgrades or not TooltipDataProcessor then
		return
	end

	self.hooked = true
	self.capture = self.CapturePattern(ITEM_UPGRADE_TOOLTIP_FORMAT_STRING)
	self.season = self.SeasonFor(AUI.TooltipUpgradeSeasons, select(4, GetBuildInfo()) or 0)

	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
		Upgrades:OnTooltip(tooltip, data)
	end)
end
