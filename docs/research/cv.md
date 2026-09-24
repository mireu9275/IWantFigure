# 조사 key: cv — 컴퓨터 비전 및 3D 재구성 기술 옵션 (크레인게임 조준 추천 앱)

- 조사일: 2026-09-24
- 한 줄 요약: 2026-09 기준, 온디바이스 검출은 **YOLO26(n)** 이 성능·모바일 지원(iPhone 17 Pro ANE 3.2 ms, Snapdragon 8 Elite Gen 5 GPU 15.8 ms) 면에서 가장 앞서지만 **AGPL-3.0/Enterprise 라이선스** 가 걸림돌이고, 상용 안전 대안은 **RF-DETR Nano(Apache 2.0)**·**MediaPipe Object Detector(Apache 2.0)**; 깊이는 **Depth Anything V2 Small(Apache, iPhone ~31–34 ms)** 또는 **DA3 METRIC-LARGE(Apache, 메트릭)**; 다중뷰 3D 는 **MapAnything Apache 변종**/**DA3**; 6-DoF 는 학습형 파운데이션 모델(FoundationPose/CenterPose 비상용) 대신 **상자 코너 키포인트 + PnP + 알려진 치수** 가 현실적. **MVP 는 클라우드 멀티모달 LLM(Gemini 3.x Flash 계열 spatial understanding) + 2D 오버레이**, v2 에서 온디바이스 검출 + 깊이 → 3D 로 가는 단계적 접근을 권장. 동일 컨셉의 선행 앱 **「AIクレーンゲーム軍師 (AIClawCoach)」(2026-03 출시, 10回500円)** 이 이미 존재함.

---

## 0. 조사 방법과 한계

- WebSearch 30회 이상, WebFetch 70회 이상 수행. GitHub(raw 포함), developer.android.com, developer.apple.com(포럼/WWDC 영상 페이지), pypi.org 는 직접 읽음.
- **직접 읽지 못한 도메인(프록시 차단)**: docs.ultralytics.com, ultralytics.com, huggingface.co(및 hf-mirror), aihub.qualcomm.com, developers.google.com, ai.google.dev, developers.googleblog.com, pytorch.org/docs.pytorch.org, onnxruntime.ai, play.google.com, apps.apple.com, universe.roboflow.com/roboflow.com/blog.roboflow.com, arxiv.org(모든 미러), wikipedia(ja/en), sega.jp, 일본 공략 블로그 다수(grabbit.co.jp, prize-lab.com, cranegame-kotsu.com, note.com 등), medium.com, infoq.com, deepmind.google, docs.unity3d.com.
- 위 도메인 정보는 **WebSearch 결과 스니펫** 에 의존했으며 아래 표에서 "(검색 스니펫)" 으로 표시하고 confidence 를 낮췄다. GitHub 원문(README/LICENSE/docs 마크다운)으로 확인한 항목은 confidence 를 높게 두었다.
- Ultralytics 문서는 docs 사이트가 차단되어 **GitHub 저장소 내 동일 마크다운(raw.githubusercontent.com/ultralytics/ultralytics/main/docs/en/...)** 을 읽어 확인했다.

---

## 1. 선행/경쟁 사례 (반드시 먼저 볼 것)

| 항목 | 내용 | 근거 |
|---|---|---|
| **AIクレーンゲーム軍師 – AIClawCoach** (株式会社テクノジェネシス 추정, 패키지 com.technogenesis.aiclawcoach) | 台の盤面を写真に撮るだけで AI が攻略法を解析. "精密座標分析" + **"3Dパースガイド"** 로 横向き/斜め 시점에서도 狙い所 표시. 요금: **秘伝チケット 10回 500円**. Google Play / App Store 양쪽 배포, 검색 스니펫상 2026-03 출시. 実機와 オンクレ 모두 지원 | Google Play: https://play.google.com/store/apps/details?id=com.technogenesis.aiclawcoach&hl=ja , App Store: https://apps.apple.com/jp/app/id6760863324 (둘 다 검색 스니펫; 페이지 직접 fetch 는 차단) |
| 日本工学院 × HEROZ "アシストキャッチャー/金箱クレア" | 카메라+AI 로 표정/상황 판단, 景品 再配置 하는 **기계측** AI (앱이 아님) | https://www.neec.ac.jp/news/202511/2025-11-06-63203.html , https://heroz.co.jp/release/2025/02/27_press02-2/ (검색 스니펫) |
| GPTs 기반 UFOキャッチャー 조언 | ChatGPT GPTs 로 사진 조언 (note 기사) | https://note.com/yoshiyuki_hongoh/n/nbf402740608b (검색 스니펫) |

시사점: "사진 → AI 조준 추천 + 3D 가이드" 는 이미 일본에 상용 앱이 있다. 차별화 포인트(한국어/다국어, 무료 티어, 온디바이스·오프라인, 정확도, 설정 유형 자동 분류, 커뮤니티 데이터)를 정해야 한다. 상대 앱의 정확도/구현(클라우드 LLM 인지, 자체 CV 인지)은 공개 정보로 확인 불가 → 직접 설치·테스트 필요.

---

## 2. 모바일용 객체 검출 / 세그멘테이션 비교표

### 2-1. 검출기

| 모델 | 버전/일자 | 크기(파라미터) | 정확도 | 라이선스 | 모바일 지원/지연 | 근거 URL |
|---|---|---|---|---|---|---|
| **Ultralytics YOLO26** | 2026-01 출시, 패키지 ultralytics 8.4.161 (2026-09-23) ; YOLO27 은 "R&D 중, 출시일 미정" | n 2.4M / s 9.5M / m 20.4M / l 24.8M / x 55.7M | COCO mAP50-95: n 40.9 / s 48.6 / m 53.1 / l 55.0 / x 57.5 ; CPU ONNX n 38.9 ms, T4 TRT n 1.7 ms | **AGPL-3.0 또는 Enterprise** (pypi classifier AGPLv3+) | NMS-free end-to-end 헤드. 7 task(detect/seg/semseg/**depth**/cls/pose/obb). Export: TFLite(LiteRT)/CoreML/ONNX/NCNN/ExecuTorch. **실측(공식 Flutter 플러그인 doc)**: YOLO26n detect 640px — iPhone 17 Pro CPU 9.2 ms / **ANE 3.2 ms**(INT8 CoreML); Xiaomi 17(8 Elite Gen 5) CPU 52.2 / GPU 15.8 / **NPU(QNN) 10.7 ms**; Galaxy S26(Exynos 2600) CPU 36.7 / GPU 16.4; Pixel 10(Tensor G5) CPU 53.3 / GPU 45.5; Xiaomi 17T Pro(Dimensity 9500) CPU 45.4 / GPU 26.6 (w8a32 LiteRT) | README: https://raw.githubusercontent.com/ultralytics/ultralytics/main/README.md ; yolo26.md: https://raw.githubusercontent.com/ultralytics/ultralytics/main/docs/en/models/yolo26.md ; LiteRT 벤치: https://raw.githubusercontent.com/ultralytics/ultralytics/main/docs/en/integrations/litert.md ; CoreML 벤치: https://raw.githubusercontent.com/ultralytics/ultralytics/main/docs/en/integrations/coreml.md ; Flutter perf: https://raw.githubusercontent.com/ultralytics/yolo-flutter-app/main/doc/performance.md ; PyPI: https://pypi.org/project/ultralytics/ ; GitHub: https://github.com/ultralytics/ultralytics |
| **RF-DETR (Roboflow)** | ICLR 2026, arXiv 2511.09554; 패키지 rfdetr | Nano 30.5M / Small 32.1M / Medium 33.7M / Large 33.9M / XL 126.4M / 2XL 126.9M (DINOv2 백본) | COCO AP: Nano 48.4 (T4 2.3 ms) / S 53.0 / M 54.7 / L 56.5 / XL 58.6 / 2XL 60.1 | **Apache 2.0** (rfdetr 패키지 + Nano~Large 가중치) ; XL/2XL 및 rfdetr_plus 는 **PML 1.0** | ONNX/TensorRT export 문서화. 모바일 공식 벤치 없음. react-native-executorch 가 `rfdetr_nano` 를 프리빌드 제공(Adreno 840/Mali-G76 GPU 측정 언급). DINOv2 백본이라 CPU 폰에서는 YOLO26n 보다 무거울 가능성 큼 → 실측 필요 | https://github.com/roboflow/rf-detr ; https://github.com/software-mansion/react-native-executorch/releases |
| **RT-DETR / v2 / v4 (Baidu)** | RT-DETRv4 추가됨 | RT-DETRv2-S 20M / L 42M / X 76M | v2-S 48.1 AP (T4 217 FPS) | **Apache-2.0** | onnxruntime/TensorRT/OpenVINO. 커뮤니티 Android LiteRT GPU 포트: RT-DETRv2-S **Pixel 8a 약 615 ms/프레임** → 실시간 모바일엔 부적합 | https://github.com/lyuwenyu/RT-DETR |
| **DEIMv2 (Intellindust)** | 2025-09 (DINOv3 백본) | Atto 0.5M / Femto 1.0M / Pico 1.5M / Nano 3.6M (HGNetv2) ; S 9.7M / M 18.1M / L 32.2M / X 50.3M (DINOv3) | AP: Atto 23.8 / Femto 31.0 / Pico 38.5 / Nano 43.0 / S 50.9 / M 53.0 / L 56.0 / X 57.8 (T4 latency 1.10~13.75 ms) | **DEIMv2 License**(별도, 상용은 Intellindust 문의) ; 전작 DEIM(v1) 은 Apache 2.0 | ONNX/TensorRT export, Intel Geti 연동. 모바일 벤치 없음. 초경량 변종(Nano 3.6M, 43.0 AP) 은 YOLO26n(2.4M, 40.9) 대비 매력적이지만 라이선스 확인 필수 | https://github.com/Intellindust-AI-Lab/DEIMv2 |
| D-FINE (USTC) | 2024-10 | — | DEIM-D-FINE-L 54.7 AP | Apache 2.0 (Roboflow playground 스니펫) | 모바일 벤치 없음 | https://playground.roboflow.com/models/ustc/d-fine (검색 스니펫) |
| **MediaPipe Object Detector (Google AI Edge)** | MediaPipe Tasks | EfficientDet-Lite0(320×320, EfficientNet-Lite0+BiFPN), Lite2, SSD-MobileNetV2 | EfficientDet-Lite0 COCO2017 val mAP 25.69% (검색 스니펫) | **Apache-2.0** | Android/iOS/Web/Python 공식 SDK. 커스텀 TFLite(메타데이터 포함) 모델 교체 가능. mAP 는 낮으나 라이선스·통합이 가장 쉬움 | https://github.com/google-ai-edge/mediapipe ; 샘플: https://raw.githubusercontent.com/google-ai-edge/mediapipe-samples/main/examples/object_detection/android/README.md |
| EfficientDet-Lite (TFLite Model Maker) | 레거시 | Lite0~Lite4 | — | Apache 2.0 | LiteRT Model Maker 문서(차단) | https://ai.google.dev/edge/litert/libraries/modify/object_detection (검색 스니펫) |

### 2-2. 세그멘테이션(SAM 계열)

| 모델 | 크기 | 라이선스 | 모바일 | 근거 |
|---|---|---|---|---|
| **SAM 3 / 3.1** (Meta, 2025-11-19 / 3.1 은 2026-03-27) | **848M** 파라미터, Python 3.12+, PyTorch 2.7+, **CUDA 12.6+ GPU 필수** | **SAM License**(커스텀; 상용 사용 허용, 군사/ITAR 등 금지, 동일 조건 재배포) | 온디바이스 부적합(서버용). 텍스트/예시 프롬프트로 "모든 인스턴스" 검출·분할 → **서버측 자동 라벨링** 에는 최적 | https://github.com/facebookresearch/sam3 ; LICENSE: https://raw.githubusercontent.com/facebookresearch/sam3/main/LICENSE |
| **SAM 2.1** (2024-09-29) | Tiny 38.9M / Small 46M / Base+ 80.8M / Large 224.4M (A100 91.2~39.5 FPS) | **Apache 2.0** | 공식 모바일 export 없음(커뮤니티 ONNX/CoreML 있음) | https://github.com/facebookresearch/sam2 |
| **MobileSAM** | 총 9.66M(TinyViT 인코더 5M) ; GPU 12 ms/이미지 | **Apache-2.0** | ONNX 커뮤니티 export(samexporter). CPU(Mac i5) ~3 s | https://github.com/ChaoningZhang/MobileSAM |
| **EdgeSAM** | 인코더 9.6M ; **iPhone 14 38.7 FPS(≈26 ms)** ; Core ML export 스크립트/모델 제공, iOS 앱 CutCha | **NTU S-Lab License 1.0**(재배포 조건 확인 필요) | iOS 실측 있는 유일한 SAM 변종 | https://github.com/chongzhou96/EdgeSAM |
| EfficientSAM (Meta) | Ti / S | **Apache-2.0** | TorchScript/ONNX(HF) | https://github.com/yformer/EfficientSAM |

### 2-3. 선택 가이드
- **상용 앱 + 라이선스 안전**: RF-DETR Nano(Apache) 또는 MediaPipe/EfficientDet-Lite(Apache). DEIMv2 는 라이선스 문의 필요.
- **최고 성능/모바일 툴체인**: YOLO26n — 단, AGPL-3.0 이면 앱 소스 공개 의무(네트워크 서비스 포함), 비공개면 Enterprise 라이선스. 가격은 공식 미공개(개별 견적; 커뮤니티에서 $5,000/년 언급은 비공식). YOLO 를 **학습·라벨링 도구로만 서버에서** 쓰고 배포 모델은 Apache 계열로 증류(distillation)하는 전략도 라이선스 검토 필요(AGPL 은 "학습된 가중치" 범위가 모호 — GitHub discussion #1260 에서도 명확한 답 없음).
- 세그멘테이션은 **서버측 SAM 3 로 자동 라벨링** → 온디바이스는 검출기 + (필요시) EdgeSAM/MobileSAM.

---

## 3. 단안 깊이 / 다중뷰 3D 재구성 비교표

| 모델 | 크기 | 라이선스 | 메트릭(미터) 출력 | 모바일 실행 | 근거 |
|---|---|---|---|---|---|
| **Depth Anything V2** (ByteDance/HKU) | Small 24.8M / Base 97.5M / Large 335.3M / Giant 1.3B | **Small: Apache-2.0**, Base/Large/Giant: **CC-BY-NC-4.0** | 상대 깊이 기본. **Metric-Hypersim-Small(실내, 최대 20 m, Apache 2.0)** 별도 제공 (검색 스니펫) | Apple 공식 Core ML 패키지(coreml-depth-anything-v2-small: F16 49.8 MB, **iPhone 12 Pro Max 31.1 ms / iPhone 15 Pro Max 33.9 ms, Neural Engine**) — 검색 스니펫. Qualcomm AI Hub: **Snapdragon 8 Elite Gen 5 TFLite 19.8 ms @518×518, peak mem 390 MB** — 검색 스니펫 | https://github.com/DepthAnything/Depth-Anything-V2 ; https://huggingface.co/apple/coreml-depth-anything-v2-small (차단) ; https://aihub.qualcomm.com/mobile/models/depth_anything_v2 (차단) |
| **Depth Anything 3 (DA3)** (2025-11, ICLR 2026) | DA3-SMALL 0.08B / BASE 0.12B / LARGE 0.35B / GIANT 1.15B ; DA3METRIC-LARGE 0.35B ; DA3MONO-LARGE 0.35B ; NESTED-GIANT-LARGE 1.40B | **Apache 2.0: SMALL, BASE, METRIC-LARGE, MONO-LARGE** ; **CC BY-NC 4.0: LARGE, GIANT, NESTED** | METRIC-LARGE 가 단안 메트릭 깊이. Any-view: 1~N 장, 카메라 포즈 있거나 없거나 → 깊이+포즈 동시 추정 | 공식 문서는 GPU(XFormers) 전제. Qualcomm AI Hub 에 Depth-Anything-V3 등재(검색 결과) → SMALL/BASE 는 모바일 변환 가능성 높음 | https://github.com/ByteDance-Seed/Depth-Anything-3 ; https://aihub.qualcomm.com/models/depth_anything_v3 (차단) |
| **YOLO26-depth** (Ultralytics) | README 표: n 6.3M / s 13.2M / m 23.3M / l 27.7M / x 57.0M (tasks/depth.md 는 n 2.7M 등 다른 수치 — 문서 간 불일치, 최신 README 우선) | AGPL-3.0/Enterprise | **미터 단위 메트릭 깊이** (NYU delta1 n 0.882, abs_rel 0.109 — README) ; 사전학습 ~2.19M 이미지(NYU/KITTI/Hypersim/SUN RGB-D/ARKitScenes) | **iPhone 17 Pro INT8 CoreML: CPU 25.0 ms / ANE 5.3 ms** ; T4 fp16 768px 2.29 ms(DA-V2-Small 13.62 ms 대비 6×) | https://raw.githubusercontent.com/ultralytics/ultralytics/main/README.md ; https://raw.githubusercontent.com/ultralytics/ultralytics/main/docs/en/tasks/depth.md ; https://raw.githubusercontent.com/ultralytics/ultralytics/main/docs/en/integrations/coreml.md |
| **Apple Depth Pro** | 파라미터 비공개; Core ML 변환본 **1.9 GB**(1536×1536) | **Apple Sample Code License(ASSCL)** — 상용/재배포 허용, 상표 사용 금지 | 메트릭 + **초점거리(focal length) 자체 추정** | 표준 GPU 0.3 s/2.25 MP. 모바일엔 과대 | https://github.com/apple/ml-depth-pro ; LICENSE: https://raw.githubusercontent.com/apple/ml-depth-pro/main/LICENSE |
| **Metric3D v2** | ViT-Small / Large / giant2 | **BSD-2-Clause** | 메트릭(단, **초점거리 입력 필요**) | ONNX(dynamic shape) 제공. 모바일 벤치 없음 | https://github.com/YvanYin/Metric3D |
| **UniDepth V2** | ViT-S/B/L | **CC BY-NC 4.0** → 상용 불가 | 메트릭 + 내부 파라미터 추정, ONNX | — | https://github.com/lpiccinelli-eth/UniDepth |
| ZoeDepth | ZoeD-N/K/NK | MIT | 메트릭 | **2025-05-05 아카이브(Intel 유지보수 종료)** | https://github.com/isl-org/ZoeDepth |
| **VGGT** (Meta, CVPR 2025 Best Paper) | 1B (500M/200M 예정) | 원본 비상용 ; **VGGT-1B-Commercial** 체크포인트는 상용 허용(군사 제외) | 1~수백 장 → 카메라 내·외부 파라미터, 깊이, 포인트맵, 트랙 ; 스케일은 상대 | GPU 전제(초 단위) → 서버용 | https://github.com/facebookresearch/vggt |
| **DUSt3R / MASt3R** (Naver) | ViT-L 인코더 | **CC BY-NC-SA 4.0** + 체크포인트는 학습 데이터 라이선스(mapfree 매우 제한적) | MASt3R 메트릭 변종 있음 | GPU 전제 → 상용 불가 | https://github.com/naver/mast3r ; https://github.com/naver/dust3r |
| **MapAnything** (Meta, 3DV 2026) | DINOv2 백본, 518px | **facebook/map-anything-apache = Apache 2.0** (원본은 CC BY-NC 4.0) | **메트릭 3D** (이미지 + 선택적 intrinsics/pose/depth 입력 → 월드 좌표, 깊이, 포즈, 스케일 팩터) | CUDA GPU 필요 → 서버 다중뷰 재구성 1순위 후보 | https://github.com/facebookresearch/map-anything |

### 3-1. 실제 스케일(미터) 확보 방법 정리
1. **알려진 치수 물체 + PnP**: 프라이즈 상자(폭·높이·깊이)나 아암 크기를 사전 DB 로 두고, 상자 코너 8점(2D 키포인트) → `solvePnP`(IPPE/IPPE_SQUARE, 평면 4점만으로도 가능) 로 카메라 상대 6-DoF + 스케일 확보. 상자 치수 DB 는 공개 표준이 없어(검색상 "프라이즈 피규어는 대체로 全高 20 cm 전후" 수준) **직접 수집** 필요.
2. **기계 자체 치수**: UFO CATCHER 10 공식 스펙 幅1685×奥行1050×高さ1998 mm(검색 스니펫, sega.jp 차단). 기종 인식 → 필드 폭/바 간격 등 고정 치수로 스케일 복원 가능. UFO CATCHER 9(2014년, 무기둥 오픈 설계), クレナフレックス(2004, フリーホール) 등 주요 기종.
3. **ARCore Depth API**(Android): 16-bit mm 깊이(1.31 부터 최대 65,535 mm, 이전 8,191 mm), Raw Depth(희소·고정밀, 신뢰도 이미지 동반), 1.56.0 에서 `AcquireDepthImageMeters` 추가. ToF 센서 불필요(모션 스테레오). 검색 스니펫상 2026-05 기준 활성 기기의 88% 이상이 Depth API 지원. `Session.isDepthModeSupported` 로 확인.
4. **ARKit sceneDepth**(iOS): LiDAR 탑재 기기 전용(iPhone 12 Pro 이후 **Pro 모델만**; iPhone 17/17 Air 등 비Pro 는 LiDAR 없음 — 검색 스니펫). 해상도 **256×192 @ 60 FPS**(ARKit), AVFoundation LiDAR 카메라는 320×240 @ 30 FPS. `ARDepthData.depthMap`(미터) + `confidenceMap`(low/medium/high). 유리 너머 LiDAR 는 반사/투과로 신뢰도 저하 가능 → 유리면 깊이만 얻고 내부는 RGB 기반으로 보정하는 하이브리드 필요.
5. **AR 세션 자체의 메트릭 스케일**: ARKit/ARCore 는 VIO 로 미터 스케일 카메라 포즈를 제공 → 2~3장을 AR 세션에서 찍으면 포즈 기지 다중뷰(DA3 any-view/MapAnything 의 pose 입력)로 스케일 문제가 해소된다.

---

## 4. 상자 6-DoF 자세 추정 옵션

| 방법 | 입력 | 라이선스 | 온디바이스 | 평가 | 근거 |
|---|---|---|---|---|---|
| **FoundationPose** (NVIDIA, CVPR 2024) | RGB(-D) + CAD 또는 소수 참조 이미지 | **NVIDIA Source Code License — 비상용(§3.3 "non-commercially", 연구·평가 목적)** | GPU 전제 | 상용 앱 불가 | https://github.com/NVlabs/FoundationPose ; https://raw.githubusercontent.com/NVlabs/FoundationPose/main/LICENSE |
| **MegaPose** (Inria/NVIDIA) | RGB + **CAD 메시(mm) 필수** + 2D bbox | **Apache 2.0** | GPU 전제 | 상자별 메시가 필요(단순 직육면체 메시로 대체 가능) → 서버 파이프라인 후보 | https://github.com/megapose6d/megapose6d |
| **CenterPose** (NVIDIA) | 단일 RGB, 카테고리 레벨(Objectron: cereal box, book, laptop 등 9종) → 6-DoF + 큐보이드 치수 | **NVIDIA Source Code License – Non-commercial** | GTX 1080Ti 15 fps | 아이디어(키포인트 기반 큐보이드)는 참고, 코드는 상용 불가 | https://github.com/NVlabs/CenterPose |
| **MediaPipe Objectron** | 2-stage(2D 검출→3D box 9 keypoints), shoes/chairs/cups/cameras | Apache 2.0 | 모바일 GPU 실시간(단일 스테이지 26 FPS) | **2023-03-01 지원 종료(legacy)** | https://raw.githubusercontent.com/google-ai-edge/mediapipe/master/docs/solutions/objectron.md |
| **Objectron 데이터셋** | 15K 클립 / 4M 프레임, 3D box 라벨, AR 메타데이터 | **C-UDA-1.0** | — | box 계열(cereal box/book) 사전학습 데이터로 활용 가능(라이선스 검토) | https://github.com/google-research-datasets/Objectron |
| **단순 방법(권장)**: 상자 코너 키포인트 검출(YOLO26-pose/RF-DETR keypoint 미리보기) + 알려진 치수 + PnP ; 또는 바/레일 직선 검출 + 소실점으로 카메라 자세 추정 | RGB 1장 | 자체 구현 | CPU 에서도 ms 단위 | 유리 반사에는 키포인트 confidence 필터 + 사용자 미세조정 UI 필요 | (OpenCV solvePnP 문서 docs.opencv.org 차단, API 존재는 일반 지식) |

### 4-1. 유리 반사/글레어 대응
- 연구: **NTIRE 2026 Single Image Reflection Removal in the Wild** 챌린지, OpenRR-5k(학습 5,000쌍/검증 300/테스트 100) — 딥러닝 반사 제거는 진전됐으나 "다양한 장면에서 일관된 품질" 은 여전한 과제 (검색 스니펫; arXiv 2604.10321 원문 차단). 모바일 실시간 반사 제거 모델은 실용 단계 아님.
- 현실적 대책(일본 촬영 팁 사이트 스니펫): PL(편광) 필터, 렌즈 스커트/실리콘 후드, 스마트폰을 유리에 밀착, 검은 옷/검은 손수건, 조명 반사각 피하기. → 앱 UX 로 "유리에 붙여서 정면/약간 위에서 촬영" 가이드 + 반사 검출 시 재촬영 유도. 학습 데이터에 반사·글레어 증강(합성 반사 오버레이) 포함.

---

## 5. 온디바이스 런타임 비교표 (2026-09-24 기준)

| 런타임 | 최신 버전 | 라이선스 | Android | iOS | 가속기 | 프레임워크 연동 | 근거 |
|---|---|---|---|---|---|---|---|
| **LiteRT** (구 TFLite, Google AI Edge) | ai-edge-litert **2.2.0 (2026-08-12)** ; 6–8주 안정 릴리스 | Apache-2.0 | CPU/GPU(OpenCL·GL, ML Drift)/**NPU(Qualcomm, MediaTek, Google Tensor, Broadcom, Intel)** | CPU/GPU(Metal), **ANE "coming soon"** | CompiledModel(V2) API: 자동 가속기 선택, 비동기 실행 | Kotlin/Swift/C++/JS. Flutter: flutter_litert 3.9.0+(Apache 2.0, LiteRT Next 2.2.0 번들, ANE iOS13+/QNN API31+), ultralytics_yolo 0.6.15. 2026-01 GPU/NPU 가속이 production 으로 승격(검색 스니펫) | https://github.com/google-ai-edge/LiteRT ; https://pypi.org/project/ai-edge-litert/ ; https://github.com/hugocornellier/flutter_litert ; https://github.com/google-ai-edge/litert-samples |
| **Core ML / Core AI** (Apple) | iOS 26 Core ML ; **WWDC 2026 에서 Core AI(iOS 27) 발표, Core ML 은 계속 동작·비추천 아님**(검색 스니펫) | Apple SDK | — | CPU/GPU/**Neural Engine**(`.cpuAndNeuralEngine`) | YOLO26n INT8: iPhone 17 Pro ANE 3.2 ms | Ultralytics Flutter 플러그인이 iOS 27+ Core AI opt-in 지원 | https://raw.githubusercontent.com/ultralytics/ultralytics/main/docs/en/integrations/coreml.md ; https://github.com/ultralytics/yolo-flutter-app |
| **ONNX Runtime** | **v1.30.0 (2026-09-10)** | MIT | NNAPI / XNNPACK / **QNN**(Snapdragon) EP | CoreML / XNNPACK EP | — | Android AAR, ObjC/Swift pod, C#. Unity Sentis 도 ONNX 입력 | https://github.com/microsoft/onnxruntime/tags |
| **ExecuTorch** (PyTorch) | **1.5.1 (2026-09-22)**, 1.0 은 2025-10 | BSD-3-Clause | XNNPACK / Vulkan / Qualcomm / MediaTek / Samsung Exynos / Arm | XNNPACK / **Core ML** / MPS / Metal(실험) | .pte 단일 포맷 | Swift·Kotlin API ; **react-native-executorch 0.10.x**(iOS 17+/Android 13+, RN 0.83+, YOLO26·rfdetr_nano·SAM 프리빌드, VisionCamera runOnFrame) ; Ultralytics `export(format="executorch")` (Pi5: 314.8→142 ms) | https://github.com/pytorch/executorch ; https://pypi.org/project/executorch/ ; https://github.com/software-mansion/react-native-executorch ; https://raw.githubusercontent.com/ultralytics/ultralytics/main/docs/en/integrations/executorch.md |
| **MediaPipe Tasks** | (LiteRT 위 고수준 API) | Apache-2.0 | O | O | GPU delegate | Android/iOS/Web/Python | https://github.com/google-ai-edge/mediapipe |
| **NCNN** (Tencent) | **20260526** | BSD-3 | Vulkan GPU | Vulkan(MoltenVK) | 의존성 없음 | YOLOv2~v8/YOLOX 예제; C++ 중심 | https://github.com/Tencent/ncnn |
| **Unity Inference Engine (Sentis)** | com.unity.ai.inference 2.x(2.6 문서 존재; 이름이 Sentis 로 회귀) | Unity 패키지 | O | O | GPUCompute/CPU | ONNX 입력, FP16/UInt8 양자화 ; 3D 오버레이 렌더링과 한 엔진에서 처리 가능 | https://docs.unity3d.com/Packages/com.unity.ai.inference@2.6/manual/index.html (차단, 검색 스니펫) |
| **KMP(Kotlin Multiplatform)** | — | — | LiteRT | Core ML/LiteRT-iOS | expect/actual 로 플랫폼별 추론 래핑 | LiteRT-LM 에 KMP `-core` 패키지 요청 이슈(#2628, 2026-06-23) 진행 중 → 공식 KMP 추론 API 는 아직 없음 | https://github.com/google-ai-edge/LiteRT-LM/issues/2628 |

개발자 프로필(Kotlin Android 경험, iOS 경험 없음) 관점의 결론:
- **Flutter + ultralytics_yolo/flutter_litert** 또는 **KMP(Compose Multiplatform) + LiteRT(Android)/Core ML(iOS) expect-actual** 이 현실적. RN 은 JS 경험이 필요.
- 3D 오버레이(경품·바·아암 재구성 + 조준점)를 보여줘야 하므로 **Unity(AR Foundation + Sentis)** 도 강력한 후보: ARCore/ARKit 추상화(AR Foundation), ONNX 추론, 3D 렌더링이 한 곳에서 해결. 단 C# 경험(WinForms)은 있으나 Unity 학습 비용 있음.

---

## 6. AR/깊이 SDK 로 3D 좌표 얻기

| SDK | 핵심 사양 | 앱에서의 사용법 | 근거 |
|---|---|---|---|
| **ARCore Depth API** (Android) | 16-bit mm 깊이, 최대 65,535 mm(1.31+), Raw Depth(희소·고정밀, confidence 이미지), 모션 기반(ToF 불필요, 있으면 근거리 신뢰도↑), SDK 1.56.0 에서 float 미터 API 추가 ; ARCore SDK for iOS 는 별도(Depth 는 Android 전용) | 유리면까지 거리 + 카메라 포즈(미터) 확보 → 유리면 평면 추정 → 내부 깊이는 단안 모델 상대 깊이를 유리면 거리로 스케일링. Raw Depth 는 정적 장면에서 몇 프레임 누적 권장 | https://github.com/google-ar/arcore-android-sdk/releases ; https://github.com/google-ar/arcore-android-sdk/releases/tag/v1.31.0 ; https://raw.githubusercontent.com/google-ar/arcore-android-sdk/main/libraries/include/arcore_c_api.h ; https://github.com/googlesamples/arcore-depth-lab |
| **ARKit sceneDepth** (iOS) | LiDAR 기기 전용, 256×192 @ 60 FPS, depthMap(미터)+confidenceMap(3단계), `supportsFrameSemantics(.sceneDepth)` 로 확인 ; `personSegmentationWithDepth` 와 병용 시 추가 전력 0 | Pro 모델에서만 LiDAR 깊이 ; 비Pro 는 ARKit VIO 포즈 + 평면 검출 + 단안 깊이 모델로 대체 | WWDC20 10611: https://developer.apple.com/videos/play/wwdc2020/10611/ ; 포럼: https://developer.apple.com/forums/thread/712943 |
| 공통 전략 | AR 세션의 미터 스케일 카메라 포즈 + 유리면 평면 앵커 → 조준점을 월드 좌표 앵커로 배치하면 카메라를 움직여도 오버레이 유지 | AR Foundation(Unity) 또는 플랫폼별 네이티브 | — |

---

## 7. 데이터 전략

### 7-1. 라벨링 도구 비교
| 도구 | 라이선스/가격 | AI 보조 | 내보내기 | 비고 | 근거 |
|---|---|---|---|---|---|
| **CVAT** | Community **MIT**, 셀프호스트 ; CVAT Online 무료 티어 + Solo $23/월(연간), Team $46/월~(검색 스니펫) | SAM 인터랙터, YOLOv7, RetinaNet(serverless/Docker) | YOLO/COCO/VOC/KITTI 등 20+ | 1인 개발자 셀프호스트 최적 | https://github.com/cvat-ai/cvat |
| **Label Studio** | Community **Apache 2.0** ; Starter Cloud 유료(약 $50–99/월, 스니펫) | ML backend SDK(SAM 백엔드 예제 존재) | YOLO/COCO(converter) | 데이터 타입 범용 | https://github.com/HumanSignal/label-studio |
| **Roboflow** | Public(무료) 은 **데이터·모델이 Universe 에 공개됨**, Core $79/월(연간)·$99/월(월간)(스니펫) | 자동 라벨링(SAM 등), 학습·배포 통합 | 다양 | 빠르지만 비공개 데이터는 유료 | https://checkthat.ai/brands/roboflow/pricing (검색 스니펫) |

### 7-2. 합성 데이터
| 도구 | 라이선스 | 기능 | 상태 | 근거 |
|---|---|---|---|---|
| **BlenderProc2** | **GPL-3.0**(툴 자체; 생성 이미지에는 영향 없음) | 물리 시뮬(상자 낙하/쌓기), COCO/BOP 포즈 라벨, 도메인 랜덤화, depth/normal/seg | 활성 | https://github.com/DLR-RM/BlenderProc |
| **Kubric** | Apache 2.0 | TFDS 통합, 대규모 분산 | 활성(검색 스니펫) | CVPR 2022 논문 |
| Unity Perception | Apache 2.0 | bbox/seg/keypoint 랜덤화 | **Unity 가 공식 지원 종료(discontinued)** | https://github.com/Unity-Technologies/com.unity.perception |

→ 크레인게임은 "투명 아크릴/유리 케이스 + 2본 바 + 상자 + 3본/2본 아암" 이라는 정형 구조라 BlenderProc 로 **상자 6-DoF/코너 키포인트 GT** 를 대량 생성하기 좋다(반사·굴절은 Cycles 로 물리 기반 재현 가능).

### 7-3. 필요 데이터량(경험칙)
- Ultralytics 공식 가이드: **클래스당 ≥1,500 이미지, ≥10,000 인스턴스, 배경 이미지 0–10%**, 촬영 조건(조명·각도·기기) 다양성, 모든 객체 라벨링. (https://github.com/ultralytics/yolov5/wiki/Tips-for-Best-Training-Results)
- 현실적 MVP: 클래스 5~8개(box, plush, bar/rail, ring, claw_arm, claw_tip, drop_hole, glass_reflection) × 300~500장(≈2,000~4,000장) 으로 파인튜닝 시작 → 합성 데이터로 보강 → 사용자 업로드로 성장.

### 7-4. 공개 데이터셋 존재 여부
- Roboflow Universe: `class:claw` 검색에서 "crane game" 소형 데이터셋(약 123장, 클래스 claw/dool/grabbedclaw) 스니펫 확인 — 직접 열람 불가(차단), 규모 작음. 나머지 "crane" 데이터셋은 건설 크레인. (https://universe.roboflow.com/search?q=class:claw)
- Kaggle/HuggingFace: "claw machine / crane game / UFO catcher" 이미지 데이터셋 **발견 못함**. Civitai 에 SD LoRA 만 존재(학습용 부적합).
- Objectron(C-UDA-1.0): cereal box/book 3D box 라벨 → 큐보이드 키포인트 사전학습용.
- 결론: **자체 수집이 필수**. 일본 게임센터 촬영(점포 촬영 허가 주의), YouTube/온크레(オンクレ) 스트림 캡처는 저작권·이용약관 확인 필요.

### 7-5. 라벨 스키마 제안(설정 유형 분류)
일본 공략 사이트 스니펫에 공통 등장하는 설정 유형: **橋渡し**(2본 바 위 상자; 縦ハメ/横ハメ/寄せ), **直取り**(3本爪/2本爪, 인형), **リング系**(Dリング/ペラ輪), **たこ焼き(穴落とし)**, 確率機 등. 경품 상한 "おおむね1,000円 이하"(2022년 800→1,000円, 2026-07 警察庁 재고지 — 검색 스니펫) 는 앱 법적 고지에 참고.

---

## 8. 단계별 파이프라인 추천

### MVP (1인 개발, 2~3개월)
1. 촬영 UX: 유리 밀착·정면·약간 위 각도 가이드, 1~3장.
2. **클라우드 멀티모달 LLM**(Gemini 3.x Flash 계열: 2D bbox `[y1,x1,y2,x2]` 0–1000 정규화 출력이 공식 쿡북에 문서화, pointing/3D box 는 "experimental")로 (a) 설정 유형 분류, (b) 상자/바/아암 bbox, (c) 조준점(2D) + 이유 텍스트를 JSON 으로 받음. 온도 0.5, 객체 25개 이하, thinking off 권장(쿡북).
   - 비용: 검색 스니펫 기준 Gemini 3.6~3.8 Flash $0.75/M 입력·$3.75/M 출력(2026-12-31 까지 프로모, 이후 2배), 2.5 Flash $0.30/$2.50. 사진 1장 ≈ 수백~천여 토큰 → 1회 분석 수 원 이하.
   - Gemini Robotics-ER 2(2026-07-30 공개, `gemini-robotics-er-2-preview`)는 pointing/bbox/궤적 특화 — 스니펫 기준, 정확도 검증 필요.
3. 2D 오버레이(조준점, 밀어야 할 방향 화살표) + 간단한 **의사 3D**: 바 2개와 상자를 평면 호모그래피로 탑뷰 변환해 표시.
4. 사용자 피드백(성공/실패, 실제로 노린 위치) 수집 → 자체 데이터셋.

### v2 (온디바이스 검출 + 깊이 → 3D)
1. 라벨링: CVAT 셀프호스트 + SAM 3(서버) 자동 마스크 → 박스/키포인트 GT.
2. 검출기: 라이선스 결정에 따라 **YOLO26n(Enterprise)** 또는 **RF-DETR Nano/MediaPipe(Apache)**. 상자 코너 8점은 pose/keypoint 헤드로.
3. 깊이: Depth Anything V2 Small(Apache, iPhone ~31–34 ms, Snapdragon 8 Elite Gen 5 ~20 ms) 또는 DA3-SMALL/METRIC 변환본; 스케일은 상자 치수 PnP + ARCore/ARKit 유리면 거리로 고정.
4. 3D 재구성: 바(직선)·상자(큐보이드)·아암(원통/키포인트) 파라메트릭 모델을 카메라 좌표계에 배치 → 규칙 엔진(橋渡し 縦ハメ/横ハメ 등)으로 조준점 산출 → AR 앵커에 오버레이.
5. 런타임: Android LiteRT 2.2(GPU/QNN), iOS Core ML(ANE). Flutter(ultralytics_yolo/flutter_litert) 또는 KMP expect/actual.

### v3 (다중뷰·기종 DB·학습형 정책)
- 2~3장 → 서버 **MapAnything(Apache)/DA3 any-view** 로 메트릭 3D 재구성 후 기종 DB(UFO CATCHER 9/10, クレナ 등 치수)로 정합.
- 성공/실패 로그로 조준 정책 학습(순위 학습), 아암 파워 추정(영상 기반).

---

## 9. 리스크와 오픈 질문
1. YOLO26 AGPL: 앱 스토어 배포 시 소스 공개 의무 vs Enterprise 비용(비공개, 커뮤니티 언급 $5,000/년은 비공식). 학습된 가중치의 AGPL 적용 범위도 공식 답변 없음.
2. 유리 반사·조명: 반사 제거 딥러닝은 실용 전 단계 → UX·증강으로 대응. 정량 실패율은 실측 필요.
3. 단안 깊이의 절대 스케일: 상자 치수 DB 구축 필요(공개 표준 치수 없음). 기종별 필드 치수 DB 도 직접 수집.
4. iOS LiDAR 는 Pro 한정 → 비Pro iPhone/저가 Android 는 RGB-only 경로가 기본이어야 함.
5. 경쟁 앱(AIクレーンゲーム軍師)의 실제 정확도·기술 스택 미확인 → 직접 사용 테스트.
6. DA3/DA-V2 의 모바일 실측치는 Qualcomm/Apple 페이지 스니펫에 의존(직접 열람 불가) → 실제 기기 벤치 필요.
7. Core AI(iOS 27) 전환기: Core ML 모델은 계속 동작한다는 스니펫이지만, 장기 지원 정책 확인 필요.
8. 데이터 수집의 법적/약관 이슈(점포 촬영, 온크레 캡처).

---

## 10. 읽은/참조한 URL 목록
- https://github.com/ultralytics/ultralytics
- https://raw.githubusercontent.com/ultralytics/ultralytics/main/README.md
- https://raw.githubusercontent.com/ultralytics/ultralytics/main/docs/en/models/yolo26.md
- https://raw.githubusercontent.com/ultralytics/ultralytics/main/docs/en/tasks/depth.md
- https://raw.githubusercontent.com/ultralytics/ultralytics/main/docs/en/integrations/litert.md
- https://raw.githubusercontent.com/ultralytics/ultralytics/main/docs/en/integrations/coreml.md
- https://raw.githubusercontent.com/ultralytics/ultralytics/main/docs/en/integrations/executorch.md
- https://github.com/ultralytics/yolo-flutter-app ; https://raw.githubusercontent.com/ultralytics/yolo-flutter-app/main/doc/performance.md
- https://github.com/orgs/ultralytics/discussions/1260 ; https://pypi.org/project/ultralytics/
- https://github.com/ultralytics/yolov5/wiki/Tips-for-Best-Training-Results
- https://github.com/roboflow/rf-detr ; https://github.com/lyuwenyu/RT-DETR ; https://github.com/Intellindust-AI-Lab/DEIMv2
- https://github.com/google-ai-edge/mediapipe ; https://raw.githubusercontent.com/google-ai-edge/mediapipe-samples/main/examples/object_detection/android/README.md ; https://raw.githubusercontent.com/google-ai-edge/mediapipe/master/docs/solutions/objectron.md
- https://github.com/facebookresearch/sam3 ; https://raw.githubusercontent.com/facebookresearch/sam3/main/LICENSE ; https://github.com/facebookresearch/sam2 ; https://github.com/ChaoningZhang/MobileSAM ; https://github.com/chongzhou96/EdgeSAM ; https://github.com/yformer/EfficientSAM
- https://github.com/DepthAnything/Depth-Anything-V2 ; https://github.com/ByteDance-Seed/Depth-Anything-3 ; https://github.com/apple/ml-depth-pro ; https://raw.githubusercontent.com/apple/ml-depth-pro/main/LICENSE ; https://github.com/lpiccinelli-eth/UniDepth ; https://github.com/YvanYin/Metric3D ; https://github.com/isl-org/ZoeDepth
- https://github.com/facebookresearch/vggt ; https://github.com/naver/mast3r ; https://github.com/facebookresearch/map-anything
- https://github.com/NVlabs/FoundationPose ; https://raw.githubusercontent.com/NVlabs/FoundationPose/main/LICENSE ; https://github.com/megapose6d/megapose6d ; https://github.com/NVlabs/CenterPose ; https://github.com/google-research-datasets/Objectron
- https://github.com/google-ai-edge/LiteRT ; https://pypi.org/project/ai-edge-litert/ ; https://github.com/google-ai-edge/litert-samples ; https://github.com/hugocornellier/flutter_litert ; https://github.com/google-ai-edge/LiteRT-LM/issues/2628
- https://github.com/pytorch/executorch ; https://pypi.org/project/executorch/ ; https://github.com/software-mansion/react-native-executorch ; https://github.com/software-mansion/react-native-executorch/releases
- https://github.com/microsoft/onnxruntime/tags ; https://github.com/Tencent/ncnn
- https://github.com/google-ar/arcore-android-sdk/releases ; https://github.com/google-ar/arcore-android-sdk/releases/tag/v1.31.0 ; https://raw.githubusercontent.com/google-ar/arcore-android-sdk/main/libraries/include/arcore_c_api.h ; https://github.com/googlesamples/arcore-depth-lab ; https://developer.android.com/develop/xr/jetpack-xr-sdk/arcore/depth
- https://developer.apple.com/videos/play/wwdc2020/10611/ ; https://developer.apple.com/forums/thread/712943
- https://raw.githubusercontent.com/google-gemini/cookbook/main/quickstarts/Spatial_understanding.ipynb
- https://github.com/cvat-ai/cvat ; https://github.com/HumanSignal/label-studio ; https://github.com/DLR-RM/BlenderProc ; https://github.com/Unity-Technologies/com.unity.perception
- (검색 스니펫만) https://play.google.com/store/apps/details?id=com.technogenesis.aiclawcoach&hl=ja ; https://apps.apple.com/jp/app/id6760863324 ; https://aihub.qualcomm.com/mobile/models/depth_anything_v2 ; https://aihub.qualcomm.com/models/depth_anything_v3 ; https://huggingface.co/apple/coreml-depth-anything-v2-small ; https://huggingface.co/depth-anything/Depth-Anything-V2-Metric-Hypersim-Small ; https://developers.google.com/ar/develop/depth ; https://universe.roboflow.com/search?q=class:claw ; https://www.sega.jp/arcade/detail/ufo-catcher-9-second/ ; https://ai.google.dev/gemini-api/docs/models/gemini-robotics-er-2-preview ; https://www.gamespark.jp/article/2026/07/08/169007.html ; https://www.infoq.com/news/2026/06/apple-core-ai-wwdc/ ; https://checkthat.ai/brands/roboflow/pricing
