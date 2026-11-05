% =========================================================================
% Controller Comparison: PID vs LQR vs Hybrid vs Adaptive P
% =========================================================================
clear; clc; close all; 

% 1. RUN THE SIMULATION
model_name = 'LQRconlacnguoc'; 
disp(['Running simulation: ', model_name, '...']);
out = sim(model_name);

% 2. EXTRACT DATA DYNAMICALLY
var_names = {'ip_pid_lqr_dist', 'ip_pid_only', 'ip_lqr_only', 'ip_adaptive_P_only'};
data = struct(); 

for i = 1:length(var_names)
    var = var_names{i};
    if isprop(out, var)
        data.(var) = out.(var);
    else
        data.(var) = evalin('base', var);
    end
end

% 3. CREATE THE TIME VECTOR
dt = 0.1;
num_samples = length(data.ip_pid_only(:,1));
t = (0:num_samples-1)' * dt;

% Define Dark Green Color 
dark_green = [0, 0.5, 0];

% =========================================================================
% FIGURE 1: Control Effort (u) Comparison
% =========================================================================
figure('Name', 'Control Effort Comparison', 'Color', 'w');
plot(t, data.ip_pid_lqr_dist(:, 1), 'b-', 'LineWidth', 1.5); hold on;
plot(t, data.ip_pid_only(:, 1), 'r-', 'LineWidth', 1.5);
plot(t, data.ip_lqr_only(:, 1), '-', 'Color', dark_green, 'LineWidth', 1.5);
plot(t, data.ip_adaptive_P_only(:, 1), 'm-', 'LineWidth', 1.5); 

% --- FONT SIZE UPDATES HERE ---
title('Control Effort (u) vs Time', 'FontSize', 14);
xlabel('Time (s)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Force (N)', 'FontSize', 12, 'FontWeight', 'bold');
legend('Hybrid LQR+PD (w/ Disturbance)', 'PD Only', 'LQR Only', 'Adaptive PD Only', 'FontSize', 11);
set(gca, 'FontSize', 11); % Increases the size of the axis tick numbers
grid on;

% =========================================================================
% FIGURE 2: State Response Comparison (Mass 1 & Mass 2 Positions)
% =========================================================================
figure('Name', 'Position Response Comparison', 'Color', 'w');

% --- Top Plot: Mass 1 Position (x1) ---
subplot(2,1,1); 
plot(t, data.ip_pid_lqr_dist(:, 2), 'b-', 'LineWidth', 1.5); hold on;
plot(t, data.ip_pid_only(:, 2), 'r-', 'LineWidth', 1.5);
plot(t, data.ip_lqr_only(:, 2), '-', 'Color', dark_green, 'LineWidth', 1.5);
plot(t, data.ip_adaptive_P_only(:, 2), 'm-', 'LineWidth', 1.5); 
yline(0, 'k-', 'Target Position', 'LineWidth', 1.2); 

% --- FONT SIZE UPDATES HERE ---
title('Mass 1 Position (x_1) vs Time', 'FontSize', 24);
xlabel('Time (s)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Position (m)', 'FontSize', 12, 'FontWeight', 'bold');
legend('Hybrid LQR+PD', 'PD Only', 'LQR Only', 'Adaptive PD Only', 'Location', 'best', 'FontSize', 11);
set(gca, 'FontSize', 11); % Increases the size of the axis tick numbers
grid on;

% --- Bottom Plot: Mass 2 Position (x2) ---
subplot(2,1,2); 
plot(t, data.ip_pid_lqr_dist(:, 3), 'b-', 'LineWidth', 1.5); hold on;
plot(t, data.ip_pid_only(:, 3), 'r-', 'LineWidth', 1.5);
plot(t, data.ip_lqr_only(:, 3), '-', 'Color', dark_green, 'LineWidth', 1.5);
plot(t, data.ip_adaptive_P_only(:, 3), 'm-', 'LineWidth', 1.5); 
yline(0, 'k-', 'Target Position', 'LineWidth', 1.2); 

% --- FONT SIZE UPDATES HERE ---
title('Mass 2 Position (x_2) vs Time', 'FontSize', 24);
xlabel('Time (s)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Position (m)', 'FontSize', 12, 'FontWeight', 'bold');
legend('Hybrid LQR+PD', 'PD Only', 'LQR Only', 'Adaptive PD Only', 'Location', 'best', 'FontSize', 11);
set(gca, 'FontSize', 11); % Increases the size of the axis tick numbers
grid on;