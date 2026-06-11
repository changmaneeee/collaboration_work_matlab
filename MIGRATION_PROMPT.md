# [새 세션 시작 프롬프트] WP4 시뮬레이터 — 검증 완료된 수정사항 재적용 지시서

> 사용법: 이 파일 내용 전체를 새 Claude Code 세션의 첫 메시지로 붙여넣으세요.
> 작성: 2026-06-11, 이전 세션(검증·수정 완료)에서 인계.

---

당신은 E/W-band 위성 다운링크 논문용 MATLAB 시뮬레이터(main_v2.m + 지원함수 10개, R2025b)가 있는 저장소에서 작업한다. 이 저장소의 코드는 **수정 전 원본**이다. 직전 세션에서 ITU-R 공식 원문(P.618-14 / P.838-3 / P.840-9 / P.676 / P.836-6 / P.453-14 / P.837-8 / P.839-4 — 전부 현행판 확인됨) 대조 전수 검증을 마쳤고, 아래 수정 4건이 **확정·수치검증 완료** 상태다. 너의 임무: ① 수정 전 원본을 `_backup_pre_p618fix\` 폴더에 백업 → ② 아래 수정을 정확히 적용 → ③ 검증 레시피 실행 → ④ 결과 보고 (+ git 저장소라면 수정 단위별 커밋).

## 수정 1 — main_v2.m: `gs0`(숫자0) → `gsO`(대문자O) [P0 실행차단 버그]

약 138~141행, 밴드 루프 내부. MATLAB은 변수명이 문자 단위로 구분되는데 `gs0`은 어디에도 정의돼 있지 않아(정의는 114행의 `gsO`), 첫 줄 `clear` 때문에 실행 즉시 "Unrecognized function or variable 'gs0'"로 중단된다. (Code Analyzer는 스크립트의 미정의 변수를 못 잡음)

찾기:
```matlab
            gmbSat  = gimbal(sat);
            gmbGS   = gimbal(gs0);
            pointAt(gmbSat, gs0);
            pointAt(gmbGS, sat);
```
교체:
```matlab
            % [FIX 2026-06-11] gs0 (digit zero) -> gsO (capital letter O).
            % The ground-station object is defined as gsO at the top of this GS
            % loop; 'gs0' was never defined, so with the leading 'clear' every
            % run aborted here with "Unrecognized function or variable 'gs0'".
            % (Code Analyzer cannot catch undefined variables in scripts.)
            gmbSat  = gimbal(sat);
            gmbGS   = gimbal(gsO);
            pointAt(gmbSat, gsO);
            pointAt(gmbGS, sat);
```

## 수정 2 — CalcRainLoss.m: 3개 지점

### 2a. P.618-14 Step 10 β 세 번째 분기 추가 [P1 — 결과를 바꾸는 오류]
원문(P.618-14 인쇄본 p.8): β는 3분기 — ① p≥1% or |φ|≥36°: β=0 ② p<1%, |φ|<36°, **θ≥25°**: β=−0.005(|φ|−36) ③ **그 외(θ<25°)**: β=−0.005(|φ|−36)+1.8−4.25·sinθ. 원본 코드는 ③이 없어 저위도(Singapore 1.35°, UAE 25.23°) 저앙각에서 강우감쇠를 최대 ×1.48 과소평가.

찾기 (Step 10 블록 내):
```matlab
        %Beta Calculation
        if target_p >= 1 || abs(gs_lat) >= 36
            beta = 0;
        else
            beta = -0.005 * (abs(gs_lat) - 36);
        end
```
교체 (β가 θ 의존 벡터가 됨 — 아래쪽 exponent_v 줄은 이미 element-wise라 무변경):
```matlab
        %Beta Calculation [ITU-R P.618-14 Step 10, p.8 - THREE cases]
        %  case 1: p >= 1%  or |lat| >= 36 deg            -> beta = 0
        %  case 2: p < 1%, |lat| < 36, theta >= 25 deg    -> beta = -0.005(|lat|-36)
        %  case 3: OTHERWISE (theta < 25 deg)             -> beta = -0.005(|lat|-36) + 1.8 - 4.25*sin(theta)
        %  NOTE: case 3 depends on theta, so beta is a PER-SAMPLE VECTOR.
        beta = zeros(size(theta));
        if target_p < 1 && abs(gs_lat) < 36
            beta(:) = -0.005 * (abs(gs_lat) - 36);
            lowEl = theta < 25;
            beta(lowEl) = beta(lowEl) + 1.8 - 4.25*sind(theta(lowEl));
        end
```

### 2b. Step 2 각주 (θ<5° 식 의도적 미구현 — 설계 결정 기록)
찾기:
```matlab
    %% 2. Slant-path length (Ls) [km]
    % Ls = (hR - hs) / sin(theta)
    Ls = (h_R_km - h_s_km) ./sind(theta);
```
교체:
```matlab
    %% 2. Slant-path length (Ls) [km]
    % Ls = (hR - hs) / sin(theta)
    % [NOTE / ITU-R P.618-14 Step 2, p.7] Eq.(1) below is valid for theta >= 5 deg ONLY.
    % For theta < 5 deg the standard mandates Eq.(2):
    %   Ls = 2(hR-hs) / ( sqrt(sin^2(theta) + 2(hR-hs)/Re) + sin(theta) ),  Re = 8500 km.
    % Eq.(2) is INTENTIONALLY not implemented: typical GS antennas cannot receive
    % below 5 deg elevation and main_v2 enforces cfg.elev_mask_deg = 5.
    % If the elevation mask is ever lowered below 5 deg, implement Eq.(2) here
    % (see VERIFICATION_REPORT.md, finding F-7).
    Ls = (h_R_km - h_s_km) ./sind(theta);
```

### 2c. 디버그 figure 비활성화 (런당 5GS×3밴드=15창 방지; 서버 -nodisplay 대비)
찾기 (Step 5 다음, 첫 줄 끝에 공백 2개가 있을 수 있음 — 유연하게 매칭):
```matlab
    figure; plot(theta, gamma_R, '.-'); grid on;
    xlabel('Elevation (deg)'); ylabel('gamma_R (from rainpl)');
    title('Check: gamma_R should NOT depend on elevation');
```
교체:
```matlab
    % [FIX 2026-06-11] Debug plot DISABLED (was: figure; plot(theta, gamma_R, ...)).
    % Reason: this function is called once per (GS, band) pair, so a full run of
    % main_v2 spawned 5x3 = 15 figure windows and slowed batch/server (-nodisplay)
    % runs; it also ignored cfg.show_plots. NOTE the old plot title's premise
    % ("gamma_R should NOT depend on elevation") only holds for tau = 45 deg,
    % where cos(2*tau) = 0 kills the theta-dependence in P.838-3 Eqs.(4)-(5).
    % Re-enable manually if needed:
    %   figure; plot(theta, gamma_R, '.-'); grid on;
    %   xlabel('Elevation (deg)'); ylabel('gamma_R [dB/km] (P.838-3 direct)');
    %   title('Debug: gamma_R vs elevation');
```
(보너스, 같은 파일) 찾기 `Ap = A001; %If Target probability is 0.01(Availbility 99.9%), Keep going` → 교체 `Ap = A001; %If target probability is exactly 0.01% (availability 99.99%), Eq.(8) reduces to Ap = A001` (0.01%는 99.9%가 아니라 99.99%에 해당 — 주석만 오류였음).

## 수정 3 — GroundStations.m: P.618-14 정합 입력값 15개 교체

근거: P.618-14 §2.5 — 구름 A_C(p)=A_C(5%) for p<5% [Eq.67], 가스 A_G(p)=A_G(5%) for p<5% [Eq.68] (0.1% 최악값 사용은 강우와 이중계상); §2.4.1 — N_wet은 연 **중앙값(50%)**. R_001(0.01%)과 h_rain(연평균)은 정의상 원래 맞으므로 무변경. 새 값은 ITU 공식 TXT product에서 추출·검증 완료(그리드 노드 일치, heritage 25/25 재현 ≤5e-05; rho는 P.836-6 공식 고도보정(VSCH/TOPO) 포함, MathWorks 독립 구현과 일치 교차검증).

각 행을 찾아 교체 (5국 × 3필드; legacy 값 주석 보존):
```matlab
Stuttgart.rho_surf       = 12.6689;     % P.836-6, 5% (Eq.68 freeze; legacy 0.1%: 16.0423)
Stuttgart.L_water        = 0.2801;      % P.840-9, 5% (Eq.67 freeze; legacy 0.1%: 0.6278) [kg/m^2]
Stuttgart.N_wet          = 45.3936;     % P.453-14, annual median 50% (Sec.2.4.1; legacy 0.1%: 101.2678)
KAU.rho_surf       = 21.0049;   % P.836-6, 5% (legacy 0.1%: 23.3458)
KAU.L_water        = 0.2068;    % P.840-9, 5% (legacy 0.1%: 0.6597)
KAU.N_wet          = 47.5024;   % P.453-14, median 50% (legacy 0.1%: 143.1342)
Singapore.rho_surf       = 22.1651;   % P.836-6, 5% (legacy 0.1%: 23.6412)
Singapore.L_water        = 0.3514;    % P.840-9, 5% (legacy 0.1%: 1.1121)
Singapore.N_wet          = 131.9951;  % P.453-14, median 50% (legacy 0.1%: 156.4038)
UAE.rho_surf       = 25.3561;   % P.836-6, 5% (legacy 0.1%: 30.0792)
UAE.L_water        = 0.2011;    % P.840-9, 5% (legacy 0.1%: 0.6413)
UAE.N_wet          = 88.1356;   % P.453-14, median 50% (legacy 0.1%: 172.6908)
SvalSat.rho_surf       = 5.1977;    % P.836-6, 5% (legacy 0.1%: 6.7769)
SvalSat.L_water        = 0.0394;    % P.840-9, 5% (legacy 0.1%: 0.1701)
SvalSat.N_wet          = 19.2665;   % P.453-14, median 50% (legacy 0.1%: 48.7323)
```
(R_001 다섯 줄과 h_rain_limit_m 다섯 줄은 절대 건드리지 말 것.)

헤더의 다음 3줄을 찾아:
```
%   The ITU-R parameter set for each station characterises the 99.9%
%   availability (0.1% exceedance) condition.  Values are carried over
%   verbatim from the verified WP2 main.m switch-case block.
```
다음으로 교체:
```
%   [P.618-14 COMPLIANT SET, 2026-06-11] Each field now carries the
%   statistic that Rec. ITU-R P.618-14 actually requires (NOT a blanket
%   0.1% condition; see VERIFICATION_REPORT.md F-3/F-4/F-11 and Sec.9):
%       R_001    : 0.01% annual exceedance      (P.618-14 Step 4)
%       h_rain   : mean annual h0 + 0.36 km     (P.839-4)
%       rho_surf : 5% annual exceedance         (P.618-14 Eq.(68) freeze,
%                  P.836-6 official interpolation incl. VSCH/TOPO altitude scaling)
%       L_water  : 5% annual exceedance         (P.618-14 Eq.(67) freeze, P.840-9)
%       N_wet    : annual MEDIAN (50%)          (P.618-14 Sec.2.4.1)
%   Legacy 0.1%-exceedance values (original WP2 extraction) are kept as
%   inline comments.
```
필드 규약 5줄(rho_surf/h_rain_limit_m/R_001/L_water/N_wet 설명)도 단위 주석을 위 통계에 맞게 갱신할 것.

## 적용 후 검증 레시피 (MATLAB에서 실행, 전부 통과해야 완료)

```matlab
cd <코드폴더>; clear functions; close all;
th = [5 10 15 20 25 30 50]';
% (1) beta 수정 검증 — Singapore: 이론비 10^((1.8-4.25sinθ)·0.9·sinθ)와 일치해야 함
L_sing = CalcRainLoss(73.5e9, 100.0675, th, 4972.3, 30, 1.35, 99.9);
ref_sing = [294.888 237.015 197.265 155.679 113.895 109.347 108.267]';  % 기대값
assert(max(abs(L_sing - ref_sing)) < 5e-3, 'beta fix mismatch');
% (2) 비영향군 불변 — KAU(|lat|>=36)
L_kau = CalcRainLoss(73.5e9, 60.5478, th, 3897.6, 15, 37.60, 99.9);
ref_kau = [145.630 98.403 79.126 68.527 61.931 57.583 51.056]';
assert(max(abs(L_kau - ref_kau)) < 5e-3, 'KAU changed unexpectedly');
% (3) figure 미생성
assert(isempty(findall(0,'Type','figure')), 'debug figure still opens');
% (4) GroundStations 신규값
gs = GroundStations();
assert(abs(gs.Stuttgart.rho_surf-12.6689)<1e-9 && abs(gs.Singapore.N_wet-131.9951)<1e-9 ...
    && abs(gs.SvalSat.L_water-0.0394)<1e-9 && abs(gs.KAU.R_001-60.5478)<1e-9);
disp('ALL CHECKS PASSED');
```
추가: main_v2.m에서 `gs0` 검색 시 코드 참조 0건(설명 주석 제외)이어야 함. 수정 파일에 Code Analyzer 이슈 없어야 함.

git 저장소라면 커밋 3개 권장: ① "Fix gs0->gsO undefined-variable bug in main_v2" ② "CalcRainLoss: implement P.618-14 Step-10 third beta branch; disable debug figure; document theta<5deg design decision" ③ "GroundStations: P.618-14-compliant inputs (L/rho 5% freeze, Nwet median; legacy kept as comments)".

## 알아야 할 잔여 사실 (새 세션 메모리에 저장 권장)

1. **CalcCloudLoss의 `T_kelvin = 273.75`는 정답** — P.840-9 Eq.(14) 원문이 273.75 K 명시(원문에 '273.75' 3회, '273.15' 0회). 주석의 273.15가 오기. **절대 273.15로 "고치지" 말 것.**
2. **Phase-4 토글 버그(미수정)**: main_v2의 self-check가 가드 없음 → `cfg.run_link/run_energy/run_volume` 전부 true로 유지할 것(하나라도 false면 Phase 4 크래시). 서버 실행 시 `cfg.save_results=true`로.
3. **논문 캐비앗**: 73.5 GHz는 P.618-14 강우(§2.2.1.1 "up to 55 GHz")·신틸레이션(§2.4.1 "4–55 GHz") 유효범위 밖 외삽 / τ=45°(원형편파) 전 밴드 고정 가정 / 하늘잡음 증가(P.618 §3) 미모델링 / 350 km+98°는 SSO 아님(96.85°가 SSO) / 밴드별 reqEbNo 기준 상이.
4. **P2~P4 잔여(선택)**: CalcRainCoeffs_Exact:81 `/(2*k)`→`./(2.*k)`(벡터입력 잠재버그), CalcCloudLoss `^`→`.^`, CalcScintillation L식을 Eq.(43)으로(현 오차 ≤0.004 dB)·마스크 4°→5°, datestr→datetime, 김벌 생성 밴드루프 밖으로, MinElevationAngle→MaskElevationAngle(R2025a+ 비권장), 데드필드(cfg.req_EbNo_dB, cfg.show_plots, gs.id/pass_*).
5. **실행 sanity 기대값**: EW@Singapore closure=0 (강우만 ~100 dB+, 정상) / J/bit = 43.6(X)/22.9(Ka)/12.0(EW) nJ / X@SvalSat 마진 최선 / 7일×3 s 풀런 ~30분 추정(가스모델 지배), 첫 실행은 sim_duration_days=1 스모크 권장.

## (선택) 원본 PC에서 복사해오면 좋은 산출물

원본 경로 `C:\Users\changmin_lee\SynologyDrive\[Stuttgart_공동연구]\` 기준:
- `[WP_4]\[MATLAB_CODE]\` → VERIFICATION_REPORT.md(전체 검증·ITU 원문 인용 부록), P618_COMPLIANCE_WORK_REPORT.md, CODE_DOCUMENTATION.md, **ITU_percentile_candidates.mat**, **availability_input_candidates.csv**(가용도 90~99.99% 입력 후보군), .gitignore
- `[WP_2]\ITU_Doc\...\` → v2 추출 스크립트 3종(find_L_value_v2.m / GetSurfaceVaporDensity_v2.m / find_N_wet_value_v2.m)과 추출 CSV 3종 — 향후 다른 백분위·다른 지상국 추가 시 재사용
- 접근 불가 시: 본 지시서만으로 코드 수정·검증은 완결됨 (위 파일들은 문서·확장용)
