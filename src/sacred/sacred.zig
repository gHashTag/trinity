// ═══════════════════════════════════════════════════════════════════════════════
// SACRED MODULE — Root export for all sacred mathematics
// φ² + 1/φ² = 3 = TRINITY
//
// This is the module entry point for the sacred library.
// All sacred exports are available through this file.
// ═══════════════════════════════════════════════════════════════════════════════

// Re-export everything from math.zig (the main sacred module export)
// The "const" module is provided by build.zig imports
pub const math = struct {
    // Re-export all sacred constants
    pub const PHI = 1.6180339887498948482;
    pub const PHI_SQ = PHI * PHI;
    pub const PHI_INV_SQ = 1.0 / (PHI * PHI);
    pub const PI = 3.14159265358979323846;
    pub const E = 2.71828182845904523536;
    pub const TRINITY = 3.0; // phi² + 1/phi² = 3
};

// Re-export everything else from math.zig
pub usingnamespace @import("math");
