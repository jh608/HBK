function p = p2s_add(sys, lib, name, varargin)
%P2S_ADD  Add a library block to SYS with parameter name/value pairs; returns its path.
%   p = p2s_add('mdl/Sub', 'simulink/Math Operations/Gain', 'K1', 'Gain', 'Kp')
p = [sys '/' name];
add_block(lib, p, 'Position', p2s_pos(sys));
for k = 1:2:numel(varargin)
    set_param(p, varargin{k}, varargin{k+1});
end
end
