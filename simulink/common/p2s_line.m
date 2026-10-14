function p2s_line(sys, src, varargin)
%P2S_LINE  Connect output port SRC ('Block/1') to one or more input ports ('Block/2', ...).
for k = 1:numel(varargin)
    add_line(sys, src, varargin{k}, 'autorouting', 'on');
end
end
