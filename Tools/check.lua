-- Runs every out-of-game check, each in its own interpreter so each keeps its own stubbed globals.
-- Run from any directory with Lua 5.1: lua Tools/check.lua
-- Exits non-zero when any check fails.

local SCRIPTS = { "check_manifest.lua", "check_core.lua", "check_media.lua", "check_profile.lua", "check_codec.lua",
	"check_minimap.lua", "check_worldmap.lua", "check_tooltip.lua", "check_interface.lua",
	"check_settings.lua" }

local dir = (arg and arg[0] or ""):match("^(.-)[^/\\]*$")
local lua = arg and arg[-1] or "lua"
local windows = package.config:sub(1, 1) == "\\"

local failed = 0
for _, script in ipairs(SCRIPTS) do
	local command = ('"%s" "%s%s"'):format(lua, dir, script)
	if windows then
		-- cmd.exe strips one pair of outer quotes from the whole line.
		command = '"' .. command .. '"'
	end
	local status = os.execute(command)
	if status ~= 0 and status ~= true then
		failed = failed + 1
		print(("check: %s failed"):format(script))
	end
end

if failed > 0 then
	os.exit(1)
end
print(("check: all %d scripts passed"):format(#SCRIPTS))
