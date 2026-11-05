% =========================================================================
% IP Control Effort Charts (u)
% Mux Structure: [u, theta, theta_dot, x, x_dot]
% =========================================================================
clc; close all;

if ~exist('out', 'var')
    error('No simulation data found! Please run your Simulink model manually first.');
end

% 1. LIST VARIABLES & LABELS FOR INVERTED PENDULUM
system_vars = {'IP_dual_PID', 'IP_SMC'}; 
labels = {'Dual PID', 'SMC'};

try
    time_vec = out.tout;
catch
    time_vec = evalin('base', 'tout');
end

disp('Generating IP Control Effort graphs...');

% 2. LOOP THROUGH EACH SYSTEM AND PLOT
for i = 1:length(system_vars)
    current_sys = system_vars{i};
    
    if isprop(out, current_sys)
        data_raw = out.(current_sys);
    else
        warning(['Variable ', current_sys, ' not found in out. Skipping...']);
        continue;
    end
    
    % Handle timeseries vs raw array (u is Col 1)
    if isa(data_raw, 'timeseries') || isa(data_raw, 'Simulink.SimulationData.Signal')
        u_data = data_raw.Data(:, 1);
        sys_time = data_raw.Time; 
    else
        u_data = data_raw(:, 1); 
        sys_time = time_vec;
    end
    
    if length(sys_time) ~= length(u_data)
        sys_time = linspace(0, max(sys_time), length(u_data))'; 
    end
    
    % 3. CREATE THE FIGURE
    fig = figure('Name', [labels{i}, ' Control Effort'], 'Color', 'w', 'Position', [150, 150, 800, 400]);
    hold on;
    grid on;
    
    % Plot control effort (u)
    plot(sys_time, u_data, '-', 'Color', [0 0.4470 0.7410], 'LineWidth', 1.5);
    
    % Add the target line at u = 0
    yline(0, '--r', 'Zero Effort', 'LineWidth', 1.5, ...
        'LabelHorizontalAlignment', 'center', ...
        'LabelVerticalAlignment', 'bottom', ...
        'FontSize', 11, 'FontWeight', 'bold', 'Color', [0.8 0 0]);
    
    % Format the Axes
    xlabel('Time (s)', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Motor Force, u (N)', 'FontSize', 12, 'FontWeight', 'bold');
    title(['Control Effort over Time: ', labels{i}], 'FontSize', 14, 'FontWeight', 'bold');
    
    xlim([min(sys_time), max(sys_time)]);
    
    % Set Y-limits symmetrically based on max effort
    y_max = max(abs(u_data));
    if y_max < 0.1; y_max = 1; end
    ylim([-y_max*1.2, y_max*1.2]); 
    
    box on;
    ax = gca;
    ax.FontSize = 11;
    ax.LineWidth = 1;
    ax.GridAlpha = 0.3;
    
    hold off;
end

disp('All IP control effort graphs generated successfully!');