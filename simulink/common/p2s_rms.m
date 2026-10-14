function p = p2s_rms(sys, name, fexpr)
%P2S_RMS  PLECS "RMS Value": sqrt of the sliding mean of u^2 over one fundamental period 1/f.
p = p2s_subsys(sys, name, {'u'}, {'rms'});
add_block('simulink/Math Operations/Math Function', [p '/Square'], 'Operator', 'square', 'Position', [100 30 140 60]);
add_block('simulink/Continuous/Integrator', [p '/Int'], 'InitialCondition', '0', 'Position', [180 30 210 60]);
add_block('simulink/Continuous/Transport Delay', [p '/Delay'], 'DelayTime', ['1/(' fexpr ')'], 'InitialOutput', '0', 'BufferSize', '131072', 'Position', [250 90 300 120]);
add_block('simulink/Math Operations/Sum', [p '/Diff'], 'Inputs', '+-', 'Position', [340 30 360 70]);
add_block('simulink/Math Operations/Gain', [p '/Scale'], 'Gain', fexpr, 'Position', [400 30 440 70]);
add_block('simulink/Math Operations/Abs', [p '/Abs'], 'Position', [480 30 510 60]);
add_block('simulink/Math Operations/Sqrt', [p '/Sqrt'], 'Position', [550 30 580 60]);
add_line(p, 'u/1', 'Square/1');
add_line(p, 'Square/1', 'Int/1');
add_line(p, 'Int/1', 'Diff/1');
add_line(p, 'Int/1', 'Delay/1');
add_line(p, 'Delay/1', 'Diff/2');
add_line(p, 'Diff/1', 'Scale/1');
add_line(p, 'Scale/1', 'Abs/1');
add_line(p, 'Abs/1', 'Sqrt/1');
add_line(p, 'Sqrt/1', 'rms/1');
end
