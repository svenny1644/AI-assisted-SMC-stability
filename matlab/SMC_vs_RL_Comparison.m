% =========================================================================
% Controller Comparison: Normal SMC vs. RL-Tuned SMC (Separate Windows)
% =========================================================================
clc; close all;

if ~exist('out', 'var')
    error('Simulation data "out" not found. Please run the model manually first!');
end

disp('Extracting and Time-Syncing data for separate comparisons...');

% --- 1. EXTRACT GLOBAL TIME & REFERENCE ---
try
    global_time = out.tout;
catch
    global_time = evalin('base', 'tout');
end

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

% Master timeline is based on the reference signal
ref_len = length(x2_ref_signal);

if ref_len > 1
    master_time = linspace(global_time(1), global_time(end), ref_len)';
else
    master_time = global_time;
    x2_ref_signal = ones(length(global_time), 1) * x2_ref_signal;
end

% --- 2. EXTRACT & RESAMPLE NORMAL SMC ---
if isprop(out, 'cmsd_smc')
    raw_smc = out.cmsd_smc;
    if isa(raw_smc, 'timeseries') || isa(raw_smc, 'Simulink.SimulationData.Signal')
        u_smc = raw_smc.Data(:, 1);
        x2_smc = raw_smc.Data(:, 3);
        t_smc = raw_smc.Time;
    else
        u_smc = raw_smc(:, 1);
        x2_smc = raw_smc(:, 3);
        t_smc = linspace(global_time(1), global_time(end), length(x2_smc))';
    end
    
    if length(x2_smc) ~= length(master_time)
        x2_smc = interp1(t_smc, x2_smc, master_time, 'linear', 'extrap');
        u_smc  = interp1(t_smc, u_smc, master_time, 'linear', 'extrap');
    end
else
    error('Variable "cmsd_smc" not found in out object.');
end

% --- 3. EXTRACT & RESAMPLE RL-SMC ---
if isprop(out, 'CMSD_RL_SMC')
    raw_rl = out.CMSD_RL_SMC;
    if isa(raw_rl, 'timeseries') || isa(raw_rl, 'Simulink.SimulationData.Signal')
        u_rl = raw_rl.Data(:, 1);
        x2_rl = raw_rl.Data(:, 3);
        t_rl = raw_rl.Time;
    else
        u_rl = raw_rl(:, 1);
        x2_rl = raw_rl(:, 3);
        t_rl = linspace(global_time(1), global_time(end), length(x2_rl))';
    end
    
    if length(x2_rl) ~= length(master_time)
        x2_rl = interp1(t_rl, x2_rl, master_time, 'linear', 'extrap');
        u_rl  = interp1(t_rl, u_rl, master_time, 'linear', 'extrap');
    end
else
    error('Variable "CMSD_RL_SMC" not found in out object.');
end

% --- 4. PLOTTING FIGURES ---
color_ref = [0.2 0.2 0.2];      
color_smc = [0 0.4470 0.7410];  
color_rl  = [0.8500 0.3250 0.0980]; 

% -------------------------------------------------------------------------
% WINDOW 1: Tracking Performance (x2)
% -------------------------------------------------------------------------
fig1 = figure('Name', 'Tracking Performance', 'Color', 'w', 'Position', [100, 200, 800, 450]);
hold on; grid on;

plot(master_time, x2_ref_signal, '--', 'Color', color_ref, 'LineWidth', 1.5, 'DisplayName', 'Reference (x_2_{ref})');
plot(master_time, x2_smc, '-', 'Color', color_smc, 'LineWidth', 1.5, 'DisplayName', 'Normal SMC');
plot(master_time, x2_rl, '-', 'Color', color_rl, 'LineWidth', 1.5, 'DisplayName', 'RL-Tuned SMC');

xlabel('Time (s)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Position, x_2 (m)', 'FontSize', 12, 'FontWeight', 'bold');
title('Tracking Performance: Normal vs. RL-Tuned SMC', 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'northeast', 'FontSize', 11, 'Box', 'off');

xlim([min(master_time), max(master_time)]);
max_val = max([max(x2_smc), max(x2_rl), max(x2_ref_signal)]);
min_val = min([min(x2_smc), min(x2_rl), min(x2_ref_signal)]);
padding = max((max_val - min_val) * 0.15, 0.1);
ylim([min_val - padding, max_val + padding]); 

ax1 = gca; ax1.FontSize = 11; ax1.LineWidth = 1; ax1.GridAlpha = 0.3;
box on; hold off;

% -------------------------------------------------------------------------
% WINDOW 2: Control Effort (u)
% -------------------------------------------------------------------------
% Offset the position slightly ([150, 150]) so it doesn't completely hide the first window
fig2 = figure('Name', 'Control Effort', 'Color', 'w', 'Position', [150, 150, 800, 450]);
hold on; grid on;

plot(master_time, u_smc, '-', 'Color', color_smc, 'LineWidth', 1.5, 'DisplayName', 'Normal SMC');
plot(master_time, u_rl, '-', 'Color', color_rl, 'LineWidth', 1.5, 'DisplayName', 'RL-Tuned SMC');

yline(0, '--', 'Color', color_ref, 'LineWidth', 1.0, 'HandleVisibility', 'off');

xlabel('Time (s)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Control Effort, u (N)', 'FontSize', 12, 'FontWeight', 'bold');
title('Control Effort: Normal vs. RL-Tuned SMC', 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'northeast', 'FontSize', 11, 'Box', 'off');

xlim([min(master_time), max(master_time)]);
y_max = max(max(abs(u_smc)), max(abs(u_rl)));
if y_max < 0.1, y_max = 1; end
ylim([-y_max*1.2, y_max*1.2]); 

ax2 = gca; ax2.FontSize = 11; ax2.LineWidth = 1; ax2.GridAlpha = 0.3;
box on; hold off;

disp('Separate comparison windows generated successfully!');