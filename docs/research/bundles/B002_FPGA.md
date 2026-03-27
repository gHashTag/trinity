# B002: Zero-DSP FPGA Accelerator

**DOI:** 10.5281/zenodo.19227867
**Version:** 9.0
**LOC:** 743

## Overview

FPGA accelerator achieving **zero DSP utilization** while maintaining comparable performance to FP32 baselines. Uses φ-based ternary encoding with LUT-only arithmetic.

## Key Features

- **Target:** Xilinx XC7A100T (48k LUTs, 240 DSP slices)
- **DSP Usage:** 0% (LUT-only implementation)
- **Power:** 2.8W total, 10× reduction vs FP32
- **Throughput:** 500K inferences/second @ 100MHz

## Resource Utilization

| Resource | Used | Available | Utilization |
|----------|----------|----------|-------------|
| LUTs | 14,256 | 48,000 | 29.7% |
| BRAM | 144 KB | 576 KB | 25.0% |
| URAM | 288 KB | 1,280 KB | 22.5% |
| DSP48E1 | 0 | 240 | **0%** |

## Files

- Metadata: `docs/research/.zenodo.B002_v8.0.json`
- Verilog: `fpga/openxc7-synth/`
- Reports: `fpga/synthesis_reports/`

## Citation

```bibtex
@software{trinity_b002,
  title={Trinity B002: Zero-DSP FPGA Accelerator for Ternary Neural Networks},
  author={Vasilev, Dmitrii},
  year={2026},
  doi={10.5281/zenodo.19227867},
  publisher={Zenodo}
}
```

## Links

- Zenodo: https://zenodo.org/doi/10.5281/zenodo.19227867
- GitHub: https://github.com/gHashTag/trinity
