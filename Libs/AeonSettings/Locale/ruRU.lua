if GetLocale() ~= "ruRU" then
	return
end

local L = select(2, ...).AeonSettings.L

-- Control.lua
L["Couldn't save %s."] = "Не удалось сохранить «%s»."

-- PageModel.lua
L["Requires %s to be enabled."] = "Требуется включить «%s»."

-- Window.lua
L["Reset %s to defaults?"] = "Восстановить для «%s» значения по умолчанию?"
L["Reset"] = "Сбросить"
L["Jump to section"] = "Перейти к разделу"
L["%s (collapsed)"] = "%s (свернуто)"
L["Unavailable in combat."] = "Недоступно в бою."
L["1 change needs a reload"] = "1 изменение требует перезагрузки"
L["%d changes need a reload"] = "Изменений, требующих перезагрузки: %d"
L["%s reset to defaults."] = "«%s»: восстановлены значения по умолчанию."
L['Search results for "%s"'] = 'Результаты поиска по запросу «%s»'
L["No settings match."] = "Подходящих настроек нет."

-- Preview.lua
L["Preview"] = "Предпросмотр"
L["Click part of the preview to find its setting"] = "Щелкните часть предпросмотра, чтобы найти ее настройку"

-- SoundCheckbox.lua
L["Play sound"] = "Воспроизводить звук"

-- TextInput.lua
L["it can't be empty."] = "значение не может быть пустым."
L["It can be %d letters at most."] = "Допустимо не более %d символов."
L["Couldn't save %s: %s"] = "Не удалось сохранить «%s»: %s"

-- ActionButton.lua
L["Couldn't %s."] = "Не удалось: %s."

-- ProfileDialog.lua
L["Press Ctrl+C to copy the text below."] = "Нажмите Ctrl+C, чтобы скопировать текст ниже."

-- Profiles.lua
L["\"%s\" is the built-in profile's name."] = "«%s» — имя встроенного профиля."
L["A profile named \"%s\" already exists."] = "Профиль «%s» уже существует."
L["Unavailable while editing the layout."] = "Недоступно во время редактирования расположения."
L["Active Profile"] = "Активный профиль"
L["Use a Profile for This Character"] = "Отдельный профиль для персонажа"
L["Switches to a profile named after this character, made the first time."] = "Переключает на профиль с именем этого персонажа; при первом включении он создается."
L["New Profile"] = "Новый профиль"
L["New"] = "Новый"
L["Create"] = "Создать"
L["Name the new profile. It starts with default settings."] = "Введите имя нового профиля. Он создается с настройками по умолчанию."
L["Profile name"] = "Имя профиля"
L["Profile \"%s\" created."] = "Профиль «%s» создан."
L["Copy Current Profile"] = "Копировать текущий профиль"
L["Copy"] = "Копировать"
L["Copy Profile"] = "Копирование профиля"
L["Name the copy of \"%s\"."] = "Введите имя копии профиля «%s»."
L["Copy of %s"] = "Копия %s"
L["Copied \"%s\" to \"%s\"."] = "Профиль «%s» скопирован в «%s»."
L["Rename Current Profile"] = "Переименовать текущий профиль"
L["Rename"] = "Переименовать"
L["Rename Profile"] = "Переименование профиля"
L["Rename \"%s\" to:"] = "Новое имя для «%s»:"
L["Renamed \"%s\" to \"%s\"."] = "Профиль «%s» переименован в «%s»."
L["The last profile can't be deleted."] = "Последний профиль нельзя удалить."
L["Delete Current Profile"] = "Удалить текущий профиль"
L["Delete"] = "Удалить"
L["Profile \"%s\" deleted; now using \"%s\"."] = "Профиль «%s» удален; теперь используется «%s»."
L["Delete Profile"] = "Удаление профиля"
L["Delete the profile \"%s\"? Its settings will be lost. Choose the profile to use instead:"] = "Удалить профиль «%s»? Его настройки будут потеряны. Выберите профиль, который будет использоваться вместо него:"
L["Delete the profile \"%s\"? Its settings will be lost, and \"%s\" becomes active."] = "Удалить профиль «%s»? Его настройки будут потеряны, а активным станет «%s»."
L["Reset Current Profile"] = "Сбросить текущий профиль"
L["Profile \"%s\" reset."] = "Профиль «%s» сброшен."
L["Reset the profile \"%s\" to default settings?"] = "Сбросить профиль «%s» до настроек по умолчанию?"
L["Export Current Profile"] = "Экспорт текущего профиля"
L["Export"] = "Экспорт"
L["Export Profile"] = "Экспорт профиля"
L["Import Profile"] = "Импорт профиля"
L["Import"] = "Импорт"
L["Paste a profile string. Importing creates a new profile."] = "Вставьте строку профиля. При импорте создается новый профиль."
L["Imported \"%s\" as \"%s\"."] = "«%s» импортирован как «%s»."
L["Profiles"] = "Профили"
L["Manage"] = "Управление"
L["Share"] = "Обмен"
