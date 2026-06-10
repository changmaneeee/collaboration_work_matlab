function L = LinkBudget(band, gs, sc_data, cfg)

%   Inputs:
%     band    : one band struct from BandParameters (.freq_Hz, .reqEbNo_dB, ...)
%     gs      : one GS struct from GroundStations (.lat_deg/.alt_m/ITU params)
%     sc_data : geometry for this GS (.el_deg/.range_m/.mask) + .ebno_fspl_dB (this band)
%     cfg     : config (.avail, .L_pol_dB, .rx_dish_m, .rx_eff, ...)
%
%   Output struct L:
%     .L_atm_dB      : total atmospheric loss vs elevation [dB] (vector)
%     .margin_dB     : link margin vs elevation [dB] (vector; -Inf where not visible)
%     .margin_min_dB : worst-case margin over visible samples [dB]
%     .margin_mean_dB: mean margin over visible samples [dB]
%     .closure_flag  : 1 if link closes over the WHOLE visible pass, else 0

    el      = sc_data.el_deg(:);
    mask    = sc_data.mask(:);
    ebno_fspl = sc_data.ebno_fspl_dB(:);

    avail_pct = cfg.avail * 100;
    p_pct     = (1 - cfg.avail) * 100;

    lat   = gs.lat_deg;
    alt   = gs.alt_m;
    rho   = gs.rho_surf;        % surface water-vapour density [g/m^3]  -> gas
    R001  = gs.R_001;           % rain rate 0.01% exceedance [mm/h]     -> rain
    hRain = gs.h_rain_limit_m;  % rain height [m]                       -> rain
    Lwat  = gs.L_water;         % cloud liquid water content [kg/m^2]   -> cloud
    Nwet  = gs.N_wet;           % wet refractivity [N-units]            -> scintillation

    %--- (B) Slice to the visible window ONLY
    idx_vis = find(mask);
    el_vis  = el(mask);
    n_vis   = numel(el_vis);


    if n_vis == 0
        L.L_atm_dB      = [];
        L.margin_dB     = [];
        L.margin_min_dB = -Inf;
        L.margin_mean_dB= -Inf;
        L.closure_flag  = 0;
        return;
    end

    
    %% Attenuation

    % Gaseous Attenuation
    L_gas = CalcZenithGasLoss(band.freq_Hz, alt, el_vis, rho);

    % Rain Attenuation
    L_rain = CalcRainLoss(band.freq_Hz, R001, el_vis, hRain, alt, lat, avail_pct);

    % Cloud Attenuation
    L_cloud = CalcCloudLoss(band.freq_Hz, el_vis, Lwat);

    %Scintillation fade
    L_scint = CalcScintillation(band.freq_Hz, el_vis, cfg.rx_dish_m, cfg.rx_eff, Nwet, p_pct);

    %Total atmospheric loss
    L_atm = L_gas + sqrt( (L_rain + L_cloud).^2 + L_scint.^2 ) + cfg.L_pol_dB;

    

    ebno_vis = ebno_fspl(mask);                          % FSPL Eb/No, visible-only [dB]

    % Margin = available - atmospheric loss - required Eb/No, per elevation.
    margin = ebno_vis - L_atm - band.reqEbNo_dB;          % [dB] per-el vector

    % Closure: link must hold over the WHOLE visible window (worst sample >= 0).
    margin_min  = min(margin);
    margin_mean = mean(margin);
    closure     = (margin_min >= 0);                      % 1 if even the worst sample closes

    % --- assemble return struct ---
    L.L_atm_dB       = L_atm;            % per-el atmospheric loss [dB]
    L.margin_dB      = margin;           % per-el margin [dB]
    L.margin_min_dB  = margin_min;       % worst-case margin [dB]
    L.margin_mean_dB = margin_mean;      % mean margin [dB]
    L.closure_flag   = double(closure);  % 1/0
    L.idx_vis        = idx_vis;          % map margin(k) back to full time axis (from block 2)
    L.el_vis_deg     = el_vis;           % elevation per margin sample [deg]
end