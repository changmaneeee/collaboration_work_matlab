# WP4 Multi-band Downlink Simulator — 코드 문서

> 대상: `main_v2.m` 및 지원 함수 10개 (MATLAB R2025b)
> 목적: E/W-band 위성 다운링크를 X / Ka 밴드와 정량 비교 (논문용 시뮬레이션)
> 작성: 2026-06-10 (Claude Code 검증 세션) — 검증 결과/TODO는 `VERIFICATION_REPORT.md` 참조

---

## 1. 시뮬레이션 개요

350 km VLEO 원형궤도(경사각 98°) 위성이 전 지구 5개 지상국으로 데이터를 내리는 시나리오를 7일간 전파(propagation)하고, 밴드별(X 8.16 GHz / Ka 26 GHz / E-W 73.5 GHz)로 다음 3개 지표를 산출한다:

| 지표 | 산출 모듈 | 축 |
|---|---|---|
| 링크 마진 / 클로저 여부 | `LinkBudget` (+ Calc* 4종 ITU 손실 모델) | 밴드 × 지상국 |
| 에너지 효율 (J/bit) | `EnergyModel` | 밴드 |
| 일일 데이터 볼륨 (GB/day) | `DailyVolume` | 밴드 × 지상국 |

핵심 비교 논리: **기하(가시성)는 밴드 무관** → 지상국별로 1회만 계산하고, **RF/감쇠는 밴드 의존** → 내부 루프에서 밴드별 계산. 최종적으로 Phase 4에서 `유효 볼륨 = 기하학적 볼륨 × closure_flag`로 게이팅.

## 2. 실행 흐름 (main_v2.m)

```
Phase 1  입력층        BandParameters() / GroundStations() 로드, 선택 검증
Phase 2  궤도+RF       satelliteScenario → satellite(케플러 6요소)
                        ├─ GS 루프: groundStation → aer() → access/accessIntervals  [밴드 무관]
                        └─ 밴드 루프: gimbal/pointAt → transmitter/gaussianAntenna
                                      → receiver(G/T) → link → ebno()  [FSPL 기준 Eb/No]
                                      → LinkBudget(밴드, GS, 기하, cfg)
Phase 3a 에너지        EnergyModel(밴드)            → J/bit (지상국 무관)
Phase 3b 볼륨          DailyVolume(밴드, GS, 기하)  → GB/day (기하학적 상한)
Phase 4  결과 조립     closure 게이팅, 구조 불변량 self-check, 저장(옵션)
```

### 주요 설정 (cfg)

| 필드 | 값 | 의미 |
|---|---|---|
| `bands_selected` | {'X','Ka','EW'} | 비교 밴드 (논문 질문의 축) |
| `avail` | 0.999 | 링크 가용도 → ITU 초과확률 p = 0.1% |
| `kepler.*` | 350 km / e=0 / i=98° | 미션 기준궤도 (고정) |
| `sample_time_s` / `sim_duration_days` | 3 s / 7일 | 시나리오 샘플링/기간 |
| `rx_dish_m` / `rx_eff` | 1.2 m / 0.6 | 공통 지상국 안테나 (G/T는 밴드별 주파수에서 유도) |
| `elev_mask_deg` | 5° | 가시성 최소 앙각 |
| `req_EbNo_dB` | 10 | ⚠ 현재 미사용 (실제로는 band.reqEbNo_dB 사용) |
| `run_link/energy/volume` | true | 단계별 토글 |

## 3. 파일별 명세

### 3.1 입력층 (AI 보조 제작)

**`BandParameters.m`** — 밴드별 스펙 struct (X: Saito 2016 / Ka: Kepler v1.1 / EW: Kallfass 2024·Schoch 2018).
핵심 규약: **`Ptx_DC_W`(DC 전력 → EnergyModel)와 `Ptx_RF_dBW`(RF 전력 → 링크버짓 EIRP)를 절대 혼용 금지.**
`reqEbNo_dB`는 밴드별 BER/FEC 기준이 서로 달라(64APSK Es/No vs DVB-S2 QEF vs uncoded QPSK) 엄밀한 동일조건 비교가 아님 → 논문 각주 필요.

| 필드 | 단위 | X | Ka | EW |
|---|---|---|---|---|
| freq_Hz | Hz | 8.16e9 | 26.0e9 | 73.5e9 |
| Ptx_DC_W | W | 22 | 40 | 60 |
| Ptx_RF_dBW | dBW | 3.0 | 3.0 | 3.0 |
| Gtx_dBi | dBi | 13.5 | 24.0 | 33.0 |
| Rb_Mbps | Mbps | 505 | 1750 | 5000 |
| reqEbNo_dB | dB | 12.7 | 7.0 | 7.0 |
| Tsys_K | K | 150 | 200 | 400 |

**`GroundStations.m`** — 지상국 5개소 struct-of-structs. 각 국소별 ITU-R 파라미터는 0.1% 초과확률(99.9% 가용도) 조건으로 디지털 맵에서 추출된 값을 하드코딩:
`rho_surf`(P.836, g/m³) / `h_rain_limit_m`(P.839, m) / `R_001`(P.837, mm/h) / `L_water`(P.840, kg/m²) / `N_wet`(P.453, N-unit).
Stuttgart(검증 기준), KAU(미션 기준), Singapore(열대 최악 강우), UAE(건조·고수증기), SvalSat(극지 최선).
`pass_start/stop`은 WP2 유산 — 현재 시뮬레이터에서 미사용.

### 3.2 ITU 손실 모델 (직접 제작, Calc*)

**`CalcZenithGasLoss.m`** — ITU-R P.676 Annex 1 층적분 + 광선추적 (이름과 달리 천정이 아닌 **임의 앙각 경사경로**).
- 층 두께 δᵢ = 0.0001·e^((i−1)/100) km, 905층 (~84.75 km, `atmosisa` 한계로 절단)
- 층별 T/P: `atmosisa`(ISA) → 수증기밀도 ρ(h) = ρ_surf·e^(−Δh/2000) (P.836)
- 수증기압 e = ρT/216.7, 굴절도 N = 77.6·p_d/T + 72·e/T + 3.75e5·e/T² (P.453)
- 층별 비감쇠 γ: `gaspl(1000, f, T_C, P_dry_Pa, ρ)` → dB/km
- 경로: P.676-10 Eq.17(굴절 경로장 aₙ) → Eq.18(출사각) → Eq.19(구면 Snell) → Eq.20(누적)
- 입력: freq [Hz], gs_alt [m], el_deg_array [deg], rho_surf [g/m³] / 출력: total_loss_dB [dB] (앙각별 벡터)

**`CalcRainCoeffs_Exact.m`** — ITU-R P.838-3 Table 1–4 + Eq.(2)–(5) 1:1 구현.
- 입력: f [**GHz**], theta(앙각) [deg], tau(편파 틸트, 45°=원형) [deg] / 출력: k, α (비감쇠계수 γ_R = k·R^α 용)

**`CalcRainLoss.m`** — ITU-R P.618 §2.2.1.1 강우감쇠 10-step.
- Step 2 경사경로 Ls = (h_R−h_s)/sinθ → Step 6 수평축소 r₀.₀₁ → Step 7 수직조정 v₀.₀₁ (ζ/χ 분기) → Step 9 A₀.₀₁ = γ_R·L_E → Step 10 확률 스케일링 Ap
- 입력: freq [Hz], R001 [mm/h], el_deg [deg], h_rain_limit [m], gs_alt [m], gs_lat [deg], target_avail [**%**, 예 99.9]
- 출력: L_rain [dB], rain_slant_path [m]

**`CalcCloudLoss.m`** — ITU-R P.840-9 §3.2 통계적 구름감쇠.
- 이중 Debye 유전모델로 Kl(f, **273.75 K**) 계산 → Eq.(14) Gaussian 보정계수 → A = Kl·L/sinθ
  (주의: 코드의 273.75 K가 P.840-9 원문과 일치하는 정답. 273.15 K는 폐기된 P.840-7 방식 — 코드 내 주석이 273.15로 잘못 적혀 있으니 "수정"하지 말 것)
- 입력: freq [Hz], el_deg [deg], L_content [kg/m²] / 출력: L_cloud [dB], KL_val [(dB/km)/(g/m³)]

**`CalcScintillation.m`** — ITU-R P.618 §2.4.1 진폭 신틸레이션.
- σ_ref = 3.6e-3 + 1e-4·N_wet → 유효경로 L(h_L=1 km) → 안테나 평균화 g(x) → σ = σ_ref·f^(7/12)·g(x)/sin^1.2θ → 페이드 깊이 A = a(p)·σ
- 입력: freq [Hz], el_deg [deg], D [m], eta [0–1], N_wet [N-unit], p [%, 0.01<p≤50] / 출력: L_scint [dB]
- 앙각 4° 미만은 모델 범위 밖 → 0 dB 반환 (main의 5° 마스크가 실질 방어)

### 3.3 통합/지표 모듈 (AI 보조 제작)

**`LinkBudget.m`** — 한 (밴드, 지상국) 쌍의 링크 클로저 판정.
- 가시 샘플만 슬라이스 → 4개 손실 호출 → 합성: **L_atm = L_gas + √((L_rain+L_cloud)² + L_scint²) + L_pol** (P.618 §2.5 결합식)
- margin = ebno_fspl(가시) − L_atm − reqEbNo / closure = (min margin ≥ 0)
- 확률 규약: 강우에 `avail_pct`(99.9), 신틸레이션에 `p_pct`(0.1) — 서로 보완 관계

**`EnergyModel.m`** — J/bit = P_DC/R_b (term-2만; term-1 SAR 관측전력은 밴드 간 상쇄되어 NaN으로 보류). 22 W/505 Mbps ≈ 43.6 → 40/1750 ≈ 22.9 → 60/5000 = 12.0 nJ/bit.

**`DailyVolume.m`** — 기하학적 상한 볼륨 = (일일 접촉시간 × R_b)/8/1e9 GB. 클로저 게이팅은 의도적으로 Phase 4로 분리(모듈 디커플링).

## 4. 인터페이스 계약 (단위 규약)

| 경계 | 전달값 | 단위 변환 |
|---|---|---|
| main → satellite() | a = R_earth + alt | **m**, 각도 deg |
| main → transmitter | Power **dBW** / BitRate **Mbps** / SystemLoss dB | BandParameters와 일치 |
| main → receiver | G/T **dB/K** = Grx − 10log₁₀(Tsys) | Grx는 cfg 접시·효율에서 유도 |
| aer() → geo | el [deg], range [**m**] | 그대로 저장 |
| LinkBudget → CalcZenithGasLoss | freq Hz, alt m, el deg, ρ g/m³ | 내부에서 gaspl에 Pa/°C 변환 |
| LinkBudget → CalcRainLoss | freq **Hz**(내부 /1e9), avail **%**(99.9) | p = 100 − avail |
| LinkBudget → CalcScintillation | p_pct = (1−avail)×100 = **0.1%** | 강우와 달리 초과확률 직접 전달 |
| LinkBudget → CalcCloudLoss | L_water kg/m² (≡ mm) | Kl·L/sinθ 차원 일치 |
| DailyVolume ← geo | intervals.Duration [s] | isduration() 가드 후 합산 |

## 5. 알려진 검증 결과 / 이슈 / TODO

상세는 **`VERIFICATION_REPORT.md`** (ITU 원문 + MathWorks 공식문서 대조, 2026-06-10 검증) 참조. 요약:

- **P0 (실행차단)**: main_v2.m:139–140 `gs0`(숫자0) ↔ `gsO`(대문자O) 오타 → 실행 즉시 중단
- **P1 (결과오류)**: CalcRainLoss β 3번째 분기(θ<25°) 누락 — Singapore/UAE 저앙각 강우감쇠 최대 ×1.48 과소 / 구름·가스 입력이 P.618 §2.5 freeze 규칙 위반(0.1% 조건 사용 → E/W밴드에 불리한 편향) / Phase-4 self-check가 부분실행 토글과 충돌
- **P2 (잠재)**: 벡터입력 시 `/`·`^` 연산자 버그(현재 미발현), θ<5° 강우식 누락, 디버그 figure 15개/런, 신틸레이션 L 간략식
- **검증통과**: P.838-3 계수 전수 일치(Table 5 재현), P.840-9 전 수식 일치(273.75 K 포함), P.676 층적분·gaspl/atmosisa 단위 정확, 위성툴박스 전 호출 단위·이중계상 검증 통과
- **논문 캐비앗**: 73.5 GHz는 P.618 유효범위(≤55 GHz) 밖 외삽 명시, τ=45° 가정, 하늘잡음 미모델링, 350 km/98°는 SSO 아님(96.85°)
