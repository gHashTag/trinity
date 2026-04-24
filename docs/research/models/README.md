# Trinity Model Documentation

This directory consolidates all documentation about model architectures and training systems used in Trinity.

## Structure

- **[JEPA-T/](./JEPA-T/)** - Ternary Joint Embedding Predictive Architecture
- **[NCA/](./NCA/)** - Neural Cellular Automata
- **[VSA/](./VSA/)** - Vector Symbolic Architecture
- **[Ternary/](./Ternary/)** - Ternary computing and representation
- **[Hybrid/](./Hybrid/)** - Hybrid BigInt and arithmetic

## Quick Links

### JEPA-T
- [Architecture](./JEPA-T/architecture.md) - TrinityBlock, masks, EMA, MSE loss
- [Parameters](./JEPA-T/parameters.md) - Training configuration and multipliers
- [Experiments](./JEPA-T/experiments.md) - Experimental results (J-000, bugs fixed, implementation files)
- [Next Experiments](./JEPA-T/next-experiments.md) - Planned work (J-001, H-001, ctx=81)

### Neural Cellular Automata (NCA)
- [Architecture](./NCA/architecture.md) - Grid configuration, states, entropy
- [Entropy Bands](./NCA/entropy-bands.md) - Wave 8.5 G1-G8 sweep
- [Integration](./NCA/integration.md) - Multi-objective with JEPA/NTP

### VSA
- [Overview & Navigation](./VSA/README.md) - Links to API docs, tutorials, and cheat sheets

### Ternary Models
- [Overview & Navigation](./Ternary/README.md) - Links to complete ternary guide and ADR

### Hybrid Models
- [Overview & Navigation](./Hybrid/README.md) - Links to HybridBigInt API and reports

## Related Documentation

- [HSLM Training: ../../experiments/FOUND_EXPERIMENTS_SUMMARY.md](../experiments/FOUND_EXPERIMENTS_SUMMARY.md)
- [SEVO Method: ../../lab/papers/sevo-method.md](../../lab/papers/sevo-method.md)
- [Framework: ../../research/TRINITY_S3AI_UNIFIED_FRAMEWORK.md](../research/TRINITY_S3AI_UNIFIED_FRAMEWORK.md)
- [Glossary: ../../glossary.md](../glossary.md)

---

**Last updated:** 2026-04-24 (consolidated JEPA-T, simplified VSA/Ternary/Hybrid)
