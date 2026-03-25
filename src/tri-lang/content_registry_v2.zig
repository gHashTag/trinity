// ═══════════════════════════════════════════════════════════════════
// ContentRegistryV2 (SOURCE OF TRUTH SELECTOR)
// ═══════════════════════════════════════════════════════════════════
//
// TTT Dogfood v0.1: Flip this one line to switch between manual/generated
//
// Self-hosted ENABLED — using generated code from Tri spec:

// Import generated code and re-export all public symbols
const gen = @import("gen_content_registry_v2.zig");

pub const ImprovedHashMapContext = gen.ImprovedHashMapContext;
pub const ContentRegistryV2 = gen.ContentRegistryV2;
pub const testHashQuality = gen.testHashQuality;

// Manual (disabled):
// const manual = @import("content_registry_v2_manual.zig");
// pub const ImprovedHashMapContext = manual.ImprovedHashMapContext;
// ... (all other exports)
//
// φ² + 1/φ² = 3 | TRINITY
// ═══════════════════════════════════════════════════════════════════
