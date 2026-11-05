% MAE_MSE_AnalysisOnly.m
% clear; % DO NOT CLEAR! We need the data from the manual run.
clc;

% 1. (SKIP RUNNING SIMULATION)
% model_name = 'LQRconlacnguoc'; 
% out = sim(model_name); % Commented out to prevent the mpc1 error

% Check if 'out' exists in the workspace
if ~exist('out', 'var')
    error('No simulation data found. Please run the Simulink model manually first!');
end

% 2. LIST YOUR VARIABLES & TABLE LABELS
% Ensure 'cmsd_mpc' is in this list
system_vars = {'cmsd_pid', 'cmsd_adaptive_pid', 'cmsd_lqr', 'cmsd_pid_lqr', 'cmsd_smc', 'cmsd_adaptive_smc', 'cmsd_mpc'}; 
row_names = {'PID', 'Adaptive PID', 'LQR', 'PID + LQR', 'SMC', 'Adaptive SMC', 'MPC'};

var_names = {'Control Effort (u)', 'Position 1 (x1)', 'Position 2 (x2)', 'Velocity 1 (v1)', 'Velocity 2 (v2)'};
metric_names = {'MAE', 'MSE', 'RMSE', 'MAPE'};

results_matrix = zeros(length(system_vars), length(metric_names), length(var_names));

% --- Extract the x2_ref signal from the manual run ---
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
    x2_ref_signal = 0; 
end

% 3. LOOP THROUGH DATA
for i = 1:length(system_vars)
    current_sys = system_vars{i};
    
    % Extract the data from the 'out' object created by your manual run
    if isprop(out, current_sys)
        data = out.(current_sys);
        
        % Extract columns: [u, x1, x2, v1, v2]
        actuals = [data(:, 1), data(:, 2), data(:, 3), data(:, 4), data(:, 5)]; 
        N = size(actuals, 1);
        
        % Align reference
        if length(x2_ref_signal) == N
            current_x2_ref = x2_ref_signal;
        else
            current_x2_ref = x2_ref_signal(1:N); 
        end
        
        targets = zeros(N, 5);
        targets(:, 3) = current_x2_ref; 
        
        for v = 1:length(var_names)
            error = actuals(:, v) - targets(:, v); 
            MAE = mean(abs(error));
            MSE = mean(error.^2);
            results_matrix(i, 1, v) = MAE;
            results_matrix(i, 2, v) = MSE;
            results_matrix(i, 3, v) = sqrt(MSE);
            results_matrix(i, 4, v) = mean(abs(error ./ (actuals(:, v) + eps))) * 100;
        end
    else
        warning(['Variable ', current_sys, ' not found in out. Check your To Workspace blocks!']);
    end
end

% 4. DISPLAY TABLES
clc;
disp('=== PERFORMANCE METRICS (FROM MANUAL RUN) ===');
for v = 1:length(var_names)
    disp(['--- Metrics for ', var_names{v}, ' ---']);
    ResultsTable = array2table(results_matrix(:, :, v), 'RowNames', row_names, 'VariableNames', metric_names);
    disp(ResultsTable);
end


% --- EXPORT TO EXCEL ---
filename = 'System_Performance_Results.xlsx';

% Delete the file if it already exists to ensure a fresh start
if exist(filename, 'file')==2, delete(filename); end

for v = 1:length(var_names)
    % Extract data and create the table object
    current_var_data = results_matrix(:, :, v);
    T = array2table(current_var_data, ...
        'RowNames', row_names, ...
        'VariableNames', metric_names);
    
    % Clean the variable name to be used as a Sheet Name (no special characters)
    clean_sheet_name = regexprep(var_names{v}, '[^a-zA-Z0-9]', '_');
    
    % Write to Excel
    % 'WriteRowNames', true is critical so your "PID", "LQR", etc. labels appear
    writetable(T, filename, 'Sheet', clean_sheet_name, 'WriteRowNames', true);
end

fprintf('Success! Metrics exported to: %s\n', filename);