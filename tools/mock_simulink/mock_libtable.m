function T = mock_libtable()
%MOCK_LIBTABLE  Library blocks the mock knows: type, default params, allowed params and
%   allowed enumeration values. Anything else is rejected, so a typo in a block path,
%   parameter name or enum value fails the build in the mock as it would in MATLAB.
persistent TT
if ~isempty(TT), T = TT; return; end
T = containers.Map();
onoff = {'on', 'off'};
relops = {'==', '~=', '<', '<=', '>=', '>'};
add('simulink/Sources/Constant', 'Constant', {'Value', '1'}, {'Value', 'OutDataTypeStr', 'SampleTime'}, {});
add('simulink/Sources/Clock', 'Clock', {}, {'DisplayTime', 'Decimation'}, {});
add('simulink/Sources/Step', 'Step', {'Time', '1', 'Before', '0', 'After', '1'}, {'Time', 'Before', 'After', 'SampleTime'}, {});
add('simulink/Sources/Pulse Generator', 'PulseGenerator', {'PulseType', 'Time based', 'Amplitude', '1', 'Period', '10', 'PulseWidth', '5', 'PhaseDelay', '0'}, ...
    {'PulseType', 'Amplitude', 'Period', 'PulseWidth', 'PhaseDelay'}, {'PulseType', {'Time based', 'Sample based'}});
add('simulink/Sources/Sine Wave', 'Sin', {'SineType', 'Time based', 'Amplitude', '1', 'Bias', '0', 'Frequency', '1', 'Phase', '0'}, ...
    {'SineType', 'Amplitude', 'Bias', 'Frequency', 'Phase', 'SampleTime'}, {'SineType', {'Time based', 'Sample based'}});
add('simulink/Math Operations/Gain', 'Gain', {'Gain', '1', 'Multiplication', 'Element-wise(K.*u)'}, {'Gain', 'Multiplication'}, ...
    {'Multiplication', {'Element-wise(K.*u)', 'Matrix(K*u)', 'Matrix(u*K)', 'Matrix(K*u) (u vector)'}});
add('simulink/Math Operations/Sum', 'Sum', {'Inputs', '|++', 'IconShape', 'round'}, {'Inputs', 'IconShape'}, {'IconShape', {'round', 'rectangular'}});
add('simulink/Math Operations/Product', 'Product', {'Inputs', '2', 'Multiplication', 'Element-wise(.*)'}, {'Inputs', 'Multiplication'}, ...
    {'Multiplication', {'Element-wise(.*)', 'Matrix(*)'}});
add('simulink/Math Operations/Abs', 'Abs', {}, {'ZeroCross'}, {'ZeroCross', onoff});
add('simulink/Math Operations/MinMax', 'MinMax', {'Function', 'min', 'Inputs', '1'}, {'Function', 'Inputs', 'ZeroCross'}, {'Function', {'min', 'max'}, 'ZeroCross', onoff});
add('simulink/Math Operations/Trigonometric Function', 'Trigonometry', {'Operator', 'sin'}, {'Operator'}, ...
    {'Operator', {'sin', 'cos', 'tan', 'asin', 'acos', 'atan', 'atan2', 'sinh', 'cosh', 'tanh'}});
add('simulink/Math Operations/Math Function', 'Math', {'Operator', 'exp'}, {'Operator'}, ...
    {'Operator', {'exp', 'log', '10^u', 'log10', 'magnitude^2', 'square', 'pow', 'conj', 'reciprocal', 'hypot', 'rem', 'mod', 'transpose', 'hermitian'}});
add('simulink/Math Operations/Sqrt', 'Sqrt', {'Operator', 'sqrt'}, {'Operator'}, {'Operator', {'sqrt', 'signedSqrt', 'rSqrt'}});
add('simulink/Logic and Bit Operations/Relational Operator', 'RelationalOperator', {'Operator', '>='}, {'Operator', 'ZeroCross'}, {'Operator', relops, 'ZeroCross', onoff});
add('simulink/Logic and Bit Operations/Logical Operator', 'Logic', {'Operator', 'AND', 'Inputs', '2'}, {'Operator', 'Inputs'}, ...
    {'Operator', {'AND', 'OR', 'NAND', 'NOR', 'XOR', 'NXOR', 'NOT'}});
add('simulink/Logic and Bit Operations/Compare To Constant', 'CompareToConstant', {'relop', '<=', 'const', '3'}, {'relop', 'const', 'ZeroCross'}, {'relop', relops, 'ZeroCross', onoff});
add('simulink/Discontinuities/Saturation', 'Saturate', {'UpperLimit', '0.5', 'LowerLimit', '-0.5'}, {'UpperLimit', 'LowerLimit', 'ZeroCross'}, {'ZeroCross', onoff});
add('simulink/Discontinuities/Relay', 'Relay', {'OnSwitchValue', 'eps', 'OffSwitchValue', 'eps', 'OnOutputValue', '1', 'OffOutputValue', '0'}, ...
    {'OnSwitchValue', 'OffSwitchValue', 'OnOutputValue', 'OffOutputValue', 'ZeroCross'}, {'ZeroCross', onoff});
add('simulink/Signal Routing/Switch', 'Switch', {'Criteria', 'u2 >= Threshold', 'Threshold', '0'}, {'Criteria', 'Threshold', 'ZeroCross'}, ...
    {'Criteria', {'u2 >= Threshold', 'u2 > Threshold', 'u2 ~= 0'}, 'ZeroCross', onoff});
add('simulink/Signal Routing/Mux', 'Mux', {'Inputs', '2'}, {'Inputs', 'DisplayOption'}, {});
add('simulink/Signal Routing/Demux', 'Demux', {'Outputs', '2'}, {'Outputs'}, {});
add('simulink/Signal Routing/Selector', 'Selector', {'NumberOfDimensions', '1', 'IndexMode', 'One-based', 'IndexOptions', 'Index vector (dialog)', 'Indices', '[1 3]', 'InputPortWidth', '3'}, ...
    {'NumberOfDimensions', 'IndexMode', 'IndexOptions', 'Indices', 'InputPortWidth'}, ...
    {'IndexMode', {'Zero-based', 'One-based'}, 'IndexOptions', {'Select all', 'Index vector (dialog)', 'Index vector (port)', 'Starting index (dialog)', 'Starting index (port)'}});
add('simulink/Continuous/Integrator', 'Integrator', {'InitialCondition', '0'}, {'InitialCondition'}, {});
add('simulink/Continuous/Transport Delay', 'TransportDelay', {'DelayTime', '1', 'InitialOutput', '0', 'BufferSize', '1024'}, {'DelayTime', 'InitialOutput', 'BufferSize'}, {});
add('simulink/Discrete/Zero-Order Hold', 'ZeroOrderHold', {'SampleTime', '1'}, {'SampleTime'}, {});
add('simulink/Discrete/Memory', 'Memory', {'InitialCondition', '0', 'InheritSampleTime', 'off'}, {'InitialCondition', 'InheritSampleTime'}, {'InheritSampleTime', onoff});
add('simulink/Discrete/Unit Delay', 'UnitDelay', {'InitialCondition', '0', 'SampleTime', '-1'}, {'InitialCondition', 'SampleTime'}, {});
pidParams = {'Controller', 'Form', 'SampleTime', 'IntegratorMethod', 'P', 'I', 'D', 'N', 'InitialConditionForIntegrator', ...
    'LimitOutput', 'UpperSaturationLimit', 'LowerSaturationLimit', 'AntiWindupMode', 'Kb'};
pidEnums = {'Controller', {'PID', 'PI', 'PD', 'P', 'I'}, 'Form', {'Parallel', 'Ideal'}, 'IntegratorMethod', {'Forward Euler', 'Backward Euler', 'Trapezoidal'}, ...
    'LimitOutput', onoff, 'AntiWindupMode', {'none', 'back-calculation', 'clamping'}};
pidDef = {'Controller', 'PID', 'Form', 'Parallel', 'SampleTime', '-1', 'IntegratorMethod', 'Forward Euler', 'P', '1', 'I', '1', 'D', '0', 'N', '100', ...
    'InitialConditionForIntegrator', '0', 'LimitOutput', 'off', 'UpperSaturationLimit', 'inf', 'LowerSaturationLimit', '-inf', 'AntiWindupMode', 'none', 'Kb', '1'};
add('simulink/Continuous/PID Controller', 'PIDc', pidDef, pidParams, pidEnums);
add('simulink/Discrete/Discrete PID Controller', 'PIDd', pidDef, pidParams, pidEnums);
add('simulink/User-Defined Functions/Fcn', 'Fcn', {'Expr', 'u(1)'}, {'Expr', 'SampleTime'}, {});
add('simulink/User-Defined Functions/MATLAB Function', 'MATLABFunction', {}, {}, {});
add('simulink/Sinks/Scope', 'Scope', {'NumInputPorts', '1'}, {'NumInputPorts'}, {});
add('simulink/Sinks/Out1', 'Outport', {'Port', '1'}, {'Port'}, {});
add('simulink/Sources/In1', 'Inport', {'Port', '1'}, {'Port'}, {});
add('simulink/Sinks/Terminator', 'Terminator', {}, {}, {});
add('simulink/Signal Attributes/Data Type Conversion', 'DataTypeConversion', {'OutDataTypeStr', 'double'}, {'OutDataTypeStr'}, {});
add('built-in/Subsystem', 'SubSystem', {}, {'TreatAsAtomicUnit'}, {'TreatAsAtomicUnit', onoff});
add('built-in/Inport', 'Inport', {'Port', '1'}, {'Port'}, {});
add('built-in/Outport', 'Outport', {'Port', '1'}, {'Port'}, {});
TT = T;
    function add(lib, type, defaults, allowed, enums)
        s.type = type;
        s.defaults = defaults;
        s.allowed = [allowed, {'Position', 'Name', 'Orientation', 'ShowName', 'BackgroundColor', 'ForegroundColor', 'Description'}];
        s.enums = enums;
        T(lib) = s;
    end
end
