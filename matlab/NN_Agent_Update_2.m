clc; close all;

% =========================================================================
% NN_Agent.m  —  CMSD Neural Network Controller Training Script
% RTX 3080 Ti  |  TD3  |  Hybrid Upgrade
% =========================================================================

% === 1. DEFINE THE GYM (SIMULINK ENVIRONMENT) ===
Ts  = 0.01;          
mdl = 'CMSD_Training_Env';
open_system(mdl);

agentBlock = [mdl, '/RL Agent'];

% Observation: [x1, x2, v1, v2, x2_ref, x2_error, u_prev]  (7×1)
obsInfo = rlNumericSpec([7 1], 'Name', 'Observations');
obsInfo.LowerLimit = [-2; -2; -5; -5; -2; -4; -1];
obsInfo.UpperLimit = [ 2;  2;  5;  5;  2;  4;  1];

% Action: normalised force in [-1, +1], scaled by 3500 N inside Simulink
actInfo = rlNumericSpec([1 1], 'LowerLimit', -1, 'UpperLimit', 1, 'Name', 'Action_u');

env = rlSimulinkEnv(mdl, agentBlock, obsInfo, actInfo);
env.ResetFcn = @myResetFunction;

% =========================================================================
% === 2. BUILD THE ACTOR NETWORK (THE DRIVER) ===
% Upgraded to 256 neurons and tanh layers for smooth, continuous torque.
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
% Using the helper function at the bottom of the script to build TWO 
% completely independent Critics (Fixes the Twin-Critic variance bug).
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
agentOptions.SampleTime               = Ts;
agentOptions.DiscountFactor           = 0.99;
agentOptions.MiniBatchSize            = 256;    % Highly optimizes the GPU pipeline
agentOptions.ExperienceBufferLength   = 1e6;
% NumWarmStartSteps is unreliable across RL Toolbox versions and caused
% training to stop at episode 4-11. Buffer warmup is handled instead by
% keeping Variance=1.0 for the first ~500 episodes (pure exploration),
% which naturally fills the buffer with diverse data before the policy
% meaningfully converges. See ExplorationModel settings below.
agentOptions.ActorOptimizerOptions    = actorOpts;
agentOptions.CriticOptimizerOptions   = criticOpts;

% High exploration variance to prevent early suicide loops, decays very slowly
agentOptions.ExplorationModel.Variance          = 1.0;
agentOptions.ExplorationModel.VarianceDecayRate = 1e-6;  % 5x slower — keeps exploration alive past ep 500
agentOptions.ExplorationModel.VarianceMin       = 0.15;  % raised floor — never go fully deterministic early

agentObj = rlTD3Agent(actor, [critic1 critic2], agentOptions);

agentDir = fullfile(pwd, 'Agents');
if ~exist(agentDir, 'dir')
    mkdir(agentDir);
end

% =========================================================================
% === 5. TRAINING OPTIONS ===
% Restored your custom save logic and 6000-step endurance tracking!
% Parallel is turned OFF because the 256 MiniBatchSize feeds the GPU directly.
% =========================================================================
trainOpts = rlTrainingOptions(...
    'MaxEpisodes',              10000, ...
    'MaxStepsPerEpisode',       6000,  ...   
    'ScoreAveragingWindowLength', 50,  ...   % wider window — stable signal, not fooled by one good episode
    'Verbose',                  false, ...
    'Plots',                    'training-progress', ... % Keeps the Episode Monitor GUI alive
    'UseParallel',              false, ...
    'StopTrainingCriteria',     'none', ...              % never auto-stop — let all 10000 episodes run
    'SaveAgentCriteria',        'AverageReward', ...     % only save genuinely good agents
    'SaveAgentValue',           -800, ...                % Phase 1 threshold — raise to 0 once agent survives 500+ steps
    'SaveAgentDirectory',       agentDir);

% =========================================================================
% === 6. START TRAINING ===
% =========================================================================
disp('Starting training — GPU active. Watch the Episode Manager window.');
trainingStats = train(agentObj, env, trainOpts);

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

figure('Name', 'AI Survival Performance', 'Color', 'w');
plot(trainingStats.EpisodeIndex, trainingStats.EpisodeSteps, 'b-', 'LineWidth', 1.2);
xlabel('Episode'); ylabel('Steps survived');
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
    in = setVariable(in, 'noise_seed', randi([1, 100000]));
    in = setVariable(in, 'ref_seed',   randi([1, 100000]));
end