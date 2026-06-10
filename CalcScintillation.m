function [L_scint, sigma_final] = CalcScintillation(freq, el_deg, D, eta, N_wet, p)
%{
    [ITU-R P.618-14 Section 2.4.1 Amplitude Scintillation]
    
    Input:
        freq      : Frequency [Hz]
        el_deg    : Elevation angle vector [degrees]
        D         : Antenna Diameter [m] (Receiver)
        eta       : Antenna Efficiency (0 ~ 1)
        N_wet     : Wet term of radio refractivity [N-units] (User Input)
        p         : Time percentage (0.01 < p <= 50) [%]
                    (e.g., for 99.9% Availability, p = 0.1)
    
    Output:
        L_scint   : Scintillation Fade Depth [dB] (최종 감쇄량)
        sigma_final : Standard deviation of signal amplitude [dB]
%}

    %% 0. 기본 설정
    f_GHz = freq / 1e9;
    L_scint = zeros(size(el_deg));
    sigma_final = zeros(size(el_deg));
    
    % 고도각 4도 미만은 ITU 모델 적용 범위 밖이므로 제외 (안정성)
    valid_mask = el_deg >= 4; 
    
    if ~any(valid_mask)
        return;
    end
    
    theta = el_deg(valid_mask);
    
    %% Step 1. 기준 표준편차 (sigma_ref) [Eq. 46]
    % 기후 요소(N_wet)에 따른 기본적인 대기 흔들림 정도
    sigma_ref = 3.6e-3 + 1e-4 * N_wet;
    
    %% Step 2. 유효 경로 길이 (L) 및 기하학적 파라미터 (x) [Eq. 49]
    % 난류층 높이 h_L = 1000 m (ITU 표준값)
    h_L = 1000;
    L = h_L ./ sind(theta); % [m] slant path to turbulent layer
    
    % 유효 안테나 직경
    D_eff = sqrt(eta) * D;
    
    % 안테나 평균화 인자 x 계산
    % x = 1.22 * D_eff^2 * (f / L)  (f: GHz, L: m)
    x = 1.22 * (D_eff^2) * f_GHz ./ L;
    
    %% Step 3. 안테나 평균화 계수 g(x) [Eq. 48]
    % 안테나가 클수록(x가 클수록) g(x)는 작아져서 손실을 줄여줌
    
    term1 = 3.86 * (x.^2 + 1).^(11/12);
    term2 = sind((11/6) * atand(1./x));
    term3 = 7.08 * x.^(5/6);
    
    g_x_sq = term1 .* term2 - term3;
    g_x_sq(g_x_sq < 0) = 0; % 수치 오류 방지
    g_x = sqrt(g_x_sq);
    
    %% Step 4. 최종 표준편차 (sigma) [Eq. 47]
    % 주파수, 고도각, 안테나 효과 통합
    sigma = sigma_ref * (f_GHz.^(7/12)) .* (g_x ./ (sind(theta).^(1.2)));
    
    %% Step 5. 시간율에 따른 페이드 깊이 (Fade Depth) [Eq. 50, 51]
    % p% 시간율 동안 겪을 수 있는 깊은 페이딩 계산
    
    log_p = log10(p);
    a_p = -0.061 * (log_p.^3) + 0.072 * (log_p.^2) - 1.71 * log_p + 3.0;
    
    As = a_p .* sigma; % [dB]
    
    %% Output Mapping
    L_scint(valid_mask) = As;
    sigma_final(valid_mask) = sigma;

end