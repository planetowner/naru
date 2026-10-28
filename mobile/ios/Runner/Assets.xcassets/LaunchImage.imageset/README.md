# 시작 화면 애셋

이 폴더의 PNG는 [브랜드 SVG 원본과 생성 도구](../../../../assets/brand/README.md)에서 만들어요. Flutter와 iOS는 같은 144·288·432px 심벌을 사용해요.

`LaunchScreen.storyboard`는 흰색 배경에 심벌을 144×144pt로 화면 정중앙에 배치해요. `Info.plist`의 시작 상태 막대는 어두운 글자색을 사용해요. 이 규격은 `AppLaunchScreen`, `AppLogo`, `AppColors.launchBackground`와 같아야 해요.

Flutter 실행 후에는 `AppLaunchGate`가 최소 2초와 첫 화면 준비 완료를 기다린 뒤 250ms 동안 전환해요. 표시 시간과 준비 조건은 네이티브 화면에서 별도로 관리하지 않아요.
