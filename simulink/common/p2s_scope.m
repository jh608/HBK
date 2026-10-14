function p = p2s_scope(sys, name, nIn)
%P2S_SCOPE  Scope with NIN inputs.
p = p2s_add(sys, 'simulink/Sinks/Scope', name, 'NumInputPorts', num2str(nIn));
end
