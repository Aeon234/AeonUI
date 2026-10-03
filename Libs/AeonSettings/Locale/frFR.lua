if GetLocale() ~= "frFR" then
	return
end

local L = select(2, ...).AeonSettings.L

-- Control.lua
L["Couldn't save %s."] = "Impossible d'enregistrer %s."

-- PageModel.lua
L["Requires %s to be enabled."] = "Nécessite d'activer %s."

-- Window.lua
L["Reset %s to defaults?"] = "Réinitialiser %s aux valeurs par défaut ?"
L["Reset"] = "Réinitialiser"
L["Unavailable in combat."] = "Indisponible en combat."
L["1 change needs a reload"] = "1 modification nécessite un rechargement"
L["%d changes need a reload"] = "%d modifications nécessitent un rechargement"
L["%s reset to defaults."] = "%s : valeurs par défaut rétablies."
L['Search results for "%s"'] = 'Résultats de recherche pour "%s"'
L["No settings match."] = "Aucun réglage ne correspond."

-- Row.lua
L["Shared"] = "Partagé"
L["Custom"] = "Personnalisé"
L["Use Shared"] = "Utiliser le partagé"
L["Removes this value so the setting follows the shared one again."] = "Supprime cette valeur pour que le réglage suive de nouveau la valeur partagée."

-- Preview.lua
L["Click an element to find its settings"] = "Cliquez sur un élément pour trouver ses réglages"

-- SoundCheckbox.lua
L["Play sound"] = "Jouer un son"

-- TextInput.lua
L["it can't be empty."] = "la valeur ne peut pas être vide."
L["It can be %d letters at most."] = "%d caractères au maximum."
L["Couldn't save %s: %s"] = "Impossible d'enregistrer %s : %s"

-- ActionButton.lua
L["Couldn't %s."] = "Impossible de %s."

-- ProfileDialog.lua
L["Press Ctrl+C to copy the text below."] = "Appuyez sur Ctrl+C pour copier le texte ci-dessous."

-- Profiles.lua
L["\"%s\" is the built-in profile's name."] = "\"%s\" est le nom du profil intégré."
L["A profile named \"%s\" already exists."] = "Un profil nommé \"%s\" existe déjà."
L["Unavailable while editing the layout."] = "Indisponible pendant la modification de la disposition."
L["Active Profile"] = "Profil actif"
L["Use a Profile for This Character"] = "Profil propre à ce personnage"
L["Switches to a profile named after this character, made the first time."] = "Passe à un profil portant le nom de ce personnage, créé la première fois."
L["New Profile"] = "Nouveau profil"
L["New"] = "Nouveau"
L["Create"] = "Créer"
L["Name the new profile. It starts with default settings."] = "Nommez le nouveau profil. Il commence avec les réglages par défaut."
L["Profile name"] = "Nom du profil"
L["Profile \"%s\" created."] = "Profil \"%s\" créé."
L["Copy Current Profile"] = "Copier le profil actuel"
L["Copy"] = "Copier"
L["Copy Profile"] = "Copier le profil"
L["Name the copy of \"%s\"."] = "Nommez la copie de \"%s\"."
L["Copy of %s"] = "Copie de %s"
L["Copied \"%s\" to \"%s\"."] = "\"%s\" copié vers \"%s\"."
L["Rename Current Profile"] = "Renommer le profil actuel"
L["Rename"] = "Renommer"
L["Rename Profile"] = "Renommer le profil"
L["Rename \"%s\" to:"] = "Renommer \"%s\" en :"
L["Renamed \"%s\" to \"%s\"."] = "\"%s\" renommé en \"%s\"."
L["The last profile can't be deleted."] = "Le dernier profil ne peut pas être supprimé."
L["Delete Current Profile"] = "Supprimer le profil actuel"
L["Delete"] = "Supprimer"
L["Profile \"%s\" deleted; now using \"%s\"."] = "Profil \"%s\" supprimé ; \"%s\" est maintenant utilisé."
L["Delete Profile"] = "Supprimer le profil"
L["Delete the profile \"%s\"? Its settings will be lost. Choose the profile to use instead:"] = "Supprimer le profil \"%s\" ? Ses réglages seront perdus. Choisissez le profil à utiliser à la place :"
L["Delete the profile \"%s\"? Its settings will be lost, and \"%s\" becomes active."] = "Supprimer le profil \"%s\" ? Ses réglages seront perdus et \"%s\" deviendra actif."
L["Reset Current Profile"] = "Réinitialiser le profil actuel"
L["Profile \"%s\" reset."] = "Profil \"%s\" réinitialisé."
L["Reset the profile \"%s\" to default settings?"] = "Réinitialiser le profil \"%s\" aux réglages par défaut ?"
L["Export Current Profile"] = "Exporter le profil actuel"
L["Export"] = "Exporter"
L["Export Profile"] = "Exporter le profil"
L["Import Profile"] = "Importer un profil"
L["Import"] = "Importer"
L["Paste a profile string. Importing creates a new profile."] = "Collez une chaîne de profil. L'importation crée un nouveau profil."
L["Imported \"%s\" as \"%s\"."] = "\"%s\" importé sous le nom \"%s\"."
L["Profiles"] = "Profils"
L["Manage"] = "Gérer"
L["Share"] = "Partager"
