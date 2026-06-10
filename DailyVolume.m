function v = DailyVolume(band, gs, geo_gs, cfg)
% DAILYVOLUME  Geometric maximum daily downlink volume for one (band, GS).
%
%   Per design decision (b): this returns the GEOMETRIC CEILING only -
%   contact-time x nominal bit rate - and does NOT apply link closure.
%   Closure gating (x closure_flag) happens later in main Phase 4, keeping
%   this module decoupled from LinkBudget.
%
%   Inputs:
%     band   : band struct (uses .Rb_Mbps)
%     gs     : GS struct  [reserved - unused in the geometric ceiling; kept for
%              future onboard-storage / latitude-analytic extensions]
%     geo_gs : per-GS geometry = geo.(gsName) from main Phase 2, with
%              .intervals (accessIntervals table; .Duration in seconds) and
%              .n_passes (pass count over the whole sim window)
%     cfg    : config (uses .sim_duration_days)
%
%   Output struct v:
%     .D_day_GB          : geometric max volume per day [GB] (decimal, 1 GB = 1e9 byte)
%     .passes_per_day    : average passes per day
%     .avg_contact_s     : mean contact (pass) duration [s]
%     .contact_per_day_s : total contact time per day [s]
%     .total_contact_s   : total contact time over the whole window [s]
%     .n_passes          : pass count over the whole window
%
%   NOTE (fidelity): volume here scales LINEARLY with R_b (same contact time
%   for every band, since contact is geometric). Low-elevation seconds where a
%   high band would not close are NOT removed here - that is the binary
%   closure_flag in Phase 4. See integration note on fractional-window closure.

    nDays = cfg.sim_duration_days;

    % --- guard: GS that never sees the satellite above the mask -> zero volume ---
    if isempty(geo_gs.intervals) || geo_gs.n_passes == 0
        v.D_day_GB          = 0;
        v.passes_per_day    = 0;
        v.avg_contact_s     = 0;
        v.contact_per_day_s = 0;
        v.total_contact_s   = 0;
        v.n_passes          = 0;
        return;
    end

    % --- contact time from access intervals (grid-independent AOS/LOS) ---
    dur = geo_gs.intervals.Duration;          % accessIntervals Duration column
    if isduration(dur), dur = seconds(dur); end   % MATLAB: ensure seconds as double
    total_contact_s   = sum(dur);              % [s] over whole window
    n_passes          = geo_gs.n_passes;
    contact_per_day_s = total_contact_s / nDays;   % [s/day]
    passes_per_day    = n_passes / nDays;          % [1/day]
    avg_contact_s     = total_contact_s / n_passes;% [s/pass]

    % --- geometric max volume: full nominal rate over all contact seconds ---
    % bits = contact_s * Rb[bps];  bytes = bits/8;  GB = bytes/1e9
    Rb_bps     = band.Rb_Mbps * 1e6;
    D_day_bits = contact_per_day_s * Rb_bps;
    D_day_GB   = D_day_bits / 8 / 1e9;             % decimal GB

    % --- pack ---
    v.D_day_GB          = D_day_GB;
    v.passes_per_day    = passes_per_day;
    v.avg_contact_s     = avg_contact_s;
    v.contact_per_day_s = contact_per_day_s;
    v.total_contact_s   = total_contact_s;
    v.n_passes          = n_passes;
end