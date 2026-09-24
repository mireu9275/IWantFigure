# IWantFigure app (Flutter)

크레인게임 사진을 분석해 조준 위치를 추천하는 앱의 클라이언트. 구조·좌표계·룰 엔진 설명은 `../docs/02_MVP_구현_가이드.md` 참조.

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

- 기본 모의(mock) 모드: 서버 없이 `assets/samples/bridge_parallel.json`으로 전체 흐름 동작.
- 실제 분석: 설정 → 모의 모드 끄기 → 서버 URL(Android 에뮬레이터는 `http://10.0.2.2:8080`).
- `lib/engine/` 룰 엔진과 `lib/scene3d/` 3D 뷰는 순수 Dart/Flutter이며 `flutter test`로 검증한다.
