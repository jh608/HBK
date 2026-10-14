function [parent, name] = mock_split(path)
% split at the last '/' that is not part of '//' (escaped slash)
idx = strfind(path, '/');
k = numel(idx);
while k > 0
    i = idx(k);
    if (i > 1 && path(i-1) == '/') || (i < numel(path) && path(i+1) == '/')
        k = k - 1; continue;
    end
    break;
end
if k == 0, parent = ''; name = path; return; end
parent = path(1:idx(k)-1);
name = path(idx(k)+1:end);
end
