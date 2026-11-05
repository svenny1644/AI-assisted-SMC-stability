# RL Meta-SMC: A Supervisory Reinforcement Learning Agent for Sliding Mode Control

> Benchmarking seven classical and modern control architectures — PID, Adaptive PID, LQR, PID+LQR, SMC, Adaptive SMC, and MPC — against a TD3-based reinforcement learning agent that supervises and re-tunes a Sliding Mode Controller in real time.

**Author:** Nguyễn Minh Hoàng (Student ID: 2252234)
**Course:** ME4204 – Introduction to Modern Control Systems, HCM City University of Technology
**Supervisors:** Prof. Nguyễn Duy Anh (Lecturing), Prof. Trương Ngọc Cương (Practice)
**Date:** May 2026

---

## Table of Contents

- [Overview](#overview)
- [Systems Modeled](#systems-modeled)
- [Controllers Implemented](#controllers-implemented)
- [Results Summary](#results-summary)
- [The RL Meta-SMC Architecture](#the-rl-meta-smc-architecture)
- [Training & Validation Pipeline](#training--validation-pipeline)
- [Stability Analysis](#stability-analysis)
- [Pros & Cons of the RL Approach](#pros--cons-of-the-rl-approach)
- [Repository Structure](#repository-structure)
- [Tech Stack](#tech-stack)

---

## Overview

This project compares classical/modern control theory against a reinforcement-learning-augmented controller on two benchmark plants. Rather than treating RL as a replacement for Sliding Mode Control (SMC), the core contribution — **RL Meta-SMC** — positions a trained TD3 agent as a *supervisory layer* above a standard SMC: the agent doesn't compute the control force directly, it continuously re-tunes the SMC's own parameters (sliding surface coefficients, switching gain, boundary layer thickness) based on real-time system state. The SMC retains its mathematical stability guarantees; the neural network contributes situational awareness that fixed-gain and even classical adaptive laws cannot.

The project is split into two stages:
1. **Classical & modern benchmarking** — seven controllers evaluated on an Inverted Pendulum (IP) and a Coupled Mass-Spring-Damper (CMSD) system.
2. **RL Meta-SMC** — a TD3 agent trained for 5,000 episodes to supervise the CMSD's SMC, benchmarked against a fixed-parameter SMC via Monte Carlo evaluation and backed by a formal stability proof.

---

## Systems Modeled

### 1. Inverted Pendulum (Cart-Pole)
A 4-state, non-collocated, inherently unstable mechatronic system (right-half-plane pole). Control effort is applied to the cart; the goal is to stabilize the pendulum angle while tracking a cart position reference.

| Parameter | Value |
|---|---|
| Cart mass (M) | 2.4 kg |
| Pendulum mass (m) | 0.23 kg |
| Distance to pendulum CoM (l) | 0.36 m |
| Gravity (g) | 9.8 m/s² |
| Cart travel limit | ±1 m |
| Sensor noise | Band-limited white noise, power 0.001 m |

### 2. Coupled Mass-Spring-Damper (CMSD)
A 4-state, non-collocated system representing an active suspension / dual-mass positioning stage. Control effort acts on `m1`; the tracked variable `x2` is separated from the actuator by a flexible spring, making this a harder tracking problem than the IP.

| Parameter | Value |
|---|---|
| Unsprung mass (k1, b1) | 750 N/m, 50 Ns/m |
| Sprung mass (m2, k2, b2) | 300 kg, 250 N/m, 100 Ns/m |
| Control input cap | ±3500 N |
| Sensor noise | Band-limited white noise, power 200 N |

---

## Controllers Implemented

| Controller | Summary | Strength | Weakness |
|---|---|---|---|
| **PID (+ Feedforward)** | Model-free, reactive P/I/D correction with a feedforward baseline term | Simple, precise for static loads | Blind to system physics, reactive only |
| **Adaptive PID** | Gains shift with operating conditions | Handles varying payloads | High computational overhead, can overreact |
| **LQR** | Optimal state-feedback regulator (Q/R cost tradeoff) | Mathematically guaranteed stability | No integral action → poor non-zero tracking |
| **PID + LQR Hybrid** | LQR inner loop + PID outer loop (cascaded) | Combines regulation and tracking | Complex to tune, loops can fight each other |
| **SMC** | Robust switching control along a defined sliding surface | Extreme robustness to matched disturbances | Chattering unless boundary-layer smoothed |
| **Adaptive SMC (Culture-Bee)** | Switching gain / boundary layer re-optimized every 0.01 s via a Culture-Bees metaheuristic | Smooths chattering near target | Heavy real-time compute cost |
| **MPC** | Receding-horizon optimization under explicit constraints | Best tracking accuracy, handles constraints natively | Computationally expensive, model-dependent |
| **RL Meta-SMC (this project)** | TD3 agent supervises SMC's parameters in real time | Learns the Pareto trade-off surface empirically | Expensive to train, hard to certify |

---

## Results Summary
**Disclaimer:** This project was done as an Assignment for the course Introduction to Modern Control Systems; therefore the controllers in this project are nowhere near being professionally parameterized, and therefore these results are not indicative of well-tuned tracking algorithms.

### Inverted Pendulum

| Controller | Position MAE (m) | Position RMSE (m) | Angle MAE (rad) | Angle RMSE (rad) |
|---|---|---|---|---|
| Dual PID | 0.0582 | 0.1068 | 0.0028 | 0.0035 |
| SMC | 0.0342 | 0.0902 | 0.0015 | 0.0032 |

SMC improved position tracking by **41.2%** and angle precision by **46.7%** over Dual PID, with only a 2.1% increase in average control effort.

### Coupled Mass-Spring-Damper (all 7 controllers)

| Controller | Tracking MAE (m) | Tracking RMSE (m) | Effort MAE (N) | Effort RMSE (N) |
|---|---|---|---|---|
| PID + Feedforward | 0.00643 | 0.02888 | 165.04 | 307.16 |
| Adaptive PID | 0.00899 | 0.03054 | 163.78 | 306.87 |
| LQR | 0.02337 | 0.05679 | 144.57 | 175.40 |
| PID + LQR Hybrid | 0.01000 | 0.03723 | 165.48 | 308.02 |
| SMC | 0.00780 | 0.03363 | 151.59 | 200.79 |
| Adaptive SMC | 0.01327 | 0.04251 | 147.89 | 196.48 |
| **MPC** | **0.00358** | **0.02589** | 160.23 | 228.01 |

MPC delivered the best tracking accuracy overall (23% better RMSE than SMC) at a moderate 16% effort premium — a favorable tradeoff when positional precision is the priority.

### RL Meta-SMC vs. Fixed-Parameter SMC (final benchmark)

| Metric | Fixed SMC | RL-Tuned SMC | Δ |
|---|---|---|---|
| Average energy usage | 95.79 N | 96.05 N | ≈ equal |
| Peak energy usage | ±2,427 N | ±1,196 N | **−51% peak actuator stress** |
| Average tracking error | 0.0127 m | 0.0169 m | **+33% tracking error** |

**Key finding:** the RL agent did not uniformly outperform the fixed SMC — it found a different, deliberate point on the Pareto frontier between actuator wear and tracking precision, trading steady-state precision for roughly half the peak mechanical stress, exactly as its reward function incentivized.

---

## The RL Meta-SMC Architecture

**Algorithm:** TD3 (Twin Delayed Deep Deterministic Policy Gradient) — chosen over DDPG/DQN to counter Q-value overestimation bias via twin critics, delayed actor updates, and target policy smoothing.

**Observation space (13-D):**
`[x1, x2, v1, v2, x2_ref, x2_error, time_since_change, s, C2_prev, C4_prev, eta_prev, phi_prev, ref_jump]`

**Action space (4-D, normalized to [-1, 1]):**
`[C2_tune, C4_tune, Eta_tune, Phi_tune]` → scaled downstream to the SMC's physical parameter ranges:

| Parameter | Role | Range |
|---|---|---|
| C₂ | Sliding surface — speed vs. overshoot | 15.0 – 25.0 |
| C₄ | Sliding surface — damping | 1.0 – 3.0 |
| η (Eta) | Reaching law gain (steady-state error) | 50.0 – 150.0 |
| φ (Phi) | Boundary layer thickness (chattering control) | 0.030 – 0.170 |

**Network:** 3 fully-connected hidden layers × 256 neurons, `tanh` activations, terminal `tanh` output layer.

**Hyperparameters:** γ = 0.99, replay buffer = 10⁶ transitions, batch size = 256, critic LR = 3×10⁻⁴, actor LR = 1×10⁻⁴, exploration variance 1.0 → 0.05 (decay 5×10⁻⁶/episode).

**Training:** 5,000 episodes × up to 3,000 steps (60 s simulated @ 50 Hz agent clock) — approx. 12 hours on an RTX 3080 Ti (12 GB VRAM) + 64 GB DDR5.

### Reward Function
Evaluated at 50 Hz across 7 weighted criteria, dominated by a quadratic tracking penalty on `x2` and shaped by secondary objectives (energy efficiency, `x1` constraint compliance):

- Base survival reward: `±0.2`
- Tracking penalty: `−4.0 × e²`
- "Parachute" penalty for high velocity near-target (discourages overshoot)
- Target-lock bonus inside 10 mm / 30 mm error bands
- Continuous Gaussian progress bonus
- `x1` soft barrier + centering bonus
- Terminal penalty of `−2000` on hardware-limit violation
- Hard reward floor of `−10.0` per step

### Kill Switch (Safety Interlock)
Terminates an episode immediately — with no further reward — on any of:

| # | Condition | Trigger |
|---|---|---|
| 1 | Hardware limit | `|x1| > 0.65 m` |
| 2 | Total loss of control | `|x2_error| > 0.50 m` for > 3.0 s |
| 3 | Settle-time violation | `|x2_error| > 30 mm` for > 2.5 s after last reference change |

---

## Training & Validation Pipeline

1. **Training** — 5,000-episode TD3 run; convergence plateaus around episode ~1,200, after which average reward shows peaks/troughs from exploration noise rather than meaningful gains.
2. **Agent screening** — all saved checkpoints re-simulated against a fixed seed pair to rank by chattering-penalized score. **Agent 3971** (score 629) outperformed the final **Agent 5000** (score 614).
3. **Monte Carlo evaluation** — Agent 3971 vs. Agent 5000 run across 100 randomized episodes, repeated for 3 independent RNG seeds (42, 16, 44):

   | Seed | Agent 3971 avg. | Agent 5000 avg. |
   |---|---|---|
   | 42 | 1094.57 | 1007.53 |
   | 16 | 1062.92 | 990.99 |
   | 44 | 1151.37 | 1065.71 |

   Agent 3971 consistently outperformed Agent 5000 by ~70–85 points across 300 total episodes — evidence of **policy degradation**: continued training past convergence, under active exploration noise, slightly eroded an already-optimal policy.
4. **Final benchmark** — Agent 3971 vs. a fixed-parameter SMC baseline under identical noise/reference seeds (see [Results Summary](#rl-meta-smc-vs-fixed-parameter-smc-final-benchmark)).

---

## Stability Analysis
**Disclaimer:** This study has not taken into account sensor lag or computational speed bottlenecks of Industrial Controllers.

Because the RL agent changes SMC parameters online, the standard static-gain Lyapunov argument (`V̇ = s·ṡ ≤ −η|s| < 0`) does not directly apply — switching between stable configurations can itself destabilize a system (Liberzon, *Switching in Systems and Control*, 2003).

This project addresses that with a **dwell-time stability proof**:

- Derives a guaranteed exponential decay rate `λ_min ≈ 448.0` from the worst-case tanh reaching-law bound, using the agent's parameter floor (`η_min = 50`, `φ_max = 0.170`).
- Derives the worst-case single-step Lyapunov energy jump `μ_max ≈ 1965.4` from the maximum legal parameter shift (bounded by the reward function's chatter penalty) combined with worst-case physical states.
- Computes the required Liberzon dwell time: `τ_d = ln(μ_max) / λ_min ≈ 0.0169 s`.
- Confirms the agent's fixed 50 Hz (0.02 s) control clock **exceeds** this minimum dwell time, proving the switched system is **Globally Asymptotically Stable** regardless of initial conditions.

---

## Pros & Cons of the RL Approach

**Limitations:**
- **Hardware cost** — GPU training, large replay buffers (~250 GB for this run alone); inference-only deployment still a tough fit for lean embedded targets (automotive ECUs, flight computers, PLCs).
- **Retraining overhead** — any plant change (payload, spring constants, actuator limits) requires a full retrain + re-validation cycle, unlike a same-day SMC re-tune.
- **No direct tunability** — fixing a specific performance shortfall means reshaping the reward function and retraining, not adjusting a single gain.
- **Certification** — no decision-chain to audit for individual actions, making compliance with standards like DO-178C, IEC 62304, or ISO 26262 effectively impossible today.

**Where it's worth it:**
- Plants too complex or poorly modeled for classical/MPC assumptions to hold.
- Applications where a single fixed algorithm can't sit optimally across competing objectives (tracking vs. energy vs. actuator wear) and the Pareto trade-off itself needs to be navigated in real time.
- Systems where **actuator longevity** outweighs micro-precision — e.g., offshore machinery, deep-space mechanisms, implanted medical devices — where this project's RL agent achieved ~51% lower peak actuator stress at the cost of 33% more tracking error.

---

## Repository Structure

> Planned layout — incomplete 

```
.
├── README.md
├── report/
│   └── BTL_ME4204_Nguyen_Minh_Hoang_2252234.pdf      # Full written report
├── simulink/
│   ├── IP_system.slx                                 # Inverted Pendulum plant + controllers
│   ├── CMSD_system.slx                                # CMSD plant + classical controllers
│   └── RL_SMC_Training_Env.slx                        # RL training/validation environment
├── matlab/
│   ├── NN_SMC_Agent_1.m                               # TD3 agent construction & training script
│   ├── calc_reward.m                                  # 50 Hz reward function
│   ├── check_safety.m                                 # Kill-switch / safety interlock logic
│   ├── benchmark_agents.m                             # Post-training agent screening script
│   └── monte_carlo_eval.m                             # 100-run Monte Carlo evaluation
└── agents/
    └── Tested_Reward629_Agent3971.mat                 # Best-performing trained agent checkpoint
```

---

## Tech Stack

- **MATLAB & Simulink** — plant modeling, classical/modern controller implementation
- **Reinforcement Learning Toolbox** — TD3 agent, environment registration, training loop
- **Parallel Computing Toolbox** — parallelized Monte Carlo evaluation
- **Control theory** — LQR, SMC, MPC, Lyapunov stability, Liberzon switched-systems dwell-time analysis

---

## Acknowledgements

Submitted for ME4204 – Introduction to Modern Control Systems, HCM City University of Technology, under the supervision of Prof. Nguyễn Duy Anh and Prof. Trương Ngọc Cương.
