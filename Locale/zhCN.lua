if GetLocale() ~= "zhCN" then
	return
end

local L = select(2, ...).L

-- Chat messages (Core)
L["AeonUI is off for this session, so its settings can't open."] = "AeonUI 在本次会话中已关闭，因此无法打开其设置。"
L["your character could not be identified, so AeonUI is off for this session."] = "无法识别你的角色，因此 AeonUI 在本次会话中已关闭。"
L["saved settings failed to load, so AeonUI is off for this session."] = "已保存的设置加载失败，因此 AeonUI 在本次会话中已关闭。"
L["saved settings come from a newer version of AeonUI, so this version is using default settings and leaves them unchanged."] = "已保存的设置来自更新版本的 AeonUI，因此当前版本使用默认设置，并保持原设置不变。"
L["saved settings are damaged, so AeonUI is using default settings and leaves them unchanged until you reset them."] = "已保存的设置已损坏，因此 AeonUI 使用默认设置，并在你重置之前保持原设置不变。"
L["the active profile can't be used, so AeonUI is showing default settings until you choose another profile."] = "当前配置文件无法使用，因此 AeonUI 显示默认设置，直到你选择其他配置文件。"

-- Profile names (Profile)
L["A profile needs a name."] = "配置文件需要一个名称。"
L["A profile name can be %d letters at most."] = "配置文件名称最多 %d 个字符。"
L["That name belongs to the default profile."] = "该名称属于默认配置文件。"
L["A profile with that name already exists."] = "已存在同名的配置文件。"

-- Profile strings (Profile)
L["This is not an AeonUI profile string, or it was cut short."] = "这不是 AeonUI 配置文件字符串，或者内容不完整。"
L["This profile string was made by a newer version of AeonUI."] = "此配置文件字符串由更新版本的 AeonUI 生成。"
L["This profile string holds settings AeonUI can't use."] = "此配置文件字符串包含 AeonUI 无法使用的设置。"

-- Minimap button tooltip (Core)
L["Click: open settings"] = "点击：打开设置"

-- Key bindings (Core)
L["Eject All Passengers"] = "弹出所有乘客"

-- Page titles (Settings)
L["Profiles"] = "配置文件"
L["Recovery"] = "恢复"
L["Unit Frames"] = "单位框架"
L["Maps"] = "地图"
L["Quality of Life"] = "便利功能"

-- Shared settings labels (Settings)
L["Auctionator, TSM or Oribos Exchange provides auction prices."] = "拍卖价格由 Auctionator、TSM 或 Oribos Exchange 提供。"
L["Access"] = "访问"
L["Text"] = "文字"
L["Open"] = "打开"
L["Font"] = "字体"
L["Outline"] = "描边"
L["Font Scale"] = "字体缩放"
L["Height"] = "高度"
L["X Offset"] = "X偏移"
L["Y Offset"] = "Y 偏移"
L["Scale"] = "缩放比例"
L["Crafting Orders"] = "制造订单"
L["Modifier"] = "修饰键"
L["Visibility"] = "显示"
L["Show"] = "显示"
L["Size"] = "大小"
L["Border"] = "边框"
L["Border Style"] = "边框样式"
L["Forever Minimal"] = "Forever Minimal"
L["Forever"] = "Forever"
L["Slate"] = "石板"
L["Thin Line"] = "细线"
L["Border Color"] = "边框颜色"
L["Needs a border style."] = "需要边框样式。"
L["Forever keeps its own colors."] = "Forever 保留其自身的颜色。"
L["Border Thickness"] = "边框粗细"
L["Casting"] = "施法中"
L["Class Color"] = "职业颜色"
L["Texture"] = "材质"
L["Horizontal"] = "水平"
L["Vertical"] = "垂直"
L["Left"] = "左侧"
L["Right"] = "右侧"
L["Bar"] = "动作条"
L["Tooltip"] = "鼠标提示"
L["Blizzard"] = "暴雪"
L["Square"] = "方形"
L["White"] = "白色"
L["Width"] = "宽度"
L["Food"] = "食物"
L["A"] = "A"
L["Layout"] = "布局"

-- General page (Settings)
L["Show Minimap Button"] = "显示小地图按钮"
L["Left-click opens settings."] = "左键点击打开设置。"
L["Goes below the game's own minimum. Turning it off needs a reload."] = "可低于游戏的最小值。关闭后需要重载界面。"
L["%s manages the UI scale."] = "%s 正在管理界面缩放。"
L["Pixel Perfect"] = "像素完美"
L["One interface unit per pixel on this screen."] = "在此屏幕上一个界面单位对应一个像素。"
L["Pixel Perfect For"] = "像素完美：分辨率"
L["Game Menu Scale"] = "游戏菜单缩放"

-- Shared by the world map marker tooltips (World Map) and the Delete Cheapest Item rows (DeleteCheapestItem)
L["Vendor"] = "商人"

-- Shared by the Delete Cheapest Item rows (DeleteCheapestItem) and the item tooltips' auction price line on a
-- client without realms (Tooltip)
L["Auction"] = "拍卖"

-- Profiles page (Settings)
L["AeonUI profile \"%s\"."] = "AeonUI 配置文件“%s”。"
L["It holds %d settings this version doesn't use; they are kept."] = "其中包含 %d 项当前版本不使用的设置；这些设置会被保留。"
L["Damaged Profiles"] = "已损坏的配置文件"
L["The active profile can't be used, so default settings are shown. Choose another profile or delete it."] = "当前配置文件无法使用，因此显示默认设置。请选择其他配置文件或将其删除。"
L["These profiles can't be used. They are kept unchanged until you delete them."] = "这些配置文件无法使用。在你删除之前，它们会保持不变。"
L["Delete the damaged profile \"%s\"? Characters using it switch to another profile."] = "删除已损坏的配置文件“%s”？使用它的角色将切换到其他配置文件。"
L["Create another profile first."] = "请先创建另一个配置文件。"

-- Recovery page (Settings)
L["AeonUI's saved settings can't be used, so its other pages are unavailable."] = "AeonUI 已保存的设置无法使用，因此其他页面不可用。"
L["Saved Settings"] = "已保存的设置"
L["Your saved settings are damaged. AeonUI shows default settings and leaves them unchanged until you reset them."] = "你已保存的设置已损坏。AeonUI 显示默认设置，并在你重置之前保持原设置不变。"
L["Your saved settings come from a newer version of AeonUI. This version shows default settings and leaves them unchanged."] = "你已保存的设置来自更新版本的 AeonUI。当前版本显示默认设置，并保持原设置不变。"
L["Diagnostic Export"] = "诊断导出"
L["Diagnostic Export (Incomplete)"] = "诊断导出（不完整）"
L["The saved settings as text, to keep or to share when reporting the problem. It is not a profile string."] = "以文本形式呈现的已保存设置，可留存或在报告问题时分享。它不是配置文件字符串。"
L["Reset Saved Settings"] = "重置已保存的设置"
L["Erase every AeonUI profile and setting on this account and start again with defaults."] = "清除此账号上所有 AeonUI 配置文件和设置，并以默认设置重新开始。"
L["Erase every AeonUI profile and setting on this account? This cannot be undone."] = "清除此账号上所有 AeonUI 配置文件和设置？此操作无法撤销。"
L["Type %s to erase every AeonUI profile and setting on this account."] = "输入 %s 以清除此账号上所有 AeonUI 配置文件和设置。"

-- Shared by the world map and other features
L["Azuregos"] = "艾索雷葛斯"
L["Dungeon"] = "地下城"
L["Raid"] = "团队副本"
L["Innkeeper"] = "旅店老板"
L["Mailbox"] = "邮箱"
L["Banker"] = "银行职员"
L["Auctioneer"] = "拍卖师"
L["Reagents"] = "材料"
L["Ammunition"] = "弹药"
