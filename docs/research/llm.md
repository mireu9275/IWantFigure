# 조사 key: llm — 멀티모달 LLM을 "두뇌"로 쓰는 접근

- 조사일: 2026-09-24
- 한 줄 요약: 2026년 9월 현재 Claude(공식 문서 확인)·Gemini·GPT·오픈웨이트 VLM 모두 사진→JSON(배치 유형·조준점)을 낼 수 있지만, **정밀 위치 지정은 최상위 모델도 사람 대비 70~75% 수준(Point-Bench 인간 89.1 vs 최고 모델 ~70)** 이므로 "CV 검출기(기하) + LLM(전략·설명)" 하이브리드가 정답이고, 비용은 이미지 1장당 $0.004~$0.04, 월 10만 회 기준 $400~$3,800(모델별)이다.

> 조사 환경 메모: 이 세션은 WebSearch 예산이 소진된 상태였고, 네트워크 egress 정책으로 `ai.google.dev`, `openai.com`, `platform.openai.com`, `developers.openai.com`, `arxiv.org`, `huggingface.co`, `ppc.go.jp`, `e-gov.go.jp`, `wikipedia.org`, `learn.microsoft.com`, `deepmind.google` 등이 차단되어 있었다. 따라서 **Claude 관련 수치는 Anthropic 공식 문서(platform.claude.com)에서 직접 확인**했고, Gemini/OpenAI 가격은 **LiteLLM의 공개 가격 DB(raw.githubusercontent.com/BerriAI/litellm, 2026-09-24 fetch)** 및 Google 공식 cookbook(GitHub) 을 근거로 했다. 각 항목에 (공식) / (2차 소스) / (사전지식·미검증) 을 표기했다.

---

## 1. 2026-09 기준 비전 지원 모델 비교표

### 1-1. Claude (Anthropic 공식 문서, 2026-09-24 확인)

| 모델 (API ID) | 입력/출력 $/MTok | 캐시 읽기 $/MTok | 컨텍스트/최대출력 | 비전 해상도 티어 | 구조화 출력 | 좌표 출력 | 비고 |
|---|---|---|---|---|---|---|---|
| Claude Fable 5.1 (`claude-fable-5-1`) | $10 / $50 | $0.25 (0.025x) | 1M / 128K | 고해상도(장변 2576px, 최대 4784 비주얼 토큰) | GA (`output_config.format` json_schema, strict tools) | 절대 픽셀 좌표 | thinking 항상 on, 안전 분류기 refusal 가능, **30일 데이터 보존 필수(ZDR 불가)**, 강제 tool_choice 불가 |
| Claude Opus 5.5 (`claude-opus-5-5`) | $4 / $20 | $0.20 (0.05x) | 1M / 128K | 고해상도 | GA | 절대 픽셀 좌표 | 기본 effort `medium`, thinking 비활성 불가, 문서 권장 기본 모델 |
| Claude Opus 5 (`claude-opus-5`) | $5 / $25 | $0.50 | 1M / 128K | 고해상도 | GA | 절대 픽셀 좌표 | 캐시 최소 512토큰, "비전은 thinking보다 crop 툴이 효율적" |
| Claude Sonnet 5 (`claude-sonnet-5`) | $2 / $10 | $0.20 | 1M / 128K | 고해상도 | GA | 절대 픽셀 좌표 | 2026-09-01 인상 예정이던 $3/$15 인상 취소, $2/$10 정가 확정. 캐시 최소 1024토큰 |
| Claude Haiku 4.5 (`claude-haiku-4-5`) | $1 / $5 | $0.10 | 200K / 64K | 표준(장변 1568px, 최대 1568 토큰) | GA | 픽셀 좌표(근사) | effort 미지원, `budget_tokens` 방식 thinking, 캐시 최소 4096토큰 |

- 근거: https://platform.claude.com/docs/en/about-claude/pricing , https://platform.claude.com/docs/en/models/overview , https://platform.claude.com/docs/en/build-with-claude/vision , https://platform.claude.com/docs/en/build-with-claude/vision-coordinates , https://platform.claude.com/docs/en/build-with-claude/structured-outputs
- 이미지 토큰 계산(공식): `⌈width/28⌉ × ⌈height/28⌉` 비주얼 토큰. 표준 티어는 장변 1568px & 1568토큰 상한, 고해상도 티어(Claude 4.7 이후 모델)는 장변 2576px & 4784토큰 상한. 예: 1920×1080 → 표준 1456×819(1560토큰), 고해상도 원본 유지(2691토큰). 4K(3840×2160) → 고해상도 2576×1449(4784토큰). 1000×1000 = 1296토큰. Haiku 4.5 기준 1000×1000 이미지 1,000장 ≈ $1.30, Opus 5 기준 ≈ $6.48.
- 요청당 이미지 상한 600장(200K 모델은 100장), 이미지당 10MB(base64), 8000×8000px 상한. JPEG/PNG/GIF/WebP.
- 배치 API 50% 할인(실시간 앱에는 부적합), 프롬프트 캐시 5분 write 1.25x, 1시간 write 2x, read 0.1x(Fable 5.1 0.025x, Opus 5.5 0.05x).
- **Claude 좌표 출력 규칙(공식, 매우 중요)**: "Claude works best with absolute pixel coordinates. Ask for them explicitly… Claude does not work well when you ask for normalized coordinates (0–1000)". 좌표는 **리사이즈 후 Claude가 보는 이미지 기준**의 픽셀이며, 원점(0,0)은 좌상단. 권장: 클라이언트에서 미리 모델이 보는 크기로 리사이즈(문서에 Python/TS/C#/Java 등 `resized_size()` 참조 구현 제공) 하거나, 반환 좌표를 재스케일. `"transformations": {"oversized_image": "error"}` 를 걸면 서버 리사이즈가 일어날 때 400 오류로 알려준다. 작은 대상은 crop 해서 다시 보내고 오프셋을 더하라고 명시. 한계: "Claude's coordinate and localization outputs are approximate… verify outputs before relying on them", 카운팅도 근사.
- 구조화 출력(공식): `output_config.format = {type: "json_schema", …}` GA, 모든 현행 모델 지원, 24시간 문법 캐시. 지원 안 되는 스키마 기능: 재귀 스키마, `minimum/maximum`, `minLength/maxLength`, `minItems`(0/1만). → 좌표 범위 제약은 스키마가 아니라 후처리로 검증해야 함.
- 데이터 보존(공식, https://platform.claude.com/docs/en/manage-claude/api-and-data-retention): "Conversation content is not retained by default; the exception is Covered Models (Fable 5/5.1, Mythos 5/5.1), which require 30-day retention." "Retained data is never used for model training without your express permission." ZDR은 조직 단위로 영업팀 통해 활성화. 자동 T&S 플래그 시 최대 2년 보존. Files API·Batch·code execution은 ZDR 비대상. ZDR 조직은 CORS 미지원 → 백엔드 프록시 필수. 이미지 FAQ: "Image uploads are ephemeral and not stored beyond the duration of the API request… Anthropic does not use uploaded images to train models."

### 1-2. Gemini (2차 소스: LiteLLM 가격 DB 2026-09-24 + Google 공식 cookbook GitHub)

| 모델 ID | 입력/출력 $/MTok | 캐시 읽기 | 컨텍스트/출력 | 좌표 출력 | 구조화 출력 | 비고 |
|---|---|---|---|---|---|---|
| `gemini-3.8-flash` | $0.75 / $3.75 (배치 $0.375/$1.875) | $0.075 | 1,048,576 / 65,536 | `box_2d`(0–1000 정규화), point | `response_json_schema` | cookbook 기본 모델. Counting_Tokens 노트북 실측: 이미지 1장 ≈ 1,081토큰 |
| `gemini-3.7-flash` / `3.6-flash` | $0.75 / $3.75 | $0.075 | 1M / 64K | 동일 | 동일 | 이전 세대 flash |
| `gemini-3.5-flash` | $1.50 / $9.00 | $0.15 | 1M / 64K | 동일 | 동일 | Robotics-ER 2의 기반 모델 |
| `gemini-3.5-flash-lite` | $0.30 / $2.50 | $0.03 | 1M / 64K | 동일 | 동일 | 최저가 급 |
| `gemini-3.1-pro-preview` | $2 / $12 (>200K: $4/$18) | $0.20 | 1M / 64K | 동일 | 동일 | Pro 급 |
| `gemini-3.1-flash-lite` | $0.25 / $1.50 | $0.025 | 1M / 64K | 동일 | 동일 | deprecation 2027-05-07 |
| `gemini-robotics-er-2-preview` | $1 / $5 | $0.10 | 131,072 / 65,536 | point `[y,x]`, `box_2d`, 궤적, 비디오 | 지원 | Gemini 3.5 Flash 기반 embodied reasoning 모델, 스트리밍 변형도 있음 |
| `gemini-2.5-flash` / `2.5-pro` | $0.30/$2.50, $1.25/$10 | $0.03/$0.125 | 1M | 동일 | 동일 | 구세대 |

- 근거: LiteLLM `model_prices_and_context_window.json`(각 항목의 `source`가 https://ai.google.dev/gemini-api/docs/pricing 를 가리킴), https://raw.githubusercontent.com/google-gemini/cookbook/main/quickstarts/Spatial_understanding.ipynb , https://raw.githubusercontent.com/google-gemini/cookbook/main/quickstarts/Counting_Tokens.ipynb , https://raw.githubusercontent.com/google-gemini/cookbook/main/quickstarts/Models.ipynb , https://raw.githubusercontent.com/google-gemini/robotics-samples/main/Getting%20Started/gemini_robotics_er.ipynb
- Gemini 좌표 규칙(공식 cookbook): 바운딩박스 `{"box_2d": [ymin, xmin, ymax, xmax], "label": "..."}` **0–1000 정규화**, 포인트 `{"point": [y, x], "label": "..."}` 0–1000 (y가 먼저!). Spatial_understanding 노트북 권장 설정: temperature 0.5, **thinking 비활성(지연만 늘고 검출 품질 향상 없음)**, 시스템 프롬프트로 객체 25개 상한, "Never return masks or code fencing". Robotics-ER 2 노트북은 토큰 절약을 위해 이미지를 장변 800px로 리사이즈해 전송.
- 이미지 토큰(2차 소스·미검증): 여러 커뮤니티 구현체(big-AGI, fenic, OmniGlyph)가 Google 문서를 인용해 Gemini 3 계열 `media_resolution` 당 이미지 토큰을 low 280 / medium 560 / high 1120 (ultra_high 2240, per-part 전용) 로, Gemini 2.5는 low 64 / medium 256 으로 기록. python-genai SDK 소스에는 `PartMediaResolutionLevel` = LOW/MEDIUM/HIGH/ULTRA_HIGH 열거형 존재 확인. 공식 확인은 https://ai.google.dev/gemini-api/docs/tokens 에서 해야 함(이 세션에서 차단).
- 데이터 보존(사전지식·미검증): 유료 티어 Gemini API/Vertex AI는 프롬프트를 모델 학습에 사용하지 않음, Vertex AI는 abuse logging 옵트아웃(ZDR 상당) 가능. 무료 티어는 학습 사용 가능. 반드시 https://ai.google.dev/gemini-api/terms 및 Vertex AI data-governance 문서에서 재확인 필요.

### 1-3. OpenAI GPT (2차 소스: LiteLLM 가격 DB 2026-09-24, `source`=developers.openai.com/api/docs/pricing)

| 모델 | 입력/출력 $/MTok | 캐시 읽기 | 컨텍스트 | 비고 |
|---|---|---|---|---|
| `gpt-6-astra` | $10 / $50 | — | 922K | 최상위(openai-openapi 스펙 예시에 213회 등장) |
| `gpt-6-sol` | $2 / $10 | — | 922K | 중간 |
| `gpt-6-luna` | $0.10 / $0.50 | — | 922K | 초저가 |
| `gpt-5.6` | $4 / $20 | $0.40 | 922K / 128K | |
| `gpt-5.5` | $5 / $30 | $0.50 | 1.05M / 128K | openai-python README 기본 예시 모델 |
| `gpt-5.4` / `5.4-mini` / `5.4-nano` | $2.5/$15, $0.75/$4.5, $0.20/$1.25 | $0.25 / $0.075 / $0.02 | 1.05M / 272K / 272K | |
| `gpt-5.6-terra` / `5.6-luna` | $2/$12, $0.20/$1.20 | $0.20 / $0.02 | 922K | |

- 모두 `supports_vision: true`, `supports_response_schema: true`(Structured Outputs). 이미지 입력은 Responses API `input_image` + `detail: auto|low|high` (openai-openapi 스펙 확인). 이미지 토큰 공식(2차 소스·LiteLLM 구현체가 OpenAI 공식 공식 반영): low = 85토큰 고정, high = 85 + 170 × (짧은 변 768px로 축소 후 512px 타일 수). 예: 1024×768 → 4타일 → 765토큰. mini/nano 계열은 32px 패치 기반 × 배율 방식이었으나 5.4/5.6 세대 공식은 이 세션에서 확인 불가.
- OpenAI는 Gemini/Claude와 달리 **바운딩박스 전용 출력 포맷이 문서화되어 있지 않음**(프롬프트로 좌표 요청은 가능). PointArena 논문(2025)에서 GPT-4o/4.1은 일부 카테고리에서 인간 근접, CoT를 붙이면 pointing 정확도가 오히려 하락.
- 데이터 보존(사전지식·미검증): API 입출력은 남용 감시 목적 최대 30일 보존 후 삭제, 기본적으로 학습 미사용, ZDR은 자격 요건 충족 시 신청. 공식 페이지(openai.com/enterprise-privacy)에서 재확인 필요.

### 1-4. 오픈웨이트 VLM

| 모델 | 라이선스 | 크기 | 좌표/grounding | 근거 |
|---|---|---|---|---|
| Qwen3-VL (2025-10~11) | Apache-2.0 | 2B/4B/8B/32B(dense), 235B-A22B(MoE), Instruct/Thinking | 2D grounding(박스+포인트), 3D 박스. **cookbook: 기본 좌표계가 Qwen2.5-VL의 절대좌표에서 0–1000 상대좌표로 변경**, 출력 `{"bbox_2d":[x1,y1,x2,y2],"label":…}`, `{"point_2d":[x,y],…}` | https://github.com/QwenLM/Qwen3-VL , https://raw.githubusercontent.com/QwenLM/Qwen3-VL/main/cookbooks/2d_grounding.ipynb |
| Molmo / Molmo2 / MolmoPoint-8B (AI2, 2024-09 ~ 2026-03) | Apache-2.0 | 1B~72B; Molmo2 4B/8B; MolmoPoint-8B | pointing 특화(PixMo-Points), Point-Bench 최고 성능(아래 §3) | https://github.com/allenai/molmo , MolmoPoint 논문 arXiv 2603.28069(미러) |
| Llama 4 (Scout/Maverick, 멀티모달) | Llama 4 Community License: "Built with Llama" 표기, 파생 모델명에 Llama 접두, **월간 활성 사용자 7억 초과 시 별도 라이선스** | — | grounding 전용 포맷 없음 | https://github.com/meta-llama/llama-models/blob/main/models/llama4/LICENSE |
| Gemma 3n (E2B/E4B) | Gemma Terms of Use(사전지식·미검증, 상업 이용 가능하나 이용정책 제한) | AI Edge Gallery 배포판: E2B int4 2.92GB, E4B int4 4.10GB, 이미지 입력 지원, 컨텍스트 4096, CPU/GPU | grounding 학습 없음(설명 위주) | https://raw.githubusercontent.com/google-ai-edge/gallery/main/model_allowlist.json |
| Gemma 4 (2026) | 동일 계열 | LiteRT-LM에서 Gemma 4 12B 등 지원, Android/iOS/macOS, 비전·오디오 입력 지원 | 미확인 | https://github.com/google-ai-edge/LiteRT-LM , https://github.com/google-ai-edge/gallery |

### 1-5. 온디바이스

- **Android ML Kit GenAI (Gemini Nano, AICore)** — https://developer.android.com/ai/gemini-nano : Prompt API(텍스트/멀티모달), Summarization, Proofreading, Rewriting, Image Description, Speech Recognition. 입력 데이터를 AICore가 저장하지 않음, 네트워크 불필요. 지원 기기 목록·GA 상태는 developers.google.com/ml-kit/genai(차단)에서 확인 필요. 좌표 출력 능력은 문서화되어 있지 않음 → "기계/경품 여부·대략적 유형" 사전 분류용으로만 적합.
- **Apple Foundation Models** — https://developer.apple.com/tutorials/data/documentation/updates/foundationmodels.json : iOS 26(2025)은 텍스트 전용(WWDC25 세션 286 전사본에 이미지 언급 없음, 약 3B 파라미터 2-bit 양자화). **2026년 6월(iOS 27)에 이미지 입력 추가**: "Perform image analysis tasks by including an image in your prompt and using tools the Vision framework provides, like OCRTool and BarcodeReaderTool", `ImageAttachmentContent`, `PrivateCloudComputeLanguageModel`(더 큰 컨텍스트·추론), `LanguageModel` 프로토콜로 서버/온디바이스 모델 교체 가능, 2026-02(iOS 26.4)에 `SystemLanguageModel.contextSize`·`tokenCount(for:)` 추가, Playground가 4,096토큰 기준 사용량을 표시. `@Generable` 매크로로 구조화 출력 보장(constrained decoding), Tool 호출 지원. iOS 전용이므로 크로스플랫폼 앱에서는 플랫폼 분기 필요.

---

## 2. 좌표(grounding) 출력 규약 비교 (앱 구현 시 반드시 통일 필요)

| 제공자 | 포맷 | 좌표계 | 순서 | 앱 내부 정규화 방법 |
|---|---|---|---|---|
| Claude | `[x1,y1,x2,y2]` 또는 `[x,y]` 픽셀 | 모델이 본(리사이즈 후) 이미지의 절대 픽셀, 원점 좌상단 | x, y | 클라이언트가 먼저 `resized_size()`로 리사이즈해서 전송 → 반환 좌표를 그대로 사용, 필요 시 /width, /height 로 0–1 정규화 |
| Gemini | `box_2d: [ymin,xmin,ymax,xmax]`, `point: [y,x]` | 0–1000 정규화 | **y 먼저** | ×W/1000, ×H/1000 |
| Qwen3-VL | `bbox_2d: [x1,y1,x2,y2]`, `point_2d: [x,y]` | 0–1000 상대좌표 | x, y | ×W/1000 |
| GPT | 자유 형식(프롬프트로 지정) | 문서화된 규약 없음 | 프롬프트로 지정 | JSON 스키마로 강제 + 범위 검증 |

→ 앱의 내부 표준을 "원본 이미지 기준 0–1 정규화 (x, y)"로 잡고, 프로바이더 어댑터에서 변환하는 설계를 권장. 3D 재구성 단계(다른 조사 key)와의 인터페이스도 이 정규화 좌표 + 카메라 내부 파라미터로 맞춘다.

---

## 3. 품질: 2026년 VLM의 공간 추론/정밀 위치 지정 신뢰도

| 벤치마크 | 측정 내용 | 결과 (읽은 출처 기준) |
|---|---|---|
| BlindTest ("VLMs are Blind", 2024) | 선 교차 수 세기, 원 겹침, 중첩 사각형 수 등 저수준 시각 | GPT-4o/Gemini 1.5 Pro/Claude 3 Sonnet/3.5 Sonnet 평균 58.12%, 최고 Claude 3.5 Sonnet 74.94% (인간 100%) — https://github.com/anguyen8/vision-llms-are-blind |
| Point-Bench (PointArena, 2025; MolmoPoint 논문 표 2026-03) | 언어 지시 → 이미지 위 한 점 찍기(마스크 안이면 정답), 982문항 | 인간 89.1 / **Gemini-Robotics-ER-1.5 67.1 / Gemini-2.5-Pro ≈62 / Qwen3-VL-235B 58.3 / Molmo2-8B 68.7 / MolmoPoint-8B ≈70**. 카테고리별로 Steerable(위치 지시 조정)이 가장 약함(대부분 23~47%). PointArena: **CoT 추가 시 pointing 정확도 하락(GPT-4o −2.9pt, Gemini 2.5 Flash −16pt)**, 모델 크기 확대 효과 미미, pointing 지도학습 데이터가 핵심 — https://github.com/pointarena/pointarena , arXiv 2505.09990·2603.28069 (GitHub 미러 averkij/top_papers) |
| MMSI-Bench (2025) | 다중 이미지 공간 지능, 1,000문항 객관식 | 인간 97.2% / Gemini-3-pro 49.2 / o3 41.0 / GPT-4.5 40.3 / Gemini-2.5-Pro 36.9 / Qwen2.5-VL-72B 30.7 / GPT-4o 30.3 (랜덤 25) — https://github.com/OpenRobotLab/MMSI-Bench |
| VSI-Bench (2024-12) | 비디오 기반 거리·크기·방향 추정 5,000+ 문항 | 최신 MLLM도 인간 대비 크게 부족, 관계·자기중심↔타자중심 변환이 병목 — https://github.com/vision-x-nyu/thinking-in-space |
| Anthropic 공식 한계 문구 | — | "Claude's coordinate and localization outputs are approximate", 카운팅 근사, 200px 미만 소형 대상 오류 가능. Opus 4.7 이후 pointing/measuring/counting 및 자연 이미지 bbox 검출 개선(모델 마이그레이션 가이드), Opus 5/Fable 5.1은 "crop·zoom·verify 툴을 주는 것이 thinking 올리기보다 비용 효율적" |

시사점:
1. "경품 어디를 노릴지"는 **수 cm 단위 정밀도**가 필요한데, 최고 VLM의 단일 포인트 정확도는 마스크 안에 찍기 기준 ~70%다. 아암 폭(수 cm) 수준의 정밀도를 LLM 좌표에 직접 의존하면 실패율이 높다.
2. 반면 **배치 유형 분류(橋渡し/直置き/ペラ輪…), 아암 종류(2本爪/3本爪), 상황 설명·근거 생성, 다음 행동 전략**은 언어·의미 추론이라 VLM이 잘하고 few-shot으로 더 좋아진다.
3. 따라서 권장 하이브리드: (a) 온디바이스/서버 CV 검출기(YOLO 계열 fine-tune, SAM 계열 세그멘테이션, 깊이 추정)가 경품·바·아암·출구의 기하 정보를 픽셀 정확도로 추출 → (b) LLM에는 사진 + "검출 결과 JSON"을 함께 넣고 **선택·전략·설명**을 시키며, 좌표는 검출된 후보 중 "선택(ID)" 또는 "후보 기준 상대 오프셋"으로 받는다 → (c) LLM이 낸 좌표는 항상 검출 마스크/박스 안으로 스냅(clamp)한다. 이 구조는 PointArena의 "명확한 타깃 지정 프롬프트가 CoT보다 낫다"는 결과와도 부합한다.
4. Gemini Robotics-ER 2(포인트·박스·궤적 특화, $1/$5)와 MolmoPoint/Molmo2(오픈웨이트, 포인팅 최고 성능)는 "LLM만으로 포인팅"이 꼭 필요할 때의 1순위 후보다.

---

## 4. 프롬프트/에이전트 설계

### 4-1. 배치 유형 분류 체계 → 테크닉 매핑 (시스템 프롬프트에 인코딩)

아래 용어는 일본 게임센터 공략 커뮤니티의 일반 용어(사전지식; 일본 공략 사이트가 이 세션에서 차단되어 원문 확인 못 함 → 공략 조사 key 담당 결과와 교차 검증 필요).

| layout_type (enum) | 일본어 | 특징 | 기본 테크닉 | 조준 규칙(요약) |
|---|---|---|---|---|
| `bridge` | 橋渡し | 두 개의 봉(バー) 위에 상자 경품이 걸쳐짐 | 縦ハメ(세로 끼우기), 横ハメ(가로 끼우기), ずらし(밀어 옮기기) | 상자 무게중심에서 벗어난 한쪽 끝(약 1/4 지점)을 눌러 회전·전진, 봉 간격 대비 상자 길이로 縦/横 결정 |
| `direct_floor` | 直置き | 바닥/발판 위에 그대로 놓임(대개 봉제인형) | 持ち上げ(들어 올리기), 寄せ(끌어당기기), 転がし(굴리기) | 무게중심 바로 위 또는 태그·구멍에 아암 끝 걸기 |
| `ring_pera` | ペラ輪/リング | 얇은 고리에 아암 끝을 걸어 들어 올림 | 引っ掛け(걸기) | 고리 중심에서 살짝 안쪽, 아암 열림 폭과 하강 깊이 우선 |
| `takoyaki` | たこ焼き | 여러 상자가 붙어 있고 하나를 밀어 떨어뜨림 | 押し込み(밀어 넣기) | 가장 앞쪽/가장자리 상자의 바깥 모서리 |
| `three_claw_prob` | 3本爪/確率機 | 3발 아암, 확률 설정으로 아암 힘 변동 | 天井まで押し込み, 端寄せ | 힘 약할 때는 이동·굴리기만 노림, 정확 그립보다 위치 이동 |
| `step_shelf` | 段差/末広がり | 단차 있는 선반, 아래로 떨어뜨리기 | 落とし | 단차 가장자리 기준 밀어내기 |
| `bar_single` / `tag_hook` | 棒/タグ掛け・Dリング | 봉 하나에 걸린 경품, 태그·D링 걸기 | 引っ掛け | 걸이부 정중앙 |
| `unknown` | — | 판단 불가 → 추가 사진 요청 | — | — |

### 4-2. 시스템 프롬프트 초안 (영어 본문 + 일본어 용어; 캐시 안정성을 위해 고정 문자열로 유지)

```text
You are "CraneCoach", an expert Japanese crane-game (クレーンゲーム / UFOキャッチャー) strategist.
You receive: (1) one or more photos of a machine, (2) optional detector output (JSON list of
objects: prize boxes, bars/バー, claw/アーム, exit/落とし口, shelves) in normalized [0,1] (x,y)
coordinates relative to the ORIGINAL photo, (3) optional user notes (arm power feel, prior attempts).

Your job: classify the prize setup (layout_type), estimate machine state, and recommend ONE primary
aim point plus alternatives, with a concrete expected motion and reasoning a beginner can follow.

Rules:
- Use the taxonomy below. If confidence < 0.5 or the photo lacks the claw or the prize's contact
  points, set layout_type="unknown" and fill needs_more_photos with the exact angle you need
  (e.g. "side view level with the bars", "top-down view of the box").
- Coordinates: return aim points as absolute pixel coordinates of the image you were given
  (origin top-left, x right, y down). If detector candidates are provided, prefer returning
  target_object_id and an offset inside that object's box; never place a point outside it.
- Prefer moving/rotating strategies (ずらし, 寄せ, 押し込み) over "grab and lift" unless the arm
  is clearly strong (3本爪 with heavy grip marks, or the user says so).
- Explain expected motion in one sentence ("box rotates clockwise ~30°, right end drops between bars").
- Be honest about uncertainty; never claim a guaranteed win. Japanese terms in parentheses are fine.
- Output ONLY the JSON object matching the provided schema.

Taxonomy (layout_type → default technique → aim rule):
bridge(橋渡し) → 縦ハメ/横ハメ/ずらし → press off-center (~1/4 from one end) to rotate ...
direct_floor(直置き) → 持ち上げ/寄せ → center of mass or tag/loop ...
ring_pera(ペラ輪) → 引っ掛け → slightly inside the ring center ...
takoyaki(たこ焼き) → 押し込み → outer corner of the front-most box ...
three_claw_prob(3本爪) → move-only when weak → ...
step_shelf(段差) → 落とし → shelf edge ...
bar_single/tag_hook(棒/タグ掛け) → 引っ掛け → center of the hook/tag ...
```

few-shot: 주석 달린 예시 5~10장(사진 + 정답 JSON)을 시스템 프롬프트 뒤, 사용자 메시지 앞에 고정 배치. Claude는 이미지가 텍스트보다 앞에 오면 성능이 좋고(공식), 고정 접두부는 프롬프트 캐시로 90% 절감(캐시 최소 토큰: Opus 5/Fable 512, Sonnet 5 1024, Haiku 4.5 4096). 예시 이미지를 Files API `file_id`로 참조하면 페이로드가 작아지지만 Files API는 ZDR 비대상(공식) → 예시 이미지는 개인정보 없는 자체 촬영본만 사용.

### 4-3. 고정 JSON 출력 스키마 (Claude `output_config.format` / Gemini `response_json_schema` / OpenAI Structured Outputs 공용)

```json
{
  "type": "object",
  "additionalProperties": false,
  "required": ["layout_type","confidence","machine","prize","aim","reasoning","needs_more_photos","warnings"],
  "properties": {
    "layout_type": {"type":"string","enum":["bridge","direct_floor","ring_pera","takoyaki","three_claw_prob","step_shelf","bar_single","tag_hook","unknown"]},
    "layout_type_ja": {"type":"string"},
    "confidence": {"type":"number"},
    "machine": {
      "type":"object","additionalProperties":false,
      "required":["claw_count","arm_power_estimate","exit_side"],
      "properties":{
        "claw_count":{"type":"integer"},
        "arm_power_estimate":{"type":"string","enum":["weak","medium","strong","unknown"]},
        "exit_side":{"type":"string","enum":["front","left","right","back","unknown"]}
      }
    },
    "prize": {
      "type":"object","additionalProperties":false,
      "required":["kind","bbox_px","support_points_px"],
      "properties":{
        "kind":{"type":"string","enum":["box","plush","bag","ring_hung","other"]},
        "bbox_px":{"type":"array","items":{"type":"integer"}},
        "support_points_px":{"type":"array","items":{"type":"array","items":{"type":"integer"}}}
      }
    },
    "aim": {
      "type":"object","additionalProperties":false,
      "required":["target_point_px","target_object_id","descent_target","technique","expected_motion","alternatives"],
      "properties":{
        "target_point_px":{"type":"array","items":{"type":"integer"}},
        "target_object_id":{"type":["string","null"]},
        "descent_target":{"type":"string","enum":["top_surface","edge","tag","ring","floor","bar"]},
        "technique":{"type":"string","enum":["tate_hame","yoko_hame","zurashi","yose","oshikomi","mochiage","hikkake","korogashi","otoshi"]},
        "expected_motion":{"type":"string"},
        "alternatives":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["target_point_px","technique","why"],"properties":{"target_point_px":{"type":"array","items":{"type":"integer"}},"technique":{"type":"string"},"why":{"type":"string"}}}}
      }
    },
    "reasoning": {"type":"string"},
    "needs_more_photos": {"type":"array","items":{"type":"string"}},
    "warnings": {"type":"array","items":{"type":"string"}}
  }
}
```
주의(공식): Claude 구조화 출력은 `minimum/maximum`·`minItems>1`을 지원하지 않으므로 좌표 범위·배열 길이(2 또는 4)는 앱에서 검증한다.

### 4-4. 에이전트 구조 (CV를 툴로)

1. 클라이언트(Android/iOS): 촬영 → 얼굴 블러(ML Kit Face Detection / Vision) → 모델별 크기로 리사이즈(Claude는 `resized_size`, Gemini는 장변 ~800–1024px) → 백엔드로 전송.
2. 백엔드(1인 개발이면 Cloud Run/Firebase Functions, Kotlin 또는 Python): 
   - `detect_scene(image)` 툴: YOLO/SAM/깊이 모델 → 객체·바·아암 박스, 접촉점, 깊이 근사.
   - `crop_zoom(bbox)` 툴: Claude 문서 권장. 소형 대상 정밀 확인용(좌표에 크롭 오프셋 가산).
   - LLM 호출: 시스템 프롬프트(캐시) + few-shot + [사진, detector JSON] → 스키마 강제 JSON.
   - 후처리: 좌표 clamp, 검출 마스크 내 스냅, 0–1 정규화 → 3D 재구성 모듈로 전달.
3. self-consistency: 동일 입력을 n=3 샘플(Claude는 sampling 파라미터 미지원이므로 effort/프롬프트 변형 또는 서로 다른 모델 조합; Gemini는 temperature 0.5 반복)로 받아 `layout_type` 다수결 + `target_point_px` 중앙값, 3표 불일치면 `needs_more_photos` 로 반환. 비용 3배(아래 표 참조).
4. Claude 특이사항(공식): Fable 5.1·Opus 5.5는 강제 `tool_choice: any/tool` 400 → `auto` + 프롬프트 지시 + `strict: true`; 구조화 출력이 목적이면 `output_config.format` 사용. Opus 5.5 기본 effort `medium`, thinking off 불가. 실시간 앱이므로 effort `low`/`medium` + 스트리밍 권장. Fable 5.1은 refusal stop_reason과 `fallbacks: "default"` 처리 필요.
5. Gemini 특이사항(cookbook): 검출 프롬프트는 thinking 끄기, temperature 0.5, 객체 수 상한.

---

## 5. 비용 모델 (월 1만 / 10만 / 100만 회 분석)

가정: 분석 1회 = 이미지 1장 + 사용자 텍스트 150토큰 + 캐시된 시스템 프롬프트/분류체계/few-shot 텍스트 4,000토큰(캐시 읽기 단가) + 출력 700토큰(thinking 없는 Haiku) 또는 1,500토큰(adaptive thinking low 포함). 이미지 토큰: Claude 표준/사전 리사이즈 1456×819 = 1,560, Claude 고해상도 원본 4K 상한 4,784, Gemini high 1,120(2차 소스), GPT high detail 765(2차 소스 추정). 가격은 §1 표 기준(2026-09-24). 환율·세금 제외, 실시간이므로 배치 할인 미적용.

| 모델 | $/분석 | 월 1만 | 월 10만 | 월 100만 | 100만 × self-consistency 3회 |
|---|---|---|---|---|---|
| Claude Haiku 4.5 | $0.0056 | $56 | $561 | $5,610 | $16,830 |
| Claude Sonnet 5 (1456×819 사전 리사이즈) | $0.0192 | $192 | $1,922 | $19,220 | $57,660 |
| Claude Sonnet 5 (4K 원본 4,784토큰) | $0.0257 | $257 | $2,567 | $25,668 | $77,004 |
| Claude Opus 5.5 (사전 리사이즈) | $0.0376 | $376 | $3,764 | $37,640 | $112,920 |
| Gemini 3.8 Flash (high) | $0.0069 | $69 | $688 | $6,878 | $20,632 |
| Gemini 3.5 Flash-Lite (high) | $0.0043 | $43 | $425 | $4,251 | $12,753 |
| Gemini Robotics-ER 2 preview | $0.0092 | $92 | $917 | $9,170 | $27,510 |
| GPT-5.4 mini (high detail 추정) | $0.0077 | $77 | $774 | $7,736 | $23,209 |
| GPT-5.6 (high detail 추정) | $0.0353 | $353 | $3,526 | $35,260 | $105,780 |

- 프롬프트 캐싱 효과(Claude 공식 단가): 시스템 프롬프트 4,000토큰을 Sonnet 5로 매번 새로 보내면 $0.008/회, 캐시 읽기면 $0.0008/회 → 해당 부분 90% 절감. 월 100만 회 기준 Sonnet 5 총액 $26,420 → $19,220. 5분 캐시 write는 1.25x가 5분마다 1회만 발생하므로 트래픽이 꾸준하면 무시 가능; 트래픽이 드문 새벽에는 `max_tokens: 0` keep-alive 또는 1시간 캐시(2x) 고려.
- 이미지 토큰이 비용의 40~60%를 차지하므로 **클라이언트 리사이즈 정책이 최대의 비용 레버**(Claude 4K 원본 4,784 vs 1,560 토큰 = 3배).
- 하이브리드(CV 검출 서버 자체 호스팅 + LLM Flash/Haiku 급) 시 LLM 비용은 월 10만 회에 $400~$700, 100만 회에 $4,000~$7,000 수준으로 억제 가능. 온디바이스 사전 필터(기계 아님/흐림/각도 불량 → 재촬영 요청)를 두면 유료 호출 수 자체를 20~30% 줄일 수 있다(추정).
- 요금 검증 방법: Claude는 `POST /v1/messages/count_tokens`(이미지 포함 토큰 사전 계산, 공식) 사용; Gemini는 `count_tokens`; 실사용 `usage` 필드 로깅.

---

## 6. 프라이버시/약관

### 6-1. 제공자 정책
- **Anthropic(공식)**: 기본 비보존, 학습 미사용("never used for model training without your express permission"), 이미지 "ephemeral… not stored beyond the duration of the API request". ZDR은 조직 단위 신청(영업). **Fable 5/5.1은 30일 보존 필수·ZDR 불가**(요건 미충족 조직은 400). T&S 플래그 시 최대 2년. Files API/Batch/code execution은 ZDR 비대상. Commercial Terms: "Anthropic may not train models on Customer Content from Services" (https://www.anthropic.com/legal/commercial-terms). ZDR 조직은 CORS 불가 → 백엔드 프록시.
- **Google Gemini(사전지식·미검증)**: 유료 티어 학습 미사용, Vertex AI abuse-logging 옵트아웃(ZDR 상당), Pre-GA 기능은 DPA 미적용이므로 개인정보 처리 금지(Google Cloud Service Terms §5에서 확인). Robotics-ER 2 "preview"는 Pre-GA → 개인정보 포함 사진은 넣지 말 것.
- **OpenAI(사전지식·미검증)**: API 데이터 30일 남용 감시 후 삭제, 기본 학습 미사용, ZDR 신청 가능.

### 6-2. 일본 개인정보보호법(APPI, 個人情報の保護に関する法律) 관점 — 조문은 GitHub 미러(JuriCode-JP, e-Gov XML 기반, last_verified 2026-05-21)에서 확인
- 제2조 1항: "「個人情報」とは、生存する個人に関する情報であって…当該情報に含まれる氏名、生年月日その他の記述等（…音声、動作その他の方法を用いて表された一切の事項…）により特定の個人を識別することができるもの" / 2항 1호 個人識別符号: "特定の個人の身体の一部の特徴を電子計算機の用に供するために変換した…符号" → **사진에 다른 손님·점원의 얼굴이 찍히면 개인정보**. 얼굴 특징을 벡터화하면 개인식별부호.
- 제17조: 利用目的をできる限り特定 → 프라이버시 정책에 "撮影画像はプレイ戦略分析のためAI事業者(米国)に送信" 명시.
- 제27조 1항: "あらかじめ本人の同意を得ないで、個人データを第三者に提供してはならない"(委託·법령 예외 있음).
- 제28조 1항(발췌): "外国…にある第三者に個人データを提供する場合には…あらかじめ外国にある第三者への提供を認める旨の本人の同意を得なければならない"(十分性認定国 또는 基準適合体制 정비 시 예외; 2항: 동의 취득 시 해당 외국의 제도 등 참고 정보 제공 의무; 3항: 継続的な実施を確保するための措置). 미국은 十分性認定 대상이 아니므로 Anthropic/Google/OpenAI 전송은 **동의 + 정보 제공** 또는 **基準適合体制(DPA/표준계약)** 경로 필요.
- 제171조(적용범위): 국외 사업자도 "国内にある者に対する物品又は役務の提供に関連して…国内にある者を本人とする個人情報…を、外国において取り扱う場合についても、適用する" → 한국 개발자가 일본 이용자에게 서비스하면 APPI 적용.
- 개인정보보호위원회(PPC)는 2023-06-02 「生成AIサービスの利用に関する注意喚起」에서 이용목적 범위 내 입력·학습 이용 여부 확인을 요구(사전지식; https://www.ppc.go.jp/files/pdf/230602_alert_generative_AI_service.pdf 이 세션 차단).
- **실무 권고**: (1) 촬영 직후 온디바이스 얼굴 검출·블러(ML Kit Face Detection/Vision) 후 업로드 — 얼굴이 없으면 사실상 개인정보 이슈가 사라짐, (2) 서버에 원본 사진을 저장하지 않고 즉시 폐기(학습용 수집은 별도 옵트인), (3) 프라이버시 정책에 해외 제공(미국 AI 사업자명), 이용목적, 보존기간 명시 + 최초 실행 시 동의 화면, (4) ZDR/보존 최소 모델 선택(Fable 5.1은 30일 보존 필수이므로 회피), (5) 한국 이용자 대상이면 한국 PIPA 국외이전 고지도 병행.

---

## 7. 권장 의사결정

1. **두뇌 모델 1순위**: Claude Sonnet 5 (구조화 출력 GA, 절대 픽셀 좌표 문서화, 고해상도, $2/$10, 캐시 $0.20) 또는 Gemini 3.8 Flash (가장 싼 축, box_2d/point 규약 성숙). 비용 민감 구간(무료 이용자)은 Haiku 4.5/Gemini 3.5 Flash-Lite, 프리미엄 구간(유료 이용자)은 Opus 5.5.
2. **좌표는 LLM에 맡기지 말고 CV가 뽑고 LLM이 고르게** 한다(Point-Bench 인간 89 vs 최고 70). LLM에는 "검출 후보 ID 선택 + 박스 내 오프셋"을 시킨다.
3. **온디바이스는 전처리·프리필터·폴백**(Gemini Nano Prompt API, Apple Foundation Models iOS 27 이미지 입력)으로만 쓰고 조준 추천은 서버 LLM으로.
4. 프로바이더 락인 방지: 내부 정규화 좌표 규약 + 공용 JSON 스키마 + 어댑터. LiteLLM 같은 게이트웨이 사용도 고려(가격 DB 자체가 LiteLLM 산).
5. Kotlin 개발자 이점: Anthropic Java SDK는 Kotlin에서 그대로 사용 가능(백엔드용). 모바일 앱에는 API 키를 절대 넣지 말고 백엔드 경유.

## 8. 열린 질문
- Gemini 3.x 계열의 정확한 이미지 토큰 규칙(280/560/1120)과 Robotics-ER 2 정식 가격·GA 시점 — ai.google.dev 접근 후 재확인.
- GPT-5.4/5.6/6 계열 이미지 토큰 공식(패치 기반 배율) 및 OpenAI ZDR 조건 — openai.com 접근 후 재확인.
- Claude Sonnet 5·Opus 5.5의 크레인게임 사진에 대한 실제 pointing 정확도(공개 벤치마크에 Claude 4.x/5 계열 수치 없음) → 자체 100장 라벨 데이터로 A/B 필수.
- Gemma 3n/4 라이선스 원문(ai.google.dev/gemma/terms) 및 온디바이스 grounding 가능 여부.
- 일본 공략 커뮤니티의 배치 유형 명칭·분류(橋渡し 하위 유형 등) 검증 — 공략 조사 key 결과와 병합.
- PPC 생성 AI 주의환기 원문·2025~2026년 개정 사항.

## 9. 실제로 읽은 출처 목록
- https://platform.claude.com/docs/en/about-claude/pricing
- https://platform.claude.com/docs/en/models/overview
- https://platform.claude.com/docs/en/build-with-claude/vision
- https://platform.claude.com/docs/en/build-with-claude/vision-coordinates
- https://platform.claude.com/docs/en/build-with-claude/structured-outputs
- https://platform.claude.com/docs/en/manage-claude/api-and-data-retention
- https://platform.claude.com/docs/en/models/fable-5/introducing-claude-fable-5-and-claude-mythos-5
- https://www.anthropic.com/legal/commercial-terms
- https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json (2026-09-24)
- https://raw.githubusercontent.com/BerriAI/litellm/main/litellm/litellm_core_utils/token_counter.py
- https://raw.githubusercontent.com/openai/openai-openapi/master/openapi.yaml
- https://github.com/openai/openai-python
- https://raw.githubusercontent.com/google-gemini/cookbook/main/quickstarts/Spatial_understanding.ipynb
- https://raw.githubusercontent.com/google-gemini/cookbook/main/quickstarts/Counting_Tokens.ipynb
- https://raw.githubusercontent.com/google-gemini/cookbook/main/quickstarts/Video_understanding.ipynb
- https://raw.githubusercontent.com/google-gemini/cookbook/main/quickstarts/Models.ipynb
- https://raw.githubusercontent.com/google-gemini/cookbook/main/README.md
- https://raw.githubusercontent.com/google-gemini/robotics-samples/main/Getting%20Started/gemini_robotics_er.ipynb
- https://raw.githubusercontent.com/googleapis/python-genai/main/google/genai/types.py
- https://raw.githubusercontent.com/googleapis/python-genai/main/README.md
- https://github.com/QwenLM/Qwen3-VL , https://raw.githubusercontent.com/QwenLM/Qwen3-VL/main/cookbooks/2d_grounding.ipynb
- https://github.com/allenai/molmo
- https://github.com/meta-llama/llama-models/blob/main/models/llama4/LICENSE
- https://github.com/google-deepmind/gemma , https://github.com/google-ai-edge/LiteRT-LM , https://github.com/google-ai-edge/gallery , https://raw.githubusercontent.com/google-ai-edge/gallery/main/model_allowlist.json
- https://developer.android.com/ai/gemini-nano
- https://developer.apple.com/videos/play/wwdc2025/286/ , https://developer.apple.com/tutorials/data/documentation/foundationmodels.json , https://developer.apple.com/tutorials/data/documentation/updates/foundationmodels.json
- https://github.com/anguyen8/vision-llms-are-blind , https://github.com/pointarena/pointarena , https://github.com/OpenRobotLab/MMSI-Bench , https://github.com/vision-x-nyu/thinking-in-space
- https://raw.githubusercontent.com/averkij/top_papers/main/assets/json/2603.28069.json (MolmoPoint, Point-Bench 표), …/2505.09990.json (PointArena), …/2511.21631.json (Qwen3-VL 리포트)
- https://raw.githubusercontent.com/JuriCode-JP/JuriCode-JP/main/data/v0.2/phase1-administrative/kojin-jouhou-hogo-hou/kojin-jouhou-hogo-hou-article-{2,17,27,28,171}.md
- https://cloud.google.com/terms/service-terms (Pre-GA 조항)
- 차단되어 읽지 못한 곳: ai.google.dev, docs.cloud.google.com, developers.google.com, openai.com/platform.openai.com/developers.openai.com, arxiv.org(export/alphaxiv 포함), huggingface.co, ollama.com, ppc.go.jp, laws.e-gov.go.jp, japaneselawtranslation.go.jp, cas.go.jp, ja/en.wikipedia.org, learn.microsoft.com, deepmind.google, machinelearning.apple.com, privacy.claude.com, 일본 공략 사이트 다수.
