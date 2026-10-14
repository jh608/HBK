function p2s_arrange(sys)
%P2S_ARRANGE  Auto-layout SYS and all subsystems below it (R2018a+; silently skipped before).
try
    subs = find_system(sys, 'LookUnderMasks', 'none', 'FollowLinks', 'off', 'BlockType', 'SubSystem');
    for k = 1:numel(subs)
        if isempty(get_param(subs{k}, 'ReferenceBlock')) && ~strcmp(get_param(subs{k}, 'SFBlockType'), 'MATLAB Function')
            Simulink.BlockDiagram.arrangeSystem(subs{k});
        end
    end
    Simulink.BlockDiagram.arrangeSystem(sys);
catch err %#ok<NASGU>
end
end
