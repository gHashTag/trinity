// ═══════════════════════════════════════════════════════════════════════════════
// VSA Core — Sparse Operations (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code and re-export all public symbols
const gen = @import("gen_sparse.zig");

pub const SparseVector = gen.SparseVector;

// Manual (disabled):
// const manual = @import("sparse_manual.zig");
// pub const SparseVector = manual.SparseVector;
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════════════════
