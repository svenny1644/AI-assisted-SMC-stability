clc; close all;
% === 1. DEFINE THE GYM (SIMULINK ENVIRONMENT) ===
mdl = 'CMSD_Training_Env';
open_system(mdl);

agentBlock = [mdl, '/RL Agent']; 
obsInfo = rlNumericSpec([7 1], 'Name', 'Observations');
actInfo = rlNumericSpec([1 1], 'LowerLimit', -1, 'UpperLimit', 1, 'Name', 'Action_u');

env = rlSimulinkEnv(mdl, agentBlock, obsInfo, actInfo);

% ---> UPGRADE 1: Point to the custom dual-randomizer reset function
env.ResetFcn = @myResetFunction; 

% ... (Keep your actorNetwork and criticNet layer configurations here) ...

% === 2. BUILD THE ACTOR NETWORK (THE DRIVER) ===

% 1. Define the network architecture explicitly in the script
actorNetwork = [
    featureInputLayer(obsInfo.Dimension(1), 'Name', 'obs_in')
    fullyConnectedLayer(128)
    reluLayer
    fullyConnectedLayer(128)
    reluLayer
    fullyConnectedLayer(actInfo.Dimension(1))
    tanhLayer('Name', 'tanh_limit') 
];

% 2. Create the Actor Object and send it to the RTX 3080 Ti
actor = rlContinuousDeterministicActor(actorNetwork, obsInfo, actInfo, ...
    'UseDevice', 'gpu');

% === 3. BUILD THE CRITIC NETWORKS (THE COACHES) ===
% We now build the Critic directly in the script for a bulletproof setup!

% 1. The Observation Path (Automatically adapts to your 7 inputs)
obsPath = [
    featureInputLayer(obsInfo.Dimension(1), 'Name', 'obs_in')
    fullyConnectedLayer(128, 'Name', 'obs_fc')
];

% 2. The Action Path (Takes the Actor's proposed motor force)
actPath = [
    featureInputLayer(actInfo.Dimension(1), 'Name', 'action_out')
    fullyConnectedLayer(128, 'Name', 'act_fc')
];

% 3. The Common Path (Merges them and calculates the Q-Value Score)
commonPath = [
    additionLayer(2, 'Name', 'add')
    reluLayer('Name', 'relu_1')
    fullyConnectedLayer(128, 'Name', 'fc_2')
    reluLayer('Name', 'relu_2')
    fullyConnectedLayer(1, 'Name', 'QValue')
];

% Assemble the Network Graph
criticNet = layerGraph(obsPath);
criticNet = addLayers(criticNet, actPath);
criticNet = addLayers(criticNet, commonPath);

% Wire the paths together
criticNet = connectLayers(criticNet, 'obs_fc', 'add/in1');
criticNet = connectLayers(criticNet, 'act_fc', 'add/in2');

% Create the actual Critic Objects and send them to the RTX 3080 Ti
critic1 = rlQValueFunction(criticNet, obsInfo, actInfo, ...
    'ObservationInputNames', 'obs_in', 'ActionInputNames', 'action_out', ...
    'UseDevice', 'gpu');

critic2 = rlQValueFunction(criticNet, obsInfo, actInfo, ...
    'ObservationInputNames', 'obs_in', 'ActionInputNames', 'action_out', ...
    'UseDevice', 'gpu'); 

% Define Optimizers
criticOpts = rlOptimizerOptions('LearnRate', 1e-3, 'GradientThreshold', 1);
actorOpts  = rlOptimizerOptions('LearnRate', 1e-4, 'GradientThreshold', 1);

% === 4. AGENT TRAINING SETTINGS ===
agentOptions = rlTD3AgentOptions;
agentOptions.DiscountFactor = 0.99;
agentOptions.ExperienceBufferLength = 1e6;
agentOptions.ActorOptimizerOptions = actorOpts;
agentOptions.CriticOptimizerOptions = criticOpts;
agentOptions.ExplorationModel.Variance = 0.5;
agentOptions.ExplorationModel.VarianceDecayRate = 1e-4;

agentObj = rlTD3Agent(actor, [critic1 critic2], agentOptions);

% ---> UPGRADE 2: Create the 'Agents' folder if it doesn't exist
agentDir = fullfile(pwd, 'Agents');
if ~exist(agentDir, 'dir')
    mkdir(agentDir);
end

% === 5. RTX PARALLEL TRAINING SETUP ===
trainOpts = rlTrainingOptions(...
    'MaxEpisodes', 10000, ...                    
    'MaxStepsPerEpisode', 6000, ... 
    'ScoreAveragingWindowLength', 50, ...
    'Verbose', false, ...
    'Plots', 'training-progress', ...
    'UseParallel', true, ...
    'SaveAgentCriteria', 'AverageReward', ... % Filter out the suicides
    'SaveAgentValue', 0, ...                  % Only save when it actually learns to drive
    'SaveAgentDirectory', agentDir);

% === 6. START THE WORKOUT ===
disp('Starting Training... Grab a coffee and watch the Episode Manager!');
trainingStats = train(agentObj, env, trainOpts);

% === 7. POST-TRAINING MAGIC (RENAMING & PLOTTING) ===
disp('Training Complete! Processing files and generating graphs...');

% 7a. Rename the Agent Files with their Reward Scores
savedFiles = dir(fullfile(agentDir, 'savedAgent_*.mat'));
for i = 1:length(savedFiles)
    oldName = savedFiles(i).name;
    
    % Extract the episode number from the file name
    epNumStr = regexp(oldName, 'Episode(\d+)', 'tokens');
    if ~isempty(epNumStr)
        epNum = str2double(epNumStr{1}{1});
        
        % Find the exact reward for that episode in the stats
        idx = find(trainingStats.EpisodeIndex == epNum);
        if ~isempty(idx)
            epReward = trainingStats.EpisodeReward(idx);
            
            % Format the reward string (e.g., -0.5 becomes -0,5)
            rewardStr = sprintf('%.1f', epReward);
            rewardStr = strrep(rewardStr, '.', ',');
            
            % Create the new filename and rename the file
            newName = sprintf('reward%s_%s', rewardStr, oldName);
            movefile(fullfile(agentDir, oldName), fullfile(agentDir, newName));
        end
    end
end
disp('All agents successfully renamed inside the Agents folder.');

% 7b. Plot the "Survived Steps" Graph
figure('Name', 'AI Survival Performance', 'Color', 'w');
plot(trainingStats.EpisodeIndex, trainingStats.EpisodeSteps, 'b-', 'LineWidth', 1.5);
xlabel('Episode Number');
ylabel('Steps Survived');
title('Simulated Steps Survived Before Safety Kill');
grid on;


% === CUSTOM ENVIRONMENT RESET FUNCTION ===
function in = myResetFunction(in)
    % Generate random integers
    new_noise = randi([1, 100000]);
    new_ref   = randi([1, 100000]);
    
    % Inject them into the Simulink environment
    in = setVariable(in, 'noise_seed', new_noise);
    in = setVariable(in, 'ref_seed', new_ref);
end