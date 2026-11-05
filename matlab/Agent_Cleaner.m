% 1. Load the massive 63MB agent
load('Renamed_Agents\Tested_Reward629_Agent3971.mat', 'saved_agent');

% 2. Surgically extract ONLY the Actor network (the deterministic brain)
lean_actor = getActor(saved_agent);

% 3. Save only the lean actor to a new file
save('Agents\Lean_Agent3971.mat', 'lean_actor');

disp('Agent stripped and compressed!');