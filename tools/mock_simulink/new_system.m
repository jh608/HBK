function new_system(mdl)
global MOCK
if any(strcmp(MOCK.models, mdl)), error('mock:new_system', 'Model %s already exists', mdl); end
MOCK.models{end+1} = mdl;
MOCK.modelParams(mdl) = struct();
end
