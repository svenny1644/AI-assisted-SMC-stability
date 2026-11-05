% 1. DATA VALIDATION
clc; close all;

if ~exist('out', 'var')
    error('Simulation data "out" not found. Please run the Simulink model manually first!');
end

% 2. LIST VARIABLES & LABELS
system_vars = {'cmsd_smc', 'CMSD_RL_SMC'}; 
labels = {'Normal SMC', 'RL-Tuned SMC'};

% Extract global time vector
try
    global_time = out.tout;
catch
    global_time = evalin('base', 'tout');
end

% Extract Reference
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

disp('Generating Tracking Performance graphs with Time-Sync Resampling...');

% 3. LOOP THROUGH EACH SYSTEM AND PLOT
for i = 1:length(system_vars)
    current_sys = system_vars{i};
    
    if isprop(out, current_sys)
        data_raw = out.(current_sys);
    else
        warning(['Variable ', current_sys, ' not found. Skipping...']);
        continue;
    end
    
    % Handle timeseries vs raw array
    if isa(data_raw, 'timeseries') || isa(data_raw, 'Simulink.SimulationData.Signal')
        x2_data = data_raw.Data(:, 3); 
        time_vec = data_raw.Time; 
    else
        x2_data = data_raw(:, 3); 
        time_vec = global_time;
    end
    
    % Ensure base lengths match before resampling
    N = length(x2_data);
    if length(time_vec) ~= N
        time_vec = linspace(0, max(time_vec), N)';
    end
    
    % --- THE RESAMPLING LOGIC (Time-Syncing) ---
    ref_len = length(x2_ref_signal);
    if ref_len == 1
        % If reference is just a static single number (e.g., 0)
        current_x2_ref = ones(N, 1) * x2_ref_signal;
    else
        if N ~= ref_len
            % Downsample (or Upsample) x2_data to perfectly match the 601 reference points
            % This keeps the 60s time-scale perfectly intact.
            new_time = linspace(time_vec(1), time_vec(end), ref_len)';
            x2_data = interp1(time_vec, x2_data, new_time, 'linear');
            time_vec = new_time; 
            N = ref_len; 
        end
        current_x2_ref = x2_ref_signal;
    end
    % -------------------------------------------
    
    % 4. CREATE FIGURE
    fig = figure('Name', [labels{i}, ' Tracking'], 'Color', 'w', 'Position', [100, 100, 800, 400]);
    hold on; grid on;
    
    plot(time_vec, current_x2_ref, '--', 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.5, 'DisplayName', 'Reference (x_2_{ref})');
    plot(time_vec, x2_data, '-', 'Color', [0 0.4470 0.7410], 'LineWidth', 1.5, 'DisplayName', 'Actual Position (x_2)');
    
    xlabel('Time (s)', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Position, x_2 (m)', 'FontSize', 12, 'FontWeight', 'bold');
    title(['Tracking Performance: ', labels{i}], 'FontSize', 14, 'FontWeight', 'bold');
    legend('Location', 'northeast', 'FontSize', 11, 'Box', 'off');
    
    xlim([min(time_vec), max(time_vec)]);
    max_val = max(max(x2_data), max(current_x2_ref));
    min_val = min(min(x2_data), min(current_x2_ref));
    padding = (max_val - min_val) * 0.15;
    if padding == 0; padding = 0.1; end
    ylim([min_val - padding, max_val + padding]); 
    
    box on;
    ax = gca; ax.FontSize = 11; ax.LineWidth = 1; ax.GridAlpha = 0.3; 
    hold off;
end

disp('All tracking graphs generated successfully!');