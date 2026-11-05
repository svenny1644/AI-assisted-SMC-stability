clear; clc;

% 1. RUN THE SIMULATION
model_name = 'LQRconlacnguoc'; 
disp('Running simulation...');
out = sim(model_name);

% 2. LIST YOUR VARIABLES
% Put the exact names of your "To Workspace" blocks here
variable_names = {'ip_pid_lqr_dist', 'ip_pid_only', 'ip_lqr_only'}; 

% 3. LOOP THROUGH EACH SYSTEM
for i = 1:length(variable_names)
    current_var = variable_names{i};
    disp(['=== Results for: ', current_var, ' ===']);
    
    % Extract the data dynamically
    if isprop(out, current_var)
        data = out.(current_var);
    else
        data = evalin('base', current_var);
    end
    
    % Extract columns
    u         = data(:, 1);  
    theta     = data(:, 2);  
    theta_dot = data(:, 3);  
    x         = data(:, 4);  
    x_dot     = data(:, 5);  
    
    % Define Targets
    ref_u = 0; ref_theta = 0; ref_theta_dot = 0; ref_x = 0.1; ref_x_dot = 0;
    
    % Calculate Errors
    errors = [u - ref_u, theta - ref_theta, theta_dot - ref_theta_dot, x - ref_x, x_dot - ref_x_dot];
    actuals = [u, theta, theta_dot, x, x_dot];
    
    % Calculate Metrics
    MAE = mean(abs(errors));
    MSE = mean(errors.^2);
    RMSE = sqrt(MSE);
    MAPE = mean(abs(errors ./ (actuals + eps))) * 100;
    
    % Display Table
    VarNames = {'Control_u'; 'Angle_theta'; 'AngVel_theta_dot'; 'Pos_x'; 'Vel_x_dot'};
    ResultsTable = table(MAE', MSE', RMSE', MAPE', ...
        'VariableNames', {'MAE', 'MSE', 'RMSE', 'MAPE'}, 'RowNames', VarNames);
    
    disp(ResultsTable);
    fprintf('\n'); % Add a blank line between tables
end