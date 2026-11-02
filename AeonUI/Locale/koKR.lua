if GetLocale() ~= "koKR" then
	return
end

local L = select(2, ...).L

-- Chat messages (Core)
L["AeonUI is off for this session, so its settings can't open."] = "이번 세션에서는 AeonUI가 꺼져 있어 설정을 열 수 없습니다."
L["your character could not be identified, so AeonUI is off for this session."] = "캐릭터를 확인할 수 없어 이번 세션에서는 AeonUI가 꺼집니다."
L["saved settings failed to load, so AeonUI is off for this session."] = "저장된 설정을 불러오지 못해 이번 세션에서는 AeonUI가 꺼집니다."
L["saved settings come from a newer version of AeonUI, so this version is using default settings and leaves them unchanged."] = "저장된 설정이 더 최신 버전의 AeonUI에서 만들어져, 이 버전은 기본 설정을 사용하며 저장된 설정은 그대로 둡니다."
L["saved settings are damaged, so AeonUI is using default settings and leaves them unchanged until you reset them."] = "저장된 설정이 손상되어 AeonUI가 기본 설정을 사용하며, 초기화할 때까지 저장된 설정은 그대로 둡니다."
L["the active profile can't be used, so AeonUI is showing default settings until you choose another profile."] = "활성 프로필을 사용할 수 없어, 다른 프로필을 선택할 때까지 AeonUI가 기본 설정을 표시합니다."

-- Profile names (Profile)
L["A profile needs a name."] = "프로필 이름이 필요합니다."
L["A profile name can be %d letters at most."] = "프로필 이름은 최대 %d자까지 가능합니다."
L["That name belongs to the default profile."] = "기본 프로필의 이름입니다."
L["A profile with that name already exists."] = "같은 이름의 프로필이 이미 있습니다."

-- Profile strings (Profile)
L["This is not an AeonUI profile string, or it was cut short."] = "AeonUI 프로필 문자열이 아니거나 문자열이 잘렸습니다."
L["This profile string was made by a newer version of AeonUI."] = "이 프로필 문자열은 더 최신 버전의 AeonUI에서 만들어졌습니다."
L["This profile string holds settings AeonUI can't use."] = "이 프로필 문자열에는 AeonUI가 사용할 수 없는 설정이 들어 있습니다."

-- Minimap button tooltip (Core)
L["Click: open settings"] = "클릭: 설정 열기"

-- Key bindings (Core)
L["Eject All Passengers"] = "모든 승객 내보내기"

-- Page titles (Settings)
L["Profiles"] = "프로필"
L["Recovery"] = "복구"
L["Unit Frames"] = "유닛 프레임"
L["Maps"] = "지도"
L["Quality of Life"] = "편의 기능"

-- Shared settings labels (Settings)
L["Auctionator, TSM or Oribos Exchange provides auction prices."] = "Auctionator, TSM 또는 Oribos Exchange가 경매장 가격을 제공합니다."
L["Access"] = "접근"
L["Text"] = "글자"
L["Open"] = "열기"
L["Font"] = "글꼴"
L["Outline"] = "외곽선"
L["Font Scale"] = "글꼴 배율"
L["Height"] = "높이"
L["X Offset"] = "X 오프셋"
L["Y Offset"] = "Y 오프셋"
L["Scale"] = "크기 비율"
L["Crafting Orders"] = "제작 주문"
L["Modifier"] = "보조 키"
L["Visibility"] = "표시"
L["Show"] = "표시"
L["Size"] = "크기"
L["Border"] = "테두리"
L["Border Style"] = "테두리 스타일"
L["Forever Minimal"] = "Forever Minimal"
L["Forever"] = "Forever"
L["Slate"] = "슬레이트"
L["Thin Line"] = "가는 선"
L["Border Color"] = "테두리 색상"
L["Needs a border style."] = "테두리 스타일이 필요합니다."
L["Forever keeps its own colors."] = "Forever는 고유 색상을 유지합니다."
L["Border Thickness"] = "테두리 두께"
L["Casting"] = "시전 중"
L["Class Color"] = "직업 색상"
L["Texture"] = "텍스처"
L["Horizontal"] = "가로"
L["Vertical"] = "세로"
L["Left"] = "왼쪽"
L["Right"] = "오른쪽"
L["Bar"] = "바"
L["Tooltip"] = "툴팁"
L["Blizzard"] = "블리자드"
L["Square"] = "사각형"
L["White"] = "흰색"
L["Width"] = "너비"
L["Food"] = "음식"
L["A"] = "A"
L["Layout"] = "배치"

-- General page (Settings)
L["Show Minimap Button"] = "미니맵 버튼 표시"
L["Left-click opens settings."] = "왼쪽 클릭으로 설정을 엽니다."
L["Goes below the game's own minimum. Turning it off needs a reload."] = "게임 최소값보다 작게 할 수 있습니다. 끄려면 UI를 다시 불러와야 합니다."
L["%s manages the UI scale."] = "%s 애드온이 UI 크기를 관리합니다."
L["Pixel Perfect"] = "픽셀 퍼펙트"
L["One interface unit per pixel on this screen."] = "이 화면에서 인터페이스 1단위가 1픽셀입니다."
L["Pixel Perfect For"] = "해상도별 픽셀 퍼펙트"
L["Game Menu Scale"] = "게임 메뉴 크기"

-- Shared by the world map marker tooltips (World Map) and the Delete Cheapest Item rows (DeleteCheapestItem)
L["Vendor"] = "상인"

-- Shared by the Delete Cheapest Item rows (DeleteCheapestItem) and the item tooltips' auction price line on a
-- client without realms (Tooltip)
L["Auction"] = "경매"

-- Profiles page (Settings)
L["AeonUI profile \"%s\"."] = "AeonUI 프로필 \"%s\"."
L["It holds %d settings this version doesn't use; they are kept."] = "이 버전에서 사용하지 않는 설정 %d개가 들어 있으며, 그대로 보관됩니다."
L["Damaged Profiles"] = "손상된 프로필"
L["The active profile can't be used, so default settings are shown. Choose another profile or delete it."] = "활성 프로필을 사용할 수 없어 기본 설정을 표시합니다. 다른 프로필을 선택하거나 이 프로필을 삭제하세요."
L["These profiles can't be used. They are kept unchanged until you delete them."] = "이 프로필들은 사용할 수 없습니다. 삭제할 때까지 그대로 보관됩니다."
L["Delete the damaged profile \"%s\"? Characters using it switch to another profile."] = "손상된 프로필 \"%s\"을(를) 삭제하시겠습니까? 이 프로필을 사용하는 캐릭터는 다른 프로필로 전환됩니다."
L["Create another profile first."] = "먼저 다른 프로필을 만드세요."

-- Recovery page (Settings)
L["AeonUI's saved settings can't be used, so its other pages are unavailable."] = "AeonUI의 저장된 설정을 사용할 수 없어 다른 페이지를 이용할 수 없습니다."
L["Saved Settings"] = "저장된 설정"
L["Your saved settings are damaged. AeonUI shows default settings and leaves them unchanged until you reset them."] = "저장된 설정이 손상되었습니다. AeonUI는 기본 설정을 표시하며, 초기화할 때까지 저장된 설정은 그대로 둡니다."
L["Your saved settings come from a newer version of AeonUI. This version shows default settings and leaves them unchanged."] = "저장된 설정이 더 최신 버전의 AeonUI에서 만들어졌습니다. 이 버전은 기본 설정을 표시하며 저장된 설정은 그대로 둡니다."
L["Diagnostic Export"] = "진단 내보내기"
L["Diagnostic Export (Incomplete)"] = "진단 내보내기 (불완전)"
L["The saved settings as text, to keep or to share when reporting the problem. It is not a profile string."] = "저장된 설정을 텍스트로 표시합니다. 보관하거나 문제를 보고할 때 공유하세요. 프로필 문자열이 아닙니다."
L["Reset Saved Settings"] = "저장된 설정 초기화"
L["Erase every AeonUI profile and setting on this account and start again with defaults."] = "이 계정의 모든 AeonUI 프로필과 설정을 지우고 기본 설정으로 다시 시작합니다."
L["Erase every AeonUI profile and setting on this account? This cannot be undone."] = "이 계정의 모든 AeonUI 프로필과 설정을 지우시겠습니까? 되돌릴 수 없습니다."
L["Type %s to erase every AeonUI profile and setting on this account."] = "이 계정의 모든 AeonUI 프로필과 설정을 지우려면 %s을(를) 입력하세요."

-- Shared by the world map and other features
L["Azuregos"] = "아주어고스"
L["Dungeon"] = "던전"
L["Raid"] = "공격대"
L["Innkeeper"] = "여관주인"
L["Mailbox"] = "우체통"
L["Banker"] = "은행원"
L["Auctioneer"] = "경매인"
L["Reagents"] = "시약"
L["Ammunition"] = "탄약"
