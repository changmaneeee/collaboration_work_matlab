function [L_cloud, KL_val] = CalcCloudLoss(freq, el_deg, L_content)

%{
    [ITU-R P.840-9 Cloud Attenuation Model Implementation]
    
    Reference: Recommendation ITU-R P.840-9 (08/2023)
               Section 3.2 (Statistical prediction method)
    
    Input:
        freq      : Frequency [Hz]
        el_deg    : Elevation angle vector [degrees]
        L_content : Integrated cloud liquid water content [kg/m^2] or [mm]
                    corresponding to the desired exceedance probability p%.
                    (User must obtain this from ITU-R P.840 Digital Maps)
        
    Output:
        L_cloud   : Slant path cloud attenuation [dB]
        KL_val    : Specific attenuation coefficient [(dB/km)/(g/m^3)] or [dB/mm]
%}


%% 0. Setting Parameter Unit
    f_GHz = freq / 1e9;
    L_cloud = zeros(size(el_deg));
    valid_mask = el_deg >0.1;

%% 1. Calculate KL(f) - Specific Attenuation Coefficient

    A1 = 0.1522;
    A2 = 11.51;
    A3 = -10.4912;

    f1 = -23.9589;
    f2 = 219.2096;

    sigma1 = 3.2991e3;
    sigma2 = 2.7595e6;


    % Dielectric Permittivity Model (Double-Debye) for Kl(f, T=273.15K)
    % Eq (16) simplifies the complex permittivity calculation into a curve fit.
    % However, Eq (16) has a term "Kl(f, T=273.15)". 
    % Let's calculate the base Kl first using Eq (2)~(10) for T=273.15K for rigorous accuracy.

    T_kelvin = 273.75;
    theta_val = 300 / T_kelvin;

    % Dielectric parameters [Eq 6-10]
    eps0 = 77.66 + 103.3*(theta_val -1);
    eps1 = 0.0671*eps0;
    eps2 = 3.52;

    fp = 20.20 - 146*(theta_val -1) + 316*(theta_val -1)^2;
    fs = 39.8*fp;

    eps_prime = ((eps0 - eps1) / (1 + (f_GHz/fp)^2)) + ...
        ((eps1 - eps2) / (1 + (f_GHz/fs)^2)) + eps2;

    eps_dprime = ((f_GHz/fp) * (eps0 - eps1) / (1 + (f_GHz/fp)^2)) + ...
        ((f_GHz/fs) * (eps1 - eps2) / (1 + (f_GHz/fs)^2));

    eta_val = (2 + eps_prime) / eps_dprime;

    Kl_base = (0.819 * f_GHz) / (eps_dprime * (1+eta_val^2));

    correction_factor = A1 * exp(-(f_GHz - f1)^2 / sigma1) + ...
        A2 * exp(-(f_GHz - f2)^2 / sigma2) + A3;
    
    KL_val = Kl_base * correction_factor;

    if any(valid_mask)
        L_cloud(valid_mask) = (KL_val *L_content) ./ sind(el_deg(valid_mask));
    end

end

