%% Main
% Multi-band Downlink Simulatior

clear; clc; close all;


%% ============================ USER SETTINGS ============================
% Central config struct. Everything the operator might change lives here,
% split into SWEEP axes (varied to answer the thesis question) and FIXED
% values (set once; changing them blurs the comparison).

% --- SWEEP axes: vary these and compare results (this IS the thesis question) ---
cfg.gs_selection   = 'all';             % 'all' = every station in GroundStations(); or a cell e.g. {'KAU','Singapore'}
cfg.bands_selected = {'X','Ka','EW'};   % subset of fieldnames(BandParameters); cell because each entry is a name (text), not a number
cfg.avail          = 0.999;             % link availability (single for Step A). [Step C] becomes a vector + innermost loop.
                                        % NOTE: avail drives the ITU-R loss inputs via exceedance p = 1 - avail (e.g. 0.999 -> p = 0.1%).

% --- FIXED: Keplerian orbital elements (NOT swept; this is the mission baseline orbit) ---
% satelliteScenario's satellite() takes all six classical elements:
%   satellite(sc, a, ecc, inc, raan, argp, nu)
cfg.kepler.alt_km  = 350;            % altitude input; converted to semi-major axis a = R_earth + alt at Step B (a is the actual element)
cfg.kepler.ecc     = 0;              % eccentricity (0 = circular orbit)
cfg.kepler.inc_deg = 98;             % inclination [deg] (~98 = sun-synchronous for this altitude)
cfg.kepler.raan_deg = 0;             % right ascension of ascending node [deg] (orbit-plane orientation vs equator)
cfg.kepler.argp_deg = 0;             % argument of periapsis [deg] (undefined for a circular orbit, but satellite() still requires it -> set 0)
cfg.kepler.nu_deg   = 0;             % true anomaly at epoch [deg] (where the satellite sits on the orbit at start time)


cfg.start_time = datetime(2026,5,28,0,0,0);   % UTC scenario epoch (fixed for reproducibility)

% R_b and rx_dish are NOT here: they are per-band, so they live in BandParameters
% (R_b: single value per band, EW = 5 Gbps; rx_dish: per-band realistic dish, value still parked).

% One satelliteScenario at this step; DailyVolume gets pass AOS/LOS from the
% same scenario via accessIntervals (interpolated, so one grid suffices).
cfg.sample_time_s     = 3;           % scenario sample step [s]
cfg.sim_duration_days = 7;           % orbit-geometry window [days]

cfg.rx_dish_m   = 1.2;
cfg.rx_eff      = 0.6;
cfg.tx_eff      = 0.6;

% --- FIXED: link closure thresholds / margins ---
cfg.req_EbNo_dB    = 10;             % required Eb/No for link closure [dB]. [PARK] reference script used 7 (depends on chosen modulation)
cfg.elev_mask_deg  = 5;              % minimum elevation for visibility [deg]; below this the station cannot see the satellite
cfg.L_pol_dB       = 0.5;            % polarization mismatch loss [dB]

% --- Execution toggles (turn phases on/off for faster partial runs / overnight batches) ---
cfg.run_link   = true;               % Phase 2: per-(GS,band) LinkBudget
cfg.run_energy = true;               % Phase 3a: per-band EnergyModel
cfg.run_volume = true;               % Phase 3b: per-(GS,band) DailyVolume
cfg.save_results = false;            % save results .mat at the end
cfg.show_plots   = false;            % draw plots at the end



%% ============================ PHASE 1: Input layer ============================
fprintf('\n=== Phase 1: Input layer ===\n');
bands_all       = BandParameters();
stations_all    = GroundStations();

if ischar(cfg.gs_selection) && strcmp(cfg.gs_selection, 'all')
    gs_list = fieldnames(stations_all);
elseif iscell (cfg.gs_selection)
    gs_list = cfg.gs_selection(:);
else
    error('main:bad_GS_insert','gs_selection must be "all" or a cell array of names');
end

% Validate: every requested station / band actually exists ---------------
for g = 1:numel(gs_list)
    if ~isfield(stations_all, gs_list{g})
        error('main:bad_GS','GS "%s" not in Groud Stations()', gs_list{g});
    end
end

for k = 1:numel(cfg.bands_selected)
    if ~isfield(bands_all, cfg.bands_selected{k})
        error('main:bad_Band','band "%s" not in Band Parameters()', cfg.bands_selected{k});
    end
end

fprintf('  GS (%d) : %s\n', numel(gs_list), strjoin(gs_list', ', '));
fprintf('  Bands   : %s\n', strjoin(cfg.bands_selected, ', '));
fprintf('  Orbit   : alt=%d km, inc=%d deg | avail=%.3f\n', ...
        cfg.kepler.alt_km, cfg.kepler.inc_deg, cfg.avail);



%% ===================== PHASE 2: Orbit, Geometry & RF link =====================
% B-merged: one GS loop. Geometry/access (band-independent) built at the TOP of
% each GS iteration; the inner band loop reuses it for the frequency-dependent
% RF chain. Orbit propagation (satellite) stays ONCE, outside all loops.
fprintf('\n=== Phase 2: Orbit, Geometry & RF link ===\n');

% --- Scenario + satellite: ONCE (orbit is GS- and band-independent) ---
startTime = cfg.start_time;
stopTime  = startTime + days(cfg.sim_duration_days);
sc  = satelliteScenario(startTime, stopTime, cfg.sample_time_s);

R_earth = 6378.137e3;                          % [m]
a_m     = R_earth + cfg.kepler.alt_km*1e3;     % semi-major axis [m] = Re + alt
sat = satellite(sc, a_m, cfg.kepler.ecc, cfg.kepler.inc_deg, ...
                cfg.kepler.raan_deg, cfg.kepler.argp_deg, cfg.kepler.nu_deg);

geo         = struct();   % per-GS geometry + access (band-independent)
linkResults = struct();   % linkResults.(band).(gs)

for g = 1:numel(gs_list)
    gsName = gs_list{g};
    gs     = stations_all.(gsName);

    % --- (1) Geometry + access: band-INDEPENDENT, computed ONCE per GS ---
    gsO = groundStation(sc, gs.lat_deg, gs.lon_deg, ...
                        "Name",              gs.name, ...
                        "Altitude",          gs.alt_m, ...
                        "MinElevationAngle", cfg.elev_mask_deg);

    [~, el, range, t] = aer(gsO, sat);
    geo.(gsName).t       = t(:);
    geo.(gsName).el_deg  = el(:);
    geo.(gsName).range_m = range(:);
    geo.(gsName).mask    = el(:) >= cfg.elev_mask_deg;

    ac = access(sat, gsO);
    geo.(gsName).intervals = accessIntervals(ac);
    geo.(gsName).n_passes  = height(geo.(gsName).intervals);

    fprintf('  [%-14s] n_passes=%2d | visible=%6.0f s\n', ...
            gsName, geo.(gsName).n_passes, sum(geo.(gsName).intervals.Duration));

    % --- (2) RF link: band-DEPENDENT, reuse the geometry above ---
    if cfg.run_link
        for k = 1:numel(cfg.bands_selected)
            bName = cfg.bands_selected{k};
            band  = bands_all.(bName);

            % [FIX 2026-06-11] gs0 (digit zero) -> gsO (capital letter O).
            % The ground-station object is defined as gsO at the top of this GS
            % loop; 'gs0' was never defined, so with the leading 'clear' every
            % run aborted here with "Unrecognized function or variable 'gs0'".
            % (Code Analyzer cannot catch undefined variables in scripts.)
            gmbSat  = gimbal(sat);
            gmbGS   = gimbal(gsO);
            pointAt(gmbSat, gsO);
            pointAt(gmbGS, sat);
            
            %---Transmitter-------------------------------------
            c = physconst('LightSpeed');
            tx = transmitter(gmbSat, ...
                "Frequency", band.freq_Hz, ...
                "Power",     band.Ptx_RF_dBW,...
                "BitRate",   band.Rb_Mbps,...
                "SystemLoss",band.Ltx_dB);

            D_tx = (c/(pi*band.freq_Hz)) * sqrt(10^(band.Gtx_dBi/10) / cfg.tx_eff);
            gaussianAntenna(tx, "DishDiameter", D_tx, "ApertureEfficiency", cfg.tx_eff);


            %---Receiver----------------------------------------
            waveLen = c / band.freq_Hz;
            Grx_dBi = 10*log10( cfg.rx_eff * ((pi*cfg.rx_dish_m)/waveLen)^2 );
            GoT_dBK = Grx_dBi - 10*log10(band.Tsys_K);
            rx = receiver(gmbGS, ...
                "GainToNoiseTemperatureRatio", GoT_dBK, ...
                "RequiredEbNo", band.reqEbNo_dB, ...
                "SystemLoss", band.Lrx_dB);

            %---Eb/No baseline
            lnk = link(tx, rx);
            [ebno_fspl, ~] = ebno(lnk);

            sc_data = geo.(gsName);
            sc_data.ebno_fspl_dB = ebno_fspl(:);

            linkResults.(bName).(gsName) = LinkBudget(band, gs, sc_data, cfg);

            fprintf('  [%-3s @ %-14s] margin(min/mean)=%6.2f /%6.2f dB | closure=%d\n', ...
                    bName, gsName, ...
                    linkResults.(bName).(gsName).margin_min_dB, ...
                    linkResults.(bName).(gsName).margin_mean_dB, ...
                    linkResults.(bName).(gsName).closure_flag);

        end
    end
end


%% ===================== PHASE 3a: Energy model (band-only, GS-independent) =====================

fprintf('\n=== Phase 3a: Energy model (per band) ===\n');

energyResults = struct();   % energyResults.(band) only - no GS axis
if cfg.run_energy
    for k = 1:numel(cfg.bands_selected)
        bName = cfg.bands_selected{k};
        band  = bands_all.(bName);
        energyResults.(bName) = EnergyModel(band);     % .J_per_bit_nJ / .term1 / .term2
        fprintf('  [%-3s] J/bit = %5.1f nJ/bit (term2 = P_DC/R_b)\n', ...
                bName, energyResults.(bName).J_per_bit_nJ);
    end
end

%% ===================== PHASE 3b: Daily data volume (GS x band) =====================
fprintf('\n=== Phase 3b: Daily data volume (per GS x band) ===\n');

volumeResults = struct();
if cfg.run_volume
    for g = 1:numel(gs_list)
        gsName = gs_list{g};
        gs     = stations_all.(gsName);
        for k = 1:numel(cfg.bands_selected)
            bName = cfg.bands_selected{k};
            band  = bands_all.(bName);
            % pass geometry already computed in Phase 2 -> reuse geo.(gsName)
            volumeResults.(bName).(gsName) = DailyVolume(band, gs, geo.(gsName), cfg);
            fprintf('  [%-3s @ %-14s] D_day = %7.1f GB | passes/day = %4.1f\n', ...
                    bName, gsName, ...
                    volumeResults.(bName).(gsName).D_day_GB, ...
                    volumeResults.(bName).(gsName).passes_per_day);
        end
    end
end

%% ===================== PHASE 4: Assemble results + closure correction + self-check =====================
fprintf('\n=== Phase 4: Results assembly ===\n');

results = struct();
results.cfg     = cfg;                 % freeze the config that produced these results (reproducibility)
results.gs_list = gs_list;
results.bands   = cfg.bands_selected;
results.link    = linkResults;         % .(band).(gs) : margin/closure  (may be empty if run_link=false)
results.energy  = energyResults;       % .(band)      : J/bit            (NO gs axis - GS-invariant)
results.volume  = volumeResults;       % .(band).(gs) : geometric max volume (closure NOT yet applied)

% --- Closure correction (decision (b)): effective volume = geometric volume x closure_flag ---
% DailyVolume returned the GEOMETRIC max (all visible seconds). Here we gate it by whether
% the link actually closes, keeping the two modules decoupled.
if cfg.run_link && cfg.run_volume
    for k = 1:numel(cfg.bands_selected)
        bName = cfg.bands_selected{k};
        for g = 1:numel(gs_list)
            gsName = gs_list{g};
            closes = results.link.(bName).(gsName).closure_flag;          % 1/0
            Dgeom  = results.volume.(bName).(gsName).D_day_GB;
            results.volume.(bName).(gsName).D_day_eff_GB = Dgeom * closes; % effective = gated
        end
    end
end


% --- Self-check: structural invariants (catches wiring bugs early) ---
fprintf('\n  --- Self-check ---\n');
% (1) energy must have NO gs sub-field (GS-invariance)
for k = 1:numel(cfg.bands_selected)
    bName = cfg.bands_selected{k};
    assert(isfield(results.energy, bName), 'energy missing band %s', bName);
    assert(isscalar(results.energy.(bName).J_per_bit_nJ), 'energy.%s not scalar', bName);
end
% (2) volume must have BOTH axes
for k = 1:numel(cfg.bands_selected)
    bName = cfg.bands_selected{k};
    for g = 1:numel(gs_list)
        assert(isfield(results.volume.(bName), gs_list{g}), ...
               'volume missing %s/%s', bName, gs_list{g});
    end
end
fprintf('  OK: energy=band-only, volume=band x gs, %d bands x %d GS\n', ...
        numel(cfg.bands_selected), numel(gs_list));

% --- Optional save ---
if cfg.save_results
    fname = sprintf('results_%s.mat', datestr(now,'yyyymmdd_HHMMSS'));
    save(fname, 'results');
    fprintf('  saved -> %s\n', fname);
end

fprintf('\n=== main_v2 complete ===\n');






