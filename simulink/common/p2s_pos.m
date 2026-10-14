function pos = p2s_pos(sys, w, h)
%P2S_POS  Next free default position in SYS (a simple grid; p2s_arrange tidies up later).
persistent counts
if isempty(counts), counts = containers.Map(); end
if nargin < 2, w = 40; end
if nargin < 3, h = 30; end
if isKey(counts, sys), n = counts(sys); else, n = 0; end
counts(sys) = n + 1;
col = floor(n / 12); row = mod(n, 12);
x = 40 + col*140; y = 40 + row*70;
pos = [x y x+w y+h];
end
