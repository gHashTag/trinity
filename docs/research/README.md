# Trinity Model Documentation

This directory consolidates all documentation about model architectures and training systems used in Trinity.

## Structure

- **[JEPAT/](./JEPAT/)** - Ternary Joint Embedding Predictive Architecture
- **[NCA/](./NCA/)** - Neural Cellular Automata
- **[VSA/](./VSA/)** - Vector Symbolic Architecture
- **[Ternary/](./Ternary/)** - Ternary computing and representation
- **[Hybrid/](./Hybrid/)** - Hybrid BigInt and arithmetic

## Quick Links

### JEPA-T
- [Architecture](./JEPAT/architecture.md) - TrinityBlock, masks, EMA, MSE loss
- [Parameters](./JEPAT/parameters.md) - Training configuration and multipliers
- [Experiments](./JEPAT/experiments.md) - Experimental results (J-000, J-001)

### Neural Cellular Automata (NCA)
- [Architecture](./NCA/architecture.md) - Grid configuration, states, entropy
- [Entropy Bands](./NCA/entropy-bands.md) - Wave 8.5 G1-G8 sweep
- [Integration](./NCA/integration.md) - Multi-objective with JEPA/NTP

### VSA
- [Overview](./VSA/overview.md) - Core VSA concepts and FPGA implementation
- [Operations](./VSA/operations.md) - Quick reference for bind/unbind/bundle
- [API Reference](./VSA/api.md) - Links to complete API docs

### Ternary Models
- [Balanced Ternary](./Ternary/balanced-ternary.md) - Complete ternary guide (link)
- [Representation ADR](./Ternary/representation.md) - Packed trit encoding (link)

### Hybrid Models
- [API Reference](./Hybrid/api.md) - HybridBigInt API (link)
- [v2.0 Report](./Hybrid/v2.0-report.md) - Implementation report from gh-pages
- [v2.1 Report](./Hybrid/v2.1-report.md) - Latest improvements report

## Related Documentation

- [HSLM Training: ../../experiments/FOUND_EXPERIMENTS_SUMMARY.md](../experiments/FOUND_EXPERIMENTS_SUMMARY.md)
- [SEVO Method: ../../lab/papers/sevo-method.md](../../lab/papers/sevo-method.md)
- [Framework: ../../research/TRINITY_S3AI_UNIFIED_FRAMEWORK.md](../research/TRINITY_S3AI_UNIFIED_FRAMEWORK.md)
- [Glossary: ../../glossary.md](../glossary.md)

---

**Last updated:** 2026-04-24
