% =========================================================================
% The Monte Carlo Agent Arena: 100-Run Parallel Evaluation
% =========================================================================
clc; 
disp('Initializing the Monte Carlo Eval ...');

% --- 1. Generate 100 Deterministic Shared Seeds
numRuns = 100;
rng(44); % Lock the RNG so this exact 100-track gauntlet can be repeated exactly
shared_ref_seeds   = randi([1, 100000], numRuns, 1);
shared_noise_seeds = randi([1, 100000], numRuns, 1);

% --- 2. Load the Two FULL Agents ---
% Point to the backup folder where the fully intact 63MB agents live
agentDir = fullfile(pwd, 'Renamed_Agents'); 

disp('Loading Full Agent 3971...');
% IMPORTANT: Ensure this filename perfectly matches the one on your drive!
data3971 = load(fullfile(agentDir, 'Tested_Reward629_Agent3971.mat')); 
varNames = fieldnames(data3971);
agent3971 = data3971.(varNames{1});

disp('Loading Full Agent 5000...');
% IMPORTANT: Ensure this filename perfectly matches the one on your drive!
data5000 = load(fullfile(agentDir, 'Tested_Reward614_Agent5000.mat'));
varNames = fieldnames(data5000);
agent5000 = data5000.(varNames{1});

% --- 3. Preallocate Score Arrays
scores_3971 = zeros(numRuns, 1);
scores_5000 = zeros(numRuns, 1);

mdl = 'RL_SMC_Training_Env';

% Setup parallel pool if available (Uses all CPU cores)
pool = gcp('nocreate');
if isempty(pool)
    disp('Spinning up parallel CPU workers...');
    parpool; 
end

disp(['Starting ', num2str(numRuns), '-episode parallel gauntlet.']);
disp('Grab a coffee, your CPU is going to 100%...');
fprintf('----------------------------------------------------\n');

% --- 4. The Parallel Gauntlet 
% We use parfor to distribute the 100 runs across CPU cores.
parfor i = 1:numRuns
    
    % --- WORKER SETUP ---
    load_system(mdl); % Load Simulink model on this specific worker
    
    % Inject the shared seeds into this worker's base workspace
    assignin('base', 'ref_seed', shared_ref_seeds(i));
    assignin('base', 'noise_seed', shared_noise_seeds(i));
    
    % Rebuild exact 13x1 limits for the worker
    obsInfo = rlNumericSpec([13 1], 'Name', 'Observations');
    obsInfo.LowerLimit = [-0.8; -0.8; -2.5; -2.5; -0.6; -1.5;   0; -30; -1; -1; -1; -1; -0.4];
    obsInfo.UpperLimit = [ 0.8;  0.8;  2.5;  2.5;  0.6;  1.5; 3.5;  30;  1;  1;  1;  1;  0.4];
    actInfo = rlNumericSpec([4 1], 'LowerLimit', -1, 'UpperLimit', 1, 'Name', 'SMC_Params');
    
    % Create env on this worker
    agentBlock = [mdl, '/RL Agent'];
    env = rlSimulinkEnv(mdl, agentBlock, obsInfo, actInfo);
    
    % Strict 1-episode test configuration (we handle the loop, not the RL toolbox)
    simOpts = rlSimulationOptions('MaxSteps', 3000, 'NumSimulations', 1);
    
    % ----- Evaluate Agent 3971 -----
    exp3971 = sim(env, agent3971, simOpts);
    scores_3971(i) = sum(exp3971.Reward);
    
    % ----- Evaluate Agent 5000 -----
    exp5000 = sim(env, agent5000, simOpts);
    scores_5000(i) = sum(exp5000.Reward);
    
end

% --- 5. Calculate and Display Results ---
fprintf('----------------------------------------------------\n');
disp('Monte Carlo Evaluation Complete!');
fprintf('Agent 3971 Average Score: %.2f\n', mean(scores_3971));
fprintf('Agent 5000 Average Score: %.2f\n', mean(scores_5000));

% Determine the ultimate winner
fprintf('----------------------------------------------------\n');
if mean(scores_3971) > mean(scores_5000)
    fprintf('WINNER: Agent 3971 (By %.2f points)\n', mean(scores_3971) - mean(scores_5000));
elseif mean(scores_5000) > mean(scores_3971)
    fprintf('WINNER: Agent 5000 (By %.2f points)\n', mean(scores_5000) - mean(scores_3971));
else
    disp('MATHEMATICAL TIE!');
end
fprintf('----------------------------------------------------\n');