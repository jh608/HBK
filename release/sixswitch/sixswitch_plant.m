function [dx, y] = sixswitch_plant(x, s, egrid, gload, Pss)
%SIXSWITCH_PLANT  Ideal-switch power stage of "SixSwitch.plecs" (body of a MATLAB Function block).
%
% Three-phase two-level converter ("2-Level MOSFET Conv.", dead time "off" in the PLECS model)
% on a DC link C1 (60 uF behind 4.2 mOhm) with a resistive DC load. AC side per phase:
%
%   leg --L (400 uH, "Inductor")--X--Lf (35 uH, "Filter")--+--Rg (0.4)--e_grid--N
%                                 |
%                                 Rd (4.7) -- Cf (2.2 uF) -- N
%
% The DC side floats with respect to the grid neutral N, so the converter-side currents sum
% to zero and the common-mode voltage follows from that constraint. The 0.4 uH in series with
% each damping resistor is neglected. MOSFETs are ideal switches (no dead time, so the top
% gate alone sets each leg).
%
% States  x = [iL(3); ig(3); vC(3); vC1]
%   iL  converter-side inductor currents, positive from node X into the converter leg
%   ig  grid-side currents, positive from the grid into node X (the direction measured by
%       the "3ph Meter" that feeds the current controller)
%   vC  filter capacitor voltages, vC1 DC-link capacitor voltage
% Inputs
%   s      3 top-gate signals (1 = leg tied to DC+)
%   egrid  3 grid source voltages (V)
%   gload  DC load conductance (S)
% Outputs
%   y = [Vdc; Idc_load; Vgrid(3) (meter voltages to N); Igrid(3); iL(3); vX(3)]
%#codegen

P = Pss;   % parameter struct from the workspace

iL = x(1:3);
ig = x(4:6);
vC = x(7:9);
vC1 = x(10);
sd = double(s);

iconv = sum(sd .* iL);                                  % current into DC+ from the converter
vdc = (vC1 + P.Resr * iconv) / (1 + P.Resr * gload);
iload = gload * vdc;

vX = vC + P.Rd * (ig - iL);                             % filter node voltage to N
vk = sd * vdc;                                          % leg voltages to DC-
v0N = (sum(vX) - sum(vk)) / 3;                          % DC- potential relative to N

dx = zeros(10, 1);
dx(1:3) = (vX - vk - v0N) / P.L;
dx(4:6) = (egrid - P.Rg * ig - vX) / P.Lf;
dx(7:9) = (ig - iL) / P.Cf;
dx(10) = (iconv - iload) / P.C1;

vmeter = egrid - P.Rg * ig;
y = [vdc; iload; vmeter; ig; iL; vX];
end
