-- The S2 Loot Sparkles probe: prints what the approached-object glints read from the soft target, so each type can be
-- checked in game against what the player sees. Development only; never packaged.
local AUI = select(2, ...)

local SOFT = "softinteract"

---@class AUISparklesProbe
local Probe = {}
AUI.Dev.SparklesProbe = Probe

---@param value any
---@return string
local function Show(value)
	if issecretvalue(value) then
		return "<secret>"
	end

	return tostring(value)
end

---Prints the soft target, its cursor, its type and state, its plate, the gate, the held console variables and the
---rows that are on.
function Probe:Command()
	local Target, Options = AUI.SparkleTarget, AUI.HiddenSettingsOptions

	local guid = UnitGUID(SOFT)

	AUI:Print("sparkles: exists %s  object %s  name %s  guid %s  id %s", Show(UnitExists(SOFT)),
		Show(UnitIsGameObject(SOFT)), Show(UnitName(SOFT)), Show(guid), tostring(Options.ObjectID(AUI:Readable(guid))))

	local unit, plate = Target:Resolve()

	if unit then
		local cursor = Target:Cursor(unit)
		local probe = Target.probe --[[@as Texture]]

		AUI:Print("cursor %s  texture %s  atlas %s", tostring(cursor), Show(probe:GetTexture()), Show(probe:GetAtlas()))

		local kind, unable = Target:Classify(unit, true, AUI.HiddenSettings:Containers())
		local inRange = Target.InRange(unit)

		AUI:Print("type %s  unable %s  in range %s  state %s  plate %s", tostring(kind), tostring(unable),
			tostring(inRange), Options.State(inRange, unable), tostring(plate ~= nil))
	else
		AUI:Print("no readable soft target")
	end

	local holder = AUI.ApproachSparkles.holder

	for _, entry in ipairs(holder and holder.held or Options.SOFT_TARGET) do
		AUI:Print("  %s = %s (held %s)", entry.name, Show(C_CVar.GetCVar(entry.name)), entry.value)
	end

	local rows = {}

	for _, kind in ipairs(Options.SPARKLE_TYPES) do
		if AUI.HiddenSettings:IsSparkle(kind) then
			rows[#rows + 1] = kind
		end
	end

	local containers = 0

	for _ in pairs(AUI.HiddenSettings:Containers()) do
		containers = containers + 1
	end

	AUI:Print("rows on: %s  active %s  shown %s %s", #rows > 0 and table.concat(rows, ", ") or "none",
		tostring(AUI.ApproachSparkles.active), tostring(AUI.ApproachSparkles.kind), tostring(AUI.ApproachSparkles.state))
	AUI:Print("GetLootSourceInfo %s  learned containers %d", tostring(GetLootSourceInfo ~= nil), containers)
end
