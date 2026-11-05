% =========================================================================
% Inverted Pendulum - LQR + PID Performance Evaluator
% =========================================================================
clear; clc;

% 1. RUN THE SIMULATION
% Replace 'LQRconlacnguoc' with the actual name of your .slx file (without the .slx)
model_name = 'LQRconlacnguoc'; 
disp(['Running simulation: ', model_name, '...']);
out = sim(model_name); % This runs the Simulink model automatically

% 2. EXTRACT THE DATA
% Check if data is inside the 'out' object (modern MATLAB) or base workspace
if isprop(out, 'ip_pid_lqr_dist')
    data = out.ip_pid_lqr_dist;
else
    data = evalin('base', 'ip_pid_lqr_dist');
end

% Extract columns based on your specified order
u         = data(:, 1);  % Control Force
theta     = data(:, 2);  % Pendulum Angle
theta_dot = data(:, 3);  % Angular Velocity
x         = data(:, 4);  % Cart Position
x_dot     = data(:, 5);  % Cart Velocity

% 3. DEFINE REFERENCE TARGETS (To calculate Error)
% NOTE: If you are using the Pulse Generator for X, you will need to export 
% the reference signal to the workspace too. Assuming a constant 0.1m target here.
ref_u         = 0;   % Ideal effort is 0
ref_theta     = 0;   % Upright is 0
ref_theta_dot = 0;   % Standing still
ref_x         = 0.1; % Target position
ref_x_dot     = 0;   % Stopped at target

% Calculate Errors (Error = Actual - Target)
err_u         = u         - ref_u;
err_theta     = theta     - ref_theta;
err_theta_dot = theta_dot - ref_theta_dot;
err_x         = x         - ref_x;
err_x_dot     = x_dot     - ref_x_dot;

% Combine errors into a matrix for easy calculation
% Columns: [u, theta, theta_dot, x, x_dot]
errors = [err_u, err_theta, err_theta_dot, err_x, err_x_dot];
actuals = [u, theta, theta_dot, x, x_dot];

% 4. CALCULATE METRICS
% MAE: Mean Absolute Error
MAE = mean(abs(errors));

% MSE: Mean Squared Error
MSE = mean(errors.^2);

% RMSE: Root Mean Squared Error
RMSE = sqrt(MSE);

% MAPE: Mean Absolute Percentage Error
% WARNING: MAPE divides by the actual target. Since your targets for angle 
% and velocity are exactly 0, this will divide by zero and output 'Inf'.
% To prevent this, we add a tiny number (eps) to the denominator.
MAPE = mean(abs(errors ./ (actuals + eps))) * 100;

% 5. DISPLAY RESULTS AS A TABLE
Variable_Names = {'Control_u'; 'Angle_theta'; 'AngVel_theta_dot'; 'Pos_x'; 'Vel_x_dot'};
ResultsTable = table(MAE', MSE', RMSE', MAPE', ...
    'VariableNames', {'MAE', 'MSE', 'RMSE', 'MAPE_Percent'}, ...
    'RowNames', Variable_Names);

disp('--- Simulation Complete. Performance Metrics: ---');
disp(ResultsTable);