function set_param(obj, varargin)
global MOCK
if mod(numel(varargin), 2) ~= 0, error('mock:set_param', 'Parameter/value pairs expected'); end
if any(strcmp(MOCK.models, obj))
    allowed = {'InitFcn', 'PreLoadFcn', 'StopTime', 'StartTime', 'SolverType', 'Solver', 'MaxStep', 'RelTol', 'AbsTol', ...
        'ZeroCrossAlgorithm', 'MaxConsecutiveZCsMsg', 'SaveOutput', 'SaveFormat', 'Description', 'FixedStep', 'Lock'};
    enums = struct('SolverType', {{'Variable-step', 'Fixed-step'}}, ...
        'Solver', {{'ode45', 'ode23', 'ode113', 'ode15s', 'ode23s', 'ode23t', 'ode23tb', 'daessc', 'VariableStepAuto', 'ode1', 'ode2', 'ode3', 'ode4', 'ode5', 'ode8'}}, ...
        'ZeroCrossAlgorithm', {{'Nonadaptive', 'Adaptive'}}, 'MaxConsecutiveZCsMsg', {{'none', 'warning', 'error'}}, ...
        'SaveOutput', {{'on', 'off'}}, 'SaveFormat', {{'Array', 'Structure', 'StructureWithTime', 'Dataset'}});
    mp = MOCK.modelParams(obj);
    for k = 1:2:numel(varargin)
        n = varargin{k}; v = varargin{k+1};
        if ~any(strcmp(allowed, n)), error('mock:set_param', 'Unknown model parameter "%s"', n); end
        if ~ischar(v), error('mock:set_param', 'Model parameter "%s" must be a char value', n); end
        if isfield(enums, n) && ~any(strcmp(enums.(n), v))
            error('mock:set_param', 'Invalid value "%s" for model parameter "%s"', v, n);
        end
        mp.(n) = v;
    end
    MOCK.modelParams(obj) = mp;
    return;
end
if ~isKey(MOCK.blocks, obj), error('mock:set_param', 'No block "%s"', obj); end
b = MOCK.blocks(obj);
T = mock_libtable();
lib = T(b.lib);
for k = 1:2:numel(varargin)
    n = varargin{k}; v = varargin{k+1};
    if ~any(strcmp(lib.allowed, n)), error('mock:set_param', 'Block %s (%s) has no parameter "%s"', obj, b.lib, n); end
    if strcmp(n, 'Position')
        if ~(isnumeric(v) && numel(v) == 4), error('mock:set_param', 'Bad Position for %s', obj); end
        b.params.Position = v; continue;
    end
    if ~ischar(v), error('mock:set_param', 'Parameter "%s" of %s must be a char value', n, obj); end
    for e = 1:2:numel(lib.enums)
        if strcmp(lib.enums{e}, n) && ~any(strcmp(lib.enums{e+1}, v))
            error('mock:set_param', 'Invalid value "%s" for %s of %s', v, n, obj);
        end
    end
    b.params.(n) = v;
end
MOCK.blocks(obj) = b;
end
