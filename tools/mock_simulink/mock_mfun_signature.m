function [ins, outs, fname] = mock_mfun_signature(code)
% parse "function [a, b] = name(x, y, z)" from the first function line
lines = strsplit(code, "\n");
ins = {}; outs = {}; fname = '';
for k = 1:numel(lines)
    l = strtrim(lines{k});
    if strncmp(l, 'function', 8)
        tok = regexp(l, '^function\s*(\[?[^=]*\]?)\s*=\s*(\w+)\s*\(([^)]*)\)', 'tokens', 'once');
        if isempty(tok), error('mock:mfun', 'Cannot parse function line: %s', l); end
        o = regexprep(tok{1}, '[\[\]]', '');
        outs = strtrim(strsplit(strtrim(o), {',', ' '}));
        outs = outs(~cellfun(@isempty, outs));
        fname = tok{2};
        ins = strtrim(strsplit(tok{3}, ','));
        ins = ins(~cellfun(@isempty, ins));
        return;
    end
end
error('mock:mfun', 'No function line found');
end
