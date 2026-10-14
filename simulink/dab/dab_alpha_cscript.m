function [alphaP, alphaS] = dab_alpha_cscript(m, enable)
%DAB_ALPHA_CSCRIPT  Translation of the PLECS "C-Script" block in DAB FPGA.plecs: inner phase
%   shifts from the voltage gain m = Vo*n/Vi (minimum 0.045), zero when not enabled.
%#codegen
alphaP = 0;
alphaS = 0;
if enable == 1
    if m <= 1
        alphaP = max(0.5*(1 - m), 0.045);
        alphaS = 0.045;
    else
        alphaP = 0.045;
        alphaS = max(0.5*(1 - 1/m), 0.045);
    end
end
end
