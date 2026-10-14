function sixswitch_build(outDir)
%SIXSWITCH_BUILD  Build sixswitch.slx: Simulink translation of "SixSwitch.plecs".
%   Power stage: ideal-switch three-phase two-level converter with L + damped LC + grid
%   (MATLAB Function "sixswitch_plant" + integrators).
%   Control: DC-voltage PI -> decoupled dq current control (PLL, 32 kHz sensing, 100 kHz PI)
%   -> space-vector (min/max) modulation, regular sampled PWM, as in PLECS.
here = fileparts(mfilename('fullpath'));
if nargin < 1, outDir = here; end
addpath(fullfile(here, '..', 'common'));
evalin('base', sprintf('run(''%s'');', fullfile(here, 'sixswitch_params.m')));

mdl = 'sixswitch';
p2s_new_model(mdl, 'sixswitch_params', '1.0', 'sixswitch_maxstep');
set_param(mdl, 'Description', 'Ideal-switch translation of SixSwitch.plecs (see README.md)');
TWO_PI = '6.283185307179586';

% ======================================================================================
% Power stage
% ======================================================================================
ps = p2s_subsys(mdl, 'Power stage (ideal switches)', {'s_top', 'e_grid', 'g_load'}, {'meas'});
p2s_mfun(ps, 'sixswitch_plant', fileread(fullfile(here, 'sixswitch_plant.m')), {'Pss'});
p2s_add(ps, 'simulink/Continuous/Integrator', 'x', 'InitialCondition', 'Pss.x0');
p2s_add(ps, 'simulink/Discrete/Memory', 'Memory (loop breaker)', 'InitialCondition', 'sixswitch_y0');
p2s_line(ps, 'x/1', 'sixswitch_plant/1');
p2s_line(ps, 's_top/1', 'sixswitch_plant/2');
p2s_line(ps, 'e_grid/1', 'sixswitch_plant/3');
p2s_line(ps, 'g_load/1', 'sixswitch_plant/4');
p2s_line(ps, 'sixswitch_plant/1', 'x/1');
p2s_line(ps, 'sixswitch_plant/2', 'Memory (loop breaker)/1');
p2s_line(ps, 'Memory (loop breaker)/1', 'meas/1');
% Measurements: Vdc, Idc(load), Vgrid(3), Igrid(3), iL(3), vX(3)
p2s_add(mdl, 'simulink/Signal Routing/Demux', 'Meas', 'Outputs', '[1 1 3 3 3 3]');
p2s_line(mdl, 'Power stage (ideal switches)/1', 'Meas/1');

% ======================================================================================
% Grid sources: Vpk*sin(2*pi*50*t + phase), amplitude ramped 0 -> 1 from 0.1 ms
% ======================================================================================
gr = p2s_subsys(mdl, 'Grid', {}, {'e_abc'});
p2s_ramp(gr, 'Ramp', 'grid_ramp_slope', 'grid_ramp_start', '0', '1');
ph = {'0', '-2*pi/3', '2*pi/3'};
nm = {'Sine Wave', 'Sine Wave1', 'Sine Wave2'};
p2s_add(gr, 'simulink/Signal Routing/Mux', 'Mux', 'Inputs', '3');
for k = 1:3
    p2s_add(gr, 'simulink/Sources/Sine Wave', nm{k}, 'Amplitude', 'Vgrid_pk', 'Bias', '0', ...
        'Frequency', '2*pi*gridFrequency', 'Phase', ph{k});
    p2s_add(gr, 'simulink/Math Operations/Product', sprintf('Product%d', k), 'Inputs', '**');
    p2s_line(gr, [nm{k} '/1'], sprintf('Product%d/1', k));
    p2s_line(gr, 'Ramp/1', sprintf('Product%d/2', k));
    p2s_line(gr, sprintf('Product%d/1', k), sprintf('Mux/%d', k));
end
p2s_line(gr, 'Mux/1', 'e_abc/1');
p2s_line(mdl, 'Grid/1', 'Power stage (ideal switches)/2');

% ======================================================================================
% DC load: "Ro" = Vdc_ref^2/P(t) with the "Load Power" ramp, or 440 Ohm + pulsed 100 Ohm
% ======================================================================================
ld = p2s_subsys(mdl, 'DC load', {}, {'G'});
p2s_ramp(ld, 'Load Power', 'load_ramp_slope', 'load_ramp_start', 'load_ramp_X0', 'load_ramp_XFinal');
p2s_add(ld, 'simulink/User-Defined Functions/Fcn', 'Load Calc (G = 1 over Ro)', 'Expr', 'u(1)/Vdc_ref^2');
p2s_line(ld, 'Load Power/1', 'Load Calc (G = 1 over Ro)/1');
p2s_add(ld, 'simulink/Sources/Pulse Generator', 'Pulse Generator', 'Amplitude', '1', ...
    'Period', '0.02', 'PulseWidth', '50', 'PhaseDelay', '0.030');
p2s_add(ld, 'simulink/Sources/Pulse Generator', 'Pulse Generator1', 'Amplitude', '1', ...
    'Period', '0.01', 'PulseWidth', '50', 'PhaseDelay', '0.045');
p2s_add(ld, 'simulink/Signal Routing/Mux', 'Mux', 'Inputs', '2');
p2s_add(ld, 'simulink/User-Defined Functions/Fcn', 'R1 + S1.R2 + S3.R3', 'Expr', '1/440 + u(1)/100 + u(2)/100');
p2s_line(ld, 'Pulse Generator/1', 'Mux/1');
p2s_line(ld, 'Pulse Generator1/1', 'Mux/2');
p2s_line(ld, 'Mux/1', 'R1 + S1.R2 + S3.R3/1');
p2s_select(ld, 'S2', 'sel_load == 2');
p2s_line(ld, 'Load Calc (G = 1 over Ro)/1', 'S2/1');
p2s_line(ld, 'R1 + S1.R2 + S3.R3/1', 'S2/2');
p2s_line(ld, 'S2/1', 'G/1');
p2s_line(mdl, 'DC load/1', 'Power stage (ideal switches)/3');

% ======================================================================================
% DC voltage controller ("Voltage Controller", Discrete) and id* selection
% ======================================================================================
vc = p2s_subsys(mdl, 'Voltage Controller', {'Vdc ref', 'Vdc'}, {'id ref'});
p2s_add(vc, 'simulink/Math Operations/Sum', 'Sum1', 'Inputs', '+-');
p2s_pid(vc, 'Discrete PID Controller', 'discrete', 'vc.kp', 'vc.ki', '0', 'vc.up', 'vc.lo', 'clamping', '1', 'vc.Ts');
p2s_line(vc, 'Vdc ref/1', 'Sum1/1');
p2s_line(vc, 'Vdc/1', 'Sum1/2');
p2s_line(vc, 'Sum1/1', 'Discrete PID Controller/1');
p2s_line(vc, 'Discrete PID Controller/1', 'id ref/1');
p2s_add(mdl, 'simulink/Sources/Constant', 'Vdc ref', 'Value', 'Vdc_ref');
p2s_moving_avg(mdl, 'Moving Average', 'vc_avg_T');
p2s_line(mdl, 'Meas/1', 'Moving Average/1');
p2s_line(mdl, 'Vdc ref/1', 'Voltage Controller/1');
p2s_line(mdl, 'Moving Average/1', 'Voltage Controller/2');
p2s_add(mdl, 'simulink/Sources/Constant', 'Id ref', 'Value', 'id_ref_const');
p2s_select(mdl, 'Manual Switch', 'sel_idref == 1');
p2s_line(mdl, 'Id ref/1', 'Manual Switch/1');
p2s_line(mdl, 'Voltage Controller/1', 'Manual Switch/2');
p2s_add(mdl, 'simulink/Sources/Constant', 'Iq ref', 'Value', '0');

% ======================================================================================
% Decoupled dq current control
% ======================================================================================
cc = p2s_subsys(mdl, 'Decoupled dq current control', {'id*', 'iq*', 'Iph', 'Vph'}, {'Valphabeta*', 'theta', 'idq'});
p2s_add(cc, 'simulink/Discrete/Zero-Order Hold', 'Zero-Order Hold', 'SampleTime', '1/grid_sr');
p2s_add(cc, 'simulink/Discrete/Zero-Order Hold', 'Zero-Order Hold1', 'SampleTime', '1/grid_sr');
p2s_line(cc, 'Iph/1', 'Zero-Order Hold/1');
p2s_line(cc, 'Vph/1', 'Zero-Order Hold1/1');
add_pll(cc, 'Three-Phase PLL', TWO_PI);
p2s_line(cc, 'Zero-Order Hold1/1', 'Three-Phase PLL/1');
add_abc2dq(cc, 'abc>dq', TWO_PI);
add_abc2dq(cc, 'abc>dq1', TWO_PI);
p2s_line(cc, 'Three-Phase PLL/1', 'abc>dq/1', 'abc>dq1/1');
p2s_line(cc, 'Zero-Order Hold1/1', 'abc>dq/2');
p2s_line(cc, 'Zero-Order Hold/1', 'abc>dq1/2');
p2s_add(cc, 'simulink/Signal Routing/Demux', 'CDemux', 'Outputs', '2');
p2s_line(cc, 'abc>dq1/1', 'CDemux/1');
% id controller: Vd* = PI(id* - id) - w*L*iq
p2s_add(cc, 'simulink/Math Operations/Sum', 'id Sum1', 'Inputs', '+-');
p2s_pid(cc, 'id PI', 'discrete', 'cc.kp', 'cc.ki', '0', 'cc.up', 'cc.lo', 'clamping', '1', 'cc.Ts');
p2s_add(cc, 'simulink/Math Operations/Gain', 'id Decoupling', 'Gain', 'decouple_gain');
p2s_add(cc, 'simulink/Sources/Constant', 'id Constant', 'Value', 'vd_dec_const');
p2s_select(cc, 'id Manual Switch', 'sel_dec_d == 1');
p2s_add(cc, 'simulink/Math Operations/Sum', 'id Sum2', 'Inputs', '+-');
p2s_line(cc, 'id*/1', 'id Sum1/1');
p2s_line(cc, 'CDemux/1', 'id Sum1/2');
p2s_line(cc, 'id Sum1/1', 'id PI/1');
p2s_line(cc, 'CDemux/2', 'id Decoupling/1');
p2s_line(cc, 'id Decoupling/1', 'id Manual Switch/1');
p2s_line(cc, 'id Constant/1', 'id Manual Switch/2');
p2s_line(cc, 'id PI/1', 'id Sum2/1');
p2s_line(cc, 'id Manual Switch/1', 'id Sum2/2');
% iq controller: Vq* = (constant -1.85 | PI(iq* - iq)) + w*L*id
p2s_add(cc, 'simulink/Math Operations/Sum', 'iq Sum1', 'Inputs', '+-');
p2s_pid(cc, 'iq PI', 'discrete', 'cc.kp', 'cc.ki', '0', 'cc.up', 'cc.lo', 'back-calculation', 'cc.kbc', 'cc.Ts');
p2s_add(cc, 'simulink/Math Operations/Gain', 'iq Decoupling', 'Gain', 'decouple_gain');
p2s_add(cc, 'simulink/Sources/Constant', 'iq Constant', 'Value', 'vq_const');
p2s_select(cc, 'iq Manual Switch', 'sel_q == 1');
p2s_add(cc, 'simulink/Math Operations/Sum', 'iq Sum2', 'Inputs', '++');
p2s_line(cc, 'iq*/1', 'iq Sum1/1');
p2s_line(cc, 'CDemux/2', 'iq Sum1/2');
p2s_line(cc, 'iq Sum1/1', 'iq PI/1');
p2s_line(cc, 'CDemux/1', 'iq Decoupling/1');
p2s_line(cc, 'iq Constant/1', 'iq Manual Switch/1');
p2s_line(cc, 'iq PI/1', 'iq Manual Switch/2');
p2s_line(cc, 'iq Manual Switch/1', 'iq Sum2/1');
p2s_line(cc, 'iq Decoupling/1', 'iq Sum2/2');
% voltage reference: vdq(grid) - [Vd*; Vq*], back to alpha-beta
p2s_add(cc, 'simulink/Signal Routing/Mux', 'CMux', 'Inputs', '2');
p2s_line(cc, 'id Sum2/1', 'CMux/1');
p2s_line(cc, 'iq Sum2/1', 'CMux/2');
p2s_add(cc, 'simulink/Math Operations/Sum', 'Sum', 'Inputs', '-+');
p2s_line(cc, 'CMux/1', 'Sum/1');
p2s_line(cc, 'abc>dq/1', 'Sum/2');
add_dq2ab(cc, 'RRF->SRF');
p2s_line(cc, 'Sum/1', 'RRF->SRF/1');
p2s_line(cc, 'Three-Phase PLL/1', 'RRF->SRF/2', 'theta/1');
p2s_line(cc, 'RRF->SRF/1', 'Valphabeta*/1');
p2s_line(cc, 'abc>dq1/1', 'idq/1');

p2s_line(mdl, 'Manual Switch/1', 'Decoupled dq current control/1');
p2s_line(mdl, 'Iq ref/1', 'Decoupled dq current control/2');
p2s_line(mdl, 'Meas/4', 'Decoupled dq current control/3');
p2s_line(mdl, 'Meas/3', 'Decoupled dq current control/4');

% ======================================================================================
% SV modulator: SVPWM (symmetrical, min/max injection), single update at carrier minimum
% ======================================================================================
sv = p2s_subsys(mdl, 'SV modulator', {'vdc', 'Valphabeta*'}, {'s_top'});
p2s_add(sv, 'simulink/Discrete/Zero-Order Hold', 'Zero-Order Hold', 'SampleTime', '1/fs');
p2s_add(sv, 'simulink/Discrete/Zero-Order Hold', 'Zero-Order Hold1', 'SampleTime', '1/fs');
p2s_add(sv, 'simulink/Math Operations/Gain', 'SRF->3ph', 'Gain', '[1 0; -1/2 sqrt(3)/2; -1/2 -sqrt(3)/2]', ...
    'Multiplication', 'Matrix(K*u)');
p2s_add(sv, 'simulink/Math Operations/Gain', 'Gain1', 'Gain', '1/2');
p2s_add(sv, 'simulink/Math Operations/Product', 'Divide', 'Inputs', '*/');
p2s_add(sv, 'simulink/Math Operations/MinMax', 'Min', 'Function', 'min', 'Inputs', '1');
p2s_add(sv, 'simulink/Math Operations/MinMax', 'Max', 'Function', 'max', 'Inputs', '1');
p2s_add(sv, 'simulink/Math Operations/Sum', 'Sum1', 'Inputs', '--');
p2s_add(sv, 'simulink/Math Operations/Gain', 'Gain', 'Gain', '1/2');
p2s_add(sv, 'simulink/Math Operations/Sum', 'Sum', 'Inputs', '++');
p2s_add(sv, 'simulink/Discrete/Zero-Order Hold', 'Single update (carrier min)', 'SampleTime', '1/fs');
p2s_add(sv, 'simulink/Sources/Clock', 't');
p2s_add(sv, 'simulink/User-Defined Functions/Fcn', 'Carrier', 'Expr', '1 - 4*abs(rem(fs*u(1), 1) - 0.5)');
p2s_add(sv, 'simulink/Logic and Bit Operations/Relational Operator', 'm >= carrier', 'Operator', '>=');
p2s_line(sv, 'vdc/1', 'Zero-Order Hold/1');
p2s_line(sv, 'Valphabeta*/1', 'Zero-Order Hold1/1');
p2s_line(sv, 'Zero-Order Hold1/1', 'SRF->3ph/1');
p2s_line(sv, 'Zero-Order Hold/1', 'Gain1/1');
p2s_line(sv, 'SRF->3ph/1', 'Divide/1');
p2s_line(sv, 'Gain1/1', 'Divide/2');
p2s_line(sv, 'Divide/1', 'Min/1', 'Max/1', 'Sum/1');
p2s_line(sv, 'Min/1', 'Sum1/1');
p2s_line(sv, 'Max/1', 'Sum1/2');
p2s_line(sv, 'Sum1/1', 'Gain/1');
p2s_line(sv, 'Gain/1', 'Sum/2');
p2s_line(sv, 'Sum/1', 'Single update (carrier min)/1');
p2s_line(sv, 'Single update (carrier min)/1', 'm >= carrier/1');
p2s_line(sv, 't/1', 'Carrier/1');
p2s_line(sv, 'Carrier/1', 'm >= carrier/2');
p2s_line(sv, 'm >= carrier/1', 's_top/1');
p2s_line(mdl, 'Meas/1', 'SV modulator/1');
p2s_line(mdl, 'Decoupled dq current control/1', 'SV modulator/2');
p2s_line(mdl, 'SV modulator/1', 'Power stage (ideal switches)/1');

% ======================================================================================
% Grid measurements, scopes and outputs
% ======================================================================================
p2s_add(mdl, 'simulink/Signal Routing/Mux', 'Mux4', 'Inputs', '2');
p2s_add(mdl, 'simulink/User-Defined Functions/Fcn', 'Pi', 'Expr', 'u(1)*u(4) + u(2)*u(5) + u(3)*u(6)');
p2s_line(mdl, 'Meas/3', 'Mux4/1');
p2s_line(mdl, 'Meas/4', 'Mux4/2');
p2s_line(mdl, 'Mux4/1', 'Pi/1');
p2s_rms(mdl, 'V RMS', 'gridFrequency');
p2s_rms(mdl, 'I RMS', 'gridFrequency');
p2s_line(mdl, 'Meas/3', 'V RMS/1');
p2s_line(mdl, 'Meas/4', 'I RMS/1');

p2s_scope(mdl, 'Grid Scope', 5);
p2s_line(mdl, 'Meas/3', 'Grid Scope/1');
p2s_line(mdl, 'Meas/4', 'Grid Scope/2');
p2s_line(mdl, 'Pi/1', 'Grid Scope/3');
p2s_line(mdl, 'V RMS/1', 'Grid Scope/4');
p2s_line(mdl, 'I RMS/1', 'Grid Scope/5');
p2s_scope(mdl, 'Scope', 5);
p2s_line(mdl, 'Decoupled dq current control/2', 'Scope/1');
p2s_line(mdl, 'Meas/1', 'Scope/2');
p2s_line(mdl, 'Manual Switch/1', 'Scope/3');
p2s_line(mdl, 'Decoupled dq current control/3', 'Scope/4');
p2s_line(mdl, 'Decoupled dq current control/1', 'Scope/5');
p2s_scope(mdl, 'Converter', 3);
p2s_line(mdl, 'Meas/5', 'Converter/1');
p2s_line(mdl, 'Meas/6', 'Converter/2');
p2s_line(mdl, 'Meas/2', 'Converter/3');

outs = {'Vdc', 'Meas/1'; 'Idc', 'Meas/2'; 'Vgrid', 'Meas/3'; 'Igrid', 'Meas/4'; 'Pgrid', 'Pi/1'; ...
        'idq', 'Decoupled dq current control/3'; 'theta', 'Decoupled dq current control/2'};
for k = 1:size(outs, 1)
    p2s_add(mdl, 'simulink/Sinks/Out1', outs{k, 1}, 'Port', num2str(k));
    p2s_line(mdl, outs{k, 2}, [outs{k, 1} '/1']);
end

p2s_arrange(mdl);
save_system(mdl, fullfile(outDir, [mdl '.slx']));
fprintf('Saved %s\n', fullfile(outDir, [mdl '.slx']));
end

function p = add_abc2dq(sys, name, TWO_PI)
% PLECS "abc>dq" subsystem (amplitude-invariant Park transform), inputs theta, abc
p = p2s_subsys(sys, name, {'theta', 'abc'}, {'dq'});
add_block('simulink/Signal Routing/Mux', [p '/CMux'], 'Inputs', '2', 'Position', [100 40 105 110]);
add_block('simulink/User-Defined Functions/Fcn', [p '/abc>d'], 'Position', [180 30 560 60], 'Expr', ...
    sprintf('2/3*(u(1)*cos(u(4))+u(2)*cos(u(4)-%s/3)+u(3)*cos(u(4)+%s/3))', TWO_PI, TWO_PI));
add_block('simulink/User-Defined Functions/Fcn', [p '/abc>q'], 'Position', [180 90 560 120], 'Expr', ...
    sprintf('2/3*(-u(1)*sin(u(4))-u(2)*sin(u(4)-%s/3)-u(3)*sin(u(4)+%s/3))', TWO_PI, TWO_PI));
add_block('simulink/Signal Routing/Mux', [p '/CMux1'], 'Inputs', '2', 'Position', [620 40 625 110]);
add_line(p, 'abc/1', 'CMux/1');
add_line(p, 'theta/1', 'CMux/2');
add_line(p, 'CMux/1', 'abc>d/1');
add_line(p, 'CMux/1', 'abc>q/1');
add_line(p, 'abc>d/1', 'CMux1/1');
add_line(p, 'abc>q/1', 'CMux1/2');
add_line(p, 'CMux1/1', 'dq/1');
end

function p = add_dq2ab(sys, name)
% PLECS "RRF->SRF": rotate dq by theta into alpha-beta
p = p2s_subsys(sys, name, {'dq', 'theta'}, {'alphabeta'});
add_block('simulink/Signal Routing/Mux', [p '/Mux'], 'Inputs', '2', 'Position', [100 40 105 110]);
add_block('simulink/User-Defined Functions/Fcn', [p '/alpha'], 'Position', [180 30 400 60], 'Expr', 'u(1)*cos(u(3)) - u(2)*sin(u(3))');
add_block('simulink/User-Defined Functions/Fcn', [p '/beta'], 'Position', [180 90 400 120], 'Expr', 'u(1)*sin(u(3)) + u(2)*cos(u(3))');
add_block('simulink/Signal Routing/Mux', [p '/Mux1'], 'Inputs', '2', 'Position', [460 40 465 110]);
add_line(p, 'dq/1', 'Mux/1');
add_line(p, 'theta/1', 'Mux/2');
add_line(p, 'Mux/1', 'alpha/1');
add_line(p, 'Mux/1', 'beta/1');
add_line(p, 'alpha/1', 'Mux1/1');
add_line(p, 'beta/1', 'Mux1/2');
add_line(p, 'Mux1/1', 'alphabeta/1');
end

function p = add_pll(sys, name, TWO_PI)
% SRF-PLL standing in for the PLECS "Three-Phase PLL": drives the q-axis voltage of the
% amplitude-invariant Park transform to zero, so theta aligns the d axis with the voltage.
p = p2s_subsys(sys, name, {'vabc'}, {'theta'});
add_block('simulink/Signal Routing/Mux', [p '/Mux'], 'Inputs', '2', 'Position', [100 40 105 110]);
add_block('simulink/User-Defined Functions/Fcn', [p '/vq'], 'Position', [160 50 560 80], 'Expr', ...
    sprintf('2/3*(-u(1)*sin(u(4))-u(2)*sin(u(4)-%s/3)-u(3)*sin(u(4)+%s/3))', TWO_PI, TWO_PI));
add_block('simulink/Math Operations/Gain', [p '/normalise'], 'Gain', '1/Vgrid_pk', 'Position', [600 50 640 80]);
add_block('simulink/Continuous/PID Controller', [p '/PI'], 'Position', [680 45 740 85]);
set_param([p '/PI'], 'Controller', 'PI', 'Form', 'Parallel', 'P', 'pll.kp', 'I', 'pll.ki', ...
    'InitialConditionForIntegrator', '0', 'LimitOutput', 'off');
add_block('simulink/Sources/Constant', [p '/w0'], 'Value', '2*pi*fgrid', 'Position', [680 120 740 140]);
add_block('simulink/Math Operations/Sum', [p '/Sum'], 'Inputs', '++', 'Position', [780 50 800 90]);
add_block('simulink/Continuous/Integrator', [p '/theta int'], 'InitialCondition', '0', 'Position', [840 55 870 85]);
add_line(p, 'vabc/1', 'Mux/1');
add_line(p, 'theta int/1', 'Mux/2');
add_line(p, 'Mux/1', 'vq/1');
add_line(p, 'vq/1', 'normalise/1');
add_line(p, 'normalise/1', 'PI/1');
add_line(p, 'PI/1', 'Sum/1');
add_line(p, 'w0/1', 'Sum/2');
add_line(p, 'Sum/1', 'theta int/1');
add_line(p, 'theta int/1', 'theta/1');
end
