function p = p2s_mfun(sys, name, code, paramNames, sizes)
%P2S_MFUN  MATLAB Function block with the given code. Arguments listed in PARAMNAMES are
%   turned into (tunable) parameters resolved from the workspace instead of input ports;
%   they must be the last arguments of the function so the port numbering is unaffected.
%   SIZES (optional) is a struct of input name -> size string (e.g. '[4 1]') for inputs
%   whose size Simulink cannot infer, such as inputs inside a loop through the block itself.
if nargin < 4, paramNames = {}; end
if nargin < 5, sizes = struct(); end
p = [sys '/' name];
add_block('simulink/User-Defined Functions/MATLAB Function', p, 'Position', p2s_pos(sys, 140, 80));
rt = sfroot;
chart = rt.find('-isa', 'Stateflow.EMChart', 'Path', p);
chart.Script = code;
for k = 1:numel(paramNames)
    d = chart.find('-isa', 'Stateflow.Data', 'Name', paramNames{k});
    d.Scope = 'Parameter';
end
f = fieldnames(sizes);
for k = 1:numel(f)
    d = chart.find('-isa', 'Stateflow.Data', 'Name', f{k});
    d.Props.Array.Size = sizes.(f{k});
end
end
