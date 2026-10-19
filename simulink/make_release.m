function make_release(version)
%MAKE_RELEASE  Rebuild the three models and copy what is needed to run them (not build them)
%   into ../release/<model>/: the .slx, its params script (run by the model's InitFcn) and
%   its plant file (called once by the params script for the initial measurements).
%   release/README.md is written by hand and left alone.
%   make_release            % models saved in the running MATLAB release
%   make_release('R2022b')  % models exported for an older release as well (overwrites the .slx)
here = fileparts(mfilename('fullpath'));
rel = fullfile(fileparts(here), 'release');
build_all;
models = {'dab', 'dab_fpga'; 'classd', 'classd_revb'; 'sixswitch', 'sixswitch'};
for k = 1:size(models, 1)
    src = fullfile(here, models{k, 1});
    dst = fullfile(rel, models{k, 1});
    if ~exist(dst, 'dir'), mkdir(dst); end
    mdl = models{k, 2};
    if nargin == 1
        close_system(mdl, 0);
        Simulink.exportToVersion(fullfile(src, [mdl '.slx']), fullfile(dst, [mdl '.slx']), version);
    else
        copyfile(fullfile(src, [mdl '.slx']), dst);
    end
    copyfile(fullfile(src, [models{k, 1} '_params.m']), dst);
    copyfile(fullfile(src, [models{k, 1} '_plant.m']), dst);
    fprintf('%s -> %s\n', mdl, dst);
end
bdclose all;
end
