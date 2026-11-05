clear; clc; close all;

% 1. DATA ENTRY (Pulled from your previous MAE tables, LQR excluded)
methods = {'PID', 'Adaptive PID', 'PID + LQR', 'SMC', 'Adaptive SMC'};

% X-Axis: Control Effort MAE (Newtons)
effort_mae = [165.04, 165.62, 164.56, 153.00, 147.79];

% Y-Axis: Tracking Error MAE (Meters)
tracking_mae = [0.00643, 0.00673, 0.01514, 0.00779, 0.01326];

% 2. CREATE THE FIGURE
figure('Color', 'w', 'Name', 'Control Methodology Trade-off', 'Position', [100, 100, 800, 500]);

% Plot the points
scatter(effort_mae, tracking_mae, 120, 'filled', ...
    'MarkerFaceColor', [0 0.4470 0.7410], ... % Deep Blue
    'MarkerEdgeColor', 'k', 'LineWidth', 1);
hold on;

% 3. ADD LABELS TO THE POINTS
for i = 1:length(methods)
    % We offset the text slightly to the left and up so it doesn't cover the dot
    text(effort_mae(i) - 0.5, tracking_mae(i) + 0.0004, methods{i}, ...
        'HorizontalAlignment', 'right', ...
        'FontSize', 11, 'FontWeight', 'bold');
end

% 4. FORMATTING THE AXES
grid on;
box on;
ax = gca;
ax.FontSize = 11;
ax.LineWidth = 1.2;
ax.GridLineStyle = '--';
ax.GridAlpha = 0.4;

% Add padding to the axes so labels don't get cut off
xlim([140, 170]);
ylim([0, 0.018]);

% 5. TITLES AND AXIS LABELS
title('Performance Trade-off: Tracking Precision vs. Control Effort', 'FontSize', 14, 'FontWeight', 'bold');
xlabel('Control Effort MAE (Newtons) \rightarrow', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Tracking Error MAE (Meters) \uparrow', 'FontSize', 12, 'FontWeight', 'bold');

% 6. ADD THE "IDEAL ZONE" ANNOTATION
% Draws a green arrow pointing to the bottom-left corner
annotation('textarrow', [0.25 0.15], [0.25 0.15], ...
    'String', 'Ideal Zone (Low Error, Low Effort)', ...
    'FontSize', 11, 'Color', [0.4660 0.6740 0.1880], ... % Green
    'FontWeight', 'bold', 'LineWidth', 2);