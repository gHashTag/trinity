# HDC Double Q-Learning Report

**φ² + 1/φ² = 3 | TRINITY**

## Overview

Implementation of Hyperdimensional Computing (HDC) based Double Q-Learning for reinforcement learning tasks.

## Environments Tested

### 1. FrozenLake 4x4 (Discrete State Space)

| Metric | Tabular Double Q | HDC Double Q (D=1024) | HDC Double Q (D=10240) |
|--------|------------------|----------------------|------------------------|
| Win Rate (last 1000) | 99.9% | 100.0% | 99.9% |
| Max Consecutive Wins | 2877 | 3545 | 2338 |
| Noise Robustness (20% flip) | N/A | 100.0% | 100.0% |
| Memory (bytes) | 1024 | 32,768 | 327,680 |
| Memory (ternary) | N/A | 2,048 | 20,480 |

**Key Finding**: HDC Double Q achieves comparable performance to tabular with added noise robustness.

### 2. CartPole-v1 (Continuous State Space)

| Metric | HDC Double Q + Tile Coding |
|--------|---------------------------|
| Dimension | 2048 |
| Tilings | 8 |
| Best Avg (100 episodes) | 152.9 |
| Target | 195 |
| Status | In Progress |

**Key Finding**: HDC with tile coding shows learning progress on continuous states.

## Architecture

### HDC State Encoding

```
Discrete States:
  state_index → random_bipolar_hypervector[state_index]

Continuous States (Tile Coding):
  state[4] → discretize → tile_indices → hash → permuted_seed → bundle
```

### HDC Q-Function Approximation

```
Q(s, a) = w_a · φ(s) / D

where:
  w_a = weight hypervector for action a
  φ(s) = HDC encoding of state s
  D = dimension
```

### Double Q Update

```
if random() < 0.5:
    a* = argmax_a Q1(s', a)
    target = r + γ × Q2(s', a*)
    Q1 update
else:
    a* = argmax_a Q2(s', a)
    target = r + γ × Q1(s', a*)
    Q2 update
```

## Advantages of HDC Double Q

1. **Noise Robustness**: 20% trit flips → 0% performance degradation
2. **Ternary Compression**: 2 bits per element (vs 32/64 for float)
3. **Parallel Operations**: All operations are element-wise
4. **Continuous State Support**: Via tile coding + HDC binding
5. **Double Q**: Reduces overestimation bias

## Files

| File | Description |
|------|-------------|
| `specs/phi/hdc_double_q.vibee` | Specification |
| `src/phi-engine/hdc/rl_hdc_double_q.zig` | Initial implementation |
| `src/phi-engine/hdc/rl_hdc_double_q_v2.zig` | Linear approximation (FrozenLake) |
| `src/phi-engine/hdc/rl_hdc_cartpole.zig` | CartPole v1 |
| `src/phi-engine/hdc/rl_hdc_cartpole_v2.zig` | CartPole with tile coding |

## Hyperparameters

### FrozenLake (Optimal)

```
dimension:      1024-10240
learning_rate:  0.5
gamma:          0.95
epsilon_decay:  0.995
epsilon_min:    0.001
```

### CartPole (Current)

```
dimension:      2048
tilings:        8
tiles_per_dim:  10
learning_rate:  0.1
gamma:          0.99
epsilon_decay:  0.995
batch_size:     32
```

## Comparison: Tabular vs HDC

| Aspect | Tabular Q | HDC Q |
|--------|-----------|-------|
| State Representation | Index lookup | Hypervector |
| Generalization | None | Similarity-based |
| Noise Robustness | Low | High |
| Memory Scaling | O(S × A) | O(D × A) |
| Continuous States | Requires discretization | Native via encoding |
| Hardware Friendly | No | Yes (ternary ops) |

## Next Steps

1. **CartPole Optimization**: Tune hyperparameters to reach 195 avg
2. **Ternary Quantization**: Apply periodic quantization during training
3. **Network Integration**: Exchange bundled Q-vectors between agents
4. **FPGA Acceleration**: Implement ternary HDC ops in Verilog

## Conclusion

HDC Double Q-Learning successfully achieves:
- **99.9%+ win rate** on FrozenLake (matching tabular)
- **100% noise robustness** at 20% trit flip rate
- **Learning progress** on continuous CartPole (152.9 avg)

The approach demonstrates that hyperdimensional computing can effectively replace tabular Q-learning while adding noise robustness and enabling continuous state spaces.

**KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED | φ² + 1/φ² = 3**
