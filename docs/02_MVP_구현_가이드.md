# IWantFigure MVP 구현 가이드

- 작성일: 2026-09-24
- 대상: 이 저장소를 이어서 개발할 사람(1인 개발자). 코드 구조, 좌표계, 룰 엔진, 실행 방법, 남은 일을 정리한다.
- 기획·기술 배경은 `01_기획_기술_분석.md` 참조.

## 1. 전체 구조

```
IWantFigure/
├─ app/        Flutter 앱 (iOS/Android)            ← Dart
├─ server/     ASP.NET Core 분석 API (.NET 10)     ← C#
├─ shared/     앱·서버 공용 계약 (JSON 스키마, 시스템 프롬프트, 샘플 응답)
└─ docs/       기획·분석·가이드
```

데이터 흐름(MVP):

```
[앱] 촬영/갤러리 → 리사이즈(장변 1,456px) → POST /api/v1/analyze (base64 JPEG)
[서버] EXIF 보정·리사이즈 → LLM(Gemini 또는 Claude) 호출: 시스템 프롬프트 + JSON 스키마 → 좌표 정규화·검증 → AnalysisResult
[앱] AnalysisResult + 사용자 보정 + 경품 치수 + 플레이 관찰 → AimEngine(룰 엔진) → AimPlan
      AimPlan.overlay → 사진 오버레이 / AimPlan.scene → 3D 뷰 / AimPlan.steps → 단계별 안내
```

핵심 설계 결정:

| 결정 | 이유 |
|---|---|
| 조준 좌표는 LLM이 아니라 앱의 룰 엔진이 계산 | 2026년 VLM의 포인팅 정확도는 사람 대비 약 70%. LLM은 유형·객체 박스·전략·설명만 담당 |
| 룰 엔진은 앱(클라이언트)에 둔다 | 보정·관찰 입력에 즉시 반응해야 하고, 서버 장애 시에도 유형만 고르면 추천 가능 |
| 3D는 사진 복원이 아니라 파라메트릭 씬 | 바 2개·상자·아암·낙하구면 충분. 소프트웨어 렌더러라 외부 패키지 의존 없음 |
| 모크 모드 기본 ON | 서버·API 키 없이도 앱 전체 흐름이 동작(번들 샘플 응답) |
| 공용 계약은 `shared/` 하나 | 서버는 EmbeddedResource 링크, 앱은 assets 복사본으로 동일 파일 사용 |

## 2. 공용 계약 (`shared/`)

- `analysis.schema.json` — LLM/서버 응답 스키마. 좌표는 **분석된 이미지 기준 0..1 정규화**, 원점 좌상단, x 오른쪽, y 아래.
- `prompt/system_prompt.md` — 배치 유형 분류 체계(15종)와 규칙. 서버가 그대로 시스템 프롬프트로 사용.
- `samples/bridge_parallel.json` — 橋渡し 샘플. 앱 모크 모드와 테스트, 서버 Mock 프로바이더가 공유.

응답 예(서버가 `analysis_id`, `provider`, `model`, `latency_ms`, `image{width,height}`를 덧붙임):

```json
{
  "analysis_id": "…", "provider": "gemini", "model": "gemini-2.5-flash", "latency_ms": 3120,
  "image": {"width": 1456, "height": 1092},
  "layout_type": "bridge_parallel", "confidence": 0.82,
  "machine": {"claw_count": 2, "arm_power_estimate": "unknown", "assist_lamp": "blue", "exit_side": "center"},
  "objects": [{"id": "box1", "kind": "box", "bbox": [0.36, 0.42, 0.64, 0.74], "notes": ""}, …],
  "strategy": {"technique": "tate_hame", "target_object_id": "box1", "target_edge": "back_right", "arm": "right",
               "sequence": ["…"], "abort_if": ["…"], "expected_motion": "…"},
  "explanation": "…", "needs_more_photos": [], "warnings": ["…"]
}
```

프로바이더별 좌표 규약은 서버가 흡수한다: Gemini는 `box_2d [ymin,xmin,ymax,xmax]` 0–1000, Claude는 전송 이미지의 절대 픽셀 `[x1,y1,x2,y2]`.

## 3. 앱 (`app/`)

### 3.1 디렉터리

| 경로 | 내용 | 비고 |
|---|---|---|
| `lib/models/analysis.dart` | `AnalysisResult`, enum(LayoutType 15종, Technique, ObjectKind, TargetEdge, Arm…), `NBox`/`Pt` | 스키마와 1:1 |
| `lib/models/scene.dart` | `Scene3D`와 구성요소(`SceneBox`, `SceneCylinder`, `SceneClaw`, `SceneMarker`, `SceneMotion`), `Vec3`/`Pose`/`Rotation` | 필드 좌표계 mm |
| `lib/engine/` | `AimEngine`(룰 엔진), `inputs.dart`(PrizeSpec, Observation, SceneCorrections, EngineOptions), `aim_plan.dart`(AimPlan, AimStep, OverlayGeometry) | 순수 Dart, `flutter test`로 검증 |
| `lib/scene3d/` | 소프트웨어 3D 렌더러(`OrbitCamera`, `ScenePainter`, `SceneView`) | 외부 패키지 없음 |
| `lib/services/` | `SettingsStore`(SharedPreferences), `AnalyzeApi`/`MockAnalyzeApi`, `PhotoPicker`(image_picker), `HistoryStore`(문서 폴더 JSON + 사진 복사, 원자적 저장), `SessionController`(분석·보정·관찰·플랜 재계산), **`face_blur.dart`**(얼굴 모자이크, 순수 Dart) + **`mlkit_face_detector.dart`**(ML Kit 온디바이스 검출) | |
| `lib/app/` | `IWantFigureApp`, `AppScope`(설정·히스토리·서비스 주입) | |
| `lib/screens/` | `HomeScreen` → `AnalyzingScreen` → `ResultScreen`(사진/3D/설명 탭) , `SettingsScreen` | |
| `lib/widgets/` | `PhotoOverlay`(오버레이·보정 핸들·줌), `CurrentStepCard`, `ObservationBar`, `PrizeSheet`, `ExplanationTab`, `ArmBadge` | |
| `lib/l10n/strings.dart` | ko/ja/en 문자열(`S.of(context)`) | 사용자 노출 문자열은 전부 여기 |
| `assets/samples/` | 모크용 샘플 응답 | `shared/samples`의 복사본 |
| `test/` | 엔진 15, 3D 16, UI·서비스·블러·동의 60 = 91건 | `flutter test` |

### 3.2 좌표계 두 가지

1. **이미지 정규화 좌표** (`Pt`, `NBox`): 0..1, 원점 좌상단. LLM 객체 박스, 오버레이, 보정 핸들이 모두 이 좌표.
2. **필드 좌표** (`Vec3`, mm): 원점 = 필드 바닥 중앙, X = 플레이어 오른쪽(+), Y = 플레이어 쪽 手前(+) / 안쪽 奥(−), Z = 위(+). 3D 씬과 `AimStep.fieldPoint`가 이 좌표.

경품 윗면의 상대 좌표 `(u, v)`: `u` 0 = 앞 끝(手前) … 1 = 안쪽 끝(奥), `v` 0 = 왼쪽 … 1 = 오른쪽. 룰은 전부 `(u, v)`로 정의되고, `_Geometry.top(u, v)`가 이미지 좌표로, `SceneBox.pointAt(u, v, 1)`이 필드 좌표로 바꾼다.

### 3.3 룰 엔진 요약 (`AimEngine.plan`)

입력: `AnalysisResult` + `PrizeSpec`(치수·무게, 기본 150×200×100 mm/300 g) + `SceneCorrections`(사용자 보정) + `List<Observation>`(플레이 관찰) + locale.

1. **기하 추출**: 대상 경품 bbox(보정 우선) → 윗면 사각형(기본 bbox 높이의 35%), 앞·뒤 바(검출 없으면 추정 + 경고), 낙하구, 아암. 바 x 범위 = 필드 폭(기본 600 mm)으로 스케일. 바 간격은 이미지에서 "바 간격 / 윗면 높이" 비율로 추정(0.35~0.9 × 경품 깊이로 클램프). 앞/뒤 위치는 사진 한 장으로 알 수 없어 0이며 사용자가 슬라이더로 지정(`boxYOffsetMm`).
2. **아암 파워 추정**: 관찰에 `lifted` → strong, `bigMove` → medium, `noMove` 2회 이상 → weak, 아니면 LLM 값.
3. **기법 선택**: LLM 제안이 해당 유형의 허용 목록에 있으면 채택, 아니면 기본값. 橋渡し는 무게(≥350 g → 縦ハメ, 아니면 横ハメ)와 바 간격(박스 폭보다 좁으면 横ハメ 불가 → 縦ハメ) 규칙 적용.
4. **단계 생성**: 기법별 `(u, v, arm)` 규칙. 예) 縦ハメ = 오른쪽 아암 발톱을 `(1−inset, 0.5+side)`(안쪽 끝 오른쪽), 왼쪽 아암을 `(1−inset, 0.5−side)`로 교대. `inset`(기본 0.12, 약한 아암이면 0.06)과 `side`(0.22)는 `EngineOptions`에서 조정. 아암 중심 = 접점 ∓ 아암 개방폭/2.
5. **현재 단계**: 관찰 수로 교대(`played % steps.length`). 前落とし는 이동 관찰 3회 후 押し込み 단계로, 乗り上げ는 들림/큰 이동 후 突き 단계로.
6. **출력**: `AimPlan` = steps(현재 단계 포함) + overlay(사진용 기하) + scene(3D) + rationale/warnings/abortIf + finished(획득) 플래그.

룰 근거는 `01_기획_기술_분석.md` 3장의 표와 동일하며, 모두 커뮤니티 휴리스틱(원문 재확인 필요 ★)이다. 수치는 실측으로 튜닝할 것.

### 3.4 개인정보 처리 흐름

1. 최초 실행 시 동의 다이얼로그(`HomeScreen._ensureConsent`): 사진이 분석 서버와 미국 소재 AI로 전송됨, 얼굴 자동 블러, 참고용 추천임을 안내. "모의 모드로만 사용"을 고르면 모의 모드가 강제된다. 동의 전에는 촬영 버튼도 다이얼로그를 먼저 띄운다.
2. `SessionController.analyze()`의 `blur` 단계: `FaceRegionDetector`(기본 `MlKitFaceRegionDetector`, 기기 내 처리)로 얼굴을 찾고 `FaceBlurrer`가 백그라운드 isolate에서 모자이크 처리 → 이후 업로드·오버레이·히스토리 모두 블러된 사진을 사용한다. 설정의 "얼굴 자동 가리기"(기본 ON)로 제어.
3. ML Kit 플러그인 요구사항: iOS 배포 타깃 15.5(`ios/Podfile`, Xcode 프로젝트에 반영됨), Android는 Flutter 기본 minSdk로 충분. 이 환경에서는 Android SDK 호스트(dl.google.com)가 차단되어 **실기 빌드는 검증하지 못했다** — 첫 `flutter run`에서 플러그인 빌드 문제가 나면 `MlKitFaceRegionDetector` 대신 `NoopFaceRegionDetector`를 주입해 격리할 수 있다(`IWantFigureApp(faceDetector: ...)`).

### 3.5 실행

```bash
export PATH=/opt/flutter-sdk/flutter/bin:$PATH   # 또는 로컬 Flutter 3.47.x
cd app
flutter pub get
flutter analyze
flutter test
flutter run            # 기기/에뮬레이터. 기본은 모크 모드
```

설정 화면에서 모크 모드를 끄고 서버 URL을 넣으면 실제 분석을 사용한다(Android 에뮬레이터에서 호스트 PC는 `http://10.0.2.2:8080`).

## 4. 서버 (`server/`)

- ASP.NET Core minimal API, .NET 10. 엔드포인트: `GET /healthz`, `POST /api/v1/analyze`. xUnit 테스트 113건(`dotnet test`).
- 구조: `Endpoints/`(라우팅·`X-App-Key` 필터), `Imaging/ImagePipeline.cs`, `Providers/`(Mock·Gemini·Claude, 프롬프트 빌더, 스키마 변환), `Analysis/`(정규화·스키마 검증·재시도 오케스트레이션), `Configuration/Options.cs`.
- 오류 응답: `{"error": <code>, "message": <상세>}`(4xx), `{"error": "provider_error", "provider_message": <일반화 문구>}`(502), 503 `provider_not_configured`, 429 시 `Retry-After: 60`.
- 운영 옵션: `Server:AppKey`, `Server:UseForwardedHeaders` + `Server:KnownProxies`/`KnownNetworks`(프록시 뒤 IP별 레이트리밋), `Analysis:MaxImagePixels`(JPEG 50MP)/`MaxImagePixelsNonJpeg`(16MP)/`MaxConcurrentDecodes`(4), `Claude:MaxTokens`(8192)/`Effort`(low)/`Thinking`(adaptive; haiku 계열은 자동 생략).
- 프로바이더: `mock`(기본) / `gemini` / `claude`. 환경변수 예:

```bash
cd server
export Analysis__Provider=gemini
export Gemini__ApiKey=...            # 또는 Claude__ApiKey + Analysis__Provider=claude
export ASPNETCORE_URLS=http://0.0.0.0:8080
dotnet run --project IWantFigure.Server
```

- 이미지 파이프라인: EXIF 회전 보정 → 장변 1,456px로 축소 → JPEG 85. 이 크기가 LLM 비용의 최대 레버(분석 문서 8.4).
- 보안: API 키는 서버에만. 앱→서버는 `X-App-Key`(선택)로 보호. 사진은 저장하지 않는다(학습용 수집은 별도 옵트인으로 설계할 것).
- 자세한 실행·배포는 `server/README.md`.

## 3.6 화면 캡처 도구

`app/tool/screenshots_test.dart`는 실제 앱(모의 분석, 합성 기계 사진, Noop 얼굴 검출기)을 폰 크기로 렌더링해 `docs/images/*.png`를 만든다. 일반 테스트 스위트에는 포함되지 않으며 `flutter test tool/screenshots_test.dart`로 직접 실행한다. 한글·일본어 글리프를 위해 Noto Sans KR/JP 폰트 파일 경로를 `IWF_NOTO_FONT`로 줄 수 있다(없으면 시스템 기본 테스트 폰트로 렌더링됨). 오버레이·3D 라벨은 테마 폰트(`textTheme.bodySmall`)를 따르므로 실기에서는 OS 폰트로 표시된다.

## 4.1 CI

`.github/workflows/ci.yml`이 푸시/PR마다 `flutter analyze` + `flutter test`(Flutter 3.47.5)와 `dotnet build` + `dotnet test`(.NET 10)를 실행한다.

## 5. 검증 이력

- 2026-09-24: 엔진/3D, 앱 UI, 서버 각각 별도 리뷰(재현 기반)를 거쳐 결함을 수정했다. 주요 항목: 3D 회전 방향과 사용자 회전 보정 유지, 링·인형 표적의 앞뒤 반전, 퇴화 bbox의 NaN, 히스토리 파일 손상 시 전체 소실, 저장 실패 처리, 중복 분석 요청 경합, 줌 상태에서 탭 스와이프 충돌, 서버 오류 메시지 전달, 프록시 뒤 레이트리밋, 힌트 입력 상한, 비JPEG 디코드 메모리, Claude max_tokens 기본값.

## 6. 남은 일 (우선순위)

1. **실기 검증**: 실제 게임센터 사진 20~50장으로 유형 분류·객체 박스 품질을 Gemini/Claude 각각 측정하고, 룰 엔진의 `inset`/`side`/윗면 비율 기본값을 튜닝.
2. **얼굴 블러 실기 검증**: 구현은 완료(ML Kit + 순수 Dart 모자이크). 실제 기기에서 검출률·처리 시간(1,456px 기준 목표 1초 이내)을 측정하고, 실패 시 재촬영 안내 UX를 보강.
3. **3D 뷰를 Filament(thermion_flutter)로 교체 검토**: 현재 소프트웨어 렌더러는 프리미티브 10개 수준에 충분하지만 텍스처·조명 품질이 필요하면 교체.
4. **경품 DB**: 제품명 → 치수·무게. 현재는 프리셋 + 수동 입력.
5. **온디바이스 검출기(v1)**: 데이터가 쌓이면 RF-DETR Nano/YOLO26n으로 객체 박스를 앱에서 계산해 LLM 의존 축소.
6. **AR(v2)**: `arkit_plugin` + `flutter_embed_unity` 경로.
7. **스토어 준비**: `03_스토어_준비_프라이버시.md`의 초안(정책 문구·리뷰 노트)을 확정하고 정책 URL 게시, IAP 설계.
