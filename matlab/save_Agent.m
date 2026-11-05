%save('Final_TD3_Agent.mat', 'agentObj');

function [is_done, next_timer_03, next_time_since_change, ...
          next_step_size, next_ref_prev] = check_safety( ...
          x1, x2, x2_ref, timer_03, time_since_change, ...
          current_step_size, x2_ref_prev)
% check_safety.m — Phase 1: 50 Hz Bounded Slalom
% Settle-time enforcement and hardware protection.

    is_done                = double(0);
    next_timer_03          = double(timer_03);
    next_time_since_change = double(time_since_change);
    next_step_size         = double(current_step_size);
    next_ref_prev          = double(x2_ref_prev);
    dt       = double(0.02);            % 50 Hz agent clock
    x2_error = double(x2_ref - x2);

    % Reference change detection
    if abs(x2_ref - x2_ref_prev) > 0.001
        next_time_since_change = double(0.0);
        next_step_size         = double(abs(x2_ref - x2_ref_prev));
    else
        next_time_since_change = double(time_since_change + dt);
    end
    next_ref_prev = double(x2_ref);

    % Condition A — hardware limit (x1 wall)
    if abs(x1) > 0.65
        is_done = double(1);
    end

    % Condition B — total loss of control
    if abs(x2_error) > 0.5
        next_timer_03 = double(timer_03 + dt);
    else
        next_timer_03 = double(0.0);
    end
    if next_timer_03 > 3.0
        is_done = double(1);
    end

    % Condition C — settle-time violation
    allowed_settle_time = double(2.5);
    error_band          = double(0.030);
    if (next_time_since_change > allowed_settle_time) && ...
       (abs(x2_error) > error_band)
        is_done = double(1);
    end

end