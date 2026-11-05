% =========================================================================
% Controller Comparison: PID vs LQR vs Hybrid
% =========================================================================
clear; clc; close all; % close all previous figure windows

% 1. RUN THE SIMULATION
model_name = 'LQRconlacnguoc'; 
disp(['Running simulation: ', model_name, '...']);
out = sim(model_name);

% 2. EXTRACT DATA DYNAMICALLY
var_names = {'ip_pid_lqr_dist', 'ip_pid_only', 'ip_lqr_only'};
data = struct(); % Create a structure to hold our three arrays cleanly

for i = 1:length(var_names)
    var = var_names{i};
    if isprop(out, var)
        data.(var) = out.(var);
    else
        data.(var) = evalin('base', var);
    end
end

% 3. CREATE THE TIME VECTOR
% Instead of hardcoding 0 to 60, we count the rows and multiply by your 0.1s delta.
% This prevents crashes if you ever change your simulation stop time!
dt = 0.1;
num_samples = length(data.ip_pid_only(:,1));
t = (0:num_samples-1)' * dt;

% =========================================================================
% FIGURE 1: Control Effort (u) Comparison
% =========================================================================
figure('Name', 'Control Effort Comparison', 'Color', 'w');
plot(t, data.ip_pid_lqr_dist(:, 1), 'b-', 'LineWidth', 1.5); hold on;
plot(t, data.ip_pid_only(:, 1), 'r-', 'LineWidth', 1.5);
plot(t, data.ip_lqr_only(:, 1), 'm-', 'LineWidth', 1.5);

title('Control Effort (u) vs Time');
xlabel('Time (s)');
ylabel('Force (N)');
legend('Hybrid LQR+PID (w/ Disturbance)', 'PID Only', 'LQR Only');
grid on;

% =========================================================================
% FIGURE 2: State Response Comparison (Angle & Position)
% =========================================================================
figure('Name', 'State Response Comparison', 'Color', 'w');

% --- Top Plot: Angle (theta) ---
subplot(2,1,1); % 2 rows, 1 column, 1st plot
plot(t, data.ip_pid_lqr_dist(:, 2), 'b-', 'LineWidth', 1.5); hold on;
plot(t, data.ip_pid_only(:, 2), 'r-', 'LineWidth', 1.5);
plot(t, data.ip_lqr_only(:, 2), 'm-', 'LineWidth', 1.5);
yline(0, 'k-', 'Upright Reference'); % Adds a solid black line at 0

title('Pendulum Angle (\theta) vs Time');
xlabel('Time (s)');
ylabel('Angle (rad)');
legend('Hybrid LQR+PID', 'PID Only', 'LQR Only', 'Location', 'best');
grid on;

% --- Bottom Plot: Cart Position (x) ---
subplot(2,1,2); % 2 rows, 1 column, 2nd plot
plot(t, data.ip_pid_lqr_dist(:, 4), 'b-', 'LineWidth', 1.5); hold on;
plot(t, data.ip_pid_only(:, 4), 'r-', 'LineWidth', 1.5);
plot(t, data.ip_lqr_only(:, 4), 'm-', 'LineWidth', 1.5);
yline(0.1, 'k-', 'Target Position'); % Assuming your target is 0.1m

title('Cart Position (x) vs Time');
xlabel('Time (s)');
ylabel('Position (m)');
legend('Hybrid LQR+PID', 'PID Only', 'LQR Only', 'Location', 'best');
grid on;