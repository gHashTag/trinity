# QUEEN Research City

The Research City is a native three-dimensional view of the canonical QUEEN
research graph. It deliberately uses original procedural geometry rather than
third-party game assets or copied faction symbols.

## Observable contract

- A valid research node becomes one laboratory.
- A valid dependency edge becomes one energy route.
- Research layers become concentric city districts.
- Research and worker endpoint failures suppress stale live claims.
- The central spire reflects only the public worker ledger.
- Pointer and keyboard selection drive the same evidence inspector.
- Rendering is demand-driven, caps DPR at 1.5, and disables camera damping when
  reduced motion is requested.
- Malformed runtime JSON fails closed without partial geometry.

The city does not claim that any FPGA is connected. Hardware structures may be
shown only when a separately verified public hardware registry is available.
