% Open-loop check of dab_plant.m: square-wave gating with a fixed phase shift, forward Euler.
% Run from Octave/MATLAB:  cd tools/plant_checks; check_dab_plant
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', '..', 'simulink', 'dab'));
dab_params;
phi = 0.08;          % phase shift [cycles], primary leading
f = SwitchingFrequency; td = DeadTime;
dt = 2e-9; T = 300e-6; N = round(T/dt);
x = Pdab.x0; iload = Pout/Vout;
logv = zeros(N/50, 4); k = 0;
for n = 1:N
  t = (n-1)*dt;
  sq = @(th) [sin(2*pi*(f*t-th))>0 && sin(2*pi*(f*t-th-td*f))>0, sin(2*pi*(f*t-th))<0 && sin(2*pi*(f*t-th-td*f))<0];
  gp = [sq(1-phi), sq(0.5-phi)];   % primary legs P (theta = x+0.5) and N (theta = x)
  gs = [sq(0), sq(0.5)];
  [dx, y] = dab_plant(x, gp, gs, [x(1)>0; x(3)>0], iload, Pdab);
  x = x + dt*dx;
  if mod(n,50)==0, k=k+1; logv(k,:) = [t y(1) y(4) y(8)]; end
end
fprintf('Vo start %.2f end %.2f V\n', logv(1,2), logv(end,2));
last = logv(end-round(2/f/(50*dt)):end, :);
fprintf('i1 peak over last 2 periods %.1f A, mean Pin %.0f W\n', max(abs(last(:,3))), mean(last(:,4)));
