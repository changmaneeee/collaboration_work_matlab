function [stations, info] = ApplyAvailabilityInputs(stations, gs_list, avail, verbose)
% APPLYAVAILABILITYINPUTS  Availability-dependent ITU-R inputs (P.618-14 Eq.65/66).
%
%   [stations, info] = ApplyAvailabilityInputs(stations, gs_list, avail) overrides,
%   for every station named in gs_list, the availability-dependent ITU-R inputs of
%   the GroundStations() struct with the values Rec. ITU-R P.618-14 requires at the
%   requested link availability, read from availability_input_candidates.csv
%   (located next to this file):
%
%       L_water   cloud liquid water  : L(5%) frozen for p < 5% (Eq.(67)),
%                                       actual L(p) for p >= 5%
%       rho_surf  water-vapour density: rho(5%) frozen for p < 5% (Eq.(68)),
%                                       actual rho(p) for p >= 5%
%       N_wet     scintillation input : annual median (50%), availability-invariant
%
%   and attaches per-station tags consumed downstream:
%
%       .rain_included  logical  true  -> Eq.(65): rain term via P.618-14 Step 10
%                                false -> Eq.(66): p > 5%, rain term EXCLUDED
%                                         (LinkBudget skips CalcRainLoss)
%       .combination    char     'Eq.(65)' or 'Eq.(66) no-rain'
%       .avail_pct, .p_pct, .scint_a_p   (informational)
%
%   R_001 and h_rain_limit_m are availability-INVARIANT by definition (0.01% rain
%   rate / mean-annual rain height) and are NOT overridden; they are cross-checked
%   against the CSV and a warning is raised on mismatch.
%
%   avail is a fraction. Valid values are exactly those tabulated in the CSV
%   (currently: 0.70 0.80 0.90 0.95 0.98 0.99 0.995 0.998 0.999 0.9995 0.9999);
%   any other value raises an error listing the valid set. Works identically for a
%   single station, a subset, or all stations (gs_list = fieldnames(stations)).
%
%   ApplyAvailabilityInputs(..., verbose=false) suppresses the printed table.
%
%   See also GROUNDSTATIONS, LINKBUDGET, EXTRACTITUPERCENTILEINPUTS.

if nargin < 4, verbose = true; end
if ischar(gs_list) || isstring(gs_list), gs_list = cellstr(gs_list); end

csv_path = fullfile(fileparts(mfilename('fullpath')), 'availability_input_candidates.csv');
if ~isfile(csv_path)
    error('ApplyAvailabilityInputs:no_csv', ...
        'availability_input_candidates.csv not found next to ApplyAvailabilityInputs.m (%s)', csv_path);
end
T = readtable(csv_path, 'TextType', 'char');

avail_pct = avail * 100;
tol = 1e-6;
rows_avail = abs(T.avail_pct - avail_pct) < tol;
if ~any(rows_avail)
    valid = unique(T.avail_pct);
    error('ApplyAvailabilityInputs:bad_avail', ...
        ['cfg.avail = %.6g is not tabulated in availability_input_candidates.csv.\n' ...
         'Valid availabilities (fractions): %s'], avail, mat2str(valid.'/100));
end

Ta = T(rows_avail, :);
info.avail_pct   = Ta.avail_pct(1);
info.p_pct       = Ta.p_pct(1);
info.combination = Ta.combination{1};
info.rain_included = ~strcmpi(Ta.rain_term{1}, 'excluded');
info.scint_a_p   = Ta.scint_a_p(1);
info.stations    = gs_list(:).';

if verbose
    if info.rain_included, rainTxt = 'Step-10 @ p'; else, rainTxt = 'EXCLUDED (Eq.66, p > 5%)'; end
    fprintf('  --- P.618-14 inputs @ avail = %g%% (p = %g%%) | %s | rain term: %s ---\n', ...
            info.avail_pct, info.p_pct, info.combination, rainTxt);
    fprintf('  %-12s %16s %16s %12s %12s %10s\n', ...
            'station', 'L_water[kg/m^2]', 'rho_surf[g/m^3]', 'N_wet[N]', 'R001[mm/h]', 'h_rain[m]');
end

for g = 1:numel(gs_list)
    gsName = gs_list{g};
    if ~isfield(stations, gsName)
        error('ApplyAvailabilityInputs:bad_gs', 'station "%s" not in stations struct', gsName);
    end
    r = strcmp(Ta.station, gsName);
    if ~any(r)
        error('ApplyAvailabilityInputs:gs_not_in_csv', ...
              'station "%s" has no rows in availability_input_candidates.csv', gsName);
    end
    row = Ta(r, :);

    % cross-check the availability-invariant fields (catches CSV <-> GroundStations drift)
    if abs(stations.(gsName).R_001 - row.R001_mmh) > 1e-4 || ...
       abs(stations.(gsName).h_rain_limit_m - row.hRain_m) > 1e-1
        warning('ApplyAvailabilityInputs:invariant_mismatch', ...
            '%s: R_001/h_rain in CSV differ from GroundStations() - check both sources', gsName);
    end

    stations.(gsName).L_water       = row.L_input_kgm2;
    stations.(gsName).rho_surf      = row.rho_input_gm3;
    stations.(gsName).N_wet         = row.Nwet_median;
    stations.(gsName).rain_included = info.rain_included;
    stations.(gsName).combination   = info.combination;
    stations.(gsName).avail_pct     = info.avail_pct;
    stations.(gsName).p_pct         = info.p_pct;
    stations.(gsName).scint_a_p     = info.scint_a_p;

    if verbose
        fprintf('  %-12s %16.6f %16.6f %12.4f %12.4f %10.1f\n', gsName, ...
                row.L_input_kgm2, row.rho_input_gm3, row.Nwet_median, row.R001_mmh, row.hRain_m);
    end
end
end
