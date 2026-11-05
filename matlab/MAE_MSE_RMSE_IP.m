% =========================================================================
% IP Performance Metrics Analysis (MAE, MSE, RMSE)
% Evaluates Control Effort (u), Pendulum Angle (theta), Cart Position (x)
% Mux Structure: [u, theta, theta_dot, x, x_dot]
% =========================================================================

clc; close all;

% 1. CHECK FOR SIMULATION DATA
if ~exist('out', 'var')
    error('No simulation data found. Please run the Simulink model manually first!');
end

% 2. LIST IP VARIABLES & LABELS
system_vars = {'IP_dual_PID', 'IP_SMC'}; 
row_names = {'Dual PID', 'SMC'};
var_names = {'Control Effort (u)', 'Pendulum Angle (theta)', 'Cart Position (x)'};
metric_names = {'MAE', 'MSE', 'RMSE'};

% Pre-allocate the 3D results matrix: (2 controllers) x (3 metrics) x (3 variables)
results_matrix = zeros(length(system_vars), length(metric_names), length(var_names));

% --- Extract the dynamic ip_x_ref signal ---
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
    warning('ip_x_ref not found. Defaulting x reference target to 0.');
    x_ref_signal = 0; 
end

% 3. LOOP THROUGH DATA AND CALCULATE METRICS
for i = 1:length(system_vars)
    current_sys = system_vars{i};
    
    if isprop(out, current_sys)
        data_raw = out.(current_sys);
        
        % Handle timeseries vs raw array
        if isa(data_raw, 'timeseries') || isa(data_raw, 'Simulink.SimulationData.Signal')
            data = data_raw.Data; 
        else
            data = data_raw; 
        end
        
        % Extract specific columns based on Mux: [u, theta, theta_dot, x, x_dot]
        % We want: u (Col 1), theta (Col 2), x (Col 4)
        actuals = [data(:, 1), data(:, 2), data(:, 4)]; 
        N = size(actuals, 1);
        
        % Align reference signal to the length of the data
        if length(x_ref_signal) == N
            current_x_ref = x_ref_signal;
        elseif length(x_ref_signal) == 1
            current_x_ref = zeros(N, 1) + x_ref_signal;
        else
            current_x_ref = x_ref_signal(1:N); 
        end
        
        % Setup Targets Matrix
        % Col 1 (u) target = 0 | Col 2 (theta) target = 0 | Col 3 (x) target = current_x_ref
        targets = zeros(N, 3);
        targets(:, 3) = current_x_ref; 
        
        % Calculate Errors & Metrics for each variable
        for v = 1:length(var_names)
            error = actuals(:, v) - targets(:, v); 
            
            MAE = mean(abs(error));
            MSE = mean(error.^2);
            RMSE = sqrt(MSE);
            
            results_matrix(i, 1, v) = MAE;
            results_matrix(i, 2, v) = MSE;
            results_matrix(i, 3, v) = RMSE;
        end
    else
        warning(['Variable ', current_sys, ' not found in out. Check your To Workspace blocks!']);
    end
end

% 4. DISPLAY TABLES IN COMMAND WINDOW
clc;
disp('=== INVERTED PENDULUM PERFORMANCE METRICS ===');
for v = 1:length(var_names)
    disp(['--- Metrics for ', var_names{v}, ' ---']);
    ResultsTable = array2table(results_matrix(:, :, v), 'RowNames', row_names, 'VariableNames', metric_names);
    disp(ResultsTable);
    fprintf('\n');
end

% 5. EXPORT TO EXCEL
filename = 'IP_Performance_Results.xlsx';

% Delete the file if it already exists to ensure a fresh start
if exist(filename, 'file')==2, delete(filename); end

for v = 1:length(var_names)
    current_var_data = results_matrix(:, :, v);
    T = array2table(current_var_data, ...
        'RowNames', row_names, ...
        'VariableNames', metric_names);
    
    % Clean the variable name to be used as a Sheet Name (no special characters)
    clean_sheet_name = regexprep(var_names{v}, '[^a-zA-Z0-9]', '_');
    
    % Write to Excel
    writetable(T, filename, 'Sheet', clean_sheet_name, 'WriteRowNames', true);
end

fprintf('Success! Metrics exported to: %s\n', fullfile(pwd, filename));