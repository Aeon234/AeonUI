if GetLocale() ~= "ptBR" then
	return
end

local L = select(2, ...).AeonSettings.L

-- Control.lua
L["Couldn't save %s."] = "Não foi possível salvar %s."

-- PageModel.lua
L["Requires %s to be enabled."] = "Requer %s ativado."

-- Window.lua
L["Reset %s to defaults?"] = "Redefinir %s para os padrões?"
L["Reset"] = "Redefinir"
L["Unavailable in combat."] = "Indisponível em combate."
L["1 change needs a reload"] = "1 alteração requer recarregar"
L["%d changes need a reload"] = "%d alterações requerem recarregar"
L["%s reset to defaults."] = "%s redefinido para os padrões."
L['Search results for "%s"'] = 'Resultados da busca por "%s"'
L["No settings match."] = "Nenhuma configuração encontrada."

-- Row.lua
L["Shared"] = "Compartilhado"
L["Custom"] = "Personalizado"
L["Use Shared"] = "Usar compartilhado"
L["Removes this value so the setting follows the shared one again."] = "Remove este valor para que a configuração volte a seguir a compartilhada."

-- Preview.lua
L["Click an element to find its settings"] = "Clique em um elemento para encontrar suas configurações"

-- SoundCheckbox.lua
L["Play sound"] = "Tocar som"

-- TextInput.lua
L["it can't be empty."] = "não pode ficar vazio."
L["It can be %d letters at most."] = "Pode ter no máximo %d letras."
L["Couldn't save %s: %s"] = "Não foi possível salvar %s: %s"

-- ActionButton.lua
L["Couldn't %s."] = "Não foi possível %s."

-- ProfileDialog.lua
L["Press Ctrl+C to copy the text below."] = "Pressione Ctrl+C para copiar o texto abaixo."

-- Profiles.lua
L["\"%s\" is the built-in profile's name."] = "\"%s\" é o nome do perfil padrão."
L["A profile named \"%s\" already exists."] = "Já existe um perfil chamado \"%s\"."
L["Unavailable while editing the layout."] = "Indisponível durante a edição do layout."
L["Active Profile"] = "Perfil ativo"
L["Use a Profile for This Character"] = "Usar um perfil para este personagem"
L["Switches to a profile named after this character, made the first time."] = "Muda para um perfil com o nome deste personagem, criado na primeira vez."
L["New Profile"] = "Novo perfil"
L["New"] = "Novo"
L["Create"] = "Criar"
L["Name the new profile. It starts with default settings."] = "Dê um nome ao novo perfil. Ele começa com as configurações padrão."
L["Profile name"] = "Nome do perfil"
L["Profile \"%s\" created."] = "Perfil \"%s\" criado."
L["Copy Current Profile"] = "Copiar perfil atual"
L["Copy"] = "Copiar"
L["Copy Profile"] = "Copiar perfil"
L["Name the copy of \"%s\"."] = "Dê um nome à cópia de \"%s\"."
L["Copy of %s"] = "Cópia de %s"
L["Copied \"%s\" to \"%s\"."] = "\"%s\" copiado para \"%s\"."
L["Rename Current Profile"] = "Renomear perfil atual"
L["Rename"] = "Renomear"
L["Rename Profile"] = "Renomear perfil"
L["Rename \"%s\" to:"] = "Renomear \"%s\" para:"
L["Renamed \"%s\" to \"%s\"."] = "\"%s\" renomeado para \"%s\"."
L["The last profile can't be deleted."] = "O último perfil não pode ser excluído."
L["Delete Current Profile"] = "Excluir perfil atual"
L["Delete"] = "Excluir"
L["Profile \"%s\" deleted; now using \"%s\"."] = "Perfil \"%s\" excluído; usando \"%s\" agora."
L["Delete Profile"] = "Excluir perfil"
L["Delete the profile \"%s\"? Its settings will be lost. Choose the profile to use instead:"] = "Excluir o perfil \"%s\"? As configurações dele serão perdidas. Escolha o perfil a usar no lugar:"
L["Delete the profile \"%s\"? Its settings will be lost, and \"%s\" becomes active."] = "Excluir o perfil \"%s\"? As configurações dele serão perdidas, e \"%s\" ficará ativo."
L["Reset Current Profile"] = "Redefinir perfil atual"
L["Profile \"%s\" reset."] = "Perfil \"%s\" redefinido."
L["Reset the profile \"%s\" to default settings?"] = "Redefinir o perfil \"%s\" para as configurações padrão?"
L["Export Current Profile"] = "Exportar perfil atual"
L["Export"] = "Exportar"
L["Export Profile"] = "Exportar perfil"
L["Import Profile"] = "Importar perfil"
L["Import"] = "Importar"
L["Paste a profile string. Importing creates a new profile."] = "Cole um texto de perfil. Importar cria um novo perfil."
L["Imported \"%s\" as \"%s\"."] = "\"%s\" importado como \"%s\"."
L["Profiles"] = "Perfis"
L["Manage"] = "Gerenciar"
L["Share"] = "Compartilhar"
