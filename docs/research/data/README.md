# Trinity Zenodo v6.1 Supplementary Data

Benchmark data and experimental results for Zenodo bundles.

## Files

| File | Bundle | Description | Rows |
|-------|---------|-------------|-------|
| B001_training.csv | B001 | HSLM training curve with 95% CI | 7 |
| B002_fpga_synthesis.csv | B002 | FPGA resource utilization | 5 |
| B003_tri27_registers.csv | B003 | TRI-27 register file layout | 27 |
| B004_lotus_cycle.csv | B004 | Queen Lotus episode data | 847 |
| B005_language_features.csv | B005 | Tri language feature analysis | 23 |
| B005_productivity.csv | B005 | Development productivity metrics | 3 |
| B006_gf16_accuracy.csv | B006 | GF16 accuracy benchmarks | 4 |
| B006_roundtrip_precision.csv | B006 | Round-trip precision test | 4 |
| B007_noise_resilience.csv | B007 | VSA noise tolerance | 5 |
| B007_simd_benchmarks.csv | B007 | SIMD speedup measurements | 4 |

## Usage

```python
import pandas as pd

# Load training data
df_train = pd.read_csv('B001_training.csv')
print(df_train.describe())

# Load FPGA synthesis results
df_fpga = pd.read_csv('B002_fpga_synthesis.csv')
print(df_fpga)

# Load SIMD benchmarks
df_simd = pd.read_csv('B007_simd_benchmarks.csv')
print(f"Average speedup: {df_simd['speedup'].mean():.1f}x")
```

## Citation

If you use this data, please cite:

```bibtex
@misc{vasilev2026trinity_data,
  title={Trinity Zenodo v6.1 Supplementary Data},
  author={Vasilev, Dmitrii},
  year={2026},
  month={March},
  doi={10.5281/zenodo.19227879},  # Parent DOI
  url={https://doi.org/10.5281/zenodo.19227879}
}
```

φ² + 1/φ² = 3 | TRINITY
