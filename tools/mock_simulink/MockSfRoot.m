classdef MockSfRoot < handle
    methods
        function c = find(obj, varargin)
            global MOCK
            path = '';
            for k = 1:2:numel(varargin)
                if strcmp(varargin{k}, 'Path'), path = varargin{k+1}; end
            end
            if ~isKey(MOCK.charts, path), error('mock:sfroot', 'No MATLAB Function block at "%s"', path); end
            c = MOCK.charts(path);
        end
    end
end
