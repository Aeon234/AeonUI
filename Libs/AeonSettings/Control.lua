-- Behavior every control shares: active state and reason, the request path, how an interaction ends,
-- refused-save shake and message, and the reason tooltip on an unlabeled inactive control.
local _, ns = ...
local AS = ns.AeonSettings
local L = AS.L
local tokens = AS.tokens

---Capitalizes the first letter of every whitespace-separated word and leaves the rest as written.
---@param text string
---@return string
function AS:TitleCase(text)
	return (text:gsub("(%S+)", function(word)
		return (word:gsub("^(%p*)(%a)", function(prefix, letter)
			return prefix .. letter:upper()
		end, 1))
	end))
end

---Mixed into every control frame. The mixin owns the active state, the request path and the three ways an
---interaction ends: going inactive, `Release` and hiding. A control calls `InitControl` from its OnLoad and
---implements any of these hooks:
---  `ApplyEnabled(enabled)`: restyles its own widgets for the active state.
---  `EndInteraction()`: ends a user interaction in progress (a drag, focus, an open menu, picker or popup, a
---    press). Runs when the control goes inactive, is released or is hidden.
---  `StopMotion()`: stops running animation and puts moving parts back. Runs on release and hide, never when
---    going inactive. The default stops the shake.
---  `IsSaved(value)`: whether `value` equals the saved value; `Request` then asks nothing.
---@class AeonSettingsControlMixin
---@field enabled boolean
---@field reason string?
---@field label AeonSettingsLabel?
---@field onRequest fun(value: any)?
---@field motionTarget Region the frame the shake moves, anchored at CENTER of the control
---@field hoverRegions Region[] regions whose hover shows the reason on an unlabeled inactive control
local Control = {}
AS.ControlMixin = Control

---Tooltip lines for an unlabeled inactive control: the control's own cut-off text, when it has one, then
---the reason.
---@return { [1]: string, [2]: number[] }[]
function Control:ReasonLines()
	local fullText = self.TooltipFullText and self:TooltipFullText() or nil

	return AS.Tooltip:Lines(fullText, nil, self.reason)
end

---@return boolean
function Control:ShowsReason()
	return not self.enabled and not self.label and self.reason ~= nil
end

---Sets up the shared behavior. Call once from the control's OnLoad.
---@param motionTarget Region the frame the shake moves, anchored at CENTER of the control
---@param hoverTarget Region the control's main hover region for the reason tooltip
---@param ... Region further hover regions for the reason tooltip
function Control:InitControl(motionTarget, hoverTarget, ...)
	self.enabled = true
	self.motionTarget = motionTarget
	self.hoverRegions = { hoverTarget, ... }
	for _, region in ipairs(self.hoverRegions) do
		region:HookScript("OnEnter", function()
			if self:ShowsReason() then
				AS.Tooltip:Show(region, self:ReasonLines())
			end
		end)
		region:HookScript("OnLeave", function()
			AS.Tooltip:Hide(region)
		end)
	end
end

function Control:ApplyEnabled(_) end

function Control:EndInteraction() end

function Control:StopMotion()
	self:StopShake()
end

---@param _ any
---@return boolean
function Control:IsSaved(_)
	return false
end

---Whether a continuous interaction is under way (a slider drag), during which the page must not be rebuilt.
---@return boolean
function Control:IsInteracting()
	return false
end

---Runs `fn` once the current interaction ends, or at once when none is under way. A later call replaces an
---earlier one still waiting.
---@param fn fun()
function Control:AfterInteraction(fn)
	if self:IsInteracting() then
		self.afterInteraction = fn
	else
		fn()
	end
end

---Runs the function `AfterInteraction` held back. A control calls it when its interaction ends.
function Control:InteractionEnded()
	local fn = self.afterInteraction
	self.afterInteraction = nil
	if fn then
		fn()
	end
end

---Refusal message when the owner refuses without one.
---@param name string the setting's label or id
---@return string
function Control:DefaultRefusal(name)
	return L["Couldn't save %s."]:format(name)
end

---Makes the control active or inactive. Going inactive ends an interaction in progress first; a running
---animation continues.
---@param enabled boolean
---@param reason string? ignored while enabled
function Control:SetEnabled(enabled, reason)
	if not enabled then
		self:EndInteraction()
	end
	self:ApplyEnabled(enabled)
	self:SetEnabledState(enabled, reason)
end

---Records the active state and reason, dims the control, and refreshes its label and any reason tooltip
---under the cursor.
---@param enabled boolean
---@param reason string? ignored while enabled
function Control:SetEnabledState(enabled, reason)
	self.enabled = enabled
	self.reason = not enabled and reason or nil
	self:SetAlpha(enabled and 1 or tokens.alpha.inactive)

	if self.label then
		self.label:Refresh()
	end
	local showsReason = self:ShowsReason()
	for _, region in ipairs(self.hoverRegions) do
		if showsReason and region:IsMouseOver() then
			AS.Tooltip:Show(region, self:ReasonLines())
		elseif AS.Tooltip:IsShownFor(region) then
			AS.Tooltip:Hide(region)
		end
	end
end

---Asks the owner to save `value`, unless nothing listens or `IsSaved(value)` holds.
---@param value any
---@return boolean asked
function Control:Request(value)
	if not self.onRequest or self:IsSaved(value) then
		return false
	end

	self.onRequest(value)

	return true
end

---Signals a refused save: shakes the control (skipped while hidden) and shows the message in Title Case.
---@param message string?
function Control:Reject(message)
	if message then
		UIErrorsFrame:AddExternalErrorMessage(AS:TitleCase(message))
	end
	if self:IsVisible() then
		self:StartShake()
	end
end

---Shakes `motionTarget` sideways: 3 · sin(t · 3 · 2π) · (1 − t) units over the reject duration.
function Control:StartShake()
	local reject = tokens.motion.reject
	local elapsed = 0
	self:SetScript("OnUpdate", function(_, delta)
		elapsed = elapsed + delta
		local t = elapsed / reject.duration
		if t >= 1 then
			self:StopShake()

			return
		end
		local offset = reject.amplitude * math.sin(t * reject.cycles * 2 * math.pi) * (1 - t)
		self.motionTarget:SetPoint("CENTER", self, "CENTER", offset, 0)
	end)
end

---Ends a shake and puts `motionTarget` back in place.
function Control:StopShake()
	self:SetScript("OnUpdate", nil)
	self.motionTarget:SetPoint("CENTER", self, "CENTER", 0, 0)
end

---Ends any interaction and motion and forgets the request handler; the active state and reason stay.
function Control:Release()
	self.afterInteraction = nil
	self:EndInteraction()
	self:StopMotion()
	self.onRequest = nil
	for _, region in ipairs(self.hoverRegions) do
		AS.Tooltip:Hide(region)
	end
	if self.label then
		self.label:Refresh()
	end
end

function Control:OnHide()
	self:EndInteraction()
	self:StopMotion()
end
