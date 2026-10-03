if GetLocale() ~= "deDE" then
	return
end

local L = select(2, ...).AeonSettings.L

-- Control.lua
L["Couldn't save %s."] = "%s konnte nicht gespeichert werden."

-- PageModel.lua
L["Requires %s to be enabled."] = "Erfordert aktivierte Option „%s“."

-- Window.lua
L["Reset %s to defaults?"] = "%s auf Standard zurücksetzen?"
L["Reset"] = "Zurücksetzen"
L["Unavailable in combat."] = "Im Kampf nicht verfügbar."
L["1 change needs a reload"] = "1 Änderung erfordert ein Neuladen"
L["%d changes need a reload"] = "%d Änderungen erfordern ein Neuladen"
L["%s reset to defaults."] = "%s auf Standard zurückgesetzt."
L['Search results for "%s"'] = 'Suchergebnisse für "%s"'
L["No settings match."] = "Keine passenden Einstellungen."

-- Row.lua
L["Shared"] = "Geteilt"
L["Custom"] = "Eigener Wert"
L["Use Shared"] = "Geteilten Wert verwenden"
L["Removes this value so the setting follows the shared one again."] = "Entfernt diesen Wert, damit die Einstellung wieder dem geteilten Wert folgt."

-- Preview.lua
L["Click an element to find its settings"] = "Klicke auf ein Element, um seine Einstellungen zu finden"

-- SoundCheckbox.lua
L["Play sound"] = "Klang abspielen"

-- TextInput.lua
L["it can't be empty."] = "es darf nicht leer sein."
L["It can be %d letters at most."] = "Es darf höchstens %d Zeichen lang sein."
L["Couldn't save %s: %s"] = "%s konnte nicht gespeichert werden: %s"

-- ActionButton.lua
L["Couldn't %s."] = "Konnte nicht %s."

-- ProfileDialog.lua
L["Press Ctrl+C to copy the text below."] = "Drücke Strg+C, um den Text unten zu kopieren."

-- Profiles.lua
L["\"%s\" is the built-in profile's name."] = "\"%s\" ist der Name des integrierten Profils."
L["A profile named \"%s\" already exists."] = "Ein Profil namens \"%s\" existiert bereits."
L["Unavailable while editing the layout."] = "Während der Layoutbearbeitung nicht verfügbar."
L["Active Profile"] = "Aktives Profil"
L["Use a Profile for This Character"] = "Profil für diesen Charakter verwenden"
L["Switches to a profile named after this character, made the first time."] = "Wechselt zu einem nach diesem Charakter benannten Profil, das beim ersten Mal erstellt wird."
L["New Profile"] = "Neues Profil"
L["New"] = "Neu"
L["Create"] = "Erstellen"
L["Name the new profile. It starts with default settings."] = "Benenne das neue Profil. Es beginnt mit den Standardeinstellungen."
L["Profile name"] = "Profilname"
L["Profile \"%s\" created."] = "Profil \"%s\" erstellt."
L["Copy Current Profile"] = "Aktuelles Profil kopieren"
L["Copy"] = "Kopieren"
L["Copy Profile"] = "Profil kopieren"
L["Name the copy of \"%s\"."] = "Benenne die Kopie von \"%s\"."
L["Copy of %s"] = "Kopie von %s"
L["Copied \"%s\" to \"%s\"."] = "\"%s\" nach \"%s\" kopiert."
L["Rename Current Profile"] = "Aktuelles Profil umbenennen"
L["Rename"] = "Umbenennen"
L["Rename Profile"] = "Profil umbenennen"
L["Rename \"%s\" to:"] = "\"%s\" umbenennen in:"
L["Renamed \"%s\" to \"%s\"."] = "\"%s\" in \"%s\" umbenannt."
L["The last profile can't be deleted."] = "Das letzte Profil kann nicht gelöscht werden."
L["Delete Current Profile"] = "Aktuelles Profil löschen"
L["Delete"] = "Löschen"
L["Profile \"%s\" deleted; now using \"%s\"."] = "Profil \"%s\" gelöscht; jetzt wird \"%s\" verwendet."
L["Delete Profile"] = "Profil löschen"
L["Delete the profile \"%s\"? Its settings will be lost. Choose the profile to use instead:"] = "Das Profil \"%s\" löschen? Seine Einstellungen gehen verloren. Wähle das Profil, das stattdessen verwendet werden soll:"
L["Delete the profile \"%s\"? Its settings will be lost, and \"%s\" becomes active."] = "Das Profil \"%s\" löschen? Seine Einstellungen gehen verloren und \"%s\" wird aktiv."
L["Reset Current Profile"] = "Aktuelles Profil zurücksetzen"
L["Profile \"%s\" reset."] = "Profil \"%s\" zurückgesetzt."
L["Reset the profile \"%s\" to default settings?"] = "Das Profil \"%s\" auf die Standardeinstellungen zurücksetzen?"
L["Export Current Profile"] = "Aktuelles Profil exportieren"
L["Export"] = "Exportieren"
L["Export Profile"] = "Profil exportieren"
L["Import Profile"] = "Profil importieren"
L["Import"] = "Importieren"
L["Paste a profile string. Importing creates a new profile."] = "Füge einen Profilstring ein. Beim Importieren wird ein neues Profil erstellt."
L["Imported \"%s\" as \"%s\"."] = "\"%s\" als \"%s\" importiert."
L["Profiles"] = "Profile"
L["Manage"] = "Verwalten"
L["Share"] = "Teilen"
