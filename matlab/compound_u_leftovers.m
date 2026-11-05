% 1. DATA VALIDATION
clc; close all;
% Check if the manual run data exists
if ~exist('out', 'var')
    error('Simulation data "out" not found. Please run the Simulink model manually first!');
end

% 2. LIST VARIABLES & LABELS FOR SUPERIMPOSED GRAPH
target_vars = {'cmsd_adaptive_pid', 'cmsd_pid_lqr', 'cmsd_lqr'}; 
target_labels = {'Adaptive PID', 'PID + LQR', 'LQR'};

% Distinct colors: Orange, Blue, Green
colors = {[0.8500 0.3250 0.0980], [0 0.4470 0.7410], [0.4660 0.6740 0.1880]}; 

% Extract global time vector
try
    time_vec = out.tout;
catch
    time_vec = evalin('base', 'tout');
end

disp('Generating Superimposed Control Effort graph...');

% 3. CREATE FIGURE
fig = figure('Name', 'Superimposed Control Effort (PID vs LQR)', 'Color', 'w', 'Position', [100, 100, 900, 500]);
hold on;
grid on;

% Track global maximum absolute value for perfect symmetrical Y-axis scaling
global_max_abs = 0;
last_time_vec = time_vec;

% 4. EXTRACT AND PLOT EACH SYSTEM
for i = 1:length(target_vars)
    current_sys = target_vars{i};
    
    if isprop(out, current_sys)
        data_raw = out.(current_sys);
    else
        warning(['Variable ', current_sys, ' not found. Skipping...']);
        continue;
    end
    
    % Handle timeseries vs raw array (targeting u at column 1)
    if isa(data_raw, 'timeseries') || isa(data_raw, 'Simulink.SimulationData.Signal')
        u_data = data_raw.Data(:, 1); 
        sys_time = data_raw.Time; 
    else
        u_data = data_raw(:, 1); 
        sys_time = time_vec;
    end
    
    % Ensure lengths match
    N = length(u_data);
    if length(sys_time) ~= N
        sys_time = linspace(0, max(sys_time), N)';
    end
    last_time_vec = sys_time;
    
    % Plot Control Effort
    plot(sys_time, u_data, '-', 'Color', colors{i}, 'LineWidth', 1.5, 'DisplayName', target_labels{i});
    
    % Update global boundary for Y-axis scaling
    global_max_abs = max(global_max_abs, max(abs(u_data)));
end

% 5. PLOT REFERENCE LINE (y = 0)
% Plotted last so it renders on top. 
% 'HandleVisibility', 'off' prevents it from creating a weird extra entry in the legend.
yline(0, 'k--', 'Desired Control Effort', 'LineWidth', 1.5, ...
    'LabelHorizontalAlignment', 'center', ...
    'LabelVerticalAlignment', 'bottom', ...
    'FontSize', 12, 'FontWeight', 'bold', 'HandleVisibility', 'off');

% 6. FORMATTING
xlabel('Time (s)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Control Effort, u (N)', 'FontSize', 12, 'FontWeight', 'bold');
title('Control Effort: Adaptive PID vs PID+LQR vs LQR', 'FontSize', 14, 'FontWeight', 'bold');

% Place legend
legend('Location', 'best', 'FontSize', 11, 'Box', 'off');

xlim([0, max(last_time_vec)]);

% Y-axis padding (Symmetrical +/- limits based on the highest energy spike)
if global_max_abs == 0; global_max_abs = 1; end
ylim([-global_max_abs * 1.2, global_max_abs * 1.2]); 

box on;
ax = gca;
ax.FontSize = 11;
ax.LineWidth = 1;
ax.GridAlpha = 0.3; 

hold off;
disp('Superimposed control effort graph generated successfully!');