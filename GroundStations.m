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
%
%   Field conventions
%   -----------------
%       id              selection index (1-5), matches legacy main.m
%       name            station name
%       lat_deg         latitude                              [deg]
%       lon_deg         longitude                             [deg]
%       alt_m           altitude above sea level              [m]
%       rho_surf        surface water-vapour density,
%                       5% annual exceedance (P.836-6)        [g/m^3]
%       h_rain_limit_m  rain height, mean annual h0 + 0.36 km
%                       (P.839-4)                             [m]
%       R_001           rain rate, 0.01% annual exceedance
%                       (P.837-8)                             [mm/h]
%       L_water         integrated cloud liquid water,
%                       5% annual exceedance (P.840-9)        [kg/m^2]
%       N_wet           wet-term radio refractivity,
%                       annual median 50% (P.453-14)          [N-units]
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
Stuttgart.rho_surf       = 12.6689;     % P.836-6, 5% (Eq.68 freeze; legacy 0.1%: 16.0423)
Stuttgart.h_rain_limit_m = 3028.1;      % ITU-R P.839
Stuttgart.R_001          = 29.7784;     % ITU-R P.837 [mm/h]
Stuttgart.L_water        = 0.2801;      % P.840-9, 5% (Eq.67 freeze; legacy 0.1%: 0.6278) [kg/m^2]
Stuttgart.N_wet          = 45.3936;     % P.453-14, annual median 50% (Sec.2.4.1; legacy 0.1%: 101.2678)
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
KAU.rho_surf       = 21.0049;   % P.836-6, 5% (legacy 0.1%: 23.3458)
KAU.h_rain_limit_m = 3897.6;
KAU.R_001          = 60.5478;
KAU.L_water        = 0.2068;    % P.840-9, 5% (legacy 0.1%: 0.6597)
KAU.N_wet          = 47.5024;   % P.453-14, median 50% (legacy 0.1%: 143.1342)
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
Singapore.rho_surf       = 22.1651;   % P.836-6, 5% (legacy 0.1%: 23.6412)
Singapore.h_rain_limit_m = 4972.3;
Singapore.R_001          = 100.0675;
Singapore.L_water        = 0.3514;    % P.840-9, 5% (legacy 0.1%: 1.1121)
Singapore.N_wet          = 131.9951;  % P.453-14, median 50% (legacy 0.1%: 156.4038)
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
UAE.rho_surf       = 25.3561;   % P.836-6, 5% (legacy 0.1%: 30.0792)
UAE.h_rain_limit_m = 4620.5;
UAE.R_001          = 20.4915;
UAE.L_water        = 0.2011;    % P.840-9, 5% (legacy 0.1%: 0.6413)
UAE.N_wet          = 88.1356;   % P.453-14, median 50% (legacy 0.1%: 172.6908)
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
SvalSat.rho_surf       = 5.1977;    % P.836-6, 5% (legacy 0.1%: 6.7769)
SvalSat.h_rain_limit_m = 1914.7;
SvalSat.R_001          = 9.3946;
SvalSat.L_water        = 0.0394;    % P.840-9, 5% (legacy 0.1%: 0.1701)
SvalSat.N_wet          = 19.2665;   % P.453-14, median 50% (legacy 0.1%: 48.7323)
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
