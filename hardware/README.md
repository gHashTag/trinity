# `hardware/` — RTL and board glue

| Path | Purpose |
|------|---------|
| `rtl-root/` | Loose Verilog from Vibee / experiments (was historically in repo root). Use paths like `hardware/rtl-root/blink.v` with `tri fpga …`. |
| `jtag/` | OpenOCD / JTAG configs (e.g. `qmtech_ft232_jtag.cfg`, `scan_jtag.tcl`). |

Curated synthesis trees stay under **`fpga/`** (e.g. `fpga/openxc7-synth/`).
