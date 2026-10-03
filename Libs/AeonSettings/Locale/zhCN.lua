if GetLocale() ~= "zhCN" then
	return
end

local L = select(2, ...).AeonSettings.L

-- Control.lua
L["Couldn't save %s."] = "无法保存%s。"

-- PageModel.lua
L["Requires %s to be enabled."] = "需要启用%s。"

-- Window.lua
L["Reset %s to defaults?"] = "将%s重置为默认设置？"
L["Reset"] = "重置"
L["Unavailable in combat."] = "战斗中不可用。"
L["1 change needs a reload"] = "1项更改需要重载界面"
L["%d changes need a reload"] = "%d项更改需要重载界面"
L["%s reset to defaults."] = "%s已重置为默认设置。"
L['Search results for "%s"'] = '“%s”的搜索结果'
L["No settings match."] = "没有匹配的设置。"

-- Row.lua
L["Shared"] = "共享"
L["Custom"] = "自定义"
L["Use Shared"] = "使用共享"
L["Removes this value so the setting follows the shared one again."] = "移除此值，使该设置重新跟随共享设置。"

-- Preview.lua
L["Click an element to find its settings"] = "点击元素以找到对应设置"

-- SoundCheckbox.lua
L["Play sound"] = "播放音效"

-- TextInput.lua
L["it can't be empty."] = "不能为空。"
L["It can be %d letters at most."] = "最多只能有%d个字符。"
L["Couldn't save %s: %s"] = "无法保存%s：%s"

-- ActionButton.lua
L["Couldn't %s."] = "无法%s。"

-- ProfileDialog.lua
L["Press Ctrl+C to copy the text below."] = "按Ctrl+C复制下方文本。"

-- Profiles.lua
L["\"%s\" is the built-in profile's name."] = "“%s”是内置配置文件的名称。"
L["A profile named \"%s\" already exists."] = "名为“%s”的配置文件已存在。"
L["Unavailable while editing the layout."] = "编辑布局时不可用。"
L["Active Profile"] = "当前配置文件"
L["Use a Profile for This Character"] = "为此角色使用配置文件"
L["Switches to a profile named after this character, made the first time."] = "切换到以此角色命名的配置文件，首次使用时自动创建。"
L["New Profile"] = "新建配置文件"
L["New"] = "新建"
L["Create"] = "创建"
L["Name the new profile. It starts with default settings."] = "为新配置文件命名。它将使用默认设置。"
L["Profile name"] = "配置文件名称"
L["Profile \"%s\" created."] = "已创建配置文件“%s”。"
L["Copy Current Profile"] = "复制当前配置文件"
L["Copy"] = "复制"
L["Copy Profile"] = "复制配置文件"
L["Name the copy of \"%s\"."] = "为“%s”的副本命名。"
L["Copy of %s"] = "%s的副本"
L["Copied \"%s\" to \"%s\"."] = "已将“%s”复制为“%s”。"
L["Rename Current Profile"] = "重命名当前配置文件"
L["Rename"] = "重命名"
L["Rename Profile"] = "重命名配置文件"
L["Rename \"%s\" to:"] = "将“%s”重命名为："
L["Renamed \"%s\" to \"%s\"."] = "已将“%s”重命名为“%s”。"
L["The last profile can't be deleted."] = "无法删除最后一个配置文件。"
L["Delete Current Profile"] = "删除当前配置文件"
L["Delete"] = "删除"
L["Profile \"%s\" deleted; now using \"%s\"."] = "已删除配置文件“%s”；现在使用“%s”。"
L["Delete Profile"] = "删除配置文件"
L["Delete the profile \"%s\"? Its settings will be lost. Choose the profile to use instead:"] = "删除配置文件“%s”？其设置将会丢失。请选择改用的配置文件："
L["Delete the profile \"%s\"? Its settings will be lost, and \"%s\" becomes active."] = "删除配置文件“%s”？其设置将会丢失，并将启用“%s”。"
L["Reset Current Profile"] = "重置当前配置文件"
L["Profile \"%s\" reset."] = "已重置配置文件“%s”。"
L["Reset the profile \"%s\" to default settings?"] = "将配置文件“%s”重置为默认设置？"
L["Export Current Profile"] = "导出当前配置文件"
L["Export"] = "导出"
L["Export Profile"] = "导出配置文件"
L["Import Profile"] = "导入配置文件"
L["Import"] = "导入"
L["Paste a profile string. Importing creates a new profile."] = "粘贴配置字符串。导入将创建新的配置文件。"
L["Imported \"%s\" as \"%s\"."] = "已将“%s”导入为“%s”。"
L["Profiles"] = "配置文件"
L["Manage"] = "管理"
L["Share"] = "分享"
