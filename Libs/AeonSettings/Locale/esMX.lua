if GetLocale() ~= "esMX" then
	return
end

local L = select(2, ...).AeonSettings.L

-- Control.lua
L["Couldn't save %s."] = "No se pudo guardar %s."

-- PageModel.lua
L["Requires %s to be enabled."] = "Requiere activar %s."

-- Window.lua
L["Reset %s to defaults?"] = "¿Restablecer %s a los valores predeterminados?"
L["Reset"] = "Restablecer"
L["Unavailable in combat."] = "No disponible en combate."
L["1 change needs a reload"] = "1 cambio requiere recargar"
L["%d changes need a reload"] = "%d cambios requieren recargar"
L["%s reset to defaults."] = "%s se restableció a los valores predeterminados."
L['Search results for "%s"'] = 'Resultados de búsqueda de "%s"'
L["No settings match."] = "Ninguna opción coincide."

-- Row.lua
L["Shared"] = "Compartido"
L["Custom"] = "Personalizado"
L["Use Shared"] = "Usar compartido"
L["Removes this value so the setting follows the shared one again."] = "Elimina este valor para que la opción vuelva a seguir la compartida."

-- Preview.lua
L["Click an element to find its settings"] = "Haz clic en un elemento para encontrar sus opciones"

-- SoundCheckbox.lua
L["Play sound"] = "Reproducir sonido"

-- TextInput.lua
L["it can't be empty."] = "no puede estar vacío."
L["It can be %d letters at most."] = "Puede tener %d letras como máximo."
L["Couldn't save %s: %s"] = "No se pudo guardar %s: %s"

-- ActionButton.lua
L["Couldn't %s."] = "No se pudo %s."

-- ProfileDialog.lua
L["Press Ctrl+C to copy the text below."] = "Presiona Ctrl+C para copiar el texto de abajo."

-- Profiles.lua
L["\"%s\" is the built-in profile's name."] = "\"%s\" es el nombre del perfil integrado."
L["A profile named \"%s\" already exists."] = "Ya existe un perfil llamado \"%s\"."
L["Unavailable while editing the layout."] = "No disponible mientras se edita el diseño."
L["Active Profile"] = "Perfil activo"
L["Use a Profile for This Character"] = "Usar un perfil para este personaje"
L["Switches to a profile named after this character, made the first time."] = "Cambia a un perfil con el nombre de este personaje, que se crea la primera vez."
L["New Profile"] = "Perfil nuevo"
L["New"] = "Nuevo"
L["Create"] = "Crear"
L["Name the new profile. It starts with default settings."] = "Ponle nombre al perfil nuevo. Empieza con la configuración predeterminada."
L["Profile name"] = "Nombre del perfil"
L["Profile \"%s\" created."] = "Perfil \"%s\" creado."
L["Copy Current Profile"] = "Copiar perfil actual"
L["Copy"] = "Copiar"
L["Copy Profile"] = "Copiar perfil"
L["Name the copy of \"%s\"."] = "Ponle nombre a la copia de \"%s\"."
L["Copy of %s"] = "Copia de %s"
L["Copied \"%s\" to \"%s\"."] = "Se copió \"%s\" a \"%s\"."
L["Rename Current Profile"] = "Renombrar perfil actual"
L["Rename"] = "Renombrar"
L["Rename Profile"] = "Renombrar perfil"
L["Rename \"%s\" to:"] = "Renombrar \"%s\" a:"
L["Renamed \"%s\" to \"%s\"."] = "Se renombró \"%s\" a \"%s\"."
L["The last profile can't be deleted."] = "No se puede eliminar el último perfil."
L["Delete Current Profile"] = "Eliminar perfil actual"
L["Delete"] = "Eliminar"
L["Profile \"%s\" deleted; now using \"%s\"."] = "Perfil \"%s\" eliminado; ahora se usa \"%s\"."
L["Delete Profile"] = "Eliminar perfil"
L["Delete the profile \"%s\"? Its settings will be lost. Choose the profile to use instead:"] = "¿Eliminar el perfil \"%s\"? Se perderá su configuración. Elige el perfil que se usará en su lugar:"
L["Delete the profile \"%s\"? Its settings will be lost, and \"%s\" becomes active."] = "¿Eliminar el perfil \"%s\"? Se perderá su configuración y \"%s\" pasará a estar activo."
L["Reset Current Profile"] = "Restablecer perfil actual"
L["Profile \"%s\" reset."] = "Perfil \"%s\" restablecido."
L["Reset the profile \"%s\" to default settings?"] = "¿Restablecer el perfil \"%s\" a la configuración predeterminada?"
L["Export Current Profile"] = "Exportar perfil actual"
L["Export"] = "Exportar"
L["Export Profile"] = "Exportar perfil"
L["Import Profile"] = "Importar perfil"
L["Import"] = "Importar"
L["Paste a profile string. Importing creates a new profile."] = "Pega una cadena de perfil. Al importar se crea un perfil nuevo."
L["Imported \"%s\" as \"%s\"."] = "Se importó \"%s\" como \"%s\"."
L["Profiles"] = "Perfiles"
L["Manage"] = "Administrar"
L["Share"] = "Compartir"
