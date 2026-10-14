function v = get_param(obj, name)
global MOCK
if any(strcmp(MOCK.models, obj))
    switch name
        case 'FileName', v = '';
        case 'Name', v = obj;
        otherwise
            mp = MOCK.modelParams(obj);
            if isfield(mp, name), v = mp.(name); else, error('mock:get_param', 'Model param %s not set', name); end
    end
    return;
end
if ~isKey(MOCK.blocks, obj), error('mock:get_param', 'No block "%s"', obj); end
b = MOCK.blocks(obj);
switch name
    case 'Name', v = b.name;
    case 'Parent', v = b.parent;
    case 'ReferenceBlock', v = '';
    case 'SFBlockType'
        if strcmp(b.type, 'MATLABFunction'), v = 'MATLAB Function'; else, v = 'NONE'; end
    case 'BlockType', v = b.type;
    otherwise
        if isfield(b.params, name), v = b.params.(name); else, error('mock:get_param', 'Block %s has no param %s', obj, name); end
end
end
