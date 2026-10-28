# 개별 스타일 인덱스

UI 아이콘은 `AppIcons`의 Google Material Symbols Rounded로 통일했어요. 이전 아이콘 Painter의 선 두께·좌표 보정은 제거했고, 파형·진행 바·말풍선·트림 선택 영역의 도형은 유지해요. [아이콘 규격](design-system.md#아이콘)을 참고해요.

[디자인 시스템 정리와 용도별 설명](design-system.md)에서 주요 항목을 먼저 확인할 수 있어요.

현재 코드에 남아 있는 UI 수치·색상·투명도·글자 보정·시간의 위치를 찾기 위한 인덱스예요. 같은 파일 안에서도 기능 공통 상수와 화면 전용 값이 섞여 있으므로, 항목 수를 디자인 시스템 위반 개수로 해석하지 않아요. 값이 같다는 이유만으로 크기·간격·도형·제스처 기준을 서로 연결하지 않아요.

- 대상: Flutter 디자인 시스템 컴포넌트와 로그인·채팅 presentation 코드의 직접 지정 값이에요. 기존 색상·간격·타이포그래피 토큰 선언 자체는 제외했어요.
- 표에는 비영점 수치가 있는 UI 생성자, 레이아웃 속성, 색상·알파, 글자 보정, 로컬 실수 상수, 밀리초 지정 위치를 모았어요. 동작에 쓰는 지연 시간도 구분해서 표시해요.
- 좌표 0, 애니메이션 경계 0/1, 데이터·캐시 한도, 날짜·파일 용량 계산을 모두 나열하는 목록은 아니에요. 벡터 도형의 좌표는 아래 Painter 목록에서 해당 구현을 확인할 수 있어요.
- 기준은 이 리팩터링 직후 코드예요. 소스가 바뀌면 행 번호도 달라질 수 있어요.

## 현재 관리 방식

2026-10-27 공통화 재정리에서 단독 스타일 파일 20개를 제거했어요. 아래의 수치·색상·동작은 그대로이며, 단독 값은 실제 위젯에 직접 두고 배치·계산에 공통인 값만 해당 컴포넌트의 상수로 관리해요. `AppSpacing`·`AppColors` 등 기존 토큰은 별칭 없이 사용해요. 현재 정의 위치를 아래 링크에 반영했어요.

## 검색 확장 이후 변경한 규격

타이포그래피는 [Yeoul 역할별 규격](design-system.md#pretendard-타이포그래피)으로 갱신했어요. 아래 옛 행 번호의 `Medium`·`Semibold` 참조는 현재 Regular·Bold로 통일되어 있으며, 글꼴은 Pretendard예요. 채팅·미디어의 전용 크기·행간은 유지해요.

기존 검색 입력·툴바·달력 확인 버튼의 개별 구현은 제거하거나 공통 컨트롤로 교체했어요. 해당 항목은 아래 현재 기준으로 확인해요. 나머지 인덱스의 행 번호는 최초 정리 시점 기준이에요.

| 위치 | 값 | 관리 방식 |
| --- | --- | --- |
| [AppControlStyle](../mobile/lib/design_system/app_control_style.dart) | 버튼·한 줄 입력 높이 46, 버튼 반경 10, 입력 반경 8, 테두리 `#D8DEE5` | Yeoul에서 가져온 공통 규격. `AppButton`·`AppIconButton`·`AppTextField`·테마가 공유 |
| [검색 상단](../mobile/lib/features/chat/presentation/chat_search_widgets.dart) | 제목 56·입력 46·탭 44·페이드 끝 여백 12·상태 줄 32 | 현재 모양 유지로 검토 완료. 실제 배치와 높이 계산이 같은 규격을 참조하며 기존 제목·입력·페이드 재사용 |
| [검색 결과 카드·격자](../mobile/lib/features/chat/presentation/chat_search_widgets.dart) | 미디어 3열·간격 8, 링크/파일 2열·간격 12, 카드 미리보기 104·설명 영역 128 | 현재 모양 유지로 검토 완료. 카드 미리보기와 격자 높이 계산이 같은 규격을 참조하며 기존 공통 카드·미리보기 사용 |
| [검색 필터](../mobile/lib/features/chat/presentation/chat_search_widgets.dart) | 필터 줄 높이 56·좌우 여백 16·간격 8, 칩 안쪽 여백 12/8·닫기 아이콘 20 | 현재 모양 유지로 검토 완료. `_SearchFilterChip`에서 관리하며 종류·날짜 표시가 같은 필터 컴포넌트를 사용. 공통 달력 버튼과 종류 선택·날짜 선택/해제·가로 스크롤 유지 |
| [날짜 선택창](../mobile/lib/features/chat/presentation/chat_conversation_view.dart) | 위아래 여백 22, 헤더 48·화살표 32, 날짜 셀 42, 연월 선택 줄 45·영역 156, 내부 간격 18·14·10·36·42 | 현재 모양 유지로 검토 완료. `_SearchDateSheet`이 크기·간격·글자 스타일을 관리하며 연·월 휠과 선택 배경의 높이를 공유 |
| [메시지 검색 툴바](../mobile/lib/features/chat/presentation/chat_conversation_view.dart) | 입력창과 같은 높이 48·모서리 24·패딩 8·좌우 여백 10, 오른쪽 원형 버튼 32·아이콘 20·간격 4 | `_ComposerSurface`·`_ComposerCircleButton.neutral` 재사용. 달력은 투명 배경, 이동 비활성 색상은 `textDisabled`. 결과 숫자의 중앙 정렬과 기존 동작 유지 |

## app_button.dart

소스: [mobile/lib/design_system/components/app_button.dart](../mobile/lib/design_system/components/app_button.dart)

로딩 표시는 현재 규격 유지로 검토를 마쳤어요. 크기 20·선 두께 2·전환 150ms와 로딩 중 비활성화를 기존 `AppButton`에서 계속 관리해요.

| 구간 | 종류 | 위치 | 직접 지정한 값·표현 |
| --- | --- | --- | --- |
| `AppButton` | 전환·지연 시간 | [L34](../mobile/lib/design_system/components/app_button.dart#L34) | `Duration(milliseconds: 150)` |
| `AppButton` | 속성 보정 | [L38](../mobile/lib/design_system/components/app_button.dart#L38) | `dimension: 20` |
| `AppButton` | 속성 보정 | [L40](../mobile/lib/design_system/components/app_button.dart#L40) | `strokeWidth: 2` |

## app_launch_screen.dart

소스: [mobile/lib/design_system/components/app_launch_screen.dart](../mobile/lib/design_system/components/app_launch_screen.dart)

현재 규격 유지로 검토를 마쳤어요. 로고 144×144·흰 배경·중앙 배치, 최소 2초와 첫 화면 준비를 기다리는 조건, 250ms 페이드를 기존 공통 컴포넌트에서 유지해요.

| 구간 | 종류 | 위치 | 직접 지정한 값·표현 |
| --- | --- | --- | --- |
| `_AppLaunchGateState` | 전환·지연 시간 | [L20](../mobile/lib/design_system/components/app_launch_screen.dart#L20) | `Duration(milliseconds: 250)` |
| `_AppLaunchGateState` | 속성 보정 | [L67](../mobile/lib/design_system/components/app_launch_screen.dart#L67) | `opacity: _isRevealing ? 0 : 1` |
| `AppLogo` | 브랜드 심벌 크기 | [L4](../mobile/lib/design_system/components/app_logo.dart#L4) | `size = 144` — 로그인·시작 화면·네이티브 시작 화면의 공통 규격 |

## app_media_viewer_chrome.dart

소스: [mobile/lib/design_system/components/app_media_viewer_chrome.dart](../mobile/lib/design_system/components/app_media_viewer_chrome.dart)

현재 규격 유지로 검토를 마쳤어요. 사진·영상 뷰어와 편집 화면이 이미 공통 구현을 재사용하므로 추가 분리 없이 유지해요.

| 구간 | 종류 | 위치 | 직접 지정한 값·표현 |
| --- | --- | --- | --- |
| `AppMediaViewerChrome` | 색상 | [L6](../mobile/lib/design_system/components/app_media_viewer_chrome.dart#L6) | `Color(0xFF202020)` |
| `AppMediaViewerChrome` | 색상 | [L7](../mobile/lib/design_system/components/app_media_viewer_chrome.dart#L7) | `Color(0xFF272727)` |
| `AppMediaViewerChrome` | 색상 | [L8](../mobile/lib/design_system/components/app_media_viewer_chrome.dart#L8) | `Color(0xFF4E4E4E)` |
| `AppMediaViewerChrome` | 색상 | [L9](../mobile/lib/design_system/components/app_media_viewer_chrome.dart#L9) | `Color(0xFFE8E8E8)` |
| `AppMediaViewerChrome` | 색상 | [L11](../mobile/lib/design_system/components/app_media_viewer_chrome.dart#L11) | `Color(0xFFF2F2F2)` |
| `AppMediaViewerChrome` | 로컬 수치 | [L12](../mobile/lib/design_system/components/app_media_viewer_chrome.dart#L12) | `static const double buttonDimension = 44;` |
| `AppMediaViewerChrome` | 로컬 수치 | [L14](../mobile/lib/design_system/components/app_media_viewer_chrome.dart#L14) | `static const double trailingSpacing = 23;` |
| `AppMediaViewerChrome` | 전환·지연 시간 | [L15](../mobile/lib/design_system/components/app_media_viewer_chrome.dart#L15) | `Duration(milliseconds: 200)` |
| `AppTopBarButtonSurface` | 공통 모서리 계산 | [borderRadiusForHeight](../mobile/lib/design_system/components/app_media_viewer_chrome.dart) | `height / 2` 계산을 버튼 표면과 사진 편집 Send 터치 영역이 공유. 현재 공통 높이 44에서 모서리 22 유지 |
| `AppTopBarButtonSurface` | 속성 보정 | [L75](../mobile/lib/design_system/components/app_media_viewer_chrome.dart#L75) | `width: 0.67)` |
| `AppTopBarBackIcon` | 크기·좌표 | [L136](../mobile/lib/design_system/components/app_media_viewer_chrome.dart#L136) | `Size.square(24)` |
| `AppMediaEditIcon` | 로컬 수치 | [L149](../mobile/lib/design_system/components/app_media_viewer_chrome.dart#L149) | `static const double referenceButtonDimension = 48;` |
| `AppMediaEditIcon` | 로컬 수치 | [L150](../mobile/lib/design_system/components/app_media_viewer_chrome.dart#L150) | `static const double referenceDimension = 24;` |

## app_theme.dart

소스: [mobile/lib/design_system/app_theme.dart](../mobile/lib/design_system/app_theme.dart)

| 구간 | 종류 | 위치 | 직접 지정한 값·표현 |
| --- | --- | --- | --- |
| `AppTheme` | 크기·좌표 | [L12](../mobile/lib/design_system/app_theme.dart#L12) | `Size(0, 56)` |
| `AppTheme` | 속성 보정 | [L164](../mobile/lib/design_system/app_theme.dart#L164) | `width: 1.5)` |
| `AppTheme` | 속성 보정 | [L172](../mobile/lib/design_system/app_theme.dart#L172) | `width: 1.5)` |
| `AppTheme` | 속성 보정 | [L226](../mobile/lib/design_system/app_theme.dart#L226) | `thickness: 1` |

## login_screen.dart

소스: [mobile/lib/features/auth/presentation/login_screen.dart](../mobile/lib/features/auth/presentation/login_screen.dart)

| 구간 | 종류 | 위치 | 직접 지정한 값·표현 |
| --- | --- | --- | --- |
| `_LoginScreenState` | 크기·좌표 | [L95](../mobile/lib/features/auth/presentation/login_screen.dart#L95) | `BoxConstraints(maxWidth: 480)` |

## chat_conversation_screen.dart

소스: [mobile/lib/features/chat/presentation/chat_conversation_screen.dart](../mobile/lib/features/chat/presentation/chat_conversation_screen.dart)

| 구간 | 종류 | 위치 | 직접 지정한 값·표현 |
| --- | --- | --- | --- |
| `파일 범위·도움 함수` | 로컬 수치 | [L23](../mobile/lib/features/chat/presentation/chat_conversation_screen.dart#L23) | `const double _chatListAvatarSize = 48;` |
| `파일 범위·도움 함수` | 전환·지연 시간 | [L27](../mobile/lib/features/chat/presentation/chat_conversation_screen.dart#L27) | `Duration(milliseconds: 190)` |
| `파일 범위·도움 함수` | 전환·지연 시간 | [L28](../mobile/lib/features/chat/presentation/chat_conversation_screen.dart#L28) | `Duration(milliseconds: 170)` |
| `파일 범위·도움 함수` | 로컬 수치 | [L29](../mobile/lib/features/chat/presentation/chat_conversation_screen.dart#L29) | `const double _chatRouteDismissProgress = 0.5;` |
| `파일 범위·도움 함수` | 로컬 수치 | [L30](../mobile/lib/features/chat/presentation/chat_conversation_screen.dart#L30) | `const double _chatRouteFlingVelocity = 700;` |
| `파일 범위·도움 함수` | 로컬 수치 | [L31](../mobile/lib/features/chat/presentation/chat_conversation_screen.dart#L31) | `const double _chatRouteDragSlop = 8;` |
| `_ChatConversationHomeScreenState` | 속성 보정 | [L824](../mobile/lib/features/chat/presentation/chat_conversation_screen.dart#L824) | `height: 1` |
| `_ChatConversationHomeScreenState` | 간격 | [L834](../mobile/lib/features/chat/presentation/chat_conversation_screen.dart#L834) | `EdgeInsets.symmetric( horizontal: _chatListHorizontalPadding, vertical: 6, )` |
| `_ChatConversationScreenState` | 전환·지연 시간 | [L916](../mobile/lib/features/chat/presentation/chat_conversation_screen.dart#L916) | `Duration(milliseconds: 400)` |
| `_ChatConversationScreenState` | 전환·지연 시간 | [L917](../mobile/lib/features/chat/presentation/chat_conversation_screen.dart#L917) | `Duration(milliseconds: 1200)` |
| `_ChatUserAvatar` | 속성 보정 | [L2020](../mobile/lib/features/chat/presentation/chat_conversation_screen.dart#L2020) | `top: -4` |
| `_ChatUserAvatar` | 속성 보정 | [L2021](../mobile/lib/features/chat/presentation/chat_conversation_screen.dart#L2021) | `right: -4` |
| `_ChatUnreadBadge` | 크기·좌표 | [L2040](../mobile/lib/features/chat/presentation/chat_conversation_screen.dart#L2040) | `BoxConstraints(minWidth: 18, minHeight: 18)` |
| `_ChatUnreadBadge` | 간격 | [L2041](../mobile/lib/features/chat/presentation/chat_conversation_screen.dart#L2041) | `EdgeInsets.symmetric(horizontal: 5)` |
| `_ChatUnreadBadge` | 속성 보정 | [L2053](../mobile/lib/features/chat/presentation/chat_conversation_screen.dart#L2053) | `height: 1` |
| `_ChatLoadingError` | 속성 보정 | [L2082](../mobile/lib/features/chat/presentation/chat_conversation_screen.dart#L2082) | `height: 14)` |

## chat_conversation_view.dart

소스: [mobile/lib/features/chat/presentation/chat_conversation_view.dart](../mobile/lib/features/chat/presentation/chat_conversation_view.dart)

| 구간 | 종류 | 위치 | 직접 지정한 값·표현 |
| --- | --- | --- | --- |
| `입력창·빠른 사진·복사 안내 배치` | 입력창 외부 간격 | [ChatComposerStyle](../mobile/lib/features/chat/presentation/chat_composer_style.dart) | 좌우 여백 10·키보드/패널 위 여백 10·메시지 간격 `AppSpacing.space12`를 기존 배치 계산에서 공유 |
| `통화·녹음·오디오 출력 시트` | 모서리·패딩 | [ChatActionSheetStyle](../mobile/lib/features/chat/presentation/chat_action_sheet_style.dart) | 반경 24 공유. 통화 시작·녹음은 기존 18/26/22 패딩 유지. 출력 선택은 승인 시안의 좌우/하단 24·상단 12, 안전 영역은 한 번만 더함 |
| `파일 범위·도움 함수` | 로컬 수치 | [L82](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L82) | `const double _attachmentPanelFallbackHeight = 302;` |
| `파일 범위·도움 함수` | 전환·지연 시간 | [L88](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L88) | `Duration( milliseconds: 180, )` |
| `파일 범위·도움 함수` | 전환·지연 시간 | [L92](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L92) | `Duration(milliseconds: 120)` |
| `파일 범위·도움 함수` | 전환·지연 시간 | [L94](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L94) | `Duration(milliseconds: 80)` |
| `파일 범위·도움 함수` | 전환·지연 시간 | [L96](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L96) | `Duration(milliseconds: 180)` |
| `파일 범위·도움 함수` | 로컬 수치 | [L379](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L379) | `const double horizontalOverflow = 8;` |
| `_ChatConversationViewState` | 전환·지연 시간 | [L747](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L747) | `Duration(milliseconds: 260)` |
| `_ChatConversationViewState` | 전환·지연 시간 | [L754](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L754) | `Duration(milliseconds: 550)` |
| `_ChatConversationViewState` | 속성 보정 | [L876](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L876) | `width: 256` |
| `_ChatConversationViewState` | 속성 보정 | [L877](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L877) | `height: 256` |
| `_openLegacyQuickPhotoPreview` | 빠른 사진 확인 화면 전환 | [_QuickPhotoPreviewScreen](../mobile/lib/features/chat/presentation/chat_conversation_view.dart) | 열기 180ms·닫기 160ms. 기존 `PageRouteBuilder`·`FadeTransition`과 플랫폼 분기 유지 |
| `_ChatConversationViewState` | 속성 보정 | [L1852](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L1852) | `maxWidth: 1920` |
| `_ChatConversationViewState` | 속성 보정 | [L1907](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L1907) | `width: width > 0 ? width : 1080` |
| `_ChatConversationViewState` | 속성 보정 | [L1908](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L1908) | `height: height > 0 ? height : 1440` |
| `_ChatConversationViewState` | 투명도 | [L2040](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L2040) | `AppColors.black.withAlpha(112)` |
| `_ChatConversationViewState` | 전환·지연 시간 | [L2177](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L2177) | `Duration(milliseconds: 300)` |
| `_ChatConversationViewState` | 전환·지연 시간 | [L2189](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L2189) | `Duration(milliseconds: 500)` |
| `_ChatConversationViewState` | 전환·지연 시간 | [L2282](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L2282) | `Duration(milliseconds: 500)` |
| `_ChatConversationViewState` | 전환·지연 시간 | [L2324](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L2324) | `Duration(milliseconds: 700)` |
| `_ChatConversationViewState` | 전환·지연 시간 | [L2415](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L2415) | `Duration(milliseconds: 180)` |
| `_ChatConversationViewState` | 전환·지연 시간 | [L2450](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L2450) | `Duration(milliseconds: 260)` |
| `_ChatConversationViewState` | 투명도 | [L2753](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L2753) | `AppColors.black.withAlpha(112)` |
| `_ChatConversationViewState` | 전환·지연 시간 | [L2866](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L2866) | `Duration(milliseconds: 16)` |
| `_ChatConversationViewState` | 투명도 | [L3155](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L3155) | `AppColors.black.withAlpha(112)` |
| `_ChatConversationViewState` | 투명도 | [L3363](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L3363) | `AppColors.black.withAlpha(112)` |
| `_ChatConversationViewState` | 색상 | [L3763](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L3763) | `Color(0x52000000)` |
| `_ChatConversationViewState` | 속성 보정 | [L3784](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L3784) | `left: 20` |
| `_ChatConversationViewState` | 속성 보정 | [L3785](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L3785) | `right: 20` |
| `_QuickPhotoPrompt` | 빠른 사진 전송 카드 전용 규격 | [_QuickPhotoPrompt](../mobile/lib/features/chat/presentation/chat_conversation_view.dart) | 현재 모양 유지로 검토 완료. 너비 비율·범위 68~76·버튼 영역 50, 모서리 17/22·여백 6/9·그림자·글자와 등장/숨김 효과를 연결. 사진과 Send 버튼은 같은 탭 피드백·사진 확인 콜백 사용 |
| `_ChatConversationViewState`·`_QuickPhotoPrompt` | 표시·숨김 시간 | [_QuickPhotoPrompt](../mobile/lib/features/chat/presentation/chat_conversation_view.dart) | 표시 10초·전환 180ms. 숨김 페이드와 카드 제거 타이머가 같은 전환 시간을 공유. 최근 15초 사진·중복 표시 방지·표시 상태에 따른 터치 제한은 기존 동작 유지 |
| `_QuickPhotoPreviewScreenState` | 빠른 사진 확인 화면 전용 규격 | [_QuickPhotoPreviewScreen](../mobile/lib/features/chat/presentation/chat_conversation_view.dart) | 현재 모양 유지로 검토 완료. 화면·시스템 하단 배경 공유, 안전 여백·버튼 배치·글자 연결. 기존 사진 조회·교체·Hero·취소·전송 콜백 유지 |
| `_ChatTopBar` | 로컬 수치 | [L4113](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L4113) | `static const double height = 56;` |
| `_ChatTopBar` | 로컬 수치 | [L4115](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L4115) | `static const double _actionsWidth = 88;` |
| `_ChatTopBar` | 속성 보정 | [L4151](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L4151) | `left: 112` |
| `_ChatTopBar` | 속성 보정 | [L4153](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L4153) | `right: 112` |
| `_ChatTopBar` | 모서리 | [L4185](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L4185) | `BorderRadius.circular( AppMediaViewerChrome.buttonDimension / 2, )` |
| `_ChatTopBar` | 속성 보정 | [L4195](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L4195) | `left: 37` |
| `_ChatTopBar` | 속성 보정 | [L4197](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L4197) | `right: 15` |
| `_ChatTopBar` | 속성 보정 | [L4256](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L4256) | `size: 25` |
| `_ChatTopBar` | 속성 보정 | [L4267](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L4267) | `size: 25` |
| `_ChatTopBarActionButton` | 모서리 | [L4310](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L4310) | `BorderRadius.circular( AppMediaViewerChrome.buttonDimension / 2, )` |
| `_ChatTopBarActionButton` | 속성 보정 | [L4314](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L4314) | `width: 40` |
| `_TopBarGradientBlur` | 투명도 | [L4380](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L4380) | `AppColors.surface.withAlpha(238)` |
| `_TopBarGradientBlur` | 투명도 | [L4381](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L4381) | `AppColors.surface.withAlpha(226)` |
| `_TopBarGradientBlur` | 투명도 | [L4382](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L4382) | `AppColors.surface.withAlpha(176)` |
| `_TopBarGradientBlur` | 투명도 | [L4383](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L4383) | `AppColors.surface.withAlpha(76)` |
| `_TopBarGradientBlur` | 투명도 | [L4384](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L4384) | `AppColors.surface.withAlpha(0)` |
| `_SearchDateSheetState` | 간격 | [L4869](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L4869) | `EdgeInsets.fromLTRB( AppSpacing.space24, 22, AppSpacing.space24, bottomPadding + 22, )` |
| `_SearchDateSheetState` | 속성 보정 | [L4887](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L4887) | `height: 48` |
| `_SearchDateSheetState` | 속성 보정 | [L4949](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L4949) | `height: 18)` |
| `_SearchDateSheetState` | 속성 보정 | [L4966](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L4966) | `height: 14)` |
| `_SearchDateSheetState` | 속성 보정 | [L4971](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L4971) | `mainAxisSpacing: 10` |
| `_SearchDateSheetState` | 속성 보정 | [L4972](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L4972) | `crossAxisSpacing: 4` |
| `_SearchDateSheetState` | 속성 보정 | [L5008](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L5008) | `height: 36)` |
| `_SearchDateSheetState` | 속성 보정 | [L5013](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L5013) | `height: 45` |
| `_SearchDateSheetState` | 속성 보정 | [L5020](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L5020) | `height: 156` |
| `_SearchDateSheetState` | 속성 보정 | [L5088](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L5088) | `height: 42)` |
| `_SearchDateSheetState` | 속성 보정 | [L5097](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L5097) | `width: 10)` |
| `_MonthChevronButton` | 속성 보정 | [L5131](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L5131) | `size: 32` |
| `_SearchDateCell` | 속성 보정 | [L5161](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L5161) | `dimension: 42` |
| `_CallNowSheet` | 간격 | [L5486](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L5486) | `EdgeInsets.fromLTRB(18, 26, 18, bottomPadding + 22)` |
| `_CallNowSheet` | 속성 보정 | [L5497](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L5497) | `height: 18)` |
| `_CallNowOption` | 속성 보정 | [L5542](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L5542) | `height: 68` |
| `_CallNowOption` | 속성 보정 | [L5548](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L5548) | `width: 40` |
| `_CallNowOption` | 속성 보정 | [L5549](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L5549) | `height: 40` |
| `_CallNowOption` | 모서리 | [L5553](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L5553) | `BorderRadius.all(Radius.circular(14))` |
| `_CallNowOption` | 속성 보정 | [L5555](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L5555) | `size: 21` |
| `_CallNowOption` | 속성 보정 | [L5557](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L5557) | `width: 14)` |
| `_VoiceMemoSheetState` | 전환·지연 시간 | [L5735](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L5735) | `Duration(milliseconds: 80)` |
| `녹음창 바깥 여백` | 간격 | [ChatActionSheetStyle](../mobile/lib/features/chat/presentation/chat_action_sheet_style.dart) | 기존 시트 공통 여백과 기기 안전 영역 사용 |
| `녹음 표시줄·재생·원형 버튼` | 전용 규격 | [_VoiceMemoRecorderControls](../mobile/lib/features/chat/presentation/chat_conversation_view.dart) | 표시줄 64·반경 14·좌우 18, 제목 간격 22·위치 보정 4·버튼 영역 간격 44, 재생 30, 원형 버튼 44·바깥 여백 5·전체 높이 54, 정지 아이콘 28·다시 녹음/전송 31, 파형/바깥 원 알파 126/24를 현재 모양 그대로 관리 |
| `_VoiceMemoWaveformPainter` | 속성 보정 | [L6308](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L6308) | `width: math.min(2.8` |
| `_VoiceMemoWaveformPainter` | 모서리 | [L6311](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L6311) | `Radius.circular(2)` |
| `_ActiveVoiceCallBanner` | 로컬 수치 | [L6336](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L6336) | `static const double _buttonHeight = 52;` |
| `_ActiveVoiceCallBanner` | 간격 | [L6352](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L6352) | `EdgeInsets.fromLTRB( 10, _verticalPadding, 0, _verticalPadding, )` |
| `_ActiveVoiceCallBanner` | 속성 보정 | [L6369](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L6369) | `width: connected ? 126 : 122` |
| `_ActiveVoiceCallBanner` | 속성 보정 | [L6376](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L6376) | `size: 28` |
| `_ActiveVoiceCallBanner` | 속성 보정 | [L6379](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L6379) | `width: connected ? 14 : 18)` |
| `_ActiveVoiceCallBanner` | 투명도 | [L6390](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L6390) | `AppColors.white.withAlpha(122)` |
| `통화·검색 공통 상단` | 공통 규격 | [ChatNavigationBar](../mobile/lib/features/chat/presentation/chat_navigation_bar.dart) | 상단 56, 원형 버튼 44, 제목 18/27 Bold. 채팅 상대방 이름과 글자 규격 공유 |
| `통화 컨트롤` | 공통 규격 | [AppRoundIconButton](../mobile/lib/design_system/components/app_round_icon_button.dart) | 지름 44·아이콘 24·테두리 0.67. 음소거/출력은 검정·회색, 종료는 빨강. 세 버튼을 같은 컴포넌트로 관리 |
| `통화 프로필·음소거 안내·출력 행` | 전용 규격 | [ChatVoiceCallScreen](../mobile/lib/features/chat/presentation/chat_voice_call_screen.dart) | 프로필 112·반경 32·아이콘 64, 안내 160×32, 출력 행 58·손잡이 44×5. 일반 간격과 모서리는 토큰 사용 |
| `_MessageListState` | 로컬 수치 | [L7246](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L7246) | `static const double _replyOriginalAlignment = 0.28;` |
| `_MessageListState` | 로컬 수치 | [L7247](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L7247) | `static const double _historyCenterContentInset = 44;` |
| `_MessageListState` | 전환·지연 시간 | [L7248](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L7248) | `Duration( milliseconds: 80, )` |
| `_MessageListState` | 전환·지연 시간 | [L7251](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L7251) | `Duration(milliseconds: 50)` |
| `_MessageListState` | 로컬 수치 | [L7253](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L7253) | `static const double _minimumHistoryPrefetchExtent = 2400;` |
| `_MessageListState` | 로컬 수치 | [L7254](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L7254) | `static const double _historyPrefetchViewportCount = 6;` |
| `_MessageListState` | 전환·지연 시간 | [L7258](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L7258) | `Duration( milliseconds: 400, )` |
| `_MessageListState` | 전환·지연 시간 | [L7261](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L7261) | `Duration(milliseconds: 50)` |
| `_MessageListState` | 스크롤 표시 전환 규격 | [_MessageScrollGeometry](../mobile/lib/features/chat/presentation/chat_conversation_view.dart) | 공통 등장 90ms, 날짜 숨김 대기/전환 120/170ms, 막대 숨김 대기/전환 520/260ms, 최신 메시지 이동 시 막대 유지 1초. 컨트롤러와 상태 조건 유지 |
| `_MessageListState` | 크기·좌표 | [L7624](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L7624) | `Size(1, metrics.viewportDimension)` |
| `_MessageListState` | 속성 보정 | [L8181](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L8181) | `width: nextVideo.width > 0 ? nextVideo.width : previousVideo.width` |
| `_MessageListState` | 속성 보정 | [L8182](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L8182) | `height: nextVideo.height > 0` |
| `_MessageListState` | 속성 보정 | [L8538](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L8538) | `width: sentVideo.width > 0 ? sentVideo.width : pendingVideo.width` |
| `_MessageListState` | 속성 보정 | [L8539](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L8539) | `height: sentVideo.height > 0 ? sentVideo.height : pendingVideo.height` |
| `_MessageListState` | 전환·지연 시간 | [L8907](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L8907) | `Duration(milliseconds: 180)` |
| `_MessageListState` | 전환·지연 시간 | [L9927](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L9927) | `Duration(milliseconds: 440)` |
| `_MessageListState` | 메시지 메뉴 전환 규격 | [_MessageActionMenu](../mobile/lib/features/chat/presentation/chat_conversation_view.dart) | 배경 검정 알파 31·전환 140ms·등장 `easeOutCubic`·닫힘 `easeInCubic`. 선택한 말풍선을 배경 위에 표시하는 기존 오버레이 유지 |
| `_MessageListState` | 말풍선 캡처 수명 | [메시지 메뉴 호출부](../mobile/lib/features/chat/presentation/chat_conversation_view.dart) | 닫힘 전환 후 캡처를 해제하는 기존 대기 160ms 유지. 표시 스타일과 구분 |
| `_MessageListState` | 속성 보정 | [L10716](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L10716) | `opacity: _didResolveInitialScrollPosition ? 1 : 0` |
| `_MessageListState` | 투명도 | [L10872](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L10872) | `AppColors.white.withAlpha(224)` |
| `_MessageListState` | 투명도 | [L10876](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L10876) | `AppColors.black.withAlpha(24)` |
| `_MessageListState` | 속성 보정 | [L10877](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L10877) | `blurRadius: 10` |
| `_MessageListState` | 속성 보정 | [L10897](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L10897) | `bottom: 8` |
| `_MessageListState` | 속성 보정 | [L10907](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L10907) | `right: 8` |
| `_MessageListState` | 속성 보정 | [L10908](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L10908) | `bottom: 8` |
| `_MessageListState` | 전환·지연 시간 | [L10913](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L10913) | `Duration(milliseconds: 180)` |
| `_MessageListState` | 전환·지연 시간 | [L10914](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L10914) | `Duration(milliseconds: 140)` |
| `_MessageListState` | 속성 보정 | [L11022](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L11022) | `height: 18));` |
| `_MessageScrollGeometry` | 스크롤 전용 규격 | [_MessageScrollGeometry](../mobile/lib/features/chat/presentation/chat_conversation_view.dart) | 두께 3·오른쪽 여백 2·오버스크롤 최소 길이 8. 스크롤바와 날짜 표시의 공통 위치 계산 유지 |
| `_MessageScrollbarPainter` | 모서리 | [L11354](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L11354) | `Radius.circular(geometry.thickness / 2)` |
| `_MessageScrollbarPainter` | 스크롤 색상 | [_MessageScrollGeometry](../mobile/lib/features/chat/presentation/chat_conversation_view.dart) | 기존 `grey700`·최대 알파 190. 애니메이션 값에 따른 알파 반올림과 범위 제한 유지 |
| `_MessageScrollDateBubbleOverlay` | 스크롤 날짜 전용 규격 | [_MessageScrollGeometry](../mobile/lib/features/chat/presentation/chat_conversation_view.dart) | 높이 24·막대와 간격 3·좌우 여백 10·검정 알파 105·완전 둥근 모서리·흰색 13/19.5 보통 글자. 표시 위치·날짜 선택·문구 포맷 유지 |
| `_ScrollToLatestMessageButton` | 투명도 | [L11467](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L11467) | `AppColors.black.withAlpha(31)` |
| `_ScrollToLatestMessageButton` | 속성 보정 | [L11468](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L11468) | `blurRadius: 12` |
| `_ScrollToLatestMessageButton` | 크기·좌표 | [L11469](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L11469) | `Offset(0, 4)` |
| `_ScrollToLatestMessageButton` | 속성 보정 | [L11481](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L11481) | `dimension: 44` |
| `_ScrollToLatestMessageButton` | 속성 보정 | [L11484](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L11484) | `size: 28` |
| `_BackToReplyMessageButton` | 속성 보정 | [L11505](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L11505) | `elevation: 4` |
| `_BackToReplyMessageButton` | 투명도 | [L11506](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L11506) | `AppColors.black.withAlpha(31)` |
| `_BackToReplyMessageButton` | 간격 | [L11513](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L11513) | `EdgeInsets.symmetric( horizontal: 15, vertical: AppSpacing.space8, )` |
| `_MessageActionMenuLayoutDelegate` | 메시지 메뉴 배치 규격 | [_MessageActionMenu](../mobile/lib/features/chat/presentation/chat_conversation_view.dart) | 최대 너비 288·좌우 안전 여백 16·상하 안전 여백 8·말풍선과 간격 6. 가로 중앙 정렬·아래 공간 부족 시 위에 표시하는 계산 유지 |
| `_MessageActionMenu` | 메시지 메뉴 표면 규격 | [_MessageActionMenu](../mobile/lib/features/chat/presentation/chat_conversation_view.dart) | 흰 배경·모서리 12·그림자 높이 4·검정 알파 31, 구분선 높이/두께 1·`grey100`. 기존 공통 메뉴 사용 |
| `_MessageActionMenuItem` | 메시지 메뉴 항목 규격 | [_MessageActionMenu](../mobile/lib/features/chat/presentation/chat_conversation_view.dart) | 높이 40·좌우 여백 14/12·아이콘 20, `typography6`·보통 굵기·일반 글자/아이콘 `grey900`/`grey700`·보내기 취소 `red500`. 같은 항목 컴포넌트에 액션만 전달 |
| `_ReplyMessageBody`·`_RenderReplyMessageLayout` | 답장 전용 규격 | [ChatMessageStyle](../mobile/lib/features/chat/presentation/chat_message_style.dart) | 현재 모양 유지로 검토 완료. 인용 제목/미리보기 스타일·구분선 색상, 제목 간격 1·구분선 두께 1·위아래 간격 7을 공유 |
| `_MessageEditStatusBody` | 수정 표시 규격 | [ChatMessageStyle](../mobile/lib/features/chat/presentation/chat_message_style.dart) | `editedLabel`의 방향별 색상·글꼴과 `editedLabelGap = 1` 사용 |
| `_DateSeparator` | 간격 | [L12039](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L12039) | `EdgeInsets.only( left: AppSpacing.space12, right: 7, top: 3, bottom: 3, )` |
| `_DateSeparator` | 속성 보정 | [L12055](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L12055) | `width: 2)` |
| `_DateSeparator` | 속성 보정 | [L12058](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L12058) | `size: 16` |
| `_IncomingMessageGroup` | 속성 보정 | [L12225](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L12225) | `size: 36` |
| `_IncomingMessageGroup` | 속성 보정 | [L12229](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L12229) | `width: 10)` |
| `_IncomingMessageRow` | 간격 | [L12529](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L12529) | `EdgeInsets.only(bottom: 1)` |
| `_IncomingMessageContent`·`_AnimatedTranslationText` | 번역 안내 규격 | [ChatMessageStyle](../mobile/lib/features/chat/presentation/chat_message_style.dart) | 현재 모양 유지로 검토 완료. 로딩·실패·재시도의 글자·여백·버튼, 로딩 크기 10·선 1.5·간격 5, 페이드 160ms·크기 전환 180ms 사용 |
| `_SearchHighlightedText` | 검색 강조 규격 | [ChatMessageStyle](../mobile/lib/features/chat/presentation/chat_message_style.dart) | `searchHighlightColor`에 기존 방향과 현재 결과 여부를 전달. 검색어 처리와 호출부의 상태 전달은 유지 |
| `_LinkMessageContent`·`_LinkPreviewCard` | 링크 카드 전용 규격 | [_LinkPreviewCard](../mobile/lib/features/chat/presentation/chat_conversation_view.dart) | 현재 모양 유지로 검토 완료. 최대 너비 316·본문과 간격 6·패딩 14/12/14/13·설명 간격 5·강조 테두리 1.6과 글자 스타일을 연결 |
| `_LinkPreviewImage` | 미리보기 이미지 규격 | [_LinkPreviewCard](../mobile/lib/features/chat/presentation/chat_conversation_view.dart) | 기본 비율 2:1·대체 표시 좌우 여백 18·글자 스타일을 연결. 검색에서 전달하는 고정 높이는 유지 |
| `_OutgoingMessageGroup` | 속성 보정 | [L13370](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L13370) | `height: 3)` |
| `_OutgoingMessageRow` | 간격 | [L13554](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L13554) | `EdgeInsets.only(bottom: 1)` |
| `_VideoMessageState` | 투명도 | [L13838](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L13838) | `AppColors.black.withAlpha(96)` |
| `_VideoMessageState` | 검색 결과 영상 타일 | [_SearchResultCard](../mobile/lib/features/chat/presentation/chat_search_widgets.dart) | 검색 사진과 모서리 12를 공유. 검색 영상 시간 배지의 위치·패딩·배경·아이콘·글자를 전용 규격에 연결. 기존 다운로드·열기와 채팅 영상 스타일 유지 |
| `_VideoDownloadRetryIndicator` | 속성 보정 | [L13864](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L13864) | `size: 24` |
| `_VideoEncodingIndicator` | 속성 보정 | [L13877](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L13877) | `dimension: 15` |
| `_VideoPlayIndicator` | 속성 보정 | [L13895](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L13895) | `size: 26` |
| `_MediaStatusIndicator` | 속성 보정 | [L13924](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L13924) | `dimension: 32` |
| `_MediaStatusIndicator` | 투명도 | [L13927](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L13927) | `AppColors.black.withAlpha(88)` |
| `_MediaStatusIndicator` | 속성 보정 | [L13936](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L13936) | `strokeWidth: 2.2` |
| `_MediaStatusIndicator` | 속성 보정 | [L13946](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L13946) | `height: 3)` |
| `_PhotoMessageState` | 전환·지연 시간 | [L14066](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L14066) | `Duration(milliseconds: 360)` |
| `_PhotoMessageState` | 투명도 | [L14229](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L14229) | `AppColors.black.withAlpha(70)` |
| `_PhotoUploadProgress` | 속성 보정 | [L14297](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L14297) | `size: 18` |
| `_PhotoUploadProgress` | 속성 보정 | [L14300](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L14300) | `dimension: 15` |
| `_PhotoMessageCollage` | 로컬 수치 | [L14389](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L14389) | `static const double _spacing = 2;` |
| `_PhotoMessageCollage` | 투명도 | [L14603](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L14603) | `AppColors.black.withAlpha(112)` |
| `_PhotoMessageImageState` | 속성 보정 | [L14944](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L14944) | `opacity: frame == null ? 0 : 1` |
| `_ActionConfirmationState`·`_ActionConfirmationCheckIcon` | 복사·저장 완료 안내 전용 규격 | [_ActionConfirmation](../mobile/lib/features/chat/presentation/chat_conversation_view.dart) | 현재 모양 유지로 검토 완료. 높이 56·좌우 여백 16/14.5·모서리 18·검정 알파 128·아이콘 24·글자 간격 12와 공통 글자 토큰을 연결. 복사·사진 저장·영상 저장은 기존 공통 컴포넌트를 사용 |
| `_ChatConversationViewState`·`_ActionConfirmationState` | 안내 배치·전환 | [_ActionConfirmation](../mobile/lib/features/chat/presentation/chat_conversation_view.dart) | 복사 안내와 입력창/검색 툴바 사이 간격 8, 오버슈트 13/3, 이동 3300ms·저장 페이드 2950ms. 구간별 시간과 곡선만 전용 규격으로 모으고 너비·위치 계산, 애니메이션 생성·상태·문구·완료 시점은 유지 |
| `_PhotoViewerScreenState` | 사진 선택·자동 스크롤 전환 | [_PhotoViewerThumbnail](../mobile/lib/features/chat/presentation/chat_conversation_view.dart) | 자동 스크롤 160ms·사진 선택 이동 180ms·`easeOutCubic`. 기존 `PageController`·`Scrollable.ensureVisible`과 중앙 정렬·호출 시점 유지 |
| `_VideoViewerScreenState` | 전환·지연 시간 | [L16032](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L16032) | `Duration(milliseconds: 1830)` |
| `_VideoViewerBottomOverlay`·`_VideoViewerTimeLabel`·`_VideoViewerProgressPainter` | 영상 재생 컨트롤 전용 규격 | [_VideoViewerBottomOverlay](../mobile/lib/features/chat/presentation/chat_conversation_view.dart) | 현재 모양 유지로 검토 완료. 배치 기준·시간 글자·진행바 선/손잡이·배경 페이드 연결. 현재/전체 시간은 같은 컴포넌트와 포맷 함수 사용 |
| `_VideoViewerBottomOverlay`·`_VideoViewerProgressScrubberState` | 공통 높이·기존 동작 | [_VideoViewerBottomOverlay](../mobile/lib/features/chat/presentation/chat_conversation_view.dart) | 행과 터치 영역이 높이 24를 공유. 진행바와 하단 액션의 배치 공식, 진행률·탭·드래그 좌표 변환·재생 제어는 기존 구현 유지. 표시/숨김은 기존 `AppMediaViewerChrome` 200ms 전환 사용 |
| `_PhotoViewerImageState` | 속성 보정 | [L17156](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L17156) | `opacity: wasSynchronouslyLoaded \|\| frame != null ? 1 : 0` |
| `_MediaViewerTopBar` | 미디어 상단 정보 전용 규격 | [_MediaViewerTopBar](../mobile/lib/features/chat/presentation/chat_conversation_view.dart) | 현재 모양 유지로 검토 완료. 이름 15/18·Bold, 날짜 13/16·Regular와 한 줄 말줄임을 연결. 사진·영상이 같은 상단바와 규격을 공유 |
| `_MediaViewerTopBar` | 공통 배치·전환 | [AppMediaViewerChrome](../mobile/lib/design_system/components/app_media_viewer_chrome.dart) | 기존 정보 영역 높이 44·좌우 여백·중앙 배치·200ms 전환 사용. 표시 상태에 따른 이동 오프셋·투명도·터치 제한, 이름 선택과 날짜 형식은 기존 구현 유지 |
| `_PhotoViewerBottomOverlay` | 크기·좌표 | [L17341](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L17341) | `Offset(0, 1)` |
| `_PhotoViewerBottomOverlay` | 속성 보정 | [L17346](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L17346) | `opacity: visible ? 1 : 0` |
| `_PhotoViewerBottomOverlay` | 썸네일 배경 위치 | [_PhotoViewerThumbnail](../mobile/lib/features/chat/presentation/chat_conversation_view.dart) | 위 위치 15 유지. 배경색·등장/숨김 전환은 기존 `AppMediaViewerChrome` 사용 |
| `_PhotoViewerThumbnailBar`·`_PhotoViewerThumbnail` | 사진 뷰어 썸네일 전용 규격 | [_PhotoViewerThumbnail](../mobile/lib/features/chat/presentation/chat_conversation_view.dart) | 현재 모양 유지로 검토 완료. 목록·순서 표시 배치와 선택별 크기·테두리·모서리를 한곳에서 관리. 기존 공통 사진 표시·콜백 유지 |
| `_CallMessageBubble`·`_callMessagePresentation` | 통화 기록 카드 전용 규격 | [_CallMessageBubble](../mobile/lib/features/chat/presentation/chat_conversation_view.dart) | 현재 모양 유지로 검토 완료. 흰 배경·테두리, 세로 패딩 9·아이콘 22·글자 간격 10과 상태별 아이콘 색상을 연결. 본문·모서리·좌우 여백은 메시지 공통 규격 공유 |
| `_VoiceMemoMessageBubbleState` | 음성 메시지 카드 전용 규격 | [_VoiceMemoMessageBubble](../mobile/lib/features/chat/presentation/chat_conversation_view.dart) | 현재 모양 유지로 검토 완료. 너비 계산·높이 56·모서리 15·패딩 10/8/14/8, 재생 버튼 40·아이콘 30, 파형 높이 22·양옆 간격 12와 색상·시간 글자를 연결. 재생·탐색 동작과 공통 파형 그리기는 유지 |
| `_FileMessageContent` | 파일 메시지 카드 전용 규격 | [_FileMessageContent](../mobile/lib/features/chat/presentation/chat_conversation_view.dart) | 현재 모양 유지로 검토 완료. 내용 최대 폭 224·아이콘 표면 38·아이콘 21·간격 10/3·파일명 최대 2줄과 방향별 글자·색상·알파 38/200을 연결. 공통 말풍선과 파일 열기 동작 유지 |
| `_MessageBubbleState` | 전환·지연 시간 | [L18867](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L18867) | `Duration(milliseconds: 360)` |
| `_MessageBubbleState` | 투명도 | [L18972](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L18972) | `AppColors.black.withAlpha(18)` |
| `_MessageBubbleState` | 로컬 수치 | [L18976](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L18976) | `const double peakPoint = 0.22;` |
| `_MessageBubbleState` | 간격·너비·꼬리 | [ChatMessageStyle](../mobile/lib/features/chat/presentation/chat_message_style.dart) | 현재 모양 유지로 검토 완료. 패딩 11/6, 일반 최대 폭 68%·답장 폭 36~70%, 꼬리 12×13·위 6·바깥쪽 -7을 전용 규격으로 연결 |
| `_ComposerBottomSurfaceState` | 전환·지연 시간 | [L19291](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L19291) | `Duration(milliseconds: 140)` |
| `_ComposerBottomSurfaceState` | 크기·좌표 | [L19314](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L19314) | `Offset(0, 0.04)` |
| `_ChatAttachmentPanel` | 간격 | [L19393](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L19393) | `EdgeInsets.fromLTRB( 10, 26, 10, math.max(18, bottomSafePadding + 12), )` |
| `_AttachmentPanelAction` | 속성 보정 | [L19452](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L19452) | `dimension: 54` |
| `_AttachmentPanelAction` | 속성 보정 | [L19458](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L19458) | `size: 28` |
| `_MessageComposer` | 채팅 입력창 전용 규격 | [ChatComposerStyle](../mobile/lib/features/chat/presentation/chat_composer_style.dart) | 현재 모양 유지로 검토 완료. 기본·답장·수정의 크기·여백·글자·색상·줄 수를 연결. 공통 입력창·답장/수정 배치와 기존 상태·콜백 유지 |
| `_ComposerActionSlot`·`_ComposerLastLineAction`·`_ComposerCircleButton` | 액션 배치·전환 | [ChatComposerStyle](../mobile/lib/features/chat/presentation/chat_composer_style.dart) | 문맥 액션 크기 42와 마지막 줄 보정 -2, 아이콘별 크기·색상 공유. 버튼·아이콘의 140ms 전환은 `_buildComposerActionSwitcher` 한 곳에서 구현 |

## _ActionConfirmation (chat_conversation_view.dart)

소스: [mobile/lib/features/chat/presentation/chat_conversation_view.dart](../mobile/lib/features/chat/presentation/chat_conversation_view.dart)

| 구간 | 종류 | 관리하는 값·표현 |
| --- | --- | --- |
| `_ActionConfirmation` | 표면·여백 | 높이 56·모서리 18, `AppColors.black` 알파 128. 왼쪽 `AppSpacing.space16`·오른쪽 14.5로 글자의 오른쪽 여백까지 포함해 정렬 |
| `_ActionConfirmation` | 아이콘·글자 | 기존 Google `checkCircle` 24·흰색, 글자와 간격 `AppSpacing.space12`. `AppTypography.subTypography9`(18/27)·Regular·흰 글자 |
| `_ActionConfirmation` | 복사 안내 배치 | 입력창/검색 툴바 위 간격 `AppSpacing.space8`. 기존 `ChatComposerStyle`의 좌우 정렬과 키보드·첨부 패널 위치 계산을 공유 |
| `_ActionConfirmation` | 저장 페이드 | 등장 200ms(`easeInOut`)·유지 2500ms·사라짐 250ms(`easeIn`). 합계 2950ms. 사진·영상 저장이 같은 중앙 안내와 애니메이션 사용 |
| `_ActionConfirmation` | 복사 이동 | 올라오기 167ms(`fastOutSlowIn`)·제자리로 돌아오기 117ms(`easeInOut`)·유지 2716ms·내려가기 300ms(`easeInOut`). 오버슈트 13/3, 합계 3300ms. 전체 시간은 구간별 시간의 합으로 정의하고 같은 값을 애니메이션 가중치에 사용 |

## _QuickPhotoPreviewScreen (chat_conversation_view.dart)

소스: [mobile/lib/features/chat/presentation/chat_conversation_view.dart](../mobile/lib/features/chat/presentation/chat_conversation_view.dart)

| 구간 | 종류 | 관리하는 값·표현 |
| --- | --- | --- |
| `_QuickPhotoPreviewScreen` | 사진 영역·배경 | 최소 안전 여백 위 52·아래 76·좌우 0. 화면과 시스템 하단 영역은 같은 `AppColors.black` 사용. 사진은 기존 `BoxFit.contain`·중앙 배치·끊김 없는 이미지 교체 유지 |
| `_QuickPhotoPreviewScreen` | 취소 | 왼쪽 `space8`, 흰 글자·`subTypography10`(16/24)·Regular. 기존 `TextButton` 표면·터치 동작 유지 |
| `_QuickPhotoPreviewScreen` | 하단 영역 | 검정 알파 217, 최소 안전 여백 좌우 `space16`·위아래 `space12`, 오른쪽 버튼 정렬 유지 |
| `_QuickPhotoPreviewScreen` | 전송 | 72×42, `blue500`·`borderRadiusFull`, 흰 글자·`typography6`(15/22.5)·Bold. 공통 기본 버튼의 높이 46·모서리 10과 다른 기존 확인 화면 규격 유지 |
| `_QuickPhotoPreviewScreen` | 화면 전환 | 열기 180ms·닫기 160ms, 기존 `FadeTransition`·사진 Hero 사용. 사진 조회와 취소/전송 결과 처리, iOS 공통 편집기 분기 유지 |

## _QuickPhotoPrompt (chat_conversation_view.dart)

소스: [mobile/lib/features/chat/presentation/chat_conversation_view.dart](../mobile/lib/features/chat/presentation/chat_conversation_view.dart)

| 구간 | 종류 | 관리하는 값·표현 |
| --- | --- | --- |
| `_QuickPhotoPrompt` | 크기 | 너비 `화면 너비 × 0.172`를 68~76으로 제한. 사진은 정사각형이며 아래 버튼 영역 50을 더해 전체 높이를 계산 |
| `_QuickPhotoPrompt` | 표면·그림자 | 흰 배경·모서리 17을 장식과 이미지 자르기에서 공유. 그림자는 `AppColors.black` 알파 26·위치 `(0, 6)`·흐림 18 |
| `_QuickPhotoPrompt` | 전송 버튼 | 주변 여백 가로 6·세로 9, 모서리 22, `AppColors.blue500`, `AppTypography.subTypography11`·Bold·흰 글자. 실제 높이 32를 유지하는 카드 전용 버튼이며 높이 46·모서리 10의 `AppButton`과 구조가 다름 |
| `_QuickPhotoPrompt` | 등장·숨김 | 표시 10초·전환 180ms. 오른쪽 아래를 기준으로 `0.92 + 0.08 × 진행률`로 확대하며 `easeOutCubic` 사용. 숨김은 `linear` 페이드 후 같은 전환 시간에 카드 제거. 사진 조회 조건과 미리보기/전송 경로는 기존 구현 유지 |

## chat_composer_style.dart

소스: [mobile/lib/features/chat/presentation/chat_composer_style.dart](../mobile/lib/features/chat/presentation/chat_composer_style.dart)

| 구간 | 종류 | 관리하는 값·표현 |
| --- | --- | --- |
| `ChatComposerStyle` | 바깥 배치 | 좌우 여백 10, 키보드/첨부 패널 위 여백 10, 메시지 간격 `AppSpacing.space12`. 복사 안내·빠른 사진의 기존 정렬 계산도 공유 |
| `ChatComposerStyle` | 기본 입력 | 최소 높이 48·`AppRadius.borderRadius24`, `grey50` 배경·흰 테두리 1, 패딩 `space8`, 원형 액션 32, 입력 패딩 좌우 `space4`·위아래 4.5 |
| `ChatComposerStyle` | 답장·수정 배치 | 모서리 28, 패딩 `(space16, 11, 10, 6)`, 제목 영역 위 1·제목/미리보기 간격 2·닫기와 간격 10·입력 행과 간격 5. 입력 행 최소 높이 50, 위아래 입력 여백 `space12`, 액션 슬롯/버튼 42·마지막 줄 위치 보정 -2 |
| `ChatComposerStyle` | 글자·줄 수 | 기본 `typography6`(15/22.5)·Regular·`textPrimary`, 안내 `#92989E`. 답장/수정 `subTypography10`(16/24)·Regular·`textPrimary`, 안내 `textTertiary`. 제목은 15·Bold, 미리보기 15·Regular·`grey700`, 각각 1줄. 입력은 1~4줄 |
| `ChatComposerStyle` | 버튼·아이콘 | 첨부/검색 이동 20·음성 18·기본 전송 19·답장 전송 23·저장 24. 닫기 원형 34·아이콘 20·`grey700`·`grey200` 테두리. 중립 버튼 흰 배경/`textPrimary`, 비활성 `textDisabled`, 전송 `blue500`, 저장 `grey900`, 채움 버튼 흰 아이콘. 기존 Google 아이콘 사용 |
| `ChatComposerStyle` | 전환 | 입력창 크기 180ms, 버튼·아이콘 교체 140ms. 기존 곡선과 페이드·크기 전환 유지 |

## _FileMessageContent (chat_conversation_view.dart)

소스: [mobile/lib/features/chat/presentation/chat_conversation_view.dart](../mobile/lib/features/chat/presentation/chat_conversation_view.dart)

| 구간 | 종류 | 관리하는 값·표현 |
| --- | --- | --- |
| `_FileMessageContent` | 내부 배치 | 내용 최대 너비 224, 아이콘 표면 38×38·아이콘 21, 아이콘과 글자 간격 10, 파일명과 용량 간격 3, 파일명 최대 2줄 |
| `_FileMessageContent` | 아이콘 | 표면 모서리 `AppRadius.borderRadius8`. 발신은 흰 배경 알파 38·흰 아이콘, 수신은 `blue50` 배경·`blue500` 아이콘. 기존 `AppIcons.file` 사용 |
| `_FileMessageContent` | 파일명 | `AppTypography.typography6`·Regular(15/22.5). 발신 `textOnPrimary`, 수신 `textPrimary` |
| `_FileMessageContent` | 용량 | `AppTypography.subTypography12`(12/18). 발신 흰색 알파 200, 수신 `grey500`. 용량 계산·표시 형식은 기존 구현 유지 |

## _VoiceMemoMessageBubble (chat_conversation_view.dart)

소스: [mobile/lib/features/chat/presentation/chat_conversation_view.dart](../mobile/lib/features/chat/presentation/chat_conversation_view.dart)

| 구간 | 종류 | 관리하는 값·표현 |
| --- | --- | --- |
| `_VoiceMemoMessageBubble` | 카드 크기·장식 | 너비 `화면 너비 - 128`을 196~304로 제한, 높이 56·모서리 15. 흰 배경, `grey100` 테두리 두께 1 |
| `_VoiceMemoMessageBubble` | 내부 여백 | 왼쪽 10·오른쪽 14·위아래 `AppSpacing.space8`, 파형 양옆 `AppSpacing.space12` |
| `_VoiceMemoMessageBubble` | 재생 버튼 | 원형 `AppSpacing.space40`·아이콘 30, 배경 `grey50`, 활성 아이콘 `grey900`·비활성 `grey300`. 아이콘은 기존 `AppIcons.playback` 사용 |
| `_VoiceMemoMessageBubble` | 파형·시간 | 높이 22, 미재생 `grey300`·재생한 부분 `grey900`, 시간 글자는 `ChatMessageStyle.body`(16/24·Regular·`textPrimary`) 공유 |

## _CallMessageBubble (chat_conversation_view.dart)

소스: [mobile/lib/features/chat/presentation/chat_conversation_view.dart](../mobile/lib/features/chat/presentation/chat_conversation_view.dart)

| 구간 | 종류 | 관리하는 값·표현 |
| --- | --- | --- |
| `_CallMessageBubble` | 카드 장식 | 배경 `AppColors.white`, 테두리 `AppColors.grey100`·두께 1, 모서리 `ChatMessageStyle.bubbleBorderRadius` |
| `_CallMessageBubble` | 크기·간격 | 위아래 여백 9, 좌우 여백 `ChatMessageStyle.horizontalPadding`(11), 아이콘 22·글자 간격 10 |
| `_CallMessageBubble` | 상태 색상 | 시작 `green500`(`#03B26C`), 부재중 `red500`(`#F04452`), 취소·응답 없음 `grey500`, 종료 `grey900`. 모두 기존 `AppColors` 토큰 사용 |

## _LinkPreviewCard (chat_conversation_view.dart)

소스: [mobile/lib/features/chat/presentation/chat_conversation_view.dart](../mobile/lib/features/chat/presentation/chat_conversation_view.dart)

| 구간 | 종류 | 관리하는 값·표현 |
| --- | --- | --- |
| `_LinkPreviewCard` | 카드 크기·간격 | 최대 너비 316, 본문과 카드 간격 6, 본문 패딩 `(14, AppSpacing.space12, 14, 13)`, 설명 간격 5·주소 간격 `AppSpacing.space8` |
| `_LinkPreviewCard` | 줄 수·이미지 | 제목·설명 최대 2줄, 주소 1줄. 기본 이미지 비율 2:1, 대체 표시 좌우 여백 18·최대 2줄 |
| `_LinkPreviewCard` | 글자·색상 | 제목은 메시지 본문의 Bold, 설명·주소는 `subTypography12`·Regular. 제목 `textPrimary`, 설명·대체 표시 `textSecondary`, 주소와 밑줄 `blue500`, 카드 배경 흰색·대체 이미지 배경 `grey50` |
| `_LinkPreviewCard` | 테두리 | 기본 `grey100`·두께 1, 강조 `primary` 알파 110·두께 1.6 |

## _MessageActionMenu (chat_conversation_view.dart)

소스: [mobile/lib/features/chat/presentation/chat_conversation_view.dart](../mobile/lib/features/chat/presentation/chat_conversation_view.dart)

| 구간 | 종류 | 현재 규격 |
| --- | --- | --- |
| `_MessageActionMenu` | 배치 | 최대 너비 288·바깥 좌우 여백 `space16`·상하 여백 `space8`·말풍선과 간격 6 |
| `_MessageActionMenu` | 표면 | 흰 배경·`borderRadius12`·그림자 높이 4·검정 알파 31·구분선 1/`grey100` |
| `_MessageActionMenu` | 항목 | 높이 40·좌우 패딩 14/`space12`·아이콘 20·`typography6` 보통 굵기. 일반 글자/아이콘 `grey900`/`grey700`, 보내기 취소 `red500` |
| `_MessageActionMenu` | 전환 | 배경 검정 알파 31·140ms 페이드·등장 `easeOutCubic`·닫힘 `easeInCubic`. 그림자와 배경 어두움은 서로 다른 역할로 관리 |

수신·발신·미디어·통화별 메뉴 노출과 보내기 취소 5분 조건은 `availableChatMessageActions`에 유지해요. 항목 문구·Google 아이콘·클릭 처리와 메뉴의 위아래 배치 계산은 기존 구현을 공유해요.

## chat_message_style.dart

소스: [mobile/lib/features/chat/presentation/chat_message_style.dart](../mobile/lib/features/chat/presentation/chat_message_style.dart)

| 구간 | 종류 | 위치 | 직접 지정한 값·표현 |
| --- | --- | --- | --- |
| `ChatMessageStyle` | 로컬 수치 | [L9](../mobile/lib/features/chat/presentation/chat_message_style.dart#L9) | `static const double bubbleRadius = 17;` |
| `ChatMessageStyle` | 로컬 수치 | [L10](../mobile/lib/features/chat/presentation/chat_message_style.dart#L10) | `static const double tailCornerRadius = 13;` |
| `ChatMessageStyle` | 모서리 | [L14](../mobile/lib/features/chat/presentation/chat_message_style.dart#L14) | `BorderRadius.all( Radius.circular(14), )` |
| `ChatMessageStyle` | 로컬 수치 | [L17](../mobile/lib/features/chat/presentation/chat_message_style.dart#L17) | `static const double horizontalPadding = 11;` |
| `ChatMessageStyle` | 로컬 수치 | [L18](../mobile/lib/features/chat/presentation/chat_message_style.dart#L18) | `static const double verticalPadding = 6;` |
| `ChatMessageStyle` | 로컬 수치 | [L19](../mobile/lib/features/chat/presentation/chat_message_style.dart#L19) | `static const double groupedMessageGap = 5;` |
| `ChatMessageStyle` | 로컬 수치 | [L20](../mobile/lib/features/chat/presentation/chat_message_style.dart#L20) | `static const double timestampGap = 6;` |
| `ChatMessageStyle` | 너비 비율 | [L23](../mobile/lib/features/chat/presentation/chat_message_style.dart#L23) | 일반 메시지·링크·사진·영상 `maximumWidthRatio = 0.68`, 답장 `replyMinimumWidthRatio = 0.36`·`replyMaximumWidthRatio = 0.70` |
| `ChatMessageStyle` | 꼬리 크기·위치 | [L28](../mobile/lib/features/chat/presentation/chat_message_style.dart#L28) | `tailSize = Size(12, 13)`, `tailTopOffset = 6`, `tailHorizontalOffset = -7` |
| `ChatMessageStyle` | 답장·수정 간격 | [L32](../mobile/lib/features/chat/presentation/chat_message_style.dart#L32) | 인용 제목 간격 1, 구분선 두께 1·위아래 간격 7, 수정 표시 간격 1 |
| `ChatMessageStyle` | 번역 안내 크기·전환 | [L38](../mobile/lib/features/chat/presentation/chat_message_style.dart#L38) | 로딩 위 여백 `AppSpacing.space4`, 실패 위 여백 3, 로딩 크기 10·선 1.5·간격 5, 재시도 간격 2, 페이드 160ms·크기 전환 180ms |
| `ChatMessageStyle` | 답장·수정 글자·색상 | [L59](../mobile/lib/features/chat/presentation/chat_message_style.dart#L59) | 발신 인용 글자/구분선 흰색 알파 220/56, 발신 수정 표시 흰색 알파 190. 수신은 기존 `textPrimary`·`grey700`·`grey200`·`grey600` 사용 |
| `ChatMessageStyle` | 번역 글자·재시도 버튼 | [L82](../mobile/lib/features/chat/presentation/chat_message_style.dart#L82) | 공통 `subTypography12`·Regular에 로딩 `textTertiary`, 실패 `textSecondary`, 재시도 `blue500`. 버튼은 같은 재시도 글자색과 기존 여백 없는 규격 사용 |
| `ChatMessageStyle` | 검색 강조 | [L108](../mobile/lib/features/chat/presentation/chat_message_style.dart#L108) | 발신 현재 결과 `blue900`·나머지 흰색 알파 76, 수신 현재 결과 `blue200`·나머지 `primary` 알파 54 |

## _PhotoViewerThumbnail (chat_conversation_view.dart)

소스: [mobile/lib/features/chat/presentation/chat_conversation_view.dart](../mobile/lib/features/chat/presentation/chat_conversation_view.dart)

| 구간 | 종류 | 관리하는 값·표현 |
| --- | --- | --- |
| `_PhotoViewerThumbnail` | 목록 배치 | 패딩 좌우 18·위 `space12`·아래 10, 사진 행 높이 56·세로 이동 19·사진 간격 5, 순서 행과 간격 7. 배경 위 위치 15 유지 |
| `_PhotoViewerThumbnail` | 순서 표시 | 행 높이 24·세로 이동 `37 / 3`, 이미지 아이콘 18·글자 간격 5. `subTypography13`(11/16.5)·Regular·흰색, 기존 순서 문구와 중앙 배치 유지 |
| `_PhotoViewerThumbnail` | 선택 표현 | 선택/미선택 정사각형 44/42, 바깥 모서리 5/7·안쪽 3/4, 테두리 2/0·`blue500`/투명. 가로·세로는 같은 선택 크기 규칙을 사용하고 사진은 기존 `_PhotoMessageImage` 재사용 |
| `_PhotoViewerThumbnail` | 전환 | 선택 크기·테두리 140ms, 선택한 썸네일 자동 스크롤 160ms, 썸네일을 눌렀을 때 사진 이동 180ms. 세 전환 모두 기존 `easeOutCubic` 유지 |

## _VideoViewerBottomOverlay (chat_conversation_view.dart)

소스: [mobile/lib/features/chat/presentation/chat_conversation_view.dart](../mobile/lib/features/chat/presentation/chat_conversation_view.dart)

| 구간 | 종류 | 관리하는 값·표현 |
| --- | --- | --- |
| `_VideoViewerBottomOverlay` | 재생 행·버튼 배치 | 진행바 행/터치 영역 높이 24, 좌우 `AppSpacing.space16`, 재생 버튼/아이콘 20·흰색, 버튼과 시간 사이 18·시간과 진행바 사이 6·하단 액션과 간격 2. 기존 Google 재생/일시정지 아이콘 사용 |
| `_VideoViewerBottomOverlay` | 시간 글자 | `AppTypography.typography7`·13/20·자간 -0.8·고정 폭 숫자, `AppMediaViewerChrome.labelColor`(`#F2F2F2`). 현재 시간과 전체 길이가 같은 규격·포맷 함수 공유 |
| `_VideoViewerBottomOverlay` | 진행바·손잡이 | 비활성 선 `#B8B8B8`·두께 2, 활성 선 `AppColors.blue500`·두께 4, 손잡이 반지름 5.5·같은 파랑. 선의 둥근 끝과 진행률에 따른 위치 계산은 기존 Painter 유지 |
| `_VideoViewerBottomOverlay` | 하단 배경 | 페이드 높이 기준 44. 위에서 아래로 검정 알파 0→184→공통 미디어 배경, 위치 0/0.43/1. 배경·진행바·액션 버튼의 상대 위치를 계산하는 기존 공식 유지 |

## _MediaViewerTopBar (chat_conversation_view.dart)

소스: [mobile/lib/features/chat/presentation/chat_conversation_view.dart](../mobile/lib/features/chat/presentation/chat_conversation_view.dart)

| 구간 | 종류 | 관리하는 값·표현 |
| --- | --- | --- |
| `_MediaViewerTopBar` | 보낸 사람 이름 | `AppTypography.typography6`·15/18·Bold. 기존 줄 높이 `18 / 15` 유지 |
| `_MediaViewerTopBar` | 날짜·시간 | `AppTypography.typography7`·13/16·Regular. 기존 줄 높이 `16 / 13` 유지. 현지 시간 변환과 `Jul 1, 2026 at 12:52 PM` 형식은 기존 함수 사용 |
| `_MediaViewerTopBar` | 공통 표시 | `AppMediaViewerChrome.labelColor`(`#F2F2F2`) 재사용. 이름·날짜 모두 최대 한 줄·`TextOverflow.ellipsis`. 중앙 배치와 날짜 가운데 정렬은 기존 위젯에 유지 |

## chat_photo_editor_screen.dart

소스: [mobile/lib/features/chat/presentation/chat_photo_editor_screen.dart](../mobile/lib/features/chat/presentation/chat_photo_editor_screen.dart)

| 구간 | 종류 | 관리 위치·사용 방식 |
| --- | --- | --- |
| `ChatPhotoEditorTopBar` | 사진 편집 상단바 전용 규격 | [ChatPhotoEditorTopBar](../mobile/lib/features/chat/presentation/chat_photo_editor_screen.dart)로 현재 모양 유지 정리 완료. 사진 순서·Send 글자와 간격·여백, 터치 영역 모서리를 연결 |
| `ChatPhotoEditorTopBar` | 공통 미디어 표면·전환 | `AppMediaViewerChrome`의 색상·높이 44·좌우 여백·200ms·등장/숨김 곡선, `AppMediaViewerChromeButton`·`AppTopBarBackIcon`·`AppTopBarButtonSurface` 재사용. 이동 오프셋·투명도·터치 제한·뒤로가기/전송 콜백 유지 |

## ChatPhotoEditorTopBar (chat_photo_editor_screen.dart)

소스: [mobile/lib/features/chat/presentation/chat_photo_editor_screen.dart](../mobile/lib/features/chat/presentation/chat_photo_editor_screen.dart)

| 구간 | 종류 | 관리하는 값·표현 |
| --- | --- | --- |
| `ChatPhotoEditorTopBar` | 배치 | 뒤로가기와 사진 순서 사이 11, Send 내부 좌우 여백 15. 버튼 높이·화면 좌우 여백·안전 영역 계산은 기존 공통 규격 사용 |
| `ChatPhotoEditorTopBar` | 글자 | 사진 순서는 `subTypography9`·18/18·Bold, Send는 `subTypography10`·16/16·Regular. 글자색은 기존 `AppMediaViewerChrome.foregroundColor`, 한 줄 높이 배율 1 유지 |
| `ChatPhotoEditorTopBar` | 터치 모서리 | `AppTopBarButtonSurface.borderRadiusForHeight(AppMediaViewerChrome.buttonDimension)` 사용. 표면과 터치 영역이 같은 `height / 2` 규칙으로 현재 모서리 22를 유지 |

## chat_photo_picker.dart

소스: [mobile/lib/features/chat/presentation/chat_photo_picker.dart](../mobile/lib/features/chat/presentation/chat_photo_picker.dart)

| 구간 | 종류 | 관리 위치·사용 방식 |
| --- | --- | --- |
| `_ChatPhotoPickerState`·`_PhotoGridTile`·`_PhotoSelectionBadge`·`_PhotoThumbnailState` | 사진 선택기 전용 규격 | [ChatPhotoPicker](../mobile/lib/features/chat/presentation/chat_photo_picker.dart)로 현재 모양 유지 정리 완료. 격자·패널·앨범·선택 배지·하단 컨트롤·오류/권한 안내·전환 수치를 연결 |
| `_photoGridTranslation`·`_buildPhotoGrid`·`_buildRemovedPhotoGridTile` | 격자 배치·이동 | 같은 `gridCrossAxisCount`(3)·`gridSpacing`(2)을 사용. 인덱스에 따른 이동·삭제 위치 계산은 기존 구현 유지 |
| `_buildCollageControl`·`_PhotoSelectionBadge` | 선택 표시 | `ChatPhotoPicker.selectionDecoration`으로 원형·선택 색·테두리 1.5를 공유하고 서로 다른 미선택 배경/테두리 색만 전달 |
| `_ChatPhotoPickerState` | 데이터·상태 규칙 | 페이지당 60개·최대 선택 10개·조회 갱신 대기 180ms·추가 조회 임계값 400·썸네일 캐시 180개는 디자인 수치가 아니므로 기존 로직에 유지 |
| `_PhotoThumbnail` | 이미지 요청 해상도 | 앨범 표지 180×180·격자 320×320 요청은 표시 크기와 구분해 기존 코드에 유지. 데이터 요청·캐시·선택 순서·편집·전송 흐름 변경 없음 |

## ChatPhotoPicker (chat_photo_picker.dart)

소스: [mobile/lib/features/chat/presentation/chat_photo_picker.dart](../mobile/lib/features/chat/presentation/chat_photo_picker.dart)

| 구간 | 종류 | 관리하는 값·표현 |
| --- | --- | --- |
| `ChatPhotoPicker` | 격자·패널 | 3열·간격 2, 펼친 패널 위 모서리 18. 그림자 검정 알파 40·흐림 6·위치 `(0, 2)`. 접힌 패널은 기존 직각 유지 |
| `ChatPhotoPicker` | 손잡이·헤더 | 손잡이 영역 높이 20·손잡이 36×4·모서리 3·`grey400`. 헤더 52·닫기 아이콘 26·왼쪽 위치 2. 접힌 제목은 `typography6`·Bold |
| `ChatPhotoPicker` | Send 버튼 | 높이 32·미선택 너비 56·오른쪽 위치 10, 선택 시 가로 패딩 11. 글자는 `typography6`, 활성 흰색·비활성 `grey500`. 기존 선택 개수에 따른 굵기·너비 계산과 `AppRadius.borderRadius16` 유지 |
| `ChatPhotoPicker` | 앨범 드롭다운 | 패딩 가로 `space8`·세로 6, 제목 최대 너비 180·아이콘 간격 2·아이콘 24. 제목은 `typography5`·Bold |
| `ChatPhotoPicker` | 앨범 행 | 높이 88·썸네일 60·글자와 간격 `space16`, 구분선 높이 1·시작점은 `60 + space16`(76). 이름/개수 간격 2, 이름 `typography5`·`textPrimary`, 개수 `subTypography10`·`textTertiary` |
| `ChatPhotoPicker` | 권한·오류·추가 조회 안내 | 권한 아이콘 42·오류 아이콘 44, 기존 글자 토큰 유지. 추가 조회 로딩은 아래 여백 14·패딩 7·크기 20·선 두께 2 |
| `ChatPhotoPicker` | 묶어 보내기·편집 | 하단 영역 48·행 위 위치 13·최소 왼쪽 여백 `space12`. 선택 원 22·체크 16·글자 간격 7. 편집 버튼 40·오른쪽 10·아래 최대 25·그림자 높이 2·검정 알파 48. 편집 아이콘은 `AppMediaEditIcon.iconToButtonRatio`로 20을 계산. 안전 영역 계산 유지 |
| `ChatPhotoPicker` | 선택 배지·사진 강조 | 배지 28·위/오른쪽 7, 미선택 흰색 알파 200·회색 테두리, 선택 파랑·흰 숫자(`subTypography11`·Bold). 배지와 묶어 보내기의 원형 테두리 1.5·선택 색은 같은 함수로 관리. 선택 사진은 검정 알파 24 |
| `ChatPhotoPicker` | 영상 시간 표시 | 오른쪽 7·아래 6·패딩 가로 5/세로 2, 검정 알파 138·`borderRadius4`. `subTypography11`·Regular·흰 글자. 기존 시간 포맷 함수 재사용 |
| `ChatPhotoPicker` | 전환 | 사진 추가·삭제/재배치 160ms·크기 0.88↔1, 이동 `easeInOutCubic`·등장 `easeOutCubic`·사라짐 `easeInCubic`. 묶어 보내기 선택 전환 140ms. 썸네일은 별도로 233ms·`easeInOut` 페이드. 기존 상태·위치 계산·터치 조건 유지 |

## _ChatSearchTopBar (chat_search_widgets.dart)

소스: [mobile/lib/features/chat/presentation/chat_search_widgets.dart](../mobile/lib/features/chat/presentation/chat_search_widgets.dart)

| 구간 | 종류 | 관리하는 값·표현 |
| --- | --- | --- |
| `_ChatSearchTopBar` | 제목·입력 영역 | 흰 배경. 제목·뒤로 가기는 공통 `ChatNavigationBar`(높이 56), 입력은 `AppTextField`·공통 높이 46. 입력 여백 가로 `space16`·세로 `space12`, 검색/지우기 아이콘 20 |
| `_ChatSearchTopBar` | 탭 | 높이 44·좌우 여백 `space16`. 글자는 `body`, 선택 시 `primary`·Bold와 아래 선 2, 미선택 시 `textSecondary`·Regular와 투명한 선 |
| `_ChatSearchTopBar` | 구분선·페이드 | 구분선 높이/두께 1·`divider`. 기존 채팅 상단의 `_TranslucentTopBarSurface`와 블러/페이드를 재사용하며 아래 여유 `space12` 유지 |
| `_ChatSearchTopBar` | 로딩·실패 안내 | 높이 32·좌우 여백 `space16`, 글자 `caption`. 로딩 표시 12·선 두께 2·글자와 간격 `space8`. 실패 시 기존 `TextButton`의 Retry 사용 |
| `_ChatSearchTopBar` | 높이 계산 | 제목·입력·입력 여백·탭·구분선·페이드 여유를 합산. 안전 영역 제외 기본 183, 로딩/실패 안내 표시 시 215. 실제 위젯과 같은 값을 참조 |

안내 표시 조건 `loading || failed`는 `_ChatSearchTopBar` 한곳에서 관리해 렌더링과 높이 계산에 함께 사용해요. 로딩 중 안내를 우선하는 조건, 검색 입력·제출·지우기·탭 전환·재시도·포커스·닫기 콜백과 기존 페이드 구현은 유지했어요.

## _SearchFilterChip (chat_search_widgets.dart)

소스: [mobile/lib/features/chat/presentation/chat_search_widgets.dart](../mobile/lib/features/chat/presentation/chat_search_widgets.dart)

| 구간 | 종류 | 관리하는 값·표현 |
| --- | --- | --- |
| `_SearchFilterChip` | 필터 줄 | 높이 56·좌우 `space16`, 종류 버튼 사이와 달력 앞 간격 `space8`. Media·Links·Files가 같은 행과 공통 `AppIconButton`(46×46)을 사용 |
| `_SearchFilterChip` | 선택한 날짜 | 바깥 여백 좌우 `space16`·위아래 `space8`, 필터 줄과 같은 좌우 기준. 날짜 표시/해제는 종류 선택과 같은 `_SearchFilterChip`에 닫기 아이콘과 콜백을 전달 |
| `_SearchFilterChip` | 칩 모양·글자 | 안쪽 여백 가로 `space12`·세로 `space8`, 표면과 터치 효과는 같은 `borderRadiusFull`. 글자 `body`, 닫기 아이콘 20·글자와 간격 `space8`. 내용에 따른 기존 크기 유지 |
| `_SearchFilterChip` | 선택 상태 | 선택 시 `primaryMuted` 배경·`primary` 글자/아이콘·투명 테두리. 미선택 시 흰 배경·`textSecondary` 글자/아이콘·`border` 테두리. 기존 테두리 두께 1 유지 |
| `_SearchFilterChip` | 정렬 안내 | Links·Files의 기존 `Newest first` 표시, `caption`·`textTertiary` 유지 |

종류별 문구·선택 조건·콜백, 날짜 표시 조건·현지 날짜 포맷·선택/해제와 가로 스크롤 구조는 변경하지 않았어요. 기존 공통 색상·글자·여백·모서리를 재사용하고, 달력 버튼과 날짜 선택창 구현은 그대로 사용해요.

## _SearchResultCard (chat_search_widgets.dart)

소스: [mobile/lib/features/chat/presentation/chat_search_widgets.dart](../mobile/lib/features/chat/presentation/chat_search_widgets.dart)

| 구간 | 종류 | 관리하는 값·표현 |
| --- | --- | --- |
| `_SearchResultCard` | 사진·영상 격자 | 3열·가로/세로 간격 `space8`, 좌우 `space16`·아래 `space12`, 정사각형 유지. 사진·영상은 같은 `borderRadius12` 사용 |
| `_SearchResultCard` | 링크·파일 격자 | 2열·가로/세로 간격 `space12`, 좌우/아래 `space16`. 두 종류는 같은 카드 컴포넌트 사용 |
| `_SearchResultCard` | 카드 높이 | 미리보기 104·설명 영역 128. 기존 공식 `104 + 128 × textScaler.scale(14) / 14` 유지. 실제 카드·링크 미리보기와 격자 높이 계산이 같은 미리보기 높이 참조 |
| `_SearchResultCard` | 카드 표면·글자 | 흰 표면·`borderRadius16`·`border` 테두리, 안쪽 `space12`, 미리보기 `grey100`. 제목 `body`·Bold·최대 2줄, 부가 정보/보낸 사람 `caption`·최대 1줄·말줄임, 간격 `space4`. 링크 주소는 `primary`, 파일 정보·보낸 사람은 `textSecondary` |
| `_SearchResultCard` | 목록 제목·파일 아이콘 | 제목 여백 좌우 `space16`·위 `space8`·아래 `space12`, 카드와 같은 제목 글자·설명 `caption`/`textTertiary`. 파일 아이콘 32·`textPrimary`·기존 Google 아이콘 |
| `_SearchResultCard` | 검색 영상 시간 배지 | 오른쪽/아래 `space4`, 패딩 가로 `space4`·세로 2, 검정 알파 153·`borderRadius4`, 재생 아이콘 12·흰색, 시간 `subTypography13`·흰색. 기존 시간 포맷 유지 |

상단 입력·탭은 `_ChatSearchTopBar`, 필터 줄은 `_ChatSearchAttachments`, 종류·날짜 칩은 `_SearchFilterChip`에서 관리해요. 빈 결과 안내는 기존 구현을 유지해요. 날짜별 묶기·검색·필터 조건·자료 열기·영상 다운로드와 키보드 처리도 변경하지 않았어요.

## _MessageScrollGeometry (chat_conversation_view.dart)

소스: [mobile/lib/features/chat/presentation/chat_conversation_view.dart](../mobile/lib/features/chat/presentation/chat_conversation_view.dart)

| 구간 | 종류 | 현재 규격 |
| --- | --- | --- |
| `_MessageScrollGeometry` | 스크롤바 | 두께 3·오른쪽 여백 2, 일반 최소 길이 36·초기 페이지 기준 144·오버스크롤 최소 길이 8. `grey700`·최대 알파 190 |
| `_MessageScrollGeometry` | 날짜 표시 | 높이 24·막대와 간격 3·좌우 여백 10, 검정 알파 105·`borderRadiusFull`, `typography7`(13/19.5)·흰색·보통 굵기·최대 1줄 |
| `_MessageScrollGeometry` | 전환 | 함께 등장 90ms. 날짜 숨김 대기 120ms·전환 170ms·`easeOut`. 막대 숨김 대기 520ms·전환 260ms. 최신 메시지 이동 중 표시 유지 1초 |

날짜를 다시 찾는 주기 50ms는 데이터 갱신 조건이므로 기존 `_MessageListState`에 유지해요. 위치와 길이 공식, 날짜 포맷, 타이머·컨트롤러의 상태 전환은 변경하지 않았어요.

## chat_scrollbar_range_tracker.dart

소스: [mobile/lib/features/chat/presentation/chat_scrollbar_range_tracker.dart](../mobile/lib/features/chat/presentation/chat_scrollbar_range_tracker.dart)

| 구간 | 종류 | 위치 | 직접 지정한 값·표현 |
| --- | --- | --- | --- |
| `ChatScrollbarThumbLengthResolver` | 스크롤 길이 기준 | [_MessageScrollGeometry](../mobile/lib/features/chat/presentation/chat_conversation_view.dart) | 일반 최소 36·초기 페이지 기준 144. 기존 길이 계산은 그대로 사용 |

## chat_video_trim_editor.dart

소스: [mobile/lib/features/chat/presentation/chat_video_trim_editor.dart](../mobile/lib/features/chat/presentation/chat_video_trim_editor.dart)

| 구간 | 종류 | 관리 위치 | 현재 규격·처리 |
| --- | --- | --- | --- |
| `ChatVideoTrimPlaybackControl`·`ChatVideoTrimTimeline` | 영상 길이 편집 전용 규격 | [ChatVideoTrimTimeline](../mobile/lib/features/chat/presentation/chat_video_trim_editor.dart) | 기존 공개 치수와 실제 구현이 같은 정의를 참조. 편집 화면의 하단 위치 기준, 화면·그리기·드래그가 같은 값 사용 |
| `_ChatVideoTrimEditorState` | 배경·등장/숨김 | [ChatVideoTrimTimeline](../mobile/lib/features/chat/presentation/chat_video_trim_editor.dart) | 배경 그라데이션은 해당 위젯에서 직접 정의. 기존 `AppMediaViewerChrome` 전환·`Offset(0, 1)`·불투명도 0/1·터치 차단 조건 유지 |
| `_ChatVideoTrimTimelineState` | 표시·좌표 계산 | [ChatVideoTrimTimeline](../mobile/lib/features/chat/presentation/chat_video_trim_editor.dart) | 시간 글자·터치 반경·선택 밖 음영·선택 색상·재생선 연결. 구간 경계와 재생 위치의 동일한 공식을 `_timelineX` 하나로 공유 |
| `_VideoTrimSelectionPainter` | 선택 테두리·손잡이 | [ChatVideoTrimTimeline](../mobile/lib/features/chat/presentation/chat_video_trim_editor.dart) | 치수·색상을 전용 규격에서 참조. 손잡이 표식 모서리 `너비 / 2`·세로 중앙 `높이 / 2`와 기존 도형 좌표 계산 유지 |

최소 선택 길이 1초(영상이 더 짧으면 전체 길이), 재생 종료 후 선택 시작점으로 복귀, 구간 밖 탐색 제한과 프레임 디코딩 크기 180은 기존 동작·데이터 처리에 유지해요.

## ChatVideoTrimTimeline (chat_video_trim_editor.dart)

소스: [mobile/lib/features/chat/presentation/chat_video_trim_editor.dart](../mobile/lib/features/chat/presentation/chat_video_trim_editor.dart)

| 구간 | 종류 | 관리하는 값·표현 |
| --- | --- | --- |
| `ChatVideoTrimTimeline` | 트랙 배치 | 높이 51·좌우 여백 15, 시간 영역 12·트랙과 간격 11·전체 높이 `12 + 11 + 51`(74), 하단 중심 기준 52. 바깥 모서리는 `AppRadius.radius8` 재사용 |
| `ChatVideoTrimTimeline` | 재생 버튼 | 너비 48·높이는 트랙과 공유, `grey100` 배경·왼쪽 모서리 8·오른쪽 흰 구분선 1. 아이콘 24·`grey900`, 기존 `AppIcons.playback` 재사용 |
| `ChatVideoTrimTimeline` | 구간 선택·손잡이 | 프레임 두께 5·손잡이 너비 18·모서리 3·터치 판정 반경 24. 표식 3×20·`grey900`. 전체 구간은 `grey100`, 편집한 구간은 `primary` |
| `ChatVideoTrimTimeline` | 현재 재생 위치 | 선 너비 4·위아래 안쪽 여백 3·흰색, 높이는 `트랙 높이 - 여백 × 2`(45), 모서리는 `너비 / 2` |
| `ChatVideoTrimTimeline` | 시간 글자 | `subTypography12`·12/12·Regular·흰색·고정 폭 숫자. 시작/끝 시간에 같은 스타일과 기존 `formatChatVideoDuration` 사용 |
| `ChatVideoTrimTimeline` | 프레임 목록 | 요청 개수와 표시 칸 수 13을 공유. 프레임 로드 전 투명·로드 후 `grey100`, 배경과 클리핑은 같은 오른쪽 모서리 사용 |
| `ChatVideoTrimTimeline` | 음영·배경 | 선택 밖 양쪽 음영은 검정 알파 150 공유. 화면 배경은 시작 `(0, 0.45)`부터 아래 중앙까지 검정 알파 0→217 그라데이션 유지 |

## 도형 좌표를 유지한 Painter

이 구현들은 말풍선 꼬리·파형·진행바·트림 선택 영역을 직접 그려요. 경로 좌표와 크기 비율은 그림의 형태를 결정하므로 일반 여백 토큰으로 바꾸지 않아요.

| 구현 | 위치 |
| --- | --- |
| `_VoiceMemoWaveformPainter` | [chat_conversation_view.dart:L6228](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L6228) |
| `_MessageScrollbarPainter` | [chat_conversation_view.dart:L11318](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L11318) |
| `_MessageScrollbarPainter` | 스크롤 색상 | [_MessageScrollGeometry](../mobile/lib/features/chat/presentation/chat_conversation_view.dart) | 기존 `grey700`·최대 알파 190. 애니메이션 값에 따른 알파 반올림과 범위 제한 유지 |
| `_VideoViewerProgressPainter` | [chat_conversation_view.dart:L16953](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L16953) |
| `_BubbleTailPainter` | [chat_conversation_view.dart:L19097](../mobile/lib/features/chat/presentation/chat_conversation_view.dart#L19097) |
| `_VideoTrimSelectionPainter` | [chat_video_trim_editor.dart:L828](../mobile/lib/features/chat/presentation/chat_video_trim_editor.dart#L828) |

## 네이티브 경계

iOS 사진 편집기는 현재 모양 유지로 검토를 마쳤어요. [PencilKitEditorStyle](../mobile/ios/Runner/PencilKitEditorBridge.swift#L5)은 해당 Swift 파일 안에서만 쓰는 전용 규격이에요. Flutter 토큰을 직접 참조하지 않으므로 같은 값을 유지해야 하는 연결을 코드 주석에 기록했어요.

| 항목 | 현재 규격 | 적용 위치·공유 기준 |
| --- | --- | --- |
| 배경색 | `#202020`·RGB 각 `32 / 255`·불투명 | 정상 편집 화면과 오류 화면이 같은 `backgroundColor` 참조. Flutter의 `AppMediaViewerChrome.backgroundColor`와 같은 값 유지 |
| 사진 맞춤 기준 | `aspectFillLogRatioThreshold = 0.45` | 사진·화면 방향이 같고 `abs(log(사진 비율 / 화면 비율)) < 0.45`이면 채우기, 나머지는 전체 맞춤. Flutter 사진 뷰어의 `_photoViewerFit`과 같은 기준 유지 |
| 사진·그림 배치 | 기존 중앙 배치·`.integral` 보정 | 계산한 프레임 하나를 사진·캔버스에 함께 적용. 크기 변경 시 그림 좌표 변환, 저장·내보내기 처리는 기존 구현 유지 |
| iOS 도구 | 기존 `PKToolPicker` | 표시·숨김·활성 화면 전환·그림 보존, 실제 도구 위치를 Flutter에 전달하는 흐름 유지 |

iOS 시작 화면의 로고 크기와 색상도 `AppLaunchScreen`의 주석에 기록된 동기화 대상이에요.
