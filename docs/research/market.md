# 조사 key: market — 시장, 선행 사례, 제약(정책/법률), 수익화
- 조사일: 2026-09-24
- 한 줄 요약: **"사진 → AI 해석 → 3D 퍼스 가이드로 조준점 표시" 라는 이 앱의 핵심 컨셉은 이미 2026년 3월 일본에서 「AIクレーンゲーム軍師 (AIClawCoach)」 가 iOS/Android 양쪽에 출시(500엔/10회 소모형 티켓)되어 "세계 최초"를 표방하고 있고, 한국에도 「뽑기AI」(Android) 가 있다. 따라서 차별화(정확도·3D 재구성·기종 DB·한국어 UX·커뮤니티)와 규제/촬영 정책(景品 1,000엔 상한, 매장 촬영 규정) 대응이 기획의 핵심이다.**

## 0. 조사 방법과 한계(반드시 읽을 것)
- WebSearch 로 일본어/영어/한국어 검색을 수행(총 30회 이상 시도; 세션 검색 한도 200회 소진 시점 이후 추가 검색 불가).
- **WebFetch 는 세션의 egress 정책상 `github.com`, `developer.apple.com`, `developer.android.com` 만 허용**되었고, App Store / Google Play / JAIA / 위키백과 / 일본 언론·법률 사이트 / 한국 언론은 모두 차단(403)되었다. 따라서 아래 수치·설명 중 상당수는 **검색 엔진이 반환한 스니펫(페이지 요약)** 에 근거한다. 각 항목에 신뢰도를 표기했다. ★ = 스니펫 근거(원문 미확인), ◎ = 원문 직접 확인.
- 날짜 민감 정보(앱 가격, 정책)는 2026-09-24 검색 기준이며 출시 전 반드시 스토어 페이지에서 재확인할 것.

---

## 1. 기존 앱 / 서비스 / 프로젝트 목록 (필수 표)

### 1-1. "사진/카메라로 세팅을 인식해 조준을 추천" — 직접 경쟁 (가장 중요)
| 이름 | 플랫폼 | 기능 | 가격 | URL | 신뢰도 |
|---|---|---|---|---|---|
| **AIクレーンゲーム軍師 (AIClawCoach)** / 開発: Technogenesis (패키지 `com.technogenesis.aiclawcoach`, iOS id6760863324) | iOS, Android | 크레인게임 盤面(판) 사진을 찍으면 AI "軍師"가 경품의 무게중심·아암이 노려야 할 최적 위치를 해석. **"3Dパースガイド"** 로 옆/비스듬한 시점에서도 정확한 狙い所 표시, 台 형상별 전략 제안. 실기(全国のゲーセン)와 온라인 크레인 모두 지원. 3단계 UX: 촬영 → AI 즉시 해석 → 최단 루트 지시. "100% 획득 보장 아님" 고지. "モバイル向けクレーンゲーム画像解析攻略アプリとして世界初(自社調べ, 2026年3月)" | 무료 설치 + 소모형 **「秘伝の知恵チケット」 500엔/10회** | https://play.google.com/store/apps/details?id=com.technogenesis.aiclawcoach&hl=ja / https://apps.apple.com/jp/app/id6760863324 | ★ (스토어 설명 스니펫 2건 교차 확인) |
| **뽑기AI** (`com.dollsai.app`) | Android(Google Play) | 카메라로 인형의 위치·크기, 집게의 위치·크기를 AI 분석 → "뽑기에 가장 좋은 인형"을 탐색·추천 (조준점보다 '어떤 인형을 고를지' 추천에 가까움) | 불명(스니펫에 가격 정보 없음) | https://play.google.com/store/apps/details?id=com.dollsai.app&hl=ko | ★ |
| **GPTs 「ゲーセンのUFOキャッチャーで景品をゲットするアドバイスをしてくれるGPT」** (본郷喜千, note.com) | ChatGPT(GPTs) | 사진 업로드 → ChatGPT 가 텍스트로 조언. 앱이 아닌 LLM 프롬프트. "사진 → LLM 조언" 접근의 선례이자, 정밀 좌표/3D 를 못 준다는 한계의 예시 | ChatGPT 요금 | https://note.com/yoshiyuki_hongoh/n/nbf402740608b | ★ |
| **アシストキャッチャー** (日本工学院 학생 프로젝트, アミューズメントエキスポ2025 초공개, 2025-11-06 발표) | 기계(앱 아님) | 카메라·마이크·스피커·모터제어를 일체화한 "AI 店員" — 손님 표정/상황을 읽고 말 걸고 보조하며 **경품을 재배치**. "AI × おもてなし" | – | https://www.neec.ac.jp/news/202511/2025-11-06-63203.html | ★ |

> 시사점: "사진 한 장 → 조준점" 자체는 더 이상 신규성이 없다. 승부처는 (1) 정확도(경품 박스 6-DoF, 바/아암 위치 인식), (2) 3D 재구성의 실제 유용성(단순 퍼스 가이드 vs. 실측 스케일), (3) 기종/설정 DB·커뮤니티, (4) 한국어/다국어 인바운드 UX, (5) 가격(500엔/10회 대비).

### 1-2. 크레인게임 시뮬레이터 (UX/물리 참고, UGC 선례)
| 이름 | 플랫폼 | 기능 | 가격 | URL | 신뢰도 |
|---|---|---|---|---|---|
| クレーンゲームシミュレーターEX | iOS (id6667101436) | 3D 크레인게임 시뮬. **"プレイヤーが公開した設定を遊んだり"** — 유저가 세팅을 만들어 공개(UGC), 온크레 공략 모색 용도 | 무료(IAP 불명) | https://apps.apple.com/us/app/id6667101436 | ★ |
| クレーンゲームシミュレーターDX (TeamFrontier) | Android (`com.TeamFrontier.CGSDX`) | 위와 동일 계열 | 무료(IAP 불명) | https://play.google.com/store/apps/details?id=com.TeamFrontier.CGSDX | ★ |
| アプリブ「クレーンゲームアプリおすすめ8選」(2026) | 웹 | 온크레·시뮬 앱 8종 정리(내용 미열람) | – | https://app-liv.jp/games/casual/3263/ | ★ |

### 1-3. 온라인 크레인게임(オンクレ) 사업자 — 제휴/경쟁/데이터 후보
| 서비스 | 운영 | 플랫폼 | 비고 | URL | 신뢰도 |
|---|---|---|---|---|---|
| トレバ (Toreba) | CyberStep(サイバーステップ) | iOS/Android/PC | **누적 2,300만 DL 초과**(스토어 설명), 실기 원격 조작·경품 무료 배송 | https://apps.apple.com/jp/app/id634329875 | ★ |
| ネッチ (Netch) | – | 앱/웹 | "日本最大級のネットキャッチャー" 표방 | (검색 스니펫) | ★ |
| クラウドキャッチャー | – | 앱/웹 | 운영 5년, 24시간 서포트, コンティニューゲージ 등 | https://cloud-catcher.jp/ | ★ |
| タイトーオンラインクレーン(タイクレ) | TAITO | iOS/Android (`jp.co.taito.onlinecrane`) | 대기업 직영 온크레 | https://www.taito.co.jp/mob/0000001895 | ★ |
| 기타: LIFTる, カプとれ(Capcom), セガキャッチャーオンライン 등 | – | – | 게임에이트 2026-09 랭킹·キュリオス.INFO "全23社比較" 에 정리 | https://game8.jp/app-review/646831 / https://curiousvv.jp/post-800/ | ★ |
| 한국: 클로머신마스터(일본 정품 인형뽑기 원격), ClawCrazy(SNS 7.5억 뷰 표방), 뽑기몬스터(집게 레이저 포인트로 위치 표시) | iOS/Android | 한국어 온크레. **뽑기몬스터의 "레이저 포인트로 현재 집게 위치 표시"** 는 조준 UX 참고 | https://apps.apple.com/kr/app/id1364387056 / https://www.taptap.io/app/91048 | ★ |

### 1-4. 게임센터 체인 공식 앱
| 앱 | 운영 | 기능 | URL | 신뢰도 |
|---|---|---|---|---|
| GiGO アプリ (`com.sega.platon`, iOS id1438200353) | GENDA GiGO Entertainment | 스마트폰 결제·サービスチケット(월 무료 티켓)·매장 체크인(Bluetooth)·**「スペシャルアシスト」(경품 획득 보조 기능)**·크레인/프라이즈 정보·주변 매장 검색 | https://gigoapp.gendagigo.jp/ | ★ |
| タイトー / namco | TAITO, Bandai Namco Amusement | 각사 회원앱·온크레(타이크레). 세부 미조사 | https://www.taito.co.jp/mob/0000001895 | ★ |

> 시사점: 체인 앱은 결제·쿠폰 중심이며 "조준 코칭"은 없다. 다만 GiGO 의 「スペシャルアシスト」처럼 **매장 측이 공식적으로 '획득 보조'를 제공**하는 흐름이 있어, 앱이 매장/체인과 제휴할 여지가 있다.

### 1-5. AI/CV/RL 로 클로머신을 다룬 연구·오픈소스 (GitHub 직접 검색 ◎)
GitHub 저장소 검색("claw machine", "crane game", "UFO catcher", "クレーンゲーム", "인형뽑기", "toreba", "wawaji") 결과 요약 — **실기 사진에서 조준점을 추정하는 CV/RL 오픈소스는 사실상 존재하지 않는다.** 대부분 (a) 아두이노/라즈베리파이 DIY 기계, (b) 웹/Unity 시뮬 게임, (c) 온라인 크레인 스트리밍 샘플이다.
| 저장소 | ★ | 언어/라이선스 | 내용 | 앱에 대한 의미 |
|---|---|---|---|---|
| mortspace/playcaptcha | 527 | TS / MIT | 클로머신 형태의 CAPTCHA(React) | 무관(UI 소재만) |
| czazuaga/Claw_Machine_Simulator | 53 | C# Unity / GPL-3.0 | 3D 클로머신 시뮬(WASD+Space) — 물리 세부 미기재 | Unity 로 "3D 재구성+조준 시각화" 프로토타입 시 참고. GPL 주의 |
| AgoraIO-Usecase/Wawaji | 30 | iOS/Android/Web | 원격 클로머신(娃娃機) 실시간 영상·제어 샘플(rtc-only / simple-control / solution 브랜치) | 온크레 연동 아키텍처 참고 |
| geo-tp/Pico-Claw-Machine | 27 | Python / MIT | RP Pico DIY 기계 | 무관 |
| Gojaehyeon/gatcha | 4 | JS / MIT | **MediaPipe Tasks Vision 손 추적(21 랜드마크) + Three.js + cannon-es** 로 웹캠 손동작 3D 인형뽑기 | 브라우저 온디바이스 CV + 3D 물리 조합의 소형 레퍼런스 |
| dldlsgh97/TorebaAR_Project | 0 | C# Unity + Vuforia | 2022 AR 수업 과제: 마커 인식으로 Toreba 식 AR 클로머신 | AR 마커 기반 시도의 한계(콜라이더 정밀도) 기록 |
| artemnovichkov/ClawKit | 0 | Swift / MIT | 폴더블 iPhone 용 RealityKit 클로머신 게임 | RealityKit 로 3D 씬 구성 예 |
| martian422/ClawMachine | 11 | Python | **이름만 같은 ICLR 2025 VLM 논문 코드(arXiv 2406.11327)** — 실기와 무관 | 검색 시 혼동 주의 |
| rayanramoul/RLCV-Papers | – | – | RL×CV 논문 큐레이션: **클로머신 논문 없음**. "Active object localization with DRL"(2015) 등만 존재 | 학술 선행 연구 공백 확인 |
| TsutsumiAkinosuke/Sniper | 1 | C++ / Apache-2.0 | 高専祭 穴通し型 크레인게임 제어 코드 | 무관 |
- 웹 검색에서도 "claw machine computer vision / reinforcement learning" 로 **학술 논문·유튜브 데모는 발견되지 않았다**(검색 결과는 OpenClaw-RL 등 이름만 유사한 LLM 에이전트 프로젝트로 오염). → 도메인 특화 데이터셋·모델은 직접 구축해야 함(cv.md 참조).

---

## 2. 유사 도메인 "AI 조준 코치" 앱 UX·가격 벤치마크
| 앱 | 도메인 | 추천 제시 방식 | 플랫폼 | 가격(2026-09 검색 기준) | 신뢰도 |
|---|---|---|---|---|---|
| AimBuddy: Pool & Billiards Trainer | 당구 | "ghost ball" 기법으로 조준점·각도 표시 | iOS | 유료 **US$1.99** | ★ |
| Aim Master 8 Ball Pool | 당구 | 고스트볼·**실시간 3D 프리뷰**, 조준 감도 조절 | iPad | **€9.99** | ★ |
| Billiards Aiming Assistant | 당구 | 실제 시점(플레이어 눈높이)으로 공 배치 제시 | iOS 12+ | (무료/불명) | ★ |
| Kings of Pool | 당구 | **AR 테이블 풀 3D** (게임) | iOS/Android | 무료 | ★ |
| DrillRoom | 당구 | **AR+AI 가상 코치**, 외부 하드웨어 불필요, 드릴/샷 트래커 | iPhone/iPad | (구독, 금액 미확인) | ★ |
| Putt Vision | 골프 퍼팅 | **실시간 지형 매핑 + AR 홀로그램**으로 퍼팅 라인 표시 | iOS | **US$4.99 + IAP** | ★ |
| Golf Scope | 골프 퍼팅 | AR 3D 매핑 + GPS 로 그린 오버레이, 최적 라인 | iOS | (기사 시점 미확인) | ★ |
| GolfLogix (Putt Line) | 골프 | **3D 그린 등고선 맵** — 과거 US$49.99/yr, 현재 주/월/연 프리미엄(첫 9홀 무료 체험) | iOS/Android | 프리미엄 구독 | ★ |
| Golfshot Pro | 골프 | 거리·클럽 추천 | iOS/Android | **US$39.99/yr** | ★ |
| HomeCourt | 농구 | 카메라만으로 슛 트래킹(자세·릴리즈 타임 등), 실시간 피드백. NVIDIA GPU 로 학습 | iOS (+iPad) | **무료 300샷/월, US$7.99/월 무제한** | ★ |
| PuttView X | 골프 | AR 글라스형 퍼팅 라인(고가 하드웨어) | 전용 HW | 미확인(사이트 차단) | – |

UX 공통점(앱 설계에 반영):
1. **"고스트" 오브젝트 + 라인**: 당구 앱은 목표 지점에 반투명 고스트볼·직선을 그린다 → 크레인게임에서는 "고스트 아암(내려올 위치)" + "경품 무게중심/힘점" + "낙하 예상 경로" 3요소로 번역 가능.
2. **실제 시점(1인칭) 유지**: Billiards Aiming Assistant 는 굳이 탑뷰로 바꾸지 않고 플레이어가 보는 각도로 표시. 게임센터에서 정면/측면 유리 너머로 보는 실제 시점에 오버레이하는 것이 자연스럽다(AIClawCoach 의 "3Dパースガイド" 도 같은 발상).
3. **가격대**: 1회성 US$2~10, 구독 US$4~8/월, 연 US$40~50. 소모형 티켓(AIClawCoach 500엔/10회 ≈ 1회 50엔 = 1플레이 100~200엔의 25~50%)도 이 도메인에서는 자연스러운 모델.
4. **무료 티어 + 상한**(HomeCourt 300샷/월) 은 "카메라 앱은 써 봐야 가치를 안다"는 특성상 가장 널리 쓰임.

---

## 3. 시장 규모
### 3-1. 일본 아뮤즈먼트/프라이즈 시장 (JAIA 「アミューズメント産業界の実態調査」)
- **2023年度(제32회, 2025년 발간)**: 시장 전체 **7,200억엔**, AM 기기 제품 판매 **1,816억엔**(+5.0%), 오퍼레이션(매장) 매출 **5,384억엔**(+4.7%). 프라이즈 게임·캐시리스 도입이 가족·젊은층 유입에 기여했다고 평가. ★ (JAIA 페이지 스니펫; 원문 PDF 차단)
- **2024年度 보고서**: 오퍼레이션이 코로나 이전을 명확히 상회, 제품 판매는 "버블기 수준에 근접". **매장 매출의 약 60% 이상이 프라이즈(크레인) 게임**, 2024년 신규 출점 다수가 프라이즈 중심. ★ (Fujisan 잡지 목차·JAIA 스니펫)
- 참고: 2012年度(JAMMA 시절) 시장 6,491억엔 — 10년 넘게 6,000~7,000억엔대 정체 후 프라이즈 주도로 재성장 국면. ★
- 설치 대수·플레이어 연령 분포는 검색 한도 소진으로 미확인(→ open question). JAIA 보고서(회원/구매) 또는 月刊アミューズメント・ジャーナル 2025년 2월호(http://www.am-j.co.jp/amusement_journal/amj202502.html)에서 확인 필요.
- 산업 구조: 2022-03-01 경품 상한 800→1,000엔 인상 이후 고단가 프라이즈(피규어) 확대, GENDA(GiGO)의 M&A 로 체인 집중 진행(GENDA 2024/1期 결산자료 존재, 미열람).

### 3-2. 온라인 크레인 시장
- Toreba 누적 2,300만 DL(스토어 설명 ★). 시장 규모(억엔) 수치는 검색 한도 소진으로 미확인. 위키백과 「オンラインクレーンゲーム」 항목(차단)에 사업자 연표 있음.
- 일본 사업자 20~23개사 비교 기사가 다수 존재(キュリオス.INFO "全23社徹底比較") → 제휴 후보가 많고, 각사 신규 등록 무료 플레이 캠페인이 활발(ポイ活 블로그) → **어필리에이트 수익 구조가 존재할 가능성 높음**(단가 미확인).

### 3-3. 방일 한국인 관광객 & 게임센터 관심
- **2025년 방일 한국인 945만 9,600명(+7.3%, 과거 최고)**, 방일 외국인 총 **4,268만 명(사상 첫 4,000만 돌파)**, 한국 비중 약 **22%로 최대 시장**. ★ (JATA/やまとごころ 스니펫)
- 訪日ラボ(2019-01-23): "訪日外国人がリピートしている場所" 랭킹 1위가 **게임센터**. ★
- **SEGA Fave 「Japanese Game Centers Guide」(2025-01-20 공개)**: 영어·간체·번체·**한국어**·일본어 5개 언어, "訪日外国人旅行者にも人気の高いクレーンゲームの取り方・コツ" 수록 → 업계가 인바운드 크레인 수요를 공식 인정. ★ https://sega.co.jp/release/250120_1.html
- 훈치라보/JapanTicket 등에 훈일 한국인 특성(20~30대 여성 비중, 리피터율, SNS 정보원) 데이터가 있으나 원문 차단으로 수치 미확인(open question).

### 3-4. 한국 국내 크레인게임 시장
- 청소년게임제공업소(뽑기방·오락실): **2022년 말 5,334곳 → 2025년 8월 5,957곳 → 2026년 1분기 말 6,815곳(+27.76% vs 2022)**. ★ (한국경제 2026-05 기사 스니펫)
- **인형뽑기방 매출: 2020년 460억원 → 2023년 584억원 → 2024년 1,241억원**(급증). ★
- 동인: 코로나 이후 '혼자 노는 문화', 키링·인형으로 가방 꾸미는 **'백꾸'** 유행, 저렴한 무인 창업. ★
- 규제: 게임산업진흥법상 경품 가액 상한(5,000원 기준 상향 이력)·집게 조작 불법(게임메카 기사 "안 다물어지는 집게, 불법입니다") — 원문 차단으로 조항 미확인. ★
- 시사점: 한국 시장은 일본식 피규어 橋渡し 보다 **인형(봉제) 중심**이라 인식 모델·룰베이스가 달라진다. 1차 타깃은 "일본 방문 한국인" + 일본인, 2차로 한국 뽑기방 모드 확장이 자연스럽다.

---

## 4. 제약: 법률·매장 정책·스토어 정책
### 4-1. 일본 법률 맥락 (앱 자체는 규제 대상 아님, 그러나 문구·기능 설계에 영향)
- **근거 법은 景品表示法이 아니라 風営法(風俗営業等の規制及び業務の適正化等に関する法律)**: 게임센터는 5号営業, 제23조 2항이 "遊技の結果に応じて賞品を提供" 을 원칙 금지. 警察庁 **解釈運用基準** 이 "크레인으로 집어 올린 **소매가격 おおむね 1,000円以下** 물품 제공은 23조2항의 賞品提供에 해당하지 않는 것으로 취급"한다는 **특례**로 크레인게임이 성립. 기준은 원가가 아니라 **소매가격**. ★ (弁護士JP, ツナグ行政書士 스니펫 교차)
- **2022-03-01: 상한 800엔 → 1,000엔 인상(1997년 이후 25년 만)** — 日経 2022-03-14 보도. ★
- **2026-07-08 Game*Spark**: 警察庁「遊技場営業について」성명으로 "おおむね1,000円以下" 및 고액 프라이즈 제공 금지를 재고지 → 2026년 현재 고액 피규어·가전 경품 확산에 대한 단속 강화 국면. PiDEA X 기사 "1000円以下なら何でもOK？高額景品も広がるクレーンゲームの謎" 도 같은 문제 제기. ★
- **確率機(확률기) 사기 판례**: 大阪 「アミューズメントトラスト」 사건 — 획득 불가능 설정으로 요금을 편취, 2019년 12월 첫 체포 후 38都道府県 약 300건·신고액 약 6,000만엔; 大阪 2개 점포 8명·약 123만엔 편취 인정, 경영자 **懲役3年執行猶予4年**, 전 종업원 3명 懲役1年6月執行猶予3年(弁護士ドットコム). ★
- 앱 설계 시사점: (a) "확률기 판별" 기능은 유용하지만 **특정 매장/기기를 '사기'로 단정하는 표현은 명예훼손 리스크** → "실력기/확률기 추정(참고)" 수준의 표현·면책 필요. (b) "반드시 획득" 류 표현 금지(景品表示法 優良誤認 — 이 법은 앱 광고 문구에 적용). (c) 경품 가액·확률 표시 규정은 매장 의무이지 앱 의무는 아님.

### 4-2. 게임센터 촬영·공략 앱 사용 정책 (체인별)
| 체인 | 정책 요지 | 출처 | 신뢰도 |
|---|---|---|---|
| **GiGO (GENDA GiGO Entertainment)** | 개인 촬영(정지화·동영상) **제한 없음**. 단 ① 다른 손님·스태프가 찍힌 영상의 인터넷/SNS 공개 금지, ② 대기 손님이 있으면 "1게임"을 기준으로 교대, ③ 조명·대형 기재 설치 금지, ④ 촬영물의 매스컴 판매 금지, ⑤ **YouTube 등 영리 요소 촬영은 사전 신청(ロケ撮影申込 폼)** | https://www.gendagigo.jp/contact/satsuei.html , https://www.gendagigo.jp/location_form.html | ★ |
| **TAITO (タイトーステーション)** | 촬영 희망 시 **반드시 크루에게 말할 것**; 매장 상황에 따라 **전면 금지인 매장도 있음**; SNS 게시는 직영점에서 **撮影許可申請書** 작성 후 허가 시 가능; 인플루언서 전용 문의 폼 존재 | https://support.taito.co.jp/faqarticle.php?kid=81249&id=871 , https://form.taito.co.jp/a.p/403/ | ★ |
| **イオンファンタジー(モーリーファンタジー)** | 공식 FAQ에 "店内での撮影について" 항목 존재(내용 미열람) | https://www.fantasy.co.jp/faq/ | ★ |
| 기타 | "동영상 촬영 가능/불가 게임센터는 매장마다 다름"(Kocohama 2024-05-15), 촬영 허가 메일 템플릿 블로그 존재 | https://kocohama.com/2024/05/15/arcadesyoucanrecord/ | ★ |
- **"공략 앱 사용 금지" 규정은 검색에서 발견되지 않았다.** 촬영 자체가 쟁점이며, 앱은 "1장 촬영·즉시 해석·저장 안 함(또는 로컬 저장)" 흐름으로 매장 부담을 최소화하는 것이 안전. 다른 손님 얼굴 자동 블러/서버 미전송 옵션은 GiGO 규정(타인 映り込み 공개 금지)과 정합.
- 촬영 시간이 길면 "1게임 교대" 규정과 충돌 → **해석 시간 수 초 이내**가 UX 요구사항이자 매장 규정 준수 요건.

### 4-3. 초상권/개인정보
- 일본 게임센터는 협소·혼잡하여 타인이 映り込み 하기 쉬움. GiGO 규정상 "타인이 찍힌 영상 SNS 공개 금지". 앱에서 커뮤니티 업로드(UGC)를 하려면 **사람 얼굴 자동 마스킹 + 업로드 전 확인** 이 사실상 필수. (肖像権 일반론 검색은 한도 소진으로 미수행 — open question)
- 스토어 정책: Apple 5.1.1 — 카메라 purpose string 에 용도를 명확히, 데이터 최소화; Apple 2.5.14 — 카메라/마이크 기록 시 명시적 동의와 시각적 표시; Apple 5.1.2 — **제3자 AI(클라우드 LLM/비전 API)에 개인 데이터를 전송할 경우 명시적 동의** 필요. ◎ (developer.apple.com 직접 확인, 2026-09-24)

### 4-4. App Store / Google Play 정책
- **Apple 5.3 Gaming, Gambling, and Lotteries** ◎: 실제 돈 게임(스포츠 베팅·포커·카지노·경마)·복권은 라이선스·지오펜싱·무료 배포 요건; **5.3.4 "Illegal gambling aids, including card counters, are not permitted"**. 크레인게임은 일본에서 風営法상 '賞品提供 예외'로 취급되고 도박이 아니며, 본 앱은 결제·베팅 기능이 없으므로 5.3 직접 적용 대상은 아니라고 판단됨. 다만 심사관이 "prize/賞品" 단어를 보고 5.3 으로 오해할 수 있으니 **리뷰 노트에 "아케이드 스킬 게임 코칭 앱, 실제 금전 거래 없음, 賞品 소매가 1,000엔 이하의 일본 아케이드"** 를 명시할 것.
- **Apple 4.2.1 ARKit 최소 기능** ◎: "모델을 AR 뷰에 떨어뜨리기만 하는 것"은 불충분 → 3D 표시가 단순 장식이면 리젝 사유가 될 수 있음. 실질적 가치(조준선·거리 측정)를 갖춰야 함.
- **Apple 1.2 UGC** ◎: 커뮤니티 기능 도입 시 필터링·신고·차단·연락처 4요소 필수.
- **Apple 3.1.1 IAP** ◎: 티켓/구독은 IAP 필수, 구매한 크레딧은 **만료 불가**·복원 필요(소모형 티켓 설계 시 주의).
- **Google Play "Real-Money Gambling, Games, and Contests"** ★(support.google.com 차단, 스니펫): 실제 돈으로 현실 가치 상품을 얻는 서비스 금지·라이선스/지오게이팅 요건; **2026-01-28부터 도박/컨테스트 기능 앱은 연령 스크리닝 필수**. 본 앱은 해당 없음. 카메라 권한은 일반 권한(런타임 권한만 필요). 
- **Apple 4.3(b) 스팸/카피캣** ◎: 이미 AIClawCoach 가 있으므로 "meaningfully different experience" 를 스토어 설명에서 분명히.

---

## 5. 수익화 모델과 커뮤니티/UGC 선례
| 모델 | 선례 | 적용 아이디어 |
|---|---|---|
| 소모형 티켓(횟수제) | **AIClawCoach 500엔/10회** | 해석 1회 = 티켓 1장. Apple 규정상 만료 불가·복원 필요 |
| 무료 티어 + 월 상한 + 구독 | HomeCourt 무료 300샷/월, US$7.99/월 | "월 N회 무료 해석 + 무제한 구독 ¥480~980/월" |
| 1회성 유료 | AimBuddy US$1.99, Putt Vision US$4.99 | 시장 규모 대비 LTV 낮음; 기능 잠금 해제 용도로만 |
| 광고 | 온크레·시뮬 앱 일반 | 게임센터 현장에서 광고 노출은 UX 저해. 결과 화면 배너 정도 |
| 온크레 제휴/어필리에이트 | Toreba·Netch 등 20+사 신규 등록 무료 플레이 캠페인 활발(ポイ活 블로그) | "이 경품은 온라인에서도 있음 → 연결" 딥링크. 단가는 미확인(open question) |
| 체인 제휴 | GiGO 앱 「スペシャルアシスト」, SEGA Fave 인바운드 가이드 | 인바운드 대응 파트너로 제안 가능성 |
| UGC/커뮤니티 | **クレーンゲームシミュレーターEX: 유저가 만든 세팅 공개·플레이**; 일본 X/YouTube 공략 커뮤니티 활발(domain.md 6.4 참조); 뽑기방 관련 한국 SNS('백꾸') | "세팅 사진 + 결과(성공/실패, 투입액) 업로드 → 기종/매장별 난이도 DB". 얼굴 블러·매장명 공개 정책·Apple 1.2 요건 필요 |

---

## 6. 앱 핵심 의사결정에 대한 시사점(요약)
1. **경쟁자 존재를 전제로 포지셔닝**: AIClawCoach(일본어, 500엔/10회, 2026-03) 대비 "실측 3D + 기종 DB + 한국어/영어 + 커뮤니티" 로 차별화. 한국어 시장은 뽑기AI(인형 추천) 외 비어 있음.
2. **타깃 우선순위**: 일본 방문 한국인(연 946만 명, 최대 시장) + 일본인 플레이어 → 이후 한국 뽑기방(6,800여 매장, 매출 1,241억원/2024) 모드.
3. **매장 정책 준수형 UX**: 1장 촬영·수 초 해석·타인 블러·비상업 개인 이용 강조. YouTube 식 장시간 촬영 아님을 명시.
4. **법적 표현 가이드**: "반드시 획득" 금지, 확률기 판정은 '추정' 표기, 특정 매장 비방 금지, 경품 1,000엔 상한은 사용자 교육 콘텐츠로 활용 가능(고액 경품 = 확률기/위법 가능성 경고).
5. **스토어 심사 대비**: 5.3 오해 방지 리뷰 노트, ARKit 4.2.1 실질 기능, 카메라 purpose string, 제3자 AI 전송 동의(5.1.2), IAP 티켓 만료 금지.

---

## 7. 미해결 질문(open questions)
- JAIA 2024年度 보고서의 정확한 수치(시장 총액, 프라이즈 매출액·비율, 설치 대수, 점포 수) — 원문 PDF 차단.
- 온라인 크레인 시장 규모(억엔)와 CyberStep(トレバ) 최신 결산 수치.
- 방일 한국인의 연령·성별·리피터율·게임센터 방문율 등 세부(訪日ラボ/JapanTicket 원문 차단).
- 한국 게임산업진흥법상 경품 가액 상한의 현재 값과 집게 조작 처벌 조항 원문.
- AIClawCoach 의 실제 정확도·리뷰 평점·DL 수(스토어 차단) 및 3D 퍼스 가이드가 실측 3D 인지 단순 원근 격자인지.
- 온크레 어필리에이트 단가·ASP 존재 여부.
- GiGO 외 체인(namco, ラウンドワン, エブリデイ 등)의 촬영 규정 원문.
- 일본 肖像権 판례·가이드라인(다른 손님 映り込み) 상세.

## 8. 읽은/참조한 URL 목록
### 직접 열람(◎)
- https://developer.apple.com/app-store/review/guidelines/ (5.3, 5.1.1, 5.1.2, 1.2, 3.1.1, 4.2.1, 4.3, 2.5.14)
- https://developer.android.com/distribute/play-policies (정책 일정 개요만)
- https://github.com/czazuaga/Claw_Machine_Simulator , https://github.com/AgoraIO-Usecase/Wawaji , https://github.com/Gojaehyeon/gatcha , https://github.com/dldlsgh97/TorebaAR_Project , https://github.com/artemnovichkov/ClawKit , https://github.com/martian422/ClawMachine , https://github.com/rayanramoul/RLCV-Papers , https://github.com/codetoanbug/claw-machine , https://github.com/topics/claw-machine , https://github.com/Feelconomy/ally-catcher
- GitHub 저장소 검색 API(mcp) 6회
### 검색 스니펫 근거(★, 원문 차단)
- https://play.google.com/store/apps/details?id=com.technogenesis.aiclawcoach&hl=ja
- https://apps.apple.com/jp/app/id6760863324
- https://play.google.com/store/apps/details?id=com.dollsai.app&hl=ko
- https://note.com/yoshiyuki_hongoh/n/nbf402740608b
- https://www.neec.ac.jp/news/202511/2025-11-06-63203.html
- https://apps.apple.com/us/app/id6667101436 , https://play.google.com/store/apps/details?id=com.TeamFrontier.CGSDX , https://app-liv.jp/games/casual/3263/
- https://apps.apple.com/jp/app/id634329875 (Toreba) , https://cloud-catcher.jp/ , https://www.taito.co.jp/mob/0000001895 , https://game8.jp/app-review/646831 , https://curiousvv.jp/post-800/ , https://curiousvv.jp/oncre-large-enterprise/ , https://ja.wikipedia.org/wiki/オンラインクレーンゲーム
- https://gigoapp.gendagigo.jp/ , https://apps.apple.com/jp/app/gigo-ギーゴ/id1438200353 , https://play.google.com/store/apps/details?id=com.sega.platon
- https://jaia.jp/survey/ , https://jaia.jp/press/ , https://www.fujisan.co.jp/product/1281695691/b/list/ , http://www.am-j.co.jp/amusement_journal/amj202502.html , https://www.value-press.com/pressrelease/116566
- https://www.ben54.jp/news/2888 , https://www.nikkei.com/article/DGXZQOUC147C90U2A310C2000000/ , https://www.gamespark.jp/article/2026/07/08/169007.html , https://tsunagu-office.net/archives/11282 , https://tsunagu-office.net/archives/10245 , https://www.pidea.jp/articles/1787906127 , https://www.bengo4.com/c_8/n_8067/ , https://prize-lab.com/trivia/kakuritsu/ , https://omoson.com/note/oosaka/
- https://www.gendagigo.jp/contact/satsuei.html , https://www.gendagigo.jp/location_form.html , https://support.taito.co.jp/faqarticle.php?kid=81249&id=871 , https://form.taito.co.jp/a.p/403/ , https://www.fantasy.co.jp/faq/ , https://kocohama.com/2024/05/15/arcadesyoucanrecord/
- https://www.jata-net.or.jp/databank/jata-trend/page-66593/2025_12/ , https://yamatogokoro.jp/inbound_data/59369/ , https://honichi.com/visitors/asia/korea/data/ , https://honichi.com/news/2019/01/23/inboundxvideoarcade/ , https://sega.co.jp/release/250120_1.html
- https://www.hankyung.com/article/2026050453741 , https://www.dhdaily.co.kr/news/articleView.html?idxno=25972 , https://www.gamemeca.com/view.php?gid=1770544 , https://ko.wikipedia.org/wiki/대한민국의_인형뽑기_산업
- 당구/골프/농구: https://apps.apple.com/us/app/billiards-aiming-assistant/id1626264164 , https://aimbuddy-pool-and-billiards-trainer.appstor.io/ , https://apps.apple.com/es/app/id6744432763 , https://drillroom.ai/ , https://apps.apple.com/us/app/kings-of-pool/id1049420215 , https://apps.apple.com/us/app/putt-vision/id1465601144 , https://mygolfspy.com/golf-scope-launches-green-reading-putting-app/ , https://www.golflogix.com/ , https://linksmagazine.com/golf-apps-which-ones-should-you-have/ , https://apps.apple.com/us/app/homecourt-basketball-training/id1258520424 , https://developer.nvidia.com/blog/this-ai-app-can-help-you-improve-your-jump-shot/
- 스토어 정책: https://support.google.com/googleplay/android-developer/answer/9877032 , https://igamingexpert.com/news/business/google-sweepstake-policies-2025/
