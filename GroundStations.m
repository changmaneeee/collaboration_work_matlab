function stations = GroundStations()
% GROUNDSTATIONS  Ground-station ITU-R parameter sets for the WP4 simulator.
%
%   stations = GroundStations() returns a struct-of-structs holding the
%   five global ground stations used in the link/channel analysis:
%
%       stations.Stuttgart   48.74 N,   9.10 E   (WP2 validation baseline)
%       stations.KAU         37.60 N, 126.86 E   (mission baseline, Seoul)
%       stations.Singapore    1.35 N, 103.81 E   (tropical, worst-case rain)
%       stations.UAE         25.23 N,  55.46 E   (arid, high water vapour)
%       stations.SvalSat     78.23 N,  15.41 E   (polar, best-case)
%
%   The ITU-R parameter set for each station characterises the 99.9%
%   availability (0.1% exceedance) condition.  Values are carried over
%   verbatim from the verified WP2 main.m switch-case block.
%
%   Field conventions
%   -----------------
%       id              selection index (1-5), matches legacy main.m
%       name            station name
%       lat_deg         latitude                              [deg]
%       lon_deg         longitude                             [deg]
%       alt_m           altitude above sea level              [m]
%       rho_surf        surface water-vapour density (P.836)  [g/m^3]
%       h_rain_limit_m  rain height (P.839, h0+0.36 km)       [m]
%       R_001           rain rate, 0.01% exceedance (P.837)   [mm/h]
%       L_water         integrated cloud liquid water (P.840) [kg/m^2]
%       N_wet           wet-term radio refractivity (P.453)   [N-units]
%       pass_start      candidate zenith-pass start (UTC)     [datetime]
%       pass_stop       candidate zenith-pass stop  (UTC)     [datetime]
%
%   NOTE
%   ----
%   pass_start / pass_stop are the per-station candidate zenith passes
%   inherited from the WP2 main.m.  They are simulation settings, not
%   physical station properties - LinkBudget may override them.
%
%   See also BANDPARAMETERS, LINKBUDGET.

% =====================================================================
%  1  Stuttgart  -  WP2 link/channel validation baseline
% =====================================================================
Stuttgart = struct();
Stuttgart.id             = 1;
Stuttgart.name           = 'Stuttgart';
Stuttgart.lat_deg        = 48.74;
Stuttgart.lon_deg        = 9.10;
Stuttgart.alt_m          = 432;
Stuttgart.rho_surf       = 16.0423;     % ITU-R P.836
Stuttgart.h_rain_limit_m = 3028.1;      % ITU-R P.839
Stuttgart.R_001          = 29.7784;     % ITU-R P.837 [mm/h]
Stuttgart.L_water        = 0.6278;      % ITU-R P.840 [kg/m^2]
Stuttgart.N_wet          = 101.2678;    % ITU-R P.453
Stuttgart.pass_start     = datetime(2026, 5, 29, 19, 0, 0);
Stuttgart.pass_stop      = datetime(2026, 5, 29, 20, 0, 0);

% =====================================================================
%  2  KAU  -  mission baseline ground station (Seoul / Goyang)
% =====================================================================
KAU = struct();
KAU.id             = 2;
KAU.name           = 'KAU';
KAU.lat_deg        = 37.60;
KAU.lon_deg        = 126.86;
KAU.alt_m          = 15;
KAU.rho_surf       = 23.3458;
KAU.h_rain_limit_m = 3897.6;
KAU.R_001          = 60.5478;
KAU.L_water        = 0.6597;
KAU.N_wet          = 143.1342;
KAU.pass_start     = datetime(2026, 5, 28, 11, 0, 0);
KAU.pass_stop      = datetime(2026, 5, 28, 12, 0, 0);

% =====================================================================
%  3  Singapore SEGS  -  tropical, worst-case rain
% =====================================================================
Singapore = struct();
Singapore.id             = 3;
Singapore.name           = 'Singapore_SEGS';
Singapore.lat_deg        = 1.35;
Singapore.lon_deg        = 103.81;
Singapore.alt_m          = 30;
Singapore.rho_surf       = 23.6412;
Singapore.h_rain_limit_m = 4972.3;
Singapore.R_001          = 100.0675;
Singapore.L_water        = 1.1121;
Singapore.N_wet          = 156.4038;
Singapore.pass_start     = datetime(2026, 5, 24, 1, 0, 0);
Singapore.pass_stop      = datetime(2026, 5, 24, 2, 0, 0);

% =====================================================================
%  4  UAE MBRSC  -  arid, high water vapour
% =====================================================================
UAE = struct();
UAE.id             = 4;
UAE.name           = 'UAE_MBRSC';
UAE.lat_deg        = 25.23;
UAE.lon_deg        = 55.46;
UAE.alt_m          = 10;
UAE.rho_surf       = 30.0792;
UAE.h_rain_limit_m = 4620.5;
UAE.R_001          = 20.4915;
UAE.L_water        = 0.6413;
UAE.N_wet          = 172.6908;
UAE.pass_start     = datetime(2026, 5, 22, 4, 0, 0);
UAE.pass_stop      = datetime(2026, 5, 22, 5, 0, 0);

% =====================================================================
%  5  SvalSat  -  polar (Svalbard, Norway), best-case
% =====================================================================
SvalSat = struct();
SvalSat.id             = 5;
SvalSat.name           = 'Norway_SvalSat';
SvalSat.lat_deg        = 78.23;
SvalSat.lon_deg        = 15.41;
SvalSat.alt_m          = 450;
SvalSat.rho_surf       = 6.7769;
SvalSat.h_rain_limit_m = 1914.7;
SvalSat.R_001          = 9.3946;
SvalSat.L_water        = 0.1701;
SvalSat.N_wet          = 48.7323;
SvalSat.pass_start     = datetime(2026, 5, 29, 21, 0, 0);
SvalSat.pass_stop      = datetime(2026, 5, 29, 22, 0, 0);

% --- Assemble -------------------------------------------------------
stations = struct( ...
    'Stuttgart', Stuttgart, ...
    'KAU',       KAU, ...
    'Singapore', Singapore, ...
    'UAE',       UAE, ...
    'SvalSat',   SvalSat);

end
