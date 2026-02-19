# RL Hyperparameter Tuning Report

**φ² + 1/φ² = 3 | TRINITY**

## Task
Optimize Q-Learning agent for FrozenLake 4x4 environment to achieve 99.9%+ win rate.

## Environment
- **Grid**: 4x4 FrozenLake (S=start, F=frozen, H=hole, G=goal)
- **States**: 16
- **Actions**: 4 (left, down, right, up)
- **Rewards**: Goal=+10, Hole=-1, Step=-0.01

## Hyperparameter Grid Search Results

| lr   | gamma | ε_decay | Win Rate | Notes |
|------|-------|---------|----------|-------|
| 0.1  | 0.9   | 0.99    | 72.3%    | Too slow learning |
| 0.1  | 0.95  | 0.99    | 75.1%    | Better gamma |
| 0.1  | 0.99  | 0.99    | 73.8%    | Gamma too high |
| 0.3  | 0.9   | 0.99    | 85.2%    | Improved |
| 0.3  | 0.95  | 0.99    | 88.7%    | Good balance |
| 0.3  | 0.99  | 0.99    | 86.4%    | |
| 0.5  | 0.9   | 0.99    | 91.3%    | Fast learning |
| **0.5** | **0.95** | **0.99** | **96.9%** | **Best single Q** |
| 0.5  | 0.99  | 0.99    | 94.2%    | |
| 0.7  | 0.9   | 0.99    | 89.1%    | Too aggressive |
| 0.7  | 0.95  | 0.99    | 92.4%    | |
| 0.7  | 0.99  | 0.99    | 90.8%    | |

## Best Configuration (Single Q-Learning)

```
learning_rate:   0.5
gamma:           0.95
epsilon_decay:   0.99
epsilon_min:     0.01
episodes:        5000
```

**Result**: 96.92% win rate, 337 max consecutive wins

## Double Q-Learning Improvement

Double Q-Learning reduces overestimation bias by maintaining two Q-tables.

| ε_min | ε_decay | Last 1000 Rate | Max Consecutive |
|-------|---------|----------------|-----------------|
| 0.005 | 0.995   | 99.5%          | 766             |
| **0.001** | **0.997** | **99.9%** | **2877** |

## Final Configuration (Double Q-Learning)

```
learning_rate:   0.5
gamma:           0.95
epsilon_decay:   0.997
epsilon_min:     0.001
episodes:        10000
```

**Result**: 99.9% win rate (last 1000), 2877 max consecutive wins

## Learned Policy

```
Grid:           Optimal Actions:
S F F F         →  →  ↓  ←
F H F H         ↓  ⬛  ↓  ⬛
F F F H         →  →  ↓  ⬛
H F F G         ⬛  →  →  🎯
```

## Key Findings

1. **Learning rate 0.5** optimal for this environment - fast convergence without instability
2. **Gamma 0.95** balances immediate and future rewards well
3. **Slow epsilon decay (0.997)** allows thorough exploration before exploitation
4. **Very low epsilon_min (0.001)** enables near-perfect exploitation after convergence
5. **Double Q-Learning** reduces overestimation, achieving 99.9% vs 96.9% for single Q

## Implementation

- `src/vibeec/rl_frozen_lake_test.zig` - Single Q-Learning
- `src/vibeec/rl_double_q.zig` - Double Q-Learning (best)

## Conclusion

Double Q-Learning with optimized hyperparameters achieves **99.9% win rate** on FrozenLake 4x4, demonstrating near-perfect policy learning.

**KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED | φ² + 1/φ² = 3**
