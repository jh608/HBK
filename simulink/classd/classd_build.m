function classd_build(outDir)
%CLASSD_BUILD  Build classd_revb.slx: Simulink translation of "Class D Rev B.plecs".
%   Power stage: six ideal-switch half bridges (MATLAB Function "classd_plant" + integrators).
%   Control: demand generator (sweep / sine / pulse / DC / shock), three interleaved
%   current PI loops ("iPID", 2 MHz) and 3-state PWM with turn-on delay, as in PLECS.
here = fileparts(mfilename('fullpath'));
if nargin < 1, outDir = here; end
addpath(fullfile(here, '..', 'common'));
evalin('base', sprintf('run(''%s'');', fullfile(here, 'classd_params.m')));

mdl = 'classd_revb';
p2s_new_model(mdl, 'classd_params', 'Timespan', 'classd_maxstep');
set_param(mdl, 'Description', 'Ideal-switch translation of Class D Rev B.plecs (see README.md)');

% ======================================================================================
% Power stage
% ======================================================================================
ps = p2s_subsys(mdl, 'Power stage (ideal switches)', {'gates', 'e_load'}, {'meas'});
p2s_mfun(ps, 'classd_plant', fileread(fullfile(here, 'classd_plant.m')), {'Pcd'});
p2s_add(ps, 'simulink/Continuous/Integrator', 'x', 'InitialCondition', 'Pcd.x0');
p2s_add(ps, 'simulink/Signal Routing/Selector', 'leg currents', 'NumberOfDimensions', '1', ...
    'InputPortWidth', '8', ...   % before Indices: Simulink checks Indices against the width
    'IndexMode', 'One-based', 'IndexOptions', 'Index vector (dialog)', 'Indices', '1:6');
p2s_add(ps, 'simulink/Sources/Constant', 'zero', 'Value', '0');
p2s_add(ps, 'simulink/Logic and Bit Operations/Relational Operator', 'i > 0', 'Operator', '>');
p2s_add(ps, 'simulink/Discrete/Memory', 'Memory (loop breaker)', 'InitialCondition', 'classd_y0');
p2s_line(ps, 'x/1', 'classd_plant/1', 'leg currents/1');
p2s_line(ps, 'gates/1', 'classd_plant/2');
p2s_line(ps, 'leg currents/1', 'i > 0/1');
p2s_line(ps, 'zero/1', 'i > 0/2');
p2s_line(ps, 'i > 0/1', 'classd_plant/3');
p2s_line(ps, 'e_load/1', 'classd_plant/4');
p2s_line(ps, 'classd_plant/1', 'x/1');
p2s_line(ps, 'classd_plant/2', 'Memory (loop breaker)/1');
p2s_line(ps, 'Memory (loop breaker)/1', 'meas/1');

% series source of load option 2 ("V": 10 V, 20 Hz)
p2s_add(mdl, 'simulink/Sources/Sine Wave', 'Sine Wave1', 'Amplitude', '10', 'Bias', '0', ...
    'Frequency', '2*pi*20', 'Phase', '0');
p2s_line(mdl, 'Sine Wave1/1', 'Power stage (ideal switches)/2');

% Measurements: [Vout Iout Vbus Isup iA iB iC iD iE iF vP vN]
p2s_add(mdl, 'simulink/Signal Routing/Demux', 'Meas', 'Outputs', '12');
p2s_line(mdl, 'Power stage (ideal switches)/1', 'Meas/1');

% ======================================================================================
% Demand generation
% ======================================================================================
dg = p2s_subsys(mdl, 'Demand', {}, {'Drive'});
% "Sine Sweep": sin(2*pi*f(t)*t) with f ramping linearly fStart -> fEnd over Timespan
sw = p2s_subsys(dg, 'Sine Sweep', {}, {'Out'});
p2s_ramp(sw, 'Ramp', '(sweep_fEnd - sweep_fStart)/Timespan', '0', 'sweep_fStart', 'sweep_fEnd');
p2s_add(sw, 'simulink/Math Operations/Gain', 'Gain', 'Gain', '2*pi');
p2s_add(sw, 'simulink/Sources/Clock', 'Clock');
p2s_add(sw, 'simulink/Math Operations/Product', 'Product1', 'Inputs', '**');
p2s_add(sw, 'simulink/Math Operations/Trigonometric Function', 'Trigonometric Function', 'Operator', 'sin');
p2s_line(sw, 'Ramp/1', 'Gain/1');
p2s_line(sw, 'Gain/1', 'Product1/1');
p2s_line(sw, 'Clock/1', 'Product1/2');
p2s_line(sw, 'Product1/1', 'Trigonometric Function/1');
p2s_line(sw, 'Trigonometric Function/1', 'Out/1');
% "Sine Wave" 567.2 Hz and "Pulse Generator" (+-0.5 square at PWMfs/9 from t = 0.1 s)
p2s_add(dg, 'simulink/Sources/Sine Wave', 'Sine Wave', 'Amplitude', '1', 'Bias', '0', ...
    'Frequency', '2*pi*567.2', 'Phase', '0');
p2s_add(dg, 'simulink/Sources/Pulse Generator', 'Pulse Generator', 'Amplitude', '1', ...
    'Period', '9/PWMfs', 'PulseWidth', '50', 'PhaseDelay', '0.1');
p2s_add(dg, 'simulink/User-Defined Functions/Fcn', 'Lo = -0.5', 'Expr', 'u(1) - 0.5');
p2s_line(dg, 'Pulse Generator/1', 'Lo = -0.5/1');
p2s_select(dg, 'Manual Switch2', 'sel_ms2 == 1');
p2s_line(dg, 'Lo = -0.5/1', 'Manual Switch2/1');
p2s_line(dg, 'Sine Wave/1', 'Manual Switch2/2');
p2s_select(dg, 'Manual Switch', 'sel_ms == 1');
p2s_line(dg, 'Sine Sweep/1', 'Manual Switch/1');
p2s_line(dg, 'Manual Switch2/1', 'Manual Switch/2');
% DC and shock waveforms
p2s_add(dg, 'simulink/Sources/Constant', 'DC', 'Value', '0.25');
p2s_add(dg, 'simulink/Sources/Sine Wave', 'Shock Wave1', 'Amplitude', 'set_current', 'Bias', '0', ...
    'Frequency', '2*pi*Driveshock_freq', 'Phase', '-pi');
p2s_add(dg, 'simulink/Sources/Sine Wave', 'Shock Wave2', 'Amplitude', '0.5', 'Bias', '0.5', ...
    'Frequency', '2*pi*Driveshock_freq*2/3', 'Phase', '-pi/2');
p2s_add(dg, 'simulink/Sources/Pulse Generator', 'Shock Pulse', 'Amplitude', '1', ...
    'Period', '1/(shockinterval*Driveshock_freq/(3*10*2.4))', 'PulseWidth', '100*shockinterval*0.05/2.4', ...
    'PhaseDelay', '0');
p2s_add(dg, 'simulink/Math Operations/Product', 'Product2', 'Inputs', '***');
p2s_line(dg, 'Shock Wave1/1', 'Product2/1');
p2s_line(dg, 'Shock Wave2/1', 'Product2/2');
p2s_line(dg, 'Shock Pulse/1', 'Product2/3');
p2s_select(dg, 'Manual Switch5', 'sel_ms5 == 1');
p2s_line(dg, 'DC/1', 'Manual Switch5/1');
p2s_line(dg, 'Product2/1', 'Manual Switch5/2');
p2s_select(dg, 'Type', 'sel_type == 1');
p2s_line(dg, 'Manual Switch/1', 'Type/1');
p2s_line(dg, 'Manual Switch5/1', 'Type/2');
% amplitude scaling: ramp 0..120 or constant 10
p2s_ramp(dg, 'Ramp', '120*(1/Timespan)', '0', '0', '120');
p2s_add(dg, 'simulink/Sources/Constant', 'Constant1', 'Value', '10');
p2s_select(dg, 'Manual Switch4', 'sel_ms4 == 1');
p2s_line(dg, 'Ramp/1', 'Manual Switch4/1');
p2s_line(dg, 'Constant1/1', 'Manual Switch4/2');
p2s_add(dg, 'simulink/Math Operations/Product', 'Product1', 'Inputs', '**');
p2s_line(dg, 'Type/1', 'Product1/1');
p2s_line(dg, 'Manual Switch4/1', 'Product1/2');
p2s_line(dg, 'Product1/1', 'Drive/1');   % "Drive" (small-signal perturbation point)

% ======================================================================================
% Voltage feedback path (used when sel_ipid = 2)
% ======================================================================================
vf = p2s_subsys(mdl, 'Voltage feedback', {'Drive', 'Vout'}, {'Ifb demand'});
p2s_add(vf, 'simulink/Math Operations/Gain', 'Gain', 'Gain', '0.01');
p2s_add(vf, 'simulink/Math Operations/Sum', 'Sum4', 'Inputs', '++');
p2s_pid(vf, 'Vfb PID', 'discrete', 'vfb.kp', 'vfb.ki', '0', 'vfb.up', 'vfb.lo', 'clamping', '1', 'vfb.Ts');
p2s_moving_avg(vf, 'Moving Average1', '1/10000');
p2s_line(vf, 'Vout/1', 'Gain/1');
p2s_line(vf, 'Drive/1', 'Sum4/1');
p2s_line(vf, 'Gain/1', 'Sum4/2');
p2s_line(vf, 'Sum4/1', 'Vfb PID/1');
p2s_line(vf, 'Vfb PID/1', 'Moving Average1/1');
p2s_line(vf, 'Moving Average1/1', 'Ifb demand/1');
p2s_line(mdl, 'Demand/1', 'Voltage feedback/1');
p2s_line(mdl, 'Meas/1', 'Voltage feedback/2');
p2s_select(mdl, 'IPID in', 'sel_ipid == 1');
p2s_line(mdl, 'Demand/1', 'IPID in/1');
p2s_line(mdl, 'Voltage feedback/1', 'IPID in/2');

% ======================================================================================
% Current measurement ("I ADC", filterType 3 = unfiltered): I = (Ip - In)/2 per leg pair
% ======================================================================================
pairs = {'I ADC', 5, 8; 'I ADC1', 6, 9; 'I ADC2', 7, 10};   % (A,D) (B,E) (C,F)
for k = 1:3
    nm = pairs{k, 1};
    p2s_add(mdl, 'simulink/Math Operations/Sum', [nm ' Ip-In'], 'Inputs', '+-');
    p2s_add(mdl, 'simulink/Math Operations/Gain', nm, 'Gain', '0.5');
    p2s_line(mdl, sprintf('Meas/%d', pairs{k, 2}), [nm ' Ip-In/1']);
    p2s_line(mdl, sprintf('Meas/%d', pairs{k, 3}), [nm ' Ip-In/2']);
    p2s_line(mdl, [nm ' Ip-In/1'], [nm '/1']);
end

% ======================================================================================
% iPID: three current PI loops on demand/3 ("Three PID's")
% ======================================================================================
ip = p2s_subsys(mdl, 'iPID', {'demand', 'IfbA', 'IfbB', 'IfbC'}, {'uC', 'uB', 'uA'});
p2s_add(ip, 'simulink/Math Operations/Gain', 'Gain1', 'Gain', '1/3');
p2s_line(ip, 'demand/1', 'Gain1/1');
legs = {'Sum1', 'IfbA', 'Discrete PID Controller', 'uA'; ...
        'Sum2', 'IfbB', 'Discrete PID Controller1', 'uB'; ...
        'Sum3', 'IfbC', 'Discrete PID Controller2', 'uC'};
for k = 1:3
    p2s_add(ip, 'simulink/Math Operations/Sum', legs{k, 1}, 'Inputs', '+-');
    p2s_pid(ip, legs{k, 3}, 'discrete', 'ipid.kp', 'ipid.ki', '0', 'ipid.up', 'ipid.lo', ...
        'back-calculation', 'ipid.kbc', 'ipid.Ts');
    p2s_line(ip, 'Gain1/1', [legs{k, 1} '/1']);
    p2s_line(ip, [legs{k, 2} '/1'], [legs{k, 1} '/2']);
    p2s_line(ip, [legs{k, 1} '/1'], [legs{k, 3} '/1']);
    p2s_line(ip, [legs{k, 3} '/1'], [legs{k, 4} '/1']);
end
p2s_line(mdl, 'IPID in/1', 'iPID/1');
p2s_line(mdl, 'I ADC/1', 'iPID/2');
p2s_line(mdl, 'I ADC1/1', 'iPID/3');
p2s_line(mdl, 'I ADC2/1', 'iPID/4');

% ======================================================================================
% 3-state PWM (one per leg pair), carriers interleaved by PWMperiod/3
% ======================================================================================
add_3state_pwm(mdl, 'PWM A', '0');
add_3state_pwm(mdl, 'PWM B', 'PWMoffset');
add_3state_pwm(mdl, 'PWM C', 'PWMoffset*2');
p2s_line(mdl, 'iPID/3', 'PWM A/1');
p2s_line(mdl, 'iPID/2', 'PWM B/1');
p2s_line(mdl, 'iPID/1', 'PWM C/1');
% gate vector [A_top A_bot B_top B_bot C_top C_bot D_top D_bot E_top E_bot F_top F_bot]:
% half bridges A/B/C take PQ1/PQ2 of PWM A/B/C, D/E/F take NQ1/NQ2
p2s_add(mdl, 'simulink/Signal Routing/Mux', 'Gates', 'Inputs', '12');
src = {'PWM A/3', 'PWM A/4', 'PWM B/3', 'PWM B/4', 'PWM C/3', 'PWM C/4', ...
       'PWM A/1', 'PWM A/2', 'PWM B/1', 'PWM B/2', 'PWM C/1', 'PWM C/2'};
for k = 1:12
    p2s_line(mdl, src{k}, sprintf('Gates/%d', k));
end
p2s_line(mdl, 'Gates/1', 'Power stage (ideal switches)/1');

% ======================================================================================
% Scopes and outputs
% ======================================================================================
p2s_add(mdl, 'simulink/Math Operations/Sum', 'Sum', 'Inputs', '+++');
p2s_line(mdl, 'I ADC/1', 'Sum/1');
p2s_line(mdl, 'I ADC1/1', 'Sum/2');
p2s_line(mdl, 'I ADC2/1', 'Sum/3');
p2s_rms(mdl, 'RMS Value', '5000');
p2s_line(mdl, 'Meas/2', 'RMS Value/1');
p2s_scope(mdl, 'PM Scope', 4);
p2s_line(mdl, 'Demand/1', 'PM Scope/1');
p2s_line(mdl, 'Meas/2', 'PM Scope/2');
p2s_line(mdl, 'Meas/1', 'PM Scope/3');
p2s_add(mdl, 'simulink/Signal Routing/Mux', 'Mux', 'Inputs', '3');
p2s_line(mdl, 'I ADC/1', 'Mux/1');
p2s_line(mdl, 'I ADC1/1', 'Mux/2');
p2s_line(mdl, 'I ADC2/1', 'Mux/3');
p2s_line(mdl, 'Mux/1', 'PM Scope/4');
p2s_scope(mdl, 'Leg currents', 6);
for k = 1:6
    p2s_line(mdl, sprintf('Meas/%d', 4 + k), sprintf('Leg currents/%d', k));
end
p2s_scope(mdl, 'DC bus', 2);
p2s_line(mdl, 'Meas/3', 'DC bus/1');
p2s_line(mdl, 'Meas/4', 'DC bus/2');
p2s_add(mdl, 'simulink/Signal Routing/Mux', 'Mux u', 'Inputs', '3');
p2s_line(mdl, 'iPID/3', 'Mux u/1');
p2s_line(mdl, 'iPID/2', 'Mux u/2');
p2s_line(mdl, 'iPID/1', 'Mux u/3');
p2s_scope(mdl, 'Modulation', 1);
p2s_line(mdl, 'Mux u/1', 'Modulation/1');

outs = {'Vout', 'Meas/1'; 'Iout', 'Meas/2'; 'Vbus', 'Meas/3'; 'Idemand', 'IPID in/1'; ...
        'Iout_rms', 'RMS Value/1'; 'Itotal_adc', 'Sum/1'};
for k = 1:size(outs, 1)
    p2s_add(mdl, 'simulink/Sinks/Out1', outs{k, 1}, 'Port', num2str(k));
    p2s_line(mdl, outs{k, 2}, [outs{k, 1} '/1']);
end
for k = [11 12]
    p2s_add(mdl, 'simulink/Sinks/Terminator', sprintf('Term%d', k));
    p2s_line(mdl, sprintf('Meas/%d', k), sprintf('Term%d/1', k));
end

p2s_arrange(mdl);
save_system(mdl, fullfile(outDir, [mdl '.slx']));
fprintf('Saved %s\n', fullfile(outDir, [mdl '.slx']));
end

function pw = add_3state_pwm(sys, name, offsetExpr)
% PLECS "PWM" library block, configuration "3-State PWM": triangular carrier -1..1 at PWMfs
% delayed by OFFSET; positive bridge compares m, negative bridge compares -m; every gate has
% a turn-on delay of tdead. Turn-on delay of (m > c) is (m > c(t)) AND (m > c(t - tdead)),
% so both comparisons are smooth and the solver can locate every edge.
% Outputs: NQ1 NQ2 PQ1 PQ2 (PLECS terminal order without the input).
pw = p2s_subsys(sys, name, {'m'}, {'NQ1', 'NQ2', 'PQ1', 'PQ2'});
car = '1 - 4*abs(rem(PWMfs*(u(1) - %s - %s) + 1000, 1) - 0.5)';
add_block('simulink/Sources/Clock', [pw '/t'], 'Position', [30 200 60 230]);
add_block('simulink/User-Defined Functions/Fcn', [pw '/PWM_Carrier'], 'Position', [120 180 400 210], ...
    'Expr', sprintf(car, offsetExpr, '0'));
add_block('simulink/User-Defined Functions/Fcn', [pw '/PWM_Carrier delayed'], 'Position', [120 260 400 290], ...
    'Expr', sprintf(car, offsetExpr, 'tdead'));
add_block('simulink/Math Operations/Gain', [pw '/Gain'], 'Gain', '-1', 'Position', [120 60 150 90]);
add_line(pw, 't/1', 'PWM_Carrier/1');
add_line(pw, 't/1', 'PWM_Carrier delayed/1');
add_line(pw, 'm/1', 'Gain/1');
cmp = {'PQ', 'm/1'; 'NQ', 'Gain/1'};
y = 40;
for s = 1:2
    pre = cmp{s, 1};
    rel = {[pre ' on'], '>', 'PWM_Carrier/1'; [pre ' on delayed'], '>', 'PWM_Carrier delayed/1'; ...
           [pre ' off'], '<=', 'PWM_Carrier/1'; [pre ' off delayed'], '<=', 'PWM_Carrier delayed/1'};
    for r = 1:4
        add_block('simulink/Logic and Bit Operations/Relational Operator', [pw '/' rel{r, 1}], ...
            'Operator', rel{r, 2}, 'Position', [480 y 510 y+30]);
        add_line(pw, cmp{s, 2}, [rel{r, 1} '/1']);
        add_line(pw, rel{r, 3}, [rel{r, 1} '/2']);
        y = y + 60;
    end
    add_block('simulink/Logic and Bit Operations/Logical Operator', [pw '/AND ' pre '1'], 'Operator', 'AND', 'Inputs', '2', 'Position', [600 y-240 630 y-190]);
    add_block('simulink/Logic and Bit Operations/Logical Operator', [pw '/AND ' pre '2'], 'Operator', 'AND', 'Inputs', '2', 'Position', [600 y-120 630 y-70]);
    add_line(pw, [rel{1, 1} '/1'], ['AND ' pre '1/1']);
    add_line(pw, [rel{2, 1} '/1'], ['AND ' pre '1/2']);
    add_line(pw, [rel{3, 1} '/1'], ['AND ' pre '2/1']);
    add_line(pw, [rel{4, 1} '/1'], ['AND ' pre '2/2']);
    add_line(pw, ['AND ' pre '1/1'], [pre '1/1']);
    add_line(pw, ['AND ' pre '2/1'], [pre '2/1']);
end
end
