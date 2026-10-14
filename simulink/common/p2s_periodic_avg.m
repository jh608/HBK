function p = p2s_periodic_avg(sys, name, Texpr)
%P2S_PERIODIC_AVG  PLECS "Periodic Average": mean of the input over the last completed
%   period T, updated (and held) at multiples of T.
p = p2s_subsys(sys, name, {'u'}, {'avg'});
add_block('simulink/Continuous/Integrator', [p '/Int'], 'InitialCondition', '0', 'Position', [100 30 130 60]);
add_block('simulink/Discrete/Zero-Order Hold', [p '/Sample'], 'SampleTime', Texpr, 'Position', [180 30 210 60]);
add_block('simulink/Discrete/Unit Delay', [p '/Prev'], 'SampleTime', Texpr, 'InitialCondition', '0', 'Position', [260 90 290 120]);
add_block('simulink/Math Operations/Sum', [p '/Diff'], 'Inputs', '+-', 'Position', [340 30 360 70]);
add_block('simulink/Math Operations/Gain', [p '/Scale'], 'Gain', ['1/(' Texpr ')'], 'Position', [420 30 460 70]);
add_line(p, 'u/1', 'Int/1');
add_line(p, 'Int/1', 'Sample/1');
add_line(p, 'Sample/1', 'Diff/1');
add_line(p, 'Sample/1', 'Prev/1');
add_line(p, 'Prev/1', 'Diff/2');
add_line(p, 'Diff/1', 'Scale/1');
add_line(p, 'Scale/1', 'avg/1');
end
