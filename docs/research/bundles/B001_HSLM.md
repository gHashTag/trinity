# B001: HSLM-1.95M Ternary Neural Networks

**DOI:** 10.5281/zenodo.19227865
**Version:** 8.0
**LOC:** 605

## Overview

HSLM (Hierarchical Sacred Language Model) is a 1.95M parameter ternary neural network using balanced ternary representation {-1, 0, +1}. Achieves 19.7× model size reduction vs FP32 baselines while maintaining comparable performance.

## Key Features

- **Architecture:** 1.95M parameters, 385 KB model size
- **Quantization:** φ-based ternary encoding (3.1 trits/parameter)
- **Training:** TinyStories dataset (10M tokens)
- **Performance:** 10× power reduction, 19.7× size reduction

## Files

- Metadata: `docs/research/.zenodo.B001_v8.0.json`
- Source: `src/hslm/`
- Models: `var/trinity/models/hslm-1.95m/`

## Citation

```bibtex
@software{trinity_b001,
  title={Trinity B001: HSLM-1.95M Ternary Neural Networks},
  author={Vasilev, Dmitrii},
  year={2026},
  doi={10.5281/zenodo.19227865},
  publisher={Zenodo}
}
```

## Links

- Zenodo: https://zenodo.org/doi/10.5281/zenodo.19227865
- GitHub: https://github.com/gHashTag/trinity
