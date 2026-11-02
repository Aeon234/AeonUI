if GetLocale() ~= "ptBR" then
	return
end

local L = select(2, ...).L

-- Chat messages (Core)
L["AeonUI is off for this session, so its settings can't open."] = "o AeonUI está desativado nesta sessão, então suas configurações não podem ser abertas."
L["your character could not be identified, so AeonUI is off for this session."] = "não foi possível identificar seu personagem, então o AeonUI está desativado nesta sessão."
L["saved settings failed to load, so AeonUI is off for this session."] = "as configurações salvas não foram carregadas, então o AeonUI está desativado nesta sessão."
L["saved settings come from a newer version of AeonUI, so this version is using default settings and leaves them unchanged."] = "as configurações salvas vêm de uma versão mais nova do AeonUI, então esta versão usa as configurações padrão e as mantém inalteradas."
L["saved settings are damaged, so AeonUI is using default settings and leaves them unchanged until you reset them."] = "as configurações salvas estão danificadas, então o AeonUI usa as configurações padrão e as mantém inalteradas até que você as redefina."
L["the active profile can't be used, so AeonUI is showing default settings until you choose another profile."] = "o perfil ativo não pode ser usado, então o AeonUI mostra as configurações padrão até que você escolha outro perfil."

-- Profile names (Profile)
L["A profile needs a name."] = "Um perfil precisa de um nome."
L["A profile name can be %d letters at most."] = "O nome de um perfil pode ter no máximo %d letras."
L["That name belongs to the default profile."] = "Esse nome pertence ao perfil padrão."
L["A profile with that name already exists."] = "Já existe um perfil com esse nome."

-- Profile strings (Profile)
L["This is not an AeonUI profile string, or it was cut short."] = "Este não é um texto de perfil do AeonUI, ou está incompleto."
L["This profile string was made by a newer version of AeonUI."] = "Este texto de perfil foi criado por uma versão mais nova do AeonUI."
L["This profile string holds settings AeonUI can't use."] = "Este texto de perfil contém configurações que o AeonUI não pode usar."

-- Minimap button tooltip (Core)
L["Click: open settings"] = "Clique: abrir configurações"

-- Key bindings (Core)
L["Eject All Passengers"] = "Ejetar todos os passageiros"

-- Page titles (Settings)
L["Profiles"] = "Perfis"
L["Recovery"] = "Recuperação"
L["Unit Frames"] = "Quadros de unidade"
L["Maps"] = "Mapas"
L["Quality of Life"] = "Qualidade de vida"

-- Shared settings labels (Settings)
L["Auctionator, TSM or Oribos Exchange provides auction prices."] = "Auctionator, TSM ou Oribos Exchange fornece os preços de leilão."
L["Access"] = "Acesso"
L["Text"] = "Texto"
L["Open"] = "Abrir"
L["Font"] = "Fonte"
L["Outline"] = "Contorno"
L["Font Scale"] = "Escala da fonte"
L["Height"] = "Altura"
L["X Offset"] = "Deslocamento X"
L["Y Offset"] = "Deslocamento Y"
L["Scale"] = "Escala"
L["Crafting Orders"] = "Pedidos de criação"
L["Modifier"] = "Modificador"
L["Visibility"] = "Visibilidade"
L["Show"] = "Mostrar"
L["Size"] = "Tamanho"
L["Border"] = "Borda"
L["Border Style"] = "Estilo da borda"
L["Forever Minimal"] = "Forever Minimal"
L["Forever"] = "Forever"
L["Slate"] = "Ardósia"
L["Thin Line"] = "Linha fina"
L["Border Color"] = "Cor da borda"
L["Needs a border style."] = "Requer um estilo de borda."
L["Forever keeps its own colors."] = "Forever mantém suas próprias cores."
L["Border Thickness"] = "Espessura da borda"
L["Casting"] = "Lançando"
L["Class Color"] = "Cor da classe"
L["Texture"] = "Textura"
L["Horizontal"] = "Horizontal"
L["Vertical"] = "Vertical"
L["Left"] = "À esquerda"
L["Right"] = "À direita"
L["Bar"] = "Barra"
L["Tooltip"] = "Dica de tela"
L["Blizzard"] = "Blizzard"
L["Square"] = "Quadrado"
L["White"] = "Branco"
L["Width"] = "Largura"
L["Food"] = "Comida"
L["A"] = "A"
L["Layout"] = "Layout"

-- General page (Settings)
L["Show Minimap Button"] = "Mostrar botão do minimapa"
L["Left-click opens settings."] = "Clicar com o botão esquerdo abre as configurações."
L["Goes below the game's own minimum. Turning it off needs a reload."] = "Vai abaixo do mínimo do jogo. Desativar exige recarregar."
L["%s manages the UI scale."] = "%s gerencia a escala da interface."
L["Pixel Perfect"] = "Pixel perfeito"
L["One interface unit per pixel on this screen."] = "Uma unidade de interface por pixel nesta tela."
L["Pixel Perfect For"] = "Pixel perfeito para"
L["Game Menu Scale"] = "Escala do menu do jogo"

-- Shared by the world map marker tooltips (World Map) and the Delete Cheapest Item rows (DeleteCheapestItem)
L["Vendor"] = "Vendedor"

-- Shared by the Delete Cheapest Item rows (DeleteCheapestItem) and the item tooltips' auction price line on a
-- client without realms (Tooltip)
L["Auction"] = "Leilão"

-- Profiles page (Settings)
L["AeonUI profile \"%s\"."] = "Perfil do AeonUI \"%s\"."
L["It holds %d settings this version doesn't use; they are kept."] = "Contém %d configurações que esta versão não usa; elas são mantidas."
L["Damaged Profiles"] = "Perfis danificados"
L["The active profile can't be used, so default settings are shown. Choose another profile or delete it."] = "O perfil ativo não pode ser usado, então as configurações padrão são mostradas. Escolha outro perfil ou exclua-o."
L["These profiles can't be used. They are kept unchanged until you delete them."] = "Estes perfis não podem ser usados. Eles são mantidos inalterados até que você os exclua."
L["Delete the damaged profile \"%s\"? Characters using it switch to another profile."] = "Excluir o perfil danificado \"%s\"? Os personagens que o usam passam para outro perfil."
L["Create another profile first."] = "Crie outro perfil primeiro."

-- Recovery page (Settings)
L["AeonUI's saved settings can't be used, so its other pages are unavailable."] = "As configurações salvas do AeonUI não podem ser usadas, então suas outras páginas estão indisponíveis."
L["Saved Settings"] = "Configurações salvas"
L["Your saved settings are damaged. AeonUI shows default settings and leaves them unchanged until you reset them."] = "Suas configurações salvas estão danificadas. O AeonUI mostra as configurações padrão e as mantém inalteradas até que você as redefina."
L["Your saved settings come from a newer version of AeonUI. This version shows default settings and leaves them unchanged."] = "Suas configurações salvas vêm de uma versão mais nova do AeonUI. Esta versão mostra as configurações padrão e as mantém inalteradas."
L["Diagnostic Export"] = "Exportação de diagnóstico"
L["Diagnostic Export (Incomplete)"] = "Exportação de diagnóstico (incompleta)"
L["The saved settings as text, to keep or to share when reporting the problem. It is not a profile string."] = "As configurações salvas como texto, para guardar ou compartilhar ao relatar o problema. Não é um texto de perfil."
L["Reset Saved Settings"] = "Redefinir configurações salvas"
L["Erase every AeonUI profile and setting on this account and start again with defaults."] = "Apague todos os perfis e configurações do AeonUI nesta conta e recomece com os padrões."
L["Erase every AeonUI profile and setting on this account? This cannot be undone."] = "Apagar todos os perfis e configurações do AeonUI nesta conta? Isso não pode ser desfeito."
L["Type %s to erase every AeonUI profile and setting on this account."] = "Digite %s para apagar todos os perfis e configurações do AeonUI nesta conta."

-- Shared by the world map and other features
L["Azuregos"] = "Azuregos"
L["Dungeon"] = "Masmorra"
L["Raid"] = "Raide"
L["Innkeeper"] = "Taverneiro"
L["Mailbox"] = "Caixa de correio"
L["Banker"] = "Banqueiro"
L["Auctioneer"] = "Leiloeiro"
L["Reagents"] = "Reagentes"
L["Ammunition"] = "Munição"
