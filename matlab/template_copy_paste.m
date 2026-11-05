% 1. Define Linearized Plant Matrices (Example for Inverted Pendulum)
% State vector order: [theta; theta_dot; x; x_dot]
A = [0, 1, 0, 0; 
     29.8310, 0, 0, 0; 
     0, 0, 0, 1; 
     -0.9392, 0, 0, 0];

B = [0; -1.1574; 0; 0.4167];

% 2. Define Penalties
% Massive penalty on angle (1000), moderate on position (100)
Q = diag([1000, 100, 100, 10]); 
R = 0.01;

% 3. Calculate Optimal LQR Gain
K = lqr(A, B, Q, R);

% 4. Acquire the Sliding Matrix C
C = K;

% Display the result to copy into Simulink
disp('Your optimal Sliding Matrix C is:');
disp(C);