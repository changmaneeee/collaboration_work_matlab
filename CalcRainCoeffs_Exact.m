function [k, alpha] = CalcRainCoeffs_Exact(f, theta, tau)
% CalcRainCoeffs_Exact : ITU-R P.838-3 문서의 Table 1~4와 Eq (2)~(5)를 1:1로 구현한 직접 계산법
% 
% Input:
%   f     : 주파수 [GHz] (예: 73.5)
%   theta : 앙각(Elevation Angle) [degrees]
%   tau   : 편파 틸트각(Polarization tilt angle) [degrees] (수평=0, 원형=45, 수직=90)
% Output:
%   k, alpha : 최종 비감쇠 계수

    log_f = log10(f);

    %% [STEP 1] 테이블 불러오기 (Table 1 ~ 4)
    % 구조: [ j,   a_j,   b_j,   c_j ]
    
    % Table 1: Coefficients for k_H
    table1_kH = [
        1, -5.33980, -0.10008, 1.13098;
        2, -0.35351,  1.26970, 0.45400;
        3, -0.23789,  0.86036, 0.15354;
        4, -0.94158,  0.64552, 0.16817
    ];
    mk_H = -0.18961;  ck_H = 0.71147;

    % Table 2: Coefficients for k_V
    table2_kV = [
        1, -3.80595,  0.56934, 0.81061;
        2, -3.44965, -0.22911, 0.51059;
        3, -0.39902,  0.73042, 0.11899;
        4,  0.50167,  1.07319, 0.27195
    ];
    mk_V = -0.16398;  ck_V = 0.63297;

    % Table 3: Coefficients for alpha_H
    table3_aH = [
        1, -0.14318,  1.82442, -0.55187;
        2,  0.29591,  0.77564,  0.19822;
        3,  0.32177,  0.63773,  0.13164;
        4, -5.37610, -0.96230,  1.47828;
        5, 16.1721,  -3.29980,  3.43990
    ];
    ma_H = 0.67849;   ca_H = -1.95537;

    % Table 4: Coefficients for alpha_V
    table4_aV = [
        1, -0.07771,  2.33840, -0.76284;
        2,  0.56727,  0.95545,  0.54039;
        3, -0.20238,  1.14520,  0.26809;
        4, -48.2991,  0.791669, 0.116226;
        5, 48.5833,   0.791459, 0.116479
    ];
    ma_V = -0.053739; ca_V = 0.83433;


    %% [STEP 2] 식 (2)와 식 (3)을 통한 수평/수직 편파 계수 계산
    % j열 데이터 분리 (a_j: 2열, b_j: 3열, c_j: 4열)
    
    % 식 (2): log10(k_H) 및 log10(k_V) 계산
    sum_kH = sum( table1_kH(:,2) .* exp(-((log_f - table1_kH(:,3)) ./ table1_kH(:,4)).^2) );
    k_H = 10^(sum_kH + mk_H * log_f + ck_H);

    sum_kV = sum( table2_kV(:,2) .* exp(-((log_f - table2_kV(:,3)) ./ table2_kV(:,4)).^2) );
    k_V = 10^(sum_kV + mk_V * log_f + ck_V);

    % 식 (3): alpha_H 및 alpha_V 계산
    sum_aH = sum( table3_aH(:,2) .* exp(-((log_f - table3_aH(:,3)) ./ table3_aH(:,4)).^2) );
    alpha_H = sum_aH + ma_H * log_f + ca_H;

    sum_aV = sum( table4_aV(:,2) .* exp(-((log_f - table4_aV(:,3)) ./ table4_aV(:,4)).^2) );
    alpha_V = sum_aV + ma_V * log_f + ca_V;


    %% [STEP 3] 식 (4)와 식 (5)를 통한 최종 k, alpha 도출
    % 앙각(theta)과 편파 틸트각(tau) 반영
    term_cos = (cosd(theta).^2) * cosd(2 * tau);
    
    % 식 (4): k 계산
    k = (k_H + k_V + (k_H - k_V) .* term_cos) / 2;
    
    % 식 (5): alpha 계산
    alpha = (k_H * alpha_H + k_V * alpha_V + (k_H * alpha_H - k_V * alpha_V) .* term_cos) / (2 * k);

end