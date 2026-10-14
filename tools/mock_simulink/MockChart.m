classdef MockChart < handle
    properties
        Path = '';
        Script = '';
        Data = {};
    end
    methods
        function obj = MockChart(p)
            obj.Path = p;
        end
        function d = find(obj, varargin)
            name = '';
            for k = 1:2:numel(varargin)
                if strcmp(varargin{k}, 'Name'), name = varargin{k+1}; end
            end
            [ins, ~] = mock_mfun_signature(obj.Script);
            if ~any(strcmp(ins, name)), error('mock:chart', 'MATLAB Function %s has no argument "%s"', obj.Path, name); end
            for k = 1:numel(obj.Data)
                if strcmp(obj.Data{k}.Name, name), d = obj.Data{k}; return; end
            end
            d = MockData(name);
            obj.Data{end+1} = d;
        end
    end
end
