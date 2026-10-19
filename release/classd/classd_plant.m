function [dx, y] = classd_plant(x, g, ipos, eload, Pcd)
%CLASSD_PLANT  Ideal-switch power stage of "Class D Rev B.plecs" (body of a MATLAB Function block).
%
% Six half bridges ("Half Bridge A".."F") on one DC bus. A, B, C drive the positive output
% node P through the leg inductors, D, E, F drive the negative node N. The load sits between
% P and N (Aout / Vout). The DC bus is the 18 mF bank (with ESR, plus the half-bridge local
% 10 uF capacitors lumped in) fed by the "AC_DC" block: a 100 A current source clamped by a
% 400 V zener and a series diode, i.e. a 400 V supply with a 100 A current limit.
%
% IGBTs/diodes are ideal: a leg with both gates off (dead time) is clamped by the diode chosen
% by the sign of its current. The IGBT/diode forward drops, snubbers, 82 nF film capacitors
% and the thermal network are not modelled.
%
% States  x = [iA; iB; iC; iD; iE; iF; vCB; vRC]
%   iA..iF  leg currents, positive flowing out of the leg midpoint ("Am1" in each half bridge)
%   vCB     DC bank capacitor voltage (behind its ESR)
%   vRC     voltage of the optional parallel R||C section of the load
% Inputs
%   g      12 gates [A_top A_bot B_top B_bot ... F_top F_bot]
%   ipos   6 booleans, leg current > 0 (zero-crossing events for the diodes)
%   eload  voltage of the optional source in series with the load (V)
% Outputs
%   y = [Vout; Iout; Vbus; Isupply; iA; iB; iC; iD; iE; iF; vP; vN]
%#codegen

P = Pcd;   % parameter struct from the workspace

il = x(1:6);
vCB = x(7);
vRC = x(8);
gd = double(g);
pd = double(ipos);

u = zeros(6, 1);
for k = 1:6
    top = gd(2*k - 1);
    bot = gd(2*k);
    if top > 0.5
        u(k) = 1;
    elseif bot > 0.5
        u(k) = 0;
    elseif pd(k) > 0.5          % current out of the midpoint -> bottom diode conducts
        u(k) = 0;
    else
        u(k) = 1;
    end
end

% --- DC bus: bank (vCB behind Resr) + current-limited supply --------------------------------
ibr = sum(u .* il);                        % current drawn from DC+ by the six legs
v1 = vCB + P.Resr * (P.Idc - ibr);         % bus voltage if the supply delivers its full Idc
if v1 <= P.Vz
    isup = P.Idc;
    vbus = v1;
else
    % zener conducting: isup = Idc - (vbus - Vz)/Rz
    vbus = (vCB + P.Resr * (P.Idc + P.Vz / P.Rz - ibr)) / (1 + P.Resr / P.Rz);
    isup = P.Idc - (vbus - P.Vz) / P.Rz;
    if isup < 0                              % series diode blocks reverse current
        isup = 0;
        vbus = vCB - P.Resr * ibr;
    end
end

% --- AC side: leg inductors into nodes P / N, load between P and N --------------------------
e = u * vbus - P.Rleg .* il;               % leg EMF behind each inductor
a = 1 ./ P.Lleg;
AP = sum(a(1:3));
AN = sum(a(4:6));
SP = sum(a(1:3) .* e(1:3));
SN = sum(a(4:6) .* e(4:6));
iL = sum(il(1:3));                         % load current (P -> N)
if P.has_rc > 0.5
    vrc = vRC;
else
    vrc = 0;
end
V0 = P.Rload * iL + vrc + P.E_on * eload;
diL = (SP / AP - SN / AN - V0) / (P.Lload + 1 / AP + 1 / AN);
vP = (SP - diL) / AP;
vN = (SN + diL) / AN;

dx = zeros(8, 1);
dx(1:3) = a(1:3) .* (e(1:3) - vP);
dx(4:6) = a(4:6) .* (e(4:6) - vN);
dx(7) = (isup - ibr) / P.CB;
if P.has_rc > 0.5
    dx(8) = (iL - vRC / P.Rpar) / P.Cpar;
end

y = [vP - vN; iL; vbus; isup; il; vP; vN];
end
