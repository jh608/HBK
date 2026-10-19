function smoke_test(which)
%SMOKE_TEST  Build each translated model, compile it and run a short simulation, printing
%   the result or the first error. Intended as the first thing to run in a real MATLAB
%   session (the models were developed against an Octave mock of the Simulink API).
%   smoke_test            % all three
%   smoke_test('dab')     % one of 'dab', 'classd', 'sixswitch'
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'common'));
cfg = struct( ...
    'dab',       struct('mdl', 'dab_fpga',    'stop', '300e-6', 'outs', {{'sVout', 'sIout', 'sPout', 'sIprirms'}}), ...
    'classd',    struct('mdl', 'classd_revb', 'stop', '5e-3',   'outs', {{'Vout', 'Iout', 'Vbus', 'Idemand'}}), ...
    'sixswitch', struct('mdl', 'sixswitch',   'stop', '20e-3',  'outs', {{'Vdc', 'Idc', 'Vgrid', 'Igrid'}}));
names = fieldnames(cfg);
if nargin == 1, names = {which}; end
for k = 1:numel(names)
    c = cfg.(names{k});
    d = fullfile(here, names{k});
    addpath(d);
    fprintf('\n===== %s =====\n', c.mdl);
    try
        feval([names{k} '_build'], d);
    catch err
        report('build', err); continue;
    end
    try
        set_param(c.mdl, 'SimulationCommand', 'update');
        fprintf('update diagram: OK\n');
    catch err
        report('update diagram', err); continue;
    end
    try
        tic;
        out = sim(c.mdl, 'StopTime', c.stop);
        fprintf('sim to %s s: OK in %.1f s wall clock\n', c.stop, toc);
        for q = 1:numel(c.outs)
            v = out.yout{q}.Values;
            fprintf('  %-8s final = %s\n', c.outs{q}, mat2str(last_sample(v), 5));
        end
    catch err
        report('sim', err);
    end
end
end

function d = last_sample(v)
% Time runs along the first dimension for vector signals, along the third for signals
% logged as matrices (e.g. 1x1xN).
d = double(v.Data);
if ndims(d) == 3
    d = reshape(d(:, :, end), 1, []);
else
    d = d(end, :);
end
end

function report(stage, err)
fprintf(2, '%s FAILED: %s\n', stage, err.message);
for s = 1:min(numel(err.stack), 4)
    fprintf(2, '    at %s line %d\n', err.stack(s).name, err.stack(s).line);
end
try
    for c = 1:numel(err.cause)
        fprintf(2, '  cause: %s\n', err.cause{c}.message);
    end
catch
end
end
