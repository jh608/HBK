function L = sim_check_dab(tstop, dt)
%SIM_CHECK_DAB  Build dab_fpga with the mock API and simulate it (fixed step) in Octave.
if nargin < 1, tstop = 100e-6; end
if nargin < 2, dt = 2e-9; end
run_build_check('dab');
tic;
L = mock_sim('dab_fpga', tstop, dt, 25);
fprintf('simulated %.0f us in %.1f s\n', tstop*1e6, toc);
end
