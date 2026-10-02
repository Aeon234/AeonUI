local AUI = select(2, ...)

local L = AUI.L
local Schema = AUI.Schema
local Pages = AUI.SettingsPages

local Section, Row, Choice, Slider, Check, Color, Setting = Pages.Section, Pages.Row, Pages.Choice, Pages.Slider,
	Pages.Check, Pages.Color, Pages.Setting

-- The frame pages, in the order Copy From lists them.
local FRAME_KEYS = { "player", "pet", "target", "targettarget", "focus", "boss", "playerPower" }

---Settings under a frame that a section header copies or returns to the shared settings.
---@class AUISharedScope
---@field paths string[] paths under the frame: a setting, or a branch ending in a dot
---@field exclude table<string, true>? paths under the frame left out: the section's switch, position and attachment

---The shared appearance on the Globals page, and the frame pages' section headers that copy a section from another
---frame or return it to the shared settings.
---@class AUISettingsShared
---@field SCOPES table<string, AUISharedScope> by section
local Shared = {
	SCOPES = {
		appearance = { paths = { "bars.", "reverse" } },
		absorbsAndHeals = { paths = { "overlays." } },
		castBar = {
			paths = { "castbar." },
			exclude = {
				["castbar.enabled"] = true,
				["castbar.x"] = true,
				["castbar.y"] = true,
				["castbar.side"] = true,
				["castbar.matchWidth"] = true,
			},
		},
		buffs = {
			paths = { "buffs." },
			exclude = { ["buffs.enabled"] = true, ["buffs.anchor"] = true, ["buffs.x"] = true, ["buffs.y"] = true },
		},
		debuffs = {
			paths = { "debuffs." },
			exclude = { ["debuffs.enabled"] = true, ["debuffs.anchor"] = true, ["debuffs.x"] = true, ["debuffs.y"] = true },
		},
		indicators = { paths = { "indicators.", "totems.", "highlight", "tooltip." } },
		text = { paths = { "text." } },
		numbers = { paths = { "numbers." } },
	},
}
AUI.SettingsShared = Shared

---@param name string a path under a frame
---@param scope AUISharedScope
---@return boolean inside
local function InScope(name, scope)
	if scope.exclude and scope.exclude[name] then
		return false
	end

	for _, prefix in ipairs(scope.paths) do
		if name == prefix or (prefix:sub(-1) == "." and name:sub(1, #prefix) == prefix) then
			return true
		end
	end

	return false
end

---@param key string
---@param scope AUISharedScope
---@return string[] paths the frame's settings inside the scope, in declaration order
function Shared:Paths(key, scope)
	local base = "frames." .. key .. "."
	local paths = {}

	for _, path in ipairs(Schema.order) do
		if path:sub(1, #base) == base and InScope(path:sub(#base + 1), scope) then
			paths[#paths + 1] = path
		end
	end

	return paths
end

---@param key string
---@param scope AUISharedScope
---@return string[] paths the scope's settings that follow a shared one and hold the frame's own value
function Shared:CustomPaths(key, scope)
	local custom = {}

	for _, path in ipairs(self:Paths(key, scope)) do
		if AUI.Profile:IsCustom(path) then
			custom[#custom + 1] = path
		end
	end

	return custom
end

---Copies a section from one frame to another as one change, Shared and Custom states included. A setting the target
---lacks, or whose value it cannot hold, is left out.
---@param fromKey string
---@param toKey string
---@param scope AUISharedScope
---@return boolean ok
---@return string[] skipped the source paths left out
function Shared:Copy(fromKey, toKey, scope)
	local config = AUI.Profile.config
	local from, to = "frames." .. fromKey .. ".", "frames." .. toKey .. "."
	local map, skipped = {}, {}

	for _, source in ipairs(self:Paths(fromKey, scope)) do
		local target = to .. source:sub(#from + 1)
		local value = Schema:Lookup(config, source)

		if Schema:Field(target) and (value == nil or (Schema:CheckValue(target, value))) then
			map[target] = source
		else
			skipped[#skipped + 1] = source
		end
	end

	return (AUI.Profile:CopyPaths(map)), skipped
end

---@param key string
---@return table<string, string> labels the labels of the frame page's settings, by path
local function Labels(key)
	local labels = {}

	for _, element in ipairs(Pages:BuildFrame(key)) do
		for _, setting in ipairs(element.settings or { element.setting }) do
			if setting.path and setting.label and not labels[setting.path] then
				labels[setting.path] = setting.label
			end
		end
	end

	return labels
end

---Reports a copy in chat, naming the settings the target frame has no place for.
---@param fromKey string
---@param toKey string
---@param title string the section's title
---@param skipped string[]
function Shared:Report(fromKey, toKey, title, skipped)
	local Text = AUI.SettingsText

	AUI:Print(L["Copied %s from %s."], title, Text:FrameTitle(fromKey))

	if #skipped == 0 then
		return
	end

	local labels = Labels(fromKey)
	local base = "frames." .. fromKey .. "."
	local names, seen = {}, {}

	for _, path in ipairs(skipped) do
		local slot = path:match("%.text%.slots%.(%d+)%.")
		local name = labels[path] or (slot and L["Text %d"]:format(tonumber(slot))) or path:sub(#base + 1)

		if not seen[name] then
			seen[name] = true
			names[#names + 1] = name
		end
	end

	AUI:Print(L["Not copied, as %s has no place for them: %s."], Text:FrameTitle(toKey), table.concat(names, ", "))
end

---A frame page's section header: Use Shared while the section holds settings that follow shared ones, and a Copy From
---menu listing the other frames with the section when it copies.
---@param id string
---@param title string
---@param key string
---@param scope AUISharedScope
---@param copy boolean
---@return table element
function Shared:Section(id, title, key, scope, copy)
	local fields = {}
	local inherits = false

	for _, path in ipairs(self:Paths(key, scope)) do
		local field = Schema:Field(path)

		if field and field.shared then
			inherits = true

			break
		end
	end

	if inherits then
		fields.action = {
			id = id .. "UseShared",
			control = "action",
			label = L["Use Shared"],
			verb = L["Use Shared"],
			confirm = L["Return %s to the shared settings?"]:format(title),
			blocked = function()
				if #self:CustomPaths(key, scope) == 0 then
					return L["This section follows the shared settings."]
				end
			end,
			set = function()
				local custom = self:CustomPaths(key, scope)

				if #custom > 0 and not AUI.Profile:Reset(custom) then
					return false
				end

				return true
			end,
		}
	end

	local options = {}

	for _, other in ipairs(copy and FRAME_KEYS or {}) do
		if other ~= key and #self:Paths(other, scope) > 0 then
			options[#options + 1] = { value = other, text = AUI.SettingsText:FrameTitle(other) }
		end
	end

	if #options > 0 then
		fields.menu = {
			id = id .. "CopyFrom",
			control = "dropdown",
			label = L["Copy From"],
			placeholder = L["Copy From"],
			verb = L["Copy"],
			width = "fit",
			rebuild = true,
			options = options,
			confirm = function(from)
				return L["Replace this frame's %s settings with those of %s?"]:format(title, AUI.SettingsText:FrameTitle(from))
			end,
			get = function()
				return nil
			end,
			set = function(from)
				local ok, skipped = self:Copy(from, key, scope)

				if not ok then
					return false
				end

				self:Report(from, key, title, skipped)
			end,
		}
	end

	return Section(id, title, fields)
end

---The bar look rows of a frame page's Appearance section, or of the Globals page's Bars section.
---@param base string `bars.` or a frame's `frames.<key>.bars.`
---@return table[] elements
function Shared:BarRows(base)
	local borderMin, borderMax = Pages.Range(base .. "border")
	local textures = {}

	for _, name in ipairs({ "texture", "powerTexture" }) do
		if Schema:Field(base .. name) then
			textures[#textures + 1] = Setting("dropdown", "bar" .. name, name == "texture" and L["Health Texture"]
				or L["Power Texture"], base .. name, { picker = "texture", options = Pages.TEXTURES })
		end
	end

	return {
		Row(textures[1], textures[2]),
		Row(
			Color("barBackground", L["Background"], base .. "background", { hasOpacity = true }),
			Slider("barBorder", L["Border Size"], base .. "border", borderMin, borderMax)
		),
		Row(Color("barBorderColor", L["Border Color"], base .. "borderColor", { hasOpacity = true })),
	}
end

---@return table[] elements the Globals page's shared appearance: Bars, Text, Cast Bars and Auras
function Shared:GlobalSections()
	local elements = { Section("bars", L["Bars"]) }

	local function Add(left, right)
		elements[#elements + 1] = Row(left, right)
	end

	for _, element in ipairs(self:BarRows("bars.")) do
		elements[#elements + 1] = element
	end

	elements[#elements + 1] = Section("text", L["Text"])
	Add(
		Setting("dropdown", "font", L["Font"], "text.font", { picker = "font", options = {} }),
		Slider("size", L["Size"], "text.size", Pages.Range("text.size"))
	)
	Add(
		Choice("outline", L["Outline"], "text.outline", Pages.Options("outline", Pages.OUTLINES)),
		Color("color", COLOR, "text.color")
	)

	local cast = "castbar."
	local sizeMin, sizeMax = Pages.Range(cast .. "name.size")

	elements[#elements + 1] = Section("castBars", L["Cast Bars"])
	Add(
		Setting("dropdown", "castTexture", L["Bar Texture"], cast .. "texture", {
			picker = "texture",
			options = Pages.TEXTURES,
		}),
		Check("castSmooth", L["Smooth Animation"], cast .. "smooth")
	)
	Add(
		Color("castColor", L["Fill Color"], cast .. "color"),
		Check("castClassColor", L["Class-Colored Fill"], cast .. "classColor", {
			description = L["Color the fill by the casting unit's class, when it has one."],
		})
	)
	Add(
		Check("castGradient", L["Gradient"], cast .. "gradient"),
		Choice("castGradientDirection", L["Gradient Direction"], cast .. "gradientDirection",
			Pages.Options("orientation", AUI.SettingsCastBar.ORIENTATIONS), { depends = "castGradient" })
	)
	Add(
		Color("castGradientColor", L["Gradient End Color"], cast .. "gradientColor", { depends = "castGradient" }),
		Color("castBackground", L["Background"], cast .. "background", { hasOpacity = true })
	)
	Add(
		Slider("castBorder", L["Border Size"], cast .. "border", Pages.Range(cast .. "border")),
		Check("castSpark", L["Show Spark"], cast .. "spark")
	)
	Add(
		Slider("castNameSize", L["Spell Name Size"], cast .. "name.size", sizeMin, sizeMax),
		Color("castNameColor", L["Spell Name Color"], cast .. "name.color")
	)
	Add(
		Slider("castTimeSize", L["Time Size"], cast .. "time.size", sizeMin, sizeMax),
		Color("castTimeColor", L["Time Color"], cast .. "time.color")
	)
	Add(
		Slider("castTargetSize", L["Cast Target Size"], cast .. "target.size", sizeMin, sizeMax),
		Choice("castOutline", L["Outline"], cast .. "outline", Pages.Options("outline", Pages.OUTLINES))
	)
	Add(Check("castShadow", L["Text Shadow"], cast .. "shadow"))
	Add(
		Color("castNotInterruptible", L["Not Interruptible"], cast .. "notInterruptible", {
			description = L["The fill color while the cast cannot be interrupted."],
		}),
		Color("castInterrupted", L["Interrupted"], cast .. "interrupted", {
			description = L["The fill color while Interrupted or Failed shows."],
		})
	)

	local auras = "auras."
	local textMin, textMax = Pages.Range(auras .. "durationSize")

	elements[#elements + 1] = Section("auras", L["Auras"])
	Add(
		Check("auraSwipe", L["Cooldown Swipe"], auras .. "swipe"),
		Check("auraBorder", L["Aura Borders"], auras .. "border", {
			description = L["The stealable glow on buffs and the dispel type border on debuffs."],
		})
	)
	Add(
		Check("auraDuration", L["Show Duration"], auras .. "duration"),
		Slider("auraDurationSize", L["Duration Size"], auras .. "durationSize", textMin, textMax, {
			depends = "auraDuration",
		})
	)
	Add(
		Choice("auraCountCorner", L["Stack Position"], auras .. "countCorner",
			Pages.Options("auraCorner", AUI.SettingsAuras.CORNERS)),
		Slider("auraCountSize", L["Stack Size"], auras .. "countSize", textMin, textMax)
	)

	return elements
end
