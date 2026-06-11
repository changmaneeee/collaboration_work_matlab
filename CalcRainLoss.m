function [L_rain, rain_slant_path] = CalcRainLoss(freq, R001, el_deg, h_rain_limit, gs_alt, gs_lat, target_avail)

%{
    [ITU-R P.618-14 Rain Attenuation Model]
    
    Input:
        1. freq         : Carrier frequency [Hz] (기존 유지)
        2. R001         : Rainfall rate for 0.01% exceedance [mm/h] (기존 rain_rate 위치)
        3. el_deg       : Elevation angles vector [degrees] (기존 유지)
        4. h_rain_limit : Rain height [m] (ITU-R P.839) (기존 유지)
        5. gs_alt       : Ground Station Altitude [m] (기존 유지)
        ---------------------------------------------------------
        6. gs_lat       : Ground Station Latitude [degrees] (Step 7, 10 계산용 필수 추가)
        7. target_avail : Target Availability [%] (e.g. 99.9) (Step 10 스케일링용 필수 추가)
    
    Output:
        L_rain          : Final Rain attenuation [dB]
        rain_slant_path : Effective path length [m] (Not just geometric!)
%}
    
    %%0. setting Parameter Unit
    freq_GHz = freq / 1e9;
    h_R_km = h_rain_limit / 1000;
    h_s_km = gs_alt / 1000;

    % Target Percentage
    target_p = 100 - target_avail;

    L_rain = zeros(size(el_deg));
    rain_slant_path = (zeros(size(el_deg)));

    valid_mask = el_deg > 0.1;
    if ~any(valid_mask)
        return;
    end

    theta = el_deg(valid_mask);

    %% 1. Rain Height
    % using h_rain_limit from ITU-R P.839-4

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

    if (h_R_km - h_s_km) <= 0
        disp('GS height > rain height');
        return;
    end

    %% 3. Horizontal projection (LG) [km]
    % LG = Ls * cos(theta)

    LG = Ls .*cosd(theta);


    %% 4. Rain rate
    % Using R001 value(default of GS location)

    %% 5. Specific attenuation (gamma_R) [dB/km]
    %Using rainpl function(MATLAB) for calculation dB/km(1km)
    tau = 45;
    k = zeros(size(theta));
    alpha = zeros(size(theta));
    for i = 1:length(theta)
         [k(i), alpha(i)] = CalcRainCoeffs_Exact(freq_GHz, theta(i), tau);
    end 

    gamma_R = k .* (R001 .^ alpha);

    if size(gamma_R, 1) ~= size(theta, 1)
        gamma_R = gamma_R';
    end
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

    %% 6. Horizontal reduction factor (r0.01)
    %Rain isn't uniform at Horizontal

    term_den = 1 + 0.78*sqrt( (LG.*gamma_R) ./ freq_GHz) - 0.38*(1 - exp(-2*LG));
    r001 = 1 ./term_den;


    %% 7. Vertical adjustment factor (v0.01)
    %Rain vertical distribution correction

    %Zeta cal
    zeta = atand( (h_R_km - h_s_km) ./ (LG.*r001));

    % Logic of LR(Rain Path) decision
    LR = zeros(size(theta));
    mask_zeta_gt_theta = zeta > theta;

    %case1: Zeta > Theta
    LR(mask_zeta_gt_theta) = (LG(mask_zeta_gt_theta) .* r001(mask_zeta_gt_theta)) ./ cosd(theta(mask_zeta_gt_theta));
    LR(~mask_zeta_gt_theta) = (h_R_km - h_s_km) ./ sind(theta(~mask_zeta_gt_theta));

    %Chi
    if abs(gs_lat) < 36
        chi = 36 - abs(gs_lat);
    else
        chi = 0;
    end

    %final value of v001
    v001 = 1 ./ (1 + sqrt(sind(theta)).*(31*(1-exp( -(theta ./ (1+chi)))) .* (sqrt(LR.*gamma_R) ./ freq_GHz.^2) -0.45));


    %% 8. Effective path length (LE) [km]
    LE = LR .* v001;

    %% 9. Predicted Attenuation at 0.01% (A001) [dB]
    A001 = gamma_R.*LE;

    %% 10. Scaling to target probability (Ap)

    if abs(target_p - 0.01) < 1e-6
        Ap = A001; %If target probability is exactly 0.01% (availability 99.99%), Eq.(8) reduces to Ap = A001
    else
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

        safe_A001 = A001;
        safe_A001(safe_A001 == 0) = eps;

        exponent_v = 0.655 + 0.033*log(target_p) - 0.045*log(safe_A001) - beta*(1-target_p) .*sind(theta);

        %Final Scaling
        Ap = A001 .* (target_p / 0.01) .^ (-exponent_v);

        Ap(A001 == 0) = 0;

    end

    L_rain(valid_mask) = Ap;

    rain_slant_path(valid_mask) = LE *1000;
end


