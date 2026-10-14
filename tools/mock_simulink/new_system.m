function new_system(mdl)
if ~exist('OCTAVE_VERSION', 'builtin'), error('mock:matlab', 'tools/mock_simulink is an Octave stand-in for Simulink: remove it from the MATLAB path'); end
global MOCK
if any(strcmp(MOCK.models, mdl)), error('mock:new_system', 'Model %s already exists', mdl); end
MOCK.models{end+1} = mdl;
MOCK.modelParams(mdl) = struct();
end
