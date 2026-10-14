% CLASSD_PARAMS  Parameters for classd_revb.slx (translated from the "Class D Rev B.plecs"
% initialisation commands). Runs automatically from the model's InitFcn.

% --- PLECS initialisation commands ------------------------------------------------------
Timespan = 1.0;

% DC Supply Parameters
DCVoltage = 400;    % input voltage
DCCurrent = 100;    % input current limit
DCImpedence = 0.0000000001;

set_current = 450;  % shock
DriveFrequency = 400;
tdead = 500e-9;
set_voltage = DCVoltage-80; % shock
rload = set_voltage/set_current;
lload = 10e-6;
cload = 200e-6;

% Snubber values (switching transients - not used in the ideal-switch model)
snubR = 4.7;
snubC = 300e-12;

% PWM Parameters
PWMperiod = 3e-5;
PWMfs = 1/PWMperiod;
PWMoffset = PWMperiod/3;

% Capacitor Bank Parameters
CapBank.CapCount = 1;
CapBank.CperCap = 0.018;
CapBank.C = CapBank.CperCap*CapBank.CapCount;
CapBank.ESRperCap = 0.016;
CapBank.ESR = 1/((1/CapBank.ESRperCap)*CapBank.CapCount);
CapBank.Vinitial = DCVoltage;

% Control signals
Driveshock_pulse_width = 11e-3;
Driveshock_freq = 1/(Driveshock_pulse_width*1.25);
shockinterval = 24;

% --- Translation-specific settings ------------------------------------------------------
% Manual switch positions as saved in the PLECS model (1 = upper input)
sel_ms     = 1;   % "Manual Switch":  1 = Sine Sweep, 2 = "Manual Switch2" output
sel_ms2    = 2;   % "Manual Switch2": 1 = square pulse (PWMfs/9), 2 = 567.2 Hz sine
sel_ms5    = 1;   % "Manual Switch5": 1 = DC (0.25), 2 = shock waveform
sel_type   = 1;   % "Type":           1 = "Manual Switch", 2 = "Manual Switch5"
sel_ms4    = 2;   % "Manual Switch4": 1 = ramp 0..120, 2 = constant 10 (demand scaling)
sel_ipid   = 1;   % "IPID in":        1 = drive signal directly, 2 = voltage-feedback PID path
% Load ("S4", 3-way switch, PLECS position s = 3):
%   1 = "Wire" -> (0.569 Ohm || 14.66 mF) + 55.5 mOhm + 26 uH
%   2 = "RLoadArm" (set_voltage/set_current) in series with the 10 V / 20 Hz source "V"
%   3 = "RField" 0.19 Ohm ("LField" is commented out in PLECS = short circuit)
sel_load   = 3;

% Sine sweep ("Sine Sweep" subsystem: linear sweep, f(t) ramps fStart -> fEnd over Timespan,
% output sin(2*pi*f(t)*t) exactly as in PLECS)
sweep_fStart = 4;
sweep_fEnd = 10000;

% Current loops ("iPID", configuration "Three PID's"): PI (Kd = 0) sampled at 2 MHz
ipid.kp = 0.005;
ipid.ki = 10;
ipid.Ts = 1/2000000;
ipid.up = 1.0;
ipid.lo = -1.0;
ipid.kbc = 1;
% Voltage feedback PID ("Vfb PID", only used when sel_ipid = 2)
vfb.kp = 5;
vfb.ki = 0;
vfb.Ts = 1/2000000;
vfb.up = 650;
vfb.lo = -650;

% Leg inductors ("Class D Inductors"). The PLECS model is saved with configuration
% "No Inductors" (200 nH on leg A and 0.2 nH on the other five legs) together with "No Filter"
% and a 0.19 Ohm resistive load. With ideal switches that leaves the three interleaved,
% paralleled legs on each side with essentially nothing to limit the circulating current, so
% the default below is the "No Mutual Inductance" configuration (75 uH per leg). To reproduce
% the saved PLECS state instead use: Lleg = [200e-9; 0.2e-9*ones(5,1)];
Lleg = 75e-6*ones(6,1);
Rleg = zeros(6,1);          % series resistance per leg (e.g. 0.010 for the mk4a inductor DCR)

% --- Plant parameter structure for the MATLAB Function block "classd_plant" ---------------
Pcd = struct();
Pcd.Lleg = Lleg;
Pcd.Rleg = Rleg;
Pcd.CB   = CapBank.C + 6*10e-6;       % bank + the six half-bridge 10 uF capacitors
Pcd.Resr = CapBank.ESR;
Pcd.Idc  = DCCurrent;
Pcd.Vz   = DCVoltage;                 % zener clamp "Z1"
Pcd.Rz   = 0.01;
switch sel_load
    case 1
        Pcd.Rload = 0.0555; Pcd.Lload = 2.6e-5; Pcd.has_rc = 1; Pcd.Rpar = 0.569; Pcd.Cpar = 0.01466; Pcd.E_on = 0;
    case 2
        Pcd.Rload = set_voltage/set_current; Pcd.Lload = 0; Pcd.has_rc = 0; Pcd.Rpar = 1; Pcd.Cpar = 1; Pcd.E_on = 1;
    otherwise
        Pcd.Rload = 0.19; Pcd.Lload = 0; Pcd.has_rc = 0; Pcd.Rpar = 1; Pcd.Cpar = 1; Pcd.E_on = 0;
end
Pcd.x0 = [zeros(6,1); CapBank.Vinitial; 0];

% measurement vector at t = 0 (initial output of the loop-breaking Memory block)
[~, classd_y0] = classd_plant(Pcd.x0, false(12,1), false(6,1), 0, Pcd);

% Solver settings
classd_maxstep = PWMperiod/50;
