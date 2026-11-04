local AUI = select(2, ...)

local Schema = AUI.Schema
local Options = AUI.UnitFrameOptions
local CastOptions = AUI.CastBarOptions
local CastBar = AUI.CastBar

-- The bar's look, which follows All Frames' Cast Bars until changed.
local SHARED = {
	"texture", "color", "classColor", "gradient", "gradientColor", "gradientDirection", "background", "notInterruptible",
	"spark", "reverse", "smooth", "font", "outline", "shadow", "name.enabled", "name.size", "name.color", "name.x",
	"name.y", "name.maxLength", "time.enabled", "time.size", "time.color", "time.x", "time.y", "time.format", "feedback",
	"interrupted", "holdTime", "fade",
}
-- The bar's border, which follows its frame's until changed.
local BORDER = { "borderStyle", "borderThickness", "borderColor", "lineColor", "showShadow", "shadowSize", "shadowColor" }

---A unit frame's cast bar: `AUI.CastBar`'s view, driven by oUF's Castbar element on the view's status bar. oUF shows and
---hides that bar, so the bar's own `Show` and `Hide` also show and hide the view, and turn a hide into Fade Out or Always
---Show's empty bar. Its update script stops while it stays shown that way, so no Lua runs between casts.
---@class AUIUnitCastBar
local UnitCastBar = {}
AUI.UnitCastBar = UnitCastBar

---@param key string
---@return string base the start of the bar's settings' paths
function UnitCastBar:Base(key)
	return Options:Path(key, "castBar.")
end

---@param spec AUIFrameSpec?
---@return boolean has the frame has a cast bar, where the client can draw it
function UnitCastBar:Has(spec)
	return spec ~= nil and spec.castBar ~= nil and AUI.can.castBar == true
end

---@param spec AUIFrameSpec
---@return table owner what `AUI.CastBar:Build` needs for this frame's bar
function UnitCastBar:Owner(spec)
	return { base = self:Base(spec.key), key = spec.key, unit = spec.unit }
end

---@param spec AUIFrameSpec
local function Declare(spec)
	local base = UnitCastBar:Base(spec.key)
	local defaults = spec.castBar --[[@as table]]

	Schema:Boolean(base .. "enabled", false)
	Schema:Boolean(base .. "matchWidth", true)
	Schema:Number(base .. "width", 270, CastOptions.MIN_WIDTH, CastOptions.MAX_WIDTH, true)
	Schema:Number(base .. "height", 16, CastOptions.MIN_HEIGHT, CastOptions.MAX_HEIGHT, true)
	Schema:Boolean(base .. "icon", defaults.icon == true)
	Schema:Choice(base .. "iconSide", "castBarSide", "LEFT")
	Schema:Number(base .. "x", 0, -CastOptions.MAX_OFFSET, CastOptions.MAX_OFFSET, true)
	Schema:Number(base .. "y", defaults.y, -CastOptions.MAX_OFFSET, CastOptions.MAX_OFFSET, true)
	Schema:Choice(base .. "strata", "castBarStrata", "MEDIUM")
	Schema:Boolean(base .. "alwaysShow", false)

	for _, field in ipairs(SHARED) do
		Schema:Inherit(base .. field, Options.ALL .. "castBars." .. field)
	end

	for _, field in ipairs(BORDER) do
		Schema:Inherit(base .. "bars." .. field, Options:Path(spec.key, "bars." .. field))
	end
end

for _, spec in ipairs(Options.FRAMES) do
	if spec.castBar then
		Declare(spec)
	end
end

---@param key string
---@return number extent how far below the frame an attached bar reaches, 0 when it has none or it is off or above
function UnitCastBar:Extent(key)
	if not self:Has(Options:Spec(key)) or AUI.Profile:Get(self:Base(key) .. "enabled") ~= true then
		return 0
	end

	local y = AUI.Profile:Get(self:Base(key) .. "y")

	return y < 0 and CastBar:DrawnHeight(self:Base(key), key) - y or 0
end

---Holds the view's update script while the bar stays shown between casts.
---@param view AUICastBarFrame
---@param bar table
local function Pause(view, bar)
	view.update = bar:GetScript("OnUpdate") or view.update
	bar:SetScript("OnUpdate", nil)
end

---Ends a fade or the feedback's colors, ready for a cast or to hide.
---@param view AUICastBarFrame
local function Reset(view)
	local fade = view.fade --[[@as AnimationGroup]]

	if view.fading then
		view.fading = false
		fade:Stop()
	end

	view:SetAlpha(1)
	view.failed:SetAlpha(0)
end

---Shows the feedback's color over the full bar, the time hidden, for what oUF holds.
---@param view AUICastBarFrame
local function ShowFeedback(view)
	if AUI.Profile:Get(view.base .. "feedback") == true then
		view.binding:SetEnabled(false)
		view.time:Hide()
		view.locked:SetAlpha(0)
		view.failed:SetAlpha(1)
	end
end

---Builds a frame's bar and gives it to oUF.
---@param frame table the oUF frame
---@return AUICastBarFrame view
function UnitCastBar:Attach(frame)
	local view = CastBar:Build(frame.Content, nil, self:Owner(frame.spec))
	local bar = view.bar --[[@as table]]
	local show, hide = bar.Show, bar.Hide

	view:EnableMouse(false)
	view.time.binding = view.binding
	bar.Text, bar.Time, bar.Icon, bar.Spark, bar.Shield = view.text, view.time, view.icon, view.spark, view.locked

	view.fade = CastBar:CreateFade(view, function()
		Reset(view)
		hide(bar)
		bar:SetScript("OnUpdate", view.update)
		view:Hide()
	end)

	function bar.Show(element)
		Reset(view)
		bar:SetScript("OnUpdate", view.update or bar:GetScript("OnUpdate"))
		view:Show()
		show(element)
	end

	function bar.Hide(element)
		local Profile = AUI.Profile

		if view.fading then
			return
		end

		if Profile:Get(view.base .. "enabled") == true and Profile:Get(view.base .. "alwaysShow") == true then
			Pause(view, bar)
			Reset(view)
			CastBar:DrawEmpty(view)
			view:Show()
			show(element)
		elseif view:IsShown() and Profile:Get(view.base .. "enabled") == true and Profile:Get(view.base .. "fade") == true then
			Pause(view, bar)
			view.fading = true
			view.binding:SetEnabled(false)
			view.spark:Hide()
			view.fade:Play()
		else
			Reset(view)
			view.binding:SetEnabled(false)
			hide(element)
			view:Hide()
		end
	end

	function bar.PostCastStart(_, _, _, _, name)
		local Profile = AUI.Profile

		view.binding:SetEnabled(true)
		view.time:SetShown(Profile:Get(view.base .. "time.enabled") == true)
		view.spark:SetShown(Profile:Get(view.base .. "spark") == true)
		view.text:SetText(CastBar:SpellName(view, name))
		CastBar:StyleFill(view)
		-- The easing follows the cast from its own place, not from where the last cast left the bar.
		bar:SetToTargetValue()
	end

	function bar.PostCastFail()
		ShowFeedback(view)
	end

	function bar.PostCastInterrupted()
		ShowFeedback(view)
	end

	frame.Castbar = bar

	return view
end

---Gives the bar its settings and places it. Not protected, so this also runs in combat.
---@param frame table the oUF frame
function UnitCastBar:Apply(frame)
	local Profile = AUI.Profile
	local view = frame.CastBarView
	local bar = view.bar --[[@as table]]
	local base = view.base
	local on = Profile:Get(base .. "enabled") == true

	view:SetFrameStrata(Profile:Get(base .. "strata"))
	-- Fade Out draws the bar as one image. Switching that on as a fade starts makes other frames flicker, so it stays on
	-- with the setting.
	view:SetIsFrameBuffer(Profile:Get(base .. "fade") == true)
	CastBar:Style(view)
	view:ClearAllPoints()
	view:SetPoint("TOP", frame, "BOTTOM", Profile:Get(base .. "x"), Profile:Get(base .. "y"))
	bar.timeToHold = Profile:Get(base .. "feedback") == true and Profile:Get(base .. "holdTime") or 0
	bar.smoothing = Profile:Get(base .. "smooth") == true and Enum.StatusBarInterpolation.ExponentialEaseOut
		or Enum.StatusBarInterpolation.Immediate
	AUI.Indicators:SetElement(frame, "Castbar", on, bar)

	if on and bar.ForceUpdate and frame:IsVisible() then
		bar:ForceUpdate()
	end
end
