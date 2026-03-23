# RTL snapshots (repo root cleanup)

All `*.v` that previously lived in the Trinity **repository root** are collected here so the root stays readable.

- **Examples:** `blink.v`, `trinity_v2_top.v`, `ternary_matvec_top.v`, …
- **CLI:** `tri fpga build hardware/rtl-root/blink.v` (adjust top module as needed).
- **New files:** agents should add RTL under this directory (or under `fpga/…`), **not** in `/`.
