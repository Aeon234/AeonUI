if GetLocale() ~= "ruRU" then
	return
end

local L = select(2, ...).L

-- Chat messages (Core)
L["AeonUI is off for this session, so its settings can't open."] = "AeonUI отключен на этот сеанс, поэтому его настройки нельзя открыть."
L["your character could not be identified, so AeonUI is off for this session."] = "не удалось определить вашего персонажа, поэтому AeonUI отключен на этот сеанс."
L["saved settings failed to load, so AeonUI is off for this session."] = "не удалось загрузить сохраненные настройки, поэтому AeonUI отключен на этот сеанс."
L["saved settings come from a newer version of AeonUI, so this version is using default settings and leaves them unchanged."] = "сохраненные настройки созданы более новой версией AeonUI, поэтому эта версия использует настройки по умолчанию и не изменяет их."
L["saved settings are damaged, so AeonUI is using default settings and leaves them unchanged until you reset them."] = "сохраненные настройки повреждены, поэтому AeonUI использует настройки по умолчанию и не изменяет их, пока вы их не сбросите."
L["the active profile can't be used, so AeonUI is showing default settings until you choose another profile."] = "активный профиль нельзя использовать, поэтому AeonUI показывает настройки по умолчанию, пока вы не выберете другой профиль."

-- Profile names (Profile)
L["A profile needs a name."] = "Профилю нужно название."
L["A profile name can be %d letters at most."] = "Название профиля может содержать не более %d букв."
L["That name belongs to the default profile."] = "Это название принадлежит профилю по умолчанию."
L["A profile with that name already exists."] = "Профиль с таким названием уже существует."

-- Profile strings (Profile)
L["This is not an AeonUI profile string, or it was cut short."] = "Это не строка профиля AeonUI, или она обрезана."
L["This profile string was made by a newer version of AeonUI."] = "Эта строка профиля создана более новой версией AeonUI."
L["This profile string holds settings AeonUI can't use."] = "Эта строка профиля содержит настройки, которые AeonUI не может использовать."

-- Minimap button tooltip (Core)
L["Left-click: open settings"] = "Левый клик: открыть настройки"
L["Right-click: open edit mode"] = "Правый клик: открыть режим редактирования"

-- Key bindings (Core)
L["Eject All Passengers"] = "Высадить всех пассажиров"

-- Page titles (Settings)
L["Profiles"] = "Профили"
L["Recovery"] = "Восстановление"
L["Unit Frames"] = "Рамки юнитов"
L["Maps"] = "Карты"
L["Quality of Life"] = "Удобство"

-- Shared settings labels (Settings)
L["Auctionator, TSM or Oribos Exchange provides auction prices."] = "Цены аукциона берутся из Auctionator, TSM или Oribos Exchange."
L["Access"] = "Доступ"
L["Text"] = "Текст"
L["Open"] = "Открыть"
L["Font"] = "Шрифт"
L["Outline"] = "Контур"
L["Font Scale"] = "Масштаб шрифта"
L["Height"] = "Высота"
L["X Offset"] = "Смещение по X"
L["Y Offset"] = "Смещение по Y"
L["Scale"] = "Масштаб"
L["Crafting Orders"] = "Заказы на изготовление"
L["Modifier"] = "Клавиша-модификатор"
L["Visibility"] = "Видимость"
L["Show"] = "Показать"
L["Size"] = "Размер"
L["Border"] = "Рамка"
L["Border Style"] = "Стиль рамки"
L["Forever Minimal"] = "Forever Minimal"
L["Forever"] = "Forever"
L["Slate"] = "Сланец"
L["Thin Line"] = "Тонкая линия"
L["Border Color"] = "Цвет рамки"
L["Needs a border style."] = "Требуется стиль рамки."
L["Forever keeps its own colors."] = "Forever сохраняет собственные цвета."
L["Border Thickness"] = "Толщина рамки"
L["Casting"] = "Произнесение"
L["Class Color"] = "Цвет класса"
L["Texture"] = "Текстура"
L["Horizontal"] = "Горизонтально"
L["Vertical"] = "Вертикально"
L["Left"] = "Слева"
L["Right"] = "Справа"
L["Bar"] = "Панель"
L["Tooltip"] = "Подсказка"
L["Blizzard"] = "Blizzard"
L["Square"] = "Квадрат"
L["White"] = "Белый"
L["Width"] = "Ширина"
L["Food"] = "Еда"
L["A"] = "A"
L["Layout"] = "Расположение"

-- General page (Settings)
L["Show Minimap Button"] = "Показывать кнопку у миникарты"
L["Left-click opens settings. Right-click opens edit mode."] = "Левый клик открывает настройки. Правый клик открывает режим редактирования."
L["Goes below the game's own minimum. Turning it off needs a reload."] = "Ниже минимума игры. Чтобы выключить, нужна перезагрузка интерфейса."
L["%s manages the UI scale."] = "Масштабом интерфейса управляет %s."
L["Pixel Perfect"] = "Попиксельно"
L["One interface unit per pixel on this screen."] = "Одна единица интерфейса на пиксель этого экрана."
L["Pixel Perfect For"] = "Попиксельно для"
L["Game Menu Scale"] = "Масштаб игрового меню"

-- Shared by the world map marker tooltips (World Map) and the Delete Cheapest Item rows (DeleteCheapestItem)
L["Vendor"] = "Торговец"

-- Shared by the Delete Cheapest Item rows (DeleteCheapestItem) and the item tooltips' auction price line on a
-- client without realms (Tooltip)
L["Auction"] = "Аукцион"

-- Profiles page (Settings)
L["AeonUI profile \"%s\"."] = "Профиль AeonUI «%s»."
L["It holds %d settings this version doesn't use; they are kept."] = "В нем %d настроек, которые эта версия не использует; они сохраняются."
L["Damaged Profiles"] = "Поврежденные профили"
L["The active profile can't be used, so default settings are shown. Choose another profile or delete it."] = "Активный профиль нельзя использовать, поэтому показаны настройки по умолчанию. Выберите другой профиль или удалите этот."
L["These profiles can't be used. They are kept unchanged until you delete them."] = "Эти профили нельзя использовать. Они хранятся без изменений, пока вы их не удалите."
L["Delete the damaged profile \"%s\"? Characters using it switch to another profile."] = "Удалить поврежденный профиль «%s»? Персонажи, использующие его, перейдут на другой профиль."
L["Create another profile first."] = "Сначала создайте другой профиль."

-- Recovery page (Settings)
L["AeonUI's saved settings can't be used, so its other pages are unavailable."] = "Сохраненные настройки AeonUI нельзя использовать, поэтому другие его страницы недоступны."
L["Saved Settings"] = "Сохраненные настройки"
L["Your saved settings are damaged. AeonUI shows default settings and leaves them unchanged until you reset them."] = "Ваши сохраненные настройки повреждены. AeonUI показывает настройки по умолчанию и не изменяет их, пока вы их не сбросите."
L["Your saved settings come from a newer version of AeonUI. This version shows default settings and leaves them unchanged."] = "Ваши сохраненные настройки созданы более новой версией AeonUI. Эта версия показывает настройки по умолчанию и не изменяет их."
L["Diagnostic Export"] = "Диагностический экспорт"
L["Diagnostic Export (Incomplete)"] = "Диагностический экспорт (неполный)"
L["The saved settings as text, to keep or to share when reporting the problem. It is not a profile string."] = "Сохраненные настройки в виде текста, чтобы сохранить или приложить к сообщению о проблеме. Это не строка профиля."
L["Reset Saved Settings"] = "Сбросить сохраненные настройки"
L["Erase every AeonUI profile and setting on this account and start again with defaults."] = "Стереть все профили и настройки AeonUI на этой учетной записи и начать заново с настройками по умолчанию."
L["Erase every AeonUI profile and setting on this account? This cannot be undone."] = "Стереть все профили и настройки AeonUI на этой учетной записи? Это действие нельзя отменить."
L["Type %s to erase every AeonUI profile and setting on this account."] = "Введите %s, чтобы стереть все профили и настройки AeonUI на этой учетной записи."

-- Shared by the world map and other features
L["Azuregos"] = "Азурегос"
L["Dungeon"] = "Подземелье"
L["Raid"] = "Рейд"
L["Innkeeper"] = "Хозяин таверны"
L["Mailbox"] = "Почтовый ящик"
L["Banker"] = "Банкир"
L["Auctioneer"] = "Аукционист"
L["Reagents"] = "Реагенты"
L["Ammunition"] = "Боеприпасы"
