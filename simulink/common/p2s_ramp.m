function p = p2s_ramp(sys, name, slope, start, X0, XFinal)
%P2S_RAMP  PLECS "Ramp": X0 until t = start, then rising (or falling) with SLOPE until XFINAL.
p = p2s_subsys(sys, name, {}, {'y'});
add_block('simulink/Sources/Clock', [p '/t'], 'Position', [30 30 60 60]);
add_block('simulink/User-Defined Functions/Fcn', [p '/Ramp'], ...
    'Expr', sprintf('(%s) + (%s)*(u(1)-(%s))*(u(1)>(%s))', X0, slope, start, start), 'Position', [100 30 260 60]);
add_block('simulink/Discontinuities/Saturation', [p '/Limit'], ...
    'UpperLimit', sprintf('max(%s,%s)', X0, XFinal), 'LowerLimit', sprintf('min(%s,%s)', X0, XFinal), 'Position', [300 30 340 60]);
add_line(p, 't/1', 'Ramp/1');
add_line(p, 'Ramp/1', 'Limit/1');
add_line(p, 'Limit/1', 'y/1');
end
