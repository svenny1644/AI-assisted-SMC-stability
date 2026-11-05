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

% Extract the dynamic x2_ref signal from manual run
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
    warning('Could not find "x2_ref". Reference line will default to 0.');
    x2_ref_signal = 0; 
end

disp('Generating Superimposed Tracking Performance graph...');

% 3. CREATE FIGURE
fig = figure('Name', 'Superimposed Tracking (PID vs LQR)', 'Color', 'w', 'Position', [100, 100, 900, 500]);
hold on;
grid on;

% Track global min and max for accurate Y-axis padding
global_max = max(x2_ref_signal);
global_min = min(x2_ref_signal);
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
    
    % Handle timeseries vs raw array (targeting x2 at column 3)
    if isa(data_raw, 'timeseries') || isa(data_raw, 'Simulink.SimulationData.Signal')
        x2_data = data_raw.Data(:, 3); 
        sys_time = data_raw.Time; 
    else
        x2_data = data_raw(:, 3); 
        sys_time = time_vec;
    end
    
    % Ensure lengths match
    N = length(x2_data);
    if length(sys_time) ~= N
        sys_time = linspace(0, max(sys_time), N)';
    end
    last_time_vec = sys_time;
    
    % Plot Actual Position
    plot(sys_time, x2_data, '-', 'Color', colors{i}, 'LineWidth', 1.5, 'DisplayName', target_labels{i});
    
    % Update global boundaries
    global_max = max(global_max, max(x2_data));
    global_min = min(global_min, min(x2_data));
end

% 5. PLOT REFERENCE LINE
% Ensure reference aligns with the time vector
N_ref = length(x2_ref_signal);
if N_ref > 1
    ref_time = linspace(0, max(last_time_vec), N_ref)';
else
    ref_time = last_time_vec;
    x2_ref_signal = zeros(length(last_time_vec), 1) + x2_ref_signal;
end

% Plotted last (and in dashed black) so it sits clearly on top of the controllers
plot(ref_time, x2_ref_signal, 'k--', 'LineWidth', 1.5, 'DisplayName', 'Reference (x_2_{ref})');

% 6. FORMATTING
xlabel('Time (s)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Position, x_2 (m)', 'FontSize', 12, 'FontWeight', 'bold');
title('Tracking Performance: Adaptive PID vs PID+LQR vs LQR', 'FontSize', 14, 'FontWeight', 'bold');

% Place legend in the best location so it doesn't cover the data
legend('Location', 'best', 'FontSize', 11, 'Box', 'off');

xlim([0, max(last_time_vec)]);

% Y-axis padding
padding = (global_max - global_min) * 0.15;
if padding == 0; padding = 0.1; end
ylim([global_min - padding, global_max + padding]); 

box on;
ax = gca;
ax.FontSize = 11;
ax.LineWidth = 1;
ax.GridAlpha = 0.3; 

hold off;
disp('Superimposed graph generated successfully!');