clear; clc; close all;

% 1. RUN THE SIMULATION
model_name = 'LQRconlacnguoc'; 
disp('Running simulation...');
out = sim(model_name);

% 2. LIST VARIABLES & LABELS (Excluding LQR)
system_vars = {'cmsd_pid', 'cmsd_adaptive_pid', 'cmsd_pid_lqr', 'cmsd_smc', 'cmsd_adaptive_smc'}; 
labels = {'PID', 'Adaptive PID', 'PID + LQR', 'SMC', 'Adaptive SMC'};

% Extract dynamic x2_ref signal
try
    if isprop(out, 'x2_ref')
        x2_ref_raw = out.x2_ref;
    else
        x2_ref_raw = evalin('base', 'x2_ref');
    end
    
    if isa(x2_ref_raw, 'timeseries') || isa(x2_ref_raw, 'Simulink.SimulationData.Signal')
        x2_ref_signal = x2_ref_raw.Data(:);
    else
        x2_ref_signal = x2_ref_raw(:);
    end
catch
    warning('Could not find "x2_ref". Defaulting to 0.');
    x2_ref_signal = 0; 
end

% Preallocate metric arrays
num_systems = length(system_vars);
effort_mae = zeros(num_systems, 1);
tracking_mae = zeros(num_systems, 1);

disp('Calculating coordinates...');

% 3. CALCULATE METRICS FOR THE PLOT
for i = 1:num_systems
    current_sys = system_vars{i};
    
    if isprop(out, current_sys)
        data = out.(current_sys);
    else
        data = evalin('base', current_sys);
    end
    
    u = data(:, 1);
    x2 = data(:, 3);
    
    N = length(x2);
    
    % Align reference signal
    if length(x2_ref_signal) == N
        current_x2_ref = x2_ref_signal;
    elseif length(x2_ref_signal) == 1
        current_x2_ref = zeros(N, 1) + x2_ref_signal;
    else
        current_x2_ref = x2_ref_signal(1:N); 
    end
    
    % Calculate MAE for X and Y axes
    effort_mae(i) = mean(abs(u - 0)); % Target for effort is always 0
    tracking_mae(i) = mean(abs(x2 - current_x2_ref));
end

% 4. GENERATE THE SCATTER PLOT
disp('Generating plot...');
figure('Name', 'Performance Trade-off', 'Color', 'w');
hold on;
grid on;

% Plot the points
scatter(effort_mae, tracking_mae, 100, 'b', 'filled', 'MarkerEdgeColor', 'k');

% Calculate the total range of the data to scale our "nudges" appropriately
range_x = max(effort_mae) - min(effort_mae);
range_y = max(tracking_mae) - min(tracking_mae);

% --- CUSTOM LABEL POSITIONING ---
% Order: {'PID', 'Adaptive PID', 'PID + LQR', 'SMC', 'Adaptive SMC'}
% We assign specific alignments and percentage nudges to untangle the cluster.
align_H = {'left',  'right',  'right',  'right',  'left'};  
align_V = {'top',   'bottom', 'bottom', 'bottom', 'bottom'};   
x_nudge = [ 0.02,  -0.02,    -0.02,    -0.03,     0.02]; % Positive is right, Negative is left
y_nudge = [-0.02,   0.02,     0.02,    -0.02,     0.02]; % Positive is up, Negative is down

% Add the text labels to each point using the custom arrays
for i = 1:num_systems
    text(effort_mae(i) + (range_x * x_nudge(i)), ...
         tracking_mae(i) + (range_y * y_nudge(i)), ...
         labels{i}, ...
        'FontSize', 11, ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', align_H{i}, ...
        'VerticalAlignment', align_V{i});
end

% Format the Axes
xlabel('Control Effort MAE (Newtons) \rightarrow', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Tracking Error MAE (meters) \rightarrow', 'FontSize', 12, 'FontWeight', 'bold');
title('Control Methodology Trade-off: Precision vs. Effort', 'FontSize', 14);

% Add a note about the origin being the target
annotation('textbox', [0.15, 0.15, 0.2, 0.05], 'String', 'Ideal (0,0)', ...
    'FitBoxToText', 'on', 'EdgeColor', 'none', 'FontWeight', 'bold', 'Color', [0 0.5 0]);

% Tweak axes limits to ensure labels aren't cut off at the edges
xlim([min(effort_mae)*0.9, max(effort_mae)*1.05]);
ylim([0, max(tracking_mae)*1.2]); % Increased slightly to give top labels breathing room

hold off;