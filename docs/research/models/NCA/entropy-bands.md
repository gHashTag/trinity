# NCA Entropy Bands (Wave 8.5 G1-G8 Sweep)

## CLI Flags

```bash
--nca-entropy-min <float>  (default 1.5)
--nca-entropy-max <float>  (default 2.8)
```

## G1-G8 Entropy Sweep Table

| Group | Min Entropy | Max Entropy | Notes |
|-------|-------------|-------------|-------|
| G1 | 1.0 | 1.5 | Very simple CA rules |
| G2 | 1.2 | 1.8 | Simple → moderate |
| G3 | 1.4 | 2.0 | Moderate complexity |
| G4 | 1.5 | 2.3 | Default band |
| G5 | 1.7 | 2.5 | Above default |
| G6 | 2.0 | 2.7 | Near max |
| G7 | 2.3 | 2.9 | High entropy |
| G8 | 2.5 | 3.0 | Max (log2(9)=3.17) |

## Configuration Command

```bash
tri farm evolve inject \
  --target <service> \
  --objective nca-jepa-ntp \
  --nca-steps 15000 \
  --nca-entropy-min 1.5 \
  --nca-entropy-max 2.8
```

## NCA Quotas

- **25% of training slots** allocated to NCA objectives
- **Cell parser agent** support for NCA trajectory analysis
- **Entropy control** via min/max bands prevents degenerate rules

## References

- [Source: docs/experiments/FOUND_EXPERIMENTS_SUMMARY.md](../../../experiments/FOUND_EXPERIMENTS_SUMMARY.md)
- [Related: architecture.md](./architecture.md)
