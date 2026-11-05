%% CMSD System Parameters
clc;
m1 = 250;  m2 = 300;
k1 = 750;  k2 = 250;
b1 = 50;   b2 = 100; % Assuming units are Ns/m

%% 1. State-Space Representation
% States x = [pos1; vel1; pos2; vel2]
A = [0, 1, 0, 0;
    -(k1+k2)/m1, -(b1+b2)/m1, k2/m1, b2/m1;
    0, 0, 0, 1;
    k2/m2, b2/m2, -k2/m2, -b2/m2];

B = [0; 1/m1; 0; 0];
C = [1 0 0 0;   % Output 1: Position of Mass 1
     0 0 1 0];  % Output 2: Position of Mass 2
D = [0; 0];

sys_open = ss(A, B, C, D);

%% 2. LQR Tuning (The "Suitable" K Search)
% Q: Penalty for state error. Increase 3rd value to tighten m2 control.
%Q = diag([5000, 10000, 100, 500]); 
%Q = diag([100, 200, 500, 1000]); 
Q = diag([100, 400, 500, 1000]);

% R: Penalty for control effort (Voltage/Force). 
% Decrease R for faster response; Increase R to save the motor.
R = 0.001; 
%R = 0.00001;

[K, S, P] = lqr(A, B, Q, R);

fprintf('Generated K vector:\n');
disp(K);

%% 3. Steady-State Gain (Nbar)
% LQR is a regulator (targets 0). To reach a specific position (e.g., 1m),
% we need a feedforward gain so the system doesn't stop short.
sys_cl = ss(A - B*K, B, C, D);
Nbar = 1 / dcgain(sys_cl(2)); % Targeting Mass 2 position

%% 4. Simulation & Validation
% t = 0:0.01:20;
% u_ref = ones(size(t)); % Target: Move to 1.0 unit
% [y, t, x] = lsim(sys_cl * Nbar, u_ref, t);
% 
% figure;
% plot(t, y(:,1), 'b--', 'LineWidth', 1.5); hold on;
% plot(t, y(:,2), 'r-', 'LineWidth', 2);
% grid on;
% title('LQR Step Response: CMSD System');
% xlabel('Time (s)'); ylabel('Position (m)');
% legend('Mass 1 (Motor)', 'Mass 2 (Load)');