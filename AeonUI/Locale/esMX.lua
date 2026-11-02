if GetLocale() ~= "esMX" then
	return
end

local L = select(2, ...).L

-- Chat messages (Core)
L["AeonUI is off for this session, so its settings can't open."] = "AeonUI está desactivado en esta sesión, así que no se puede abrir su configuración."
L["your character could not be identified, so AeonUI is off for this session."] = "no se pudo identificar a tu personaje, así que AeonUI está desactivado en esta sesión."
L["saved settings failed to load, so AeonUI is off for this session."] = "no se pudo cargar la configuración guardada, así que AeonUI está desactivado en esta sesión."
L["saved settings come from a newer version of AeonUI, so this version is using default settings and leaves them unchanged."] = "la configuración guardada procede de una versión más reciente de AeonUI, así que esta versión usa la configuración predeterminada y no la modifica."
L["saved settings are damaged, so AeonUI is using default settings and leaves them unchanged until you reset them."] = "la configuración guardada está dañada, así que AeonUI usa la configuración predeterminada y no la modifica hasta que la restablezcas."
L["the active profile can't be used, so AeonUI is showing default settings until you choose another profile."] = "el perfil activo no se puede usar, así que AeonUI muestra la configuración predeterminada hasta que elijas otro perfil."

-- Profile names (Profile)
L["A profile needs a name."] = "Un perfil necesita un nombre."
L["A profile name can be %d letters at most."] = "El nombre de un perfil puede tener %d letras como máximo."
L["That name belongs to the default profile."] = "Ese nombre pertenece al perfil predeterminado."
L["A profile with that name already exists."] = "Ya existe un perfil con ese nombre."

-- Profile strings (Profile)
L["This is not an AeonUI profile string, or it was cut short."] = "Esto no es una cadena de perfil de AeonUI, o está incompleta."
L["This profile string was made by a newer version of AeonUI."] = "Esta cadena de perfil se creó con una versión más reciente de AeonUI."
L["This profile string holds settings AeonUI can't use."] = "Esta cadena de perfil contiene ajustes que AeonUI no puede usar."

-- Minimap button tooltip (Core)
L["Click: open settings"] = "Clic: abrir configuración"

-- Key bindings (Core)
L["Eject All Passengers"] = "Expulsar a todos los pasajeros"

-- Page titles (Settings)
L["Profiles"] = "Perfiles"
L["Recovery"] = "Recuperación"
L["Unit Frames"] = "Marcos de unidad"
L["Maps"] = "Mapas"
L["Quality of Life"] = "Calidad de vida"

-- Shared settings labels (Settings)
L["Auctionator, TSM or Oribos Exchange provides auction prices."] = "Auctionator, TSM u Oribos Exchange proporcionan los precios de subasta."
L["Access"] = "Acceso"
L["Text"] = "Texto"
L["Open"] = "Abrir"
L["Font"] = "Fuente"
L["Outline"] = "Contorno"
L["Font Scale"] = "Escala de fuente"
L["Height"] = "Alto"
L["X Offset"] = "Desplazamiento X"
L["Y Offset"] = "Desplazamiento Y"
L["Scale"] = "Escala"
L["Crafting Orders"] = "Órdenes de fabricación"
L["Modifier"] = "Modificador"
L["Visibility"] = "Visibilidad"
L["Show"] = "Mostrar"
L["Size"] = "Tamaño"
L["Border"] = "Borde"
L["Border Style"] = "Estilo de borde"
L["Forever Minimal"] = "Forever Minimal"
L["Forever"] = "Forever"
L["Slate"] = "Pizarra"
L["Thin Line"] = "Línea delgada"
L["Border Color"] = "Color del borde"
L["Needs a border style."] = "Requiere un estilo de borde."
L["Forever keeps its own colors."] = "Forever conserva sus propios colores."
L["Border Thickness"] = "Grosor del borde"
L["Casting"] = "Lanzando"
L["Class Color"] = "Color de clase"
L["Texture"] = "Textura"
L["Horizontal"] = "Horizontal"
L["Vertical"] = "Vertical"
L["Left"] = "Izquierda"
L["Right"] = "Derecha"
L["Bar"] = "Barra"
L["Tooltip"] = "Descripción emergente"
L["Blizzard"] = "Blizzard"
L["Square"] = "Cuadrado"
L["White"] = "Blanco"
L["Width"] = "Ancho"
L["Food"] = "Comida"
L["A"] = "A"
L["Layout"] = "Diseño"

-- General page (Settings)
L["Show Minimap Button"] = "Mostrar botón del minimapa"
L["Left-click opens settings."] = "Clic izquierdo abre la configuración."
L["Goes below the game's own minimum. Turning it off needs a reload."] = "Baja del mínimo del juego. Desactivarla requiere recargar."
L["%s manages the UI scale."] = "%s gestiona la escala de la interfaz."
L["Pixel Perfect"] = "Píxel perfecto"
L["One interface unit per pixel on this screen."] = "Una unidad de interfaz por píxel en esta pantalla."
L["Pixel Perfect For"] = "Píxel perfecto para"
L["Game Menu Scale"] = "Escala del menú del juego"

-- Shared by the world map marker tooltips (World Map) and the Delete Cheapest Item rows (DeleteCheapestItem)
L["Vendor"] = "Vendedor"

-- Shared by the Delete Cheapest Item rows (DeleteCheapestItem) and the item tooltips' auction price line on a
-- client without realms (Tooltip)
L["Auction"] = "Subasta"

-- Profiles page (Settings)
L["AeonUI profile \"%s\"."] = "Perfil de AeonUI \"%s\"."
L["It holds %d settings this version doesn't use; they are kept."] = "Contiene %d ajustes que esta versión no usa; se conservan."
L["Damaged Profiles"] = "Perfiles dañados"
L["The active profile can't be used, so default settings are shown. Choose another profile or delete it."] = "El perfil activo no se puede usar, así que se muestra la configuración predeterminada. Elige otro perfil o elimínalo."
L["These profiles can't be used. They are kept unchanged until you delete them."] = "Estos perfiles no se pueden usar. Se conservan sin cambios hasta que los elimines."
L["Delete the damaged profile \"%s\"? Characters using it switch to another profile."] = "¿Eliminar el perfil dañado \"%s\"? Los personajes que lo usan cambiarán a otro perfil."
L["Create another profile first."] = "Crea otro perfil primero."

-- Recovery page (Settings)
L["AeonUI's saved settings can't be used, so its other pages are unavailable."] = "La configuración guardada de AeonUI no se puede usar, así que sus demás páginas no están disponibles."
L["Saved Settings"] = "Configuración guardada"
L["Your saved settings are damaged. AeonUI shows default settings and leaves them unchanged until you reset them."] = "Tu configuración guardada está dañada. AeonUI muestra la configuración predeterminada y no la modifica hasta que la restablezcas."
L["Your saved settings come from a newer version of AeonUI. This version shows default settings and leaves them unchanged."] = "Tu configuración guardada procede de una versión más reciente de AeonUI. Esta versión muestra la configuración predeterminada y no la modifica."
L["Diagnostic Export"] = "Exportación de diagnóstico"
L["Diagnostic Export (Incomplete)"] = "Exportación de diagnóstico (incompleta)"
L["The saved settings as text, to keep or to share when reporting the problem. It is not a profile string."] = "La configuración guardada como texto, para conservarla o compartirla al reportar el problema. No es una cadena de perfil."
L["Reset Saved Settings"] = "Restablecer configuración guardada"
L["Erase every AeonUI profile and setting on this account and start again with defaults."] = "Borra todos los perfiles y ajustes de AeonUI de esta cuenta y empieza de nuevo con los valores predeterminados."
L["Erase every AeonUI profile and setting on this account? This cannot be undone."] = "¿Borrar todos los perfiles y ajustes de AeonUI de esta cuenta? No se puede deshacer."
L["Type %s to erase every AeonUI profile and setting on this account."] = "Escribe %s para borrar todos los perfiles y ajustes de AeonUI de esta cuenta."

-- Shared by the world map and other features
L["Azuregos"] = "Azuregos"
L["Dungeon"] = "Calabozo"
L["Raid"] = "Banda"
L["Innkeeper"] = "Posadero"
L["Mailbox"] = "Buzón"
L["Banker"] = "Banquero"
L["Auctioneer"] = "Subastador"
L["Reagents"] = "Componentes"
L["Ammunition"] = "Munición"
