# 담타고고 — iOS 흡연 시뮬레이터

SwiftUI로 만든 iPhone용 인터랙티브 흡연 시뮬레이터입니다. 연초/전자담배 선택, 꺼내기, 점화, 흡입, 햅틱, 연기 파티클, 잔량 영구 저장과 AdMob 적응형 배너가 구현되어 있습니다.

## 실행

```bash
cd ios
xcodegen generate
open SMOK.xcodeproj
```

Xcode에서 개발 팀을 선택한 뒤 iPhone 시뮬레이터나 실제 기기로 실행하세요. Debug 빌드는 Google 공식 테스트 배너를, Release 빌드는 실제 AdMob 배너를 사용합니다.

루트의 웹 파일은 초기 화면 콘셉트 프로토타입이며, 실제 iOS 앱 소스는 `ios/SMOK`에 있습니다.
