function add_line(sys, src, dst, varargin)
global MOCK
if ~(any(strcmp(MOCK.models, sys)) || isKey(MOCK.blocks, sys))
    error('mock:add_line', 'System "%s" does not exist', sys);
end
[sb, sp] = parse_port(sys, src);
[db, dp] = parse_port(sys, dst);
for k = 1:numel(MOCK.lines)
    L = MOCK.lines(k);
    if strcmp(L.dst, db) && L.dport == dp
        error('mock:add_line', 'Input port %s already connected (adding %s -> %s in %s)', dst, src, dst, sys);
    end
end
MOCK.lines(end+1) = struct('sys', sys, 'src', sb, 'sport', sp, 'dst', db, 'dport', dp);
end

function [blk, port] = parse_port(sys, s)
global MOCK
i = find(s == '/', 1, 'last');
if isempty(i), error('mock:add_line', 'Port spec "%s" has no /port', s); end
port = str2double(s(i+1:end));
if isnan(port), error('mock:add_line', 'Bad port number in "%s"', s); end
blk = [sys '/' s(1:i-1)];
if ~isKey(MOCK.blocks, blk), error('mock:add_line', 'No block "%s" (from "%s" in %s)', blk, s, sys); end
end
