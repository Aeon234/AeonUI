local AUI = select(2, ...)

local AS = AUI.AeonSettings --[[@as table]]

---A page element that shows a line or two of explanatory text, one row tall: `{ kind = "note", id, text, small? }`.
---`small` sets it in the smaller, dimmer font used for technical detail.
AS:RegisterElementKind("note", {
	template = "AeonUINoteTemplate",
	Init = function(frame, entry)
		local data = entry.data

		frame.Text:SetFontObject(data.small and "GameFontDisableSmall" or "GameFontHighlight")
		frame.Text:SetText(data.text)
	end,
	Reset = function(frame)
		frame.Text:SetText("")
	end,
	Search = function(data)
		return data.text
	end,
})
