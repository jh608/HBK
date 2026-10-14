function kids = mock_children(sys)
global MOCK
kids = {};
for k = 1:numel(MOCK.order)
    p = MOCK.order{k};
    b = MOCK.blocks(p);
    if strcmp(b.parent, sys), kids{end+1} = p; end %#ok<AGROW>
end
end
