# [서버 세션 프롬프트] WP4 시뮬레이터 — 서버 환경 정밀 작업 가능성 검증

> 사용법: 로컬에서 이 저장소를 push한 뒤, **서버의 Claude Code 새 세션 첫 메시지로 이 파일 내용 전체를 붙여넣거나** "저장소 루트의 SERVER_VALIDATION_PROMPT.md를 읽고 그대로 수행해"라고 지시하세요.
> 작성: 2026-06-11, 로컬 PC 세션(모든 수정·검증 완료)에서 인계. 기준 커밋: `c9f4f60`.

---

당신은 E/W-band 위성 다운링크 논문용 MATLAB 시뮬레이터 저장소(main_v2.m + 지원함수 12개, 기준 R2025b)에서 작업한다. 이 저장소는 로컬 PC에서 **P.618-14 정합 수정 + 가용도(70~99.99%) 입력 파이프라인까지 완료·검증된 상태 그대로** push된 것이다. 너의 임무는 **이 서버 환경이 로컬과 동일한 정밀도로 작업 가능한지** 아래 V1~V5로 판정하고 PASS/FAIL 보고서를 작성하는 것이다.

**대원칙: 본 세션은 검증 전용 — 코드를 수정하지 말 것.** 임시 스크립트는 `tmp_` 접두사로 만들고 종료 시 전부 삭제. 검증 실패 시 "고치지" 말고 실패 내용·원인 추정만 보고할 것.

## V1 — 저장소 무결성

1. `git log --oneline`에 다음 체인이 있어야 함: `c9f4f60`(문서 동기화) ← `5d64efa`(가용도 연동) ← `5332969`(CSV 70/80% 확장) ← `7dc95ca` ← `e60c969` ← `ce75d73` ← `f248ae7` ← `27b30dc` ← `7ba65f8`. HEAD는 `c9f4f60` 이상.
2. 추적 파일 19종 존재 확인: `.gitignore`, `README.md`, MD 4종(VERIFICATION_REPORT / P618_COMPLIANCE_WORK_REPORT / CODE_DOCUMENTATION / MIGRATION_PROMPT), `availability_input_candidates.csv`, .m 13종(main_v2, ApplyAvailabilityInputs, ExtractITUPercentileInputs, BandParameters, GroundStations, LinkBudget, EnergyModel, DailyVolume, CalcRainLoss, CalcRainCoeffs_Exact, CalcCloudLoss, CalcScintillation, CalcZenithGasLoss) (+본 파일).
3. CSV 구조: 헤더 1행 + 데이터 55행(가용도 11종 × 5국), 11컬럼. 70/80% 행의 `rain_term`은 `excluded`.
4. **없어야 정상**(gitignore — 결손 아님): `R-REC-P.*` ITU 맵 폴더(시뮬레이션 실행에는 불필요; `ExtractITUPercentileInputs.m`만 사용 불가), `.mcp.json`, `_backup_pre_p618fix\`.

## V2 — MATLAB 환경

1. MATLAB 실행 수단 자동 감지: MATLAB MCP 도구가 보이면 그것을 사용, 없으면 CLI `matlab -batch "스크립트"` (헤드리스). 어느 쪽인지 보고서에 기록.
2. `ver` 결과 기록 — 기준은 R2025b (다른 버전이면 기록하고 V3/V4 허용오차를 완화 규칙대로 적용).
3. 필수 툴박스 — 각각 `license('test',...)` + 대표 함수 `which`로 확인:
   - Satellite Communications Toolbox: `satelliteScenario, satellite, groundStation, gimbal, transmitter, receiver, link, ebno, aer, access`
   - Aerospace Toolbox: `atmosisa`
   - `gaspl` (Radar Toolbox 또는 Phased Array System Toolbox)
   하나라도 없으면 V4/V5는 SKIP 처리하고 그 사실을 핵심 결론에 명시 (V3의 recipe 1~3 중 위성툴박스 무관 부분은 계속 진행).
4. 헤드리스 안전성: 풀런에서 figure가 0개여야 정상 (CalcRainLoss 디버그 plot은 2026-06-11 비활성화됨).

## V3 — 수치 회귀 (정밀성 핵심; 로컬 앵커값 재현)

아래를 그대로 실행 (저장소 루트에서). **전부 통과해야 "정밀 작업 가능" 판정.**

```matlab
clear functions; clear; close all;
th = [5 10 15 20 25 30 50]';
% (1) CalcRainLoss 앵커 — Singapore(베타 3분기 경로) / KAU(비영향군)
L_sing = CalcRainLoss(73.5e9, 100.0675, th, 4972.3, 30, 1.35, 99.9);
ref_sing = [294.888 237.015 197.265 155.679 113.895 109.347 108.267]';
assert(max(abs(L_sing - ref_sing)) < 5e-3, 'rain anchor (Singapore)');
L_kau = CalcRainLoss(73.5e9, 60.5478, th, 3897.6, 15, 37.60, 99.9);
ref_kau = [145.630 98.403 79.126 68.527 61.931 57.583 51.056]';
assert(max(abs(L_kau - ref_kau)) < 5e-3, 'rain anchor (KAU)');
% (2) 가용도 로더 앵커
gs = GroundStations();
[s999,i999] = ApplyAvailabilityInputs(gs, fieldnames(gs), 0.999, false);
assert(i999.rain_included && abs(s999.Stuttgart.rho_surf-12.6688592227883)<1e-12);
[s80,i80] = ApplyAvailabilityInputs(gs, {'Singapore','SvalSat'}, 0.80, false);
assert(~i80.rain_included && abs(s80.Singapore.L_water-0.18652)<1e-12 ...
    && abs(s80.Singapore.rho_surf-21.3959802629974)<1e-12 && s80.SvalSat.L_water==0 ...
    && abs(s80.Singapore.scint_a_p-0.762775799775406)<1e-12);
[s70,~] = ApplyAvailabilityInputs(gs, fieldnames(gs), 0.70, false);
assert(abs(s70.UAE.rho_surf-19.7254946677307)<1e-12 && abs(s70.KAU.L_water-0.03928)<1e-12 ...
    && abs(s70.Stuttgart.scint_a_p-0.434620903338888)<1e-12);
ok=false; try, ApplyAvailabilityInputs(gs,{'KAU'},0.85,false); catch ME, ok=contains(ME.identifier,'bad_avail'); end
assert(ok, 'invalid-avail error path');
assert(abs(gs.KAU.R_001-60.5478)<1e-9 && abs(gs.SvalSat.N_wet-19.2665)<1e-4);
% (3) LinkBudget Eq.(65)/(66) 스위치 — 강우 제외 항등식
bands = BandParameters(); band = bands.EW; el = [6;10;20;40;70];
sc.el_deg=el; sc.mask=true(size(el)); sc.ebno_fspl_dB=60*ones(size(el));
cfg.avail=0.80; cfg.L_pol_dB=0.5; cfg.rx_dish_m=1.2; cfg.rx_eff=0.6;
Lx = LinkBudget(band, s80.Singapore, sc, cfg);
L_ref = CalcZenithGasLoss(band.freq_Hz,30,el,s80.Singapore.rho_surf) ...
      + sqrt(CalcCloudLoss(band.freq_Hz,el,s80.Singapore.L_water).^2 ...
      + CalcScintillation(band.freq_Hz,el,1.2,0.6,s80.Singapore.N_wet,20).^2) + 0.5;
assert(max(abs(Lx.L_atm_dB - L_ref)) < 1e-9, 'Eq.(66) no-rain identity');
% (4) figure 미생성 (헤드리스 전제)
assert(isempty(findall(0,'Type','figure')), 'unexpected figure');
disp('V3 ALL PASS');
```

허용오차 완화 규칙: MATLAB 버전이 R2025b가 아니면 (1)의 5e-3 → 2e-2까지 허용하되 편차를 기록. (2)(3)은 버전 무관하게 그대로 통과해야 함(순수 산술 + readtable).

## V4 — 엔드투엔드 스모크 (결정적 궤도 전파 재현)

main_v2.m을 직접 수정하지 말고, 메모리에서 문자열 치환한 임시 사본 `tmp_smoke.m`으로 실행:
치환 5건 — `cfg.gs_selection   = 'all';` → `{'Singapore','SvalSat'}`, `cfg.bands_selected = {'X','Ka','EW'};` → `{'X','EW'}`, `cfg.avail          = 0.999;` → `0.80;`, `cfg.sample_time_s     = 3;` → `10;`, `cfg.sim_duration_days = 7;` → `1;`. 실행 후 한 번 더, avail만 0.999로 바꿔 재실행. 종료 후 `tmp_smoke.m` 삭제.

**로컬 기대값** (2026-06-11, R2025b; epoch 2026-05-28 00:00 UTC 고정이라 결정적):

| 항목 | 기대값 |
|---|---|
| Singapore n_passes / visible | 3 / 830 s |
| SvalSat n_passes / visible | 11 / 4180 s |
| avail=0.80: margin(min/mean) X@Sing | −17.49 / −13.51 dB |
| avail=0.80: EW@Sing, X@Sval, EW@Sval | −37.61/−18.48, −16.75/−11.93, −15.83/−5.25 dB |
| avail=0.999: X@Sing, EW@Sing | −36.07/−25.09, −338.33/−238.31 dB |
| avail=0.999: X@Sval, EW@Sval | −18.19/−12.46, −45.35/−20.51 dB |
| J/bit | X 43.6 / EW 12.0 nJ |
| D_day | X@Sing 52.4 / EW@Sing 518.8 / X@Sval 263.9 / EW@Sval 2612.5 GB |
| Phase 1 출력 | avail=80%일 때 "rain term: EXCLUDED (Eq.66 ...)" 테이블 |

판정 기준: 패스 수·visible 초는 정확 일치(동일 R2025b 기준; 버전 다르면 ±1패스/±20 s 허용 후 기록), 마진은 ±0.05 dB(버전 다르면 ±0.5 dB), J/bit·D_day는 표기 자릿수 일치. Phase 1→4 전 구간 에러 없이 완주해야 PASS.

## V5 (선택) — 풀런 리허설

V1~V4 전부 PASS이고 시간이 허용되면: main_v2.m 원본 설정 그대로(5GS × 3밴드 × 7일 × 3 s)에 `cfg.save_results = true`만 임시 사본에서 바꿔 실행 (~30분 예상). Sanity: EW@Singapore closure=0 (강우만 100 dB+, **정상**) / X@SvalSat 마진 최선 / J/bit 43.6/22.9/12.0 nJ / results_*.mat 생성. 생성된 .mat은 보존하고 경로를 보고.

## 금지·주의사항 (서버 세션에서 반드시 준수)

1. **코드 수정 금지.** 특히 `CalcCloudLoss`의 `T_kelvin = 273.75`는 P.840-9 Eq.(14) 원문 그대로의 **정답** — 273.15로 "고치지" 말 것 (주석의 273.15가 오기).
2. `cfg.run_link / run_energy / run_volume`은 **전부 true 유지** (Phase-4 self-check에 가드가 없어 하나라도 false면 크래시 — 알려진 미수정 P1).
3. `cfg.avail`은 CSV 수록 11종(0.70/0.80/0.90/0.95/0.98/0.99/0.995/0.998/0.999/0.9995/0.9999)만 유효.
4. `ExtractITUPercentileInputs.m`은 ITU 맵 폴더(R-REC-*, gitignore로 미push) 부재 시 실패가 **정상** — 서버에서 재추출이 필요해지면 맵 폴더를 별도 전송할 것.
5. 73.5 GHz는 P.618-14 유효범위(≤55 GHz) 밖 외삽 — 수치가 이상해 보여도 모델 한계이지 버그 아님 (EW@Singapore 수백 dB 정상).

## 보고서 형식

| 단계 | 판정 | 측정값 vs 기대값 (편차) | 비고 |
|---|---|---|---|
| V1 무결성 | PASS/FAIL | ... | |
| V2 환경 | PASS/FAIL | MATLAB 버전·툴박스·실행수단 | |
| V3 수치 회귀 | PASS/FAIL | 최대 편차 | |
| V4 스모크 | PASS/FAIL | 표 항목별 | |
| V5 풀런 | PASS/FAIL/SKIP | .mat 경로 | |

**최종 판정**: V1~V4 전부 PASS → "서버 정밀 작업 가능". 하나라도 FAIL → 가능/불가 항목을 구분하고 원인(툴박스 부재 / 버전 차이 / 파일 결손)을 명시. 끝으로 임시 파일 삭제 여부와 git 작업트리가 깨끗한지(`git status`) 확인해 보고할 것.
