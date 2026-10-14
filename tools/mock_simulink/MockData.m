classdef MockData < handle
    properties
        Name = '';
        Scope = 'Input';
    end
    methods
        function obj = MockData(n)
            obj.Name = n;
        end
    end
end
