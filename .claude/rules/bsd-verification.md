---
paths:
  - "src/bsd/**/*.zig"
---

# BSD/Cremona Verification Rules

- 3,063,485 curves verified against full Cremona database — do not break this
- LMFDB data files live in `data/ecdata/` — treat as read-only reference
- `verify_bsd.zig` and `verify_lmfdb.zig` are the verification entry points
- L-function computation uses independent_l.zig — high-precision arithmetic required
- Test with: `zig test src/bsd/verify_bsd.zig`
- Never hardcode curve data — always read from LMFDB/Cremona sources
- VSA-FPGA bridge in `vsa_fpga.zig` connects software verification to hardware
