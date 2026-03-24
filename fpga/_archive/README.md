# FPGA Archive

Everything here is historical / experimental.
Agents MUST NOT use anything under `fpga/_archive/` by default.

Canonical flow is documented in `../README.md`.

## Archived Bitstreams

| File | Issue | Notes |
|------|-------|-------|
| `uart_bridge_fixed.bit` | J1 vs J2 pin mismatch | Uses A9/D10 (J1) instead of K20/L20 (J2) |

Use `tri fpga build-uart` for the correct J2 bitstream.
