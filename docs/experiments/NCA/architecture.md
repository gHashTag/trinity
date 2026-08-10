# NCA Architecture (Neural Cellular Automata)

## Overview

Neural Cellular Automata (NCA) is a grid-based evolution system integrated with neural networks for self-supervised learning. Based on MIT arXiv 2603.10055.

## Grid Configuration

```zig
pub const NcaConfig = struct {
    grid_size: u8 = 9,           // 9×9 = 81 = CONTEXT_LEN
    num_states: u8 = 9,          // K=9 states per cell
    rollout_steps: u16 = 128,    // T timesteps per trajectory
    token_offset: u16 = 4,       // skip PAD/BOS/EOS/UNK
    min_entropy: f32 = 1.5,      // reject too-simple trajectories
    max_entropy: f32 = 2.8,      // reject too-random (log2(9)=3.17)
    seed: u64 = 42,
};
```

### Key Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| Grid | 9×9 = 81 cells | Matches context length |
| States per cell | K=9 | 9 possible states |
| Rollout steps | 128 | Timesteps per trajectory |
| Min entropy | 1.5 | Lower bound for trajectory complexity |
| Max entropy | 2.8 | Upper bound (log2(9)=3.17) |

## Entropy-Based Control

The NCA system uses entropy bands to control rule complexity:

- **Low entropy** (1.0-1.5): Very simple CA rules
- **Default band** (1.5-2.3): Moderate complexity
- **High entropy** (2.5-3.0): Near max possible complexity

See [entropy-bands.md](./entropy-bands.md) for Wave 8.5 G1-G8 sweep details.

## References

- [Source: docs/experiments/FOUND_EXPERIMENTS_SUMMARY.md](../../../experiments/FOUND_EXPERIMENTS_SUMMARY.md)
- [Source: src/tri/evolution.zig](../../../../../src/tri/evolution.zig)
- [Source: src/tri/tri_farm.zig](../../../../../src/tri/tri_farm.zig)
- [Source: src/brain/evolution_simulation.zig](../../../../../src/brain/evolution_simulation.zig)
