function out = ExtractITUPercentileInputs(suffixes, alt_mode)
% EXTRACTITUPERCENTILEINPUTS  Extract per-station ITU-R inputs from the local
% official digital-map products (repo-root R-REC-* folders).
%
%   out = ExtractITUPercentileInputs({'01','5','10','20','30'}) returns, for the
%   five WP4 ground stations and each requested probability suffix:
%       out.L(s,k)            P.840-9 integrated cloud liquid water [kg/m^2]
%                             (plain bilinear, identical to official find_L_value.m)
%       out.rho_official(s,k) P.836-6 surface water-vapour density [g/m^3] with the
%                             OFFICIAL altitude scaling (P.836-6 Annex, steps c-e):
%                             rho_i' = rho_i * exp(-(alt0 - alt_i)/vsch_i) at the four
%                             surrounding 1.125-deg grid nodes, alt_i from TOPO_0DOT5
%                             via BICUBIC interpolation, then bilinear of the four
%                             scaled values. (Bicubic for the node altitudes is the
%                             convention that reproduces the verified WP2-v2 anchor
%                             values to machine precision; 'linear' deviates ~0.06.)
%       out.rho_plain(s,k)    P.836-6 plain bilinear (heritage WP2 method, no alt corr.)
%       out.NWET(s,k)         P.453-14 wet-term refractivity [N-units] (plain bilinear)
%
%   Suffix convention (per official P.836 readme): '01'=0.1%, '05'=0.5%, '5'=5%,
%   '10'=10%, '20'=20%, '30'=30%, '50'=50% (median), ...
%
%   alt_mode (optional, default 'station'): altitude used as alt0 in the P.836-6
%   scaling — 'station' = GroundStations alt_m; 'topo' = TOPO_0DOT5 at the site.
%
%   Validation: anchors reproduced by this implementation (see
%   availability_input_candidates.csv and GroundStations.m legacy comments):
%     rho_official 5%  : 12.6688592227883 / 21.0049317640536 / 22.1650973029236 /
%                        25.3561168185756 / 5.19773121617311
%     L 5%             : 0.280128 / 0.2068 / 0.351408 / 0.2011344 / 0.0394
%     rho_plain 0.1%   : 16.0423 / 23.3458 / 23.6412 / 30.0792 / 6.7769  (4 dp)
%     NWET 50%         : 45.3936 / 47.5024 / 131.9951 / 88.1356 / 19.2665
%
%   See also GROUNDSTATIONS, APPLYAVAILABILITYINPUTS.

if nargin < 2, alt_mode = 'station'; end

root = fileparts(mfilename('fullpath'));

% ---------- station set (must match GroundStations.m) ----------
out.names = {'Stuttgart','KAU','Singapore','UAE','SvalSat'};
lats   = [48.74 37.60 1.35 25.23 78.23];
lons   = [9.10 126.86 103.81 55.46 15.41];
alts_m = [432 15 30 10 450];

nS = numel(out.names); nP = numel(suffixes);
out.suffixes = suffixes;
out.L            = nan(nS, nP);
out.rho_official = nan(nS, nP);
out.rho_plain    = nan(nS, nP);
out.NWET         = nan(nS, nP);

% ---------- P.840-9 (cloud liquid water), 0.25 deg, lat 90->-90, lon 0->360 ----------
d840 = fullfile(root, 'R-REC-P.840Part01-0-202308-I!!ZIP-E');

% ---------- P.836-6 (water vapour), 1.125 deg + VSCH + TOPO ----------
b836    = fullfile(root, 'R-REC-P.836-6-201712-I!!ZIP-E');
rhodir  = fullfile(b836, 'P_836_Maps_annual', 'Surface Water Vapor Density', 'RHO Annual Maps');
vschdir = fullfile(b836, 'P_836_Maps_annual', 'Total Columnar Water Content', 'VSCH Annual Maps');
latv = colvec(load(fullfile(rhodir, 'LAT1dot125.txt')), 1);   % 90 .. -90 (descending)
lonv = colvec(load(fullfile(rhodir, 'LON1dot125.txt')), 2);   % 0 .. 360  (ascending)
topo  = load(fullfile(b836, 'TOPO_0DOT5.txt'));               % [km], 363x723 w/ guard cells
tlatv = colvec(load(fullfile(b836, 'TOPOLAT.txt')), 1);       % 90.5 .. -90.5
tlonv = colvec(load(fullfile(b836, 'TOPOLON.txt')), 2);       % -0.5 .. 360.5
if tlatv(1) > tlatv(end), tlatv = flipud(tlatv); topo = flipud(topo); end
topoF = griddedInterpolant({tlatv, tlonv}, topo, 'cubic');   % bicubic (see header note)

% ---------- P.453-14 (N_wet), 0.75 deg, axis files ----------
d453 = fullfile(root, 'R-REC-P.453-14-201908-I!!ZIP-E', 'P.453_NWET_Maps', 'P.453_NWET_Maps_Annual');
nlat = colvec(load(fullfile(d453, 'LAT_N.TXT')), 1);
nlon = colvec(load(fullfile(d453, 'LON_N.TXT')), 2);

for k = 1:nP
    sfx = suffixes{k};

    % --- L (P.840-9): plain bilinear, grid built per official find_L_value.m ---
    fL = fullfile(d840, sprintf('L_%s.TXT', sfx));
    if isfile(fL)
        data = load(fL);
        [rows, cols] = size(data);
        Llat = linspace(90, -90, rows)';
        Llon = linspace(0, 360, cols);
        for s = 1:nS
            out.L(s,k) = interp2(Llon, flip(Llat), flipud(data), mod(lons(s),360), lats(s), 'linear');
        end
    end

    % --- rho (P.836-6): official altitude-corrected + plain ---
    fR = fullfile(rhodir,  sprintf('RHO_%s_v4.txt', sfx));
    fV = fullfile(vschdir, sprintf('VSCH_%s_v4.txt', sfx));
    if isfile(fR)
        rho = load(fR);
        for s = 1:nS
            out.rho_plain(s,k) = bilin_descLat(latv, lonv, rho, lats(s), mod(lons(s),360));
        end
        if isfile(fV)
            vsch = load(fV);
            for s = 1:nS
                lat0 = lats(s); lon0 = mod(lons(s),360);
                switch alt_mode
                    case 'station', alt0 = alts_m(s)/1000;       % [km]
                    case 'topo',    alt0 = topoF(lat0, lon0);    % [km]
                    otherwise, error('alt_mode must be station|topo');
                end
                i = find(latv(1:end-1) >= lat0 & latv(2:end) <= lat0, 1);
                j = find(lonv(1:end-1) <= lon0 & lonv(2:end) >= lon0, 1);
                la = [latv(i) latv(i)   latv(i+1) latv(i+1)];
                lo = [lonv(j) lonv(j+1) lonv(j)   lonv(j+1)];
                rr = [rho(i,j)  rho(i,j+1)  rho(i+1,j)  rho(i+1,j+1)];
                vv = [vsch(i,j) vsch(i,j+1) vsch(i+1,j) vsch(i+1,j+1)];
                aa = topoF(la, lo);
                rc = rr .* exp(-(alt0 - aa) ./ vv);              % P.836-6 Eq.(1) scaling
                fl = (latv(i) - lat0) / (latv(i) - latv(i+1));
                fo = (lon0 - lonv(j)) / (lonv(j+1) - lonv(j));
                out.rho_official(s,k) = rc(1)*(1-fl)*(1-fo) + rc(2)*(1-fl)*fo ...
                                      + rc(3)*fl*(1-fo)     + rc(4)*fl*fo;
            end
        end
    end

    % --- N_wet (P.453-14): plain bilinear, lon -180..180 convention ---
    fN = fullfile(d453, sprintf('NWET_Annual_%s.TXT', sfx));
    if isfile(fN)
        nw = load(fN);
        for s = 1:nS
            lonq = lons(s); if lonq > 180, lonq = lonq - 360; end
            out.NWET(s,k) = bilin_descLat(nlat, nlon, nw, lats(s), lonq);
        end
    end
end
end

function v = colvec(x, dim)
% First column (dim=1) / first row (dim=2) of an axis file, as a column vector.
if isvector(x), v = x(:);
elseif dim == 1, v = x(:,1);
else,            v = x(1,:).';
end
end

function val = bilin_descLat(latv, lonv, data, lat0, lon0)
% Bilinear interpolation with a possibly descending latitude axis.
la = latv; da = data;
if la(1) > la(end), la = flipud(la); da = flipud(da); end
val = interp2(lonv.', la, da, lon0, lat0, 'linear');
end
