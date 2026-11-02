local AUI = select(2, ...)

local Options = AUI.ScreenTextOptions

---The Screen Text module: the font, size and outline of the error and objective lines and of the zone, subzone and
---territory lines Blizzard shows on screen. Each line's size is a percentage of its font object's size, read each time
---it is applied. Blizzard's colors are kept. Nothing is changed while the module is off, and turning it off gives each
---line its font object back and the message frame its size.
---@class AUIScreenText
---@field active boolean started this session
---@field changed boolean the lines hold AeonUI's fonts
---@field frameSize { width: number, height: number }? the message frame's size before AeonUI changed it
local ScreenText = {
	active = false,
	changed = false,
}
AUI.ScreenText = ScreenText

-- Each line's regions and the font object Blizzard gives them.
local TARGETS = {
	messages = { regions = { "UIErrorsFrame" }, font = "ErrorFont" },
	zone = { regions = { "ZoneTextString" }, font = "ZoneTextFont" },
	subZone = { regions = { "SubZoneTextString" }, font = "SubZoneTextFont" },
	pvp = { regions = { "PVPInfoTextString", "PVPArenaTextString" }, font = "PVPInfoTextFont" },
}

---@param line string one of `Options.LINES`
---@return number size the size Blizzard gives the line
function ScreenText:BaseSize(line)
	local font = _G[TARGETS[line].font] --[[@as Font?]]

	if not font then
		return 16
	end

	local _, size = font:GetFont()

	return size or 16
end

---Gives a font string or the message frame a line's font, size and outline.
---@param region FontString|MessageFrame
---@param line string one of `Options.LINES`
function ScreenText:Style(region, line)
	local Profile, Media = AUI.Profile, AUI.Media

	region:SetFont(Media:Font(Profile:Get(Options:Path(line, "font"))),
		Options:FontSize(self:BaseSize(line), Profile:Get(Options:Path(line, "size"))),
		Media:FontFlags(Profile:Get(Options:Path(line, "outline"))))
end

---Grows the message frame with its font so larger text is not clipped, or gives Blizzard's size back.
---@param scale number? the messages' size setting; nil restores Blizzard's size
function ScreenText:SizeFrame(scale)
	local frame = UIErrorsFrame

	if not self.frameSize then
		local width, height = frame:GetSize()

		self.frameSize = { width = width, height = height }
	end

	local saved = self.frameSize

	if scale then
		frame:SetSize(Options:FrameSize(saved.width, saved.height, scale))
	else
		frame:SetSize(saved.width, saved.height)
	end
end

function ScreenText:Apply()
	local on = AUI.can.screenText == true and AUI.Profile:Get(Options.ENABLED_PATH) == true

	if not on and not self.changed then
		return
	end

	for line, target in pairs(TARGETS) do
		local font = _G[target.font] --[[@as Font]]

		for _, name in ipairs(target.regions) do
			local region = _G[name]

			if on then
				self:Style(region, line)
			else
				region:SetFontObject(font)
			end
		end
	end

	self:SizeFrame(on and AUI.Profile:Get(Options:Path("messages", "size")) or nil)
	self.changed = on
end

---@param path string? the changed setting; nil when the whole profile changed
function ScreenText:OnProfileChanged(path)
	if path == nil or path:sub(1, 11) == "screenText." then
		AUI.Events:Coalesce("screenTextApply", function()
			ScreenText:Apply()
		end)
	end
end

function ScreenText:Start()
	if self.active then
		return
	end

	self.active = true
	AUI.Callbacks:Register("Profile", self, self.OnProfileChanged)
	self:Apply()
end
