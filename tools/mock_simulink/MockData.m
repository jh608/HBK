classdef MockData < handle
    properties
        Name = '';
        Scope = 'Input';
        Props = struct('Array', struct('Size', '-1'));
    end
    methods
        function obj = MockData(n)
            obj.Name = n;
        end
    end
end
