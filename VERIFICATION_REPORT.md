# WP4 시뮬레이터 검증 보고서

> 작성: 2026-06-10 | 방법: ITU-R 공식 PDF 원문 대조(P.838-3 / P.618-13·14 / P.840-7·9 / P.676-10·13 / P.453-14 / P.835-5) + MathWorks 공식 문서 대조 + MATLAB R2025b 정적분석 + 함수 단위 수치 재현 + 발견사항별 적대적 재검증(refute 시도)
> 결과: **확정 7건(중복 제거) / 반박 0건 / 검증통과 항목 80+건**
> 주: 개별 함수의 수치 스팟체크(예: CalcRainCoeffs_Exact를 P.838-3 Table 5와 대조 실행)는 수행했으나, **main_v2 전체 시뮬레이션은 실행하지 않음** (실행 계획은 §6).

---

## 1. 한눈에 보는 결론

| 구분 | 판정 |
|---|---|
| **P.838-3 강우계수 (직접 제작)** | ✅ 테이블 42계수+상수 8개 전부 원문과 자릿수까지 일치, Table 5 기준값 재현 성공. 단 벡터입력 시 잠재버그 1건 |
| **P.618 강우감쇠 10-step (직접 제작)** | ⚠ Step 2~9 + Step 10 구조 모두 정확하나, **Step 10 β 3번째 분기 누락 (실결과 영향)** (✅ 2026-06-11 수정 완료 — 현 CalcRainLoss.m:135–145) + θ<5° 식 누락(잠재; 의도적 미구현으로 확정, 각주 CalcRainLoss.m:44–50) |
| **P.840-9 구름감쇠 (직접 제작)** | ✅ 전 수식·상수 원문과 일치, 273.75 K도 정답 (주석만 273.15로 오기). 독립 구현과 소수점 6자리 일치 |
| **P.676 가스감쇠 (직접 제작)** | ✅ 층적분·광선추적·굴절도·gaspl/atmosisa 단위 전부 정확. 86 GHz 천정 0.81 dB 등 스모크값 타당 |
| **P.618 신틸레이션 (직접 제작)** | ✅ 전 수식 정확. 유효경로 L만 간략식 사용(영향 ≤0.004 dB, 현 구성에서 무시 가능) |
| **위성툴박스 사용 (AI 제작)** | ✅ 전 함수 단위·인수순서·G/T 처리·이중계상 없음 실측 확인. 단 **gs0/gsO 오타로 실행 불가** (✅ 2026-06-11 수정 완료 — 현 main_v2.m:151–159) |
| **인터페이스/배선 (AI 제작)** | ✅ 단위 체인·구조체 계약·벡터 방향 전부 안전. 단 Phase-4 self-check가 부분실행 토글과 충돌 |

**핵심 메시지**: 직접 제작한 ITU 수식들은 매우 충실하게 구현됨 (β 분기 1건 제외 — ✅ 수정 완료). AI 제작 부분도 툴박스 사용은 정확하나 실행을 막는 오타 1건(✅ 수정 완료)과 토글 버그 1건(미수정) 존재. 가장 큰 **논문 차원의** 이슈는 코딩이 아니라 **모델 정합성**: ① P.618 §2.5의 freeze 규칙 위반(구름·가스를 0.1% 조건으로 입력 → E/W밴드에 불리한 비대칭 비관 편향) — ✅ 2026-06-11 GroundStations 입력 교체로 해소(§7 #3/#4/#4b), ② 73.5 GHz가 P.618 유효범위(≤55 GHz) 밖이라는 외삽 명시 필요(미반영).

---

## 2. 확정 결함 (발견 당시 기준, 우선순위순 — 현재 적용 상태는 §7 표 참조)

### P0 — 실행 차단

**[F-1] `gs0`(숫자 0) ↔ `gsO`(대문자 O) 미정의 변수 — main_v2.m:139–140** *(✅ 2026-06-11 수정 완료 — 현 main_v2.m:151–159)*
- 114행 정의는 `gsO`, 139–140행 참조는 `gs0`. 바이트 단위(U+004F vs U+0030) 및 라이브 세션 `exist('gs0')==0`으로 확인. 1행의 `clear` 때문에 구제 불가.
- 기본 설정(run_link=true)에서 **첫 (GS,밴드) 반복에서 즉시 중단** → link/energy/volume/Phase4 전부 미생성. Code Analyzer는 스크립트의 미정의 변수를 못 잡으므로 정적분석 통과.
- 수정: 139–140행 `gs0`→`gsO` (권장: 전체를 `gsObj`로 개명해 O/0 혼동 원천 제거).

### P1 — 결과를 바꾸는 모델 오류

**[F-2] P.618 Step 10 β 3번째 분기 누락 — CalcRainLoss.m:121–126** *(✅ 2026-06-11 수정 완료 — 현 CalcRainLoss.m:135–145, 아래 제안 코드 그대로 적용)*
- 원문(P.618-14 p.8, 원문 추출 검증): p≥1% 또는 |φ|≥36° → β=0 / p<1%, |φ|<36°, **θ≥25°** → β=−0.005(|φ|−36) / **그 외(θ<25°) → β=−0.005(|φ|−36)+1.8−4.25·sinθ**. 코드는 마지막 분기 누락.
- 영향: |위도|<36° 지상국(Singapore 1.35°, UAE 25.23°)의 θ<25° 구간 — **LEO 패스의 대부분** — 에서 강우감쇠 dB값을 최대 ×1.48 과소평가 (θ≈12°에서 최대; 예: 진짜 35 dB 페이드를 23.9 dB로 보고 → ~11 dB 낙관 오차). KAU(37.6°)/Stuttgart/SvalSat는 무관.
- 수정(벡터화 필요 — β가 θ 의존이 됨):
  ```matlab
  beta = zeros(size(theta));
  if target_p < 1 && abs(gs_lat) < 36
      beta(:) = -0.005*(abs(gs_lat)-36);
      lowEl = theta < 25;
      beta(lowEl) = beta(lowEl) + 1.8 - 4.25*sind(theta(lowEl));
  end
  % exponent_v의 beta*(1-target_p).*sind(theta)는 이미 element-wise라 그대로 동작
  ```

**[F-3] P.618 §2.5 freeze 규칙 위반: 구름 A_C를 0.1% 값으로 사용 — LinkBudget.m:56 + GroundStations.m** *(✅ 적용 완료 — GroundStations L_water = L(5%), §7 #3)*
- 원문: P.618-13 Eq.(61) p<1%면 A_C(p)=A_C(1%), P.618-14 Eq.(67) p<5%면 A_C(p)=A_C(5%). 이유: "p<1%에서는 구름감쇠의 상당 부분이 이미 강우감쇠 예측에 포함" → 0.1% L_water 사용은 **구름·강우 이중계상**.
- 영향: 비관(보수) 편향이되 주파수에 따라 ~f^1.8로 증가(KL: 73.5 GHz는 26 GHz의 5.7배, 8.16 GHz의 54배) → **E/W밴드에 체계적으로 불리** = 논문 비교의 공정성 훼손. Singapore 73.5 GHz에서 구름만 천정 3.5 dB / el 10°에서 ~20 dB.
- 수정: P.840 디지털 맵에서 L_water를 1%(P.618-13 인용 시) 또는 5%(P.618-14 인용 시, 권장) 초과확률로 재추출. 논문에 어느 개정판 따랐는지 명기.

**[F-4] 가스 A_G도 0.1% 조건의 ρ_surf로 계산 — LinkBudget.m:50 + GroundStations.m** *(✅ 적용 완료 — rho_surf = RHO(5%) 고도보정값으로 교체·헤더 갱신, §7 #4)*
- 검증 과정에서 로컬 P.836 맵([WP_2]\ITURDigitalMaps\p836.mat — 원본 PC 전용, 이 저장소에는 없음; 공식 P.836-6 TXT는 루트 R-REC-P.836-6-201712-I!!ZIP-E\ 참조)을 보간해 GroundStations의 rho_surf가 실제로 **P.836 0.1% 초과확률 값**임을 확인(예: Stuttgart 16.04 vs 맵 16.30; 중앙값은 6.95). 헤더 문서 그대로.
- 원문: P.618-14 §2.5 — 시간율별 데이터 없으면 **평균(mean) 가스감쇠** 사용, 있어도 p<5%는 A_G(5%)로 freeze.
- 영향: UAE el 10°에서 평균 대비 최대 ~8 dB 비관, 밴드 비대칭(Singapore el 10°: X +0.03 / Ka +0.57 / EW +1.76 dB) → 역시 E/W에 불리.
- 수정: 가스 계산에는 P.836 **연평균** ρ_surf 사용(§2.5가 승인한 fallback) + GroundStations 헤더를 필드별 초과확률 표기로 수정(강우 0.01%, 구름 1%/5%, 가스 평균).

**[F-5] Phase-4 self-check가 부분실행 토글을 깨뜨림 — main_v2.m:250–262 (현 265–281)**
- run_energy=false → 252행(현 270행) assert 즉사; run_volume=false → 259행(현 277행) 비존재 필드 참조로 즉사 (R2025b 라이브 재현 완료). 클로저 보정 루프(234행, 현 252행)만 가드되어 있음 — 명백한 누락.
- 수정: self-check (1)을 `if cfg.run_energy`, (2)를 `if cfg.run_volume`로 감싸기.

**[F-11] N_wet도 중앙값이 아닌 고초과확률 값 사용 — GroundStations.m (2026-06-10 신규 확인)** *(✅ 적용 완료 — N_wet = 연 중앙값, §7 #4b)*
- P.618-14 §2.4.1(인쇄본 p.19): 신틸레이션의 N_wet은 **"the median value of the wet term of the surface refractivity exceeded for the average year"** — P.453 디지털 맵의 **연 중앙값(50%)**을 요구.
- 로컬 ITURDigitalMaps(p453.NWET_Annual_50, P.453 08/2019 — 원본 PC 전용; 이 저장소에는 공식 P.453-14 TXT가 루트 R-REC-P.453-14-201908-I!!ZIP-E\에 있음) 보간 결과 중앙값은 45.4/47.5/132.0/88.1/19.3 (Stuttgart/KAU/Singapore/UAE/SvalSat)인데, 당시 하드코딩값은 101.3/143.1/156.4/172.7/48.7 — **중앙값의 2~3.5배** (0.1%급 추출로 추정; 현재 코드는 중앙값으로 교체 완료, 구값은 주석 보존).
- 영향: σ_ref = 3.6e-3 + 1e-4·N_wet ∝ 신틸레이션 페이드 → 약 1.2~2.9배 과대(UAE 최대). 비관 편향이며 저앙각 margin_min에 직접 작용.
- 수정: N_wet을 §9의 중앙값으로 교체.

### P2 — 잠재 버그 (현 구성에선 미발현, 방치 시 위험)

**[F-6] CalcRainCoeffs_Exact.m:81 — 벡터 θ 입력 시 mrdivide(`/`)가 최소제곱 스칼라를 무경고 반환**
- 실측: `CalcRainCoeffs_Exact(73.5,[10 40],0)` → α가 스칼라 0.72435 (정답 [0.72546, 0.72324]); 열벡터면 2×2 행렬 반환. 현재 호출자(CalcRainLoss 스칼라 루프)는 안전 — 잠재 버그.
- 수정: 81행 `/(2*k)` → `./(2.*k)` (또는 `arguments` 블록으로 스칼라 강제).

**[F-7] CalcRainLoss Step 2 — θ<5° 전용식 Eq.(2) 누락 (Re=8500 km)**
- 현 elev_mask 5°라 미발현. 마스크를 낮추면 θ=1°에서 Ls ×1.56 과대. 수정 코드는 보고서 원문 finding 참조.

**[F-8] CalcCloudLoss — 벡터 freq 입력 시 `^`(mpower) 런타임 에러; el>0.1° 마스크가 5° 미만 비물리값 허용(el 0.2°에서 888 dB)**
- 수정: `.^` 통일 + 마스크 5°(또는 sin(5°) 클램프), 미만 구간은 0 대신 NaN+warning.

**[F-9] CalcScintillation — L=h_L/sinθ 간략식 (원문 Eq.43: L=2h_L/(√(sin²θ+2.35e-4)+sinθ)); 마스크 4°(원문 §2.4.1은 θ≥5°)**
- 현 구성 오차 ≤0.004 dB로 무시 가능하나 논문이 인용할 표준식과 다름. 1줄 수정 권장.

**[F-10] CalcRainLoss.m:74–76 (현 81–90 주석 블록) — 함수 내부 디버그 figure 15개/런 생성** (cfg.show_plots 무시, plot 제목의 전제 "γ_R은 앙각 무관"도 τ=45°에서만 참) *(✅ 2026-06-11 비활성화 완료)*
- 수정: 3줄 삭제 또는 debug 플래그 가드.

---

## 3. 오해 방지: "버그처럼 보이지만 정답"으로 판명된 것들

| 항목 | 판정 |
|---|---|
| `CalcCloudLoss` T_kelvin=**273.75** | ✅ **정답.** P.840-9 Eq.(14)가 273.75 K 명시(원문에 '273.75' 3회, '273.15' 0회). 273.15는 폐기된 P.840-7 방식. **주석을 코드에 맞춰 고치고 "273.15로 '수정'하지 말 것" 경고 주석 추가할 것** |
| Gaussian 보정계수 7개 (A1=0.1522 등) | ✅ P.840-9 Eq.(14) 원문과 전부 일치 — 외부 첨가물 아님 |
| `gaspl`에 건조기압(P−e) 전달 | ✅ 정답. MathWorks 문서 원문 "Dry air pressure in Pa" — 총기압 아님. (T °C, ρ g/m³, range 1000 m → dB/km도 전부 정확) |
| ISA(atmosisa) ≈ P.835 | ✅ P.835-5 §1.1이 USSA-1976 기반 명시, 7층 감률·지상값 동일 |
| `receiver` G/T 속성 vs 안테나 이중계상 | ✅ 없음. ebno는 G/T 속성을 직접 사용(+7 dB → 정확히 +7.0000 dB), 부착 안테나는 무시(2.8e-14 dB) — R2025b 실측 |
| ebno에 대기손실 포함? | ✅ 미포함(FSPL 전용, 문서+1e-4 dB 수동재현 일치) → LinkBudget의 L_atm 차감은 정확히 1회 계상 |
| RequiredEbNo 속성 + 수동 차감 | ✅ 이중계상 아님(ebno 식에 해당 항 없음; linkStatus 전용 속성, 미호출) — 속성은 사실상 데드 |
| transmitter Power=dBW, BitRate=Mbps | ✅ 문서 확인. 3 dBW≈2 W 의도 일치, Rb_Mbps 직접 전달 정확 |
| D_tx 역산식 | ✅ gaussianAntenna 이득식의 정확한 역함수 — X밴드 0.0714 m → 정확히 13.5000 dBi 재현 |
| accessIntervals Duration | ✅ double 초(문서) → main의 %6.0f 출력, DailyVolume 합산 안전 |
| aer/satellite/groundStation 인수·단위 | ✅ 전부 문서와 일치 (a는 m, 각도 deg, el deg, range m; 관측자=1번째 인수) |
| ebno와 aer 시간축 정렬 | ✅ isequal 실측 참; ebno는 el<MinElevationAngle에서 −Inf인데 mask=5°=MinElevationAngle이라 −Inf 미유입 (두 값이 갈라지면 위험 — 가드 권장) |
| 단위 체인 (Hz→GHz, m→km, avail→p%) | ✅ 전 경계 일치; 벡터 방향도 열벡터로 전 구간 안전(암묵 확장 폭발 불가) |
| EnergyModel / DailyVolume 산식 | ✅ J/bit=W/bps, GB 환산, 0-패스 가드 모두 정확 |

P.838-3 강우계수는 **Table 5 공표값을 f=1~1000 GHz 8개 지점에서 전 자릿수 재현**했고, P.840-9는 독립 구현과 6자리 일치 — 직접 제작 코드의 충실도가 정량적으로 입증됨.

---

## 4. 논문(paper-grade) 캐비앗 — 코드 수정이 아닌 서술 필요

1. **73.5 GHz는 P.618 유효범위 밖**: 강우법(§2.2.1.1) "frequencies up to 55 GHz", 신틸레이션(§2.4.1) "4 ≤ f ≤ 55 GHz". E/W 결과는 ITU 공인 외삽임을 명시 (γ_R 자체는 P.838-3이 1–1000 GHz 커버라 문제없음; r₀.₀₁/v₀.₀₁/Step10/σ_ref 회귀식이 미검증 영역). X 8.16은 완전 유효, Ka 26은 P.618-14 기준 유효(P.618-13 기준으론 외삽 — **P.618-14 인용 권장**).
2. **τ=45° (원형편파) 전 밴드 고정**: E-band EIVE가 선형편파면 τ=0/90이 정확. 영향은 E-band ±2.2%, X/Ka ±9–10% — 가정 명시 필요.
3. **하늘잡음 증가 미모델링**: P.618 §3 — 감쇠 시 T_sky→~275 K. 0.1% 조건에서 X/Ka G/T가 1–3 dB 추가 침식 가능. 모델링하거나 보수성 캐비앗으로 서술.
4. **Tsys_K(피더 포함)와 Lrx 1 dB의 기준면 중복 가능성**: EW Tsys=400 K 주석이 피더 포함을 명시 → 같은 피더가 Lrx로도 1 dB 차감되면 ~1 dB 이중계상(비관). 밴드별 기준면 1개로 통일.
5. **350 km/98°는 SSO 아님**: SSO는 96.85°(98°는 ~650 km용). 주석 또는 요소값 수정.
6. reqEbNo 3밴드가 서로 다른 BER/FEC 기준(이미 BandParameters 주석에 있음) — 각주 유지.
7. P.618 §2.5 결합식 자체의 rms 오차 ~33%(ITU 자체 기술) — 민감도 분석 시 참고.
8. 기대 sanity: **EW@Singapore 0.1%는 강우만 ~100 dB+ → closure=0이 정상**. 시뮬레이터가 한 자릿수 dB를 찍으면 상류가 고장난 것.

## 5. 정리성 항목 (P3–P4)

- 데드 코드/필드: `cfg.req_EbNo_dB`(미사용 — band.reqEbNo_dB가 실사용), `cfg.show_plots`(읽는 곳 없음), `gs.id`/`pass_start`/`pass_stop`/`band.name`, DailyVolume의 `gs` 인수, CalcRainLoss 71–73행(현 78–80행) transpose 데드코드, "rainpl 사용" 낡은 주석
- 김벌/송수신기가 밴드 루프 안에서 생성 → 5GS×3밴드=15세트 누적 (정확도 무관, 성능·관리 문제) → GS 루프 상단으로 호이스트
- `MinElevationAngle`은 R2025a부터 비권장 → `MaskElevationAngle` 전환
- `datestr(now)` → `string(datetime('now'),'yyyyMMdd_HHmmss')`
- CalcZenithGasLoss: 이름·헤더 불일치(실제는 경사경로; max_height/step_size/layer_data는 존재하지 않는 입출력), `P_dry_hPa` 변수가 65행 이후 Pa 보유(이름만 위험), 지위고도/기하고도 변환(<0.01 dB), P.835 혼합비 하한(<0.01 dB), 음수 앙각 무가드, 905층 vs 922층(무영향) — 전부 무해 확인됨, 주석 정비 권장
- main_v2.m:73(현 79행) 'Groud Stations()' 오타, 193행(현 211행) 주석 필드명 불일치
- 신틸레이션/강우/구름의 자체 앙각 하한(4°/0.1°/0.1°)이 main 마스크 5°에 기생 — LinkBudget에 `assert(min(el_vis)>=5)` 권장

## 6. 실행·디버깅 계획 (보고용 — 아직 미실행)

**전제**: F-1(gs0) 수정 없이는 어떤 실행도 불가. *(✅ F-1은 2026-06-11 수정 완료 — 전제 충족, 현재 실행 가능)* F-2~F-5 수정 여부에 따라 결과가 달라지므로 "수정 전 1회 실행(베이스라인) → 수정 후 재실행(차이 정량화)" 순서가 논문 기록용으로 유리.

1. **스모크 런** (수 분): `sim_duration_days=1`, `sample_time_s=10`, `gs_selection={'Stuttgart'}`, 밴드 {'X'}로 축소 → Phase 1→4 전 구간 통과 확인. MATLAB Desktop이 떠 있으므로 MCP `run_matlab_file`로 실행하고 각 Phase fprintf를 체크포인트로 사용.
2. **함수 단위 회귀 셀프테스트 스크립트** (`test_itu_functions.m` 신규): P.838-3 Table 5 재현(이미 검증된 8개 주파수), P.840-9 KL 기준값(73.5 GHz → 3.1019), CalcZenithGasLoss 스모크값(86 GHz 천정 0.81 dB), β 수정 전후 Singapore θ=10° 비율(×1.466) — 수정이 들어갈 때마다 자동 검증.
3. **성능 측정**: CalcZenithGasLoss는 905층×가시샘플 수. 7일/3 s → 가시샘플 수천 개/GS → 분 단위 예상(측정치 0.18 s/4앙각 기준 외삽 시 GS·밴드당 1–2분). 느리면 앙각 0.1° 그리드 사전계산+interp1로 ~100배 단축 가능 (밴드별 γ층 캐시는 이미 올바르게 1회 계산됨).
4. **본 실행** (7일×3 s×5GS×3밴드): 단계별 토글로 Phase 2까지 먼저 → margin/closure 합리성 확인 후 3a/3b/4.
5. **Sanity 체크리스트**: EW@Singapore closure=0 (강우 ~100 dB+) / X@SvalSat 마진 최대 / J/bit = 43.6/22.9/12.0 nJ 정확 재현 / D_day가 Rb에 선형 / 패스당 평균 접촉시간 ~수백 초(350 km LEO) / Stuttgart 결과를 WP2 검증 베이스라인과 대조.
6. **디버깅 도구**: 구간별 `dbstop if error`, LinkBudget에 el-vs-L_atm 프로파일 덤프 옵션, 수정 전후 results.mat diff 스크립트.

## 7. 우선순위 TODO 요약

| # | 항목 | 파일:행 | 심각도 | 상태 |
|---|---|---|---|---|
| 1 | `gs0`→`gsO` | main_v2.m:139–140 (현 151–159) | **P0 실행차단** | ✅ **적용 완료** (2026-06-11, 각주 포함; 코드 내 gs0 잔존 0건 확인) |
| 2 | β 3번째 분기(θ<25°) 추가+벡터화 | CalcRainLoss.m:121–126 (현 135–145) | **P1 결과오류** | ✅ **적용 완료** (2026-06-11, 이론비 4자리 일치 검증) |
| 3 | L_water → P.840-9 공식 product의 **5%** 값으로 재추출 | GroundStations.m | **P1 모델정합** | ✅ **적용 완료** (공식 TXT L(5%) 추출·교체) |
| 4 | rho_surf → **5% 동결값**(권장, Eq.68) 또는 50% 평균 | GroundStations.m | **P1 모델정합** | ✅ **적용 완료** (공식 고도보정 5% 값) |
| 4b | N_wet → **연 중앙값(50%)** (§2.4.1, F-11 신규) | GroundStations.m | **P1 모델정합** | ✅ **적용 완료** |
| 5 | self-check 토글 가드 | main_v2.m:250–262 (현 265–281; energy assert 270행, volume 참조 277행) | **P1 토글버그** | 미수정 |
| 6 | `./(2.*k)` | CalcRainCoeffs_Exact.m:81 | P2 잠재 | 미수정 |
| 7 | θ<5° Ls Eq.(2) | CalcRainLoss.m:44 (현 51; 설계결정 각주 44–50) | P2 잠재 | 📝 각주만 추가(설계 결정: GS 최소앙각 5° — 2026-06-11) |
| 8 | 디버그 figure 제거 | CalcRainLoss.m:74–76 (현 81–90) | P2 위생 | ✅ **적용 완료** (2026-06-11, 주석 보존+각주; figure 0개·수치 불변 검증) |
| 9 | `.^` 벡터화+el 마스크 5° | CalcCloudLoss.m | P2 잠재 | 미수정 |
| 10 | L=Eq.(43)+마스크 5° | CalcScintillation.m:25,40 | P2 표준정합 | 미수정 |
| 11 | 273.75 K 주석 정정(+경고) | CalcCloudLoss.m:40–45 | P2 문서 | 미수정 |
| 12 | 55 GHz 외삽 캐비앗·τ=45·하늘잡음·Tsys/Lrx 기준면·SSO 96.85° | 논문+주석 | P3 논문 | 미반영 |
| 13 | 데드필드·datestr·김벌 호이스트·MaskElevationAngle 등 | 다수 | P4 정리 | 미수정 |

## 부록 A. ITU 원문 인용 (논문·회의 근거용)

> 출처 PDF: R-REC-P.618-14-202308-I!!PDF-E.pdf / R-REC-P.618-13-201712-S!!PDF-E.pdf (itu.int 공식). ITU 문서에는 줄번호가 없으므로 "인쇄본 쪽수 + Step/식 번호"로 인용 (PDF 뷰어 쪽수 병기).

**A-1. 주파수 유효범위 — P.618-14 인쇄본 p.6 (PDF 8쪽), §2.2.1.1 첫 문장**
> "The following procedure provides estimates of the long-term statistics of the slant-path rain attenuation at a given location **for frequencies up to 55 GHz**." — 73.5 GHz 적용은 공인 범위 밖 외삽. 같은 페이지 파라미터 목록에 "Re : effective radius of the Earth (**8 500 km**)".

**A-2. Step 2 경사경로 — P.618-14 인쇄본 p.7 (PDF 9쪽), Eq.(1)/(2)**
> "Step 2: **For θ ≥ 5°** compute the slant-path length, Ls, below the rain height from: Ls = (hR − hs)/sin θ km (1)
> **For θ < 5°, the following equation is used**: Ls = 2(hR − hs) / [ (sin²θ + 2(hR − hs)/Re)^½ + sin θ ] km (2)"
→ 코드(CalcRainLoss.m:44, 현 51행)는 el>0.1° 전 구간에 Eq.(1)만 적용 — Eq.(2) 부재 (의도적 미구현으로 확정·각주화, §7 #7).

**A-3. Step 10 확률 스케일링 β — P.618-14 인쇄본 p.8 (PDF 10쪽)**
> "Step 10: The estimated attenuation to be exceeded for other percentages of an average year, **in the range 0.001% to 5%**, is determined from the attenuation to be exceeded for 0.01% for an average year:
> If p ≥ 1% or |φ| ≥ 36°: β = 0
> If p < 1% and |φ| < 36° and θ ≥ 25°: β = −0.005(|φ| − 36)
> **Otherwise: β = −0.005(|φ| − 36) + 1.8 − 4.25 sin θ**
> A_p = A₀.₀₁ (p/0.01)^−(0.655 + 0.033 ln(p) − 0.045 ln(A₀.₀₁) − β(1−p) sin θ) dB (8)"
→ 코드(CalcRainLoss.m:122–126)는 첫 두 분기만 구현, 두 번째 분기의 "θ ≥ 25°" 조건 자체가 없어 θ<25°에도 두 번째 식을 적용. "Otherwise" 분기 부재. *(검증 당시 기준 — ✅ 2026-06-11 수정 완료, 현 CalcRainLoss.m:135–145에 3분기 전부 구현)*

**A-4. 총감쇠 결합 + freeze 규칙 — P.618-14 인쇄본 p.23 (PDF 25쪽), §2.5**
> "A_T(p) = A_G(p) + √[(A_R(p) + A_C(p))² + A_S²(p)], 0.001% ≤ p ≤ 5% (65)
> where: **A_C(p) = A_C(5%) (dB) for p < 5.0% (67)**; **A_G(p) = A_G(5%) (dB) for p < 5.0% (68)**"
> "Gaseous attenuation as a function of percentage of time can be calculated using § 2.2 of Annex 2 of Recommendation ITU-R P.676 **if local meteorological data at the required time percentage are available. In the absence of local data at the required time percentage, the mean gaseous attenuation should be calculated** and used in equations (65) and (66)."

**A-5. freeze 규칙의 근거 문장 — P.618-13 인쇄본 p.22 (PDF 24쪽), §2.5** *(주의: -13 전용)*
> "A_C(p) = A_C(1%) for p < 1.0% (61); A_G(p) = A_G(1%) for p < 1.0% (62)
> **Equations (61) and (62) take account of the fact that a large part of the cloud attenuation and gaseous attenuation is already included in the rain attenuation prediction for time percentages below 1%.**"
→ 이중계상 방지라는 설계 의도를 설명하는 문장. **단, P.618-14 전문 검색 결과 이 문장("already included...")은 -14에서 삭제됨** — -14에서는 Eq.(67)/(68) 규칙 자체가 규범이며 동결 기준이 1%→5%로 오히려 강화됨. 논문에서 이 '의도 설명'을 인용하려면 출처를 P.618-13 §2.5로 명기할 것 (규칙 인용은 -14 Eq.67/68).

**A-6. 가스-강우 상관의 -14 내 근거 — P.618-14 인쇄본 p.6 (PDF 8쪽), §2.1**
> "At a given frequency the oxygen contribution to atmospheric absorption is relatively constant. However, both water vapour density and its vertical profile are quite variable. **Typically, the maximum gaseous attenuation occurs during the season of maximum rainfall** (see Recommendation ITU-R P.836)."
→ 가스감쇠 최대치가 최대 강우 시기와 겹친다는 -14 자체의 서술 — 가스를 0.1% 최악값으로 별도 입력하면 강우항과 같은 기상조건을 이중 반영하게 되는 물리적 근거.

**A-7. (확정) 프로젝트 참조판 = P.618-14 — F-3/F-4 적용 기준**
2026-06-10 사용자 확인: 본 프로젝트의 참조 문서는 R-REC-P.618-14-202308. 따라서 freeze 적용은 **5% 기준**: L_water → P.840 맵의 5% 초과확률 값, 가스 → A_G(5%) 동결 또는 (시간율별 데이터 부재 시) **평균** 가스감쇠 (A-4 원문). 강우 A_R(p)와 신틸레이션 A_S(p)는 동결 대상이 아님 — §2.5가 "A_R(p): as estimated by Ap in equation (8)" / "A_S(p): as estimated by equation (49)"로 p 의존을 명시.

**A-8. N_wet은 연 중앙값 — P.618-14 인쇄본 p.19 (PDF 21쪽), §2.4.1**
> "If **the median value of the wet term of the surface refractivity exceeded for the average year, N_wet**, is obtained from the digital maps in Recommendation ITU-R P.453, go directly to Step 3."
→ 신틸레이션용 N_wet은 50% (중앙값). 고초과확률 값 사용 금지의 직접 근거 (F-11).

## 9. P.618-14 정합 재추출 값 — 최종 확정 (2026-06-11, 공식 ITU TXT product)

**소스 및 방법**: ITU 공식 디지털 product TXT (P.840-9 Part01 / P.836-6 annual / P.453-14 NWET annual / P.837-8(2025-09) / P.839-4) — 원본 PC 경로는 `[WP_2]\ITU_Doc\`; **이 저장소에서는 루트의 `R-REC-P.840Part01-0-202308-I!!ZIP-E` / `R-REC-P.836-6-201712-I!!ZIP-E` / `R-REC-P.453-14-201908-I!!ZIP-E` / `R-REC-P.837-8-202509-I!!ZIP-E` / `R-REC-P.839-4-201309-I!!ZIP-E` 폴더** (공식 추출 스크립트 `find_L_value.m`·`GetSurfaceVaporDensity.m`·`find_N_wet_value.m`·`get_R001_value.m`·`get_h0_value.m`도 각 product 폴더 내부에 포함; '_v2' 확장 스크립트와 ITU_percentile_candidates.mat은 원본 PC 전용) + 동일한 bilinear 보간 규약. 이 저장소에서의 재추출은 루트의 `ExtractITUPercentileInputs.m` 사용 (앵커값 기계 정밀도 재현 검증, 2026-06-11).

**출처 확정**: 하드코딩된 GroundStations 값 5필드 × 5국 = 25개 전부가 공식 TXT의 **0.1% 파일(`*_01`) 보간값과 소수점 4자리까지 완전 일치** (L 0.6278/0.6597/1.1121/0.6413/0.1701 등). → WP2 추출 파이프라인의 정밀성은 입증됐고, 문제는 오직 "모든 필드를 0.1%로 뽑은 것".

| 필드 (요구 통계) | Stuttgart | KAU | Singapore | UAE | SvalSat | 조치 |
|---|---|---|---|---|---|---|
| R_001 [mm/h] (0.01%, P.837-8에서도 동일 확인) | 29.7784 | 60.5478 | 100.0675 | 20.4915 | 9.3946 | **유지** |
| h_rain [m] (P.839-4 h0+0.36 km) | 3028.1 | 3897.6 | 4972.3 | 4620.5 | 1914.7 | **유지** |
| **L_water [kg/m²] ← L(5%)** (Eq.67) | **0.2801** | **0.2068** | **0.3514** | **0.2011** | **0.0394** | 교체 (현재의 0.1%값 대비 ~1/2~1/4) |
| (참고) L(1%) — P.618-13 경로 시 | 0.4497 | 0.4078 | 0.6587 | 0.3928 | 0.0885 | 대안 |
| **rho_surf [g/m³] ← RHO(5%)** (Eq.68; 본 행은 순수 bilinear **참고값**) | 12.3758 | 20.0830 | 22.2136 | 24.7600 | 5.4433 | 교체 — **실제 적용값은 공식 고도보정 포함 12.6689 / 21.0049 / 22.1651 / 25.3561 / 5.1977** (주① 참조) |
| (참고) RHO(50%) — mean fallback 경로 시 | 6.7307 | 7.5963 | 20.5414 | 15.5834 | 2.6542 | 대안 |
| **N_wet [N-unit] ← NWET(50%)** (§2.4.1 중앙값) | **45.3936** | **47.5024** | **131.9951** | **88.1356** | **19.2665** | 교체 |

주: ① rho의 **최종 적용값은 P.836-6 공식 고도보정(VSCH 지수 스케일링 + TOPO_0DOT5 노드고도 bicubic 보간) 포함 5% 값**(12.6689/21.0049/22.1651/25.3561/5.1977 — GroundStations.m·availability_input_candidates.csv와 일치, §7 #4)으로 확정됨. 본 표의 순수 bilinear 값은 참고용이며 적용값과 최대 약 ±4.6% 차이(KAU +4.6%, SvalSat −4.5%). ② 로컬 p840.mat(MathWorks, 원본 PC 전용 — 이 저장소에는 없음)은 P.840-8 L_red라 정의가 달라 사용 금지 — 본 표의 L은 P.840-9 공식 product 직접 추출값.

## 8. 검증 출처 (대표)

- ITU-R 공식 PDF (itu.int에서 직접 취득·텍스트 추출): P.838-3, P.618-14(08/2023), P.618-13, P.840-9(08/2023), P.840-7, P.676-10, P.453-14, P.835-5
- MathWorks 공식 문서: gaspl, atmosisa, satelliteScenario, satellite, groundStation, aer, access/accessIntervals, gimbal/pointAt, transmitter, receiver, gaussianAntenna, link/ebno/linkStatus, physconst
- MATLAB R2025b 라이브 검증(MCP, 읽기 전용 수치 실험): ebno 식 1e-4 dB 재현, G/T 직접사용 실측, Table 5 재현, P.836/P.840 맵 보간 대조, 함수 단위 스모크 테스트
- 교차 검증: ITU-Rpy 레퍼런스 구현, 독립 Python 재계산
