function save_system(mdl, file)
global MOCK
mock_validate(mdl);
MOCK.saved{end+1} = file;
end
