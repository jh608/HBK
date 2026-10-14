function p = p2s_moving_avg(sys, name, Texpr)
%P2S_MOVING_AVG  PLECS "Moving Average": sliding-window mean over the last T seconds
%   (zero history before t = 0, as the PLECS buffer is initialised with x0 = 0).
p = p2s_subsys(sys, name, {'u'}, {'avg'});
add_block('simulink/Continuous/Integrator', [p '/Int'], 'InitialCondition', '0', 'Position', [100 30 130 60]);
add_block('simulink/Continuous/Transport Delay', [p '/Delay'], 'DelayTime', Texpr, 'InitialOutput', '0', 'BufferSize', '131072', 'Position', [180 90 230 120]);
add_block('simulink/Math Operations/Sum', [p '/Diff'], 'Inputs', '+-', 'Position', [300 30 320 70]);
add_block('simulink/Math Operations/Gain', [p '/Scale'], 'Gain', ['1/(' Texpr ')'], 'Position', [380 30 420 70]);
add_line(p, 'u/1', 'Int/1');
add_line(p, 'Int/1', 'Diff/1');
add_line(p, 'Int/1', 'Delay/1');
add_line(p, 'Delay/1', 'Diff/2');
add_line(p, 'Diff/1', 'Scale/1');
add_line(p, 'Scale/1', 'avg/1');
end
