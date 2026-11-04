if GetLocale() ~= "deDE" then
	return
end

local L = select(2, ...).L

-- Chat messages (Core)
L["AeonUI is off for this session, so its settings can't open."] = "AeonUI ist für diese Sitzung deaktiviert, daher können die Einstellungen nicht geöffnet werden."
L["your character could not be identified, so AeonUI is off for this session."] = "Dein Charakter konnte nicht erkannt werden, daher ist AeonUI für diese Sitzung deaktiviert."
L["saved settings failed to load, so AeonUI is off for this session."] = "Die gespeicherten Einstellungen konnten nicht geladen werden, daher ist AeonUI für diese Sitzung deaktiviert."
L["saved settings come from a newer version of AeonUI, so this version is using default settings and leaves them unchanged."] = "Die gespeicherten Einstellungen stammen von einer neueren Version von AeonUI. Diese Version verwendet Standardeinstellungen und lässt sie unverändert."
L["saved settings are damaged, so AeonUI is using default settings and leaves them unchanged until you reset them."] = "Die gespeicherten Einstellungen sind beschädigt. AeonUI verwendet Standardeinstellungen und lässt sie unverändert, bis du sie zurücksetzt."
L["the active profile can't be used, so AeonUI is showing default settings until you choose another profile."] = "Das aktive Profil kann nicht verwendet werden. AeonUI zeigt Standardeinstellungen, bis du ein anderes Profil wählst."

-- Profile names (Profile)
L["A profile needs a name."] = "Ein Profil braucht einen Namen."
L["A profile name can be %d letters at most."] = "Ein Profilname darf höchstens %d Zeichen lang sein."
L["That name belongs to the default profile."] = "Dieser Name gehört zum Standardprofil."
L["A profile with that name already exists."] = "Ein Profil mit diesem Namen existiert bereits."

-- Profile strings (Profile)
L["This is not an AeonUI profile string, or it was cut short."] = "Dies ist kein AeonUI-Profiltext, oder er ist unvollständig."
L["This profile string was made by a newer version of AeonUI."] = "Dieser Profiltext wurde von einer neueren Version von AeonUI erstellt."
L["This profile string holds settings AeonUI can't use."] = "Dieser Profiltext enthält Einstellungen, die AeonUI nicht verwenden kann."

-- Minimap button tooltip (Core)
L["Left-click: open settings"] = "Linksklick: Einstellungen öffnen"
L["Right-click: open edit mode"] = "Rechtsklick: Bearbeitungsmodus öffnen"

-- Key bindings (Core)
L["Eject All Passengers"] = "Alle Passagiere auswerfen"

-- Page titles (Settings)
L["Profiles"] = "Profile"
L["Recovery"] = "Wiederherstellung"
L["Unit Frames"] = "Einheitenfenster"
L["Maps"] = "Karten"
L["Quality of Life"] = "Komfort"

-- Shared settings labels (Settings)
L["Auctionator, TSM or Oribos Exchange provides auction prices."] = "Auctionator, TSM oder Oribos Exchange liefert Auktionspreise."
L["Access"] = "Zugriff"
L["Text"] = "Text"
L["Open"] = "Öffnen"
L["Font"] = "Schriftart"
L["Outline"] = "Umriss"
L["Font Scale"] = "Schriftskalierung"
L["Height"] = "Höhe"
L["X Offset"] = "X-Versatz"
L["Y Offset"] = "Y-Versatz"
L["Scale"] = "Skalierung"
L["Crafting Orders"] = "Handwerksaufträge"
L["Modifier"] = "Sondertaste"
L["Visibility"] = "Sichtbarkeit"
L["Show"] = "Anzeigen"
L["Size"] = "Größe"
L["Border"] = "Rahmen"
L["Border Style"] = "Rahmenstil"
L["Forever Minimal"] = "Forever Minimal"
L["Forever"] = "Forever"
L["Slate"] = "Schiefer"
L["Thin Line"] = "Dünne Linie"
L["Border Color"] = "Rahmenfarbe"
L["Needs a border style."] = "Benötigt einen Rahmenstil."
L["Forever keeps its own colors."] = "Forever behält seine eigenen Farben."
L["Border Thickness"] = "Rahmenstärke"
L["Show Shadow"] = "Schatten anzeigen"
L["Shadow Size"] = "Schattengröße"
L["Shadow Color"] = "Schattenfarbe"
L["Casting"] = "Wirken"
L["Class Color"] = "Klassenfarbe"
L["Texture"] = "Textur"
L["Horizontal"] = "Waagerecht"
L["Vertical"] = "Senkrecht"
L["Left"] = "Links"
L["Right"] = "Rechts"
L["Bar"] = "Leiste"
L["Tooltip"] = "Tooltip"
L["Blizzard"] = "Blizzard"
L["Square"] = "Quadratisch"
L["White"] = "Weiß"
L["Width"] = "Breite"
L["Food"] = "Essen"
L["A"] = "A"
L["Layout"] = "Anordnung"

-- General page (Settings)
L["Show Minimap Button"] = "Minikartenknopf anzeigen"
L["Left-click opens settings. Right-click opens edit mode."] = "Linksklick öffnet die Einstellungen. Rechtsklick öffnet den Bearbeitungsmodus."
L["Goes below the game's own minimum. Turning it off needs a reload."] = "Geht unter das Minimum des Spiels. Zum Ausschalten ist ein Neuladen nötig."
L["%s manages the UI scale."] = "%s verwaltet die UI-Skalierung."
L["Pixel Perfect"] = "Pixelgenau"
L["One interface unit per pixel on this screen."] = "Eine Oberflächeneinheit pro Pixel auf diesem Bildschirm."
L["Pixel Perfect For"] = "Pixelgenau für"
L["Game Menu Scale"] = "Spielmenü-Skalierung"

-- Shared by the world map marker tooltips (World Map) and the Delete Cheapest Item rows (DeleteCheapestItem)
L["Vendor"] = "Händler"

-- Shared by the Delete Cheapest Item rows (DeleteCheapestItem) and the item tooltips' auction price line on a
-- client without realms (Tooltip)
L["Auction"] = "Auktion"

-- Profiles page (Settings)
L["AeonUI profile \"%s\"."] = "AeonUI-Profil „%s“."
L["It holds %d settings this version doesn't use; they are kept."] = "Es enthält %d Einstellungen, die diese Version nicht nutzt; sie bleiben erhalten."
L["Damaged Profiles"] = "Beschädigte Profile"
L["The active profile can't be used, so default settings are shown. Choose another profile or delete it."] = "Das aktive Profil kann nicht verwendet werden, daher werden Standardeinstellungen gezeigt. Wähle ein anderes Profil oder lösche es."
L["These profiles can't be used. They are kept unchanged until you delete them."] = "Diese Profile können nicht verwendet werden. Sie bleiben unverändert, bis du sie löschst."
L["Delete the damaged profile \"%s\"? Characters using it switch to another profile."] = "Das beschädigte Profil „%s“ löschen? Charaktere, die es nutzen, wechseln zu einem anderen Profil."
L["Create another profile first."] = "Erstelle zuerst ein anderes Profil."

-- Recovery page (Settings)
L["AeonUI's saved settings can't be used, so its other pages are unavailable."] = "Die gespeicherten Einstellungen von AeonUI können nicht verwendet werden, daher sind die anderen Seiten nicht verfügbar."
L["Saved Settings"] = "Gespeicherte Einstellungen"
L["Your saved settings are damaged. AeonUI shows default settings and leaves them unchanged until you reset them."] = "Deine gespeicherten Einstellungen sind beschädigt. AeonUI zeigt Standardeinstellungen und lässt sie unverändert, bis du sie zurücksetzt."
L["Your saved settings come from a newer version of AeonUI. This version shows default settings and leaves them unchanged."] = "Deine gespeicherten Einstellungen stammen von einer neueren Version von AeonUI. Diese Version zeigt Standardeinstellungen und lässt sie unverändert."
L["Diagnostic Export"] = "Diagnoseexport"
L["Diagnostic Export (Incomplete)"] = "Diagnoseexport (unvollständig)"
L["The saved settings as text, to keep or to share when reporting the problem. It is not a profile string."] = "Die gespeicherten Einstellungen als Text, zum Aufbewahren oder zum Teilen beim Melden des Problems. Kein Profiltext."
L["Reset Saved Settings"] = "Gespeicherte Einstellungen zurücksetzen"
L["Erase every AeonUI profile and setting on this account and start again with defaults."] = "Alle AeonUI-Profile und -Einstellungen auf diesem Account löschen und mit Standardwerten neu beginnen."
L["Erase every AeonUI profile and setting on this account? This cannot be undone."] = "Alle AeonUI-Profile und -Einstellungen auf diesem Account löschen? Dies kann nicht rückgängig gemacht werden."
L["Type %s to erase every AeonUI profile and setting on this account."] = "Gib %s ein, um alle AeonUI-Profile und -Einstellungen auf diesem Account zu löschen."

-- Shared by the world map and other features
L["Azuregos"] = "Azuregos"
L["Dungeon"] = "Dungeon"
L["Raid"] = "Schlachtzug"
L["Innkeeper"] = "Gastwirt"
L["Mailbox"] = "Briefkasten"
L["Banker"] = "Bankier"
L["Auctioneer"] = "Auktionator"
L["Reagents"] = "Reagenzien"
L["Ammunition"] = "Munition"
