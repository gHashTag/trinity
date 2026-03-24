## Task: TDGS-3 (Tri Wave 1: reticularraphe + Coptic)
- Goal: First TRI-27 brain module running on VM + Coptic alphabet
- Current step: Update asm_parser.zig for Coptic register names
- Last commit: 402cec4551 — feat(tri27): Coptic alphabet + OPTIC system (Issue #407)
- Build: l0=OK, l1=OK, tri=PARTIAL (HTTP API issue in tri_fpga.zig, non-blocking)
- Blockers: Lexer doesn't recognize Coptic names as Register tokens (classified as Mnemonic)
- Last iteration: 2026-03-25T03:00+07
