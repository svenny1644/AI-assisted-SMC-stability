% 1. DATA VALIDATION
% Removed 'clear' to protect your manual simulation results
clc; close all;

% Check if the manual run data exists
if ~exist('out', 'var')
    error('Simulation data "out" not found. Please run the Simulink model manually first!');
end

% 2. LIST VARIABLES & LABELS
% Updated to include 'cmsd_mpc' as requested
system_vars = {'cmsd_pid', 'cmsd_adaptive_pid', 'cmsd_lqr', 'cmsd_pid_lqr', 'cmsd_smc', 'cmsd_adaptive_smc', 'cmsd_mpc'}; 
labels = {'PID', 'Adaptive PID', 'LQR', 'PID + LQR', 'SMC', 'Adaptive SMC', 'MPC'};

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

disp('Generating Tracking Performance graphs from manual data...');

% 3. LOOP THROUGH EACH SYSTEM AND PLOT
for i = 1:length(system_vars)
    current_sys = system_vars{i};
    
    % Safely extract data from the 'out' object
    if isprop(out, current_sys)
        data_raw = out.(current_sys);
    else
        warning(['Variable ', current_sys, ' not found. Skipping...']);
        continue;
    end
    
    % Handle timeseries vs raw array (targeting x2 at column 3)
    if isa(data_raw, 'timeseries') || isa(data_raw, 'Simulink.SimulationData.Signal')
        x2_data = data_raw.Data(:, 3); 
        time_vec = data_raw.Time; 
    else
        x2_data = data_raw(:, 3); 
    end
    
    % Ensure lengths match
    N = length(x2_data);
    if length(time_vec) ~= N
        time_vec = linspace(0, max(time_vec), N)';
    end
    
    % Align reference signal
    if length(x2_ref_signal) == N
        current_x2_ref = x2_ref_signal;
    elseif length(x2_ref_signal) == 1
        current_x2_ref = zeros(N, 1) + x2_ref_signal;
    else
        current_x2_ref = x2_ref_signal(1:N); 
    end
    
    % 4. CREATE FIGURE
    fig = figure('Name', [labels{i}, ' Tracking'], 'Color', 'w', 'Position', [100, 100, 800, 400]);
    hold on;
    grid on;
    
    % Reference line (Dashed Gold)
    plot(time_vec, current_x2_ref, '--', 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.5, 'DisplayName', 'Reference (x_2_{ref})');
    
    % Actual Position (Solid Blue)
    plot(time_vec, x2_data, '-', 'Color', [0 0.4470 0.7410], 'LineWidth', 1.5, 'DisplayName', 'Actual Position (x_2)');
    
    % Formatting
    xlabel('Time (s)', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Position, x_2 (m)', 'FontSize', 12, 'FontWeight', 'bold');
    title(['Tracking Performance: ', labels{i}], 'FontSize', 14, 'FontWeight', 'bold');
    legend('Location', 'northeast', 'FontSize', 11, 'Box', 'off');
    
    xlim([min(time_vec), max(time_vec)]);
    
    % Y-axis padding
    max_val = max(max(x2_data), max(current_x2_ref));
    min_val = min(min(x2_data), min(current_x2_ref));
    padding = (max_val - min_val) * 0.15;
    if padding == 0; padding = 0.1; end
    ylim([min_val - padding, max_val + padding]); 
    
    box on;
    ax = gca;
    ax.FontSize = 11;
    ax.LineWidth = 1;
    ax.GridAlpha = 0.3; 
    
    hold off;
end

disp('All tracking graphs generated successfully!');