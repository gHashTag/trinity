# T-JEPA Training Parameters

## Multiplier Weights

From experiments, convergence rates for different objectives:

| Objective | Multiplier | Convergence Rate | Notes |
|-----------|-----------|-----------------|-------|
| NTP | 1.0 | Baseline | Standard next-token prediction |
| JEPA | 1.4 | 40% slower | Joint embedding prediction |
| NCA-NTP | 1.6 | 60% slower | Neural cellular automata + NTP |
| Hybrid | 1.2 | 20% slower | Combined objectives |

## Configuration Files

- **Wave 9 config:** `.trinity/wave9.json`
- **JEPA weight:** `HSLM_JEPA_WEIGHT=0.25` (25% of multi-objective)
- **Full config:** See [FOUND_EXPERIMENTS_SUMMARY.md](../../../experiments/FOUND_EXPERIMENTS_SUMMARY.md)

## Environment Variables

```bash
# Mask configuration
HSLM_MASK_RATIO=0.3

# EMA decay
HSLM_EMA_DECAY_START=0.996
HSLM_EMA_DECAY_END=1.0

# Predictor learning rate
HSLM_PREDICTOR_LR_MULT=2.0
```

## Integration with Other Objectives

JEPA operates within the multi-objective system alongside:
- **NTP** (Next Token Prediction): 50% weight
- **NCA** (Neural Cellular Automata): 25% weight
- **JEPA**: 25% weight

See [integration.md](./integration.md) for details.
