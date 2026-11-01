local AUI = select(2, ...)

local Schema = AUI.Schema

---The player cast bar's profile settings, its look and its frame-free rules: which duration a cast is drawn from, the
---direction its fill runs, and when the bar shows.
---@class AUICastBarOptions
---@field ENABLED_PATH string the page's switch
---@field POSITION_PATH string the bar's place, set in edit mode
---@field DEFAULT_POSITION { point: string, x: number, y: number }
---@field WIDTH number
---@field HEIGHT number
---@field FILL AUIColor the fill's left color
---@field FILL_END AUIColor the fill's right color
---@field BACKGROUND AUIColor
---@field BORDER AUIColor
---@field LOCKED AUIColor the fill while the cast cannot be interrupted
---@field SPARK_TEXTURE string
---@field SPARK_WIDTH number
---@field SPARK_HEIGHT number
---@field FONT string a LibSharedMedia font name
---@field FONT_SIZE number
---@field SHADOW AUIColor
---@field SAMPLE_PROGRESS number how far the edit-mode sample is filled, 0 to 1
local Options = {
	ENABLED_PATH = "castBar.enabled",
	POSITION_PATH = "castBar.position",
	DEFAULT_POSITION = { point = "CENTER", x = 0, y = -254 },
	WIDTH = 386,
	HEIGHT = 16,
	FILL = { r = 1, g = 0.71, b = 0.19 },
	FILL_END = { r = 1, g = 0.682, b = 0.224 },
	BACKGROUND = { r = 1, g = 1, b = 1, a = 0.5 },
	BORDER = { r = 0, g = 0, b = 0, a = 1 },
	LOCKED = { r = 0.8, g = 0.1, b = 0.1 },
	SPARK_TEXTURE = "Interface\\CastingBar\\UI-CastingBar-Spark",
	SPARK_WIDTH = 10,
	SPARK_HEIGHT = 30,
	FONT = "Expressway",
	FONT_SIZE = 14,
	SHADOW = { r = 0, g = 0, b = 0, a = 1 },
	SAMPLE_PROGRESS = 0.6,
}
AUI.CastBarOptions = Options

Schema:Boolean(Options.ENABLED_PATH, false)
Schema:Position(Options.POSITION_PATH)

---The kinds of cast the bar draws, each with the duration it is drawn from and the way its fill runs: casts and
---empowered casts fill as they run; channels start full and drain.
---@enum AUICastKind
Options.KINDS = {
	CAST = "CAST",
	EMPOWERED = "EMPOWERED",
	CHANNEL = "CHANNEL",
}

---@param kind AUICastKind
---@return boolean drains the fill shows the remaining time rather than the elapsed time
function Options:Drains(kind)
	return kind == self.KINDS.CHANNEL
end

---Which kind of cast `UnitCastingInfo` and `UnitChannelInfo` describe.
---@param casting boolean `UnitCastingInfo` returned a cast
---@param channeling boolean `UnitChannelInfo` returned a channel
---@param empowered boolean the channel is empowered (its `isEmpowered`, never secret)
---@return AUICastKind? kind nil when the player is not casting
function Options:Kind(casting, channeling, empowered)
	if casting then
		return self.KINDS.CAST
	elseif channeling then
		return empowered and self.KINDS.EMPOWERED or self.KINDS.CHANNEL
	end
end

---@param on boolean the page's switch is on
---@param casting boolean a cast is drawn
---@param sampling boolean edit mode shows the sample
---@param petBattle boolean a pet battle is in progress
---@return boolean shown
function Options:Visible(on, casting, sampling, petBattle)
	if not on then
		return false
	end

	return sampling or (casting and not petBattle)
end
