if GetLocale() ~= "zhTW" then
	return
end

local L = select(2, ...).AeonSettings.L

-- Control.lua
L["Couldn't save %s."] = "無法儲存%s。"

-- PageModel.lua
L["Requires %s to be enabled."] = "需要啟用%s。"

-- Window.lua
L["Reset %s to defaults?"] = "要將%s重置為預設值嗎？"
L["Reset"] = "重置"
L["Jump to section"] = "跳至區段"
L["%s (collapsed)"] = "%s（已收合）"
L["Unavailable in combat."] = "戰鬥中無法使用。"
L["1 change needs a reload"] = "1 項變更需要重新載入"
L["%d changes need a reload"] = "%d 項變更需要重新載入"
L["%s reset to defaults."] = "%s已重置為預設值。"
L['Search results for "%s"'] = '「%s」的搜尋結果'
L["No settings match."] = "沒有符合的設定。"

-- Preview.lua
L["Preview"] = "預覽"
L["Click part of the preview to find its setting"] = "點擊預覽的某部分以找到其設定"

-- SoundCheckbox.lua
L["Play sound"] = "播放音效"

-- TextInput.lua
L["it can't be empty."] = "不能為空。"
L["It can be %d letters at most."] = "最多只能有 %d 個字元。"
L["Couldn't save %s: %s"] = "無法儲存%s：%s"

-- ActionButton.lua
L["Couldn't %s."] = "無法%s。"

-- ProfileDialog.lua
L["Press Ctrl+C to copy the text below."] = "按 Ctrl+C 複製下方文字。"

-- Profiles.lua
L["\"%s\" is the built-in profile's name."] = "「%s」是內建設定檔的名稱。"
L["A profile named \"%s\" already exists."] = "名為「%s」的設定檔已存在。"
L["Unavailable while editing the layout."] = "編輯版面配置時無法使用。"
L["Active Profile"] = "使用中的設定檔"
L["Use a Profile for This Character"] = "此角色使用專屬設定檔"
L["Switches to a profile named after this character, made the first time."] = "切換至以此角色命名的設定檔，首次使用時自動建立。"
L["New Profile"] = "新增設定檔"
L["New"] = "新增"
L["Create"] = "建立"
L["Name the new profile. It starts with default settings."] = "為新設定檔命名。新設定檔會使用預設設定。"
L["Profile name"] = "設定檔名稱"
L["Profile \"%s\" created."] = "已建立設定檔「%s」。"
L["Copy Current Profile"] = "複製目前設定檔"
L["Copy"] = "複製"
L["Copy Profile"] = "複製設定檔"
L["Name the copy of \"%s\"."] = "為「%s」的複本命名。"
L["Copy of %s"] = "%s的複本"
L["Copied \"%s\" to \"%s\"."] = "已將「%s」複製為「%s」。"
L["Rename Current Profile"] = "重新命名目前設定檔"
L["Rename"] = "重新命名"
L["Rename Profile"] = "重新命名設定檔"
L["Rename \"%s\" to:"] = "將「%s」重新命名為："
L["Renamed \"%s\" to \"%s\"."] = "已將「%s」重新命名為「%s」。"
L["The last profile can't be deleted."] = "無法刪除最後一個設定檔。"
L["Delete Current Profile"] = "刪除目前設定檔"
L["Delete"] = "刪除"
L["Profile \"%s\" deleted; now using \"%s\"."] = "已刪除設定檔「%s」，現在使用「%s」。"
L["Delete Profile"] = "刪除設定檔"
L["Delete the profile \"%s\"? Its settings will be lost. Choose the profile to use instead:"] = "要刪除設定檔「%s」嗎？其設定將會遺失。請選擇改用的設定檔："
L["Delete the profile \"%s\"? Its settings will be lost, and \"%s\" becomes active."] = "要刪除設定檔「%s」嗎？其設定將會遺失，並改用「%s」。"
L["Reset Current Profile"] = "重置目前設定檔"
L["Profile \"%s\" reset."] = "已重置設定檔「%s」。"
L["Reset the profile \"%s\" to default settings?"] = "要將設定檔「%s」重置為預設設定嗎？"
L["Export Current Profile"] = "匯出目前設定檔"
L["Export"] = "匯出"
L["Export Profile"] = "匯出設定檔"
L["Import Profile"] = "匯入設定檔"
L["Import"] = "匯入"
L["Paste a profile string. Importing creates a new profile."] = "貼上設定檔字串。匯入會建立新的設定檔。"
L["Imported \"%s\" as \"%s\"."] = "已將「%s」匯入為「%s」。"
L["Profiles"] = "設定檔"
L["Manage"] = "管理"
L["Share"] = "分享"
