# Trinity Documentation

## Quick Navigation

| Section | Description | Audience |
|---------|-------------|----------|
| [Getting Started](getting-started/) | Installation, quick start, tutorials | All users |
| [API Reference](api/) | Trinity & VIBEE API documentation | Developers |
| [Architecture](architecture/) | System design and internals | Engineers |
| [FPGA](fpga/) | Hardware acceleration, BitNet | Hardware engineers |
| [Research](research/) | Scientific papers, proofs | Academics |
| [Integrations](integrations/) | Agents, browser automation, IGLA | Developers |
| [Development](development/) | Koschei methodology, reports | Contributors |
| [i18n](i18n/) | Localized documentation | All users |

---

## For Engineers

### Getting Started
```bash
git clone https://github.com/gHashTag/trinity.git
cd trinity
zig build
zig build test
```

### Key Documents
1. [Installation Guide](getting-started/INSTALLATION.md)
2. [Trinity API](api/TRINITY_API.md)
3. [VIBEE Spec Format](api/VIBEE_SPEC_FORMAT.md)
4. [Architecture Overview](architecture/TRINITY_TECHNOLOGIES.md)

---

## For Academics

### Research Papers
- [BitNet Mathematical Proof](research/BITNET_MATHEMATICAL_PROOF.md)
- [Ternary vs Binary Explained](research/TERNARY_VS_BINARY_EXPLAINED.md)
- [Scientific Papers Collection](research/SCIENTIFIC_PAPERS.md)

### Key Results
| Metric | Value | Reference |
|--------|-------|-----------|
| VSA Throughput | 8.9 B trits/sec | [Benchmarks](fpga/BENCHMARKS.md) |
| Memory Efficiency | 256x vs FP32 | [Architecture](architecture/) |
| BitNet Energy | 0.05 mJ/token | [FPGA Whitepaper](fpga/FPGA_NETWORK_WHITEPAPER.md) |

---

## For FPGA Engineers

### Hardware Documentation
- [FPGA Quick Start](fpga/FPGA_QUICKSTART.md)
- [FPGA Network Whitepaper](fpga/FPGA_NETWORK_WHITEPAPER.md)
- [BitNet Core Specification](../specs/fpga/bitnet_core.vibee)
- [Verilog Code Generation](getting-started/VERILOG_CODEGEN.md)

### Supported Platforms
- Xilinx Artix-7 (XC7A35T)
- Xilinx Alveo U50/U55C
- Intel/Altera (planned)

---

## Directory Structure

```
docs/
├── getting-started/    # 16 docs - Installation, tutorials, guides
├── api/                # 3 docs  - API reference
├── architecture/       # 22 docs - System design, internals
├── fpga/               # 39 docs - Hardware, BitNet, benchmarks
├── research/           # 39 docs - Scientific papers, proofs
├── integrations/       # 78 docs - Agents, browser, IGLA, PAS
├── development/        # 77 docs - Koschei, reports, roadmap
├── i18n/               # 11 docs - Russian, English translations
└── archive/            # 5514 docs - Historical, book chapters
```

---

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.

### Development Methodology
Trinity uses the **Koschei** development methodology:
- [Koschei Whitepaper](development/KOSHEY_WHITEPAPER.md)
- [Technology Tree](development/TECHNOLOGY_TREE.md)
- [Toxic Verdict Template](development/KOSHEY_TOXIC_VERDICT.md)

---

## Localization

- [Russian Documentation](i18n/ru/)
- [English Documentation](i18n/en/)

---

## License

MIT License - see [LICENSE](../LICENSE)
