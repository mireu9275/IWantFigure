# 조사 key: xplat — 크로스플랫폼 프레임워크 + 3D 렌더링 + AR 선택

- 조사일: 2026-09-24
- 한 줄 요약: C#/Kotlin 경험이 강하고 iOS 경험이 없는 1인 개발자가 "사진 → 온디바이스 ML → 인터랙티브 3D(회전/줌) → 추후 AR" 앱을 iOS/Android 동시 출시하려면, **1순위 Flutter(+thermion/flutter_scene, tflite_flutter/flutter_litert)**, **2순위 Unity(C#) + AR Foundation + Sentis(단독 또는 Flutter에 UaaL 임베드)**, **3순위 KMP/Compose Multiplatform(+SceneView, iOS는 UIKitView 네이티브 뷰)** 순으로 추천한다. RN/Expo는 AR 라이브러리(ViroReact)가 가장 성숙하지만 JS/TS 학습이 필요하고, .NET MAUI와 Godot은 모바일 3D/AR 생태계가 얇아 비추천. iOS 빌드는 결국 macOS+Xcode 26이 필요하므로 Mac mini 구매(US$799~) 또는 Codemagic 무료 500분/월 등 클라우드 macOS를 병행해야 한다.

> 주의: 이 세션의 네트워크 프록시가 docs.flutter.dev, expo.dev, blog.jetbrains.com, docs.unity3d.com, unity.com, godotengine.org, codemagic.io, docs.github.com, support.google.com, apple.com, macrumors.com 등 다수 도메인을 차단했다. 그런 항목은 (a) GitHub raw/pub.dev API/npm registry/Maven Central 같은 기계 판독 가능한 1차 소스, (b) 차단되지 않은 공식 페이지, (c) 검색 결과 스니펫(2차) 순으로 대체 검증했고, 각 항목에 신뢰도를 표시했다. "검색 스니펫" 표기는 원문 페이지를 직접 읽지 못했음을 뜻한다.

---

## 0. 요구사항 재정리 (앱 관점)

| 요구 | 의미 | 프레임워크 선택에 주는 제약 |
|---|---|---|
| iOS + Android | 단일 코드베이스 선호 (1인 개발) | 이중 네이티브는 공수 2배 + Swift 학습 |
| 카메라 촬영 (정지 사진 우선) | 라이브 프레임 스트림은 2단계 | 카메라 플러그인 성숙도 |
| 온디바이스 ML 추론 | LiteRT(TFLite)/ONNX/Core ML 로 경품 배치 유형·아암 인식 | ML 런타임 바인딩 존재 여부, GPU/NPU delegate |
| 인터랙티브 3D 뷰 (회전/줌) | 경품·바·아암을 3D 로 재구성하고 조준점 표시 | glTF 로더 + PBR + 제스처 카메라 컨트롤 |
| 추후 라이브 AR 오버레이 | ARKit/ARCore 평면·앵커 | AR SDK 바인딩 존재 여부 |
| 개발자: C#/Kotlin 강함, iOS 0, Mac 보유 불명 | 언어 친화도, iOS 빌드 환경 | Dart/Kotlin/C# 중 선택 유리; Swift 최소화 |

---

## 1. 프레임워크 비교표 (2026-09-24 기준)

| 항목 | Flutter | React Native (Expo) | KMP + Compose Multiplatform | .NET MAUI | Unity (C#) | Godot | 네이티브 이중 (Kotlin+Swift) |
|---|---|---|---|---|---|---|---|
| (a) 최신 안정 버전 | **3.47.x** (3.47.0 2026-08-12, 3.47.1 2026-08-19; Dart 3.13) — 검색 스니펫(Shorebird 문서). pub.dev 의 flutter_scene 0.23.0 이 "Flutter >=3.47.0" 을 요구(2026-08-25 게시)하므로 3.47 안정 출시는 확인됨 | **RN 0.87.1** (npm 2026-08-26). 0.85.0 2026-04-07, 0.86.0 2026-06-09, 0.87.0 2026-08-11. **Expo SDK 57** (57.0.0 2026-06-30, 최신 57.0.25 2026-09-24), SDK 56.0.0 2026-05-20. SDK 55+ 는 New Architecture 전용 | **Kotlin 2.4.20** (Maven Central 2026-09-07; 2.5.0-Beta1 2026-09-23). **Compose Multiplatform 1.12.1** (GitHub 릴리스 2026-09-22). kotlinlang 호환표: Android/iOS/macOS/Windows/Linux/Web(WasmGC) 모두 **Stable** | **.NET MAUI 10** (2025-11-11 출시, 10.0.101 2026-09-07, 10.0.110 2026-09-22). MAUI 11 RC1 (2026-09-08, Xcode 26.6 권장). MAUI 10 지원 종료 **2027-05-11** (dotnet.microsoft.com 지원 정책) | **Unity 6.3 LTS** (6000.3.x, LTS 2027-12 까지) + 6.4 메인라인, 6.5 beta (arfoundation-samples README). Personal 은 연매출/펀딩 **US$200K 미만** 무료, Runtime Fee 폐지 (unity.com 스니펫) | **4.7.2-stable** (2026-08-18), 4.7 2026-06-18, 4.6 2026-01-26. MIT | Android: Kotlin + Jetpack Compose. iOS: Swift + SwiftUI, **Xcode 26** 필수 |
| 성숙도 | 매우 높음. Impeller 가 3.47 부터 모든 네이티브 플랫폼 기본 렌더러 | 매우 높음. New Arch 만 지원 | 높음(iOS UI 는 1.8.0/2025-05 부터 Stable) | 높음(하지만 모바일 3D/AR 얇음) | 매우 높음(게임/AR) | 높음(게임), 모바일 AR 낮음 | 최고 |
| (b) 카메라/ML | camera 0.12.1 (2026-09-03), tflite_flutter 0.12.1 (2025-10-28, 공식 tensorflow/flutter-tflite), flutter_litert 3.9.1 (2026-09-22), google_mlkit_object_detection 0.17.1 (2026-08-17) | react-native-vision-camera 5.2.3 (2026-08-20, Nitro), react-native-fast-tflite 3.0.1 (2026-04-21, MIT, CoreML/GPU/NNAPI delegate, VisionCamera v5 frame processor 연동, Expo config plugin) | CameraK 1.2 (Apache-2.0, 579★, Analyzer 프레임 제공), KTensorFlow (Apache-2.0, 34★, iOS 는 CocoaPods 만), kflite, moko-tensorflow. 실무는 expect/actual 로 Android LiteRT Kotlin + iOS LiteRT Swift/Core ML | CommunityToolkit.Maui.Camera 6.1.0 (2026-06-02, MIT), Microsoft.ML.OnnxRuntime 1.30.0 (2026-09-10; net9.0-android/ios, CoreML/XNNPACK EP), Xamarin.TensorFlow.Lite 2.16.1.10 (2026-06-27) | AR Foundation 카메라 + **Sentis(com.unity.ai.inference) 2.6.x** (ONNX, GPUCompute/CPU; 2.6.1 2026-04 — 검색 스니펫) | 카메라 플러그인은 서드파티; ML 바인딩 사실상 없음(GDExtension 직접 작성) | CameraX + LiteRT Kotlin / AVFoundation + Core ML·Vision |
| (c) 3D 렌더링 | **thermion_flutter 0.5.0** (Filament 1.76.0, Apache-2.0), **flutter_scene 0.23.0** (Flutter GPU, MIT, pre-1.0), model_viewer_plus 1.10.0 (WebView), flutter_3d_controller 2.3.0 (WebView). flutter_gl/three_dart 는 2022 이후 방치(Dart<3.0) | **react-native-filament 1.11.0** (2026-05-27, MIT, 1.4k★, old+new arch), expo-gl 57.0.2 + @react-three/fiber 9.8.0 (expo-three 는 8.0.0/2024-07 정체, 버전 불일치 이슈) , ViroReact 3D 씬 | **SceneView 4.39.0** (Android, Compose+Filament, Apache-2.0, Maven 2026-09-22). iOS 는 SceneViewSwift(RealityKit, **alpha**) 또는 UIKitView 로 SceneKit/RealityKit 직접 | **Evergine** (.NET 3D 엔진, 상용 무료 — 검색 스니펫; evergine.com 차단으로 iOS 지원 미확인), SkiaSharp(2D) | 내장 | 내장 | Android Filament/SceneView, iOS SceneKit/RealityKit |
| (d) AR SDK | arkit_plugin 1.5.0 (2026-08-03, iOS 13+, 509 likes, 활발), ar_flutter_plugin 0.7.3 (2022, 사망), ar_flutter_plugin_2 0.0.3 (2025-03, Dart<3.0 제약!), ar_flutter_plugin_engine 1.0.1 (2024-07), arcore_flutter_plugin 0.1.0 (2023, 사망). 대안: flutter_embed_unity 2.0.0 (2026-04-13) 로 AR Foundation 임베드 | **ViroReact @reactvision/react-viro 3.0.1** (2026-09-21, MIT, 1.8k★, ReactVision 사 전담팀; ARKit iOS 15.1+/ARCore/Quest/visionOS/Web, RN CLI+Expo, Fabric interop) | Android: arsceneview 4.39.0 (ARCore). iOS: ARKit 은 Swift 로 직접 작성 후 UIKitView 임베드 | 공식 옵션 없음(네이티브 바인딩 직접) | **AR Foundation 6.3/6.4** (ARCore 1.48, ARKit; 6.5 beta) — 업계 표준 | godot_arcore (GDExtension, Godot 4.2+, MIT, ~92★, 포럼상 WIP), iOS ARKit 플러그인 없음 | ARKit/ARCore 직접 |
| (e) 스토어 배포 | 성숙(양 스토어 방대한 사례) | 성숙(EAS Build 로 클라우드 iOS 빌드 가능) | 성숙(Android), iOS 는 Xcode 프로젝트 유지 | 성숙 | 성숙(단, 앱 용량 큼) | 가능(iOS C# export 는 experimental) | 최고 |
| (f) 이 개발자 학습 곡선 | Dart 는 Kotlin/C# 과 문법 유사 → 낮음. 위젯 패러다임은 Compose 와 유사 | JS/TS + React 패러다임 신규 → 중~높음 | Kotlin 그대로 → **가장 낮음**. 단, iOS 3D/AR 은 Swift 필요 | C#/XAML → 낮음(WinForms 와 다른 MVVM/XAML) | C# → 낮음, 하지만 "앱 UI" 를 Unity 로 만드는 건 비효율 | GDScript/C# → 중 | Swift/SwiftUI 신규 → 높음 |
| (g) 한국/일본 커뮤니티 | **일본 최대**: FlutterKaigi 2026 (2026-10-29~30, 浜松町コンベンションホール, FlutterNinjas 와 합동, 세션 1/3 영어, 티켓 ¥9,900~13,200 — 검색 스니펫). 한국: Flutter Korea/Flutter Seoul (GitHub org 152 followers, "2026 Flutter Korea conference" 사이트 저장소 2026-09-09 갱신 — 확인) | 일본: React Native Japan (connpass, Meetup #24 2026-02-12 — 스니펫). 한국: 미확인 | 일본: JKUG Kotlin Fest 2026 (2026-11-14, 東京コンファレンスセンター品川 — 스니펫). 한국: Kotlin/Android 커뮤니티 큼(미검증) | 한국/일본 모두 작음 | 일본 게임 개발 커뮤니티 매우 큼(Unity Japan) — 미검증 | 중 | Android 커뮤니티 매우 큼 |
| (h) 장기 리스크 | Google 지원, 3D 패키지는 pre-1.0(개인 유지보수: thermion=nmfisher, flutter_scene=bdero(Flutter 팀 출신)) | Meta 지원. Margelo 의 filament v2 재작성 진행 중(RNWC 제거) | JetBrains 지원, iOS 3D 는 자체 유지 | Microsoft 지원이나 MAUI 11 은 LTS 아님(MAUI 는 LTS 개념 없음, 후속 출시 후 6개월) | 라이선스 변경 전력(2023 Runtime Fee → 2024 철회) | 재단 운영, 모바일 AR 미성숙 | 없음 |
| 라이선스 | BSD-3 | MIT | Apache-2.0 | MIT | 독점(Personal 무료 <US$200K) | MIT | — |

---

## 2. 3D/AR/ML 라이브러리 표 (이름 / 최신 버전 / 최근 업데이트 / 플랫폼 / 라이선스 / URL / 비고)

### 2-1. 3D 렌더링

| 이름 | 버전 | 최근 업데이트 | 플랫폼 | 라이선스 | URL | 비고 |
|---|---|---|---|---|---|---|
| thermion_flutter | 0.5.0 | 2026-08-20 (pub.dev API) | iOS arm64, Android arm64, macOS, Windows x64, Web/WASM | Apache-2.0 | https://pub.dev/packages/thermion_flutter , https://github.com/nmfisher/thermion | Google Filament 1.76.0 기반 PBR, glTF/KTX, 스키닝/모프, 모바일 제스처 카메라. 221★, 19 likes, 140 pts. 첫 빌드 시 네이티브 바이너리 다운로드 |
| flutter_scene | 0.23.0 | 2026-08-25 (pub.dev API) | iOS, Android, Web, macOS, Windows, Linux | MIT | https://pub.dev/packages/flutter_scene , https://github.com/bdero/flutter_scene | Flutter GPU 기반, Flutter >=3.47 필수, `flutter run --enable-flutter-gpu` 로 활성화. PBR/IBL/그림자/후처리/가우시안 스플래팅. **pre-1.0, minor 에 breaking**. 792★, 339 likes, 150 pts |
| model_viewer_plus | 1.10.0 | 2025-11-26 | Android(API24+), iOS, Web | Apache-2.0 | https://pub.dev/packages/model_viewer_plus | WebView 에 Google `<model-viewer>` 임베드. 회전/줌은 되지만 커스텀 마커/조준점 오버레이 제어가 제한적. AR 은 Scene Viewer / AR Quick Look 위임 |
| flutter_3d_controller | 2.3.0 | 2025-09-13 | Android, iOS, Web | (pub.dev 참조) | https://pub.dev/packages/flutter_3d_controller | WebView 기반 model-viewer 컨트롤러 |
| flutter_gl / three_dart | 0.0.21 / 0.0.16 | 2022-10-04 / 2022-11-19 | — | MIT | https://pub.dev/packages/flutter_gl , https://pub.dev/packages/three_dart | **Dart <3.0 제약, 사실상 방치**. 사용 금지 |
| react-native-filament | 1.11.0 | 2026-05-27 (npm) | iOS(Metal), Android(OpenGL/Vulkan) | MIT | https://www.npmjs.com/package/react-native-filament , https://github.com/margelo/react-native-filament | Margelo. old+new arch, react-native-worklets-core 의존. v2(worklets 로 이전) PR #327 2026-01 진행. 1.4k★ |
| expo-gl + @react-three/fiber (+expo-three) | 57.0.2 / 9.8.0 / 8.0.0 | 2026-07-15 / 2026-09-22 / 2024-07-28 | iOS, Android, Web | MIT | https://www.npmjs.com/package/expo-gl , https://github.com/expo/expo-three | expo-three 정체, New Arch 이슈(gpujs/expo-gl#7), SDK 별 expo-gl 버전 불일치 사례. JS 스레드 렌더링 |
| ViroReact (@reactvision/react-viro) | 3.0.1 | 2026-09-21 (npm) | iOS(ARKit, 15.1+), Android(ARCore), Meta Quest, visionOS, Web | MIT | https://www.npmjs.com/package/@reactvision/react-viro , https://github.com/ReactVision/viro | 3D 씬 + AR 통합. Expo/RN CLI 지원, Fabric interop 레이어. 1.8k★ |
| SceneView (Android) | 4.39.0 | 2026-09-22 (Maven Central) | Android(Compose+Filament+ARCore), iOS(SwiftUI+RealityKit, **alpha**), Web(Filament.js), Desktop | Apache-2.0 | https://github.com/SceneView/sceneview-android | `io.github.sceneview:sceneview` / `arsceneview`. 매우 활발(9월에만 7개 릴리스). KMP core 모듈 있음 |
| Google Filament | 1.77.1 | 2026-09-21 (GitHub 릴리스; Maven 1.77.0 2026-09-21) | Android, iOS 11+, macOS, Windows, Linux, WebGL2/WASM | Apache-2.0 | https://github.com/google/filament | 20.5k★. thermion/react-native-filament/SceneView 의 공통 기반 |
| Evergine (.NET) | 2026 릴리스 | 2026 (검색 스니펫) | Windows, Android, (iOS/Web 여부 미확인) | 상용 무료(스니펫) | https://evergine.com/ (차단), https://devblogs.microsoft.com/dotnet/dotnet-maui-3d-app-with-evergine/ (차단) | .NET MAUI 용 EvergineView 존재. iOS 지원·성숙도 미검증 |
| Unity 6.3 LTS | 6000.3.x | 2026 분기별 | 전 플랫폼 | Unity Personal(무료 <US$200K) | https://unity.com/releases/unity-6 (차단) | 내장 3D |
| Godot | 4.7.2 | 2026-08-18 | 전 플랫폼 | MIT | https://github.com/godotengine/godot/releases | 내장 3D |

### 2-2. AR

| 이름 | 버전 | 최근 업데이트 | 플랫폼 | 라이선스 | URL | 비고 |
|---|---|---|---|---|---|---|
| arkit_plugin (Flutter) | 1.5.0 | 2026-08-03 | iOS 13+ (A9+) | MIT | https://pub.dev/packages/arkit_plugin | 평면 감지, 이미지 앵커, glTF/glb 로드, 물리, 라이트 추정. 509 likes/160 pts. 가장 건강한 Flutter AR 플러그인(iOS 전용) |
| ar_flutter_plugin | 0.7.3 | 2022-11-19 | — | MIT | https://pub.dev/packages/ar_flutter_plugin | **사망** (Dart <3.0) |
| ar_flutter_plugin_2 | 0.0.3 | 2025-03-17 | Android(sceneview_android), iOS | MIT | https://pub.dev/packages/ar_flutter_plugin_2 | pubspec 이 여전히 Dart >=2.16.1 <3.0.0 → 최신 Flutter 와 호환 의문. AI 보조 마이그레이션 자백. 17 likes |
| ar_flutter_plugin_engine | 1.0.1 | 2024-07-03 | Android, iOS | (pub.dev) | https://pub.dev/packages/ar_flutter_plugin_engine | Dart <3.0 제약 |
| arcore_flutter_plugin | 0.1.0 | 2023-02-07 | Android | (pub.dev) | https://pub.dev/packages/arcore_flutter_plugin | 사망 |
| flutter_embed_unity | 2.0.0 (2.1.0-dev.1) | 2026-04-13 | Android API 23+, iOS 13+ ; Unity 2022.3 LTS / 6000.0 / 6000.3 LTS | MIT | https://pub.dev/packages/flutter_embed_unity | 검증된 퍼블리셔(learntoflutter.com). AR Foundation/ARKit/ARCore 동작. **단일 Unity 인스턴스, 백그라운드 메모리 상주**, Java 17/Gradle 8 정렬 필요 |
| flutter_unity_widget / _2 | 2022.2.1 / 6000.1.0+1 | 2024-01-08 / 2025-08-04 | — | (pub.dev) | https://pub.dev/packages/flutter_unity_widget_2 | 원본은 정체, _2 포크가 Unity 6000 실험 브랜치 기반 |
| ViroReact | 3.0.1 | 2026-09-21 | 상동 | MIT | 상동 | RN 진영 AR 의 사실상 표준 |
| SceneView arsceneview | 4.39.0 | 2026-09-22 | Android | Apache-2.0 | https://github.com/SceneView/sceneview-android | KMP/네이티브 Android AR |
| AR Foundation | 6.3 (Unity 6000.0+ 호환, samples main) / 6.4 / 6.5 beta | 2026 | iOS(ARKit), Android(ARCore 1.48), visionOS 등 | Unity 패키지 라이선스 | https://github.com/Unity-Technologies/arfoundation-samples | Unity 6.3 LTS 브랜치 별도 |
| godot_arcore | (미출시) | — | Android(Godot 4.2+) | MIT | https://github.com/GodotVR/godot_arcore | GDExtension, 빌드 절차 복잡, ~92★. iOS ARKit 대응 없음 |
| Unity as a Library (UaaL) | Unity 6000.0.0b16+ (Android), 2021.3.28+ (iOS) | — | Android, iOS | Unity | https://github.com/Unity-Technologies/uaal-example | **전체 화면 렌더링만 지원, 단일 인스턴스, 언로드 상태 오버헤드 Android 90MB / iOS 110MB**, Xamarin 비호환 |

### 2-3. 온디바이스 ML / 카메라

| 이름 | 버전 | 최근 업데이트 | 플랫폼 | 라이선스 | URL | 비고 |
|---|---|---|---|---|---|---|
| tflite_flutter | 0.12.1 | 2025-10-28 | Android, iOS(+desktop) | Apache-2.0 | https://pub.dev/packages/tflite_flutter | TensorFlow 공식 리포(tensorflow/flutter-tflite). delegate 지원 |
| flutter_litert | 3.9.1 | 2026-09-22 | Android, iOS, macOS, Windows, Linux, Web | (pub.dev) | https://pub.dev/packages/flutter_litert | LiteRT 런타임 번들. 매우 활발 |
| google_mlkit_object_detection | 0.17.1 | 2026-08-17 | Android, iOS | (pub.dev) | https://pub.dev/packages/google_mlkit_object_detection | ML Kit 객체 감지(커스텀 TFLite 모델 가능) |
| camera (Flutter 공식) | 0.12.1 | 2026-09-03 | Android, iOS, Web | BSD-3 | https://pub.dev/packages/camera | `startImageStream` 으로 프레임 스트림 |
| react-native-fast-tflite | 3.0.1 | 2026-04-21 | iOS(CoreML delegate), Android(GPU/NNAPI) | MIT | https://www.npmjs.com/package/react-native-fast-tflite | Nitro Modules, zero-copy, VisionCamera v5 frame processor, Expo config plugin |
| react-native-vision-camera | 5.2.3 | 2026-08-20 | iOS, Android | MIT | https://www.npmjs.com/package/react-native-vision-camera | v5 = Nitro 기반 |
| CameraK (KMP) | 1.2 | 2026 | Android API21+, iOS 13+, JVM | Apache-2.0 | https://github.com/Kashif-E/CameraK | Analyzer 플러그인으로 프레임 ByteArray 수신(JPEG). 579★ |
| KTensorFlow (KMP) | 1.2 | — | Android, iOS(CocoaPods only) | Apache-2.0 | https://github.com/kursor1337/KTensorFlow | 34★, GPU/NPU delegate. 소규모 |
| LiteRT (Google AI Edge) | 6~8주 주기 | 2026 | Android(Kotlin/Java), iOS(Swift/ObjC), C++, Python, Web | Apache-2.0 | https://github.com/google-ai-edge/LiteRT | 공식 언어 API. Compiled Model API 권장 |
| CommunityToolkit.Maui.Camera | 6.1.0 | 2026-06-02 | Android, iOS, Windows, Mac Catalyst | MIT | https://www.nuget.org/packages/CommunityToolkit.Maui.Camera | 프리뷰/촬영/줌/플래시 |
| Microsoft.ML.OnnxRuntime | 1.30.0 | 2026-09-10 | net9.0-android35, net9.0-ios18, maccatalyst | MIT | https://www.nuget.org/packages/Microsoft.ML.OnnxRuntime | CoreML/XNNPACK EP 포함 |
| Xamarin.TensorFlow.Lite | 2.16.1.10 | 2026-06-27 | Android | MIT+Apache-2.0 | NuGet | Android 전용 바인딩 |
| Unity Sentis (com.unity.ai.inference) | 2.6.1 | 2026-04-02(검색 스니펫) | Unity 전 플랫폼 | Unity 패키지 라이선스 | https://github.com/Unity-Technologies/sentis-samples | ONNX 입력, GPUCompute/CPU 백엔드, FP16/UInt8 양자화. 2025-08 "Inference Engine" 으로 개명 후 2.4 부터 표시명 Sentis 로 복귀(스니펫) |

---

## 3. 하이브리드 옵션 평가

| 하이브리드 | 구성 | 장점 | 단점/리스크 | 판정 |
|---|---|---|---|---|
| **A. Flutter 앱 + Unity as a Library(flutter_embed_unity)** | Flutter 로 촬영/UI/ML, Unity 씬으로 3D·AR | AR Foundation + Sentis 를 그대로 사용, C# 재사용, 3D 툴링 최강 | UaaL 은 전체 화면 전용·단일 인스턴스·90~110MB 상주, 앱 용량 +수십MB, Unity Splash(Personal), Gradle/JDK/Xcode 버전 정렬 부담, 두 프로젝트 유지 | 2단계(라이브 AR) 진입 시 유력한 "탈출구". 1단계에서는 과함 |
| **B. Flutter 앱 + 네이티브 3D PlatformView** | Android SceneView(Kotlin), iOS SceneKit/RealityKit(Swift) 를 PlatformView 로 | 렌더 품질/AR 접근성 최고 | iOS 는 Swift 작성 필요, PlatformView 합성 오버헤드(iOS 는 Hybrid composition 만), 두 벌 3D 코드 | thermion/flutter_scene 이 요구를 못 맞출 때의 대안. iOS 경험 0 인 현 시점에선 비추천 |
| **C. KMP 로직 공유 + 각 플랫폼 네이티브 UI** | 공통 Kotlin(ML 전/후처리, 조준 알고리즘) + Android Compose/SceneView + iOS SwiftUI/RealityKit | Kotlin 강점 극대화, Android 는 즉시 최고 품질 | iOS UI/3D/AR 전부 Swift → 1인 개발자에게 사실상 이중 코드베이스 | Android 선출시 전략이면 고려. iOS 동시 출시엔 부적합 |
| **D. Compose Multiplatform UI + UIKitView 로 iOS 3D 뷰만 네이티브** | UI/로직 Kotlin 공유, Android 3D=SceneView, iOS 3D=SceneKit(UIKitView) | Swift 코드 최소화(3D 뷰 하나) | iOS SceneKit 코드는 여전히 Swift/ObjC, Kotlin/Native cinterop 학습 필요 | 3순위 안의 실제 구현 형태 |
| **E. Unity 단독 앱** | Unity UI Toolkit 로 앱 UI 까지 | 단일 프로젝트, 3D/AR/ML 통합 최상 | 앱형 UI(폼, 리스트, 로컬라이즈, 접근성)가 비효율, 배터리/용량, 스토어에서 "앱" 으로서의 완성도 낮아 보일 위험 | 2순위 |

---

## 4. iOS 빌드 환경과 비용 (2026-09-24 기준)

| 항목 | 내용 | 근거/신뢰도 |
|---|---|---|
| Xcode 필요성 | iOS/App Store 빌드는 macOS + Xcode 필수(모든 프레임워크 공통; Godot 문서도 "iOS export 는 macOS 에서만"). **2026-04-28 부터 App Store 제출은 Xcode 26 + iOS 26 SDK 필수** | developer.apple.com 뉴스(검색 스니펫) — 중 |
| Xcode 26 요구 macOS | Xcode 26~26.3: macOS Sequoia 15.6+; **Xcode 26.4+: macOS Tahoe 26.2+**. visionOS 개발은 Apple silicon 필수 | https://developer.apple.com/xcode/system-requirements (직접 확인) — 높음 |
| Apple Developer Program | **US$99/년**(개인/조직 동일, 2FA 필수, 법적 성인). 무료 계정은 7일 프로비저닝·3대 기기·TestFlight 불가 | https://developer.apple.com/programs/enroll/ , https://developer.apple.com/support/compare-memberships/ (직접 확인) — 높음 |
| Google Play 등록비 | **US$25 일회성**. 개인 계정 신규는 12명 테스터 14일 비공개 테스트 요건(2023-11~) | support.google.com 차단 → 검색 스니펫 다수 일치 — 중 |
| Mac mini 구매 | 기본형 **US$799** (M4, 16GB/512GB; 2026-05-01 256GB 모델 단종으로 $599→$799), M4 Pro **US$1,599** (2026-06-25 인상). M6 Mac mini US$899 언급 있음(미검증) | macrumors 스니펫 — 중 |
| Codemagic | 개인 계정 **월 500분 무료(macOS M2)**, 초과 M2 $0.095/분, **M4 $0.114/분**, Linux/Windows $0.045/분, 동시 빌드 1. 팀 연간 M2 $3,990/M4 $5,400(3 동시, 무제한) | codemagic-docs GitHub raw (직접 확인) — 높음 |
| GitHub Actions | 표준 macOS 3/4-core **$0.062/분**, macOS 12-core $0.077, M2 Pro 5-core $0.102(대형 러너, 무료분 사용 불가). Free 플랜 사설 저장소 2,000분/월, Pro 3,000분/월; **공개 저장소는 표준 러너 무료** | github/docs raw (직접 확인) — 높음. macOS 배율(10x) 은 2차 소스 — 중 |
| MacinCloud | Managed(공유) 약 $25~29/월, Dedicated M2 $99/월, M4 $124.99/월, PAYG 약 $1/시간 | 검색 스니펫만(사이트 차단) — 낮음 |
| Unity Build Automation | Free tier 에 **월 100분 Mac 빌드** 추가(2026 Q1 예정 발표), Mac 없이 iOS 빌드·서명 가능 | unity.com 스니펫 — 중 |
| Expo EAS Build | Expo 선택 시 클라우드 iOS 빌드(별도 요금) | expo.dev 차단 — 미검증 |

비용 시나리오(1인, 1년차):
- 최소: Apple $99 + Google $25 + Codemagic 무료 500분(Flutter iOS 빌드 1회 10~20분 가정 → 월 25~50회) = **약 US$124**. 단, 실기기 디버깅/Xcode 프로젝트 설정(권한 plist, 서명)을 Mac 없이 하기는 매우 고통스럽다.
- 권장: Mac mini M4 US$799 (일본/한국 현지가는 별도) + $124 = **약 US$923**. Xcode 26.4+ 는 Tahoe 26.2+ 이므로 Apple silicon 권장.
- 중간: MacinCloud Managed ~$29/월 × 12 = ~$348 + $124.

---

## 5. 후보별 상세 평가

### 5-1. Flutter (1순위)
- 강점: Dart 는 Kotlin/C# 개발자가 1~2주면 적응. 단일 코드베이스로 iOS UI 를 Swift 없이 완성. 카메라(camera 0.12.1)·ML(tflite_flutter/flutter_litert/ML Kit) 이 전부 살아있고, **3D 는 Filament 기반 thermion(0.5.0) 과 Flutter GPU 기반 flutter_scene(0.23.0) 두 축이 2026-08 에 업데이트**. 일본(FlutterKaigi)·한국(Flutter Seoul) 커뮤니티가 후보 중 가장 크고 활발.
- 약점: 3D 패키지가 pre-1.0(개인 유지보수). AR 은 iOS(arkit_plugin) 만 건강하고 Android ARCore 플러그인은 사실상 사망 → 라이브 AR 단계에선 (a) flutter_embed_unity 로 AR Foundation 임베드, (b) SceneView(Android)+arkit_plugin(iOS) 조합, (c) 직접 PlatformView 중 택1 필요.
- 권장 스택(1단계): Flutter 3.47 + camera + flutter_litert(or tflite_flutter) + thermion_flutter(글TF 로 경품·바·아암 프리미티브 구성, 조준점 노드 추가) + Riverpod. thermion 이 불안정하면 flutter_scene 으로 교체(둘 다 glTF).
- 2단계(AR): arkit_plugin(iOS) + flutter_embed_unity(Android/iOS 공통 AR Foundation) 또는 Unity 로 AR 화면 전체를 이관.

### 5-2. Unity (2순위) — 단독 또는 UaaL
- 강점: C# 그대로. AR Foundation(6.3)·Sentis(2.6) 로 "3D 재구성 + AR 오버레이 + ONNX 추론" 이 한 프로젝트에서 해결. Personal 무료(연매출 <US$200K), Runtime Fee 없음. Unity Build Automation 으로 Mac 없이도 iOS 빌드 가능(월 100분).
- 약점: 앱형 UI(촬영 플로우, 설정, 다국어 텍스트)를 Unity UI 로 만드는 비용, 앱 용량(수십 MB+), Personal 스플래시, 라이선스 변경 전력. UaaL 로 Flutter 에 임베드하면 전체화면·단일 인스턴스·메모리 오버헤드 제약.
- 추천 형태: 1단계는 Flutter 로 시작하되 3D 요구가 thermion/flutter_scene 한계를 넘거나 라이브 AR 단계가 되면 Unity 씬을 flutter_embed_unity 로 붙이는 "A 하이브리드".

### 5-3. Kotlin Multiplatform + Compose Multiplatform (3순위)
- 강점: 언어 학습 0. CMP 1.12.1 은 iOS Stable. Android 쪽은 SceneView 4.39.0(Compose 네이티브 3D+AR) 로 즉시 최고 품질. CameraK 로 카메라 공통화.
- 약점: iOS 3D/AR 을 커버하는 KMP 라이브러리가 없다(SceneView iOS 는 Swift/RealityKit alpha). 결국 UIKitView + SceneKit/RealityKit 을 Swift 또는 Kotlin/Native cinterop 로 작성 → iOS 경험 0 인 개발자에게 병목. ML 도 expect/actual 로 두 벌.
- 언제 택하나: Android 선출시 + iOS 후속, 또는 Swift 를 배울 의지가 있을 때.

### 5-4. React Native (Expo) (4순위)
- 강점: **ViroReact 3.0(2026-09)** 가 후보 중 유일하게 "회사가 전담 유지보수하는 크로스플랫폼 AR+3D" 이고 Expo 와 New Arch 를 지원. react-native-filament + fast-tflite + VisionCamera 조합도 성숙(Margelo). EAS Build 로 클라우드 iOS 빌드.
- 약점: JS/TS + React 패러다임을 새로 배워야 함. New Arch 전환기의 라이브러리 호환 이슈(expo-gl/three 정체). 일본 RN 커뮤니티는 Flutter 보다 작음.

### 5-5. .NET MAUI (5순위)
- C# 친화적이나 모바일 3D(Evergine 뿐, iOS 지원 미검증)·AR(공식 없음) 생태계가 얇고, MAUI 는 LTS 개념이 없어 매년 마이그레이션 압박(MAUI 10 지원 종료 2027-05-11). ML 은 ONNX Runtime 1.30 으로 가능.

### 5-6. Godot (6순위)
- C# iOS export 가 여전히 experimental, godot_arcore 는 빌드 절차 복잡·ARKit 없음. 앱형 UI 에도 부적합.

### 5-7. 네이티브 이중 (7순위)
- 품질 최고이나 Swift/SwiftUI/ARKit/RealityKit 학습 + 코드 2벌. 1인 개발 초기엔 비현실적.

---

## 6. 최종 순위와 근거

1. **Flutter + thermion_flutter(→flutter_scene 대체 가능) + flutter_litert/tflite_flutter + camera**, AR 은 arkit_plugin + (필요 시) flutter_embed_unity. — 단일 코드베이스·낮은 학습 곡선·최대 KR/JP 커뮤니티·3D 옵션 2개 존재.
2. **Unity 6.3 LTS + AR Foundation 6.3 + Sentis 2.6** (단독 앱 또는 Flutter 에 UaaL 임베드). — C# 재사용, AR/3D/ML 통합 최강, 단 앱 UI/용량/라이선스 리스크.
3. **KMP + Compose Multiplatform + SceneView(Android) + UIKitView SceneKit(iOS)**. — Kotlin 강점, iOS 3D/AR 은 Swift 의존.
4. React Native(Expo) + ViroReact/react-native-filament + fast-tflite. — AR 라이브러리 최성숙, JS 학습 필요.
5. .NET MAUI, 6. Godot, 7. 네이티브 이중.

의사결정 트리거:
- 1단계(정지 사진 → 3D 추천)만 6개월 내 출시: **Flutter**.
- 처음부터 라이브 AR 이 핵심이고 C# 을 버리기 싫다: **Unity 단독**.
- Android 먼저, iOS 는 나중: **KMP/CMP**.

---

## 7. 검증 상태 요약 (직접 읽은 1차 소스)
- pub.dev API (버전/게시일): flutter_scene, thermion_flutter, tflite_flutter, flutter_litert, camera, ar_flutter_plugin_2/_engine/_updated, arkit_plugin, arcore_flutter_plugin, model_viewer_plus, flutter_embed_unity, flutter_unity_widget(_2), google_mlkit_object_detection, flutter_gl, three_dart, flutter_3d_controller
- npm registry: react-native-fast-tflite, react-native-filament, react-native-vision-camera, @reactvision/react-viro, expo, react-native, expo-gl, expo-three, @react-three/fiber, react-native-worklets-core, react-native-nitro-modules
- Maven Central: kotlin-stdlib, io.github.sceneview:sceneview, com.google.android.filament:filament-android
- NuGet API: CommunityToolkit.Maui.Camera, Microsoft.ML.OnnxRuntime, Xamarin.TensorFlow.Lite
- GitHub 페이지/raw: flutter_scene README, thermion README, react-native-filament, ReactVision/viro, SceneView README, google/filament, uaal-example README, arfoundation-samples README, godot_arcore README, godot-docs C# 페이지, godot releases, JetBrains/compose-multiplatform v1.12.1 태그, kotlin releases, dotnet/maui releases, KTensorFlow, CameraK, LiteRT README, flutter-korea org, codemagic-docs pricing.md, github/docs actions 요금 md
- 공식 페이지: developer.apple.com (enroll, compare-memberships, xcode/system-requirements), kotlinlang.org (호환표, UIKit interop), dotnet.microsoft.com MAUI 지원정책, pub.dev 패키지 페이지
- 2차(검색 스니펫만): Flutter 3.47 날짜, Expo SDK 56/57 의 RN 버전 매핑, Unity Personal 임계값·Sentis 2.6.1·Build Automation 100분, Google Play $25, Mac mini 가격, MacinCloud 가격, FlutterKaigi/Kotlin Fest/RN Japan 일정, GitHub Actions macOS 배율, Stack Overflow 2024 설문(Flutter 9.4% vs RN 8.4%)
