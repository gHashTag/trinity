// ═══════════════════════════════════════════════════════════════════════════════
// VSA Core — Operations (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════════════════
//
// TTT Dogfood Stage 1.0: Using GENERATED implementation from .tri spec
// Source: specs/vsa/ops.tri → tri_to_zig.zig → gen_ops.zig
//
const generated = @import("gen_ops.zig");

pub usingnamespace generated;
//
// ═══════════════════════════════════════════════════════════════════════════════
// To revert to manual: comment out above, uncomment below:
// const manual = @import("ops_manual.zig");
// pub usingnamespace manual;
// ═══════════════════════════════════════════════════════════════════════════════
//
// φ² + 1/φ² = 3 | TRINITY
