function p = p2s_subsys(sys, name, inNames, outNames)
%P2S_SUBSYS  Create an empty subsystem with named inports/outports (in the given order).
p = [sys '/' name];
add_block('built-in/Subsystem', p, 'Position', p2s_pos(sys, 120, 30 + 20*max(numel(inNames), numel(outNames))));
for k = 1:numel(inNames)
    add_block('built-in/Inport', [p '/' inNames{k}], 'Port', num2str(k), 'Position', [20 40+60*(k-1) 50 54+60*(k-1)]);
end
for k = 1:numel(outNames)
    add_block('built-in/Outport', [p '/' outNames{k}], 'Port', num2str(k), 'Position', [900 40+60*(k-1) 930 54+60*(k-1)]);
end
end
