local AUI = select(2, ...)

local Schema = AUI.Schema

-- Classic health colors: red when empty, yellow at half, green when full.
local CLASSIC = {
	{ 0, { r = 1, g = 0, b = 0 } },
	{ 0.5, { r = 1, g = 1, b = 0 } },
	{ 1, { r = 0, g = 1, b = 0 } },
}

-- Reaction levels each reaction color covers.
local REACTIONS = {
	[1] = "hostile", [2] = "hostile", [3] = "hostile",
	[4] = "neutral",
	[5] = "friendly", [6] = "friendly", [7] = "friendly", [8] = "friendly",
}

---What decides a unit's base health color.
---@class AUIHealthState
---@field connected boolean
---@field tapDenied boolean the unit is not player controlled and is tapped by someone else
---@field classColor table? the class color of a player unit, possibly holding secret channels
---@field reaction integer? the unit's reaction to the player

---Health bar colors: fill by mode, gradient, background and the dark treatment, in a fixed precedence. The dark
---treatment comes first, then a mode that follows health, then the custom color, then the base color: disconnected,
---tapped, class, reaction. Health-following modes are evaluated by the client through color curves, so health values
---never reach Lua; the settings previews evaluate the same points in Lua at their sample health.
---@class AUIHealthColor
local HealthColor = {}
AUI.HealthColor = HealthColor

---@param config table
---@param key string
---@return table? settings the frame's health colors, with the Globals-only state colors, or nil without them
function HealthColor:Resolve(config, key)
	local base = "frames." .. key .. ".health."

	if not Schema:Field(base .. "mode") then
		return nil
	end

	local settings = { stops = {}, reaction = {} }

	for _, name in ipairs(Schema.HEALTH_LOOK) do
		local group, field = name:match("^(%a+)%.(%a+)$")
		local value = Schema:Read(config, base .. name)

		if group then
			settings[group][field] = value
		else
			settings[name] = value
		end
	end

	for _, name in ipairs({ "tapped", "tappedColor", "disconnected", "disconnectedColor" }) do
		settings[name] = Schema:Read(config, "health." .. name)
	end

	for _, name in ipairs({ "hostile", "neutral", "friendly" }) do
		settings.reaction[name] = Schema:Read(config, "health.reaction." .. name)
	end

	settings.barBackground = Schema:Read(config, "frames." .. key .. ".bars.background")

	return settings
end

---@param settings table from `Resolve`
---@param full table? the full-health color for Class Fade: a readable base color
---@return table[]? points `{ position, color }` pairs from empty to full, or nil when the fill does not follow health
function HealthColor:Points(settings, full)
	local mode, stops = settings.mode, settings.stops

	if mode == "classic" then
		return CLASSIC
	end

	if mode == "stops" then
		return { { 0, stops.empty }, { 0.5, stops.half }, { 1, stops.full } }
	end

	if mode == "classFade" and full then
		local half = stops.half

		-- Fully the half color at 40% health; three quarters of the way back to the full color at 75%.
		return {
			{ 0, stops.empty },
			{ 0.4, half },
			{ 0.75, {
				r = half.r + (full.r - half.r) * 0.75,
				g = half.g + (full.g - half.g) * 0.75,
				b = half.b + (full.b - half.b) * 0.75,
			} },
			{ 1, full },
		}
	end
end

---Interpolates points linearly, for the previews.
---@param points table[]
---@param fraction number 0 to 1
---@return table color
function HealthColor:Evaluate(points, fraction)
	fraction = math.max(0, math.min(1, fraction))

	for index = 2, #points do
		local position, color = points[index][1], points[index][2]

		if fraction <= position then
			local previous, start = points[index - 1][1], points[index - 1][2]
			local t = (fraction - previous) / (position - previous)

			return {
				r = start.r + (color.r - start.r) * t,
				g = start.g + (color.g - start.g) * t,
				b = start.b + (color.b - start.b) * t,
			}
		end
	end

	return points[#points][2]
end

---@param settings table
---@param reaction integer?
---@return table? color the reaction color: the configured one, else Blizzard's
function HealthColor:ReactionColor(settings, reaction)
	local name = reaction and REACTIONS[reaction]

	return (name and settings.reaction[name]) or (reaction and AUI.oUF.colors.reaction[reaction]) or nil
end

---@param settings table
---@param state AUIHealthState
---@return table color the base color: disconnected, tapped, class, reaction, then the health default
function HealthColor:Base(settings, state)
	if settings.disconnected and not state.connected then
		return settings.disconnectedColor
	end

	if settings.tapped and state.tapDenied then
		return settings.tappedColor
	end

	return state.classColor or self:ReactionColor(settings, state.reaction) or AUI.oUF.colors.health
end

---The fill and background colors for a sample, in Lua; live frames reach the same result in `UpdateColor`.
---@param settings table
---@param state AUIHealthState
---@param fraction number the sample's health, 0 to 1
---@param dead boolean?
---@return table fill
---@return table background
function HealthColor:Sample(settings, state, fraction, dead)
	local base = self:Base(settings, state)
	local fill = base

	if settings.dark then
		fill = settings.darkFill
	else
		local points = self:Points(settings, base)

		if points then
			fill = self:Evaluate(points, fraction)
		elseif settings.mode == "custom" then
			fill = settings.color
		end
	end

	return fill, self:Background(settings, base, dead)
end

---@param settings table
---@return number alpha the fill's opacity
function HealthColor:Alpha(settings)
	if settings.dark then
		return settings.darkFill.a or 1
	end

	return settings.fillAlpha / 100
end

---@param settings table
---@param base table the base color, possibly holding secret channels
---@param dead boolean?
---@return table color the background color; its `a` is a plain number
function HealthColor:Background(settings, base, dead)
	if settings.deadBackground and dead then
		return settings.deadColor
	end

	if settings.dark then
		return settings.darkBackground
	end

	local custom = settings.barBackground

	if settings.background == "classReaction" then
		return { r = base.r, g = base.g, b = base.b, a = custom.a or 1 }
	end

	return custom
end

---Paints a health bar: the fill, as a gradient when it is on and the fill color is readable, its opacity, and the
---background. Used by the live frames and the previews alike.
---@param bar StatusBar
---@param background Texture a white texture, tinted here
---@param settings table
---@param fill table the fill color, possibly holding secret channels
---@param backdrop table the background color
function HealthColor:Paint(bar, background, settings, fill, backdrop)
	local texture = bar:GetStatusBarTexture()

	if settings.gradient and not settings.dark and not issecretvalue(fill.r) then
		local finish = settings.gradientColor

		texture:SetGradient(settings.gradientDirection, CreateColor(fill.r, fill.g, fill.b, 1),
			CreateColor(finish.r, finish.g, finish.b, finish.a or 1))
	else
		bar:SetStatusBarColor(fill.r, fill.g, fill.b)
	end

	texture:SetAlpha(self:Alpha(settings))
	background:SetVertexColor(backdrop.r, backdrop.g, backdrop.b, backdrop.a or 1)
end

-- Live frames ---------------------------------------------------------------------------------------------------

---@param points table[]
---@return table curve a client color curve through the points
local function Curve(points)
	local curve = C_CurveUtil.CreateColorCurve()

	curve:SetType(Enum.LuaCurveType.Linear)

	for _, point in ipairs(points) do
		local color = point[2]

		curve:AddPoint(point[1], CreateColor(color.r, color.g, color.b, 1))
	end

	return curve
end

---@param unit string
---@return AUIHealthState state
function HealthColor:State(unit)
	local state = {
		connected = UnitIsConnected(unit),
		tapDenied = not UnitPlayerControlled(unit) and UnitIsTapDenied(unit),
		reaction = UnitReaction(unit, "player"),
	}

	if UnitIsPlayer(unit) or UnitInPartyIsAI(unit) then
		local _, class = UnitClass(unit)

		if issecretvalue(class) then
			state.classColor = C_ClassColor.GetClassColor(class)
		elseif class then
			state.classColor = AUI.oUF.colors.class[class]
		end
	end

	return state
end

---Takes a frame's resolved health colors and builds its curves. Run when the settings change.
---@param frame table an AeonUI unit frame with health
---@param settings table from `Resolve`
function HealthColor:Apply(frame, settings)
	local points = settings.mode ~= "classFade" and self:Points(settings)

	frame.healthColors = settings
	frame.healthCurve = points and Curve(points) or nil
	frame.fadeCurves = {}
end

---@param frame table
---@param settings table
---@param base table
---@return table? curve the curve the fill follows, or nil for a flat fill
function HealthColor:CurveFor(frame, settings, base)
	if settings.mode ~= "classFade" then
		return frame.healthCurve
	end

	-- Class Fade needs a readable full-health color.
	if issecretvalue(base.r) then
		return nil
	end

	local key = ("%.3f,%.3f,%.3f"):format(base.r, base.g, base.b)
	local curve = frame.fadeCurves[key]

	if not curve then
		curve = Curve(self:Points(settings, base) --[[@as table[] ]])
		frame.fadeCurves[key] = curve
	end

	return curve
end

---oUF's `Health.UpdateColor` override: paints the fill, its gradient and opacity, and the background.
---@param frame table the oUF frame
---@param _ string? the event
---@param unit string?
function HealthColor.UpdateColor(frame, _, unit)
	local settings = frame.healthColors

	if not unit or frame.__unit ~= unit or not settings then
		return
	end

	local element = frame.Health
	local base = HealthColor:Base(settings, HealthColor:State(unit))
	local fill = base

	if settings.dark then
		fill = settings.darkFill
	else
		local curve = HealthColor:CurveFor(frame, settings, base)

		if curve then
			fill = element.values:EvaluateCurrentHealthPercent(curve)
		elseif settings.mode == "custom" then
			fill = settings.color
		end
	end

	local dead = AUI:Readable(UnitIsDeadOrGhost(unit), false)

	HealthColor:Paint(element, frame.Background, settings, fill, HealthColor:Background(settings, base, dead))
end
