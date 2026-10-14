function h = add_block(src, dst, varargin)
if ~exist('OCTAVE_VERSION', 'builtin'), error('mock:matlab', 'tools/mock_simulink is an Octave stand-in for Simulink: remove it from the MATLAB path'); end
global MOCK
T = mock_libtable();
if ~isKey(T, src), error('mock:add_block', 'Unknown library block "%s"', src); end
if isKey(MOCK.blocks, dst), error('mock:add_block', 'Block "%s" already exists', dst); end
[parent, name] = mock_split(dst);
if ~(any(strcmp(MOCK.models, parent)) || (isKey(MOCK.blocks, parent) && strcmp(MOCK.blocks(parent).type, 'SubSystem')))
    error('mock:add_block', 'Parent "%s" of "%s" does not exist or is not a subsystem', parent, dst);
end
if isempty(name), error('mock:add_block', 'Empty block name in "%s"', dst); end
lib = T(src);
b.lib = src;
b.type = lib.type;
b.parent = parent;
b.name = name;
b.params = struct();
for k = 1:2:numel(lib.defaults)
    b.params.(lib.defaults{k}) = lib.defaults{k+1};
end
MOCK.blocks(dst) = b;
MOCK.order{end+1} = dst;
if strcmp(b.type, 'MATLABFunction')
    MOCK.charts(dst) = MockChart(dst);
end
for k = 1:2:numel(varargin)
    set_param(dst, varargin{k}, varargin{k+1});
end
h = dst;
end
