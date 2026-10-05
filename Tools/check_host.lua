-- Checks Settings/Host.lua outside the game: registration checks, the contract version, page-id namespacing, the
-- hosted header after AeonUI's categories and the handle's routing to the window.
-- Run from any directory with Lua 5.1: lua Tools/check_host.lua
-- AeonUI's Settings and the library are stand-ins that record the calls; drawing is not exercised.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

local printed = {}
local window = { calls = {} }
for _, method in ipairs({ "RefreshPage", "ShowStatus", "SetPreviewChosen", "SetReloadPending" }) do
	window[method] = function(_, first, second)
		window.calls[#window.calls + 1] = method .. " " .. tostring(first) .. " " .. tostring(second)
	end
end

local opened, shown, hostChanges = {}, false, 0
local cursor = {}

local AUI = {
	L = setmetatable({}, {
		__index = function(_, key)
			return key
		end,
	}),
	Profile = { characterID = "Player-1" },
	AeonSettings = {
		CallHost = function(_, fallback, fn, ...)
			local ok, result = pcall(fn, ...)

			return ok and result or fallback
		end,
		TextCursor = function(_, id)
			return cursor[id]
		end,
		SetTextCursor = function(_, id, position)
			cursor[id] = position
		end,
	},
}

function AUI:Print(message, ...)
	printed[#printed + 1] = message:format(...)
end

AUI.Settings = {
	Create = function(self)
		self.window = window
	end,
	Open = function(self, page)
		self:Create()
		opened[#opened + 1] = page or "<last>"
		shown = true
	end,
	Close = function()
		shown = false
	end,
	IsOpen = function()
		return shown
	end,
	OnHostChanged = function()
		hostChanges = hostChanges + 1
	end,
}

assert(loadfile(root .. "Settings/Host.lua"))("AeonUI", AUI)

-- Harness -------------------------------------------------------------------------------------------------

local checks = 0

local function Equal(name, actual, expected)
	checks = checks + 1
	if actual ~= expected then
		io.stderr:write(("FAIL: %s: expected %s, got %s\n"):format(name, tostring(expected), tostring(actual)))
		os.exit(1)
	end
end

local Host = AUI.SettingsHost

local function Registration(fields)
	local registration = {
		contract = 1,
		addon = "AeonEssentials",
		title = "Aeon Essentials",
		pages = {
			{ id = "automation", title = "Automation", Build = function() return {} end, tabs = { { id = "a" } } },
			{ id = "controls", title = "Controls", Build = function() return {} end },
		},
	}
	for key, value in pairs(fields or {}) do
		registration[key] = value
	end

	return registration
end

-- Registration --------------------------------------------------------------------------------------------

Equal("the host is a global", type(AeonUIHost), "table")
Equal("nothing hosted, no header", Host:Category(), nil)

local accepted, reason = AeonUIHost:Register("nonsense")
Equal("a malformed registration is refused", accepted, false)
Equal("with a reason", type(reason), "string")
Equal("pages without Build are refused", (AeonUIHost:Register(Registration({ pages = { { id = "x" } } }))), false)

accepted = AeonUIHost:Register(Registration({ contract = 2 }))
Equal("a newer contract is refused", accepted, false)
Equal("and says so once", #printed, 1)
AeonUIHost:Register(Registration({ contract = 3 }))
Equal("only once per session", #printed, 1)

local handle
accepted = AeonUIHost:Register(Registration({
	onAttached = function(given)
		handle = given
	end,
}))
Equal("a current registration is accepted", accepted, true)
Equal("the guest gets its handle", type(handle), "table")
Equal("the window is told", hostChanges, 1)
Equal("a second guest is refused", (AeonUIHost:Register(Registration({ addon = "Other" }))), false)

local category = Host:Category()
Equal("one header titled for the guest", category.title, "Aeon Essentials")
Equal("holding its pages", #category.pages, 2)
Equal("page ids are namespaced", category.pages[1].id, "AeonEssentials:automation")
Equal("the guest's own page is left unchanged", Host.guest.pages[1].id, "automation")
Equal("other page fields pass through", category.pages[1].tabs[1].id, "a")

-- Handle --------------------------------------------------------------------------------------------------

Equal("open routes to the namespaced page", (handle:Open("controls")), true)
Equal("the window opened there", opened[#opened], "AeonEssentials:controls")
handle:Open()
Equal("open without a page keeps the last one", opened[#opened], "<last>")
Equal("is open", handle:IsOpen(), true)
handle:RefreshPage()
handle:ShowStatus("Saved.")
handle:SetReloadPending("uiScale", true)
handle:SetPreviewChosen("ring")
Equal("calls reach the window, reload keys namespaced", table.concat(window.calls, "|"),
	"RefreshPage nil nil|ShowStatus Saved. nil|SetReloadPending AeonEssentials:uiScale true|SetPreviewChosen ring nil")
handle:SetTextCursor("tag", 4)
Equal("text cursors pass through", handle:TextCursor("tag"), 4)
handle:Close()
Equal("close closes", handle:IsOpen(), false)
window.calls = {}
handle:RefreshPage()
Equal("a closed window is not refreshed", #window.calls, 0)

AUI.failed = true
Equal("open fails while AeonUI is off", (handle:Open("controls")), false)
AUI.failed = nil
AUI.Profile.characterID = ""
Equal("open fails before the character is known", (handle:Open("controls")), false)

io.stdout:write(("check_host: %d checks passed\n"):format(checks))
