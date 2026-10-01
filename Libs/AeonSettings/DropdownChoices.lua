-- Dropdown choices: a setting's options merged with LibSharedMedia's media for the font, texture and sound
-- pickers. Frame-free; the media library is passed in.
local _, ns = ...
local AS = ns.AeonSettings

---A choice: `value`, `text`, and where it applies `blocked` (a reason), `tooltip`, `font`, `texture`, `soundKit`,
---`soundFile`. A choice with `title` is a group heading that cannot be chosen.
---@alias AeonSettingsChoice { value: any, text: string, title: boolean?, blocked: string?, tooltip: string?, font: string?, texture: string?, soundKit: number?, soundFile: string? }

---The part of LibSharedMedia-3.0 the choices read.
---@class AeonSettingsMediaSource
---@field MediaType { FONT: string, STATUSBAR: string, SOUND: string }
---@field List fun(self: AeonSettingsMediaSource, mediaType: string): string[] registered names, in list order
---@field HashTable fun(self: AeonSettingsMediaSource, mediaType: string): table<string, any>? files by name

---Returns a registered media file by name, or nil. Reads the registry directly, so a global override set
---through LibSharedMedia does not replace every entry; an empty file counts as missing.
---@param media AeonSettingsMediaSource
---@param mediaType string
---@param name string
---@return any
function AS:MediaFile(media, mediaType, name)
	local registry = media:HashTable(mediaType)
	local file = registry and registry[name]
	if file == "" then
		return nil
	end

	return file
end

---Returns the choices a dropdown lists: the setting's options in their order, then, for a picker, every
---registered media name not already used as an option's text or value. An `options` function runs through
---`AS:CallHost`; if it raises an error there are no options. LibSharedMedia's own "None" sound, stored as the
---number 1, is left out; the setting supplies its own.
---@param options AeonSettingsChoice[]|fun(): AeonSettingsChoice[]|nil
---@param picker "font" | "texture" | "sound" | nil
---@param media AeonSettingsMediaSource
---@return AeonSettingsChoice[]
function AS:DropdownChoices(options, picker, media)
	if type(options) == "function" then
		options = self:CallHost(nil, options)
	end

	local choices = {}
	local seen = {}
	for _, option in ipairs(options or {}) do
		choices[#choices + 1] = option
		seen[option.text] = true
		seen[tostring(option.value)] = true
	end

	if picker == "font" or picker == "texture" then
		local mediaType = picker == "font" and media.MediaType.FONT or media.MediaType.STATUSBAR
		for _, name in ipairs(media:List(mediaType)) do
			local file = self:MediaFile(media, mediaType, name)
			if file and not seen[name] then
				choices[#choices + 1] = {
					value = name,
					text = name,
					font = picker == "font" and file or nil,
					texture = picker == "texture" and file or nil,
				}
			end
		end
	elseif picker == "sound" then
		for _, name in ipairs(media:List(media.MediaType.SOUND)) do
			local file = self:MediaFile(media, media.MediaType.SOUND, name)
			if file and file ~= 1 and not seen[name] then
				choices[#choices + 1] = { value = name, text = name, soundFile = file }
			end
		end
	end

	return choices
end

---Returns the first choice with `value`, and its index.
---@param choices AeonSettingsChoice[]
---@param value any
---@return AeonSettingsChoice?
---@return integer?
function AS:FindChoice(choices, value)
	for index, choice in ipairs(choices) do
		if not choice.title and choice.value == value then
			return choice, index
		end
	end

	return nil
end
