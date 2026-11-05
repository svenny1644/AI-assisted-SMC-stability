% Define System Parameters
clc;
m1 = 250; m2 = 300; k1 = 750; k2 = 250; b1 = 50; b2 = 100;

% Define A and B Matrices
A = [0, 0, 1, 0;
     0, 0, 0, 1;
     -(k1+k2)/m1, k2/m1, -(b1+b2)/m1, b2/m1;
     k2/m2, -k2/m2, b2/m2, -b2/m2];

B = [0; 0; 1/m1; 0];

% --- Generate K for Strategy A ---
Q_A = diag([2000000, 2000000, 0, 0]); R_A = 0.005;
K_A = lqr(A, B, Q_A, R_A);
disp('Strategy A (Position Priority) K Matrix:'); disp(K_A);

% --- Generate K for Strategy B ---
Q_B = diag([500, 500, 50, 50]); R_B = 1;
K_B = lqr(A, B, Q_B, R_B);
disp('Strategy B (Balanced) K Matrix:'); disp(K_B);

% --- Generate K for Strategy C ---
Q_C = diag([100, 100, 0, 0]); R_C = 50;
K_C = lqr(A, B, Q_C, R_C);
disp('Strategy C (Energy Saving) K Matrix:'); disp(K_C);