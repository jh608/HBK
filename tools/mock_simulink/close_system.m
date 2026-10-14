function close_system(mdl, varargin)
global MOCK
idx = strcmp(MOCK.models, mdl);
if ~any(idx), return; end
MOCK.models(idx) = [];
ks = MOCK.blocks.keys();
for k = 1:numel(ks)
    if strncmp(ks{k}, [mdl '/'], numel(mdl) + 1), MOCK.blocks.remove(ks{k}); end
end
MOCK.order = MOCK.order(~strncmp(MOCK.order, [mdl '/'], numel(mdl) + 1));
MOCK.lines = MOCK.lines(~strncmp({MOCK.lines.sys}, mdl, numel(mdl)));
end
