function dab_build(outDir)
%DAB_BUILD  Build dab_fpga.slx: Simulink translation of "DAB FPGA.plecs".
%   Power stage: ideal-switch dual active bridge (MATLAB Function "dab_plant" + integrators).
%   Control: Vo PI -> phase shift, Dp/Ds (TPS) scheduling, FPGA-style "Phase Shift PWM"
%   with dead time, as selected in the PLECS model.
here = fileparts(mfilename('fullpath'));
if nargin < 1, outDir = here; end
addpath(fullfile(here, '..', 'common'));
evalin('base', sprintf('run(''%s'');', fullfile(here, 'dab_params.m')));

mdl = 'dab_fpga';
p2s_new_model(mdl, 'dab_params', 'timeSpan', 'dab_maxstep');
set_param(mdl, 'Description', 'Ideal-switch translation of DAB FPGA.plecs (see README.md)');

% ======================================================================================
% Power stage
% ======================================================================================
ps = p2s_subsys(mdl, 'Power stage (ideal switches)', {'gates_pri', 'gates_sec', 'i_load'}, {'meas'});
p2s_mfun(ps, 'dab_plant', fileread(fullfile(here, 'dab_plant.m')), {'Pdab'});
p2s_add(ps, 'simulink/Continuous/Integrator', 'x', 'InitialCondition', 'Pdab.x0');
% pick i1 = x(1) and is = x(3) out of the state vector
p2s_add(ps, 'simulink/Math Operations/Gain', 'i1 is', 'Gain', '[1 0 0 0 0 0 0 0; 0 0 1 0 0 0 0 0]', ...
    'Multiplication', 'Matrix(K*u)');
p2s_add(ps, 'simulink/Sources/Constant', 'zero', 'Value', '0');
p2s_add(ps, 'simulink/Logic and Bit Operations/Relational Operator', 'i > 0', 'Operator', '>');
p2s_line(ps, 'x/1', 'dab_plant/1', 'i1 is/1');
p2s_line(ps, 'gates_pri/1', 'dab_plant/2');
p2s_line(ps, 'gates_sec/1', 'dab_plant/3');
p2s_line(ps, 'i1 is/1', 'i > 0/1');
p2s_line(ps, 'zero/1', 'i > 0/2');
p2s_line(ps, 'i > 0/1', 'dab_plant/4');
p2s_line(ps, 'i_load/1', 'dab_plant/5');
p2s_line(ps, 'dab_plant/1', 'x/1');
% Memory: the measurements depend instantly on the gates (ESR drops), and parts of the
% control use them without any dynamics in between -> break that algebraic loop here.
p2s_add(ps, 'simulink/Discrete/Memory', 'Memory (loop breaker)', 'InitialCondition', 'dab_y0');
p2s_line(ps, 'dab_plant/2', 'Memory (loop breaker)/1');
p2s_line(ps, 'Memory (loop breaker)/1', 'meas/1');

% Measurements: [Vo Io Vin i1 is v_pri v_sec Pin i_mag_ext i_mag]
p2s_add(mdl, 'simulink/Signal Routing/Demux', 'Meas', 'Outputs', '10');
p2s_line(mdl, 'Power stage (ideal switches)/1', 'Meas/1');
measNames = {'Vo', 'Io', 'Vi', 'Ipri', 'Isec', 'Vpri', 'Vsec', 'Pin', 'Imag_ext', 'Imag'};

% ======================================================================================
% Output voltage reference and load
% ======================================================================================
ramp = p2s_ramp(mdl, 'Vout Ramp', '1600', '0.0', '0.1', 'Vout');
p2s_add(mdl, 'simulink/Sources/Constant', 'Vout Target', 'Value', 'Vout');
p2s_select(mdl, 'Manual Switch3', 'sel_vref == 1');
p2s_line(mdl, 'Vout Ramp/1', 'Manual Switch3/1');
p2s_line(mdl, 'Vout Target/1', 'Manual Switch3/2');

p2s_add(mdl, 'simulink/Sources/Constant', 'Power Target', 'Value', 'Pout');
p2s_add(mdl, 'simulink/Sources/Step', 'Step', 'Time', '0.25', 'Before', '0', 'After', '1');
p2s_add(mdl, 'simulink/Sources/Constant', 'Triangular Wave (disabled in PLECS)', 'Value', '0');
p2s_add(mdl, 'simulink/Sources/Constant', 'Constant4', 'Value', 'Pout/1000');
p2s_add(mdl, 'simulink/Signal Routing/Switch', 'Switch5', 'Criteria', 'u2 ~= 0');
p2s_line(mdl, 'Triangular Wave (disabled in PLECS)/1', 'Switch5/1');
p2s_line(mdl, 'Step/1', 'Switch5/2');
p2s_line(mdl, 'Constant4/1', 'Switch5/3');
p2s_select(mdl, 'Manual Switch', 'sel_power == 1');
p2s_line(mdl, 'Power Target/1', 'Manual Switch/1');
p2s_line(mdl, 'Switch5/1', 'Manual Switch/2');

% Load: current source drawing P/Vref from the output ("Load Calc1" / current source "I")
p2s_add(mdl, 'simulink/Signal Routing/Mux', 'Mux4', 'Inputs', '2');
p2s_add(mdl, 'simulink/User-Defined Functions/Fcn', 'Load Calc1', 'Expr', 'u(2)/u(1)');
p2s_line(mdl, 'Manual Switch3/1', 'Mux4/1');
p2s_line(mdl, 'Manual Switch/1', 'Mux4/2');
p2s_line(mdl, 'Mux4/1', 'Load Calc1/1');
p2s_line(mdl, 'Load Calc1/1', 'Power stage (ideal switches)/3');

% ======================================================================================
% Output voltage controller: e = Vref - Vo -> Periodic Average -> PI -> x0.5 -> phi
% ======================================================================================
vc = p2s_subsys(mdl, 'Voltage controller', {'Vref', 'Vo'}, {'phi'});
p2s_add(vc, 'simulink/Math Operations/Sum', 'Sum2', 'Inputs', '+-');
p2s_periodic_avg(vc, 'Periodic Average5', 'dab_pid_avg_T');
p2s_pid(vc, 'Continuous PID Controller', 'continuous', 'dab_pid.kp', 'dab_pid.ki', ...
    'dab_pid.x0', 'dab_pid.up', 'dab_pid.lo', 'back-calculation', 'dab_pid.kbc', '');
p2s_add(vc, 'simulink/Math Operations/Gain', 'Gain', 'Gain', '0.5');
p2s_line(vc, 'Vref/1', 'Sum2/1');
p2s_line(vc, 'Vo/1', 'Sum2/2');
p2s_line(vc, 'Sum2/1', 'Periodic Average5/1');
p2s_line(vc, 'Periodic Average5/1', 'Continuous PID Controller/1');
p2s_line(vc, 'Continuous PID Controller/1', 'Gain/1');
p2s_line(vc, 'Gain/1', 'phi/1');
p2s_line(mdl, 'Manual Switch3/1', 'Voltage controller/1');
p2s_line(mdl, 'Meas/1', 'Voltage controller/2');

% ======================================================================================
% Dp / Ds scheduling (TPS) and alpha = (1-D)/2
% ======================================================================================
tp = p2s_subsys(mdl, 'Dp Ds scheduling', {'phi', 'Vo', 'Vi'}, {'Dp', 'Ds', 'alphaP', 'alphaS'});
p2s_add(tp, 'simulink/Math Operations/Abs', 'phiAbs');
p2s_add(tp, 'simulink/User-Defined Functions/Fcn', 'Fcn2', 'Expr', 'tpsDpSlope*u(1) + tpsDpIntercept');
p2s_add(tp, 'simulink/Discontinuities/Saturation', 'Saturation2', 'UpperLimit', 'tpsDpMax', 'LowerLimit', 'tpsDpMin');
p2s_add(tp, 'simulink/User-Defined Functions/Fcn', 'Fcn3', 'Expr', 'tpsDsSlope*u(1) + tpsDsIntercept');
p2s_add(tp, 'simulink/Discontinuities/Saturation', 'Saturation3', 'UpperLimit', 'tpsDsMax', 'LowerLimit', 'tpsDsMin');
p2s_add(tp, 'simulink/Math Operations/Product', 'Product4', 'Inputs', '**');
p2s_add(tp, 'simulink/Math Operations/Product', 'Product5', 'Inputs', '**');
% start-up scaling: Relay1 on Vo, 1 when started, otherwise the start-up source
p2s_add(tp, 'simulink/Discontinuities/Relay', 'Relay1', 'OnSwitchValue', 'Vout', ...
    'OffSwitchValue', 'Vout - 150', 'OnOutputValue', '1', 'OffOutputValue', '0');
p2s_add(tp, 'simulink/Sources/Constant', 'Constant', 'Value', '1');
p2s_add(tp, 'simulink/Sources/Constant', 'Constant1', 'Value', '0.5');
p2s_add(tp, 'simulink/Signal Routing/Switch', 'Switch2', 'Criteria', 'u2 ~= 0');
% voltage ratio m = Vo*n/Vi (start-up source 2 and C-Script input)
p2s_add(tp, 'simulink/Discontinuities/Saturation', 'Saturation1', 'UpperLimit', 'inf', 'LowerLimit', '50');
p2s_add(tp, 'simulink/Discontinuities/Saturation', 'Saturation', 'UpperLimit', 'inf', 'LowerLimit', '1');
p2s_add(tp, 'simulink/Math Operations/Gain', 'Constant3', 'Gain', 'n_pri/n_sec');
p2s_add(tp, 'simulink/Math Operations/Product', 'Product1', 'Inputs', '*/');
p2s_select(tp, 'Startup source Switch', 'sel_startup == 1');
% forward / reverse power: swap the roles of Dp and Ds
p2s_add(tp, 'simulink/Discontinuities/Relay', 'Relay', 'OnSwitchValue', '0.01', ...
    'OffSwitchValue', '-0.01', 'OnOutputValue', '1', 'OffOutputValue', '0');
p2s_add(tp, 'simulink/Signal Routing/Switch', 'Switch', 'Criteria', 'u2 ~= 0');
p2s_add(tp, 'simulink/Signal Routing/Switch', 'Switch1', 'Criteria', 'u2 ~= 0');
% "Force": fixed Dp/Ds from the parameters
p2s_add(tp, 'simulink/Sources/Constant', 'Force', 'Value', 'Force');
p2s_add(tp, 'simulink/Sources/Constant', 'Dp const', 'Value', 'Dp');
p2s_add(tp, 'simulink/Sources/Constant', 'Ds const', 'Value', 'Ds');
p2s_add(tp, 'simulink/Signal Routing/Switch', 'Switch3', 'Criteria', 'u2 ~= 0');
p2s_add(tp, 'simulink/Signal Routing/Switch', 'Switch4', 'Criteria', 'u2 ~= 0');
p2s_add(tp, 'simulink/User-Defined Functions/Fcn', 'Fcn1', 'Expr', '(1-u(1))/2');
p2s_add(tp, 'simulink/User-Defined Functions/Fcn', 'Fcn', 'Expr', '(1-u(1))/2');
% C-Script alternative for alphaP/alphaS (discrete, Ts/10)
p2s_add(tp, 'simulink/Discrete/Zero-Order Hold', 'C-Script sample', 'SampleTime', 'Ts/10');
p2s_add(tp, 'simulink/Sources/Constant', 'enable', 'Value', '1');
p2s_mfun(tp, 'C-Script', fileread(fullfile(here, 'dab_alpha_cscript.m')));
p2s_select(tp, 'alphaP sel', 'sel_alphaP == 1');
p2s_select(tp, 'alphaS sel', 'sel_alphaS == 1');

p2s_line(tp, 'phi/1', 'phiAbs/1', 'Relay/1');
p2s_line(tp, 'phiAbs/1', 'Fcn2/1', 'Fcn3/1');
p2s_line(tp, 'Fcn2/1', 'Saturation2/1');
p2s_line(tp, 'Fcn3/1', 'Saturation3/1');
p2s_line(tp, 'Saturation2/1', 'Product4/1');
p2s_line(tp, 'Saturation3/1', 'Product5/1');
p2s_line(tp, 'Vo/1', 'Relay1/1', 'Saturation1/1');
p2s_line(tp, 'Vi/1', 'Saturation/1');
p2s_line(tp, 'Saturation1/1', 'Constant3/1');
p2s_line(tp, 'Constant3/1', 'Product1/1');
p2s_line(tp, 'Saturation/1', 'Product1/2');
p2s_line(tp, 'Constant1/1', 'Startup source Switch/1');
p2s_line(tp, 'Product1/1', 'Startup source Switch/2', 'C-Script sample/1');
p2s_line(tp, 'Constant/1', 'Switch2/1');
p2s_line(tp, 'Relay1/1', 'Switch2/2');
p2s_line(tp, 'Startup source Switch/1', 'Switch2/3');
p2s_line(tp, 'Switch2/1', 'Product4/2', 'Product5/2');
p2s_line(tp, 'Product4/1', 'Switch/1', 'Switch1/3');
p2s_line(tp, 'Product5/1', 'Switch/3', 'Switch1/1');
p2s_line(tp, 'Relay/1', 'Switch/2', 'Switch1/2');
p2s_line(tp, 'Dp const/1', 'Switch3/1');
p2s_line(tp, 'Force/1', 'Switch3/2', 'Switch4/2');
p2s_line(tp, 'Switch/1', 'Switch3/3');
p2s_line(tp, 'Ds const/1', 'Switch4/1');
p2s_line(tp, 'Switch1/1', 'Switch4/3');
p2s_line(tp, 'Switch3/1', 'Fcn1/1', 'Dp/1');
p2s_line(tp, 'Switch4/1', 'Fcn/1', 'Ds/1');
p2s_line(tp, 'C-Script sample/1', 'C-Script/1');
p2s_line(tp, 'enable/1', 'C-Script/2');
p2s_line(tp, 'Fcn1/1', 'alphaP sel/1');
p2s_line(tp, 'C-Script/1', 'alphaP sel/2');
p2s_line(tp, 'Fcn/1', 'alphaS sel/1');
p2s_line(tp, 'C-Script/2', 'alphaS sel/2');
p2s_line(tp, 'alphaP sel/1', 'alphaP/1');
p2s_line(tp, 'alphaS sel/1', 'alphaS/1');

p2s_line(mdl, 'Voltage controller/1', 'Dp Ds scheduling/1');
p2s_line(mdl, 'Meas/1', 'Dp Ds scheduling/2');
p2s_line(mdl, 'Meas/3', 'Dp Ds scheduling/3');

% ======================================================================================
% Phase Shift PWM (FPGA-style modulator) with turn-on delay (dead time)
% ======================================================================================
% The PLECS block sets/resets four flip-flops from two 0..1 sawtooth carriers; each output
% is a 50 % square wave. Leg k's top switch conducts while mod(f*t - theta_k, 1) is in
% [f*DeadTime, 0.5) and its bottom switch while it is in [0.5 + f*DeadTime, 1), with
%   x = 0.5 - phiF + (alphaP + alphaS)/2
%   theta(pri P) = x - alphaP + 0.5,  theta(pri N) = x,
%   theta(sec P) = 1,                 theta(sec N) = 0.5 + alphaS.
% Edges are generated from sin() comparisons so the solver locates each switching instant
% with zero-crossing detection.
pw = p2s_subsys(mdl, 'Phase Shift PWM', {'alphaS', 'alphaP', 'phiF'}, {'PWM_pri', 'PWM_sec'});
p2s_add(pw, 'simulink/Signal Routing/Mux', 'Mux in', 'Inputs', '3');
p2s_line(pw, 'phiF/1', 'Mux in/1');
p2s_line(pw, 'alphaP/1', 'Mux in/2');
p2s_line(pw, 'alphaS/1', 'Mux in/3');
p2s_add(pw, 'simulink/Sources/Clock', 't');
thetaExpr = {'1 - u(1) + (u(3) - u(2))/2', ...   % primary leg P
             '0.5 - u(1) + (u(2) + u(3))/2', ... % primary leg N
             '1 + 0*u(1)', ...                   % secondary leg P
             '0.5 + u(3)'};                      % secondary leg N
legNames = {'pri P', 'pri N', 'sec P', 'sec N'};
for k = 1:4
    p2s_add(pw, 'simulink/User-Defined Functions/Fcn', ['theta ' legNames{k}], 'Expr', thetaExpr{k});
    p2s_line(pw, 'Mux in/1', ['theta ' legNames{k} '/1']);
    leg = add_square_leg(pw, ['Leg ' legNames{k}], 'SwitchingFrequency', 'DeadTime');
    p2s_line(pw, 't/1', [get_param(leg, 'Name') '/1']);
    p2s_line(pw, ['theta ' legNames{k} '/1'], [get_param(leg, 'Name') '/2']);
end
p2s_add(pw, 'simulink/Signal Routing/Mux', 'Mux', 'Inputs', '4');
p2s_add(pw, 'simulink/Signal Routing/Mux', 'Mux1', 'Inputs', '4');
p2s_line(pw, 'Leg pri P/1', 'Mux/1');
p2s_line(pw, 'Leg pri P/2', 'Mux/2');
p2s_line(pw, 'Leg pri N/1', 'Mux/3');
p2s_line(pw, 'Leg pri N/2', 'Mux/4');
p2s_line(pw, 'Leg sec P/1', 'Mux1/1');
p2s_line(pw, 'Leg sec P/2', 'Mux1/2');
p2s_line(pw, 'Leg sec N/1', 'Mux1/3');
p2s_line(pw, 'Leg sec N/2', 'Mux1/4');
p2s_line(pw, 'Mux/1', 'PWM_pri/1');
p2s_line(pw, 'Mux1/1', 'PWM_sec/1');

p2s_line(mdl, 'Dp Ds scheduling/4', 'Phase Shift PWM/1');
p2s_line(mdl, 'Dp Ds scheduling/3', 'Phase Shift PWM/2');
p2s_line(mdl, 'Voltage controller/1', 'Phase Shift PWM/3');
p2s_line(mdl, 'Phase Shift PWM/1', 'Power stage (ideal switches)/1');
p2s_line(mdl, 'Phase Shift PWM/2', 'Power stage (ideal switches)/2');

% ======================================================================================
% Measurements, scopes and outputs
% ======================================================================================
p2s_add(mdl, 'simulink/Math Operations/Product', 'Product3', 'Inputs', '**');   % Pout = Vo*Io
p2s_line(mdl, 'Meas/1', 'Product3/1');
p2s_line(mdl, 'Meas/2', 'Product3/2');
p2s_rms(mdl, 'RMS Ipri', 'SwitchingFrequency');
p2s_rms(mdl, 'RMS Isec', 'SwitchingFrequency');
p2s_line(mdl, 'Meas/4', 'RMS Ipri/1');
p2s_line(mdl, 'Meas/5', 'RMS Isec/1');
% efficiency from period-averaged input and output power (resistive losses only)
p2s_periodic_avg(mdl, 'Pin avg', 'AvergingTime');
p2s_periodic_avg(mdl, 'Pout avg', 'AvergingTime');
p2s_line(mdl, 'Meas/8', 'Pin avg/1');
p2s_line(mdl, 'Product3/1', 'Pout avg/1');
p2s_add(mdl, 'simulink/Signal Routing/Mux', 'Mux eff', 'Inputs', '2');
p2s_add(mdl, 'simulink/User-Defined Functions/Fcn', 'Efficiency', 'Expr', '100*u(2)/(abs(u(1)) + 1e-9)');
p2s_line(mdl, 'Pin avg/1', 'Mux eff/1');
p2s_line(mdl, 'Pout avg/1', 'Mux eff/2');
p2s_line(mdl, 'Mux eff/1', 'Efficiency/1');

p2s_scope(mdl, 'Output', 3);
p2s_line(mdl, 'Meas/1', 'Output/1');
p2s_line(mdl, 'Meas/2', 'Output/2');
p2s_line(mdl, 'Product3/1', 'Output/3');
p2s_scope(mdl, 'Transformer', 4);
p2s_line(mdl, 'Meas/6', 'Transformer/1');
p2s_line(mdl, 'Meas/7', 'Transformer/2');
p2s_line(mdl, 'Meas/4', 'Transformer/3');
p2s_line(mdl, 'Meas/5', 'Transformer/4');
p2s_scope(mdl, 'Control', 5);
p2s_add(mdl, 'simulink/Signal Routing/Mux', 'Mux', 'Inputs', '2');
p2s_line(mdl, 'Manual Switch3/1', 'Mux/1');
p2s_line(mdl, 'Meas/1', 'Mux/2');
p2s_line(mdl, 'Mux/1', 'Control/1');
p2s_line(mdl, 'Voltage controller/1', 'Control/2');
p2s_line(mdl, 'Dp Ds scheduling/1', 'Control/3');
p2s_line(mdl, 'Dp Ds scheduling/2', 'Control/4');
p2s_add(mdl, 'simulink/Signal Routing/Mux', 'Mux2', 'Inputs', '2');
p2s_line(mdl, 'Dp Ds scheduling/3', 'Mux2/1');
p2s_line(mdl, 'Dp Ds scheduling/4', 'Mux2/2');
p2s_line(mdl, 'Mux2/1', 'Control/5');

outs = {'sVout', 'Meas/1'; 'sIout', 'Meas/2'; 'sPout', 'Product3/1'; ...
        'sIprirms', 'RMS Ipri/1'; 'sIsecrms', 'RMS Isec/1'; 'phi', 'Voltage controller/1'; ...
        'sEfficiency', 'Efficiency/1'; 'Vin_bridge', 'Meas/3'; 'Imag', 'Meas/10'};
for k = 1:size(outs, 1)
    p2s_add(mdl, 'simulink/Sinks/Out1', outs{k, 1}, 'Port', num2str(k));
    p2s_line(mdl, outs{k, 2}, [outs{k, 1} '/1']);
end
% unused measurement channels
for k = 9
    p2s_add(mdl, 'simulink/Sinks/Terminator', ['Term ' measNames{k}]);
    p2s_line(mdl, sprintf('Meas/%d', k), ['Term ' measNames{k} '/1']);
end

p2s_arrange(mdl);
save_system(mdl, fullfile(outDir, [mdl '.slx']));
fprintf('Saved %s\n', fullfile(outDir, [mdl '.slx']));
end

function leg = add_square_leg(sys, name, fexpr, tdexpr)
% One half-bridge leg driven by a 50 % square wave of phase theta with turn-on delay td:
%   top = sin(2*pi*(f*t - theta)) > 0  AND  sin(2*pi*(f*t - theta - f*td)) > 0
%   bot = sin(2*pi*(f*t - theta)) < 0  AND  sin(2*pi*(f*t - theta - f*td)) < 0
leg = p2s_subsys(sys, name, {'t', 'theta'}, {'top', 'bot'});
add_block('simulink/Signal Routing/Mux', [leg '/Mux'], 'Inputs', '2', 'Position', [80 40 85 110]);
add_block('simulink/User-Defined Functions/Fcn', [leg '/s1'], 'Position', [140 40 340 70], ...
    'Expr', sprintf('sin(6.283185307179586*((%s)*u(1) - u(2)))', fexpr));
add_block('simulink/User-Defined Functions/Fcn', [leg '/s2'], 'Position', [140 110 340 140], ...
    'Expr', sprintf('sin(6.283185307179586*((%s)*u(1) - u(2) - (%s)*(%s)))', fexpr, fexpr, tdexpr));
add_block('simulink/Sources/Constant', [leg '/zero'], 'Value', '0', 'Position', [300 180 330 200]);
add_block('simulink/Logic and Bit Operations/Relational Operator', [leg '/s1>0'], 'Operator', '>', 'Position', [400 30 430 60]);
add_block('simulink/Logic and Bit Operations/Relational Operator', [leg '/s2>0'], 'Operator', '>', 'Position', [400 90 430 120]);
add_block('simulink/Logic and Bit Operations/Relational Operator', [leg '/s1<0'], 'Operator', '<', 'Position', [400 150 430 180]);
add_block('simulink/Logic and Bit Operations/Relational Operator', [leg '/s2<0'], 'Operator', '<', 'Position', [400 210 430 240]);
add_block('simulink/Logic and Bit Operations/Logical Operator', [leg '/AND top'], 'Operator', 'AND', 'Inputs', '2', 'Position', [500 40 530 100]);
add_block('simulink/Logic and Bit Operations/Logical Operator', [leg '/AND bot'], 'Operator', 'AND', 'Inputs', '2', 'Position', [500 160 530 220]);
add_line(leg, 't/1', 'Mux/1');
add_line(leg, 'theta/1', 'Mux/2');
add_line(leg, 'Mux/1', 's1/1');
add_line(leg, 'Mux/1', 's2/1');
add_line(leg, 's1/1', 's1>0/1');
add_line(leg, 's1/1', 's1<0/1');
add_line(leg, 's2/1', 's2>0/1');
add_line(leg, 's2/1', 's2<0/1');
add_line(leg, 'zero/1', 's1>0/2');
add_line(leg, 'zero/1', 's2>0/2');
add_line(leg, 'zero/1', 's1<0/2');
add_line(leg, 'zero/1', 's2<0/2');
add_line(leg, 's1>0/1', 'AND top/1');
add_line(leg, 's2>0/1', 'AND top/2');
add_line(leg, 's1<0/1', 'AND bot/1');
add_line(leg, 's2<0/1', 'AND bot/2');
add_line(leg, 'AND top/1', 'top/1');
add_line(leg, 'AND bot/1', 'bot/1');
end
