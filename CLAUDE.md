# IWantFigure — Claude Code 프로젝트 지침

일본 게임센터 크레인게임 기계 사진을 찍으면 AI가 배치 유형을 인식하고, 앱의 룰 엔진이 조준점과 다음 수를 사진 오버레이·3D 씬으로 추천하는 iOS/Android 앱(Flutter)과 분석 서버(ASP.NET Core, .NET 10).

현재 상태와 로컬 개발 방법은 `docs/04_진행정리_로컬개발_가이드.md`를 먼저 읽을 것.

## 디렉터리 지도

| 경로 | 내용 |
|---|---|
| `app/` | Flutter 앱 (Flutter 3.47.5 / Dart 3.13.4, android·ios만) |
| `app/lib/engine/` | 조준 룰 엔진 `AimEngine`, 입력(`inputs.dart`, `EngineOptions`), 결과(`aim_plan.dart`) |
| `app/lib/models/` | `analysis.dart`(스키마와 1:1), `scene.dart`(3D 씬, 필드 좌표 mm) |
| `app/lib/scene3d/` | 외부 패키지 없는 소프트웨어 3D(투영·페인터·뷰) |
| `app/lib/screens/`, `app/lib/widgets/` | 화면, 사진 오버레이·보정 핸들·단계 카드 등 |
| `app/lib/services/` | 세션 컨트롤러, API 클라이언트, 모의 API, 얼굴 블러, 히스토리, 설정 |
| `app/lib/l10n/` | ko/ja/en 문자열(`strings.dart`), 유형 가이드 본문(`guide_content.dart`) |
| `app/test/` | 앱 테스트 (현재 116건) |
| `app/tool/screenshots_test.dart` | 스크린샷 생성 도구 → `docs/images/` 덮어씀 (폰트: `app/tool/fonts/`, gitignore) |
| `server/IWantFigure.Server/` | 분석 API (`/healthz`, `/api/v1/analyze`), 이미지 파이프라인, Mock/Gemini/Claude 프로바이더 |
| `server/IWantFigure.Server.Tests/` | xUnit (현재 113건, 네트워크 불필요) |
| `shared/` | 앱·서버 공용 계약: `analysis.schema.json`, `prompt/system_prompt.md`, `samples/` |
| `docs/` | 01 기획, 02 구현 가이드, 03 스토어·프라이버시, 04 진행 정리·로컬 가이드, `research/`, `images/` |
| `.github/workflows/ci.yml` | 모든 브랜치 push·PR에서 Flutter analyze+test, .NET build+test |

## 빌드·테스트 명령

앱 (`app/` 폴더에서):

```
flutter pub get
flutter analyze
flutter test
flutter run
```

서버 (`server/` 폴더에서):

```
dotnet build -c Release
dotnet test -c Release --no-build
dotnet run --project IWantFigure.Server
```

- 서버 기본 주소는 `http://localhost:8080`, 기본 프로바이더는 `mock`. 실기 LAN 연결은 `-- --urls http://0.0.0.0:8080`.
- API 키는 `dotnet user-secrets set "Gemini:ApiKey" "<키>" --project IWantFigure.Server`. user-secrets는 Development(기본 launch profile)에서만 로드된다.
- 앱은 기본이 모의 모드. 에뮬레이터에서 호스트 PC 서버는 `http://10.0.2.2:8080`.

## 작업 규칙 (반드시 지킬 것)

1. **응답과 문서는 한국어.** 제품명·명령어·일본어 용어(橋渡し, 縦ハメ 등)는 원어 그대로.
2. **항상 `develop` 브랜치에서 작업.** 다른 브랜치로 바꾸거나 새 브랜치를 만들 때는 사용자에게 먼저 물어볼 것.
3. **커밋은 사용자 본인 명의.** 커밋 메시지·PR 설명에 `Co-Authored-By: Claude` 등 Claude 표기를 넣지 않는다. 커밋·push는 사용자가 요청할 때만.
4. **git 명령은 `cd`와 분리.** `cd <폴더> && git ...`처럼 한 줄로 잇지 말고, 먼저 `cd`로 이동한 뒤 별도 명령으로 `git`을 실행한다.
5. **커밋 전 검증 필수**: `app`에서 `flutter analyze`(이슈 0)와 `flutter test`, `server`에서 `dotnet test`가 모두 통과해야 한다. 서버는 경고=오류(TreatWarningsAsErrors).
6. **`shared/`가 단일 계약.** 스키마·프롬프트·샘플을 바꾸면 `app/assets/samples/`의 복사본을 같은 내용으로 맞추고, `app/lib/models/analysis.dart`와 서버 테스트(정규화·스키마 변환)가 통과하는지 확인한다.
7. **사용자에게 보이는 문자열은 `app/lib/l10n/`에만** 둔다(ko/ja/en 세 언어 모두 추가). 위젯 코드에 문자열을 하드코딩하지 않는다.
8. **획득을 보장하는 표현 금지.** "반드시 잡힌다", "100%" 같은 문구를 앱 문자열·가이드·프롬프트에 쓰지 않는다. 추천은 참고용이다.
9. **API 키는 서버에만.** 앱 코드·저장소·로그에 키를 넣지 않는다. 비밀은 user-secrets나 환경변수로.
10. 개인정보: 사진은 업로드 전 기기 안에서 얼굴 블러. 서버는 이미지를 저장·로깅하지 않는다. 이 흐름을 약하게 만드는 변경은 사용자와 먼저 상의.
11. 확인하지 못한 내용은 추측으로 단정하지 말고 "(확인 필요)"로 표시한다.

## 핵심 설계 원칙

- **좌표는 LLM이 아니라 룰 엔진이 계산한다.** LLM(서버)은 배치 유형·객체 박스·기법·설명만 JSON으로 돌려주고, 조준점·아암 위치·다음 수는 `app/lib/engine/aim_engine.dart`가 경품 치수·사용자 보정·플레이 관찰·집게 회전으로 계산한다.
- 룰 엔진은 앱 안에 있어 보정·관찰에 즉시 반응한다(서버 왕복 없음).
- **좌표계는 두 가지**(`docs/02` 3.2절):
  - 이미지 정규화 좌표 `Pt`/`NBox`: 0..1, 원점 좌상단. LLM 박스·오버레이·보정 핸들.
  - 필드 좌표 `Vec3`(mm): 원점 필드 바닥 중앙, X 오른쪽(+), Y 手前(+)/奥(−), Z 위(+). 3D 씬과 `AimStep.fieldPoint`.
  - 경품 윗면 상대 좌표 `(u, v)`: u 0=手前…1=奥, v 0=왼쪽…1=오른쪽. 룰은 `(u, v)`로 정의한다.
- 3D는 파라메트릭 씬이며 외부 3D·상태관리 패키지를 쓰지 않는다.
- 모의 모드가 기본이라 서버·키 없이 전체 흐름이 돈다. 이 기본값을 깨지 않는다.
- 엔진 수치(`EngineOptions`)는 커뮤니티 휴리스틱(★)이며 실사진 튜닝 대상이다. 바꾸면 엔진 테스트를 함께 갱신한다.

## 알려진 주의점

- Android·iOS 실기/에뮬레이터 빌드는 아직 검증되지 않았다. ML Kit 문제 격리는 `IWantFigureApp(faceDetector: const NoopFaceRegionDetector())`.
- Android 빌드에는 NDK 28.2.13676358과 CMake(3.10+)가 필요하다(`jni` 플러그인).
- 설정 화면의 서버 URL 입력란은 모의 모드를 꺼야 활성화된다.
- 스크린샷 도구는 `docs/images/`를 덮어쓴다. 의도하지 않은 PNG 변경은 커밋하지 않는다.

## 주요 문서

- `docs/04_진행정리_로컬개발_가이드.md` — 진행 정리, 로컬 환경 설정, 자주 나는 오류, 다음 할 일
- `docs/02_MVP_구현_가이드.md` — 코드 구조, 좌표계, 룰 엔진, 개인정보 흐름, 검증 이력
- `docs/01_기획_기술_분석.md` — 배치 유형 15종, 기법, 기술 선택, 로드맵
- `docs/03_스토어_준비_프라이버시.md` — 프라이버시 정책 초안, 출시 체크리스트
- `server/README.md` — 서버 설정 키, API, curl, Docker
