% SIXSWITCH_PARAMS  Parameters for sixswitch.slx (translated from the "SixSwitch.plecs"
% initialisation commands). Runs automatically from the model's InitFcn.

% --- PLECS initialisation commands (DAB / Class D / thermal entries kept for reference) ---
Vf = 1;
Ceqv = 3.11e-9;
Vin = 700;
Vout = 300;
Pout = 16000;
R_Co = 1e-2;
L = 400e-6;
Cout = 75e-6;
Ccd = 12000e-6;
n_pri = 14;
n_sec = 5;

% MOSFET Parameters
RgOn = 1;
RgOff = 1;
num_par_switch = 1;

% Modulator
SwitchingFrequency = 100e3;
AvergingTime = 1/(SwitchingFrequency/50);
DeadTime = 100e-9;
Ts = 1/SwitchingFrequency;

% Heat Sink parameters
Tamb = 50;
T_init = 75;

% Six Switch
gridVoltageLLrms = 380;
gridFrequency = 50;
Vgrid_pk = (gridVoltageLLrms/sqrt(3))*sqrt(2);   % grid voltage (V, line-to-neutral)
fgrid = 50;                 % grid frequency (Hz)
offset = pi/2;              % grid phase offset (rad) - not used by the model
Lline = 0.0005;             % line inductance (H) - not used by the model
Vdc_ref = Vin;              % DC-bus reference voltage (V)
fs = 100e3;                 % switching frequency (Hz)
grid_sr = 32e3;             % grid ADC sample rate (Hz)
cap = 75e-6;                % DC-bus capacitance (F) - not used ("C1" is 60 uF)
V_init = Vdc_ref;           % initial DC-bus voltage (V)
Lf = 35e-6;
Cf = 2.2e-6;

% --- Translation-specific settings ------------------------------------------------------
% Manual switch positions as saved in the PLECS model (1 = upper input)
sel_idref  = 2;   % "Manual Switch": 1 = constant "Id ref" (13.8 A), 2 = DC voltage controller
sel_load   = 2;   % "S2": 1 = 440 Ohm + two pulsed 100 Ohm loads, 2 = "Ro" (power ramp)
sel_dec_d  = 1;   % id controller "Manual Switch": 1 = decoupling w*L*iq, 2 = constant -10
sel_q      = 1;   % iq controller "Manual Switch": 1 = constant -1.85 (q-axis PI NOT used,
                  %   as saved in PLECS), 2 = q-axis PI output
id_ref_const = 13.8;
vq_const = -1.85;
vd_dec_const = -10;
decouple_gain = 2*pi*fgrid*L;

% Current PIs ("id controller"/"iq controller", configuration "Discrete")
cc.kp = 3.5;
cc.ki = 125;
cc.Ts = 1/fs;
cc.up = 1024;
cc.lo = -1024;
cc.kbc = 1;
% DC voltage PI ("Voltage Controller", configuration "Discrete")
vc.kp = 0.25;
vc.ki = 160;
vc.Ts = 1/fs;
vc.up = 40;
vc.lo = -32;
vc_avg_T = (1/fs)*10;   % "Moving Average" on the measured DC voltage

% PLL (replaces the PLECS "Three-Phase PLL" library block, automatic design): SRF-PLL on
% the normalised q-axis voltage, PI tuned for wn = 2*pi*25 rad/s, zeta = 0.707
pll.wn = 2*pi*25;
pll.zeta = 0.707;
pll.kp = 2*pll.zeta*pll.wn;
pll.ki = pll.wn^2;

% Grid ("Grid" subsystem): ramped sine sources behind 0.4 Ohm
grid_Rg = 0.4;
grid_ramp_slope = gridFrequency*100;   % "Ramp": 0 -> 1 starting at 0.1 ms
grid_ramp_start = 0.0001;

% DC load ("Load Power" ramp into "Ro" = Vdc_ref^2 / P)
load_ramp_slope = 17000*(1/0.40);
load_ramp_start = 0.05;
load_ramp_X0 = 100;
load_ramp_XFinal = 18000;

% --- Plant parameter structure for the MATLAB Function block "sixswitch_plant" ------------
Pss = struct();
Pss.L    = L;        % "Inductor", configuration "Electrical" (Lgrid = L)
Pss.Lf   = Lf;       % "Filter", configuration "LRC Damped Saturatable" (taken as linear)
Pss.Cf   = Cf;
Pss.Rd   = 4.7;
Pss.Rg   = grid_Rg;
Pss.C1   = 60e-6;
Pss.Resr = 4.2e-3;
Pss.x0   = [zeros(9,1); Vdc_ref];

% measurement vector at t = 0 (initial output of the loop-breaking Memory block)
[~, sixswitch_y0] = sixswitch_plant(Pss.x0, false(3,1), zeros(3,1), 0, Pss);

% Solver settings
sixswitch_maxstep = 1/fs/20;
