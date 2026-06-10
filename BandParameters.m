function bands = BandParameters()
% BANDPARAMETERS  Per-band downlink SPEC (X / Ka / E-W).
%   Struct-of-structs (same pattern as GroundStations): bands.X / .Ka / .EW
%   Anchored to SPEC v4.0 + papers: Saito 2016 [X], Kepler v1.1 [Ka],
%   Kallfass 2024 / Schoch 2018 [E-W].
%
%   *** TWO POWERS - never conflate ***
%     Ptx_DC_W    -> EnergyModel term-2  (J/bit = Ptx_DC / Rb)   [22 / 40 / 60 W]
%     Ptx_RF_dBW  -> link-budget EIRP    (EIRP = Ptx_RF + Gtx)
%
%   RX antenna is NOT here: it is a COMMON GS dish (cfg.rx_dish_m, cfg.rx_eff),
%   so G/T emerges per-band from frequency. Only per-band Tsys_K lives here.
%
%   reqEbNo_dB caveat: the three values come from DIFFERENT BER/FEC bases
%   (X: 64APSK Es/No; Ka: DVB-S2 QEF; E-W: QPSK BER 1e-3 uncoded). NOT a
%   strict apples-to-apples threshold -> thesis needs a footnote on this.

% ---------------- X-band (Hodoyoshi-4, Saito 2016) ----------------
bands.X.name       = 'X';
bands.X.freq_Hz    = 8.16e9;    % carrier 8.16 GHz (Saito 2016 Sec.2.2)
bands.X.Ptx_DC_W   = 22;        % Tx DC supply (Saito 2016 Sec.2.4) -> EnergyModel
bands.X.Ptx_RF_dBW = 3.0;       % 33 dBm = 2 W at Tx port (Saito 2016 Sec.2.4) -> link
bands.X.Gtx_dBi    = 13.5;      % 2x2 patch MGA, RHCP (Saito 2016 Fig.4)
bands.X.Rb_Mbps    = 505;       % 64APSK 4/5 single-pol demonstrated (Saito 2013)
bands.X.reqEbNo_dB = 12.7;      % Es/No 19.5 dB (64APSK 4/5) - 10log10(6*4/5)
bands.X.Tsys_K     = 150;       % clear-sky GS noise temp [PARK - doc says ~120 K]
bands.X.Ltx_dB     = 1.0;       % Tx system/feeder loss [PARK]
bands.X.Lrx_dB     = 1.0;       % Rx system/feeder loss [PARK]

% ---------------- Ka-band (Kepler Ka/S Terminal v1.1) ----------------
bands.Ka.name       = 'Ka';
bands.Ka.freq_Hz    = 26.0e9;   % 25.5-27.0 GHz EESS, center 26
bands.Ka.Ptx_DC_W   = 40;       % full-duplex DC (Kepler v1.1) -> EnergyModel
bands.Ka.Ptx_RF_dBW = 3.0;      % 33 dBm (upper of 31-33 dBm) -> link
bands.Ka.Gtx_dBi    = 24.0;     % 256-element phased array (Kepler v1.1)
bands.Ka.Rb_Mbps    = 1750;     % 32APSK + ACM, DVB-S2 (Kepler v1.1)
bands.Ka.reqEbNo_dB = 7.0;      % 32APSK 3/4 DVB-S2 QEF [PARK - ACM adaptive, least certain]
bands.Ka.Tsys_K     = 200;      % clear-sky GS noise temp [PARK]
bands.Ka.Ltx_dB     = 1.0;
bands.Ka.Lrx_dB     = 1.0;

% ---------------- E/W-band (EIVE, Kallfass 2024 / Schoch 2018) ----------------
bands.EW.name       = 'EW';
bands.EW.freq_Hz    = 73.5e9;   % E-band center for attenuation (Schoch 2018 T3)
bands.EW.Ptx_DC_W   = 60;       % mid of 54.5-65.5 W payload (Kallfass 2024) -> EnergyModel
bands.EW.Ptx_RF_dBW = 3.0;      % 33 dBm -> EIRP 66 dBm (Schoch). ALT: 4.77 dBW = 3 W (Kallfass measured)
bands.EW.Gtx_dBi    = 33.0;     % horn + dielectric lens (Kallfass 2024)
bands.EW.Rb_Mbps    = 5000;     % QPSK 90% avail, conservative (Schoch 2018)
bands.EW.reqEbNo_dB = 7.0;      % QPSK BER 1e-3 (Schoch 2018 Fig.5)
bands.EW.Tsys_K     = 400;      % clear-sky GS noise temp (NF 2dB + feeder + antenna; ref script)
bands.EW.Ltx_dB     = 1.0;
bands.EW.Lrx_dB     = 1.0;

end