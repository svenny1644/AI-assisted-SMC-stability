# AI-Assisted Sliding Mode Control (Simulation, Dwell-Time Stability & Multi-Agent Benchmark)

A supervisory Deep Reinforcement Learning (DRL) framework paired with Sliding Mode Control (SMC) for online parameter adaptation on a 4th-order non-collocated Coupled Mass-Spring-Damper (CMSD) system[cite: 3, 5, 28]. 

The architecture deploys an offline-trained continuous-action **Twin Delayed Deep Deterministic Policy Gradient (TD3)** supervisory agent updating the SMC surface slopes, reaching gain, and boundary layer parameters online at 50 Hz[cite: 30, 32, 35]. The closed-loop switched system is analytically proven to be **Globally Asymptotically Stable via Liberzon's dwell-time theory** ($\tau_d = 0.0169\text{ s} \le 0.02\text{ s}$)[cite: 61], slashing peak mechanical actuator stress by **51%** ($\pm 1,196\text{ N}$ vs. $\pm 2,427\text{ N}$) for identical average energy consumption[cite: 53].

<!-- Embed your Simulink / response comparison plot here -->
![Control Comparison](media/smc_tracking_effort_comparison.png)

---

## 📌 Key Engineering Highlights

* **Supervisory DRL Adaptation:** Unlike reactive self-tuning laws, the supervisory TD3 actor network dynamically modulates $\mathbf{\theta}_k = [C_2, C_4, \eta, \phi]^T$ at 50 Hz ($\Delta t = 0.02\text{ s}$) based on a 13-dimensional system observation vector[cite: 30, 34, 35, 36]:
  $$\mathbf{o} = [x_1, x_2, v_1, v_2, x_{2,\text{ref}}, e_{x_2}, t_{\text{step}}, s, C_{2,\text{prev}}, C_{4,\text{prev}}, \eta_{\text{prev}}, \phi_{\text{prev}}, \Delta x_{\text{ref}}]^T \in \mathbb{R}^{13}$$
[cite: 36, 37]
* **Analytical Stability Guarantee (Liberzon's Dwell-Time):** Solved the non-trivial stability problem of dynamic parameter switching[cite: 58, 59]. Derived the exponential decay rate under a hyperbolic tangent reaching law ($\lambda_{\min} = 448.0$)[cite: 59, 60] and bounded the maximum energy jump ($\mu_{\max} \approx 1965.4$) under action rate penalties[cite: 60, 61]:
  $$\tau_d = \frac{\ln(\mu_{\max})}{\lambda_{\min}} = \frac{\ln(1965.4)}{448.0} \approx 0.0169\text{ s} \le 0.02\text{ s} = T_s$$
[cite: 61]
  Because the controller sample time ($0.02\text{ s}$) strictly exceeds the calculated dwell time ($0.0169\text{ s}$), the hybrid switched system is provably **Globally Asymptotically Stable**[cite: 61].
* **Actuator Protection & Energy Distribution:** Slashed maximum control effort by **51%** ($\pm 1,196\text{ N}$ vs. $\pm 2,427\text{ N}$) relative to fixed-gain SMC while maintaining near-identical average energy draw ($96.05\text{ N}$ vs. $95.79\text{ N}$)[cite: 53].
* **Statistical Rigor & Policy Drift Detection:** Evaluated across a **100-run parallel Monte Carlo suite** over 3 randomized RNG seeds (42, 16, 44; 300 total 60-second evaluations)[cite: 47, 49]. Identified late-stage policy degradation between mid-training (Agent 3971: avg score $1,102.9$) and end-of-training (Agent 5000: avg score $1,021.4$) caused by lingering exploration noise[cite: 46, 49].
* **Comprehensive Benchmarking:** Evaluated alongside **7 classical and modern control topologies** (Dual PID, SMC on Inverted Pendulum[cite: 7, 10, 13]; PID w/ Feedforward, Adaptive PID, LQR, PID+LQR, Culture-Bees Adaptive SMC, and linear MPC on CMSD)[cite: 5, 6, 7, 13, 16, 20, 22, 25].

---

## 🔬 Mathematical Modeling & System Formulation

### 1. Coupled Mass-Spring-Damper (CMSD) Dynamics
The plant is a 4th-order non-collocated dual-mass system representing an active vehicular suspension or precision industrial dual-stage positioning system[cite: 4, 9]:
* **Unsprung Mass (Actuated):** $m_1 = 250\text{ kg}$, $k_1 = 750\text{ N/m}$, $b_1 = 50\text{ Ns/m}$[cite: 4, 9]
* **Sprung Mass (Tracked Output $x_2$):** $m_2 = 300\text{ kg}$, $k_2 = 250\text{ N/m}$, $b_2 = 100\text{ Ns/m}$[cite: 4, 9]
* **Actuation Limits:** $u(t) \in [-3500, 3500]\text{ N}$ acting directly on $m_1$[cite: 4, 9]
* **Sensor Noise:** Band-limited white noise with power $200\text{ N}$, sample time $0.01\text{ s}$[cite: 9]

State equations:
$$\begin{aligned} \ddot{x}_1 &= \frac{1}{m_1} \left[ u(t) - (b_1 + b_2)\dot{x}_1 - (k_1 + k_2)x_1 + b_2\dot{x}_2 + k_2 x_2 \right] \\ \ddot{x}_2 &= \frac{1}{m_2} \left[ -b_2(\dot{x}_2 - \dot{x}_1) - k_2(x_2 - x_1) + d(t) \right] \end{aligned}$$
[cite: 4, 9]

### 2. SMC Surface and Reaching Law
The sliding surface vector $C = [0, C_2, 0, C_4]^T$ acts on the state tracking error vector $\mathbf{e} = \mathbf{x}_{\text{ref}} - \mathbf{x}$[cite: 18, 41, 42]:
$$s(\mathbf{x}) = C_2 (\dot{x}_{1,\text{ref}} - \dot{x}_1) + C_4 (\dot{x}_{2,\text{ref}} - \dot{x}_2)$$
[cite: 42, 61]
Using an exponential reaching law smoothed by a hyperbolic tangent boundary layer to prevent mechanical chattering[cite: 18, 59]:
$$\dot{s} = -\eta \tanh\left(\frac{s}{\phi}\right)$$
[cite: 59]

### 3. Supervisory Action Translation & Parameter Envelopes
The TD3 actor network generates normalized actions $u_i \in [-1, 1]$ mapped to continuous physical parameters[cite: 35, 41, 42]:
* **$C_2$ (Speed vs. Overshoot):** $C_2 = 20.0 + 5.0 \cdot u_1 \in [15.0, 25.0]$[cite: 42]
* **$C_4$ (Internal Damping):** $C_4 = 2.0 + 1.0 \cdot u_2 \in [1.0, 3.0]$[cite: 42]
* **$\eta$ (Reaching Velocity):** $\eta = 100.0 + 50.0 \cdot u_3 \in [50.0, 150.0]$[cite: 42]
* **$\phi$ (Boundary Layer):** $\phi = 0.100 + 0.070 \cdot u_4 \in [0.030, 0.170]$ (guaranteed above the $0.027$ chattering boundary)[cite: 42]

---

## 🛡️ Training Environment, Multi-Tier Reward & Safety Kill-Switch

Training was executed offline in MATLAB/Simulink across **5,000 episodes (60s / 3,000 steps each)** utilizing an NVIDIA RTX 3080 Ti GPU (12-hour compute budget)[cite: 35, 37, 39, 43].

```text
       ┌────────────────────────────────────────────────────────┐
       │             Supervisory TD3 Agent (50 Hz)              │
       │    Observation: 13x1 Vector | Action: [C2, C4, η, φ]   │
       └──────────────────────────┬─────────────────────────────┘
                                  │ Actions u ∈ [-1, 1]
                                  ▼
       ┌────────────────────────────────────────────────────────┐
       │      scale_actions: Linear Envelope Scaling Block      │
       └──────────────────────────┬─────────────────────────────┘
                                  │ Dynamic [C2, C4, η, φ]
                                  ▼
┌─────────────┐   u(t)    ┌──────────────┐  x1, x2   ┌───────────────────┐
│ Reference / ├──────────►│ Manual SMC   ├──────────►│  4th-Order CMSD   │
│ Step Limits │           │ Reaching Law │           │ Physical Dynamics │
└─────────────┘           └──────────────┘           └─────────┬─────────┘
       ▲                                                       │
       └──────────────── Feedback Loop (100 Hz) ───────────────┘
```[cite: 9, 34, 35, 41, 42]

### Multi-Tier Reward Function (`calc_reward.m`)
Evaluated at 50 Hz to balance precision with structural preservation[cite: 30, 31, 32]:
1. **Base Survival:** $+0.2$ per timestep[cite: 31, 32]
2. **Quadratic Tracking Penalty:** $-4.0 \cdot e_{x_2}^2$[cite: 31, 32]
3. **Parachute Penalty:** $-1.0 \cdot \vert{}v_2\vert{}$ active only within $\vert{}e_{x_2}\vert{} < 50\text{ mm}$ when $\vert{}v_2\vert{} > 0.10\text{ m/s}$ (curbs aggressive terminal velocity)[cite: 31, 32]
4. **Target Lock Bonus:** $+0.6$ for $\vert{}e\vert{} < 10\text{ mm}$, $+0.3$ for $\vert{}e\vert{} < 30\text{ mm}$[cite: 31, 32]
5. **Continuous Gaussian Progress:** $+0.2 \cdot \exp(-5.0 \cdot e_{x_2}^2)$[cite: 31, 32]
6. **Actuator Stroke Protection:** Quadratic soft penalty for $\vert{}x_1\vert{} > 0.30\text{ m}$, Gaussian centering bonus $0.06 \cdot \exp(-10.0 \cdot x_1^2)$[cite: 31, 32]
7. **Terminal Fail Penalty:** $-2000.0$ if $\vert{}x_1\vert{} > 0.65\text{ m}$[cite: 31, 32]
8. **Action Smoothness Penalty (Inference Benchmark):** $-0.05 \cdot \sum \vert{}\Delta u_i\vert{}$ when single-frame action shifts exceed $0.2$[cite: 44]

### Hardware-Protection Safety Interlock (`check_safety.m`)
Terminates bad episodes immediately to prevent solver divergence and policy collapse[cite: 33, 34]:
* **Hardware Limit:** $\vert{}x_1\vert{} > 0.65\text{ m}$ (unconditional trip)[cite: 33, 34]
* **Total Loss of Control:** $\vert{}e_{x_2}\vert{} > 0.50\text{ m}$ sustained for $> 3.0\text{ s}$[cite: 33, 34]
* **Settle-Time Violation:** $\vert{}e_{x_2}\vert{} > 30\text{ mm}$ after $2.5\text{ s}$ following a reference step[cite: 33, 34]

---

## 📊 Comprehensive Controller Benchmark

### 1. Meta-RL SMC vs. Baseline Fixed-Gain SMC (CMSD Benchmark)
Evaluated on reference steps $\in [-0.2, 0.5]\text{ m}$ under white noise ($P_n = 200\text{ N}$)[cite: 9, 41, 50]:

| Metric | Fixed-Gain SMC[cite: 53] | Meta-RL Tuned SMC[cite: 53] | Delta / Trade-off |
| :--- | :--- | :--- | :--- |
| **Max Peak Force ($u_{\max}$)**[cite: 53] | $+2,427\text{ N}$[cite: 50, 53] | **$+1,196\text{ N}$**[cite: 53] | **-50.7% (Reduced Actuator Stress)**[cite: 53] |
| **Min Peak Force ($u_{\min}$)**[cite: 53] | $-2,421\text{ N}$[cite: 50, 53] | **$-1,162\text{ N}$**[cite: 53] | **-52.0% (Reduced Actuator Stress)**[cite: 53] |
| **Average Energy Draw ($\vert{}u\vert{}$)**[cite: 53] | $95.79\text{ N}$[cite: 50, 53] | $96.05\text{ N}$[cite: 53] | $+0.27\%$ (Identical baseline consumption)[cite: 53] |
| **Mean Absolute Error ($x_2$)**[cite: 53] | $0.0127\text{ m}$[cite: 50, 53] | $0.0169\text{ m}$[cite: 53] | $+33\%$ trade-off due to parachute penalty[cite: 53] |
| **Actuation Profile**[cite: 53] | Severe violent spikes[cite: 52] | Smooth force gradients[cite: 52, 53] | Eliminates actuator fatigue and chatter[cite: 53] |

### 2. Full 7-Controller Comparative Performance (CMSD System)
Data extracted from empirical test series across the CMSD benchmark[cite: 25]:

| Controller Architecture | Tracking MAE ($x_2$)[cite: 25] | Tracking RMSE ($x_2$)[cite: 25] | Effort MAE ($u$)[cite: 25] | Effort RMSE ($u$)[cite: 25] | Performance Summary |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Model Predictive Control (MPC)**[cite: 25] | **$0.00358\text{ m}$**[cite: 25] | **$0.02589\text{ m}$**[cite: 25] | $160.23\text{ N}$[cite: 25] | $228.01\text{ N}$[cite: 25] | Lowest tracking error via receding horizon lookahead[cite: 7, 24] |
| **PID + Feedforward**[cite: 25] | $0.00643\text{ m}$[cite: 25] | $0.02888\text{ m}$[cite: 25] | $165.04\text{ N}$[cite: 25] | $307.16\text{ N}$[cite: 25] | High precision, but severe mechanical actuator spikes[cite: 17] |
| **Fixed-Gain SMC**[cite: 25] | $0.00780\text{ m}$[cite: 25] | $0.03363\text{ m}$[cite: 25] | $151.59\text{ N}$[cite: 25] | $200.79\text{ N}$[cite: 25] | Robust disturbance rejection, moderate effort[cite: 19] |
| **Adaptive PID**[cite: 25] | $0.00899\text{ m}$[cite: 25] | $0.03054\text{ m}$[cite: 25] | $163.78\text{ N}$[cite: 25] | $306.87\text{ N}$[cite: 25] | High overhead, prone to transient overshoot[cite: 5, 25] |
| **PID + LQR Hybrid**[cite: 25] | $0.01000\text{ m}$[cite: 25] | $0.03723\text{ m}$[cite: 25] | $165.48\text{ N}$[cite: 25] | $308.02\text{ N}$[cite: 25] | Complex to tune; inner/outer loops compete[cite: 6, 25] |
| **Adaptive SMC (Culture-Bees)**[cite: 25] | $0.01327\text{ m}$[cite: 25] | $0.04251\text{ m}$[cite: 25] | $147.89\text{ N}$[cite: 25] | $196.48\text{ N}$[cite: 25] | Good chatter attenuation; computationally heavy (10ms opt)[cite: 6, 22] |
| **Linear Quadratic Regulator (LQR)**[cite: 25] | $0.02337\text{ m}$[cite: 25] | $0.05679\text{ m}$[cite: 25] | **$144.57\text{ N}$**[cite: 25] | **$175.40\text{ N}$**[cite: 25] | Pure regulator; lacks integral tracking authority[cite: 5, 25] |

### 3. Inverted Pendulum Benchmark Results
Initial benchmark validating modern SMC against classical Dual-PID under non-collocated cart-pole dynamics[cite: 8, 12, 15]:
* **Cart Position Tracking ($x$):** SMC achieved $\text{MAE} = 0.0342\text{ m}$ vs Dual-PID $\text{MAE} = 0.0582\text{ m}$ (**41.2% improvement**)[cite: 12, 15].
* **Angle Stabilization ($\theta$):** SMC achieved $\text{MAE} = 0.0015\text{ rad}$ vs Dual-PID $\text{MAE} = 0.0028\text{ rad}$ (**46.7% improvement**)[cite: 12, 15].
* **Control Effort ($u$):** Achieved superior balance with only a negligible $2.1\%$ increase in average effort[cite: 15].

---

## 🎲 Monte Carlo Statistical Evaluation & Policy Drift Analysis

To verify generalizability across arbitrary disturbance profiles, agents were evaluated in a **100-run parallel Monte Carlo gauntlet** over three randomized RNG seeds[cite: 44, 47, 49]:

```matlab
% Monte Carlo Parallel Execution Extract
parfor i = 1:numRuns
    assignin('base', 'ref_seed', shared_ref_seeds(i));
    assignin('base', 'noise_seed', shared_noise_seeds(i));
    exp3971 = sim(env, agent3971, simOpts);
    scores_3971(i) = sum(exp3971.Reward);
    exp5000 = sim(env, agent5000, simOpts);
    scores_5000(i) = sum(exp5000.Reward);
end
```[cite: 47, 48]

| Test Batch | Random Seed | Agent 3971 (Mid-Training)[cite: 49] | Agent 5000 (End-Training)[cite: 49] | Statistical Winner[cite: 49] |
| :---: | :---: | :---: | :---: | :---: |
| Run 1[cite: 49] | Seed 42[cite: 49] | **1094.57**[cite: 49] | 1007.53[cite: 49] | Agent 3971 (+87.04 pts)[cite: 49] |
| Run 2[cite: 49] | Seed 16[cite: 49] | **1062.92**[cite: 49] | 990.99[cite: 49] | Agent 3971 (+71.93 pts)[cite: 49] |
| Run 3[cite: 49] | Seed 44[cite: 49] | **1151.37**[cite: 49] | 1065.71[cite: 49] | Agent 3971 (+85.66 pts)[cite: 49] |

### The "Policy Degradation" Phenomenon
Around episode 3,971, the actor network had successfully converged upon an optimal trade-off frontier[cite: 46, 49]. Because training continued for an additional 1,000 episodes with an exploration variance floor ($\sigma_{\min} = 0.05$)[cite: 37, 49], gradient updates overwrote subtle optimal weights with slightly more conservative ones[cite: 49]. **Key Takeaway:** In deep reinforcement learning for physical control, more training steps do not guarantee monotonic improvements; rigorous checkpoint scoring is required[cite: 49].

---

## 📁 Repository Structure

```text
├── docs/
│   ├── BTL_ME4204_Report.pdf            # Full 62-page curriculum report
│   └── dwell_time_stability_proof.pdf   # Complete Liberzon hybrid stability derivation
├── matlab/
│   ├── agents/
│   │   ├── Tested_Reward629_Agent3971.mat  # Optimal checkpoint (Monte Carlo winner)
│   │   └── Tested_Reward614_Agent5000.mat  # Episode 5000 terminal agent
│   ├── functions/
│   │   ├── calc_reward.m               # 7-stage 50 Hz reward shaping function
│   │   └── check_safety.m              # 3-condition hardware-protection kill switch
│   ├── scripts/
│   │   ├── NN_SMC_Agent_1.m            # TD3 training configuration & hyperparameter setup
│   │   ├── run_agent_benchmark.m       # Chatter-penalized evaluation pipeline
│   │   └── run_monte_carlo_gauntlet.m  # 100-run parallelized statistical validator
│   └── models/
│       ├── Inverted_Pendulum_Sim.slx   # Dual-PID vs. SMC Inverted Pendulum benchmark
│       ├── CMSD_Classical_Modern.slx   # CMSD with PID, SMC, Adaptive SMC, LQR, MPC
│       └── RL_SMC_Training_Env.slx     # Closed-loop TD3 supervisory training harness
└── media/
    ├── smc_tracking_effort_comparison.png
    ├── training_convergence_5000ep.png
    └── ai_parameter_adaptation_profiles.png
```[cite: 2, 3, 32, 34, 35, 41, 42, 45, 47]

---

## 🚀 How to Run the Simulations

### Prerequisites
* MATLAB R2024a or newer[cite: 1]
* Simulink[cite: 1]
* Reinforcement Learning Toolbox
* Control System Toolbox
* Parallel Computing Toolbox (for multi-core Monte Carlo sweeps)[cite: 47]

### 1. Evaluate Pre-Trained Agent 3971 vs. Fixed SMC
```matlab
% Set benchmark seeds matching report specification
noise_seed = 23341; ref_seed = 12345;
open_system('matlab/models/RL_SMC_Training_Env.slx');
sim('matlab/models/RL_SMC_Training_Env.slx');
```[cite: 41, 42, 45, 50]

### 2. Execute the 100-Run Monte Carlo Statistical Gauntlet
```matlab
run('matlab/scripts/run_monte_carlo_gauntlet.m');
```[cite: 47]

---

## 📜 Academic Attribution

```bibtex
@techreport{nguyen2026rl_meta_smc,
  author      = {Nguy{\~{e}}n Minh Ho{\`{a}}ng},
  title       = {Curriculum Report: AI-Assisted Sliding Mode Control and Supervisory Reinforcement Learning Agent on Coupled Mechanical Systems},
  institution = {Ho Chi Minh City University of Technology (HCMUT)},
  number      = {ME4204-2252234},
  year        = {2026},
  month       = {May}
}
```[cite: 2]
