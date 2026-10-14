function selftest()
%SELFTEST  Check that the mock rejects the kinds of mistakes it exists to catch.
here = fileparts(mfilename('fullpath')); addpath(here);
cases = {
  'unknown library path', @() add_block('simulink/Math Operations/Gainz', 'm/g');
  'unknown parameter',    @() add_block('simulink/Math Operations/Gain', 'm/g', 'Gian', '2');
  'bad enum value',       @() add_block('simulink/Signal Routing/Switch', 'm/s', 'Criteria', 'u2 > 0');
  'duplicate block',      @() dup();
  'missing block in line',@() add_line('m', 'nope/1', 'x/1');
  'slash in name',        @() add_block('simulink/Sources/Constant', 'm/a/b');
};
for k = 1:size(cases, 1)
    mock_reset(); new_system('m');
    ok = false;
    try, cases{k, 2}(); catch, ok = true; end
    if ~ok, error('selftest: mock accepted "%s"', cases{k, 1}); end
end
% structural: port out of range and unconnected input
mock_reset(); new_system('m');
add_block('simulink/Sources/Constant', 'm/c');
add_block('simulink/Math Operations/Sum', 'm/s', 'Inputs', '+-');
add_line('m', 'c/1', 's/1');
add_block('simulink/Sinks/Terminator', 'm/t'); add_line('m', 's/1', 't/1');
ok = false; try, mock_validate('m'); catch, ok = true; end
if ~ok, error('selftest: unconnected input not detected'); end
add_line('m', 'c/1', 's/3');
ok = false; try, mock_validate('m'); catch, ok = true; end
if ~ok, error('selftest: port out of range not detected'); end
fprintf('mock selftest passed\n');
end
function dup()
add_block('simulink/Sources/Constant', 'm/c'); add_block('simulink/Sources/Constant', 'm/c');
end
