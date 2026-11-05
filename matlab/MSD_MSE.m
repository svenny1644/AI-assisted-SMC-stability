clear; clc;

% 1. RUN THE SIMULATION
model_name = 'LQRconlacnguoc'; 
disp('Running simulation...');
out = sim(model_name);

% 2. LIST YOUR VARIABLES
% ADDED: 'ip_adaptive_P_only' to the end of the list
variable_names = {'ip_pid_lqr_dist', 'ip_pid_only', 'ip_lqr_only', 'ip_adaptive_P_only'}; 

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
    
    % Extract columns based on your array structure [u, x1, x2, v1, v2]
    u  = data(:, 1);  
    x1 = data(:, 2);  
    x2 = data(:, 3);  
    v1 = data(:, 4);  
    v2 = data(:, 5);  
    
    % Define Targets (Regulator / Suspension Mode)
    ref_u  = 0; 
    ref_x1 = 0; 
    ref_x2 = 0; 
    ref_v1 = 0;  
    ref_v2 = 0;
    
    % Calculate Errors
    errors = [u - ref_u, x1 - ref_x1, x2 - ref_x2, v1 - ref_v1, v2 - ref_v2];
    actuals = [u, x1, x2, v1, v2];
    
    % Calculate Metrics
    MAE = mean(abs(errors));
    MSE = mean(errors.^2);
    RMSE = sqrt(MSE);
    
    % eps prevents division by zero for regulator targets
    MAPE = mean(abs(errors ./ (actuals + eps))) * 100; 
    
    % Display Table
    VarNames = {'Control_u'; 'Pos_x1'; 'Pos_x2'; 'Vel_v1'; 'Vel_v2'};
    ResultsTable = table(MAE', MSE', RMSE', MAPE', ...
        'VariableNames', {'MAE', 'MSE', 'RMSE', 'MAPE'}, 'RowNames', VarNames);
    
    disp(ResultsTable);
    fprintf('\n'); % Add a blank line between tables
end