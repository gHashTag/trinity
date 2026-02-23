// ═══════════════════════════════════════════════════════════════════════════════
// VIBEE CODEGEN TESTS — Bridge file for zig build test
// ═══════════════════════════════════════════════════════════════════════════════
//
// Tests the VIBEEC compiler pipeline via the trinity-lang module.
// Source of truth: trinity-nexus/lang/src/
//
// ═══════════════════════════════════════════════════════════════════════════════

const lang = @import("trinity-lang");

// Pattern modules (each has embedded tests)
comptime {
    _ = lang.zig_codegen.codegen; // mod.zig + all pattern submodules
}
