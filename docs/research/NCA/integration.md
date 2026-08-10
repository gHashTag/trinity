# NCA Integration with JEPA and NTP

## Multi-Objective System

NCA operates within the HSLM multi-objective training alongside:

| Objective | Weight | Description |
|-----------|--------|-------------|
| NTP | 0.50 | Next token prediction |
| JEPA | 0.25 | Joint embedding prediction |
| NCA-NTP | 0.25 | Neural cellular automata + NTP |

## Training Pipeline Phases

### Phase 1: NCA Pre-training (15K steps)
```bash
HSLM_NCA_STEPS=15000
```

### Phase 2: JEPA Training (40K steps)
```bash
HSLM_JEPA_STEPS=40000
```

### Phase 3: NTP Training (until convergence)
Standard next-token prediction training

## Alternative Configurations

```zig
enum { ntp, jepa, hybrid, nca_ntp, nca_jepa_ntp, nca_jepa_ntp_v2 }

// nca_jepa_ntp:    NCA 15K → JEPA 40K → NTP
// nca_jepa_ntp_v2: NCA 15K → JEPA 20K → NTP (faster)
```

## SEVO Evolution

The SEVO (Sacred EVolutionary Objective Search) system supports objective mutation including NCA:

- **JEPA** can be mutated to NCA during evolution
- **NCA** can be mutated to JEPA during evolution
- **Quotas** ensure diversity across objective types

See [SEVO documentation](../../docs/lab/papers/sevo-method.md) for details.

## References

- [JEPA: ../JEPAT/architecture.md](../JEPAT/architecture.md)
- [SEVO: docs/lab/papers/sevo-method.md](../../../lab/papers/sevo-method.md)
- [Framework: docs/research/TRINITY_S3AI_UNIFIED_FRAMEWORK.md](../../../research/TRINITY_S3AI_UNIFIED_FRAMEWORK.md)
