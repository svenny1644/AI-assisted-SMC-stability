% =========================================================================
% Meta-RL Parameter Adaptation Viewer
% Plots: [C2 & C4], [Eta], and [Phi] from 'control_changes'
% =========================================================================
clc; close all;

% 1. DATA VALIDATION
if ~exist('out', 'var')
    error('Simulation data "out" not found. Please run the model manually first!');
end

disp('Extracting AI parameter adjustments...');

% 2. EXTRACT DATA
if isprop(out, 'control_changes')
    raw_params = out.control_changes;
    
    % Handle timeseries vs raw array
    if isa(raw_params, 'timeseries') || isa(raw_params, 'Simulink.SimulationData.Signal')
        time_vec = raw_params.Time;
        C2  = raw_params.Data(:, 1);
        C4  = raw_params.Data(:, 2);
        Eta = raw_params.Data(:, 3);
        Phi = raw_params.Data(:, 4);
    else
        % If raw array, attempt to grab the global tout
        try
            time_vec = out.tout;
        catch
            time_vec = evalin('base', 'tout');
        end
        C2  = raw_params(:, 1);
        C4  = raw_params(:, 2);
        Eta = raw_params(:, 3);
        Phi = raw_params(:, 4);
    end
else
    error('Variable "control_changes" not found! Ensure the "To Workspace" block is named exactly correctly.');
end

% Failsafe for length mismatch
if length(time_vec) ~= length(C2)
    time_vec = linspace(0, max(time_vec), length(C2))';
end

% Color Palette for clean technical graphs
color_c2  = [0 0.4470 0.7410];      % Blue
color_c4  = [0.8500 0.3250 0.0980]; % Red/Orange
%color_eta = [0.4660 0.6740 0.1880]; % Green
color_eta = [0.4940 0.1840 0.5560]; % Purple
color_phi = [0.4940 0.1840 0.5560]; % Purple

disp('Generating Parameter Tracking Windows...');

% -------------------------------------------------------------------------
% GRAPH 1: C2 and C4 (Sliding Surface Coefficients)
% -------------------------------------------------------------------------
fig1 = figure('Name', 'RL Output: C2 & C4', 'Color', 'w', 'Position', [100, 200, 800, 400]);
hold on; grid on;

plot(time_vec, C2, '-', 'Color', color_c2, 'LineWidth', 1.5, 'DisplayName', 'C_2 (Damping)');
plot(time_vec, C4, '-', 'Color', color_c4, 'LineWidth', 1.5, 'DisplayName', 'C_4 (Stiffness)');

xlabel('Time (s)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Parameter Value', 'FontSize', 12, 'FontWeight', 'bold');
title('AI Adaptation: Sliding Surface Coefficients (C_2, C_4)', 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 11, 'Box', 'off');

xlim([min(time_vec), max(time_vec)]);
y_max = max(max(C2), max(C4));
y_min = min(min(C2), min(C4));
pad = max((y_max - y_min) * 0.15, 0.1);
ylim([y_min - pad, y_max + pad]);

ax1 = gca; ax1.FontSize = 11; ax1.LineWidth = 1; ax1.GridAlpha = 0.3;
box on; hold off;

% -------------------------------------------------------------------------
% GRAPH 2: Eta (Reaching Law Gain)
% -------------------------------------------------------------------------
fig2 = figure('Name', 'RL Output: Eta', 'Color', 'w', 'Position', [150, 150, 800, 400]);
hold on; grid on;

plot(time_vec, Eta, '-', 'Color', color_eta, 'LineWidth', 1.5, 'DisplayName', '\eta (Reaching Gain)');

xlabel('Time (s)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('\eta Value', 'FontSize', 12, 'FontWeight', 'bold');
title('AI Adaptation: Reaching Law Gain (\eta)', 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 11, 'Box', 'off');

xlim([min(time_vec), max(time_vec)]);
pad_eta = max((max(Eta) - min(Eta)) * 0.15, 0.05);
ylim([min(Eta) - pad_eta, max(Eta) + pad_eta]);

ax2 = gca; ax2.FontSize = 11; ax2.LineWidth = 1; ax2.GridAlpha = 0.3;
box on; hold off;

% -------------------------------------------------------------------------
% GRAPH 3: Phi (Boundary Layer Thickness)
% -------------------------------------------------------------------------
fig3 = figure('Name', 'RL Output: Phi', 'Color', 'w', 'Position', [200, 100, 800, 400]);
hold on; grid on;

plot(time_vec, Phi, '-', 'Color', color_phi, 'LineWidth', 1.5, 'DisplayName', '\Phi (Boundary Layer)');

xlabel('Time (s)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('\Phi Value', 'FontSize', 12, 'FontWeight', 'bold');
title('AI Adaptation: Boundary Layer Thickness (\Phi)', 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 11, 'Box', 'off');

xlim([min(time_vec), max(time_vec)]);
pad_phi = max((max(Phi) - min(Phi)) * 0.15, 0.05);
ylim([min(Phi) - pad_phi, max(Phi) + pad_phi]);

ax3 = gca; ax3.FontSize = 11; ax3.LineWidth = 1; ax3.GridAlpha = 0.3;
box on; hold off;

disp('All parameter windows generated successfully!');