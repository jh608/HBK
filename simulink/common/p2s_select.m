function p = p2s_select(sys, name, condExpr)
%P2S_SELECT  Two-way selector replacing a PLECS Manual Signal Switch: a subsystem whose
%   output is input 1 when CONDEXPR (a workspace expression, e.g. 'sel_vref == 1') is true and
%   input 2 otherwise.
p = p2s_subsys(sys, name, {'a', 'b'}, {'y'});
add_block('simulink/Sources/Constant', [p '/sel'], 'Value', ['double(' condExpr ')'], 'Position', [120 100 180 130]);
add_block('simulink/Signal Routing/Switch', [p '/Switch'], 'Criteria', 'u2 > Threshold', 'Threshold', '0.5', 'Position', [300 40 340 120]);
add_line(p, 'a/1', 'Switch/1');
add_line(p, 'sel/1', 'Switch/2');
add_line(p, 'b/1', 'Switch/3');
add_line(p, 'Switch/1', 'y/1');
end
