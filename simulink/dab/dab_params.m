% DAB_PARAMS  Parameters for dab_fpga.slx (translated from the "DAB FPGA.plecs" initialisation
% commands). Runs automatically from the model's InitFcn; edit here, not in the blocks.

% --- PLECS initialisation commands (verbatim apart from printf -> fprintf) ----------------
timeSpan = 0.004;

% Simulation mode setting (PLECS/SPICE switch of the bridge models - not used here)
PLECS   = 1;
SPICE   = 2;
simMode = PLECS;

% Script options
Force = 1;          % 1: use the fixed Dp/Ds below, 0: use the TPS (|phi|-scheduled) Dp/Ds
Dp = 1.0;
Ds = 0.95;

% Input voltage
Vin = 700;
% Vout target
Vout = 250;
CapVout = Vout;

% Cin
Cin = 30e-6;
R_Cin = 1e-2;

% Cout
Cout = 1e-3;
R_Cout = 0.003;

% DC bus cap
Cdc = 18000e-6;
R_Cdc = 0.016;

% Load Power
Pout = 16000;

% Modulator
SwitchingFrequency = 150e3;            % switching frequency
AvergingTime = 1/(SwitchingFrequency/50);
DeadTime = 100e-9;
Ts = 1/SwitchingFrequency;             % sample time (s)
Rgon = 2;          % gate resistors / snubber: switching-transient parameters, not used
Rgoff = 2;
Csnub = 150e-12;
Rsnub = 4.7;

% Transformer
Llk = 13e-6;
Lm = 1.3e-3;
n_pri = 11;
n_sec = 4;
Llkp = Llk/2.0;
Llks = (Llk/2)/((n_pri/n_sec)^2);
resonantFrequency = SwitchingFrequency / 1.2;
Cr = 1/(((2*pi*resonantFrequency)^2)*Llk);
Crp = 1/(((2*pi*resonantFrequency)^2)*Llkp);
Crs = 1/(((2*pi*resonantFrequency)^2)*Llks);

% TPS coefficients (700/250 set, as active in the PLECS model)
tpsDpSlope = 0.0;
tpsDpIntercept = 1.0;
tpsDpMax = 1.0;
tpsDpMin = 1.0;
tpsDsSlope = 0.0;
tpsDsIntercept = 0.95;
tpsDsMax = 0.95;
tpsDsMin = 0.95;

% --- Translation-specific settings --------------------------------------------------------
% Positions of the PLECS manual switches as saved in the PLECS model (1 = upper input).
sel_vref    = 2;   % "Manual Switch3": 1 = "Vout Ramp", 2 = "Vout Target" (constant Vout)
sel_power   = 1;   % "Manual Switch": 1 = "Power Target" (Pout), 2 = step/triangle test source
sel_startup = 1;   % "Startup source Switch": 1 = 0.5, 2 = Vo*n/Vi
sel_alphaP  = 1;   % "alphaP": 1 = (1-Dp)/2, 2 = C-Script output
sel_alphaS  = 1;   % "alphaS": 1 = (1-Ds)/2, 2 = C-Script output
% "Mod Switch Pri/Sec" are at position 2 = "Phase Shift PWM" (the FPGA-style modulator); the
% unused "Triple Phase Shift Modulator" alternative is not translated.

% Voltage PID ("Continuous PID Controller", PI, parallel form)
dab_pid.kp = 0.125;
dab_pid.ki = 0.002;
dab_pid.x0 = 0.25;
dab_pid.up = 0.49;
dab_pid.lo = -0.49;
dab_pid.kbc = 1;
dab_pid_avg_T = 1/(SwitchingFrequency*0.5);   % "Periodic Average5" window

% Transformer model ("HF Transformer", configuration "Electrical")
dab_tx.Lp = Llk;            % internal primary leakage
dab_tx.Ls = Llk;            % internal secondary leakage
dab_tx.Rp = 0.0101999;      % R5 + R2
dab_tx.Rs = 0.0101999;      % R3 + R4
dab_tx.Lm = Lm;             % magnetising inductance (referred to the primary)
dab_Lx = 1.3e-3;            % "Llk1" in parallel with the transformer primary terminals
dab_R1 = 0.01;              % source resistance "R1"

% --- Plant parameter structure used by the MATLAB Function block "dab_plant" --------------
Pdab = struct();
Pdab.Vin  = Vin;
Pdab.R1   = dab_R1;
Pdab.Cin  = Cin;
Pdab.RCin = R_Cin;
Pdab.Co   = Cout;
Pdab.RCo  = R_Cout;
Pdab.Cdc  = Cdc;
Pdab.RCdc = R_Cdc;
Pdab.Crp  = Crp;
Pdab.Crs  = Crs;
Pdab.Rp   = dab_tx.Rp;
Pdab.Rs   = dab_tx.Rs;
Pdab.n    = n_sec/n_pri;    % secondary/primary voltage ratio
Mdab = [Llkp + dab_Lx,   -dab_Lx,                          0;
        -dab_Lx,         dab_Lx + dab_tx.Lp + dab_tx.Lm,   -Pdab.n*dab_tx.Lm;
        0,               -Pdab.n*dab_tx.Lm,                Pdab.n^2*dab_tx.Lm + dab_tx.Ls + Llks];
Pdab.Minv = inv(Mdab);
% initial states [i1 ip is vCrp vCrs vCin vCo vCdc]
Pdab.x0 = [0; 0; 0; 0; 0; Vin; CapVout; CapVout];

% measurement vector at t = 0 (initial output of the loop-breaking Memory block)
[~, dab_y0] = dab_plant(Pdab.x0, false(4,1), false(4,1), false(2,1), 0, Pdab);

% Solver settings
dab_maxstep = Ts/20;
