// ═══════════════════════════════════════════════════════════════════════════════
// VIBEE CODEGEN TESTS — Bridge file for zig build test
// ═══════════════════════════════════════════════════════════════════════════════
//
// Root at src/vibeec/ so all imports resolve correctly:
//   codegen/types.zig → @import("../vibee_parser.zig") → src/vibeec/vibee_parser.zig
//
// ═══════════════════════════════════════════════════════════════════════════════

// Pattern modules (each has embedded tests)
comptime {
    _ = @import("codegen/patterns/rl.zig"); // 52 e2e tests
    _ = @import("codegen/patterns/mod.zig"); // matchAll, matchWithCategory tests
    _ = @import("codegen/patterns/registry.zig"); // prefix/category lookup tests
}
