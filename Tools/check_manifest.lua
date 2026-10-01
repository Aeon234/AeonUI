-- Checks the load path: every file the .toc and its .xml files name exists, and every AeonUI-owned .lua file is
-- loaded exactly once. Libraries under Libs/ are followed only where embeds.xml names them.
-- Run from any directory with Lua 5.1: lua Tools/check_manifest.lua

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"
local windows = package.config:sub(1, 1) == "\\"

-- Folders whose .lua files are never loaded by the game or are not AeonUI's.
local UNLISTED = { ["Libs/"] = true, ["Tools/"] = true, ["Scripts/"] = true }

local problems = {}
local loaded = {}

local function Problem(text)
	problems[#problems + 1] = text
end

local function Read(path)
	local file = io.open(root .. path, "rb")
	if not file then
		return nil
	end
	local text = file:read("*a")
	file:close()

	return text
end

local function Normalize(path)
	path = path:gsub("\\", "/")
	local parts = {}
	for part in path:gmatch("[^/]+") do
		if part == ".." then
			parts[#parts] = nil
		elseif part ~= "." then
			parts[#parts + 1] = part
		end
	end

	return table.concat(parts, "/")
end

local Visit

local function Load(path, from)
	path = Normalize(path)
	local text = Read(path)
	if not text then
		Problem(("missing %s (named by %s)"):format(path, from))

		return
	end
	if path:match("%.lua$") then
		if loaded[path] then
			Problem(("loaded twice: %s (%s and %s)"):format(path, loaded[path], from))
		end
		loaded[path] = from
	elseif path:match("%.xml$") then
		Visit(path, text)
	end
end

function Visit(path, text)
	local dir = path:match("^(.*/)") or ""
	-- Strip comments so commented-out examples (oUF.xml has some) are not followed.
	text = text:gsub("<!%-%-.-%-%->", "")
	for tag, file in text:gmatch("<(%a+)%s+file%s*=%s*\"([^\"]+)\"") do
		if tag == "Script" or tag == "Include" then
			Load(dir .. file, path)
		end
	end
end

local toc = Read("AeonUI.toc")
if not toc then
	Problem("missing AeonUI.toc")
else
	toc = toc:gsub("#@do%-not%-package@.-#@end%-do%-not%-package@", function(block)
		return block:gsub("\n#", "\n")
	end)
	for line in toc:gmatch("[^\r\n]+") do
		if not line:match("^%s*#") and line:match("%S") then
			Load(line:match("^%s*(.-)%s*$"), "AeonUI.toc")
		end
	end
end

-- Every owned .lua file on disk must be loaded.
local here = assert(io.popen(windows and ('cd /d "%s" && cd'):format(root:gsub("/", "\\")) or ('cd "%s" && pwd'):format(root)))
local base = Normalize(here:read("*l")):lower() .. "/"
here:close()
local listing = windows and 'dir /s /b /a-d "' .. root:gsub("/", "\\") .. '*.lua" 2>nul'
	or 'find "' .. root .. '" -name "*.lua" -type f'
local pipe = assert(io.popen(listing))
for line in pipe:lines() do
	local path = Normalize(line)
	if path:lower():sub(1, #base) == base then
		path = path:sub(#base + 1)
	end
	local top = path:match("^[^/]+/")
	if not (top and UNLISTED[top]) and not path:match("^%.") and not loaded[path] then
		Problem("not loaded: " .. path)
	end
end
pipe:close()

local count = 0
for _ in pairs(loaded) do
	count = count + 1
end

if #problems > 0 then
	for _, text in ipairs(problems) do
		print("FAIL: " .. text)
	end
	os.exit(1)
end
print(("check_manifest: %d Lua files on the load path, all present and owned files all loaded"):format(count))
