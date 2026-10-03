if GetLocale() ~= "koKR" then
	return
end

local L = select(2, ...).AeonSettings.L

-- Control.lua
L["Couldn't save %s."] = "%s을(를) 저장하지 못했습니다."

-- PageModel.lua
L["Requires %s to be enabled."] = "%s 활성화가 필요합니다."

-- Window.lua
L["Reset %s to defaults?"] = "%s을(를) 기본값으로 초기화하시겠습니까?"
L["Reset"] = "초기화"
L["Unavailable in combat."] = "전투 중에는 사용할 수 없습니다."
L["1 change needs a reload"] = "변경 사항 1개는 UI를 다시 불러와야 적용됩니다"
L["%d changes need a reload"] = "변경 사항 %d개는 UI를 다시 불러와야 적용됩니다"
L["%s reset to defaults."] = "%s을(를) 기본값으로 초기화했습니다."
L['Search results for "%s"'] = '"%s" 검색 결과'
L["No settings match."] = "일치하는 설정이 없습니다."

-- Row.lua
L["Shared"] = "공유"
L["Custom"] = "사용자 지정"
L["Use Shared"] = "공유 값 사용"
L["Removes this value so the setting follows the shared one again."] = "이 값을 제거하여 설정이 다시 공유 값을 따르게 합니다."

-- Preview.lua
L["Click an element to find its settings"] = "요소를 클릭하면 해당 설정을 찾습니다"

-- SoundCheckbox.lua
L["Play sound"] = "소리 재생"

-- TextInput.lua
L["it can't be empty."] = "비워 둘 수 없습니다."
L["It can be %d letters at most."] = "최대 %d자까지 입력할 수 있습니다."
L["Couldn't save %s: %s"] = "%s을(를) 저장하지 못했습니다: %s"

-- ActionButton.lua
L["Couldn't %s."] = "%s 작업을 할 수 없습니다."

-- ProfileDialog.lua
L["Press Ctrl+C to copy the text below."] = "Ctrl+C를 눌러 아래 텍스트를 복사하세요."

-- Profiles.lua
L["\"%s\" is the built-in profile's name."] = "\"%s\"은(는) 기본 제공 프로필의 이름입니다."
L["A profile named \"%s\" already exists."] = "\"%s\" 이름의 프로필이 이미 있습니다."
L["Unavailable while editing the layout."] = "레이아웃 편집 중에는 사용할 수 없습니다."
L["Active Profile"] = "현재 프로필"
L["Use a Profile for This Character"] = "이 캐릭터 전용 프로필 사용"
L["Switches to a profile named after this character, made the first time."] = "이 캐릭터 이름의 프로필로 전환합니다. 처음에는 새로 만듭니다."
L["New Profile"] = "새 프로필"
L["New"] = "새로 만들기"
L["Create"] = "생성"
L["Name the new profile. It starts with default settings."] = "새 프로필의 이름을 입력하세요. 기본 설정으로 시작합니다."
L["Profile name"] = "프로필 이름"
L["Profile \"%s\" created."] = "\"%s\" 프로필을 만들었습니다."
L["Copy Current Profile"] = "현재 프로필 복사"
L["Copy"] = "복사"
L["Copy Profile"] = "프로필 복사"
L["Name the copy of \"%s\"."] = "\"%s\" 사본의 이름을 입력하세요."
L["Copy of %s"] = "%s 사본"
L["Copied \"%s\" to \"%s\"."] = "\"%s\"을(를) \"%s\"(으)로 복사했습니다."
L["Rename Current Profile"] = "현재 프로필 이름 변경"
L["Rename"] = "이름 변경"
L["Rename Profile"] = "프로필 이름 변경"
L["Rename \"%s\" to:"] = "\"%s\"의 새 이름:"
L["Renamed \"%s\" to \"%s\"."] = "\"%s\"의 이름을 \"%s\"(으)로 변경했습니다."
L["The last profile can't be deleted."] = "마지막 프로필은 삭제할 수 없습니다."
L["Delete Current Profile"] = "현재 프로필 삭제"
L["Delete"] = "삭제"
L["Profile \"%s\" deleted; now using \"%s\"."] = "\"%s\" 프로필을 삭제했습니다. 이제 \"%s\" 프로필을 사용합니다."
L["Delete Profile"] = "프로필 삭제"
L["Delete the profile \"%s\"? Its settings will be lost. Choose the profile to use instead:"] = "\"%s\" 프로필을 삭제하시겠습니까? 설정이 사라집니다. 대신 사용할 프로필을 선택하세요:"
L["Delete the profile \"%s\"? Its settings will be lost, and \"%s\" becomes active."] = "\"%s\" 프로필을 삭제하시겠습니까? 설정이 사라지며 \"%s\" 프로필이 활성화됩니다."
L["Reset Current Profile"] = "현재 프로필 초기화"
L["Profile \"%s\" reset."] = "\"%s\" 프로필을 초기화했습니다."
L["Reset the profile \"%s\" to default settings?"] = "\"%s\" 프로필을 기본 설정으로 초기화하시겠습니까?"
L["Export Current Profile"] = "현재 프로필 내보내기"
L["Export"] = "내보내기"
L["Export Profile"] = "프로필 내보내기"
L["Import Profile"] = "프로필 가져오기"
L["Import"] = "가져오기"
L["Paste a profile string. Importing creates a new profile."] = "프로필 문자열을 붙여 넣으세요. 가져오면 새 프로필이 생성됩니다."
L["Imported \"%s\" as \"%s\"."] = "\"%s\"을(를) \"%s\"(으)로 가져왔습니다."
L["Profiles"] = "프로필"
L["Manage"] = "관리"
L["Share"] = "공유"
