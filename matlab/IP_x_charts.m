% =========================================================================
% IP Tracking Charts (Cart Position & Pendulum Angle)
% Mux Structure: [u, theta, theta_dot, x, x_dot]
% =========================================================================
clc; close all;

% Check if the manual run data exists
if ~exist('out', 'var')
    error('Simulation data "out" not found. Please run the Simulink model manually first!');
end

% 1. LIST VARIABLES & LABELS FOR INVERTED PENDULUM
system_vars = {'IP_dual_PID', 'IP_SMC'}; 
labels = {'Dual PID', 'SMC'};

% Extract global time vector
try
    time_vec = out.tout;
catch
    time_vec = evalin('base', 'tout');
end

% Extract the dynamic ip_x_ref signal
try
    if isprop(out, 'ip_x_ref')
        x_ref_raw = out.ip_x_ref;
    else
        x_ref_raw = evalin('base', 'ip_x_ref');
    end
    
    if isa(x_ref_raw, 'timeseries') || isa(x_ref_raw, 'Simulink.SimulationData.Signal')
        x_ref_signal = x_ref_raw.Data(:);
    else
        x_ref_signal = x_ref_raw(:);
    end
catch
    warning('Could not find "ip_x_ref". Reference line will default to 0.');
    x_ref_signal = 0; 
end

disp('Generating IP Tracking Performance graphs...');

% 2. LOOP THROUGH EACH SYSTEM AND PLOT
for i = 1:length(system_vars)
    current_sys = system_vars{i};
    
    if isprop(out, current_sys)
        data_raw = out.(current_sys);
    else
        warning(['Variable ', current_sys, ' not found. Skipping...']);
        continue;
    end
    
    % Handle timeseries vs raw array
    % theta is col 2, x is col 4
    if isa(data_raw, 'timeseries') || isa(data_raw, 'Simulink.SimulationData.Signal')
        theta_data = data_raw.Data(:, 2); 
        x_data     = data_raw.Data(:, 4); 
        sys_time   = data_raw.Time; 
    else
        theta_data = data_raw(:, 2); 
        x_data     = data_raw(:, 4); 
        sys_time   = time_vec;
    end
    
    % Ensure lengths match
    N = length(x_data);
    if length(sys_time) ~= N
        sys_time = linspace(0, max(sys_time), N)';
    end
    
    % Align position reference signal
    if length(x_ref_signal) == N
        current_x_ref = x_ref_signal;
    elseif length(x_ref_signal) == 1
        current_x_ref = zeros(N, 1) + x_ref_signal;
    else
        current_x_ref = x_ref_signal(1:N); 
    end
    
    % 3. CREATE FIGURE WITH SUBPLOTS
    fig = figure('Name', [labels{i}, ' Tracking Performance'], 'Color', 'w', 'Position', [100, 100, 900, 700]);
    
    % --- SUBPLOT 1: CART POSITION (x) ---
    subplot(2, 1, 1);
    hold on; grid on;
    plot(sys_time, current_x_ref, '--', 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.5, 'DisplayName', 'Reference (x_{ref})');
    plot(sys_time, x_data, '-', 'Color', [0 0.4470 0.7410], 'LineWidth', 1.5, 'DisplayName', 'Actual Position (x)');
    
    xlabel('Time (s)', 'FontSize', 11, 'FontWeight', 'bold');
    ylabel('Cart Position, x (m)', 'FontSize', 11, 'FontWeight', 'bold');
    title(['Cart Position Tracking: ', labels{i}], 'FontSize', 13, 'FontWeight', 'bold');
    legend('Location', 'best', 'FontSize', 10, 'Box', 'off');
    xlim([min(sys_time), max(sys_time)]);
    
    max_x = max(max(x_data), max(current_x_ref));
    min_x = min(min(x_data), min(current_x_ref));
    pad_x = (max_x - min_x) * 0.15;
    if pad_x == 0; pad_x = 0.1; end
    ylim([min_x - pad_x, max_x + pad_x]); 
    ax1 = gca; ax1.FontSize = 10; ax1.GridAlpha = 0.3; hold off;

    % --- SUBPLOT 2: PENDULUM ANGLE (theta) ---
    subplot(2, 1, 2);
    hold on; grid on;
    yline(0, '--', 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.5, 'DisplayName', 'Target Angle (0 rad)');
    plot(sys_time, theta_data, '-', 'Color', [0.4660 0.6740 0.1880], 'LineWidth', 1.5, 'DisplayName', 'Pendulum Angle (\theta)');
    
    xlabel('Time (s)', 'FontSize', 11, 'FontWeight', 'bold');
    ylabel('Angle, \theta (rad)', 'FontSize', 11, 'FontWeight', 'bold');
    title(['Pendulum Angle Stabilization: ', labels{i}], 'FontSize', 13, 'FontWeight', 'bold');
    legend('Location', 'best', 'FontSize', 10, 'Box', 'off');
    xlim([min(sys_time), max(sys_time)]);
    
    max_th = max(abs(theta_data));
    if max_th < 0.01; max_th = 0.05; end
    ylim([-max_th*1.2, max_th*1.2]); % Symmetrical padding for angle
    ax2 = gca; ax2.FontSize = 10; ax2.GridAlpha = 0.3; hold off;
end

disp('All IP tracking graphs generated successfully!');