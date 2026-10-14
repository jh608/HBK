function [nin, nout] = mock_ports(path)
global MOCK
b = MOCK.blocks(path);
P = b.params;
switch b.type
    case {'Constant', 'Clock', 'Step', 'PulseGenerator', 'Sin', 'Inport'}
        nin = 0; nout = 1;
    case {'Gain', 'Abs', 'Saturate', 'Memory', 'Relay', 'Integrator', 'TransportDelay', 'ZeroOrderHold', 'UnitDelay', ...
          'Fcn', 'Math', 'Sqrt', 'Trigonometry', 'Selector', 'PIDc', 'PIDd', 'CompareToConstant', 'DataTypeConversion'}
        nin = 1; nout = 1;
    case 'Sum'
        nin = count_signs(P.Inputs, '+-'); nout = 1;
    case 'Product'
        nin = count_signs(P.Inputs, '*/'); nout = 1;
    case 'RelationalOperator'
        nin = 2; nout = 1;
    case 'Logic'
        if strcmp(P.Operator, 'NOT'), nin = 1; else, nin = str2double(P.Inputs); end
        nout = 1;
    case 'Switch'
        nin = 3; nout = 1;
    case 'Mux'
        v = str2num(P.Inputs); %#ok<ST2NM>
        if isscalar(v), nin = v; else, nin = numel(v); end
        nout = 1;
    case 'Demux'
        v = str2num(P.Outputs); %#ok<ST2NM>
        if isscalar(v), nout = v; else, nout = numel(v); end
        nin = 1;
    case 'MinMax'
        nin = str2double(P.Inputs); nout = 1;
    case 'Scope'
        nin = str2double(P.NumInputPorts); nout = 0;
    case {'Outport', 'Terminator'}
        nin = 1; nout = 0;
    case 'SubSystem'
        nin = 0; nout = 0;
        kids = mock_children(path);
        for k = 1:numel(kids)
            c = MOCK.blocks(kids{k});
            if strcmp(c.type, 'Inport'), nin = nin + 1; end
            if strcmp(c.type, 'Outport'), nout = nout + 1; end
        end
    case 'MATLABFunction'
        ch = MOCK.charts(path);
        if isempty(ch.Script), error('mock:ports', 'MATLAB Function %s has no script', path); end
        [ins, outs] = mock_mfun_signature(ch.Script);
        nparams = 0;
        for k = 1:numel(ch.Data)
            if strcmp(ch.Data{k}.Scope, 'Parameter'), nparams = nparams + 1; end
        end
        % parameters must be the trailing arguments
        for k = 1:numel(ch.Data)
            if strcmp(ch.Data{k}.Scope, 'Parameter')
                idx = find(strcmp(ins, ch.Data{k}.Name));
                if idx <= numel(ins) - nparams
                    error('mock:ports', 'Parameter %s of %s is not a trailing argument', ch.Data{k}.Name, path);
                end
            end
        end
        nin = numel(ins) - nparams; nout = numel(outs);
    otherwise
        error('mock:ports', 'No port rule for type %s', b.type);
end
end

function n = count_signs(s, chars)
v = str2double(s);
if ~isnan(v), n = v; return; end
n = sum(ismember(s, chars));
end
