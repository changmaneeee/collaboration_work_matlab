function [total_loss_dB] = CalcZenithGasLoss(freq, gs_alt, el_deg_array, rho_surf)

%This file calculated total zenith atmospheric attenuation using layered
%integration
%{
 Input:
    freq: Carrier Frequency(Hz)
    gs_alt: Ground Station Altitude(m)
    max_height: Integration Limit (m)
    step_size: Layer thickness resolution (m)\

 Output:
    total_loss_dB: Total integration loss towards Zenith (90deg)
    layer_data: (Optional) Struct containing profiles for debugging

 Reference:
    Atmosphere: ITU-R P.835 (via atmosisa)
    Water Vapor: Exponential decay model (ITU-R P.836 approx)
    Attenuation: ITU-R P.676 (via gaspl)
%}
    Re = 6378.137e3;
    
    h_curr = gs_alt;
    num_layers = 905; % Until 84.7502km
    h_nodes = zeros(1, num_layers);
    delta_nodes = zeros(1, num_layers);

    for i = 1:num_layers
        %[ITU-R P.676-10] Eq 21 10cm at the lowest layer to 1km at an
        %altitude of 100km
        delta_km = 0.0001 * exp((i-1)/100);
        delta_m = delta_km * 1000;

        h_nodes(i) = h_curr;
        delta_nodes(i) = delta_m;

        h_curr = h_curr + delta_m;
    end

    n_layer = zeros(1, num_layers);
    gamma_layer = zeros(1,num_layers);

    for k = 1:num_layers
        h_mid = h_nodes(k) + delta_nodes(k)/2;

        h_mid_safe = min(h_mid, 84851); %atmosisa function limit
        [T_K, ~, P_Pa, ~] = atmosisa(h_mid_safe);
        T_C = T_K - 273.15;
        P_hpa = P_Pa / 100;
        
        %[ITU-R P.836-6] Water Vapor Density
        rho = rho_surf * exp(-(h_mid - gs_alt) / 2000); 

        %[ITU-R P.453-14] Water Vapor Pressure
        e_hPa = (rho*T_K) / 216.7;

        % [ITU-R P.453-14 Eq. 5] Dry Atmospheric Pressure [hPa]
        P_dry_hPa = P_hpa - e_hPa;
        
        % [ITU-R P.453-14 Eq. 2] Exact Radio Refractivity 'N'
        N_ref = 77.6 * (P_dry_hPa / T_K) + 72 *(e_hPa / T_K) + 3.75e5*(e_hPa / T_K^2);
        n_layer(k) = 1 + N_ref * 1e-6;

        % [ITU-R P.676-10 Annex 1] Specific Attenuation [dB/km] via gaspl
        P_dry_hPa = P_dry_hPa*100;
        gamma_layer(k) = gaspl(1000, freq, T_C, P_dry_hPa, rho);
    end

    h_top_safe = min(h_curr, 84851);
    [T_K_top, ~, P_Pa_top, ~] = atmosisa(h_top_safe);
    rho_top = rho_surf * exp(-(h_curr - gs_alt) / 2000);
    e_hPa_top = (rho_top * T_K_top) / 216.7;
    P_dry_hPa_top = (P_Pa_top / 100) - e_hPa_top;
    N_ref_top = 77.6 * (P_dry_hPa_top / T_K_top) + 72 * (e_hPa_top / T_K_top) + 3.75e5 * (e_hPa_top / T_K_top^2);
    n_top = 1 + N_ref_top * 1e-6;

    n_boundary = [n_layer, n_top];

    total_loss_dB = zeros(size(el_deg_array));

    for idx = 1:length(el_deg_array)
        el_deg = el_deg_array(idx);
        beta_curr = deg2rad(90 - el_deg);
        
        total_loss = 0;

        for k = 1:num_layers
            r_n = Re + h_nodes(k);
            delta_n = delta_nodes(k);

            %[ITU-R P.676-10] Eq. 17 Actual bent path length through the current layer (a_n)
            term1 = -r_n * cos(beta_curr);
            term2 = 0.5 * sqrt(4* r_n^2 * (cos(beta_curr))^2 + 8*r_n*delta_n + 4*delta_n^2);
            a_n = term1 + term2;

            %[ITU-R P.676-10] Eq. 20 Accumulate Gas Attenuation (gamma is dB/km, a_n is m)
            total_loss = total_loss + gamma_layer(k) * (a_n / 1000);

            % [ITU-R P.676-10] Eq. 18 Calculate exit angle alpha_n
            arg_alpha = (-a_n^2 - 2*r_n*delta_n - delta_n^2) / (2 * a_n * r_n + 2 * a_n * delta_n);
            arg_alpha = max(min(arg_alpha, 1), -1); % Numerical safeguard
            alpha_n = pi - acos(arg_alpha);
            
            % [ITU-R P.676-10] Eq. 19  Snell's Law for spherical layers (next incidence angle beta_{n+1})
            arg_beta = (n_boundary(k) / n_boundary(k+1)) * sin(alpha_n);
            arg_beta = max(min(arg_beta, 1), -1); % Numerical safeguard
            beta_curr = asin(arg_beta);
        end

        total_loss_dB(idx) = total_loss;

    end
 
end

