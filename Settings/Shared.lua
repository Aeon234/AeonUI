local AUI = select(2, ...)

local L = AUI.L
local Schema = AUI.Schema
local Pages = AUI.SettingsPages

local Section, Row, Choice, Slider, Check, Color, Setting = Pages.Section, Pages.Row, Pages.Choice, Pages.Slider,
	Pages.Check, Pages.Color, Pages.Setting

-- Health color modes.
local HEALTH_MODES = {
	classReaction = L["Class / Reaction"],
	custom = CUSTOM,
	classic = L["Classic"],
	stops = L["Custom Stops"],
	classFade = L["Class Fade"],
}

local HEALTH_BACKGROUNDS = {
	custom = L["Bar Background"],
	classReaction = L["Class / Reaction"],
}

-- Reaction colors and the Blizzard reaction level each one shows until set.
local REACTIONS = {
	{ name = "hostile", label = FACTION_STANDING_LABEL2, level = 2 },
	{ name = "neutral", label = FACTION_STANDING_LABEL4, level = 4 },
	{ name = "friendly", label = FACTION_STANDING_LABEL5, level = 5 },
}

local POWER_MODES = {
	type = L["Power Type"],
	class = CLASS,
	custom = CUSTOM,
}

local POWER_BACKGROUNDS = {
	custom = L["Bar Background"],
	power = L["Power Color"],
}

-- The frame pages, in the order Copy From lists them.
local FRAME_KEYS = { "player", "pet", "target", "targettarget", "focus", "boss", "playerPower" }

---Settings under a frame that a section header copies or returns to the shared settings.
---@class AUISharedScope
---@field paths string[] paths under the frame: a setting, or a branch ending in a dot
---@field exclude table<string, true>? paths under the frame left out: the section's switch, position and attachment;
---a path ending in a dot leaves out its whole branch

---The shared appearance on the Globals page, and the frame pages' section headers that copy a section from another
---frame or return it to the shared settings.
---@class AUISettingsShared
---@field SCOPES table<string, AUISharedScope> by section
local Shared = {
	SCOPES = {
		appearance = { paths = { "bars.", "reverse", "portrait." } },
		absorbsAndHeals = { paths = { "overlays." } },
		castBar = {
			paths = { "castbar." },
			exclude = {
				["castbar.enabled"] = true,
				["castbar.x"] = true,
				["castbar.y"] = true,
				["castbar.side"] = true,
				["castbar.matchWidth"] = true,
				["castbar.layout."] = true,
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
		healthColors = { paths = { "health." } },
		powerColors = { paths = { "powerColors." } },
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
	for excluded in pairs(scope.exclude or {}) do
		if name == excluded or (excluded:sub(-1) == "." and name:sub(1, #excluded) == excluded) then
			return false
		end
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

---The health color rows of a frame page's Health Colors section, or of the Globals page's.
---@param base string `health.` or a frame's `frames.<key>.health.`
---@return table[] elements
function Shared:HealthRows(base)
	---@param modes table<string, true> the fill modes that use the setting
	---@param reason string
	---@return fun(): string? blocked
	local function Unless(modes, reason)
		return function()
			if AUI.Profile:Get(base .. "dark") then
				return L["Dark Mode sets the fill."]
			end

			if not modes[AUI.Profile:Get(base .. "mode")] then
				return reason
			end
		end
	end

	local stopsReason = L["Only with Custom Stops or Class Fade."]

	return {
		Row(
			Choice("healthMode", L["Health Color"], base .. "mode", Pages.Options("healthMode", HEALTH_MODES), {
				description = L["Classic and Custom Stops follow the unit's health; Class Fade starts from the class or reaction color at full health."],
				blocked = function()
					if AUI.Profile:Get(base .. "dark") then
						return L["Dark Mode sets the fill."]
					end
				end,
			}),
			Color("healthCustom", L["Custom Color"], base .. "color", {
				blocked = Unless({ custom = true }, L["Only with the Custom health color."]),
			})
		),
		Row(
			Color("healthFull", L["Full Health Color"], base .. "stops.full", {
				blocked = Unless({ stops = true }, L["Only with Custom Stops."]),
			}),
			Color("healthHalf", L["Half Health Color"], base .. "stops.half", {
				blocked = Unless({ stops = true, classFade = true }, stopsReason),
			})
		),
		Row(
			Color("healthEmpty", L["Empty Health Color"], base .. "stops.empty", {
				blocked = Unless({ stops = true, classFade = true }, stopsReason),
			}),
			Slider("healthFillAlpha", L["Fill Opacity"], base .. "fillAlpha", 0, 100, { format = "percent", step = 5 })
		),
		Row(
			Check("healthGradient", L["Gradient"], base .. "gradient", {
				description = L["Blends the fill toward the end color. A restricted unit's health color stays solid."],
			}),
			Choice("healthGradientDirection", L["Gradient Direction"], base .. "gradientDirection",
				Pages.Options("orientation", AUI.SettingsCastBar.ORIENTATIONS), { depends = "healthGradient" })
		),
		Row(
			Color("healthGradientColor", L["Gradient End Color"], base .. "gradientColor", {
				depends = "healthGradient",
				hasOpacity = true,
			}),
			Choice("healthBackground", L["Background Color"], base .. "background",
				Pages.Options("healthBackground", HEALTH_BACKGROUNDS), {
					description = L["Class / Reaction uses the unit's color at the bar background's opacity."],
				})
		),
		Row(
			Check("healthDead", L["Dead Background"], base .. "deadBackground", {
				description = L["Colors the background while the unit is dead or a ghost."],
			}),
			Color("healthDeadColor", L["Dead Background Color"], base .. "deadColor", {
				depends = "healthDead",
				hasOpacity = true,
			})
		),
		Row(
			Check("healthDark", L["Dark Mode"], base .. "dark", {
				description = L["A dark fill over a lighter background, whatever the health color."],
			}),
			Color("healthDarkFill", L["Dark Fill"], base .. "darkFill", { depends = "healthDark", hasOpacity = true })
		),
		Row(Color("healthDarkBackground", L["Dark Background"], base .. "darkBackground", {
			depends = "healthDark",
			hasOpacity = true,
		})),
	}
end

---The power color rows of a frame page's Power Colors section, or of the Globals page's.
---@param base string `powerColors.` or a frame's `frames.<key>.powerColors.`
---@return table[] elements
function Shared:PowerRows(base)
	return {
		Row(
			Choice("powerMode", L["Power Color"], base .. "mode", Pages.Options("powerMode", POWER_MODES), {
				description = L["Class colors a player's power bar by class; other units keep their power type's color."],
			}),
			Color("powerCustom", L["Custom Color"], base .. "color", {
				blocked = function()
					if AUI.Profile:Get(base .. "mode") ~= "custom" then
						return L["Only with the Custom power color."]
					end
				end,
			})
		),
		Row(
			Check("powerGradient", L["Gradient"], base .. "gradient"),
			Choice("powerGradientDirection", L["Gradient Direction"], base .. "gradientDirection",
				Pages.Options("orientation", AUI.SettingsCastBar.ORIENTATIONS), { depends = "powerGradient" })
		),
		Row(
			Color("powerGradientColor", L["Gradient End Color"], base .. "gradientColor", {
				depends = "powerGradient",
				hasOpacity = true,
			}),
			Choice("powerBackground", L["Background Color"], base .. "background",
				Pages.Options("powerBackground", POWER_BACKGROUNDS), {
					description = L["Power Color uses the bar's color at the bar background's opacity."],
				})
		),
		Row(Slider("powerFillAlpha", L["Fill Opacity"], base .. "fillAlpha", 0, 100, { format = "percent", step = 5 })),
	}
end

---@return table[] elements the Globals page's Power Colors section, with a color for each power type the client has
local function GlobalPowerSection()
	local elements = { Section("powerColors", L["Power Colors"]) }

	for _, element in ipairs(Shared:PowerRows("powerColors.")) do
		elements[#elements + 1] = element
	end

	local swatches = {}

	for _, token in ipairs(AUI.Schema.choices.powerTokens) do
		if AUI.oUF.colors.power[token] then
			local path = "powerColors.palette." .. token

			swatches[#swatches + 1] = Color("power" .. token, _G[token] or token, path, {
				description = L["Until set, Blizzard's color for this power type."],
				get = function()
					local color = AUI.Profile:Get(path) or AUI.PowerColor.blizzard[token] or AUI.oUF.colors.power[token]

					return { r = color.r, g = color.g, b = color.b }
				end,
			})
		end
	end

	for index = 1, #swatches, 2 do
		elements[#elements + 1] = Row(swatches[index], swatches[index + 1])
	end

	return elements
end

---@return table[] elements the Globals page's Health Colors section, with the game-state and reaction colors
local function GlobalHealthSection()
	local elements = { Section("healthColors", L["Health Colors"]) }

	for _, element in ipairs(Shared:HealthRows("health.")) do
		elements[#elements + 1] = element
	end

	elements[#elements + 1] = Row(
		Check("healthTapped", L["Tapped"], "health.tapped", {
			description = L["Grays the health of a unit someone else has tapped."],
		}),
		Color("healthTappedColor", L["Tapped Color"], "health.tappedColor", { depends = "healthTapped" })
	)
	elements[#elements + 1] = Row(
		Check("healthDisconnected", L["Disconnected"], "health.disconnected", {
			description = L["Grays the health of a disconnected player."],
		}),
		Color("healthDisconnectedColor", L["Disconnected Color"], "health.disconnectedColor",
			{ depends = "healthDisconnected" })
	)

	local swatches = {}

	for _, reaction in ipairs(REACTIONS) do
		local path = "health.reaction." .. reaction.name

		swatches[#swatches + 1] = Color("reaction" .. reaction.name, reaction.label, path, {
			description = L["Until set, Blizzard's color for this reaction."],
			get = function()
				local color = AUI.Profile:Get(path) or AUI.oUF.colors.reaction[reaction.level]

				return { r = color.r, g = color.g, b = color.b }
			end,
		})
	end

	elements[#elements + 1] = Row(swatches[1], swatches[2])
	elements[#elements + 1] = Row(swatches[3])

	return elements
end

---@return table[] elements the Globals page's shared appearance: Bars, Health Colors, Text, Cast Bars and Auras
function Shared:GlobalSections()
	local elements = { Section("bars", L["Bars"]) }

	local function Add(left, right)
		elements[#elements + 1] = Row(left, right)
	end

	for _, element in ipairs(self:BarRows("bars.")) do
		elements[#elements + 1] = element
	end

	for _, element in ipairs(GlobalHealthSection()) do
		elements[#elements + 1] = element
	end

	for _, element in ipairs(GlobalPowerSection()) do
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
