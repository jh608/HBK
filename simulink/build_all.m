function build_all()
%BUILD_ALL  Generate the three Simulink models translated from the PLECS models:
%   dab/dab_fpga.slx, classd/classd_revb.slx, sixswitch/sixswitch.slx
%   Each model is saved next to its *_params.m file; the model's InitFcn runs that script.
%   Requires Simulink only (no Simscape). Run from any folder:  build_all
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'common'));
dirs = {'dab', 'classd', 'sixswitch'};
for k = 1:numel(dirs)
    addpath(fullfile(here, dirs{k}));
end
dab_build(fullfile(here, 'dab'));
classd_build(fullfile(here, 'classd'));
sixswitch_build(fullfile(here, 'sixswitch'));
end
