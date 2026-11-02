if GetLocale() ~= "zhTW" then
	return
end

local L = select(2, ...).L

-- Chat messages (Core)
L["AeonUI is off for this session, so its settings can't open."] = "AeonUI 在本次登入中已關閉，因此無法開啟其設定。"
L["your character could not be identified, so AeonUI is off for this session."] = "無法識別你的角色，因此 AeonUI 在本次登入中已關閉。"
L["saved settings failed to load, so AeonUI is off for this session."] = "已儲存的設定載入失敗，因此 AeonUI 在本次登入中已關閉。"
L["saved settings come from a newer version of AeonUI, so this version is using default settings and leaves them unchanged."] = "已儲存的設定來自較新版本的 AeonUI，因此目前版本使用預設設定，並保留原設定不變。"
L["saved settings are damaged, so AeonUI is using default settings and leaves them unchanged until you reset them."] = "已儲存的設定已損毀，因此 AeonUI 使用預設設定，並在你重置前保留原設定不變。"
L["the active profile can't be used, so AeonUI is showing default settings until you choose another profile."] = "目前的設定檔無法使用，因此 AeonUI 顯示預設設定，直到你選擇其他設定檔。"

-- Profile names (Profile)
L["A profile needs a name."] = "設定檔需要名稱。"
L["A profile name can be %d letters at most."] = "設定檔名稱最多 %d 個字元。"
L["That name belongs to the default profile."] = "此名稱屬於預設設定檔。"
L["A profile with that name already exists."] = "已有同名的設定檔。"

-- Profile strings (Profile)
L["This is not an AeonUI profile string, or it was cut short."] = "這不是 AeonUI 設定檔字串，或內容不完整。"
L["This profile string was made by a newer version of AeonUI."] = "此設定檔字串由較新版本的 AeonUI 產生。"
L["This profile string holds settings AeonUI can't use."] = "此設定檔字串包含 AeonUI 無法使用的設定。"

-- Minimap button tooltip (Core)
L["Click: open settings"] = "點擊：開啟設定"

-- Key bindings (Core)
L["Eject All Passengers"] = "彈出所有乘客"

-- Page titles (Settings)
L["Profiles"] = "設定檔"
L["Recovery"] = "復原"
L["Unit Frames"] = "單位框架"
L["Maps"] = "地圖"
L["Quality of Life"] = "便利功能"

-- Shared settings labels (Settings)
L["Auctionator, TSM or Oribos Exchange provides auction prices."] = "拍賣價格由 Auctionator、TSM 或 Oribos Exchange 提供。"
L["Access"] = "存取"
L["Text"] = "文字"
L["Open"] = "開啟"
L["Font"] = "字型"
L["Outline"] = "外框線"
L["Font Scale"] = "字型縮放"
L["Height"] = "高度"
L["X Offset"] = "X偏移"
L["Y Offset"] = "Y 偏移"
L["Scale"] = "縮放比例"
L["Crafting Orders"] = "製作訂單"
L["Modifier"] = "輔助鍵"
L["Visibility"] = "顯示"
L["Show"] = "顯示"
L["Size"] = "大小"
L["Border"] = "外框"
L["Border Style"] = "外框樣式"
L["Forever Minimal"] = "Forever Minimal"
L["Forever"] = "Forever"
L["Slate"] = "石板"
L["Thin Line"] = "細線"
L["Border Color"] = "外框顏色"
L["Needs a border style."] = "需要外框樣式。"
L["Forever keeps its own colors."] = "Forever 保留其本身的顏色。"
L["Border Thickness"] = "外框粗細"
L["Casting"] = "施法中"
L["Class Color"] = "職業顏色"
L["Texture"] = "材質"
L["Horizontal"] = "水平"
L["Vertical"] = "垂直"
L["Left"] = "左側"
L["Right"] = "右側"
L["Bar"] = "列"
L["Tooltip"] = "滑鼠提示"
L["Blizzard"] = "暴雪"
L["Square"] = "方形"
L["White"] = "白色"
L["Width"] = "寬度"
L["Food"] = "食物"
L["A"] = "A"
L["Layout"] = "版面"

-- General page (Settings)
L["Show Minimap Button"] = "顯示小地圖按鈕"
L["Left-click opens settings."] = "左鍵點擊開啟設定。"
L["Goes below the game's own minimum. Turning it off needs a reload."] = "可低於遊戲的最小值。關閉後需要重新載入介面。"
L["%s manages the UI scale."] = "%s 正在管理介面縮放。"
L["Pixel Perfect"] = "像素完美"
L["One interface unit per pixel on this screen."] = "在此螢幕上一個介面單位對應一個像素。"
L["Pixel Perfect For"] = "像素完美：解析度"
L["Game Menu Scale"] = "遊戲選單縮放"

-- Shared by the world map marker tooltips (World Map) and the Delete Cheapest Item rows (DeleteCheapestItem)
L["Vendor"] = "商人"

-- Shared by the Delete Cheapest Item rows (DeleteCheapestItem) and the item tooltips' auction price line on a
-- client without realms (Tooltip)
L["Auction"] = "拍賣"

-- Profiles page (Settings)
L["AeonUI profile \"%s\"."] = "AeonUI 設定檔「%s」。"
L["It holds %d settings this version doesn't use; they are kept."] = "其中包含 %d 項目前版本不使用的設定；這些設定會被保留。"
L["Damaged Profiles"] = "已損毀的設定檔"
L["The active profile can't be used, so default settings are shown. Choose another profile or delete it."] = "目前的設定檔無法使用，因此顯示預設設定。請選擇其他設定檔或將其刪除。"
L["These profiles can't be used. They are kept unchanged until you delete them."] = "這些設定檔無法使用。在你刪除之前，它們會保持不變。"
L["Delete the damaged profile \"%s\"? Characters using it switch to another profile."] = "刪除已損毀的設定檔「%s」？使用它的角色將切換至其他設定檔。"
L["Create another profile first."] = "請先建立另一個設定檔。"

-- Recovery page (Settings)
L["AeonUI's saved settings can't be used, so its other pages are unavailable."] = "AeonUI 已儲存的設定無法使用，因此其他頁面無法使用。"
L["Saved Settings"] = "已儲存的設定"
L["Your saved settings are damaged. AeonUI shows default settings and leaves them unchanged until you reset them."] = "你已儲存的設定已損毀。AeonUI 顯示預設設定，並在你重置前保留原設定不變。"
L["Your saved settings come from a newer version of AeonUI. This version shows default settings and leaves them unchanged."] = "你已儲存的設定來自較新版本的 AeonUI。目前版本顯示預設設定，並保留原設定不變。"
L["Diagnostic Export"] = "診斷匯出"
L["Diagnostic Export (Incomplete)"] = "診斷匯出（不完整）"
L["The saved settings as text, to keep or to share when reporting the problem. It is not a profile string."] = "以文字形式呈現的已儲存設定，可保留或在回報問題時分享。它不是設定檔字串。"
L["Reset Saved Settings"] = "重置已儲存的設定"
L["Erase every AeonUI profile and setting on this account and start again with defaults."] = "清除此帳號上所有 AeonUI 設定檔與設定，並以預設設定重新開始。"
L["Erase every AeonUI profile and setting on this account? This cannot be undone."] = "清除此帳號上所有 AeonUI 設定檔與設定？此動作無法復原。"
L["Type %s to erase every AeonUI profile and setting on this account."] = "輸入 %s 以清除此帳號上所有 AeonUI 設定檔與設定。"

-- Shared by the world map and other features
L["Azuregos"] = "艾索雷苟斯"
L["Dungeon"] = "地城"
L["Raid"] = "團隊副本"
L["Innkeeper"] = "旅店老闆"
L["Mailbox"] = "郵箱"
L["Banker"] = "銀行職員"
L["Auctioneer"] = "拍賣師"
L["Reagents"] = "材料"
L["Ammunition"] = "彈藥"
