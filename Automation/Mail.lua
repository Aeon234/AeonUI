local AUI = select(2, ...)

local Options = AUI.AutomationOptions

---The send-mail helpers, where `AUI.can.mail` holds: Remember Recipient puts the last recipient back in the To field
---after a mail is sent, and Money Subject fills an empty subject with Money when gold is entered to send, which
---Blizzard needs before a mail can go. Blizzard clears the send form only once a mail has gone, so the name is taken as
---the mail is sent and restored after that reset. The hooks are installed the first time either is on and do nothing
---while it is off.
---@class AUIMail
---@field hooked boolean
---@field recipient string? the name the last mail was sent to
local Mail = {
	hooked = false,
}
AUI.Mail = Mail

---@param path string
---@return boolean
local function IsOn(path)
	return Options:Get(path) == true
end

function Mail:Apply()
	if not AUI.can.mail then
		return
	end

	if not IsOn(Options.REMEMBER_RECIPIENT_PATH) then
		self.recipient = nil
	end

	if self.hooked or not (IsOn(Options.REMEMBER_RECIPIENT_PATH) or IsOn(Options.MONEY_SUBJECT_PATH)) then
		return
	end

	self.hooked = true

	hooksecurefunc("SendMailFrame_SendMail", function()
		if IsOn(Options.REMEMBER_RECIPIENT_PATH) then
			self.recipient = SendMailNameEditBox:GetText()
		end
	end)
	hooksecurefunc("SendMailFrame_Reset", function()
		self:RestoreRecipient()
	end)

	for _, key in ipairs({ "gold", "silver", "copper" }) do
		local box = SendMailMoney[key]

		if box then
			box:HookScript("OnTextChanged", function()
				self:FillSubject()
			end)
		end
	end
end

function Mail:RestoreRecipient()
	if not IsOn(Options.REMEMBER_RECIPIENT_PATH) or not self.recipient or self.recipient == "" then
		return
	end

	SendMailNameEditBox:SetText(self.recipient)
	SendMailNameEditBox:ClearFocus()
end

function Mail:FillSubject()
	if not IsOn(Options.MONEY_SUBJECT_PATH) or SendMailSubjectEditBox:GetText() ~= "" then
		return
	end

	-- The same field holds a C.O.D. charge when that option is chosen; only money sent names the mail.
	local sending = SendMailSendMoneyButton == nil or SendMailSendMoneyButton:GetChecked()

	if sending and MoneyInputFrame_GetCopper(SendMailMoney) > 0 then
		SendMailSubjectEditBox:SetText(MONEY)
	end
end
