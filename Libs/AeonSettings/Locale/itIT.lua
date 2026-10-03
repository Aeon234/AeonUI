if GetLocale() ~= "itIT" then
	return
end

local L = select(2, ...).AeonSettings.L

-- Control.lua
L["Couldn't save %s."] = "Impossibile salvare %s."

-- PageModel.lua
L["Requires %s to be enabled."] = "Richiede che %s sia attivo."

-- Window.lua
L["Reset %s to defaults?"] = "Ripristinare i valori predefiniti di %s?"
L["Reset"] = "Ripristina"
L["Unavailable in combat."] = "Non disponibile in combattimento."
L["1 change needs a reload"] = "1 modifica richiede di ricaricare"
L["%d changes need a reload"] = "%d modifiche richiedono di ricaricare"
L["%s reset to defaults."] = "%s: ripristinati i valori predefiniti."
L['Search results for "%s"'] = 'Risultati della ricerca per "%s"'
L["No settings match."] = "Nessuna impostazione corrispondente."

-- Row.lua
L["Shared"] = "Condiviso"
L["Custom"] = "Personalizzato"
L["Use Shared"] = "Usa condiviso"
L["Removes this value so the setting follows the shared one again."] = "Rimuove questo valore così l'impostazione torna a seguire quella condivisa."

-- Preview.lua
L["Click an element to find its settings"] = "Clicca un elemento per trovarne le impostazioni"

-- SoundCheckbox.lua
L["Play sound"] = "Riproduci suono"

-- TextInput.lua
L["it can't be empty."] = "non può essere vuoto."
L["It can be %d letters at most."] = "Può contenere al massimo %d caratteri."
L["Couldn't save %s: %s"] = "Impossibile salvare %s: %s"

-- ActionButton.lua
L["Couldn't %s."] = "Impossibile %s."

-- ProfileDialog.lua
L["Press Ctrl+C to copy the text below."] = "Premi Ctrl+C per copiare il testo qui sotto."

-- Profiles.lua
L["\"%s\" is the built-in profile's name."] = "\"%s\" è il nome del profilo integrato."
L["A profile named \"%s\" already exists."] = "Esiste già un profilo chiamato \"%s\"."
L["Unavailable while editing the layout."] = "Non disponibile durante la modifica del layout."
L["Active Profile"] = "Profilo attivo"
L["Use a Profile for This Character"] = "Usa un profilo per questo personaggio"
L["Switches to a profile named after this character, made the first time."] = "Passa a un profilo con il nome di questo personaggio, creato la prima volta."
L["New Profile"] = "Nuovo profilo"
L["New"] = "Nuovo"
L["Create"] = "Crea"
L["Name the new profile. It starts with default settings."] = "Dai un nome al nuovo profilo. Parte con le impostazioni predefinite."
L["Profile name"] = "Nome del profilo"
L["Profile \"%s\" created."] = "Profilo \"%s\" creato."
L["Copy Current Profile"] = "Copia profilo attuale"
L["Copy"] = "Copia"
L["Copy Profile"] = "Copia profilo"
L["Name the copy of \"%s\"."] = "Dai un nome alla copia di \"%s\"."
L["Copy of %s"] = "Copia di %s"
L["Copied \"%s\" to \"%s\"."] = "\"%s\" copiato in \"%s\"."
L["Rename Current Profile"] = "Rinomina profilo attuale"
L["Rename"] = "Rinomina"
L["Rename Profile"] = "Rinomina profilo"
L["Rename \"%s\" to:"] = "Rinomina \"%s\" in:"
L["Renamed \"%s\" to \"%s\"."] = "\"%s\" rinominato in \"%s\"."
L["The last profile can't be deleted."] = "L'ultimo profilo non può essere eliminato."
L["Delete Current Profile"] = "Elimina profilo attuale"
L["Delete"] = "Elimina"
L["Profile \"%s\" deleted; now using \"%s\"."] = "Profilo \"%s\" eliminato; ora è in uso \"%s\"."
L["Delete Profile"] = "Elimina profilo"
L["Delete the profile \"%s\"? Its settings will be lost. Choose the profile to use instead:"] = "Eliminare il profilo \"%s\"? Le sue impostazioni andranno perse. Scegli il profilo da usare al suo posto:"
L["Delete the profile \"%s\"? Its settings will be lost, and \"%s\" becomes active."] = "Eliminare il profilo \"%s\"? Le sue impostazioni andranno perse e \"%s\" diventerà attivo."
L["Reset Current Profile"] = "Ripristina profilo attuale"
L["Profile \"%s\" reset."] = "Profilo \"%s\" ripristinato."
L["Reset the profile \"%s\" to default settings?"] = "Ripristinare le impostazioni predefinite del profilo \"%s\"?"
L["Export Current Profile"] = "Esporta profilo attuale"
L["Export"] = "Esporta"
L["Export Profile"] = "Esporta profilo"
L["Import Profile"] = "Importa profilo"
L["Import"] = "Importa"
L["Paste a profile string. Importing creates a new profile."] = "Incolla una stringa di profilo. L'importazione crea un nuovo profilo."
L["Imported \"%s\" as \"%s\"."] = "\"%s\" importato come \"%s\"."
L["Profiles"] = "Profili"
L["Manage"] = "Gestisci"
L["Share"] = "Condividi"
