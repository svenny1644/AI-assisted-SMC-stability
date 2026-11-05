% 1. CHECK FOR MANUAL SIMULATION DATA
% We remove 'clear' so we don't lose the 'out' object you just generated
clc; close all;

% Check if 'out' exists in the workspace from your manual Simulink run
if ~exist('out', 'var')
    error('No simulation data found! Please run your Simulink model manually first.');
end

% 2. LIST VARIABLES & LABELS (Focused only on SMC and RL-SMC)
% IMPORTANT: Ensure 'CMSD_RL_SMC' perfectly matches the case of your "To Workspace" block
system_vars = {'cmsd_smc', 'CMSD_RL_SMC'}; 
labels = {'Normal SMC', 'RL-Tuned SMC'};

% Try to extract the global time vector
try
    time_vec = out.tout;
catch
    time_vec = evalin('base', 'tout');
end

disp('Generating graphs from manual simulation data...');

% 3. LOOP THROUGH EACH SYSTEM AND PLOT
for i = 1:length(system_vars)
    current_sys = system_vars{i};
    
    % Extract the data safely from the 'out' object
    if isprop(out, current_sys)
        data_raw = out.(current_sys);
    else
        warning(['Variable ', current_sys, ' not found in out. Skipping...']);
        continue;
    end
    
    % Handle timeseries vs raw array
    if isa(data_raw, 'timeseries') || isa(data_raw, 'Simulink.SimulationData.Signal')
        u_data = data_raw.Data(:, 1);
        time_vec = data_raw.Time; 
    else
        u_data = data_raw(:, 1); 
    end
    
    % Failsafe: Ensure time and data lengths match perfectly
    if length(time_vec) ~= length(u_data)
        time_vec = linspace(0, length(u_data)*0.01, length(u_data))'; 
    end
    
    % 4. CREATE THE FIGURE
    fig = figure('Name', [labels{i}, ' Control Effort'], 'Color', 'w', 'Position', [100, 100, 800, 400]);
    hold on;
    grid on;
    
    % Plot control effort (u)
    plot(time_vec, u_data, '-', 'Color', [0 0.4470 0.7410], 'LineWidth', 1.5);
    
    % Add the target line at u = 0
    yline(0, '--r', 'Desired Control Effort', 'LineWidth', 1.5, ...
        'LabelHorizontalAlignment', 'center', ...
        'LabelVerticalAlignment', 'bottom', ...
        'FontSize', 12, 'FontWeight', 'bold', 'Color', [0.8 0 0]);
    
    % Format the Axes
    xlabel('Time (s)', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Control Effort, u (N)', 'FontSize', 12, 'FontWeight', 'bold');
    title(['Control Effort over Time: ', labels{i}], 'FontSize', 14, 'FontWeight', 'bold');
    
    xlim([min(time_vec), max(time_vec)]);
    
    % Set Y-limits with 20% padding
    y_max = max(abs(u_data));
    if y_max < 0.1, y_max = 1; end
    ylim([-y_max*1.2, y_max*1.2]); 
    
    box on;
    ax = gca;
    ax.FontSize = 11;
    ax.LineWidth = 1;
    
    hold off;
end

disp('All graphs generated successfully!');