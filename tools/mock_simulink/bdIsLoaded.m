function tf = bdIsLoaded(mdl)
global MOCK
tf = any(strcmp(MOCK.models, mdl));
end
