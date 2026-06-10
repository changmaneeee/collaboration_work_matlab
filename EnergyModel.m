function e = EnergyModel(band)
% ENERGYMODEL  Joules per useful bit for one band (band-only, GS-independent).
%
%   Primary thesis metric. Per the framing lock-in, the band ranking is
%   governed entirely by term-2 = P_tx_DC / R_b (term-1 cancels analytically
%   across bands, so it is band-independent and left as NaN here).
%
%   Inputs : band struct from BandParameters() -> uses .Ptx_DC_W, .Rb_Mbps
%   Output : struct e with
%              .J_per_bit_nJ : term-2 in nJ/bit  (the headline number)
%              .term2_J_per_bit : term-2 in J/bit (SI)
%              .term1_J_per_bit : SAR observation-power term [NaN - deferred]
%              .J_per_bit       : total J/bit (= term2 while term1 is NaN)
%
%   Units: P_tx_DC in W, R_b in Mbps -> bps. J/bit = W / (bits/s) = J/bit.

    Rb_bps = band.Rb_Mbps * 1e6;                 % Mbps -> bps

    % --- term-2: transmit DC power per delivered bit (band ranking driver) ---
    e.term2_J_per_bit = band.Ptx_DC_W / Rb_bps;  % [J/bit]
    e.J_per_bit_nJ    = e.term2_J_per_bit * 1e9; % [nJ/bit] headline

    % --- term-1: SAR observation power per bit (band-independent) [deferred] ---
    % T_obs cancels analytically in the band comparison, so term-1 does NOT
    % affect ranking. Wire to SAR Mission Baseline (NIMBUS P_obs, duty) later.
    e.term1_J_per_bit = NaN;

    % --- total (= term-2 while term-1 deferred) ---
    e.J_per_bit = e.term2_J_per_bit;             % [J/bit]
end