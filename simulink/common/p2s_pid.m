function p = p2s_pid(sys, name, domain, kp, ki, x0, up, lo, awMode, kb, Ts)
%P2S_PID  PI controller replacing a PLECS (Discrete/Continuous) PID Controller: parallel form
%   kp*e + ki*integral(e), output limited to [lo up] with anti-windup.
%   domain: 'continuous' | 'discrete' (forward Euler, sample time Ts); awMode: 'back-calculation'
%   | 'clamping' | 'none' (no output limit). All numeric arguments are workspace expressions (strings).
if strcmp(domain, 'discrete')
    p = p2s_add(sys, 'simulink/Discrete/Discrete PID Controller', name, ...
        'SampleTime', Ts, 'IntegratorMethod', 'Forward Euler');
else
    p = p2s_add(sys, 'simulink/Continuous/PID Controller', name);
end
set_param(p, 'Controller', 'PI', 'Form', 'Parallel', 'P', kp, 'I', ki, ...
    'InitialConditionForIntegrator', x0);
if strcmp(awMode, 'none')       % unlimited PI
    set_param(p, 'LimitOutput', 'off');
    return;
end
set_param(p, 'LimitOutput', 'on', 'UpperSaturationLimit', up, 'LowerSaturationLimit', lo, ...
    'AntiWindupMode', awMode);
if strcmp(awMode, 'back-calculation')
    set_param(p, 'Kb', kb);
end
end
