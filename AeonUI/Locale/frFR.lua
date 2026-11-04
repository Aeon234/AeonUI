if GetLocale() ~= "frFR" then
	return
end

local L = select(2, ...).L

-- Chat messages (Core)
L["AeonUI is off for this session, so its settings can't open."] = "AeonUI est désactivé pour cette session, ses paramètres ne peuvent donc pas s'ouvrir."
L["your character could not be identified, so AeonUI is off for this session."] = "votre personnage n'a pas pu être identifié, AeonUI est donc désactivé pour cette session."
L["saved settings failed to load, so AeonUI is off for this session."] = "les paramètres enregistrés n'ont pas pu être chargés, AeonUI est donc désactivé pour cette session."
L["saved settings come from a newer version of AeonUI, so this version is using default settings and leaves them unchanged."] = "les paramètres enregistrés proviennent d'une version plus récente d'AeonUI ; cette version utilise donc les paramètres par défaut et ne les modifie pas."
L["saved settings are damaged, so AeonUI is using default settings and leaves them unchanged until you reset them."] = "les paramètres enregistrés sont endommagés ; AeonUI utilise donc les paramètres par défaut et ne les modifie pas tant que vous ne les réinitialisez pas."
L["the active profile can't be used, so AeonUI is showing default settings until you choose another profile."] = "le profil actif est inutilisable ; AeonUI affiche donc les paramètres par défaut jusqu'à ce que vous choisissiez un autre profil."

-- Profile names (Profile)
L["A profile needs a name."] = "Un profil doit avoir un nom."
L["A profile name can be %d letters at most."] = "Un nom de profil peut compter %d lettres au maximum."
L["That name belongs to the default profile."] = "Ce nom est celui du profil par défaut."
L["A profile with that name already exists."] = "Un profil portant ce nom existe déjà."

-- Profile strings (Profile)
L["This is not an AeonUI profile string, or it was cut short."] = "Ce n'est pas une chaîne de profil AeonUI, ou elle a été tronquée."
L["This profile string was made by a newer version of AeonUI."] = "Cette chaîne de profil provient d'une version plus récente d'AeonUI."
L["This profile string holds settings AeonUI can't use."] = "Cette chaîne de profil contient des paramètres qu'AeonUI ne peut pas utiliser."

-- Minimap button tooltip (Core)
L["Left-click: open settings"] = "Clic gauche : ouvrir les paramètres"
L["Right-click: open edit mode"] = "Clic droit : ouvrir le Mode Édition"

-- Key bindings (Core)
L["Eject All Passengers"] = "Éjecter tous les passagers"

-- Page titles (Settings)
L["Profiles"] = "Profils"
L["Recovery"] = "Récupération"
L["Unit Frames"] = "Cadres d'unité"
L["Maps"] = "Cartes"
L["Quality of Life"] = "Qualité de vie"

-- Shared settings labels (Settings)
L["Auctionator, TSM or Oribos Exchange provides auction prices."] = "Auctionator, TSM ou Oribos Exchange fournit les prix des enchères."
L["Access"] = "Accès"
L["Text"] = "Texte"
L["Open"] = "Ouvrir"
L["Font"] = "Police"
L["Outline"] = "Contour"
L["Font Scale"] = "Échelle de police"
L["Height"] = "Hauteur"
L["X Offset"] = "Décalage X"
L["Y Offset"] = "Décalage Y"
L["Scale"] = "Échelle"
L["Crafting Orders"] = "Commandes d'artisanat"
L["Modifier"] = "Modificateur"
L["Visibility"] = "Visibilité"
L["Show"] = "Afficher"
L["Size"] = "Taille"
L["Border"] = "Bordure"
L["Border Style"] = "Style de bordure"
L["Forever Minimal"] = "Forever Minimal"
L["Forever"] = "Forever"
L["Slate"] = "Ardoise"
L["Thin Line"] = "Trait fin"
L["Border Color"] = "Couleur de la bordure"
L["Needs a border style."] = "Nécessite un style de bordure."
L["Forever keeps its own colors."] = "Forever garde ses propres couleurs."
L["Border Thickness"] = "Épaisseur de la bordure"
L["Show Shadow"] = "Afficher l'ombre"
L["Shadow Size"] = "Taille de l'ombre"
L["Shadow Color"] = "Couleur de l'ombre"
L["Casting"] = "Incantation"
L["Class Color"] = "Couleur de classe"
L["Texture"] = "Texture"
L["Horizontal"] = "Horizontale"
L["Vertical"] = "Verticale"
L["Left"] = "À gauche"
L["Right"] = "À droite"
L["Bar"] = "Barre"
L["Tooltip"] = "Infobulle"
L["Blizzard"] = "Blizzard"
L["Square"] = "Carré"
L["White"] = "Blanc"
L["Width"] = "Largeur"
L["Food"] = "Nourriture"
L["A"] = "A"
L["Layout"] = "Disposition"

-- General page (Settings)
L["Show Minimap Button"] = "Afficher le bouton de la minicarte"
L["Left-click opens settings. Right-click opens edit mode."] = "Le clic gauche ouvre les paramètres. Le clic droit ouvre le Mode Édition."
L["Goes below the game's own minimum. Turning it off needs a reload."] = "Descend sous le minimum du jeu. La désactiver demande un rechargement."
L["%s manages the UI scale."] = "%s gère l'échelle de l'interface."
L["Pixel Perfect"] = "Pixel parfait"
L["One interface unit per pixel on this screen."] = "Une unité d'interface par pixel sur cet écran."
L["Pixel Perfect For"] = "Pixel parfait pour"
L["Game Menu Scale"] = "Échelle du menu du jeu"

-- Shared by the world map marker tooltips (World Map) and the Delete Cheapest Item rows (DeleteCheapestItem)
L["Vendor"] = "Marchand"

-- Shared by the Delete Cheapest Item rows (DeleteCheapestItem) and the item tooltips' auction price line on a
-- client without realms (Tooltip)
L["Auction"] = "Enchères"

-- Profiles page (Settings)
L["AeonUI profile \"%s\"."] = "Profil AeonUI « %s »."
L["It holds %d settings this version doesn't use; they are kept."] = "Il contient %d paramètres que cette version n'utilise pas ; ils sont conservés."
L["Damaged Profiles"] = "Profils endommagés"
L["The active profile can't be used, so default settings are shown. Choose another profile or delete it."] = "Le profil actif est inutilisable ; les paramètres par défaut sont donc affichés. Choisissez un autre profil ou supprimez-le."
L["These profiles can't be used. They are kept unchanged until you delete them."] = "Ces profils sont inutilisables. Ils sont conservés tels quels jusqu'à ce que vous les supprimiez."
L["Delete the damaged profile \"%s\"? Characters using it switch to another profile."] = "Supprimer le profil endommagé « %s » ? Les personnages qui l'utilisent passent à un autre profil."
L["Create another profile first."] = "Créez d'abord un autre profil."

-- Recovery page (Settings)
L["AeonUI's saved settings can't be used, so its other pages are unavailable."] = "Les paramètres enregistrés d'AeonUI sont inutilisables ; ses autres pages ne sont donc pas disponibles."
L["Saved Settings"] = "Paramètres enregistrés"
L["Your saved settings are damaged. AeonUI shows default settings and leaves them unchanged until you reset them."] = "Vos paramètres enregistrés sont endommagés. AeonUI affiche les paramètres par défaut et ne les modifie pas tant que vous ne les réinitialisez pas."
L["Your saved settings come from a newer version of AeonUI. This version shows default settings and leaves them unchanged."] = "Vos paramètres enregistrés proviennent d'une version plus récente d'AeonUI. Cette version affiche les paramètres par défaut et ne les modifie pas."
L["Diagnostic Export"] = "Export de diagnostic"
L["Diagnostic Export (Incomplete)"] = "Export de diagnostic (incomplet)"
L["The saved settings as text, to keep or to share when reporting the problem. It is not a profile string."] = "Les paramètres enregistrés sous forme de texte, à conserver ou à partager pour signaler le problème. Ce n'est pas une chaîne de profil."
L["Reset Saved Settings"] = "Réinitialiser les paramètres enregistrés"
L["Erase every AeonUI profile and setting on this account and start again with defaults."] = "Effacer tous les profils et paramètres d'AeonUI sur ce compte et repartir des valeurs par défaut."
L["Erase every AeonUI profile and setting on this account? This cannot be undone."] = "Effacer tous les profils et paramètres d'AeonUI sur ce compte ? Cette action est irréversible."
L["Type %s to erase every AeonUI profile and setting on this account."] = "Tapez %s pour effacer tous les profils et paramètres d'AeonUI sur ce compte."

-- Shared by the world map and other features
L["Azuregos"] = "Azuregos"
L["Dungeon"] = "Donjon"
L["Raid"] = "Raid"
L["Innkeeper"] = "Aubergiste"
L["Mailbox"] = "Boîte aux lettres"
L["Banker"] = "Banquier"
L["Auctioneer"] = "Commissaire-priseur"
L["Reagents"] = "Composants"
L["Ammunition"] = "Munitions"
