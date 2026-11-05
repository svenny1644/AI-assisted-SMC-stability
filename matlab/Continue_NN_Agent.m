clc; close all;

% =========================================================================
% Continue_NN_Agent.m  —  CMSD Meta-RL Phase 2: Fine-Tuning
% Purpose: Load an elite brain, lower exploration noise, and train against
%          stricter tracking/overshoot constraints.
% =========================================================================

% === 1. DEFINE THE GYM (SIMULINK ENVIRONMENT) ===
Ts_AI = 0.1;  % The AI's macro-clock (10x slower than the physics engine)        
mdl   = 'RL_SMC_Training_Env';
open_system(mdl);

agentBlock = [mdl, '/RL Agent'];

% Observation: 12x1 Vector
% [x1, x2, v1, v2, x2_ref, x2_error, time_since_change, s, C2_prev, C4_prev, eta_prev, phi_prev]
obsInfo = rlNumericSpec([12 1], 'Name', 'Observations');
obsInfo.LowerLimit = [-2; -2; -5; -5; -2; -4;  0; -50; -1; -1; -1; -1];
obsInfo.UpperLimit = [ 2;  2;  5;  5;  2;  4; 60;  50;  1;  1;  1;  1];

% Action: 4x1 Vector [C2, C4, Eta, Phi]
actInfo = rlNumericSpec([4 1], 'LowerLimit', -1, 'UpperLimit', 1, 'Name', 'SMC_Params');

env = rlSimulinkEnv(mdl, agentBlock, obsInfo, actInfo);
env.ResetFcn = @myResetFunction;

% =========================================================================
% === 2. LOAD THE ELITE BRAIN (PHASE 1 WEIGHTS) ===
% =========================================================================
agentDir = fullfile(pwd, 'Agents');
brainFile = fullfile(agentDir, 'Agent384.mat');

if exist(brainFile, 'file')
    disp(['Loading brain: ', brainFile]);
    load(brainFile, 'saved_agent');
    metaObj = saved_agent;
else
    error('Could not find brain file! Check the filename and path.');
end

% =========================================================================
% === 3. ADJUST HYPERPARAMETERS FOR FINE-TUNING ===
% =========================================================================
% We drop the variance significantly. The AI already knows how to drive; 
% it just needs to make microscopic adjustments to its braking timing.
metaObj.AgentOptions.ExplorationModel.Variance = 0.05; 
metaObj.AgentOptions.ExplorationModel.VarianceMin = 0.01;

% =========================================================================
% === 4. PHASE 2 TRAINING OPTIONS ===
% =========================================================================
trainOpts = rlTrainingOptions(...
    'MaxEpisodes',              5000,  ...       % Give it plenty of time to refine
    'MaxStepsPerEpisode',       600,   ...       % 60 seconds
    'ScoreAveragingWindowLength', 50,  ...
    'Verbose',                  false, ...
    'Plots',                    'training-progress', ... 
    'UseParallel',              false, ...   
    'SaveAgentCriteria',        'AverageReward', ...     
    'SaveAgentValue',           2600,   ...      % Raised bar: only save god-tier runs
    'StopTrainingCriteria',     'AverageReward', ... 
    'StopTrainingValue',        Inf,    ...      % Let it keep running to find the absolute max
    'SaveAgentDirectory',       agentDir);

% =========================================================================
% === 5. START TRAINING ===
% =========================================================================
disp('Starting Phase 2 Fine-Tuning — GPU active.');
trainingStats = train(metaObj, env, trainOpts);

% =========================================================================
% === 6. POST-TRAINING: RENAME FILES ===
% =========================================================================
disp('Training complete. Renaming Phase 2 checkpoints...');

savedFiles = dir(fullfile(agentDir, 'savedAgent_*.mat'));
for i = 1:length(savedFiles)
    oldName   = savedFiles(i).name;
    % Extract the episode number from the default MATLAB filename
    epNumStr  = regexp(oldName, 'Episode(\d+)', 'tokens');
    
    if ~isempty(epNumStr)
        epNum = str2double(epNumStr{1}{1});
        
        % Create the clean, simple new name
        newName = sprintf('Agent%d_Phase2.mat', epNum);
        
        % Rename the file
        movefile(fullfile(agentDir, oldName), fullfile(agentDir, newName));
    end
end
disp('Phase 2 Checkpoints renamed to AgentXXX_Phase2.mat');

% =========================================================================
% === CUSTOM MATLAB FUNCTIONS ===
% =========================================================================

% Dual-Randomizer for Environment Reset
function in = myResetFunction(in)
    new_noise = randi([1, 100000]);
    new_ref   = randi([1, 100000]);
    
    in = setVariable(in, 'noise_seed', new_noise);
    in = setVariable(in, 'ref_seed',   new_ref);
    
    % Print to command window to prove it is randomizing
    %fprintf('Episode Reset -> Noise: %d | Ref: %d\n', new_noise, new_ref);
end