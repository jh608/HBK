function p = p2s_mfun(sys, name, code, paramNames)
%P2S_MFUN  MATLAB Function block with the given code. Arguments listed in PARAMNAMES are
%   turned into (tunable) parameters resolved from the workspace instead of input ports;
%   they must be the last arguments of the function so the port numbering is unaffected.
if nargin < 4, paramNames = {}; end
p = [sys '/' name];
add_block('simulink/User-Defined Functions/MATLAB Function', p, 'Position', p2s_pos(sys, 140, 80));
rt = sfroot;
chart = rt.find('-isa', 'Stateflow.EMChart', 'Path', p);
chart.Script = code;
for k = 1:numel(paramNames)
    d = chart.find('-isa', 'Stateflow.Data', 'Name', paramNames{k});
    d.Scope = 'Parameter';
end
end
