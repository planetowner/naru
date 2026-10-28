# naru 브랜드 애셋

[피그마 승인안 03 · 작은 나룻배](https://www.figma.com/design/GWkDUUxGKUXshtMMFVHAP9?node-id=4-382)을 적용했어요.

| 파일 | 용도 |
| --- | --- |
| `source/naru-symbol.svg` | 피그마에서 내려받은 144×144 벡터 원본. 모든 파생 이미지의 기준이에요. |
| `naru-symbol.png`, `2.0x/`, `3.0x/` | Flutter용 투명 심벌. 144·288·432px예요. |
| `app-icon-1024.png` | 흰색 배경의 1024px 앱 아이콘 원본이에요. |

색상은 디자인 시스템의 `AppColors.primary` (`#3182F6`), `AppColors.blue200` (`#90C2FF`), `AppColors.background` (`#FFFFFF`)를 사용해요. 시작 화면에는 문구 없이 144×144 심벌을 화면 가운데 배치해요. 로그인 화면은 같은 `AppLogo`와 기존 타이포그래피·간격 토큰을 사용해요.

## 플랫폼별 출력

- iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`, `LaunchImage.imageset/`. Flutter와 iOS 시작 로고는 같은 PNG를 사용해요.
- Android: `android/app/src/main/res/mipmap-*/`, `drawable-*/`. 일반 아이콘, adaptive icon 전경, 시작 화면을 밀도별로 생성해요.
- 웹: `web/icons/`, `web/favicon.png`, `web/brand/naru-symbol.svg`. Flutter가 첫 프레임을 그리기 전에도 같은 로고를 보여 줘요.

아이콘은 128px 캔버스에 96px 심벌을 넣은 피그마 비율을 유지해요. PNG에는 둥근 모서리를 넣지 않고 운영체제의 마스크를 사용해요. Android adaptive icon은 108dp 캔버스의 중앙 72dp 영역에 맞춰 배치해요. Android 12 시작 화면은 시스템의 288dp 캔버스 안에 심벌을 144dp로 넣어요. [Android 시작 화면 규격](https://developer.android.com/develop/ui/views/launch/splash-screen)

## 다시 생성하기

`mobile` 폴더에서 실행해요. Node.js와 sharp는 애셋 생성에만 쓰며 앱 실행 의존성에 포함하지 않아요.

```bash
npm install --prefix tool
npm run --prefix tool brand
```

원본을 바꿀 때는 `source/naru-symbol.svg`를 교체하고 위 명령으로 파생 파일을 함께 갱신해요. 플랫폼별 PNG를 따로 수정하지 않아요. 시작 화면의 2초 최소 표시 시간과 250ms 전환은 `AppLaunchGate`에서 관리해요.
