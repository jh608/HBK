function [dx, y] = dab_plant(x, gp, gs, ipos, iload, Pdab)
%DAB_PLANT  Ideal-switch power stage of "DAB FPGA.plecs" (body of the MATLAB Function block).
%
% Circuit (as in the PLECS schematic, primary bridge config "Infineon IMZC120R012M2H",
% secondary "Infineon IMZA65R007M2H", transformer config "Electrical"):
%
%   V_dc --R1--+-- DC+  [primary full bridge]  P --Llk(Llkp)--A--+--------------------+
%   (Vin)      |                                                  |                    |
%            Rcin                                          Llk1 (1.3 mH)   R5,Lp(Llk) --+ Tr2 (np:ns, Lm)
%            Cin                                                  |        R2 ---------+
%              |                                    N --Crp-------B--+--------------------+
%   ------- DC- ...
%   Tr2 secondary --Ls(Llk),R3--port3--Asec--Llk2(Llks)-- P [secondary full bridge] DC+ --+-- Co+R_Cout
%   Tr2 secondary --R4--port4--Crs-------------------- N                              +-- Cdc+R_Cdc
%                                                                                     +-- load current
%
% The MOSFETs are ideal switches with ideal anti-parallel diodes: a leg whose gates are both
% off (dead time) is clamped by the diode selected by the sign of its current. Snubbers
% (Csnub/Rsnub), Coss, the 55 pF inter-winding capacitance and the thermal/loss network are
% not modelled (switching dynamics only).
%
% States  x = [i1; ip; is; vCrp; vCrs; vCin; vCo; vCdc]
%   i1   current in the external primary leakage Llk (out of primary bridge P terminal)
%   ip   current in the transformer-internal primary leakage Lp (into Tr2 dot)
%   is   secondary current (out of Tr2 secondary dot, into secondary bridge P terminal)
%   vCrp primary series capacitor voltage, vCrs secondary series capacitor voltage
%   vCin input capacitor, vCo / vCdc the two output capacitors (each behind its ESR)
% Inputs
%   gp    4 gate signals primary  [Q1 (P top) Q2 (P bottom) Q3 (N top) Q4 (N bottom)]
%   gs    4 gate signals secondary, same order
%   ipos  [i1 > 0; is > 0]  (computed outside from the states so that the solver gets a
%         zero-crossing event when a diode current reverses)
%   iload load current drawn from the output node (A)
% Outputs
%   dx  state derivatives
%   y   [Vo; Io; Vin_bridge; i1; is; v_pri_bridge; v_sec_bridge; Pin; i_mag_ext; i_mag]
%#codegen

P = Pdab;   % parameter struct from the workspace

i1 = x(1); ip = x(2); is = x(3);
vCrp = x(4); vCrs = x(5); vCin = x(6); vCo = x(7); vCdc = x(8);

g1 = double(gp);
g2 = double(gs);
ip1 = double(ipos(1)) > 0.5;   % i1 > 0
is1 = double(ipos(2)) > 0.5;   % is > 0

% Leg output state: 1 = midpoint tied to DC+, 0 = tied to DC-.
% The current out of each leg midpoint is: pri P: +i1, pri N: -i1, sec P: -is, sec N: +is.
uPp = leg_state(g1(1), g1(2), ip1);
uNp = leg_state(g1(3), g1(4), ~ip1);
uPs = leg_state(g2(1), g2(2), ~is1);
uNs = leg_state(g2(3), g2(4), is1);

kp = uPp - uNp;          % primary bridge: v_ac = kp * v_dc, i_dc = kp * i_ac
ks = uPs - uNs;          % secondary bridge

% Primary DC node: source Vin behind R1 in parallel with Cin behind R_Cin
idcp = kp * i1;
vin = (P.Vin / P.R1 + vCin / P.RCin - idcp) / (1 / P.R1 + 1 / P.RCin);
vpb = kp * vin;

% Secondary DC node: Co behind R_Cout and Cdc behind R_Cdc in parallel, load current out
idcs = ks * is;
vo = (idcs - iload + vCo / P.RCo + vCdc / P.RCdc) / (1 / P.RCo + 1 / P.RCdc);
vsb = ks * vo;

% Coupled inductor equations M * d[i1; ip; is]/dt = rhs (M is constant, inverse precomputed)
rhs = [vpb - vCrp; -P.Rp * ip; -(P.Rs * is + vsb + vCrs)];
di = P.Minv * rhs;

dx = zeros(8, 1);
dx(1:3) = di;
dx(4) = i1 / P.Crp;
dx(5) = is / P.Crs;
dx(6) = (vin - vCin) / (P.RCin * P.Cin);
dx(7) = (vo - vCo) / (P.RCo * P.Co);
dx(8) = (vo - vCdc) / (P.RCdc * P.Cdc);

io = (vo - vCdc) / P.RCdc + iload;      % ammeter "Io" (into Cdc branch + load)
pin = P.Vin * (P.Vin - vin) / P.R1;     % power delivered by the DC source
y = [vo; io; vin; i1; is; vpb; vsb; pin; i1 - ip; ip - P.n * is];
end

function u = leg_state(top, bot, iout_pos)
% Ideal half bridge: gate wins, otherwise the anti-parallel diode picked by current direction
% (current flowing out of the midpoint is supplied by the bottom diode).
if top > 0.5
    u = 1;
elseif bot > 0.5
    u = 0;
elseif iout_pos
    u = 0;
else
    u = 1;
end
end
