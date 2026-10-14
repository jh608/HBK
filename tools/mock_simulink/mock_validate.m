function mock_validate(mdl)
%MOCK_VALIDATE  Structural checks: port numbers in range, every input port driven exactly once,
%   subsystem port numbering contiguous, Fcn expressions only use Fcn-block syntax.
global MOCK
paths = MOCK.order(strncmp(MOCK.order, [mdl '/'], numel(mdl) + 1));
nin = containers.Map(); nout = containers.Map();
for k = 1:numel(paths)
    [a, b] = mock_ports(paths{k});
    nin(paths{k}) = a; nout(paths{k}) = b;
    blk = MOCK.blocks(paths{k});
    if any(strcmp(blk.type, {'Inport', 'Outport'})) && ~any(strcmp(MOCK.models, blk.parent))
        sib = mock_children(blk.parent);
        nums = [];
        for s = 1:numel(sib)
            c = MOCK.blocks(sib{s});
            if strcmp(c.type, blk.type), nums(end+1) = str2double(c.params.Port); end %#ok<AGROW>
        end
        if ~isequal(sort(nums), 1:numel(nums)), error('mock:validate', 'Port numbers of %ss in %s not 1..n', blk.type, blk.parent); end
    end
    if strcmp(blk.type, 'Fcn')
        e = blk.params.Expr;
        bad = regexp(e, '\<(mod|min|max|pi|if|else)\>', 'match');
        if ~isempty(bad), error('mock:validate', 'Fcn %s uses unsupported "%s": %s', paths{k}, bad{1}, e); end
    end
end
driven = containers.Map();
for k = 1:numel(MOCK.lines)
    L = MOCK.lines(k);
    if ~strncmp(L.sys, mdl, numel(mdl)), continue; end
    if ~strcmp(MOCK.blocks(L.src).parent, L.sys) || ~strcmp(MOCK.blocks(L.dst).parent, L.sys)
        error('mock:validate', 'Line in %s connects blocks of another system (%s -> %s)', L.sys, L.src, L.dst);
    end
    if L.sport < 1 || L.sport > nout(L.src)
        error('mock:validate', 'Output port %d of %s out of range (has %d)', L.sport, L.src, nout(L.src));
    end
    if L.dport < 1 || L.dport > nin(L.dst)
        error('mock:validate', 'Input port %d of %s out of range (has %d)', L.dport, L.dst, nin(L.dst));
    end
    key = sprintf('%s|%d', L.dst, L.dport);
    if isKey(driven, key), error('mock:validate', 'Input %s driven twice', key); end
    driven(key) = 1;
end
nUnusedOut = 0;
for k = 1:numel(paths)
    p = paths{k};
    for q = 1:nin(p)
        if ~isKey(driven, sprintf('%s|%d', p, q))
            error('mock:validate', 'Input port %d of %s is not connected', q, p);
        end
    end
    for q = 1:nout(p)
        used = false;
        for m = 1:numel(MOCK.lines)
            if strcmp(MOCK.lines(m).src, p) && MOCK.lines(m).sport == q, used = true; break; end
        end
        if ~used
            nUnusedOut = nUnusedOut + 1;
            fprintf('  note: output %d of %s is unconnected\n', q, p);
        end
    end
end
fprintf('mock_validate(%s): %d blocks, %d lines OK (%d unconnected outputs)\n', mdl, numel(paths), ...
    sum(strncmp({MOCK.lines.sys}, mdl, numel(mdl))), nUnusedOut);
end
