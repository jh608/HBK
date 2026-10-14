function LOG = mock_sim(mdl, tstop, dt, dec, logBlocks)
%MOCK_SIM  Fixed-step (forward Euler) simulation of a model built with the mock Simulink API.
%   The recorded block graph is compiled into straight-line Octave code (one statement or
%   so per block) and run, with Simulink block semantics. It checks the wiring, signs and
%   parameter expressions of the generated model end to end. Switching instants are only
%   resolved to DT (no zero-crossing location), so use a small DT.
%   LOG.<name>{k} = values of input k of every Scope / top-level Outport, every DEC steps;
%   LOG.t the matching times. LOGBLOCKS (cellstr of block paths relative to the model) are
%   logged as well (their first output).
global MOCK
if nargin < 4, dec = 10; end
if nargin < 5, logBlocks = {}; end
paths = MOCK.order(strncmp(MOCK.order, [mdl '/'], numel(mdl) + 1));

% ---- non-virtual blocks --------------------------------------------------------------
blocks = {};
for k = 1:numel(paths)
    b = MOCK.blocks(paths{k});
    virt = strcmp(b.type, 'SubSystem') || (any(strcmp(b.type, {'Inport', 'Outport'})) && ~strcmp(b.parent, mdl));
    if ~virt, blocks{end+1} = paths{k}; end %#ok<AGROW>
end
nb = numel(blocks);
bidx = containers.Map(blocks, num2cell(1:nb));
lineMap = containers.Map();
for k = 1:numel(MOCK.lines)
    L = MOCK.lines(k);
    lineMap(sprintf('%s|%d', L.dst, L.dport)) = {L.src, L.sport};
end

% ---- signals ----------------------------------------------------------------------------
sigOf = containers.Map(); nsig = 0;
B = struct('path', blocks, 'type', '', 'in', [], 'out', []);
for k = 1:nb
    b = MOCK.blocks(blocks{k});
    [ni, no] = mock_ports(blocks{k});
    B(k).type = b.type;
    B(k).out = zeros(1, no);
    for q = 1:no
        nsig = nsig + 1; sigOf(sprintf('%s|%d', blocks{k}, q)) = nsig; B(k).out(q) = nsig;
    end
    B(k).nin = ni;
end
for k = 1:nb
    B(k).in = zeros(1, B(k).nin);
    for q = 1:B(k).nin
        [s, sp] = resolve(blocks{k}, q);
        B(k).in(q) = sigOf(sprintf('%s|%d', s, sp));
    end
end

% ---- execution order ----------------------------------------------------------------------
noFeed = {'Integrator', 'Memory', 'UnitDelay', 'TransportDelay', 'Constant', 'Clock', 'Step', 'PulseGenerator', 'Sin'};
producer = zeros(1, nsig);
for k = 1:nb, producer(B(k).out) = k; end
indeg = zeros(1, nb); succ = cell(1, nb);
for k = 1:nb
    if any(strcmp(B(k).type, noFeed)), continue; end
    for q = 1:B(k).nin
        p = producer(B(k).in(q));
        indeg(k) = indeg(k) + 1; succ{p}(end+1) = k;
    end
end
order = zeros(1, nb); n = 0; queue = find(indeg == 0);
while ~isempty(queue)
    k = queue(1); queue(1) = [];
    n = n + 1; order(n) = k;
    for s = succ{k}
        indeg(s) = indeg(s) - 1;
        if indeg(s) == 0, queue(end+1) = s; end %#ok<AGROW>
    end
end
if n < nb
    stuck = blocks(indeg > 0);
    error('mock:sim', 'Algebraic loop involving: %s', strjoin(stuck(1:min(8, end)), ', '));
end

% ---- code generation --------------------------------------------------------------------
tmpdir = tempname(); mkdir(tmpdir); addpath(tmpdir);
cleanup = onCleanup(@() rmpath(tmpdir));
nsteps = floor(tstop/dt) + 1;
nlog = floor((nsteps - 1)/dec) + 1;
PRM = cell(1, nb);
init = {}; body = {}; upd = {}; wcap = {}; wexp = {};
sv = @(i) sprintf('s%d', i);
num = @(x) sprintf('%.17g', x);
ev = @(e) evalin('base', e);
for oi = 1:nb
    k = order(oi);
    b = MOCK.blocks(blocks{k}); P = b.params;
    in = arrayfun(sv, B(k).in, 'UniformOutput', false);
    out = arrayfun(sv, B(k).out, 'UniformOutput', false);
    tag = sprintf('%% [%d] %s (%s)', k, blocks{k}, b.type);
    c = {};
    switch b.type
        case 'Constant'
            PRM{k} = ev(P.Value);
            init{end+1} = sprintf('%s = PRM{%d}(:); %s', out{1}, k, tag); %#ok<AGROW>
        case 'Clock', c{end+1} = sprintf('%s = t;', out{1});
        case 'Step', c{end+1} = sprintf('%s = %s + (%s)*(t >= %s);', out{1}, num(ev(P.Before)), num(ev(P.After) - ev(P.Before)), num(ev(P.Time)));
        case 'PulseGenerator'
            c{end+1} = sprintf('%s = %s*double(t >= %s && rem(t - %s, %s) < %s);', out{1}, num(ev(P.Amplitude)), ...
                num(ev(P.PhaseDelay)), num(ev(P.PhaseDelay)), num(ev(P.Period)), num(ev(P.PulseWidth)/100*ev(P.Period)));
        case 'Sin'
            c{end+1} = sprintf('%s = %s*sin(%s*t + %s) + %s;', out{1}, num(ev(P.Amplitude)), num(ev(P.Frequency)), num(ev(P.Phase)), num(ev(P.Bias)));
        case 'Gain'
            PRM{k} = ev(P.Gain);
            if isscalar(PRM{k}), c{end+1} = sprintf('%s = %s*%s;', out{1}, num(PRM{k}), in{1});
            elseif strcmp(P.Multiplication, 'Element-wise(K.*u)'), c{end+1} = sprintf('%s = PRM{%d}(:).*%s;', out{1}, k, in{1});
            else, c{end+1} = sprintf('%s = PRM{%d}*%s;', out{1}, k, in{1}); end
        case 'Sum'
            sg = signs(P.Inputs, '+-');
            if numel(in) == 1 && sg(1) == 1
                c{end+1} = sprintf('%s = sum(%s);', out{1}, in{1});
            else
                e = '';
                for q = 1:numel(in)
                    if sg(q) > 0, op = '+'; else, op = '-'; end
                    if q == 1 && sg(q) > 0, op = ''; end
                    e = [e op in{q}]; %#ok<AGROW>
                end
                c{end+1} = sprintf('%s = %s;', out{1}, e);
            end
        case 'Product'
            sg = signs(P.Inputs, '*/');
            if numel(in) == 1, c{end+1} = sprintf('%s = prod(%s);', out{1}, in{1});
            else
                e = in{1};
                if sg(1) < 0, e = ['1./' in{1}]; end
                for q = 2:numel(in)
                    if sg(q) > 0, e = [e '.*' in{q}]; else, e = [e './' in{q}]; end %#ok<AGROW>
                end
                c{end+1} = sprintf('%s = %s;', out{1}, e);
            end
        case 'Abs', c{end+1} = sprintf('%s = abs(%s);', out{1}, in{1});
        case 'Sqrt', c{end+1} = sprintf('%s = sqrt(%s);', out{1}, in{1});
        case 'Math'
            switch P.Operator
                case 'square', c{end+1} = sprintf('%s = %s.^2;', out{1}, in{1});
                case 'exp', c{end+1} = sprintf('%s = exp(%s);', out{1}, in{1});
                case 'log', c{end+1} = sprintf('%s = log(%s);', out{1}, in{1});
                case 'reciprocal', c{end+1} = sprintf('%s = 1./%s;', out{1}, in{1});
                otherwise, error('mock:sim', 'Math op %s', P.Operator);
            end
        case 'Trigonometry', c{end+1} = sprintf('%s = %s(%s);', out{1}, P.Operator, in{1});
        case 'Fcn'
            c{end+1} = sprintf('%s = double(%s);', out{1}, fcn_expr(P.Expr, in{1}));
        case 'Saturate'
            c{end+1} = sprintf('%s = min(max(%s, %s), %s);', out{1}, in{1}, num(ev(P.LowerLimit)), num(ev(P.UpperLimit)));
        case 'Relay'
            init{end+1} = sprintf('r%d = 0;', k);
            c{end+1} = sprintf('if %s >= %s, r%d = 1; elseif %s <= %s, r%d = 0; end', in{1}, num(ev(P.OnSwitchValue)), k, in{1}, num(ev(P.OffSwitchValue)), k);
            c{end+1} = sprintf('%s = %s + (%s)*r%d;', out{1}, num(ev(P.OffOutputValue)), num(ev(P.OnOutputValue) - ev(P.OffOutputValue)), k);
        case 'Switch'
            switch P.Criteria
                case 'u2 >= Threshold', cnd = sprintf('%s >= %s', in{2}, num(ev(P.Threshold)));
                case 'u2 > Threshold', cnd = sprintf('%s > %s', in{2}, num(ev(P.Threshold)));
                otherwise, cnd = sprintf('%s ~= 0', in{2});
            end
            c{end+1} = sprintf('if all(%s), %s = %s; else, %s = %s; end', cnd, out{1}, in{1}, out{1}, in{3});
        case 'RelationalOperator'
            c{end+1} = sprintf('%s = double(%s %s %s);', out{1}, in{1}, P.Operator, in{2});
        case 'CompareToConstant'
            c{end+1} = sprintf('%s = double(%s %s %s);', out{1}, in{1}, P.relop, num(ev(P.const)));
        case 'Logic'
            switch P.Operator
                case 'NOT', c{end+1} = sprintf('%s = double(~%s);', out{1}, in{1});
                case 'AND', c{end+1} = sprintf('%s = double(%s);', out{1}, strjoin(cellfun(@(x) ['(' x ' ~= 0)'], in, 'UniformOutput', false), ' & '));
                case 'OR', c{end+1} = sprintf('%s = double(%s);', out{1}, strjoin(cellfun(@(x) ['(' x ' ~= 0)'], in, 'UniformOutput', false), ' | '));
                otherwise, error('mock:sim', 'Logic op %s', P.Operator);
            end
        case 'Mux'
            c{end+1} = sprintf('%s = [%s];', out{1}, strjoin(cellfun(@(x) [x '(:)'], in, 'UniformOutput', false), '; '));
        case 'Demux'
            nn = numel(out);
            wv = str2num(P.Outputs); %#ok<ST2NM>
            if isscalar(wv)
                c{end+1} = sprintf('w_ = numel(%s)/%d;', in{1}, nn);
                for q = 1:nn
                    c{end+1} = sprintf('%s = %s((%d)*w_+1:(%d)*w_);', out{q}, in{1}, q-1, q); %#ok<AGROW>
                end
            else
                cs = [0 cumsum(wv)];
                c{end+1} = sprintf('if numel(%s) ~= %d, error(''Demux width mismatch at %s''); end', in{1}, cs(end), strrep(blocks{k}, '''', ''));
                for q = 1:nn
                    c{end+1} = sprintf('%s = %s(%d:%d);', out{q}, in{1}, cs(q)+1, cs(q+1)); %#ok<AGROW>
                end
            end
        case 'Selector'
            c{end+1} = sprintf('%s = %s(%s);', out{1}, in{1}, mat2str(ev(P.Indices)));
        case 'MinMax'
            if numel(in) == 1, c{end+1} = sprintf('%s = %s(%s);', out{1}, P.Function, in{1});
            else
                e = in{1};
                for q = 2:numel(in), e = sprintf('%s(%s, %s)', P.Function, e, in{q}); end
                c{end+1} = sprintf('%s = %s;', out{1}, e);
            end
        case 'Integrator'
            PRM{k} = ev(P.InitialCondition);
            init{end+1} = sprintf('x%d = PRM{%d}(:);', k, k);
            wcap{end+1} = sprintf('wx%d = numel(%s);', k, in{1});
            wexp{end+1} = sprintf('if numel(x%d) == 1 && wx%d > 1, x%d = repmat(x%d, wx%d, 1); end', k, k, k, k, k);
            c{end+1} = sprintf('%s = x%d;', out{1}, k);
            upd{end+1} = sprintf('x%d = x%d + dt*%s(:);', k, k, in{1}); %#ok<AGROW>
        case 'Memory'
            PRM{k} = ev(P.InitialCondition);
            init{end+1} = sprintf('m%d = PRM{%d}(:);', k, k);
            wcap{end+1} = sprintf('wm%d = numel(%s);', k, in{1});
            wexp{end+1} = sprintf('if numel(m%d) == 1 && wm%d > 1, m%d = repmat(m%d, wm%d, 1); end', k, k, k, k, k);
            c{end+1} = sprintf('%s = m%d;', out{1}, k);
            upd{end+1} = sprintf('m%d = %s(:);', k, in{1}); %#ok<AGROW>
        case 'TransportDelay'
            D = ev(P.DelayTime); y0 = ev(P.InitialOutput);
            init{end+1} = sprintf('tdb%d = []; tdD%d = %s; tdy%d = %s;', k, k, num(D), k, num(y0));
            c{end+1} = sprintf(['if t - tdD%d < 0, %s = tdy%d; else, fi_ = (t - tdD%d)/dt + 1; i0_ = floor(fi_ + 1e-9); a_ = fi_ - i0_; ' ...
                'if a_ < 1e-9, %s = tdb%d(:, i0_); else, %s = tdb%d(:, i0_) + a_*(tdb%d(:, i0_+1) - tdb%d(:, i0_)); end; end'], ...
                k, out{1}, k, k, out{1}, k, out{1}, k, k, k);
            upd{end+1} = sprintf(['if isempty(tdb%d), tdb%d = zeros(numel(%s), nsteps + 1); elseif size(tdb%d, 1) ~= numel(%s), ' ...
                'tdb%d = repmat(tdb%d(1, :), numel(%s), 1); end; tdb%d(:, step) = %s(:);'], k, k, in{1}, k, in{1}, k, k, in{1}, k, in{1}); %#ok<AGROW>
        case 'ZeroOrderHold'
            Ts = ev(P.SampleTime);
            init{end+1} = sprintf('zl%d = -1; z%d = 0;', k, k);
            c{end+1} = sprintf('kh_ = floor(t/%s + 1e-9); if kh_ ~= zl%d, zl%d = kh_; z%d = %s; end; %s = z%d;', num(Ts), k, k, k, in{1}, out{1}, k);
        case 'UnitDelay'
            Ts = ev(P.SampleTime); PRM{k} = ev(P.InitialCondition);
            init{end+1} = sprintf('ul%d = -1; u%d = PRM{%d}(:);', k, k, k);
            wcap{end+1} = sprintf('wu%d = numel(%s);', k, in{1});
            wexp{end+1} = sprintf('if numel(u%d) == 1 && wu%d > 1, u%d = repmat(u%d, wu%d, 1); end', k, k, k, k, k);
            c{end+1} = sprintf('%s = u%d;', out{1}, k);
            upd{end+1} = sprintf('kh_ = floor(t/%s + 1e-9); if kh_ ~= ul%d, ul%d = kh_; u%d = %s(:); end', num(Ts), k, k, k, in{1}); %#ok<AGROW>
        case {'PIDc', 'PIDd'}
            kp = ev(P.P); ki = ev(P.I); if strcmp(P.Controller, 'P'), ki = 0; end
            if strcmp(P.LimitOutput, 'on'), up = ev(P.UpperSaturationLimit); lo = ev(P.LowerSaturationLimit); else, up = inf; lo = -inf; end
            kb = ev(P.Kb); aw = P.AntiWindupMode;
            init{end+1} = sprintf('xi%d = %s; pe%d = 0; pu%d = 0; py%d = 0; pl%d = -1;', k, num(ev(P.InitialConditionForIntegrator)), k, k, k, k);
            switch aw
                case 'back-calculation', dxi = sprintf('%s*pe%d + %s*(py%d - pu%d)', num(ki), k, num(kb), k, k);
                case 'clamping', dxi = sprintf('%s*pe%d*double(~(py%d ~= pu%d && sign(%s*pe%d) == sign(pu%d - py%d)))', num(ki), k, k, k, num(ki), k, k, k);
                otherwise, dxi = sprintf('%s*pe%d', num(ki), k);
            end
            calc = sprintf('pe%d = %s; pu%d = %s*pe%d + xi%d; py%d = min(max(pu%d, %s), %s);', k, in{1}, k, num(kp), k, k, k, k, num(lo), num(up));
            if strcmp(b.type, 'PIDd')
                Ts = ev(P.SampleTime);
                c{end+1} = sprintf('kh_ = floor(t/%s + 1e-9); if kh_ ~= pl%d, pl%d = kh_; %s xi%d = xi%d + %s*(%s); end; %s = py%d;', ...
                    num(Ts), k, k, calc, k, k, num(Ts), dxi, out{1}, k);
            else
                c{end+1} = sprintf('%s %s = py%d;', calc, out{1}, k);
                upd{end+1} = sprintf('xi%d = xi%d + dt*(%s);', k, k, dxi); %#ok<AGROW>
            end
        case 'MATLABFunction'
            ch = MOCK.charts(blocks{k});
            [~, outs, fname] = mock_mfun_signature(ch.Script);
            uname = sprintf('mockfn_%d', k);
            code = regexprep(ch.Script, ['(function[^=]*=\s*)' fname '(\s*\()'], ['$1' uname '$2'], 'once');
            fid = fopen(fullfile(tmpdir, [uname '.m']), 'w'); fprintf(fid, '%s', code); fclose(fid);
            prm = {};
            for d = 1:numel(ch.Data)
                if strcmp(ch.Data{d}.Scope, 'Parameter'), prm{end+1} = ev(ch.Data{d}.Name); end %#ok<AGROW>
            end
            PRM{k} = prm;
            args = strjoin(in, ', ');
            if ~isempty(prm), args = [args ', PRM{' num2str(k) '}{:}']; end
            c{end+1} = sprintf('[%s] = %s(%s);', strjoin(out, ', '), uname, args);
        case 'DataTypeConversion', c{end+1} = sprintf('%s = double(%s);', out{1}, in{1});
        case {'Scope', 'Outport', 'Terminator'}
        otherwise
            error('mock:sim', 'No simulation rule for %s (%s)', b.type, blocks{k});
    end
    if ~isempty(c), body{end+1} = sprintf('%s\n%s', tag, strjoin(c, sprintf('\n'))); end %#ok<AGROW>
end

% logging
logSig = {}; logName = {};
for k = 1:nb
    if any(strcmp(B(k).type, {'Scope', 'Outport'}))
        logSig{end+1} = B(k).in; %#ok<AGROW>
        logName{end+1} = matlab.lang.makeValidName(strrep(blocks{k}(numel(mdl)+2:end), '/', '_')); %#ok<AGROW>
    end
end
for k = 1:numel(logBlocks)
    kk = bidx([mdl '/' logBlocks{k}]);
    logSig{end+1} = B(kk).out(1); logName{end+1} = matlab.lang.makeValidName(logBlocks{k}); %#ok<AGROW>
end
lg = {};
for i = 1:numel(logSig)
    for q = 1:numel(logSig{i})
        lg{end+1} = sprintf('LG{%d}{%d}(li, :) = %s(:).'';', i, q, sv(logSig{i}(q))); %#ok<AGROW>
    end
end
fname = 'mock_gen_sim';
fid = fopen(fullfile(tmpdir, [fname '.m']), 'w');
fprintf(fid, 'function [LG, tl] = %s(PRM, dt, nsteps, dec, nlog, nlg)\n', fname);
fprintf(fid, '%s\n', init{:});
% dry pass at t = 0 to learn signal widths, then re-initialise and scalar-expand states
fprintf(fid, 't = 0; step = 1;\n');
fprintf(fid, '%s\n', body{:});
fprintf(fid, '%s\n', wcap{:});
fprintf(fid, '%s\n', init{:});
fprintf(fid, '%s\n', wexp{:});
fprintf(fid, 'LG = cell(1, numel(nlg)); for i = 1:numel(nlg), LG{i} = cell(1, nlg(i)); end\n');
fprintf(fid, 'tl = zeros(nlog, 1); li = 0;\n');
fprintf(fid, 'for step = 1:nsteps\nt = (step - 1)*dt;\n');
fprintf(fid, '%s\n', body{:});
fprintf(fid, 'if mod(step - 1, dec) == 0\nli = li + 1; tl(li) = t;\nif li == 1\n');
for i = 1:numel(logSig)
    for q = 1:numel(logSig{i})
        fprintf(fid, 'LG{%d}{%d} = zeros(nlog, numel(%s));\n', i, q, sv(logSig{i}(q)));
    end
end
fprintf(fid, 'end\n%s\nend\n', strjoin(lg, sprintf('\n')));
fprintf(fid, '%s\n', upd{:});
fprintf(fid, 'end\nend\n');
fclose(fid);
copyfile(fullfile(tmpdir, [fname '.m']), fullfile(tempdir, ['last_' mdl '_gen.m']));
rehash();
nlg = cellfun(@numel, logSig);
[LG, tl] = feval(fname, PRM, dt, nsteps, dec, nlog, nlg);
LOG = struct('t', tl);
for i = 1:numel(logSig), LOG.(logName{i}) = LG{i}; end

    function [s, sp] = resolve(dst, port)
        key = sprintf('%s|%d', dst, port);
        if ~isKey(lineMap, key), error('mock:sim', 'Unconnected input %s', key); end
        v = lineMap(key); s = v{1}; sp = v{2};
        sb = MOCK.blocks(s);
        if strcmp(sb.type, 'SubSystem')
            kids = mock_children(s);
            for kk = 1:numel(kids)
                cb = MOCK.blocks(kids{kk});
                if strcmp(cb.type, 'Outport') && str2double(cb.params.Port) == sp
                    [s, sp] = resolve(kids{kk}, 1); return;
                end
            end
            error('mock:sim', 'Subsystem %s has no outport %d', s, sp);
        elseif strcmp(sb.type, 'Inport') && ~strcmp(sb.parent, mdl)
            [s, sp] = resolve(sb.parent, str2double(sb.params.Port));
        end
    end
end

function e = fcn_expr(expr, uvar)
% Fcn-block expression -> Octave: u(i)/u[i] -> signal, workspace variables -> literals
e = regexprep(expr, '\<u\[(\d+)\]', 'u($1)');
known = {'u', 'sin', 'cos', 'tan', 'asin', 'acos', 'atan', 'atan2', 'sinh', 'cosh', 'tanh', 'exp', 'log', 'ln', ...
    'log10', 'sqrt', 'abs', 'fabs', 'rem', 'floor', 'ceil', 'hypot', 'pow', 'power', 'sgn', 'e', 'inf', 'Inf'};
[tok, s0, s1] = regexp(e, '[A-Za-z_]\w*(\.\w+)*', 'match', 'start', 'end');
for i = numel(tok):-1:1
    if any(strcmp(tok{i}, known)), continue; end
    v = evalin('base', tok{i});
    e = [e(1:s0(i)-1) sprintf('(%.17g)', v) e(s1(i)+1:end)];
end
e = regexprep(e, '\<ln\(', 'log(');
e = regexprep(e, '\<u\(', [uvar '(']);
end

function sg = signs(s, chars)
v = str2double(s);
if ~isnan(v), sg = ones(1, v); return; end
s = s(ismember(s, chars));
sg = ones(1, numel(s));
sg(s == chars(2)) = -1;
end
