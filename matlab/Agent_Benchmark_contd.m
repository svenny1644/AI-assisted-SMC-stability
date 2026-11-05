% =========================================================================
% The Agent Arena: Auto-Benchmarker & Safe Copier (Resume Edition)
% =========================================================================
clc; 
disp('Initializing the Agent Arena...');

% IMPORTANT: Ensure your physical parameters (mass, etc.) are already in the workspace!
% We also inject dummy seeds just in case the env requires them to initialize.
assignin('base', 'noise_seed', 23341);
assignin('base', 'ref_seed', 12345);

fprintf('Locked Noise Seed: 23341 | Locked Ref Seed: 12345\n');

% --- 1. Rebuild the Environment ---
mdl = 'RL_SMC_Training_Env';
open_system(mdl);
agentBlock = [mdl, '/RL Agent'];

% Rebuild your exact 13x1 granular limits
obsInfo = rlNumericSpec([13 1], 'Name', 'Observations');
obsInfo.LowerLimit = [-0.8; -0.8; -2.5; -2.5; -0.6; -1.5;   0; -30; -1; -1; -1; -1; -0.4];
obsInfo.UpperLimit = [ 0.8;  0.8;  2.5;  2.5;  0.6;  1.5; 3.5;  30;  1;  1;  1;  1;  0.4];

actInfo = rlNumericSpec([4 1], 'LowerLimit', -1, 'UpperLimit', 1, 'Name', 'SMC_Params');

env = rlSimulinkEnv(mdl, agentBlock, obsInfo, actInfo);

% --- 2. Setup the Arena & Directories ---
agentDir   = fullfile(pwd, 'Agents');
renamedDir = fullfile(pwd, 'Renamed_Agents');

if ~exist(renamedDir, 'dir')
    mkdir(renamedDir);
    disp('Created \Renamed_Agents folder.');
end

files = dir(fullfile(agentDir, '*.mat'));
simOpts = rlSimulationOptions('MaxSteps', 3000, 'NumSimulations', 1);

% Define the starting point
resume_agent_number = 4643;

disp(['Found ', num2str(length(files)), ' agents. Resuming from Agent ', num2str(resume_agent_number), '...']);
fprintf('----------------------------------------------------\n');

% --- 3. The Gauntlet Loop ---
for i = 1:length(files)
    oldName = files(i).name;
    
    % --- RESUME FILTER ---
    % Extract the number from the file name
    epNumStrCheck = regexp(oldName, '\d+', 'match');
    if ~isempty(epNumStrCheck)
        currentAgentNum = str2double(epNumStrCheck{end});
        
        % If the agent number is less than our target, skip it instantly
        if currentAgentNum < resume_agent_number
            continue; 
        end
    end
    % ---------------------

    fprintf('Testing %s... ', oldName);
    
    try
        % DYNAMIC LOAD: Load the file as a struct, grab the first variable
        loadedData = load(fullfile(agentDir, oldName));
        varNames   = fieldnames(loadedData);
        test_agent = loadedData.(varNames{1}); % Extracts the brain dynamically
        
        % Drop it in the simulation
        experience = sim(env, test_agent, simOpts);
        
        % Calculate total exact score from the run
        epScore = sum(experience.Reward);
        fprintf('Score: %.2f\n', epScore);
        
        % Extract any numbers from the old name
        epNumStr = regexp(oldName, '\d+', 'match');
        if ~isempty(epNumStr)
            epNum = epNumStr{end};
        else
            epNum = num2str(i);
        end
        
        % Forge the new name and COPY it
        newName = sprintf('Tested_Reward%.0f_Agent%s.mat', epScore, epNum);
        copyfile(fullfile(agentDir, oldName), fullfile(renamedDir, newName));
        
    catch ME
        % If it fails, print the EXACT reason why
        fprintf(2, 'FAILED! Reason: %s\n', ME.message); 
    end
end

fprintf('----------------------------------------------------\n');
disp('Benchmarking complete! Check the \Renamed_Agents folder.');