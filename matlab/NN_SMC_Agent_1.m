clc; close all;

% =========================================================================
% NN_Agent.m  —  CMSD Meta-RL Tuning Agent
% Architecture: Supervisory TD3 (0.1s Sample Time)
% Output: [C2, C4, Eta, Phi]
% =========================================================================

% === 1. DEFINE THE GYM (SIMULINK ENVIRONMENT) ===
Ts_AI = 0.02;  % The AI's macro-clock (2x slower than the physics engine)        
mdl   = 'RL_SMC_Training_Env';
open_system(mdl);

agentBlock = [mdl, '/RL Agent'];

% Observation: 13x1 Vector
% [x1, x2, v1, v2, x2_ref, x2_error, time_since_change, s, C2_prev, C4_prev, eta_prev, phi_prev, ref_jump]
obsInfo = rlNumericSpec([13 1], 'Name', 'Observations');

% --- Granular Limits for the 3s Bounded Slalom ---
% x1, x2:    Capped at +/- 0.8 (Death wall is at 0.65)
% v1, v2:    Capped at +/- 2.5 (Max observed is ~2.0)
% x2_ref:    Capped at +/- 0.6 (Saturation is -0.2 to 0.5)
% x2_error:  Capped at +/- 1.5 (Max possible difference)
% time:      Capped at 3.5s (Resets every 3.0s)
% s:         Capped at +/- 30 (Lower speeds mean smaller sliding surface)
% actions:   Must remain [-1, 1] for TD3 outputs
% ref_jump:  Capped at +/- 0.4 (Max jump is 0.3)

obsInfo.LowerLimit = [-0.8; -0.8; -2.5; -2.5; -0.6; -1.5;   0; -30; -1; -1; -1; -1; -0.4];
obsInfo.UpperLimit = [ 0.8;  0.8;  2.5;  2.5;  0.6;  1.5; 3.5;  30;  1;  1;  1;  1;  0.4];

% Action: 4x1 Vector
% [C2_tune, C4_tune, Eta_tune, Phi_tune]
actInfo = rlNumericSpec([4 1], 'LowerLimit', -1, 'UpperLimit', 1, 'Name', 'SMC_Params');

env = rlSimulinkEnv(mdl, agentBlock, obsInfo, actInfo);
env.ResetFcn = @myResetFunction;

% =========================================================================
% === 2. BUILD THE ACTOR NETWORK (THE SUPERVISOR) ===
% =========================================================================
actorNetwork = [
    featureInputLayer(obsInfo.Dimension(1), 'Name', 'obs_in')
    fullyConnectedLayer(256, 'Name', 'fc1')
    tanhLayer('Name', 'tanh1')
    fullyConnectedLayer(256, 'Name', 'fc2')
    tanhLayer('Name', 'tanh2')
    fullyConnectedLayer(256, 'Name', 'fc3')
    tanhLayer('Name', 'tanh3')
    fullyConnectedLayer(actInfo.Dimension(1), 'Name', 'fc_out')
    tanhLayer('Name', 'tanh_limit')
];

actor = rlContinuousDeterministicActor(actorNetwork, obsInfo, actInfo, 'UseDevice', 'gpu');

% =========================================================================
% === 3. BUILD THE CRITIC NETWORKS (THE COACHES) ===
% =========================================================================
criticNet1 = buildCriticGraph(obsInfo.Dimension(1), actInfo.Dimension(1));
criticNet2 = buildCriticGraph(obsInfo.Dimension(1), actInfo.Dimension(1));

critic1 = rlQValueFunction(criticNet1, obsInfo, actInfo, ...
    'ObservationInputNames', 'obs_in', 'ActionInputNames', 'action_out', 'UseDevice', 'gpu');

critic2 = rlQValueFunction(criticNet2, obsInfo, actInfo, ...
    'ObservationInputNames', 'obs_in', 'ActionInputNames', 'action_out', 'UseDevice', 'gpu');

% =========================================================================
% === 4. AGENT HYPERPARAMETERS ===
% =========================================================================
criticOpts = rlOptimizerOptions('LearnRate', 3e-4, 'GradientThreshold', 1);
actorOpts  = rlOptimizerOptions('LearnRate', 1e-4, 'GradientThreshold', 1);

agentOptions = rlTD3AgentOptions;
agentOptions.SampleTime               = Ts_AI;  % AI operates every 0.1s
agentOptions.DiscountFactor           = 0.99;
agentOptions.MiniBatchSize            = 256;    
agentOptions.ExperienceBufferLength   = 1e6;
agentOptions.ActorOptimizerOptions    = actorOpts;
agentOptions.CriticOptimizerOptions   = criticOpts;

% High exploration variance to map out the tuning space quickly
agentOptions.ExplorationModel.Variance          = 1.0;
agentOptions.ExplorationModel.VarianceDecayRate = 5e-6;
agentOptions.ExplorationModel.VarianceMin       = 0.05; 

% Create the new Meta Object
metaObj = rlTD3Agent(actor, [critic1 critic2], agentOptions);

agentDir = fullfile(pwd, 'Agents');
if ~exist(agentDir, 'dir')
    mkdir(agentDir);
end

% =========================================================================
% === 5. TRAINING OPTIONS ===
% =========================================================================
trainOpts = rlTrainingOptions(...
    'MaxEpisodes',              5000, ...
    'MaxStepsPerEpisode',       3000,   ...       % 600 steps * 0.1s = 60 seconds
    'ScoreAveragingWindowLength', 50,  ...
    'Verbose',                  false, ...
    'Plots',                    'training-progress', ... 
    'UseParallel',              false, ...   
    'SaveAgentCriteria',        'AverageReward', ...     
    'SaveAgentValue',           1700,   ...
    'StopTrainingCriteria',     'AverageReward', ... 
    'StopTrainingValue',        2600,    ...          
    'SaveAgentDirectory',       agentDir);

% =========================================================================
% === 6. START TRAINING ===
% =========================================================================
disp('Starting Meta-RL Training — GPU active.');
trainingStats = train(metaObj, env, trainOpts);

% =========================================================================
% === 7. POST-TRAINING: RENAME FILES & PLOT ===
% =========================================================================
disp('Training complete. Renaming checkpoints...');

savedFiles = dir(fullfile(agentDir, 'savedAgent_*.mat'));
for i = 1:length(savedFiles)
    oldName   = savedFiles(i).name;
    epNumStr  = regexp(oldName, 'Episode(\d+)', 'tokens');
    if ~isempty(epNumStr)
        epNum = str2double(epNumStr{1}{1});
        idx   = find(trainingStats.EpisodeIndex == epNum);
        if ~isempty(idx)
            epReward  = trainingStats.EpisodeReward(idx);
            rewardStr = strrep(sprintf('%.1f', epReward), '.', ',');
            newName   = sprintf('reward%s_%s', rewardStr, oldName);
            movefile(fullfile(agentDir, oldName), fullfile(agentDir, newName));
        end
    end
end
disp('Checkpoints renamed.');

figure('Name', 'Meta-RL Survival Performance', 'Color', 'w');
plot(trainingStats.EpisodeIndex, trainingStats.EpisodeSteps, 'b-', 'LineWidth', 1.2);
xlabel('Episode'); ylabel('Steps survived (Max 600)');
title('Steps Survived Before Safety Kill');
grid on;

figure('Name', 'Average Reward', 'Color', 'w');
plot(trainingStats.EpisodeIndex, trainingStats.AverageReward, 'r-', 'LineWidth', 1.5);
xlabel('Episode'); ylabel('Average reward (50-ep window)');
title('Training Convergence');
yline(0, '--k', 'Zero line'); grid on;


% =========================================================================
% === CUSTOM MATLAB FUNCTIONS ===
% =========================================================================

% 1. Twin-Critic Graph Generator
function criticNet = buildCriticGraph(obsDim, actDim)
    obsPath = [
        featureInputLayer(obsDim,  'Name', 'obs_in')
        fullyConnectedLayer(256,   'Name', 'obs_fc')
        tanhLayer('Name', 'obs_tanh')
    ];
    actPath = [
        featureInputLayer(actDim,  'Name', 'action_out')
        fullyConnectedLayer(256,   'Name', 'act_fc')
        tanhLayer('Name', 'act_tanh')
    ];
    commonPath = [
        additionLayer(2,           'Name', 'add')
        tanhLayer('Name', 'relu_1')
        fullyConnectedLayer(256,   'Name', 'fc_2')
        tanhLayer('Name', 'relu_2')
        fullyConnectedLayer(1,     'Name', 'QValue')
    ];
    criticNet = layerGraph(obsPath);
    criticNet = addLayers(criticNet, actPath);
    criticNet = addLayers(criticNet, commonPath);
    criticNet = connectLayers(criticNet, 'obs_tanh',  'add/in1');
    criticNet = connectLayers(criticNet, 'act_tanh',  'add/in2');
end

% 2. Dual-Randomizer for Environment Reset
function in = myResetFunction(in)
    new_noise = randi([1, 100000]);
    new_ref   = randi([1, 100000]);
    
    in = setVariable(in, 'noise_seed', new_noise);
    in = setVariable(in, 'ref_seed',   new_ref);
    
    % Print to command window to prove it is randomizing
    %fprintf('Episode Reset -> Noise Seed: %d | Ref Seed: %d\n', new_noise, new_ref);
end

