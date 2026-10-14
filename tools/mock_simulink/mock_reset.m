function mock_reset()
%MOCK_RESET  Clear the mock Simulink database.
global MOCK
MOCK = struct();
MOCK.models = {};
MOCK.blocks = containers.Map();
MOCK.order = {};
MOCK.lines = struct('sys', {}, 'src', {}, 'sport', {}, 'dst', {}, 'dport', {});
MOCK.charts = containers.Map();
MOCK.modelParams = containers.Map();
MOCK.saved = {};
end
