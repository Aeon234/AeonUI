local AUI = select(2, ...)

-- The slider's range and step, in percent; 100 is Blizzard's size.
local MIN_PERCENT, MAX_PERCENT, STEP = 50, 150, 5

---Scales Blizzard's game menu (Escape), AeonUI's button in it included. Blizzard never rescales the menu itself, so
---the scale is set at login and when the value changes. The value is account-wide, in `global.gameMenuScale`
---(percent; absent means 100).
---@class AUIGameMenuScale
local GameMenuScale = {
	DEFAULT = 100,
	MIN_PERCENT = MIN_PERCENT,
	MAX_PERCENT = MAX_PERCENT,
	STEP = STEP,
}
AUI.GameMenuScale = GameMenuScale

---@param value any
---@return number percent within the slider's range; the default when `value` is not a number
function GameMenuScale.Clamp(value)
	if type(value) ~= "number" or value ~= value then
		return GameMenuScale.DEFAULT
	end

	return math.min(math.max(value, MIN_PERCENT), MAX_PERCENT)
end

---@return number percent
function GameMenuScale:Get()
	local global = AUI.Profile:Global()

	return self.Clamp(global and global.gameMenuScale)
end

---@param percent number
function GameMenuScale:Set(percent)
	local global = AUI.Profile:Global()

	if not global then
		return
	end

	global.gameMenuScale = self.Clamp(percent)
	self:Apply()
end

function GameMenuScale:Apply()
	if GameMenuFrame then
		GameMenuFrame:SetScale(self:Get() / 100)
	end
end

---Sets the saved scale at login; Blizzard's size is left untouched.
function GameMenuScale:Start()
	if self:Get() ~= self.DEFAULT then
		self:Apply()
	end
end
