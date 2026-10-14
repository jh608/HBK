function run_build_check(which)
%RUN_BUILD_CHECK  Run a model build script against the mock Simulink API (Octave).
here = fileparts(mfilename('fullpath'));
addpath(here);
root = fullfile(here, '..', '..', 'simulink');
addpath(fullfile(root, 'common'));
addpath(fullfile(root, which));
mock_reset();
tmp = tempname(); mkdir(tmp);
feval([which '_build'], tmp);
end
