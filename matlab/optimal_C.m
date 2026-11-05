%% Inverted Pendulum: Optimal SMC Surface Generation (Updated States)
clc; clear;

% 1. Define the Linearized System Matrices
% States: [theta, theta_dot, x, x_dot]
A = [0, 1, 0, 0; 
     29.8310, 0, 0, 0; 
     0, 0, 0, 1; 
     -0.9392, 0, 0, 0];

B = [0; 
     -1.1574; 
     0; 
     0.4167];

% 2. Define the Penalty Matrices (Q and R)
% Q must perfectly match the state order: [theta, theta_dot, x, x_dot]
% theta=1000, theta_dot=100, x=100, x_dot=10
Q = diag([1000, 100, 100, 10]); 

% R penalizes the motor effort. 
R = 0.01;

% 3. Calculate the Optimal Gain (K)
K = lqr(A, B, Q, R);

% 4. Map the LQR Gain to the SMC Sliding Surface (C)
C = K;

fprintf('The optimal Sliding Surface coefficients (C) are:\n');
disp(C);