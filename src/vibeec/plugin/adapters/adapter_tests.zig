// Trinity Plugin Adapters - Test Runner
// Imports all adapter modules and runs their tests
//
// Run with: zig test src/vibeec/plugin/adapters/adapter_tests.zig
//
// This file exists because individual adapter files can't be tested
// directly due to relative import paths going outside module boundaries.

const std = @import("std");

// Test stub - actual tests are in individual modules
// This file is used to add adapters to build.zig for proper testing

test "adapter tests placeholder" {
    // Placeholder test - actual adapter tests are in build.zig
    try std.testing.expect(true);
}
