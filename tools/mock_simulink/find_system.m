function out = find_system(sys, varargin)
global MOCK
out = {};
bt = '';
for k = 1:2:numel(varargin)
    if strcmp(varargin{k}, 'BlockType'), bt = varargin{k+1}; end
end
for k = 1:numel(MOCK.order)
    p = MOCK.order{k};
    if strncmp(p, [sys '/'], numel(sys) + 1)
        b = MOCK.blocks(p);
        if isempty(bt) || strcmp(b.type, bt), out{end+1, 1} = p; end %#ok<AGROW>
    end
end
end
