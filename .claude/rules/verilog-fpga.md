---
paths:
  - "fpga/**/*.v"
  - "fpga/**/*.xdc"
  - "openxc7-synth/**"
---

# Verilog/FPGA Rules

- Generate Verilog from .tri specs: `zig build vibee -- gen <spec.tri>` with `language: varlog`
- Never manually edit generated .v files in `var/trinity/output/fpga/`
- Testbenches use `*_tb.v` suffix and `iverilog` for simulation
- XDC constraint files must match the target board (Artix-7 xc7a35t)
- After modifying any .v file, remind about synthesis: run `/fpga-synth`
- Keep modules under 500 lines; split into submodules if larger
- Use parameterized widths — avoid hardcoded bit widths where possible
- Clock domain crossings require explicit synchronizers
