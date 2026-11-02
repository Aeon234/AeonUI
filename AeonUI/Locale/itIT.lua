if GetLocale() ~= "itIT" then
	return
end

local L = select(2, ...).L

-- Chat messages (Core)
L["AeonUI is off for this session, so its settings can't open."] = "AeonUI è disattivato per questa sessione, quindi le sue impostazioni non possono essere aperte."
L["your character could not be identified, so AeonUI is off for this session."] = "non è stato possibile identificare il tuo personaggio, quindi AeonUI è disattivato per questa sessione."
L["saved settings failed to load, so AeonUI is off for this session."] = "il caricamento delle impostazioni salvate non è riuscito, quindi AeonUI è disattivato per questa sessione."
L["saved settings come from a newer version of AeonUI, so this version is using default settings and leaves them unchanged."] = "le impostazioni salvate provengono da una versione più recente di AeonUI, quindi questa versione usa le impostazioni predefinite e le lascia invariate."
L["saved settings are damaged, so AeonUI is using default settings and leaves them unchanged until you reset them."] = "le impostazioni salvate sono danneggiate, quindi AeonUI usa le impostazioni predefinite e le lascia invariate finché non le reimposti."
L["the active profile can't be used, so AeonUI is showing default settings until you choose another profile."] = "il profilo attivo non può essere usato, quindi AeonUI mostra le impostazioni predefinite finché non scegli un altro profilo."

-- Profile names (Profile)
L["A profile needs a name."] = "Un profilo deve avere un nome."
L["A profile name can be %d letters at most."] = "Il nome di un profilo può avere al massimo %d lettere."
L["That name belongs to the default profile."] = "Quel nome appartiene al profilo predefinito."
L["A profile with that name already exists."] = "Esiste già un profilo con quel nome."

-- Profile strings (Profile)
L["This is not an AeonUI profile string, or it was cut short."] = "Questa non è una stringa di profilo di AeonUI, oppure è stata troncata."
L["This profile string was made by a newer version of AeonUI."] = "Questa stringa di profilo è stata creata da una versione più recente di AeonUI."
L["This profile string holds settings AeonUI can't use."] = "Questa stringa di profilo contiene impostazioni che AeonUI non può usare."

-- Minimap button tooltip (Core)
L["Click: open settings"] = "Clic: apri le impostazioni"

-- Key bindings (Core)
L["Eject All Passengers"] = "Espelli tutti i passeggeri"

-- Page titles (Settings)
L["Profiles"] = "Profili"
L["Recovery"] = "Ripristino"
L["Unit Frames"] = "Riquadri unità"
L["Maps"] = "Mappe"
L["Quality of Life"] = "Qualità della vita"

-- Shared settings labels (Settings)
L["Auctionator, TSM or Oribos Exchange provides auction prices."] = "Auctionator, TSM o Oribos Exchange forniscono i prezzi d'asta."
L["Access"] = "Accesso"
L["Text"] = "Testo"
L["Open"] = "Apri"
L["Font"] = "Carattere"
L["Outline"] = "Contorno"
L["Font Scale"] = "Scala carattere"
L["Height"] = "Altezza"
L["X Offset"] = "Scostamento X"
L["Y Offset"] = "Scostamento Y"
L["Scale"] = "Scala"
L["Crafting Orders"] = "Ordini di creazione"
L["Modifier"] = "Modificatore"
L["Visibility"] = "Visibilità"
L["Show"] = "Mostra"
L["Size"] = "Dimensione"
L["Border"] = "Bordo"
L["Border Style"] = "Stile del bordo"
L["Forever Minimal"] = "Forever Minimal"
L["Forever"] = "Forever"
L["Slate"] = "Ardesia"
L["Thin Line"] = "Linea sottile"
L["Border Color"] = "Colore del bordo"
L["Needs a border style."] = "Richiede uno stile del bordo."
L["Forever keeps its own colors."] = "Forever mantiene i propri colori."
L["Border Thickness"] = "Spessore del bordo"
L["Casting"] = "Lancio"
L["Class Color"] = "Colore della classe"
L["Texture"] = "Texture"
L["Horizontal"] = "Orizzontale"
L["Vertical"] = "Verticale"
L["Left"] = "A sinistra"
L["Right"] = "A destra"
L["Bar"] = "Barra"
L["Tooltip"] = "Tooltip"
L["Blizzard"] = "Blizzard"
L["Square"] = "Quadrato"
L["White"] = "Bianco"
L["Width"] = "Larghezza"
L["Food"] = "Cibo"
L["A"] = "A"
L["Layout"] = "Disposizione"

-- General page (Settings)
L["Show Minimap Button"] = "Mostra pulsante della minimappa"
L["Left-click opens settings."] = "Il clic sinistro apre le impostazioni."
L["Goes below the game's own minimum. Turning it off needs a reload."] = "Scende sotto il minimo del gioco. Disattivarla richiede un ricaricamento."
L["%s manages the UI scale."] = "%s gestisce la scala dell'interfaccia."
L["Pixel Perfect"] = "Pixel perfetto"
L["One interface unit per pixel on this screen."] = "Un'unità d'interfaccia per pixel su questo schermo."
L["Pixel Perfect For"] = "Pixel perfetto per"
L["Game Menu Scale"] = "Scala del menu di gioco"

-- Shared by the world map marker tooltips (World Map) and the Delete Cheapest Item rows (DeleteCheapestItem)
L["Vendor"] = "Mercante"

-- Shared by the Delete Cheapest Item rows (DeleteCheapestItem) and the item tooltips' auction price line on a
-- client without realms (Tooltip)
L["Auction"] = "Asta"

-- Profiles page (Settings)
L["AeonUI profile \"%s\"."] = "Profilo di AeonUI \"%s\"."
L["It holds %d settings this version doesn't use; they are kept."] = "Contiene %d impostazioni che questa versione non usa; vengono conservate."
L["Damaged Profiles"] = "Profili danneggiati"
L["The active profile can't be used, so default settings are shown. Choose another profile or delete it."] = "Il profilo attivo non può essere usato, quindi vengono mostrate le impostazioni predefinite. Scegli un altro profilo o eliminalo."
L["These profiles can't be used. They are kept unchanged until you delete them."] = "Questi profili non possono essere usati. Restano invariati finché non li elimini."
L["Delete the damaged profile \"%s\"? Characters using it switch to another profile."] = "Eliminare il profilo danneggiato \"%s\"? I personaggi che lo usano passano a un altro profilo."
L["Create another profile first."] = "Crea prima un altro profilo."

-- Recovery page (Settings)
L["AeonUI's saved settings can't be used, so its other pages are unavailable."] = "Le impostazioni salvate di AeonUI non possono essere usate, quindi le altre pagine non sono disponibili."
L["Saved Settings"] = "Impostazioni salvate"
L["Your saved settings are damaged. AeonUI shows default settings and leaves them unchanged until you reset them."] = "Le tue impostazioni salvate sono danneggiate. AeonUI mostra le impostazioni predefinite e le lascia invariate finché non le reimposti."
L["Your saved settings come from a newer version of AeonUI. This version shows default settings and leaves them unchanged."] = "Le tue impostazioni salvate provengono da una versione più recente di AeonUI. Questa versione mostra le impostazioni predefinite e le lascia invariate."
L["Diagnostic Export"] = "Esportazione diagnostica"
L["Diagnostic Export (Incomplete)"] = "Esportazione diagnostica (incompleta)"
L["The saved settings as text, to keep or to share when reporting the problem. It is not a profile string."] = "Le impostazioni salvate come testo, da conservare o condividere quando segnali il problema. Non è una stringa di profilo."
L["Reset Saved Settings"] = "Reimposta impostazioni salvate"
L["Erase every AeonUI profile and setting on this account and start again with defaults."] = "Cancella ogni profilo e impostazione di AeonUI su questo account e ricomincia con i valori predefiniti."
L["Erase every AeonUI profile and setting on this account? This cannot be undone."] = "Cancellare ogni profilo e impostazione di AeonUI su questo account? L'operazione non può essere annullata."
L["Type %s to erase every AeonUI profile and setting on this account."] = "Digita %s per cancellare ogni profilo e impostazione di AeonUI su questo account."

-- Shared by the world map and other features
L["Azuregos"] = "Azuregos"
L["Dungeon"] = "Spedizione"
L["Raid"] = "Incursione"
L["Innkeeper"] = "Locandiere"
L["Mailbox"] = "Cassetta postale"
L["Banker"] = "Banchiere"
L["Auctioneer"] = "Banditore"
L["Reagents"] = "Reagenti"
L["Ammunition"] = "Munizioni"
