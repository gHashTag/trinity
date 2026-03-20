// @origin(spec:vibee_codegen_tests.tri) @regen(manual-impl)
// ═══════════════════════════════════════════════════════════════════════════════
// VIBEE CODEGEN TESTS
// ═══════════════════════════════════════════════════════════════════════════════
//
// Tests the VIBEEC compiler pipeline.
// Note: trinity-lang module lives in deploy/trinity-nexus/lang/ and is a separate
// workspace. This test is disabled until module path is configured in build.zig.
//
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

test "codegen placeholder" {
    // Placeholder test - trinity-lang module is external (deploy/trinity-nexus/lang/)
    // To enable: uncomment module path in build.zig and uncomment import below
    // const lang = @import("trinity-lang");
    // comptime { _ = lang.zig_codegen.codegen; }
    try std.testing.expect(true);
}

// Uncomment when trinity-lang module is available:
// const lang = @import("trinity-lang");
// comptime {
//     _ = lang.zig_codegen.codegen; // mod.zig + all pattern submodules
// }
